begin
    UPDATE fact_ifrs_outstanding_group
    SET
        q_end_ifrs_stage_ind ='N'
    WHERE
        id IN ( WITH dim_file AS (
            SELECT
                *
            FROM
                dim_loaded_file_set dim_file
            WHERE
                dim_file.active_ind = 'Y'
                AND (dim_file.loaded_ind = 'Y'
                OR dim_file.loaded_ind IS NULL
                OR dim_file.loaded_ind = 'P' )
                AND dim_file.event_type = 'calculation'
                AND dim_file.record_valid_from =l_date_start_t_1
                AND (dim_file.q_end_ifrs_stage_ind = 'Y'
                OR dim_file.q_end_ifrs_stage_ind IS NULL)
        ), dim_file1 AS (
            SELECT
                *
            FROM
                dim_loaded_file_set dim_file
            WHERE
                dim_file.active_ind = 'Y'
                AND dim_file.event_type = 'daily_vde'
                AND dim_file.record_valid_from = l_date_end
        ), fact_active AS (
            SELECT
                fact_data_act.facility_id,
                fact_data_act.customer_id,
                fact_data_act.system_id,
                fact_data_act.record_valid_from,
                fact_data_act.id
            FROM
                fact_ifrs_outstanding_group fact_data_act,
                dim_file                    dim_file
            WHERE
                fact_data_act.export_id = dim_file.export_id
                AND fact_data_act.system_id = dim_file.system_id
                AND fact_data_act.record_valid_from = l_date_start_t_1
        ), fact_inactive AS (
            SELECT
                fact_data_inact.facility_id,
                fact_data_inact.customer_id,
                fact_data_inact.system_id,
                fact_data_inact.record_valid_from,
                fact_data_inact.id
            FROM
                fact_ifrs_outstanding_group fact_data_inact,
                dim_file1                   dim_file
            WHERE
                fact_data_inact.export_id = dim_file.export_id
                AND fact_data_inact.system_id = dim_file.system_id
                AND fact_data_inact.q_end_ifrs_stage_ind = 'Y'
                AND fact_data_inact.record_valid_from = l_date_end
        )
            SELECT
                fact_active.id
            FROM
                fact_active,
                fact_inactive
            WHERE
                fact_inactive.system_id = fact_active.system_id
                AND fact_inactive.customer_id = fact_active.customer_id
                AND fact_inactive.facility_id = fact_active.facility_id
        );
end;