CREATE OR REPLACE EDITIONABLE PROCEDURE PRC_CRDM_FACT_IFRS_CONFIG_REFRESH
(
   batch_id         IN pkg_subtype.v_batch_id DEFAULT NULL,
   system_id        IN pkg_subtype.system_id DEFAULT NULL,
   reporting_date   IN pkg_subtype.general_date
)
AS
        l_record_valid_from  DATE := reporting_date;
        l_table_name        VARCHAR2(50) := 'T_FACT_IFRS_OUTSTANDING_GRP_CONFIG';       
        l_system_id         VARCHAR2(3) := system_id;
        l_batch_id            NUMBER        := batch_id;
        l_query             CLOB;
BEGIN

---Populating Table T_FACT_IFRS_OUTSTANDING_GRP_CONFIG 

        EXECUTE IMMEDIATE 'TRUNCATE TABLE '||l_table_name;
        dbms_output.put_line('Table Truncated '||l_table_name);
        
        l_query := 'INSERT INTO '||l_table_name||' (EVENT_TYPE,SYSTEM_ID,RECORD_VALID_FROM,BATCH_ID) '||
                    'VALUES(''BUSS_CRDM_CALC'', :SYSTEM_ID , :RECORD_VALID_FROM , :BATCH_ID )';

        DBMS_OUTPUT.PUT_LINE('Query Generated : '||l_query);
        
        
        EXECUTE IMMEDIATE l_query using l_system_id,l_record_valid_from,l_batch_id;
        
        DBMS_OUTPUT.PUT_LINE('Total Rows Inserted Successfully : '||sql%rowcount);
        COMMIT;

         schema_maint.gather_idx_stats(l_table_name);

---Populating Table T_FACT_IFRS_OUTSTANDING_GRP_CONFIG Completed


END PRC_CRDM_FACT_IFRS_CONFIG_REFRESH;
/
show error;

GRANT EXECUTE ON PRC_CRDM_FACT_IFRS_CONFIG_REFRESH TO VORTEX_BUSS_RW;