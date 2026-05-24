BEGIN
        SELECT
                LISTAGG(DISTINCT
                        CASE
                                WHEN upper(rve.raw_view_name) = 'VTX_DWH_COVER'
                                THEN
                                        'vtx.cover_provider_key'
                                ELSE
                                        'vtx.customer_key'
                        END
                        || chr(13)
                        || ' from ', 'union'
                                     || chr(13) ) WITHIN GROUP (ORDER BY rve.raw_view_name) INTO v_insert
        FROM
                raw_view_scope rve;
END;