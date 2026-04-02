#!/usr/bin/env bash
# =============================================================================
# Liferay Export/Import – Validation Script  (entry point)
# =============================================================================
#
# USAGE:
#   ./compare.sh [--source-company-web-id <webId>] --source-site <site_key> \
#                   [--target-company-web-id <webId>] --target-site <site_key> \
#                   [--tests m1,m2,...] [--verbose]
#
# EXAMPLES:
#   # Default liferay.com company, different sites
#   ./compare.sh --source-site Guest --target-site new-site
# 
#   # Same company, different sites
#   ./compare.sh --source-company liferay.com --source-site Guest \
#                   --target-company liferay.com --target-site new-site
#
#   # Different companies (multitenant)
#   ./compare.sh --source-company-web-id tenant-a.com --source-site Guest \
#                   --target-company-web-id tenant-b.com --target-site new-site
#
#   # Specific tests only
#   ./compare.sh --source-company liferay.com --source-site Guest \
#                   --target-company liferay.com --target-site new-site \
#                   --tests wiki,segments
#
#   # Save verbose output for audit
#   VERBOSE=1 NO_COLOR=1 ./compare.sh ... > report.txt
#
# OUTPUT:
#   Screen : summary only
#   Log    : full check output written to logs/compare_<timestamp>.log
#
# SQL placeholders available in tests:
#   __GROUPID__    → resolved groupId for the compared site
#   __COMPANYID__  → resolved companyId for the compared company
#
# CONFIG:
#   Copy config/db.conf.example → config/db.conf and fill in credentials.
#   db.conf is gitignored and never committed.
#
# EXTENDING:
#   Drop a new file  tests/<name>.sh  that defines  test_<name>().
#   It is auto-discovered – no registration needed.
#
# =============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
TESTS_DIR="${TESTS_DIR:-$SCRIPT_DIR/tests}"
CONFIG_FILE="${CONFIG_FILE:-$SCRIPT_DIR/config/db.conf}"
LOG_DIR="${LOG_DIR:-$SCRIPT_DIR/logs}"
NO_COLOR="${NO_COLOR:-}"
VERBOSE="${VERBOSE:-}"        # Can also be set via --verbose flag

# -----------------------------------------------------------------------------
# LOG FILE SETUP
# -----------------------------------------------------------------------------
mkdir -p "$LOG_DIR"
LOG_FILE="$LOG_DIR/compare_$(date '+%Y%m%d_%H%M%S').log"

_log()  { printf '%s\n' "$*" >> "$LOG_FILE"; }

# -----------------------------------------------------------------------------
# RESULT TRACKING  –  entries are stored as "test|STATUS|label"
# -----------------------------------------------------------------------------
declare -a CHECK_LOG=()
CURRENT_TEST=""

# -----------------------------------------------------------------------------
# LOAD CREDENTIALS
# -----------------------------------------------------------------------------
if [[ ! -f "$CONFIG_FILE" ]]; then
    echo "[ERROR] Config file not found: $CONFIG_FILE"
    echo "        Copy config/db.conf.example to config/db.conf and fill in your credentials."
    exit 1
fi
# shellcheck source=/dev/null
source "$CONFIG_FILE"

# Expected variables after sourcing db.conf:
#   SRC_DB_HOST  SRC_DB_PORT  SRC_DB_NAME  SRC_DB_USER  SRC_DB_PASS
#   TGT_DB_HOST  TGT_DB_PORT  TGT_DB_NAME  TGT_DB_USER  TGT_DB_PASS

# -----------------------------------------------------------------------------
# PARSE ARGUMENTS
#   --source-company-web-id <webId>   Source company webId. Optional, defaults to liferay.com
#   --source-site <site_key>          Source site key       (required)
#   --target-company-web-id <webId>   Target company webId. Optional, defaults to liferay.com
#   --target-site <site_key>          Target site key       (required)
#   --tests <m1,m2,...>      Comma-separated list of tests (optional)
# -----------------------------------------------------------------------------
SRC_COMPANY=""
SRC_SITE=""
TGT_COMPANY=""
TGT_SITE=""
TESTS_ARG=()

while [[ $# -gt 0 ]]; do
    case "$1" in
        --source-company-web-id) SRC_COMPANY="$2";                        shift 2 ;;
        --source-site)           SRC_SITE="$2";                           shift 2 ;;
        --target-company-web-id) TGT_COMPANY="$2";                        shift 2 ;;
        --target-site)           TGT_SITE="$2";                           shift 2 ;;
        --tests)        IFS=',' read -ra TESTS_ARG <<< "$2";   shift 2 ;;
        *) echo "Unknown argument: $1"; exit 1 ;;
    esac
done

