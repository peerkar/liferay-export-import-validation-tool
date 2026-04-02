# =============================================================================
# Test: PAGES
# Tables: Layout, LayoutPageTemplateEntry, LayoutPageTemplateCollection,
#         LayoutPageTemplateStructure, LayoutPageTemplateStructureRel,
#         ClassName_
# =============================================================================
#
# LayoutPageTemplateEntry type_ values:
#   0 = Page Template (Basic/Content page template)
#   1 = Display Page Template
#   2 = Master Page
#   3 = Utility Page
#
# Page structure note:
#   LayoutPageTemplateStructure has no data_ column. Page content is stored
#   in LayoutPageTemplateStructureRel.data_, linked via
#   layoutPageTemplateStructureId and scoped by segmentsExperienceId.
#
# =============================================================================

test_page() {
    section "PAGE"


    # =========================================================================
    # REGULAR SITE PAGES  (Layout)
    # =========================================================================

    check "Layout – Count by type and visibility" "
        SELECT
            type_,
            privateLayout,
            hidden_,
            COUNT(*)        AS total
        FROM Layout
        WHERE groupId        = __GROUPID__
          AND ctCollectionId = 0
          AND status         = 0
          AND system_        = 0
        GROUP BY type_, privateLayout, hidden_;
    "

    check "Layout – Identifiers" "
        SELECT
            externalReferenceCode,
            uuid_,
            friendlyURL
        FROM Layout
        WHERE groupId        = __GROUPID__
          AND ctCollectionId = 0
          AND status         = 0
          AND system_        = 0
        ORDER BY externalReferenceCode;
    "

    check "Layout – Names and titles" "
        SELECT
            externalReferenceCode,
            REGEXP_REPLACE(name,  '<[^>]+>', '') AS name_plain,
            REGEXP_REPLACE(title, '<[^>]+>', '') AS title_plain
        FROM Layout
        WHERE groupId        = __GROUPID__
          AND ctCollectionId = 0
          AND status         = 0
          AND system_        = 0
        ORDER BY externalReferenceCode;
    "

    check "Layout – Core fields" "
        SELECT
            externalReferenceCode,
            friendlyURL,
            type_,
            privateLayout,
            hidden_,
            priority,
            status
        FROM Layout
        WHERE groupId        = __GROUPID__
          AND ctCollectionId = 0
          AND status         = 0
          AND system_        = 0
        ORDER BY externalReferenceCode;
    "

    check "Layout – Page hierarchy" "
        SELECT
            l.externalReferenceCode,
            l.friendlyURL,
            COALESCE(p.friendlyURL, '(root)') AS parent_friendlyURL
        FROM Layout l
        LEFT JOIN Layout p
               ON p.plid           = l.parentPlid
              AND p.groupId        = l.groupId
              AND p.ctCollectionId = 0
        WHERE l.groupId        = __GROUPID__
          AND l.ctCollectionId = 0
          AND l.status         = 0
          AND l.system_        = 0
        ORDER BY l.externalReferenceCode;
    "

    check "Layout – Structure checksum (content pages)" "
        SELECT
            l.externalReferenceCode,
            MD5(lptsr.data_)     AS structure_hash,
            LENGTH(lptsr.data_)  AS structure_length
        FROM Layout l
        JOIN LayoutPageTemplateStructure lpts
          ON lpts.plid           = l.plid
         AND lpts.ctCollectionId = 0
        JOIN LayoutPageTemplateStructureRel lptsr
          ON lptsr.layoutPageTemplateStructureId = lpts.layoutPageTemplateStructureId
         AND lptsr.ctCollectionId = 0
        WHERE l.groupId        = __GROUPID__
          AND l.ctCollectionId = 0
          AND l.status         = 0
          AND l.system_        = 0
          AND l.type_          = 'content'
        ORDER BY l.externalReferenceCode;
    "

    check "Layout – Dates" "
        SELECT
            externalReferenceCode,
            createDate,
            modifiedDate,
            publishDate
        FROM Layout
        WHERE groupId        = __GROUPID__
          AND ctCollectionId = 0
          AND status         = 0
          AND system_        = 0
        ORDER BY externalReferenceCode;
    "


    # =========================================================================
    # MASTER PAGES  (LayoutPageTemplateEntry type_ = 2)
    # =========================================================================

    check "Master Pages – Count" "
        SELECT
            COUNT(*)        AS total_master_pages
        FROM LayoutPageTemplateEntry
        WHERE groupId        = __GROUPID__
          AND ctCollectionId = 0
          AND type_          = 2;
    "

    check "Master Pages – Identifiers" "
        SELECT
            externalReferenceCode,
            uuid_,
            layoutPageTemplateEntryKey
        FROM LayoutPageTemplateEntry
        WHERE groupId        = __GROUPID__
          AND ctCollectionId = 0
          AND type_          = 2
        ORDER BY externalReferenceCode;
    "

    check "Master Pages – Names" "
        SELECT
            externalReferenceCode,
            name
        FROM LayoutPageTemplateEntry
        WHERE groupId        = __GROUPID__
          AND ctCollectionId = 0
          AND type_          = 2
        ORDER BY externalReferenceCode;
    "

    check "Master Pages – Core fields" "
        SELECT
            externalReferenceCode,
            name,
            status
        FROM LayoutPageTemplateEntry
        WHERE groupId        = __GROUPID__
          AND ctCollectionId = 0
          AND type_          = 2
        ORDER BY externalReferenceCode;
    "

    check "Master Pages – Structure checksum" "
        SELECT
            lpte.externalReferenceCode,
            MD5(lptsr.data_)     AS structure_hash,
            LENGTH(lptsr.data_)  AS structure_length
        FROM LayoutPageTemplateEntry lpte
        JOIN LayoutPageTemplateStructure lpts
          ON lpts.plid           = lpte.plid
         AND lpts.ctCollectionId = 0
        JOIN LayoutPageTemplateStructureRel lptsr
          ON lptsr.layoutPageTemplateStructureId = lpts.layoutPageTemplateStructureId
         AND lptsr.ctCollectionId = 0
        WHERE lpte.groupId        = __GROUPID__
          AND lpte.ctCollectionId = 0
          AND lpte.type_          = 2
        ORDER BY lpte.externalReferenceCode;
    "

    check "Master Pages – Dates" "
        SELECT
            externalReferenceCode,
            createDate,
            modifiedDate
        FROM LayoutPageTemplateEntry
        WHERE groupId        = __GROUPID__
          AND ctCollectionId = 0
          AND type_          = 2
        ORDER BY externalReferenceCode;
    "


    # =========================================================================
    # PAGE TEMPLATES  (LayoutPageTemplateEntry type_ = 0)
    # =========================================================================

    check "Page Template Collections – Count" "
        SELECT
            COUNT(*)        AS total_collections
        FROM LayoutPageTemplateCollection
        WHERE groupId        = __GROUPID__
          AND ctCollectionId = 0;
    "

    check "Page Template Collections – Identifiers" "
        SELECT
            externalReferenceCode,
            uuid_,
            lptCollectionKey
        FROM LayoutPageTemplateCollection
        WHERE groupId        = __GROUPID__
          AND ctCollectionId = 0
        ORDER BY externalReferenceCode;
    "

    check "Page Template Collections – Names and descriptions" "
        SELECT
            externalReferenceCode,
            name,
            description
        FROM LayoutPageTemplateCollection
        WHERE groupId        = __GROUPID__
          AND ctCollectionId = 0
        ORDER BY externalReferenceCode;
    "

    check "Page Template Collections – Dates" "
        SELECT
            externalReferenceCode,
            createDate,
            modifiedDate
        FROM LayoutPageTemplateCollection
        WHERE groupId        = __GROUPID__
          AND ctCollectionId = 0
        ORDER BY externalReferenceCode;
    "

    check "Page Templates – Count per collection" "
        SELECT
            lptc.externalReferenceCode  AS collection_erc,
            COUNT(*)                    AS template_count
        FROM LayoutPageTemplateEntry lpte
        JOIN LayoutPageTemplateCollection lptc
          ON lptc.layoutPageTemplateCollectionId = lpte.layoutPageTemplateCollectionId
         AND lptc.ctCollectionId = 0
        WHERE lpte.groupId        = __GROUPID__
          AND lpte.ctCollectionId = 0
          AND lpte.type_          = 0
        GROUP BY lptc.externalReferenceCode
        ORDER BY lptc.externalReferenceCode;
    "

    check "Page Templates – Identifiers" "
        SELECT
            externalReferenceCode,
            uuid_,
            layoutPageTemplateEntryKey
        FROM LayoutPageTemplateEntry
        WHERE groupId        = __GROUPID__
          AND ctCollectionId = 0
          AND type_          = 0
        ORDER BY externalReferenceCode;
    "

    check "Page Templates – Names" "
        SELECT
            externalReferenceCode,
            name
        FROM LayoutPageTemplateEntry
        WHERE groupId        = __GROUPID__
          AND ctCollectionId = 0
          AND type_          = 0
        ORDER BY externalReferenceCode;
    "

    check "Page Templates – Core fields" "
        SELECT
            lpte.externalReferenceCode,
            lpte.name,
            lptc.externalReferenceCode  AS collection_erc,
            lpte.status
        FROM LayoutPageTemplateEntry lpte
        LEFT JOIN LayoutPageTemplateCollection lptc
               ON lptc.layoutPageTemplateCollectionId = lpte.layoutPageTemplateCollectionId
              AND lptc.ctCollectionId = 0
        WHERE lpte.groupId        = __GROUPID__
          AND lpte.ctCollectionId = 0
          AND lpte.type_          = 0
        ORDER BY lpte.externalReferenceCode;
    "

    check "Page Templates – Structure checksum" "
        SELECT
            lpte.externalReferenceCode,
            MD5(lptsr.data_)     AS structure_hash,
            LENGTH(lptsr.data_)  AS structure_length
        FROM LayoutPageTemplateEntry lpte
        JOIN LayoutPageTemplateStructure lpts
          ON lpts.plid           = lpte.plid
         AND lpts.ctCollectionId = 0
        JOIN LayoutPageTemplateStructureRel lptsr
          ON lptsr.layoutPageTemplateStructureId = lpts.layoutPageTemplateStructureId
         AND lptsr.ctCollectionId = 0
        WHERE lpte.groupId        = __GROUPID__
          AND lpte.ctCollectionId = 0
          AND lpte.type_          = 0
        ORDER BY lpte.externalReferenceCode;
    "

    check "Page Templates – Dates" "
        SELECT
            externalReferenceCode,
            createDate,
            modifiedDate
        FROM LayoutPageTemplateEntry
        WHERE groupId        = __GROUPID__
          AND ctCollectionId = 0
          AND type_          = 0
        ORDER BY externalReferenceCode;
    "


    # =========================================================================
    # DISPLAY PAGE TEMPLATES  (LayoutPageTemplateEntry type_ = 1)
    # =========================================================================

    check "Display Page Templates – Count" "
        SELECT
            COUNT(*)        AS total
        FROM LayoutPageTemplateEntry
        WHERE groupId        = __GROUPID__
          AND ctCollectionId = 0
          AND type_          = 1;
    "

    check "Display Page Templates – Identifiers" "
        SELECT
            externalReferenceCode,
            uuid_,
            layoutPageTemplateEntryKey
        FROM LayoutPageTemplateEntry
        WHERE groupId        = __GROUPID__
          AND ctCollectionId = 0
          AND type_          = 1
        ORDER BY externalReferenceCode;
    "

    check "Display Page Templates – Names" "
        SELECT
            externalReferenceCode,
            name
        FROM LayoutPageTemplateEntry
        WHERE groupId        = __GROUPID__
          AND ctCollectionId = 0
          AND type_          = 1
        ORDER BY externalReferenceCode;
    "

    check "Display Page Templates – Core fields" "
        SELECT
            lpte.externalReferenceCode,
            lpte.name,
            lpte.defaultTemplate,
            lpte.status
        FROM LayoutPageTemplateEntry lpte
        WHERE lpte.groupId        = __GROUPID__
          AND lpte.ctCollectionId = 0
          AND lpte.type_          = 1
        ORDER BY lpte.externalReferenceCode;
    "

    check "Display Page Templates – Mapped asset type" "
        SELECT
            lpte.externalReferenceCode,
            cn.value         AS class_name,
            lpte.classTypeKey
        FROM LayoutPageTemplateEntry lpte
        LEFT JOIN ClassName_ cn
               ON cn.classNameId = lpte.classNameId
        WHERE lpte.groupId        = __GROUPID__
          AND lpte.ctCollectionId = 0
          AND lpte.type_          = 1
        ORDER BY lpte.externalReferenceCode;
    "

    check "Display Page Templates – Structure checksum" "
        SELECT
            lpte.externalReferenceCode,
            MD5(lptsr.data_)     AS structure_hash,
            LENGTH(lptsr.data_)  AS structure_length
        FROM LayoutPageTemplateEntry lpte
        JOIN LayoutPageTemplateStructure lpts
          ON lpts.plid           = lpte.plid
         AND lpts.ctCollectionId = 0
        JOIN LayoutPageTemplateStructureRel lptsr
          ON lptsr.layoutPageTemplateStructureId = lpts.layoutPageTemplateStructureId
         AND lptsr.ctCollectionId = 0
        WHERE lpte.groupId        = __GROUPID__
          AND lpte.ctCollectionId = 0
          AND lpte.type_          = 1
        ORDER BY lpte.externalReferenceCode;
    "

    check "Display Page Templates – Dates" "
        SELECT
            externalReferenceCode,
            createDate,
            modifiedDate
        FROM LayoutPageTemplateEntry
        WHERE groupId        = __GROUPID__
          AND ctCollectionId = 0
          AND type_          = 1
        ORDER BY externalReferenceCode;
    "


    # =========================================================================
    # UTILITY PAGES  (LayoutPageTemplateEntry type_ = 3)
    # =========================================================================

    check "Utility Pages – Count" "
        SELECT
            COUNT(*)        AS total
        FROM LayoutPageTemplateEntry
        WHERE groupId        = __GROUPID__
          AND ctCollectionId = 0
          AND type_          = 3;
    "

    check "Utility Pages – Identifiers" "
        SELECT
            externalReferenceCode,
            uuid_,
            layoutPageTemplateEntryKey
        FROM LayoutPageTemplateEntry
        WHERE groupId        = __GROUPID__
          AND ctCollectionId = 0
          AND type_          = 3
        ORDER BY externalReferenceCode;
    "

    check "Utility Pages – Core fields" "
        SELECT
            externalReferenceCode,
            name,
            defaultTemplate,
            status
        FROM LayoutPageTemplateEntry
        WHERE groupId        = __GROUPID__
          AND ctCollectionId = 0
          AND type_          = 3
        ORDER BY externalReferenceCode;
    "

    check "Utility Pages – Structure checksum" "
        SELECT
            lpte.externalReferenceCode,
            MD5(lptsr.data_)     AS structure_hash,
            LENGTH(lptsr.data_)  AS structure_length
        FROM LayoutPageTemplateEntry lpte
        JOIN LayoutPageTemplateStructure lpts
          ON lpts.plid           = lpte.plid
         AND lpts.ctCollectionId = 0
        JOIN LayoutPageTemplateStructureRel lptsr
          ON lptsr.layoutPageTemplateStructureId = lpts.layoutPageTemplateStructureId
         AND lptsr.ctCollectionId = 0
        WHERE lpte.groupId        = __GROUPID__
          AND lpte.ctCollectionId = 0
          AND lpte.type_          = 3
        ORDER BY lpte.externalReferenceCode;
    "

    check "Utility Pages – Dates" "
        SELECT
            externalReferenceCode,
            createDate,
            modifiedDate
        FROM LayoutPageTemplateEntry
        WHERE groupId        = __GROUPID__
          AND ctCollectionId = 0
          AND type_          = 3
        ORDER BY externalReferenceCode;
    "
}
