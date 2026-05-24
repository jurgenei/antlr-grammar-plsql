SELECT 1
  FROM x
 WHERE EXISTS (
          WITH t AS (
                SELECT nvl(MAX(reporting_date), TO_DATE('01-01-1900', 'DD-MM-YYYY')) AS max_rd
                  FROM loaded_file_set_ferdi
                 WHERE status = 'C'
             )
          SELECT *
            FROM t
           WHERE p_reporting_date < t.max_rd
       );