if [[ -z "$SRC_SITE" || -z "$TGT_SITE" ]]; then
    echo "Usage: ./compare.sh [--source-company-web-id <webId>] --source-site <site_key>"
    echo "                       [--target-company-web-id <webId>] --target-site <site_key>"
    echo "                       [--tests m1,m2,...] [--verbose]"
    exit 1
fi

# -----------------------------------------------------------------------------
# DB HELPERS
# -----------------------------------------------------------------------------
_db() {                          # _db <host> <port> <user> <pass> <name> <sql>
    local host="$1" port="$2" user="$3" pass="$4" name="$5" sql="$6"
    local args=(-h "$host" -P "$port" -u "$user" --database="$name")
    [[ -n "$pass" ]] && args+=(-p"$pass")
    mysql "${args[@]}" --table -e "$sql"
}

_db_raw() {                      # Like _db but returns bare values (no table formatting)
    local host="$1" port="$2" user="$3" pass="$4" name="$5" sql="$6"
    local args=(-h "$host" -P "$port" -u "$user" --database="$name"
                --skip-column-names --silent)
    [[ -n "$pass" ]] && args+=(-p"$pass")
    mysql "${args[@]}" -e "$sql" 2>/dev/null
}

_db_src()  { _db     "$SRC_DB_HOST" "$SRC_DB_PORT" "$SRC_DB_USER" "$SRC_DB_PASS" "$SRC_DB_NAME" "$1"; }
_db_tgt()  { _db     "$TGT_DB_HOST" "$TGT_DB_PORT" "$TGT_DB_USER" "$TGT_DB_PASS" "$TGT_DB_NAME" "$1"; }
_raw_src() { _db_raw "$SRC_DB_HOST" "$SRC_DB_PORT" "$SRC_DB_USER" "$SRC_DB_PASS" "$SRC_DB_NAME" "$1"; }
_raw_tgt() { _db_raw "$TGT_DB_HOST" "$TGT_DB_PORT" "$TGT_DB_USER" "$TGT_DB_PASS" "$TGT_DB_NAME" "$1"; }

