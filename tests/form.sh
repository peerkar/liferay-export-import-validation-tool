# =============================================================================
# Test: FORMS
# Tables: DDMFormInstance, DDMFormInstanceVersion,
#         DDMFormInstanceRecord, DDMFormInstanceRecordVersion,
#         DDMStructure, DDMStructureVersion
# =============================================================================

test_form() {
    section "FORM"

    # =========================================================================
    # DDMFormInstance
    # =========================================================================

    check "DDMFormInstance – Total count" "
        SELECT
            COUNT(*)        AS total
        FROM DDMFormInstance
        WHERE groupId = __GROUPID__
          AND ctCollectionId = 0;
    "

    check "DDMFormInstance – Identifiers" "
        SELECT
            REGEXP_REPLACE(name, '<[^>]+>', '') AS form_name,
            uuid_
        FROM DDMFormInstance
        WHERE groupId = __GROUPID__
          AND ctCollectionId = 0        
        ORDER BY form_name;
    "

   check "DDMFormInstance – Name and description" "
        SELECT
            REGEXP_REPLACE(name,        '<[^>]+>', '') AS name_plain,
            REGEXP_REPLACE(description, '<[^>]+>', '') AS description_plain
        FROM DDMFormInstance
        WHERE groupId = __GROUPID__
            AND ctCollectionId = 0
        ORDER BY name_plain;
    "

    check "DDMFormInstance – Settings checksum" "
        SELECT
            REGEXP_REPLACE(name, '<[^>]+>', '') AS name_plain,
            MD5(settings_)      AS settings_hash,
            LENGTH(settings_)   AS settings_length
        FROM DDMFormInstance
        WHERE groupId = __GROUPID__
          AND ctCollectionId = 0       
        ORDER BY name_plain;
    "

    check "DDMFormInstance – Dates" "
        SELECT
            uuid_,
            REGEXP_REPLACE(name, '<[^>]+>', '') AS name_plain,
            createDate,
            modifiedDate
        FROM DDMFormInstance
        WHERE groupId = __GROUPID__
          AND ctCollectionId = 0
        ORDER BY name_plain;
    "

    check "DDMFormInstance – Linked structure" "
        SELECT
            REGEXP_REPLACE(fi.name, '<[^>]+>', '') AS form_name,
            ds.structureKey
        FROM DDMFormInstance fi
        JOIN DDMStructure ds
          ON ds.structureId = fi.structureId
        WHERE fi.groupId = __GROUPID__
          AND fi.ctCollectionId = 0       
        ORDER BY form_name;
    "

    # =========================================================================
    # DDMFormInstanceRecord
    # =========================================================================

    check "DDMFormInstanceRecord – Total count" "
        SELECT
            COUNT(*)        AS total
        FROM DDMFormInstanceRecord
        WHERE groupId = __GROUPID__
          AND ctCollectionId = 0;
    "

    check "DDMFormInstanceRecord – Count per form" "
        SELECT
            fi.uuid_        AS form_uuid,
            REGEXP_REPLACE(fi.name, '<[^>]+>', '') AS form_name,
            COUNT(*)        AS record_count
        FROM DDMFormInstance fi
        JOIN DDMFormInstanceRecord rec
          ON rec.formInstanceId = fi.formInstanceId
        WHERE fi.groupId = __GROUPID__
          AND fi.ctCollectionId = 0        
        GROUP BY fi.uuid_, form_name
        ORDER BY fi.uuid_;
    "

    check "DDMFormInstanceRecord – Dates" "
        SELECT
            uuid_,
            createDate,
            modifiedDate
        FROM DDMFormInstanceRecord
        WHERE groupId = __GROUPID__
          AND ctCollectionId = 0
        ORDER BY uuid_;
    "

    check "DDMFormInstanceRecord – Audit fields" "
        SELECT
            uuid_,
            ipaddress
        FROM DDMFormInstanceRecord
        WHERE groupId = __GROUPID__
          AND ctCollectionId = 0
        ORDER BY uuid_;
    "

    # =========================================================================
    # DDMFormInstanceRecordVersion
    # =========================================================================

    check "DDMFormInstanceRecordVersion – Total count" "
        SELECT
            COUNT(*)        AS total
        FROM DDMFormInstanceRecordVersion
        WHERE groupId = __GROUPID__
          AND ctCollectionId = 0;
    "

    check "DDMFormInstanceRecordVersion – Record version count per form" "
        SELECT
            fi.uuid_            AS form_uuid,
            REGEXP_REPLACE(fi.name, '<[^>]+>', '') AS form_name,
            COUNT(*)            AS record_version_count
        FROM DDMFormInstance fi
        JOIN DDMFormInstanceRecord rec
          ON rec.formInstanceId = fi.formInstanceId
        JOIN DDMFormInstanceRecordVersion rv
          ON rv.formInstanceRecordId = rec.formInstanceRecordId
        WHERE fi.groupId = __GROUPID__
          AND fi.ctCollectionId = 0
        GROUP BY fi.uuid_, form_name
        ORDER BY form_name;
    "

    check "DDMFormInstanceRecordVersion – Latest version status per record" "
        SELECT
            fi.uuid_            AS form_uuid,
            REGEXP_REPLACE(fi.name, '<[^>]+>', '') AS form_name,
            rec.uuid_           AS record_uuid,
            rv.status
        FROM DDMFormInstance fi
        JOIN DDMFormInstanceRecord rec
          ON rec.formInstanceId = fi.formInstanceId
        JOIN DDMFormInstanceRecordVersion rv
          ON rv.formInstanceRecordId = rec.formInstanceRecordId
         AND rv.version = (
             SELECT MAX(rv2.version)
             FROM DDMFormInstanceRecordVersion rv2
             WHERE rv2.formInstanceRecordId = rec.formInstanceRecordId
         )
        WHERE fi.groupId = __GROUPID__
          AND fi.ctCollectionId = 0
        ORDER BY form_name, rec.uuid_;
    "

    check "DDMFormInstanceRecordVersion – Dates" "
        SELECT
            uuid_,
            createDate
        FROM DDMFormInstanceRecord
        WHERE groupId = __GROUPID__
          AND ctCollectionId = 0
        ORDER BY uuid_;
    "

    # =========================================================================
    # DDMFormInstanceReport
    # =========================================================================

    check "DDMFormInstanceReport – Total count" "
        SELECT
            COUNT(*)        AS total
        FROM DDMFormInstanceReport
        WHERE groupId = __GROUPID__
          AND ctCollectionId = 0;
    "

    check "DDMFormInstanceReport – Report count per form" "
        SELECT
            fi.uuid_            AS form_uuid,
            REGEXP_REPLACE(fi.name, '<[^>]+>', '') AS form_name,
            COUNT(*)            AS report_count
        FROM DDMFormInstance fi
        JOIN DDMFormInstanceReport rpt
          ON rpt.formInstanceId = fi.formInstanceId
        WHERE fi.groupId = __GROUPID__
          AND fi.ctCollectionId = 0
        GROUP BY fi.uuid_, form_name
        ORDER BY form_uuid, form_name;
    "

    check "DDMFormInstanceReport – Data checksum per form" "
        SELECT
            fi.uuid_            AS form_uuid,
            REGEXP_REPLACE(fi.name, '<[^>]+>', '') AS form_name,
            LENGTH(rpt.data_)   AS data_length
        FROM DDMFormInstance fi
        JOIN DDMFormInstanceReport rpt
          ON rpt.formInstanceId = fi.formInstanceId
        WHERE fi.groupId = __GROUPID__
          AND fi.ctCollectionId = 0
        ORDER BY form_uuid, form_name;
    "

    check "DDMFormInstanceReport – Dates" "
        SELECT
            createDate,
            modifiedDate
        FROM DDMFormInstanceReport
        WHERE groupId = __GROUPID__
          AND ctCollectionId = 0
        ORDER BY createDate;
    "

    # =========================================================================
    # DDMFormInstanceVersion
    # =========================================================================


    check "DDMFormInstanceVersion – Latest version core fields" "
        SELECT
            fi.uuid_            AS form_uuid,
            REGEXP_REPLACE(fi.name, '<[^>]+>', '') AS form_name,
            fiv.status
        FROM DDMFormInstance fi
        JOIN DDMFormInstanceVersion fiv
          ON fiv.formInstanceId = fi.formInstanceId
         AND fiv.version = (
             SELECT MAX(fiv2.version)
             FROM DDMFormInstanceVersion fiv2
             WHERE fiv2.formInstanceId = fi.formInstanceId
         )
        WHERE fi.groupId = __GROUPID__
          AND fi.ctCollectionId = 0
        ORDER BY form_name;
    "

    check "DDMFormInstanceVersion – Latest version settings checksum" "
        SELECT
            fi.uuid_            AS form_uuid,
            REGEXP_REPLACE(fi.name, '<[^>]+>', '') AS form_name,
            MD5(fiv.settings_)  AS settings_hash
        FROM DDMFormInstance fi
        JOIN DDMFormInstanceVersion fiv
          ON fiv.formInstanceId = fi.formInstanceId
         AND fiv.version = (
             SELECT MAX(fiv2.version)
             FROM DDMFormInstanceVersion fiv2
             WHERE fiv2.formInstanceId = fi.formInstanceId
         )
        WHERE fi.groupId = __GROUPID__
          AND fi.ctCollectionId = 0
        ORDER BY form_name;
    "

    # =========================================================================
    # DDMStructure
    # =========================================================================

    check "DDMStructure – UUIDs (form structures)" "
        SELECT
            structureKey,
            uuid_
        FROM DDMStructure
        WHERE groupId = __GROUPID__
          AND classNameId = (
              SELECT classNameId FROM ClassName_
              WHERE  value = 'com.liferay.dynamic.data.mapping.model.DDMFormInstance'
          )
          AND ctCollectionId = 0        
        ORDER BY structureKey;
    "

    check "DDMStructure – Name and description (form structures)" "
        SELECT
            structureKey,
            REGEXP_REPLACE(name,        '<[^>]+>', '') AS name_plain,
            REGEXP_REPLACE(description, '<[^>]+>', '') AS description_plain
        FROM DDMStructure
        WHERE groupId = __GROUPID__
          AND classNameId = (
              SELECT classNameId FROM ClassName_
              WHERE  value = 'com.liferay.dynamic.data.mapping.model.DDMFormInstance'
          )
          AND ctCollectionId = 0        
        ORDER BY structureKey;
    "

    check "DDMStructure – Structure Key and Storage Type" "
        SELECT
            structureKey,
            storageType
        FROM DDMStructure
        WHERE groupId = __GROUPID__
          AND classNameId = (
              SELECT classNameId FROM ClassName_
              WHERE  value = 'com.liferay.dynamic.data.mapping.model.DDMFormInstance'
          )
          AND ctCollectionId = 0        
        ORDER BY structureKey;
    "

    check "DDMStructure – Field definition checksum (form structures)" "
        SELECT
            structureKey,
            MD5(definition)     AS definition_hash,
            LENGTH(definition)  AS definition_length
        FROM DDMStructure
        WHERE groupId = __GROUPID__
          AND classNameId = (
              SELECT classNameId FROM ClassName_
              WHERE  value = 'com.liferay.dynamic.data.mapping.model.DDMFormInstance'
          )
          AND ctCollectionId = 0       
        ORDER BY structureKey;
    "

    check "DDMStructure – Dates (form structures)" "
        SELECT
            structureKey,
            createDate,
            modifiedDate
        FROM DDMStructure
        WHERE groupId = __GROUPID__
          AND classNameId = (
              SELECT classNameId FROM ClassName_
              WHERE  value = 'com.liferay.dynamic.data.mapping.model.DDMFormInstance'
          )
          AND ctCollectionId = 0
        ORDER BY structureKey;
    "
}




