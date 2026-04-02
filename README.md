# Liferay Export/Import Validation Tool

A modular Bash script for helping in validating Liferay export/import operations by comparing the database state of a source site against a target site. It runs SQL checks against both environments, diffs the results automatically, and produces a summary on screen with a full log written to file.

---

## How it works

The script connects to two MySQL databases — source and target — resolves the provided company and site into concrete `companyId` and `groupId` values, then runs a series of SQL checks per entity type. Each check runs the same query against both sides, normalizes the output, and diffs the result. A summary of pass/fail per check is printed to the screen; full query output and diff details are written to a timestamped log file.

---

## Requirements

This was written for Liferay DXP 7.4 2026.Q1

- Bash 4+
- `mysql` client in `PATH`
- Network access to both source and target MySQL/MariaDB instances
- Read-only DB credentials for both environments

---

## File structure

```
compare.sh                 Main script
config/
  db.conf                  DB Credentials file
tests/
  asset_library.sh         Asset Libraries
  blog.sh                  Blogs
  calendar.sh              Calendar
  category_vocabulary.sh   Asset Categories and Vocabularies
  collection.sh            Collections
  documents_and_media.sh   Documents and Media
  form.sh                  Forms
  fragment.sh              Fragments
  friendly_url.sh          Friendly URLs
  navigation_menu.sh       Navigation Menus
  page.sh                  Pages
  segment.sh               Segments and Experiences
  style_book.sh            Style Books
  tag.sh                   Tags
  template.sh              Templates
  web_content.sh           Web Content
  wiki.sh                  Wiki
logs/
  compare_YYYYMMDD_HHMMSS.log   Generated per run (gitignored)
```

---

## Setup

1. Clone the repository.
2. Copy the credentials template and fill in your values:
   ```bash
   cp config/db.conf.example config/db.conf
   ```
3. Edit `config/db.conf`:
   ```bash
   # Source environment
   SRC_DB_HOST=localhost
   SRC_DB_PORT=3306
   SRC_DB_NAME=lportal
   SRC_DB_USER=root
   SRC_DB_PASS=

   # Target environment
   TGT_DB_HOST=localhost
   TGT_DB_PORT=3306
   TGT_DB_NAME=lportal
   TGT_DB_USER=root
   TGT_DB_PASS=
   ```
4. Make the script executable:
   ```bash
   chmod +x compare.sh
   ```

---

## Usage

```
bash compare.sh --source-company-web-id <webId> --source-site <site_key>
                --target-company-web-id <webId> --target-site <site_key>
                [--tests t1,t22,...] [--verbose]
```

### Parameters

| Parameter | Required | Description |
|---|---|---|
| `--source-company-web-id` | No | Source company `webId` from the `Company` table. Defaults to `liferay.com`. |
| `--source-site` | Yes | Source site `groupKey` from the `Group_` table. |
| `--target-company-web-id` | No | Target company `webId`. Defaults to `liferay.com`. |
| `--target-site` | Yes | Target site `groupKey`. |
| `--tests` | No | Comma-separated list of tests to run. Defaults to all discovered tests. |
| `--verbose` | No | Write full query output to the log for passing checks as well as failing ones. |

### Examples

```bash
# Compare two sites within the same Liferay instance
./compare.sh --source-site guest --target-site new-site

# Compare sites across two different tenants
./compare.sh compare.sh --source-company-web-id tenant-a.com --source-site guest \
                --target-company-web-id tenant-b.com --target-site guest

# Run specific tests only
./compare.sh compare.sh --source-site guest --target-site guest \
                --tests wiki,segments,webcontent

# Save a full audit log with no colors
NO_COLOR=1 ./compare.sh compare.sh --source-site guest --target-site guest \
                            --verbose > report.txt
```

---

## Output

### Screen
A summary is printed after all tests have run:

```
═════════════════════════════════════════════════════════════════
  VALIDATION SUMMARY
═════════════════════════════════════════════════════════════════

  [ WIKI ]
    ✓  WikiNode – Total count
    ✓  WikiNode – Identifiers
    ✗  WikiPage – Content checksum for head pages

  [ SEGMENTS ]
    ✓  SegmentsEntry – Total count
    ✓  SegmentsEntry – Identifiers
    ✓  SegmentsEntry – Criteria checksum

  ✗ 1 of 7 checks failed.
```

### Log file
Full output is written to `logs/compare_YYYYMMDD_HHMMSS.log`. For failing checks the log contains:
- Full source query result
- Full target query result
- Column headers followed by the diff

---

## SQL placeholders

Tests use two placeholders in SQL that `check()` substitutes automatically:

| Placeholder | Replaced with |
|---|---|
| `__GROUPID__` | Resolved `groupId` for the compared site |
| `__COMPANYID__` | Resolved `companyId` for the compared company |

---

## Modules

Each test covers one entity type across all validation layers:

| Layer | What is checked |
|---|---|
| Counts | Row counts per status, type, or category |
| Identifiers | Stable  anchors per entity |
| Names & descriptions | Human-readable fields |
| Core fields | Type, status, key configuration fields |
| Content integrity | MD5 checksums on large content fields |
| Relationships | Associations, mappings, hierarchy |
| Dates | `createDate`, `modifiedDate`, etc. |

---

## Adding a new test

1. Create `tests/<name>.sh`.
2. Define a function `test_<name>()` inside it.
3. Use `section`, `check`, `warn` helpers — they are sourced automatically from `compare.sh`.
4. Use `__GROUPID__` and `__COMPANYID__` as placeholders in SQL.
5. Filter `ctCollectionId = 0` on every table to exclude Publications drafts.

Example skeleton:

```bash
test_example() {
    section "EXAMPLE"

    check "ExampleTable – Total count" "
        SELECT COUNT(*) AS total
        FROM ExampleTable
        WHERE groupId        = __GROUPID__
          AND ctCollectionId = 0;
    "

    check "ExampleTable – Core fields" "
        SELECT
            exampleKey,
            name,
            status
        FROM ExampleTable
        WHERE groupId        = __GROUPID__
          AND ctCollectionId = 0
        ORDER BY exampleKey;
    "
}
```

The test is auto-discovered on the next run — no registration needed.

---

## Notes

- **Partition-aware**: Queries filter on `groupId` which is typically the partition key in Liferay databases, so MySQL/MariaDB partition pruning applies automatically.
- **NULL vs empty**: The diff engine normalizes `NULL` and empty string as equivalent, since Liferay can import empty values as `NULL`.
- **Version numbers**: Version columns are intentionally excluded from comparisons — Liferay resets version numbers to `1` on import while preserving the actual content.
- **Generated IDs**: No raw generated IDs (`*Id` columns) are compared across environments. All checks use stable natural keys (`uuid_`, `*Key`, `friendlyURL`, etc.) or resolve IDs to their natural key equivalents.
- **Publications**: All queries filter `ctCollectionId = 0` to exclude rows belonging to unpublished Publications drafts.
