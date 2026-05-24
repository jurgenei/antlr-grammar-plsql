CREATE TABLE dmi_corep_recap_aggr_main (
  aggregation_main NUMBER(12, 0),
  allocated_limit_amt NUMBER(22, 2),
  allocated_outstanding_amt NUMBER(22, 2),
  eca_indicator NUMBER(1, 0)
) PCTFREE 25 PARTITION BY RANGE (
  record_valid_from
) SUBPARTITION BY LIST (
  system_id
) (
  PARTITION p_pre2006 VALUES LESS THAN (TO_DATE('2006-01-01 00:00:00', 'YYYY-MM-DD HH24:MI:SS')) TABLESPACE vortex_buss_data COMPRESS FOR ARCHIVE HIGH ( SUBPARTITION p_pre2006_aml VALUES ('AML') TABLESPACE vortex_buss_data COMPRESS FOR ARCHIVE HIGH, SUBPARTITION p_pre2006_bmg VALUES ('BMG') TABLESPACE vortex_buss_data COMPRESS FOR ARCHIVE HIGH, SUBPARTITION p_999999_default VALUES (DEFAULT) TABLESPACE vortex_buss_data_9999 )
) ENABLE ROW MOVEMENT;