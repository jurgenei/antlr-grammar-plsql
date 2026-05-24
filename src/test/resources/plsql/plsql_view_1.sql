CREATE OR REPLACE FORCE EDITIONABLE VIEW CRDM_DQ_DETAIL (REPORTING_DATE, SYSTEM_ID, CUSTOMER_KEY, FACILITY_KEY, SYSTEM_DESCRIPTION, EXCEPTION_TYPE, EXCEPTION_TYPE_DESCRIPTION, EXCEPTION_CODE, EXCEPTION_DESCRIPTION,
EXCEPTION_CATEGORY, EXCEPTION_CATEGORY_DESCRIPTION, PRIORITY, EXCEPTION_CCRM_CODE, SOURCE_VALUE, ADJUSTED_VALUE, CONSUMER_ID, LIMIT_ID, COVER_ID, BOOKING_OFFICE_KEY, BOOKING_OFFICE_DESCRIPTION, INITIATING_OFFICE_KEY,
INITIATING_OFFICE_DESCRIPTION, LEGAL_ENTITY_KEY, LEGAL_ENTITY_CODE, LEGAL_ENTITY_DESCRIPTION, FACILITY_TYPE_KEY, FACILITY_TYPE_CODE, FACILITY_TYPE_DESCRIPTION, FACILITY_PURPOSE_KEY, FACILITY_PURPOSE_CODE,
FACILITY_PURPOSE_DESCRIPTION, CUSTOMER_TYPE_KEY, CUSTOMER_TYPE_CODE, CUSTOMER_TYPE_DESCRIPTION, SEGMENTATION_TYPE_KEY, SEGMENTATION_TYPE_CODE, SEGMENTATION_TYPE_DESCRIPTION, DATA_QUALITY_DIMENSION, LOAD_DATE,
DATA_QUALITY_DIMENSION_DESC, SOLUTION_CODE, DWH_EXCEPTION_CATEGORY) AS
  WITH
ec_g AS
(
SELECT A.exception_category ,A.exception_cat_group , B.exception_category_grp_desc
FROM exception_category  A , (SELECT exception_category , DESCRIPTION AS exception_category_grp_desc FROM exception_category
WHERE exception_category = exception_cat_group) B
WHERE A.exception_cat_group = B.exception_category
)
SELECT /*+ NO_INDEX(f  )
        */
           e.record_valid_from                      AS reporting_date,
           e.system_id                              AS system_id,
           e.customer_key                           AS customer_key,
           e.facility_key                           AS facility_key,
           ss.system_descr                          AS system_description,
           e.exception_type                         AS exception_type,
           et.description                           AS exception_type_description,
           e.exception_code                         AS exception_code,
           es.description                           AS exception_description,
           ec.exception_cat_group                   AS exception_category,
           ec_g.exception_category_grp_desc         AS exception_category_description,      --2451155 Column Logic Changes
           es.priority                              AS priority,
           es.exception_rule_code                   AS exception_ccrm_code,
           NVL(e.local_value, '-')                  AS source_value,
           NVL(e.icrm_value, '-')               	AS adjusted_value,
           e.local_customer_id                      AS consumer_id,
           e.facility_id                            AS limit_id,
--           NVL(e.higher_level_facility_id, '-')     AS Higher_Limit_ID,
           NVL(e.cover_id, '-')                     AS cover_id,
           bo.office_key                            AS booking_office_key,
           bo.description                           AS booking_office_description,
           io.office_key                            AS initiating_office_key,
           io.description                           AS initiating_office_description,
           f.entity_key                             AS legal_entity_key,
           le.code                                  AS legal_entity_code,
           le.description                           AS legal_entity_description,
           f.facility_type_key                      AS facility_type_key,
           ft.code                                  AS facility_type_code,
           ft.description                           AS facility_type_description,
           f.facility_purpose_key                   AS facility_purpose_key,
           fp.code                                  AS facility_purpose_code,
           fp.description                           AS facility_purpose_description,
           c.customer_type_key                      AS customer_type_key,
           ct.code                                  AS customer_type_code,
           ct.description                           AS customer_type_description,
           c.segmentation_type_key                  AS segmentation_type_key,
           st.code                                  AS segmentation_type_code,
           st.description                           AS segmentation_type_description,
           es.data_quality_dimension				AS data_quality_dimension,			    --2361940 Story added column
           sysdate                                  AS load_date,
           dqd.DESCRIPTION                          AS data_quality_dimension_desc,          --2968501 Story added column
		       e.SOLUTION_CODE                          AS solution_code,
           e.exception_category                     AS dwh_exception_category
        FROM dwh_exception  e
        INNER JOIN exception_category  ec          ON e.exception_category = ec.exception_category
        INNER JOIN ec_g                            ON e.exception_category = ec_g.exception_category
        LEFT JOIN dwh_facility  f                  ON f.facility_key = e.facility_key and f.system_id = e.system_id and f.record_valid_from = e.record_valid_from
        LEFT JOIN facility_type  ft                ON f.facility_type_key = ft.facility_type_key
        LEFT JOIN facility_purpose  fp             ON f.facility_purpose_key = fp.facility_purpose_key
        LEFT JOIN dwh_derived_customer  c          ON c.customer_key = e.customer_key
        LEFT JOIN customer_type  ct                ON c.customer_type_key = ct.customer_type_key
        LEFT JOIN segmentation_type  st            ON c.segmentation_type_key = st.segmentation_type_key
        LEFT JOIN office  bo                       ON f.booking_office_key = bo.office_key
        LEFT JOIN office  io                       ON f.initiating_office_key = io.office_key
        LEFT JOIN entity  le                       ON f.entity_key = le.entity_key
        LEFT JOIN source_system  ss                ON e.system_id = ss.system_id
        LEFT JOIN exception_type  et               ON e.exception_type = et.exception_type
        LEFT JOIN exception_specification  es      ON e.exception_category = es.exception_category AND e.exception_code = es.exception_code AND e.solution_code = es.solution_code
        LEFT JOIN data_quality_dimension  dqd      ON es.data_quality_dimension = dqd.CODE
        WHERE
		    nvl(ss.Pipeline_Deal_Indicator, 'N') != 'Y'  --Commented for story 4312254
		    --f.crr2_calc_ind = 'Y'              --Added for story 4312254
;

