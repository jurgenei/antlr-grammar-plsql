MERGE /*+ PARALLEL enable_parallel_dml */ INTO (
    SELECT
         cover_id,
         system_id,
         record_valid_from,
         cover_key
    FROM
         work_dwh_vre_cover_ifrs_multiyear
    WHERE
         system_id = v_system_id
        AND record_valid_from = v_calculation_date
        AND cover_key IS NULL
) a
    USING (
    SELECT /*+ PARALLEL */
          b.cover_key,
         b.cover_id,
         b.system_id,
         b.record_valid_from
    FROM
         dwh_cover_cds                     b
) src ON ( src.cover_id = a.cover_id
       AND src.record_valid_from = a.record_valid_from
       AND src.system_id = a.system_id )
    WHEN MATCHED
    THEN UPDATE SET a.cover_key = src.cover_key
     WHERE a.system_id = v_system_id
       AND a.record_valid_from = v_calculation_date
       AND a.cover_key IS NULL;