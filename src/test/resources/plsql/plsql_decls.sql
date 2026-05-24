create or replace PROCEDURE lots_of_decls
(
  basel_portfolio_code IN pkg_subtype.GENERAL_CODE DEFAULT NULL ,-- OFFICIAL, SA, AIRB
  crs_data_available IN OUT pkg_subtype.INDICATOR/* DEFAULT NULL*/,--Y or N
  ct_hierarchy_type IN pkg_subtype.INDICATOR DEFAULT 'L' ,
  customer_hierarchy_variables IN CLOB DEFAULT ' ' ,
  customer_id IN pkg_subtype.CUSTOMER_ID,
  data_filter_status IN OUT VARCHAR2/* DEFAULT 'NONE'*/,--NONE or OO_AGGREGATED_TOO_LOW
  debug IN NUMBER DEFAULT 0 ,
  elec_approach IN pkg_subtype.GENERAL_CODE DEFAULT 'Finance' ,
  facility_hierarchy_variables IN CLOB DEFAULT ' ' ,
  fundmanager IN pkg_subtype.GENERAL_CODE DEFAULT NULL ,
  login IN VARCHAR2 DEFAULT NULL ,
  original_customer_id IN pkg_subtype.CUSTOMER_ID DEFAULT NULL ,
  recap_hierarchy_variables IN CLOB DEFAULT ' ' ,
  reporting_date IN pkg_subtype.GENERAL_DATE DEFAULT NULL ,
  risk_description IN VARCHAR2 DEFAULT 'Concentration'
)
AS
   v_ct_hierarchy_type pkg_subtype.INDICATOR := ct_hierarchy_type;
   v_original_customer_id pkg_subtype.CUSTOMER_ID := original_customer_id;
   v_sys_error NUMBER := 0;
   v_authorisation_components VARCHAR2(10);
   v_auth_office VARCHAR2(50);
   v_authorisation_enabled VARCHAR2(1);
   v_authorisation_in_group_tree VARCHAR2(1);
   v_authorised pkg_subtype.INDICATOR;
   v_crm_table VARCHAR2(50);
   lv_economic_capital_active pkg_subtype.INDICATOR;
   lv_elec_available pkg_subtype.INDICATOR;
   v_elec_available_basel pkg_subtype.INDICATOR;
   lv_elec_suffix pkg_subtype.GENERAL_CODE;
   lv_expected_loss_active pkg_subtype.INDICATOR;
   v_fac_table VARCHAR2(50);
   v_from_statement CLOB;
   v_from_statement_fb CLOB;
   v_from_statement_rc CLOB;
   v_hierarchy_level pkg_subtype.HIERARCHY_LEVEL;
   v_imf_table VARCHAR2(50);
   v_max_facility_hierarchy_level NUMBER(12);
   v_oo_aggregated_limit pkg_subtype.GENERAL_AMOUNT;
   v_oo_aggregated_outstanding pkg_subtype.GENERAL_AMOUNT;
   v_period pkg_subtype.INDICATOR;
   v_procedure_name VARCHAR2(128);
   lv_raroc_active pkg_subtype.INDICATOR;
   v_recap_table VARCHAR2(50);
   v_select_statement --ORAIQ_P9 LONG VARCHAR changed with varchar(16384)
    CLOB;
   v_statement --ORAIQ_P9 LONG VARCHAR changed with varchar(16384)
    CLOB;
   v_time pkg_subtype.GENERAL_DATE;
   v_tmp_sql_statement --ORAIQ_P9 LONG VARCHAR changed with varchar(16384)
    CLOB;
   v_where_clause --ORAIQ_P9 LONG VARCHAR changed with varchar(16384)
    CLOB;
   v_where_clause_fb --ORAIQ_P9 LONG VARCHAR changed with varchar(16384)
    CLOB;
   v_where_clause_rc CLOB;--ORAIQ_P9 LONG VARCHAR changed with varchar(16384)
   v_cursor SYS_REFCURSOR;
     v_basel_portfolio_code pkg_subtype.GENERAL_CODE := basel_portfolio_code;
  v_crs_data_available pkg_subtype.INDICATOR:= crs_data_available ;
  v_customer_hierarchy_variables CLOB := customer_hierarchy_variables;
  v_customer_id pkg_subtype.CUSTOMER_ID := customer_id;
  v_data_filter_status VARCHAR2(40):=nvl(data_filter_status,'NONE');
  v_debug NUMBER(10):=debug;
  v_elec_approach pkg_subtype.GENERAL_CODE := elec_approach;
  v_facility_hierarchy_variables CLOB := facility_hierarchy_variables;
  v_fundmanager pkg_subtype.GENERAL_CODE := fundmanager;
  v_login VARCHAR2(10) := login;
  v_recap_hierarchy_variables CLOB := recap_hierarchy_variables;
  v_reporting_date pkg_subtype.GENERAL_DATE := reporting_date;
  v_risk_description VARCHAR2(100) := risk_description;
  v_dummy_null varchar2(10) null;
    v_debug_msg                                  pkg_subtype.debug_msg;
    v_proc_name                                  pkg_subtype.procedure_name := $$plsql_unit;

BEGIN

   commit;

   utils.resetTrancount;
   v_authorisation_enabled := 'Y' ;
   v_authorised := 'N' ;
   v_ct_hierarchy_type := UPPER(v_ct_hierarchy_type) ;
   v_max_facility_hierarchy_level := 0 ;
   v_original_customer_id := NVL(v_original_customer_id, v_customer_id) ;
   v_procedure_name := 'ws_oog_amount_aggr' ;


END;
/
show error;
GRANT EXECUTE ON WS_OOG_AMOUNT_AGGR TO VORTEX_BUSS_REPORT_GRP;