# -----------------------------------------------------------------------------
# RESOLVE COMPANY webId → companyId
# -----------------------------------------------------------------------------
resolve_company_id() {           # resolve_company_id <raw_fn> <webId>
    local raw_fn="$1" web_id="$2"

    if [[ -z "$web_id" ]]; then
        web_id="liferay.com"
    fi

    local cid
    cid=$($raw_fn "SELECT companyId FROM Company
                   WHERE webId = '$web_id' LIMIT 1;")
    if [[ -z "$cid" ]]; then
        echo "[ERROR] Company not found: \"$web_id\"" >&2
        exit 1
    fi
    echo "$cid"
}

# -----------------------------------------------------------------------------
# RESOLVE SITE groupKey → groupId  (scoped to company)
# -----------------------------------------------------------------------------
resolve_group_id() {             # resolve_group_id <raw_fn> <site_key> <companyId>
    local raw_fn="$1" site_key="$2" company_id="$3"
    local gid
    gid=$($raw_fn "SELECT groupId FROM Group_
                   WHERE groupKey  = '$site_key'
                     AND companyId = '$company_id'
                     AND site      = 1
                   LIMIT 1;")
    if [[ -z "$gid" ]]; then
        echo "[ERROR] Site not found: \"$site_key\" in company \"$company_id\"" >&2
        exit 1
    fi
    echo "$gid"
}

SRC_COMPANY_ID=$(resolve_company_id _raw_src "$SRC_COMPANY")
TGT_COMPANY_ID=$(resolve_company_id _raw_tgt "$TGT_COMPANY")
SRC_GROUP_ID=$(resolve_group_id _raw_src "$SRC_SITE" "$SRC_COMPANY_ID")
TGT_GROUP_ID=$(resolve_group_id _raw_tgt "$TGT_SITE" "$TGT_COMPANY_ID")

# -----------------------------------------------------------------------------
# ANSI COLORS  (screen only)
# -----------------------------------------------------------------------------
_color() { [[ -z "$NO_COLOR" ]] && printf '%b' "$1" || true; }

C0=$'\033[0m'
CGREEN=$'\033[1;32m'
CYELLOW=$'\033[1;33m'
CGRAY=$'\033[0;37m'
CRED=$'\033[1;31m'

# -----------------------------------------------------------------------------
# TEST HELPERS  –  available to all tests via sourcing
# All detail output goes to the log file; only summary goes to the screen.
# -----------------------------------------------------------------------------
section() {                      # section "TEST NAME"
    _log ""
    _log ""
    _log "$(printf '═%.0s' {1..65})"
    _log "  TEST: $1"
    _log "$(printf '═%.0s' {1..65})"
}

# _norm_for_diff: normalizes MySQL --table output for stable comparison.
# - Removes border lines (+---+)
# - Treats NULL and empty string as equal
# - Strips cell padding so column width differences don't cause false diffs
_norm_for_diff() {
    sed '/^+/d' |
    sed 's/| NULL[[:space:]]*/|/g' |
    sed 's/|[[:space:]]*/|/g' |
    sed 's/[[:space:]]*|/|/g'
}

# check "Label" "SQL with __GROUPID__ and/or __COMPANYID__ placeholders"
# Substitutes both SRC/TGT values, runs against both DBs, diffs, logs result.
check() {
    local label="$1" sql_tpl="$2"
    local src_sql tgt_sql
    src_sql="${sql_tpl//__GROUPID__/$SRC_GROUP_ID}"
    src_sql="${src_sql//__COMPANYID__/$SRC_COMPANY_ID}"
    tgt_sql="${sql_tpl//__GROUPID__/$TGT_GROUP_ID}"
    tgt_sql="${tgt_sql//__COMPANYID__/$TGT_COMPANY_ID}"

    local src_file tgt_file src_err_file tgt_err_file diff_file src_norm tgt_norm
    src_file=$(mktemp);     tgt_file=$(mktemp)
    src_err_file=$(mktemp); tgt_err_file=$(mktemp)
    diff_file=$(mktemp);    src_norm=$(mktemp); tgt_norm=$(mktemp)

    _db_src "$src_sql" > "$src_file" 2>"$src_err_file" || true
    _db_tgt "$tgt_sql" > "$tgt_file" 2>"$tgt_err_file" || true

    local src_err tgt_err
    src_err=$(grep -i '^ERROR' "$src_err_file" || true)
    tgt_err=$(grep -i '^ERROR' "$tgt_err_file" || true)
    rm -f "$src_err_file" "$tgt_err_file"

    if [[ -n "$src_err" || -n "$tgt_err" ]]; then
        _log ""
        _log "  ✖ ERROR  $label"
        _log "  $(printf '─%.0s' {1..62})"
        [[ -n "$src_err" ]] && _log "  ◈ SOURCE ERROR: $src_err"
        [[ -n "$tgt_err" ]] && _log "  ◈ TARGET ERROR: $tgt_err"
        rm -f "$src_file" "$tgt_file" "$diff_file" "$src_norm" "$tgt_norm"
        CHECK_LOG+=("${CURRENT_TEST}|ERROR|${label}")
        return
    fi

    _norm_for_diff < "$src_file" > "$src_norm"
    _norm_for_diff < "$tgt_file" > "$tgt_norm"
    diff "$src_norm" "$tgt_norm" > "$diff_file" || true
    rm -f "$src_norm" "$tgt_norm"

    local status
    if [[ ! -s "$diff_file" ]]; then
        status="PASS"
        _log ""
        _log "  ✓ MATCH  $label"
    else
        status="FAIL"
        _log ""
        _log "  ✗ DIFF   $label"
    fi
    _log "  $(printf '─%.0s' {1..62})"

    if [[ -n "$VERBOSE" || "$status" == "FAIL" ]]; then
        _log "  ◈ SOURCE  ($SRC_COMPANY / $SRC_SITE · groupId=$SRC_GROUP_ID)"
        sed 's/^/    /' "$src_file" >> "$LOG_FILE"
        _log "  ◈ TARGET  ($TGT_COMPANY / $TGT_SITE · groupId=$TGT_GROUP_ID)"
        sed 's/^/    /' "$tgt_file" >> "$LOG_FILE"
    fi

    if [[ -s "$diff_file" ]]; then
        _log ""
        _log "  ⚡ DIFFERENCES:"
        head -3 "$src_file" | sed 's/^/    /' >> "$LOG_FILE"
        local h1 h2 h3
        h1=$(sed -n '1p' "$src_file")
        h2=$(sed -n '2p' "$src_file")
        h3=$(sed -n '3p' "$src_file")
        awk -v h1="$h1" -v h2="$h2" -v h3="$h3" '
            { c = substr($0, 3)
              if (c == h1 || c == h2 || c == h3) next
              print "    " $0 }
        ' "$diff_file" >> "$LOG_FILE"
    fi

    rm -f "$src_file" "$tgt_file" "$diff_file"
    CHECK_LOG+=("${CURRENT_TEST}|${status}|${label}")
}

warn() {
    _color "$CRED"; printf '  [WARN] %s\n' "$1"; _color "$C0"
}

# -----------------------------------------------------------------------------
# SUMMARY  (screen only)
# -----------------------------------------------------------------------------
print_summary() {
    local passed=0 failed=0 prev_test=""

    echo ""
    echo ""
    _color "$CYELLOW"
    printf '═%.0s' {1..65}; echo ""
    printf "  VALIDATION SUMMARY\n"
    printf '═%.0s' {1..65}; echo ""
    _color "$C0"

    for entry in "${CHECK_LOG[@]}"; do
        IFS='|' read -r mod status label <<< "$entry"

        if [[ "$mod" != "$prev_test" ]]; then
            echo ""
            _color "$CYELLOW"; printf '  [ %s ]\n' "${mod^^}"; _color "$C0"
            prev_test="$mod"
        fi

        if [[ "$status" == "PASS" ]]; then
            _color "$CGREEN";  printf '    ✓  %s\n' "$label"; _color "$C0"
            ((passed++)) || true
        elif [[ "$status" == "FAIL" ]]; then
            _color "$CRED";    printf '    ✗  %s\n' "$label"; _color "$C0"
            ((failed++)) || true
        else
            _color "$CYELLOW"; printf '    ✖  %s\n' "$label"; _color "$C0"
            ((failed++)) || true
        fi
    done

    local total=$(( passed + failed ))
    echo ""
    _color "$CGRAY"; printf '  '; printf '─%.0s' {1..62}; echo ""; _color "$C0"
    if [[ $failed -eq 0 ]]; then
        _color "$CGREEN"; printf '  ✓ All %d checks passed.\n' "$total"; _color "$C0"
    else
        _color "$CRED";   printf '  ✗ %d of %d checks failed.\n' "$failed" "$total"; _color "$C0"
    fi
    echo ""
}

# -----------------------------------------------------------------------------
# TEST LOADER
# -----------------------------------------------------------------------------
load_tests() {
    if [[ ! -d "$TESTS_DIR" ]]; then
        warn "Tests directory not found: $TESTS_DIR"; return
    fi
    for file in "$TESTS_DIR"/*.sh; do
        [[ -f "$file" ]] || continue
        # shellcheck source=/dev/null
        source "$file"
    done
}

# -----------------------------------------------------------------------------
# MAIN
# -----------------------------------------------------------------------------
main() {
    load_tests

    local to_run=()
    if [[ ${#TESTS_ARG[@]} -gt 0 ]]; then
        to_run=("${TESTS_ARG[@]}")
    else
        while IFS= read -r fn; do
            to_run+=("${fn#test_}")
        done < <(declare -F | awk '{print $3}' | grep '^test_')
    fi

    if [[ ${#to_run[@]} -eq 0 ]]; then
        warn "No tests found in $TESTS_DIR. Nothing to run."; exit 1
    fi

    # Write run header to log
    _log "$(printf '═%.0s' {1..65})"
    _log "  LIFERAY EXPORT/IMPORT VALIDATION"
    _log "$(printf '═%.0s' {1..65})"
    _log "  Source  : $SRC_DB_NAME  ($SRC_COMPANY / $SRC_SITE  groupId=$SRC_GROUP_ID  companyId=$SRC_COMPANY_ID)"
    _log "  Target  : $TGT_DB_NAME  ($TGT_COMPANY / $TGT_SITE  groupId=$TGT_GROUP_ID  companyId=$TGT_COMPANY_ID)"
    _log "  Tests : ${to_run[*]}"
    _log "  Started : $(date '+%Y-%m-%d %H:%M:%S')"

    # Print brief header to screen
    echo ""
    _color "$CGREEN"
    printf '═%.0s' {1..65}; echo ""
    printf "  LIFERAY EXPORT/IMPORT VALIDATION\n"
    printf '═%.0s' {1..65}; echo ""
    _color "$C0"
    printf '  Source  : %s  (%s / %s  groupId=%s  companyId=%s)\n' \
        "$SRC_DB_NAME" "$SRC_COMPANY" "$SRC_SITE" "$SRC_GROUP_ID" "$SRC_COMPANY_ID"
    printf '  Target  : %s  (%s / %s  groupId=%s  companyId=%s)\n' \
        "$TGT_DB_NAME" "$TGT_COMPANY" "$TGT_SITE" "$TGT_GROUP_ID" "$TGT_COMPANY_ID"
    printf '  Tests : %s\n' "${to_run[*]}"
    printf '  Started : %s\n' "$(date '+%Y-%m-%d %H:%M:%S')"
    printf '  Log     : %s\n' "$LOG_FILE"

    for test in "${to_run[@]}"; do
        if declare -f "test_${test}" > /dev/null 2>&1; then
            CURRENT_TEST="$test"
            "test_${test}"
        else
            warn "Test \"${test}\" not found – skipping."
        fi
    done

    print_summary

    _log ""
    _log "  Finished : $(date '+%Y-%m-%d %H:%M:%S')"

    _color "$CGREEN"
    printf '  Log     : %s\n' "$LOG_FILE"
    printf '═%.0s' {1..65}; echo ""
    _color "$C0"
    echo ""
}

main