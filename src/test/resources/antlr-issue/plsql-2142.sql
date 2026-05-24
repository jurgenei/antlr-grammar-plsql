-- Issue #2142: plsql grammar issue
-- URL: https://github.com/antlr/grammars-v4/issues/2142

whenever sqlerror exit sql.sqlcode
whenever oserror exit oscode
set timing on
alter session enable parallel dml;

define v_schema_stg = stg;
define v_schema = prod;
define v_parallel = 8;
define v_role = stg_select_role;

--Sample for Merge :
MERGE INTO &v_schema_stg..member_staging tgt
USING 
(SELECT /*+ parallel(&v_parallel) */  member_id, 
	  first_name, 
	  last_name, 
         rank
  FROM v_schema.members) stg
ON (tgt.member_id  = stg.member_id)
WHEN MATCHED THEN
    UPDATE /*+ parallel(&v_parallel) */  SET tgt.first_name = stg.first_name, 
               tgt.last_name = stg.last_name, 
               tgt.rank = stg.rank
    WHERE tgt.first_name <> stg.first_name OR 
           tgt.last_name <> stg.last_name OR 
           tgt.rank <> stg.rank 
WHEN NOT MATCHED THEN
    INSERT
 	(tgt.member_id, 
	 tgt.first_name, 
	 tgt.last_name, 
	 tgt.rank
       )
    VALUES
	(stg.member_id, 
	 stg.first_name, 
       stg.last_name,
       stg.rank
      );

COMMIT;