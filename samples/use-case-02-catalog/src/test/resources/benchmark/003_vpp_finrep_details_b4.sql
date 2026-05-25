create or replace PROCEDURE vpp_finrep_details_b4 (

    v_reporting_date   IN pkg_subtype.general_date,
    v_system_id        IN VARCHAR2,
    v_batch_id         IN NUMBER DEFAULT NULL,
    v_debug            IN NUMBER DEFAULT 0
)

AS


    v_procedure_name VARCHAR2(50 CHAR);
    v_reporting_date_t_1 pkg_subtype.general_date;
    v_check_day VARCHAR2(2 CHAR);
    v_check_month VARCHAR2(2 CHAR);
    v_check_quarter_end VARCHAR2(4 CHAR);
    v_provisions_t_1_insert VARCHAR2(1 CHAR);
    v_retstatus NUMBER(12);
    v_retstatus_ins NUMBER(12);
    v_event_processed VARCHAR2(50 CHAR);
    v_error NUMBER(12);
    v_temp NUMBER(1,0) := 0;
    v_begin_of_year DATE;
    v_end_of_last_year DATE;
    v_time_key_end_of_last_year NUMBER(12);
    v_number_of_records NUMBER(12);
    v_debug_msg VARCHAR2(10000 CHAR);
    v_reporting_date_t_12 DATE;
    v_is_ind_active varchar2(5 CHAR); --new varible added for STRY3563103
	v_min_rank NUMBER(12);
	v_max_rank NUMBER(12);
   -- EU_OFFICIAL_SME_IND varchar2(1 char);
	v_cnt integer:= 0; -- varible added for 4335652
   BEGIN
     EXECUTE IMMEDIATE 'ALTER SESSION ENABLE PARALLEL DML';
         v_debug_msg := $$plsql_line || ' of unit ' || $$plsql_unit || '<<START>>';
    utilities.show_debug(v_debug_msg);
    utilities.show_debug (replace('[%1!] start vpp_finrep_details_b4 ','%1!',systimestamp) );
    v_procedure_name := 'vpp_finrep_details_b4';
    v_reporting_date_t_1 := utils.dateadd('DAY',-1,utils.dateadd('MONTH',-1,utils.dateadd('DAY',1,v_reporting_date)));-- + 1 day - 1 month - 1 day

    v_check_day := utils.datepart('DD',v_reporting_date);
    v_check_month := utils.datepart('MM',v_reporting_date);
    v_check_quarter_end := v_check_month || v_check_day;
    v_provisions_t_1_insert := CASE
                                    WHEN v_check_quarter_end IN ('331','630','930','1231')
                                    THEN 'Y'
                                    ELSE 'N'
                              END;

    v_event_processed := 'finrep_load';
      --truncate table vpp_finrep_details_info where reporting_period = @reporting_date and system_id = @system_id
      --truncate vpp_finrep_cover_info where reporting_period = @reporting_date and system_id = @system_id
      -- Below tables replace hash tables by same name; to be truncated at begining of processing
BEGIN
    --Fetch reference value into newly declared variable
            SELECT
                TEXT_VALUE
            INTO v_is_ind_active
            FROM
                functional_parameter
            WHERE
                    code = 'SME_INDICATOR_VPP_LR_SWITCH'
                AND record_valid_until IS NULL;
     EXCEPTION
        WHEN NO_DATA_FOUND THEN v_is_ind_active := NULL;
        WHEN OTHERS THEN RAISE;
    END;
    utilities.truncate_table('tmp_finrep_cover_info');
    utilities.truncate_table('tmp_finrep_cover_capped_info');
    utilities.truncate_table('tmp_vpp_finrep_details_info');
      ---- Workaround for Finrep_product_type table to preocess loan commitments

    utilities.truncate_table('tt_finrep_product_type');
BEGIN
    INSERT /*+ APPEND enable_parallel_dml */ INTO tt_finrep_product_type (
        finrep_product_type_key,
        finrep_product_type_id,
        record_valid_from,
        record_valid_until,
        higher_level_code,
        highest_level_code,
        level_number,
        higher_level_key,
        highest_level_key,
        description
    )
        (
            SELECT
                finrep_product_type_key,
                finrep_product_type_id,
                record_valid_from,
                record_valid_until,
                higher_level_code,
                highest_level_code,
                level_number,
                higher_level_key,
                highest_level_key,
                description
            FROM
                finrep_product_type
        );

    EXCEPTION
        WHEN OTHERS THEN
            utils.handleerror(sqlcode,sqlerrm);
    END;

    v_debug_msg := $$plsql_line || ' of unit ' || $$plsql_unit || '<<dm count>>' || SQL%rowcount;

    utilities.show_debug(v_debug_msg);
	commit; --per fix
    BEGIN

        INSERT  /*+ APPEND enable_parallel_dml*/ INTO tt_finrep_product_type
            ( SELECT
                17,
                'OTHERS',
                to_date('2017-11-24','yyyy-mm-dd'),
                NULL,
                'OTHERS',
                'OTHERS',
                1,
                17,
                17,
                'Others (not in scope)'
              FROM
                dual
            );

    EXCEPTION
        WHEN OTHERS THEN
            utils.handleerror(sqlcode,sqlerrm);
    END;

    v_debug_msg := $$plsql_line || ' of unit ' || $$plsql_unit || '<<dm count>>' || SQL%rowcount;

    utilities.show_debug(v_debug_msg);
	commit; --per fix
    schema_maint.gather_idx_stats('tt_finrep_product_type');

--//2021017
    utilities.truncate_table('tt_finrep_cover_type');
    BEGIN
		insert /*+ APPEND enable_parallel_dml*/ into tt_finrep_cover_type(priority,cre_indicator,finrep_cover_type_id)
		select 1 , 'Y','COM_PROP' FROM DUAL UNION ALL
		select 1 , 'N','RES_PROP' FROM DUAL UNION ALL
		select 3 , NULL,'CASH' FROM DUAL UNION ALL
		select 4 , NULL,'MOV_PROP' FROM DUAL UNION ALL
		select 5 , NULL,'EQ_DEB_SEC' FROM DUAL UNION ALL
		select 6 , NULL,'REST' FROM DUAL UNION ALL
		select 7 , NULL,'CRED_DERIV' FROM DUAL UNION ALL
		select 8 , NULL,'FINAN_GUAR' FROM DUAL;
    EXCEPTION
        WHEN OTHERS THEN
            utils.handleerror(sqlcode,sqlerrm);
    END;

    BEGIN
        UPDATE /*+ enable_parallel_dml */  tt_finrep_product_type
            SET
                higher_level_code = 'OTHERS',
                highest_level_code = 'OTHERS',
                higher_level_key = 17,
                highest_level_key = 17
        WHERE
            finrep_product_type_id = 'OTH' AND   level_number = 2;

    EXCEPTION
        WHEN OTHERS THEN
            utils.handleerror(sqlcode,sqlerrm);
    END;

    v_debug_msg := $$plsql_line || ' of unit ' || $$plsql_unit || '<<dm count>>' || SQL%rowcount;

    utilities.show_debug(v_debug_msg);
	commit; --per fix
      ---- Workaround for facility_type
    utilities.truncate_table('tt_facility_type');
BEGIN
    INSERT /*+ APPEND enable_parallel_dml*/ INTO tt_facility_type (
        facility_type_key,
        code,
        record_valid_from,
        record_valid_until,
        higher_level_code,
        highest_level_code,
        level_number,
        higher_level_key,
        highest_level_key,
        description,
        default_product_type,
        default_facility_purpose,
        underlying_value_type,
        current_inst_calc,
        le_inclusion_percentage,
        calculate_country_risk,
        trading_non_trading,
        on_balance_sheet_indicator,
        mirb_risky_product,
        given_taken_indicator,
        internal_guarantee_given,
        eligible_cds_indicator,
        resecuritisation_indicator,
        senior_indicator,
        cva_cap_eligible_recap,
        cva_cap_eligible_incap,
        ltv_included,
        qccp_initial_margin,
        qccp_default_fund,
        ccp_eligible_recap,
        ccp_eligible_incap,
        corep_counterparty_cluster,
        corep_sponsor_cluster,
        le_exemption_type,
        recap_included,
        incap_included,
        country_risk_included,
        llp_included,
        ler_included,
        finrep_lim_type_1,
        finrep_lim_type_2,
        ctryrisk_facility_exclusion,
        lr_counterparty_cluster,
        lr_deriv_classification,
        interest_only,
        revolving,
        notice_period,
        committed_indicator,
        contractual_maturity,
        advised,
        anacredit_instr_type,
        finrep_product_type,
        statutory_product_type,
        gcd_facility_type_id,
        dod_scp_product,
        secsts_ccf,
        salary_secured_loan_ind
    )
        (
            SELECT /*+ PARALLEL */
                facility_type_key,
                code,
                record_valid_from,
                record_valid_until,
                higher_level_code,
                highest_level_code,
                level_number,
                higher_level_key,
                highest_level_key,
                description,
                default_product_type,
                default_facility_purpose,
                underlying_value_type,
                current_inst_calc,
                le_inclusion_percentage,
                calculate_country_risk,
                trading_non_trading,
                on_balance_sheet_indicator,
                mirb_risky_product,
                given_taken_indicator,
                internal_guarantee_given,
                eligible_cds_indicator,
                resecuritisation_indicator,
                senior_indicator,
                cva_cap_eligible_recap,
                cva_cap_eligible_incap,
                ltv_included,
                qccp_initial_margin,
                qccp_default_fund,
                ccp_eligible_recap,
                ccp_eligible_incap,
                corep_counterparty_cluster,
                corep_sponsor_cluster,
                le_exemption_type,
                recap_included,
                incap_included,
                country_risk_included,
                d_llp_included,
                ler_included,
                finrep_lim_type_1,
                finrep_lim_type_2,
                ctryrisk_facility_exclusion,
                lr_counterparty_cluster,
                lr_deriv_classification,
                interest_only,
                revolving,
                notice_period,
                committed_indicator,
                contractual_maturity,
                advised,
                anacredit_instr_type,
                finrep_product_type,
                statutory_product_type,
                gcd_facility_type_id,
                d_dod_scp_product,
                secsts_ccf,
                salary_secured_loan_ind
            FROM
                facility_type
            WHERE
                level_number IN ( 5, 6 )
        );

EXCEPTION
    WHEN OTHERS THEN
        utils.handleerror(sqlcode, sqlerrm);
END;

    v_debug_msg := $$plsql_line || ' of unit ' || $$plsql_unit || '<<dm count>>' || SQL%rowcount;
    utilities.show_debug(v_debug_msg);
	commit; --per fix
    schema_maint.gather_idx_stats('tt_facility_type');

    utilities.truncate_table('tt_tmp_facility_type');
BEGIN
    INSERT /*+ APPEND enable_parallel_dml*/ INTO tt_tmp_facility_type (


        facility_type_key,
        code,
        record_valid_from,
        record_valid_until,
        higher_level_code,
        highest_level_code,
        level_number,
        higher_level_key,
        highest_level_key,
        description,
        default_product_type,
        default_facility_purpose,
        underlying_value_type,
        current_inst_calc,
        le_inclusion_percentage,
        calculate_country_risk,
        trading_non_trading,
        on_balance_sheet_indicator,
        mirb_risky_product,
        given_taken_indicator,
        internal_guarantee_given,
        eligible_cds_indicator,
        resecuritisation_indicator,
        senior_indicator,
        cva_cap_eligible_recap,
        cva_cap_eligible_incap,
        ltv_included,
        qccp_initial_margin,
        qccp_default_fund,
        ccp_eligible_recap,
        ccp_eligible_incap,
        corep_counterparty_cluster,
        corep_sponsor_cluster,
        le_exemption_type,
        recap_included,
        incap_included,
        country_risk_included,
        llp_included,
        ler_included,
        finrep_lim_type_1,
        finrep_lim_type_2,
        ctryrisk_facility_exclusion,
        lr_counterparty_cluster,
        lr_deriv_classification,
        interest_only,
        revolving,
        notice_period,
        committed_indicator,
        contractual_maturity,
        advised,
        anacredit_instr_type,
        finrep_product_type,
        statutory_product_type,
        gcd_facility_type_id,
        dod_scp_product,
        secsts_ccf,
        salary_secured_loan_ind
    )
        (
            SELECT /*+ PARALLEL */


                facility_type_key,
                code,
                record_valid_from,
                record_valid_until,
                higher_level_code,
                highest_level_code,
                level_number,
                higher_level_key,
                highest_level_key,
                description,
                default_product_type,
                default_facility_purpose,
                underlying_value_type,
                current_inst_calc,
                le_inclusion_percentage,
                calculate_country_risk,
                trading_non_trading,
                on_balance_sheet_indicator,
                mirb_risky_product,
                given_taken_indicator,
                internal_guarantee_given,
                eligible_cds_indicator,
                resecuritisation_indicator,
                senior_indicator,
                cva_cap_eligible_recap,
                cva_cap_eligible_incap,
                ltv_included,
                qccp_initial_margin,
                qccp_default_fund,
                ccp_eligible_recap,
                ccp_eligible_incap,
                corep_counterparty_cluster,
                corep_sponsor_cluster,
                le_exemption_type,
                recap_included,
                incap_included,
                country_risk_included,
                llp_included,
                ler_included,
                finrep_lim_type_1,
                finrep_lim_type_2,
                ctryrisk_facility_exclusion,
                lr_counterparty_cluster,
                lr_deriv_classification,
                interest_only,
                revolving,
                notice_period,
                committed_indicator,
                contractual_maturity,
                advised,
                anacredit_instr_type,
                finrep_product_type,
                statutory_product_type,
                gcd_facility_type_id,
                dod_scp_product,
                secsts_ccf,
                salary_secured_loan_ind
            FROM
                tt_facility_type
            WHERE
                    record_valid_from <= TO_DATE('2017-12-31', 'yyyy-mm-dd')
                AND ( record_valid_until IS NULL
                      OR record_valid_until >= TO_DATE('2017-12-31', 'yyyy-mm-dd') )
        );

    EXCEPTION
        WHEN OTHERS THEN
            utils.handleerror(sqlcode,sqlerrm);
    END;

    v_debug_msg := $$plsql_line || ' of unit ' || $$plsql_unit || '<<dm count>>' || SQL%rowcount;
    utilities.show_debug(v_debug_msg);
	commit; --per fix
    schema_maint.gather_idx_stats('tt_tmp_facility_type');

    --PK:Merge Modification : 18-07-2019
    BEGIN
        MERGE  /*+ enable_parallel_dml */ INTO tt_facility_type tf USING ( SELECT /*+ PARALLEL */
            tmp.finrep_product_type,
            tmp.code
            FROM tt_tmp_facility_type tmp )
        src ON ( src.code = tf.code AND tf.record_valid_from <= to_date('2017-11-30','yyyy-mm-dd') AND   (
                nvl(tf.record_valid_until,utilities.record_default_date) >= to_date('2017-11-30','yyyy-mm-dd')))
        WHEN MATCHED THEN UPDATE SET tf.finrep_product_type = src.finrep_product_type;

    EXCEPTION
        WHEN OTHERS THEN
            utils.handleerror(sqlcode,sqlerrm);
    END;

    v_debug_msg := $$plsql_line || ' of unit ' || $$plsql_unit || '<<dm count>>' || SQL%rowcount;

    utilities.show_debug(v_debug_msg);
	commit; --per fix
    BEGIN
        UPDATE /*+ PARALLEL enable_parallel_dml */  tt_facility_type
            SET
                finrep_product_type = 'NON_LOAN'
        WHERE
            code IN (
                SELECT
                    dmi_facility_type.facility_type_code
                FROM
                    dmi_facility_type
                WHERE
                    dmi_facility_type.record_valid_from <= v_reporting_date
                AND   (dmi_facility_type.record_valid_until IS NULL OR    dmi_facility_type.record_valid_until >= v_reporting_date)
                AND   tt_facility_type.level_number = 6
                AND   dmi_facility_type.product_group_level3_code IN ('WSOL','WSL')
            );

    EXCEPTION
        WHEN OTHERS THEN
            utils.handleerror(sqlcode,sqlerrm);
    END;

    v_debug_msg := $$plsql_line || ' of unit ' || $$plsql_unit || '<<dm count>>' || SQL%rowcount;

    utilities.show_debug(v_debug_msg);
	commit; --per fix
    IF v_debug = 1 THEN
        BEGIN
            utilities.show_debug(replace(
                '[%1!] executing vpp_finrep_details_b4... 1a insert into tt_tmp_FINREP_BASIC_INFO',
                '%1!',
                systimestamp
            ) );
        END;
    END IF;

    utilities.truncate_table('tt_tmp_FINREP_BASIC_INFO');
    BEGIN
        INSERT /*+ APPEND enable_parallel_dml */   INTO tt_tmp_finrep_basic_info
            ( SELECT --top 10
                v_reporting_date reporting_period,
                iog.record_valid_from record_valid_from,
                iog.record_valid_until record_valid_until,
                iog.system_id,
                'B' source,
                iog.facility_key facility_key,
                iog.facility_id facility_id,
                fac.higher_level_facility_key,
                hfac.facility_id higher_level_facility_id,
                iog.outstanding_group_id outstanding_group_id,
                iog.outstanding_group_key outstanding_group_key,
                dvb.outstanding_id outstanding_id,
                dvb.outstanding_key outstanding_key,
                dog.local_outstanding_id,
                ddc.customer_id customer_id,
                iog.customer_key customer_key,
                dog.security_id instrument_id,
                dog.security_id_type instrument_type,
                dog.booking_office_key os_booking_office_key,
                dog.initiating_office_key os_initiating_office_key,
                dog.book_base_entity_key os_booking_base_entity_key,
                dog.book_base_entity_code os_booking_base_entity_code,
                dog.init_base_entity_key os_initiating_base_entity_key,
                dog.init_base_entity_code os_initiating_base_entity_code,
                dog.prod_type_key product_type_key,
                dog.entity_key ing_legal_entity_key,
                dog.entity_code ing_legal_entity_code,
                dog.days_past_due days_pastdue,
                fac.booking_office_key fac_booking_office_key,
                fac.initiating_office_key fac_initiating_office_key,
                fac.book_base_entity_key fac_booking_base_entity_key,
                fac.book_base_entity_code fac_booking_base_entity_code,
                fac.init_base_entity_key fac_initiating_base_entity_key,
                fac.init_base_entity_code fac_initiating_base_entity_code,
                fac.facility_type_key facility_type_key,
                fac.entity_key fac_ing_legal_entity_key,
                fac.entity_code fac_ing_legal_entity_code,
                fac.advised_key,
                --fac.forbearance_measure_key,---ORAMIGSecondcatchup
                fac.forbearance_status_key,
                fac.committed_indicator,
                fac.purch_or_orig_credit_impaired_key poci_tp_key,
                dvb.official_approach basel_official_approach,
                dvb.exposure_class_sa_original exposure_class_original_sa,
                dvb.exposure_class_original exposure_class_original_irb,
                dvb.exposure_class_sa_not_def,
                cast(null as varchar2(20)) as exposure_class_sec,
                dvb.ifrs9_finrep_subordination finrep_subordinate,
                fac.derecognition_reason_key derecognition_reason_key,
                fac.derecognition_date derecognition_date,
                dvb.rating_original risk_rating_code,
                dog.ifrs9_accounting_classification_key,
                dog.ifrs9_measurement_category_key,
                pt.on_balance_sheet_indicator on_balance_sheet_ind,
                CASE
                        WHEN    pt.finrep_product_type IS NOT NULL
                                AND fpt.higher_level_code = 'LOAN_ADV'
                                -- AND fac.committed_indicator = 'C' -- Commented for #6100334
								AND cci.code in ( 'CCC', 'UCC') -- Added for #6100334
                                AND iog.allocated_limit_amount <> 0
                                AND iog.gross_carrying_amount <= iog.allocated_limit_amount
                        THEN iog.gross_carrying_amount / iog.allocated_limit_amount
        --when pt.on_balance_sheet_indicator <> 'Y' then 0
                        ELSE 1
                    END
                on_balance_ratio_drawn,
                CASE
                        WHEN    pt.finrep_product_type IS NOT NULL
                            AND fpt.higher_level_code = 'LOAN_ADV'
                            -- AND fac.committed_indicator = 'C' -- Commented for #6100334
							AND cci.code in ( 'CCC', 'UCC') -- Added for #6100334
                            AND iog.exposure_credit <> 0
                            AND iog.exposure_credit IS NOT NULL
                            AND iog.allocated_limit_amount - iog.gross_carrying_amount > 0
                            AND iog.gross_carrying_amount <= iog.exposure_credit
                        THEN iog.gross_carrying_amount / iog.exposure_credit
        --when pt.on_balance_sheet_indicator <> 'Y' then 0
                        ELSE 1
                    END
                on_balance_ratio_ead,
                ddc.customer_type_key,
                CASE
                        WHEN ddc.industry1_key IS NOT NULL
                        THEN ddc.industry1_key
                        ELSE industry1_key
                    END
                industry_type_key,
                ddc.ctry_of_residence_key residence_country_key,
                iog.allocated_limit_amount allocated_limit_amt,
                iog.outstanding_amount allocated_outstanding_amt,
                iog.gross_carrying_amount gross_carrying_amt,
                iog.commit_undrawn_amount commit_undrawn_amount,
                iog.exposure_credit exposure_original,
                dvb.securitisation_code,---ORAMIGSecondcatchup
                -- dvb.securitised_factor,  ---ORAMIGSecondcatchup -- Changed for #4857458
				sec.securitised_factor, -- added for #4857458
                cast(null as varchar2(10)) as sts_ind,--ORAMIGTHIRDCATCHUP
                cast(null as  varchar2(10)) as securitised_ind,--ORAMIGTHIRDCATCHUP
                cast(null as  varchar2(10)) as retained_position_ind,--ORAMIGTHIRDCATCHUP
                --ltv.ltv_indexed_limit       as ltv_ratio--ORAMIGTHIRDCATCHUP
                --ltv.ltv_indexed_outstanding as ltv_ratio, --CU6 --Commented for 6979056
                ltv.ltv_finrep as ltv_ratio, --Added for 6979056
                ------------------Start iof vdd_rrd_catchup_124----------------
                ddc.segmentation_type_key as segmentation_type_key
                ,dog.accounting_unit_key as accounting_unit_key
                ------------------End of vdd_rrd_catchup_124-------------------
                ,cci.code as CREDIT_COMMITMENT_IND --6100295
              FROM
                dwh_ifrs_outstanding_group iog
                JOIN dwh_outstanding_group dog ON dog.outstanding_group_key = iog.outstanding_group_key and dog.record_valid_from = iog.record_valid_from and iog.system_id = dog.system_id --extra conditions added to improve performance
                -- LEFT JOIN dwh_vbr_basel2 dvb
				LEFT JOIN dwh_recapb4_outstanding_group dvb -- Changed source for #4857458
				ON iog.outstanding_group_key = dvb.outstanding_group_key AND dvb.record_valid_from = v_reporting_date AND   dvb.system_id = v_system_id
                JOIN dwh_facility fac ON fac.facility_key = iog.facility_key and fac.record_valid_from = iog.record_valid_from and iog.system_id = fac.system_id --extra conditions added to improve performance
                -- and nvl(fac.crr2_calc_ind,'Y') != 'N' --added for story 4054104
				AND NVL(fac.crr3_calc_ind,'Y') != 'N' -- added for story #4857458
                JOIN dwh_facility hfac ON hfac.facility_key = fac.higher_level_facility_key and fac.record_valid_from = hfac.record_valid_from and hfac.system_id = fac.system_id --extra conditions added to improve performance
                JOIN tt_facility_type pt ON pt.level_number = 6 AND dog.prod_type_key = pt.facility_type_key
                LEFT JOIN tt_finrep_product_type fpt
                ON  fpt.record_valid_from <= v_reporting_date
                    AND ( fpt.record_valid_until IS NULL OR fpt.record_valid_until > v_reporting_date)
                    AND fpt.level_number         = 2 AND pt.finrep_product_type   = fpt.finrep_product_type_id
                JOIN dwh_derived_customer ddc ON ddc.customer_key   = iog.customer_key
                left outer join dwh_vre_facility_ltv ltv
                ON ltv.facility_id = iog.facility_id
                    and ltv.system_id = iog.system_id--ORAMIGTHIRDCATCHUP
                    and ltv.record_valid_from <= v_reporting_date
                    and (ltv.record_valid_until is NULL or ltv.record_valid_until > v_reporting_date)       --ORAMIGTHIRDCATCHUP
				-- Added join for securitised_factor from new source #4857458 start
				LEFT JOIN
				(SELECT outstanding_group_key,facility_key ,securitised_factor
				FROM dwh_vre_securitisation_recapb4
				WHERE record_valid_from <= v_reporting_date
				AND system_id=v_system_id
				GROUP BY outstanding_group_key,facility_key ,securitised_factor ) sec
					ON sec.outstanding_group_key=iog.outstanding_group_key
					AND sec.facility_key=fac.facility_key
				-- #4857458 end
                LEFT JOIN credit_commitment_ind cci --6100295
                    ON cci.credit_commitment_ind_key = fac.credit_commitment_key
                    AND cci.RECORD_VALID_FROM <= v_reporting_date
                    AND (nvl(cci.record_valid_until,utilities.record_default_date) > v_reporting_date )
              WHERE
                iog.record_valid_from = v_reporting_date AND   iog.system_id = v_system_id
            );

    EXCEPTION
        WHEN OTHERS THEN
            utils.handleerror(sqlcode,sqlerrm);
    END;
    v_debug_msg := $$plsql_line || ' of unit ' || $$plsql_unit || '<<dm count>>' || SQL%rowcount;
    utilities.show_debug(v_debug_msg);

    IF ( SQL%rowcount = 0 ) THEN
        utilities.show_debug(replace(
            '[%1!] No records found for this reporting date',
            '%1!',
            systimestamp
        ) );
    END IF;
commit; --per fix
    schema_maint.gather_idx_stats('tt_tmp_finrep_basic_info');
    -- Update info from dwh_vre_securitisation_recap for SEC records not in dwh_vbr_basel2
---ORAMIGSecondcatchup ? Begin
--PK:Merge Modification : 18-07-2019
BEGIN
    MERGE  /*+ enable_parallel_dml */ INTO tt_tmp_finrep_basic_info fbi USING ( SELECT  --distinct --applied distinct as dwh_vre_securitisation_recap has duplicate outstanding_group_keys for the same system_id and record_valid_from
        vsr.outstanding_id,
        vsr.outstanding_key,
        vsr.exposure_class_original, -- PLACEHOLDER
        vsr.internal_rating,
        vsr.securitisation_code,
        vsr.securitised_factor,
        vsr.outstanding_group_key,
        ers.risk_rating_master_scale,
        vsr.retained_position_ind
        --,ROW_NUMBER() OVER( PARTITION BY outstanding_group_key ORDER BY internal_rating DESC ) row_num --ADDED DESC TO MATCH SYBASE CONDITION
        -- FROM dwh_vre_securitisation_recap vsr
        FROM dwh_vre_securitisation_recapb4 vsr 	-- Changed source for #4857458
        LEFT OUTER JOIN rating_agency ra          ON cast (vsr.rating_agency as number) = ra.rating_agency_key
                                          AND ra.record_valid_from <= vsr.record_valid_from
                                          AND (ra.record_valid_until > vsr.record_valid_from or ra.record_valid_until is null)
        LEFT OUTER JOIN external_rating_scale ers ON  ers.external_rating_scale = vsr.external_rating
                                          AND ra.code = ers.rating_agency_code
                                          AND ers.rating_type = 'LR'
                                          AND ers.record_valid_from <= vsr.record_valid_from
                                          AND (ers.record_valid_until > vsr.record_valid_from or ers.record_valid_until is null)
        WHERE vsr.record_valid_from = v_reporting_date AND   vsr.system_id = v_system_id AND vsr.cover_key IS NULL  --added extra condition as per RRD BA's
        AND vsr.configuration_code = 'SECSTS4' -- Added for avoiding TR (SECSTS4TR) records and fix duplicate issues #4857458
        )
    src ON ( fbi.outstanding_group_key = src.outstanding_group_key )-- and src.row_num = 1 )
    WHEN MATCHED THEN UPDATE SET fbi.outstanding_id = src.outstanding_id,
                                fbi.outstanding_key = src.outstanding_key,
                                fbi.exposure_class_sec = src.exposure_class_original,
                                fbi.risk_rating_code = CASE WHEN src.internal_rating IS NOT NULL
                                                            THEN src.internal_rating
                                                            ELSE src.risk_rating_master_scale
                                                       END,
                                fbi.securitisation_code = src.securitisation_code,
                                fbi.securitised_factor = src.securitised_factor,
                                fbi.finrep_subordinate = 'OTH',
                                fbi.sts_ind               = 'STS',
                                fbi.securitised_ind       = 0,
                                fbi.retained_position_ind = src.retained_position_ind;
EXCEPTION WHEN OTHERS THEN
    utils.handleerror(sqlcode,sqlerrm);
END;
commit; --per fix

---ORAMIGSecondcatchup ? End
---ORAMIGTHIRDCATCHUP Start

UPDATE /*+ enable_parallel_dml */  tt_tmp_FINREP_BASIC_INFO fbi
 SET  fbi.sts_ind = 'NON-STS'
WHERE fbi.sts_ind IS NULL;
commit; --per fix
---ORAMIGTHIRDCATCHUP End

      -- Update the instrument details if instrument type is 'BLOOMBERG'
    --do not change
    BEGIN
        MERGE  /*+ enable_parallel_dml */ INTO tt_tmp_finrep_basic_info USING ( SELECT
            tt_tmp_finrep_basic_info.rowid row_id,
            CASE
                    WHEN tt_tmp_finrep_basic_info.instrument_type = 'BLOOMBERG' AND sec_data.security_id_type = 'SEDOL' THEN
                        sec_data.security_id
                    WHEN tt_tmp_finrep_basic_info.instrument_type = 'BLOOMBERG' AND sec_data.security_id_type = 'CUSIP' THEN
                        sec_data.security_id
                    WHEN tt_tmp_finrep_basic_info.instrument_type = 'BLOOMBERG' AND sec_data.security_id_type = 'ISIN' THEN
                        sec_data.security_id
                    ELSE instrument_id
                END
            AS pos_2,
            CASE
                    WHEN tt_tmp_finrep_basic_info.instrument_type = 'BLOOMBERG' AND sec_data.security_id_type = 'SEDOL' THEN
                        'SEDOL'
                    WHEN tt_tmp_finrep_basic_info.instrument_type = 'BLOOMBERG' AND sec_data.security_id_type = 'CUSIP' THEN
                        'CUSIP'
                    WHEN tt_tmp_finrep_basic_info.instrument_type = 'BLOOMBERG' AND sec_data.security_id_type = 'ISIN' THEN
                        'ISIN'
                    ELSE instrument_type
                END
            AS pos_3
                                                    FROM
            tt_tmp_finrep_basic_info left
            JOIN scs_combined_security_data sec_data
            ON sec_data.record_valid_from <= v_reporting_date
            AND (sec_data.record_valid_until IS NULL OR sec_data.record_valid_until > v_reporting_date)
            AND tt_tmp_finrep_basic_info.instrument_type   = 'BLOOMBERG'
            AND tt_tmp_finrep_basic_info.instrument_id     = sec_data.bloomberg_code
        )
        src ON ( tt_tmp_finrep_basic_info.rowid = src.row_id )
        WHEN MATCHED THEN UPDATE SET instrument_id = pos_2,
        instrument_type = pos_3;

    EXCEPTION
        WHEN OTHERS THEN
            utils.handleerror(sqlcode,sqlerrm);
    END;

    v_debug_msg := $$plsql_line || ' of unit ' || $$plsql_unit || '<<dm count>>' || SQL%rowcount;

    utilities.show_debug(v_debug_msg);
	commit; --per fix
      --select * from tt_tmp_FINREP_BASIC_INFO where facility_id = 'FC10019835'  and outstanding_group_id = 2247
      --2. Populate all the reference data along with all on/off balance products except Undrawn records.
    IF v_debug = 1 THEN
        BEGIN
            utilities.show_debug (replace('[%1!] 2a. Populate all the reference data along with all on/off balance products except Undrawn records.','%1!',systimestamp) );
        END;
    END IF;

    BEGIN
        INSERT /*+ APPEND */  INTO tmp_vpp_finrep_details_info (
            reporting_period,
            record_valid_from,
            record_valid_until,
            system_id,
            source,
            facility_key,
            facility_id,
            higher_level_facility_key,
            higher_level_facility_id,
            outstanding_group_id,
            outstanding_group_key,
            local_outstanding_id,
            outstanding_id,
            outstanding_key,
            customer_id,
            customer_key,
            instrument_id,
            instrument_type,
            os_booking_office_key,
            os_booking_office_code,
            os_booking_base_entity_key,
            os_booking_base_entity_code,
            os_booking_base_entity_descr,
            os_initiating_office_key,
            os_initiating_office_code,
            os_initiating_base_entity_key,
            os_initiating_base_entity_code,
            os_initiating_base_entity_descr,
            fac_booking_office_key,
            fac_booking_office_code,
            fac_booking_base_entity_key,
            fac_booking_base_entity_code,
            fac_booking_base_entity_descr,
            fac_initiating_office_key,
            fac_initiating_office_code,
            fac_initiating_base_entity_key,
            fac_initiating_base_entity_code,
            fac_initiating_base_entity_descr,
            customer_type_key,
            customer_type_code,
            customer_type_descr,
            industry_type_key,
            industry_type_code,
            industry_type_nace_2_0,
            nace_highest_level_code,
            residence_country_key,
            residence_country_code,
            residence_country_name,
            regulatory_country_code,
            regulatory_country_key,
            regulatory_country_name,
            basel_official_approach,
            exposure_class_original_sa,
            exposure_class_original_irb,
            exposure_class_sa_not_def,
            exposure_class_sec    ,
            limit_type_key,
            limit_type_code,
            limit_type_descr,
            product_type_key,
            product_type_code,
            product_type_descr,
            risk_category_level1_code,
            risk_category_level1_key,
            ing_legal_entity_key,
            ing_legal_entity_code,
            ifrs_accounting_classification,
            ifrs_measurement_category,
            on_balance_sheet_ind,
            on_balance_ind,
            committed_indicator,
            poci_type_key,
            poci_type,
            poci_type_descr,
            advised_indicator,

            forbearance_status_code,
            forbearance_status_key,
            allocated_limit_amt,
            allocated_outstanding_amt,
            exposure_original,
            carrying_amt,
            gross_carrying_amt,
            loan_commitments_given_amt,
            accrued_interest_amt,
            write_off_amt_partial,
            write_off_amt_full,
            ifrs_stage_t0,
            days_pastdue_t0,
            days_pastdue_bucket_t0,
            provision_category_t0,
            alloc_provision_amt_t0,
            on_balance_ratio_ead_t0,
            on_balance_ratio_ca_t0,
            performing_ind_t0,
            risk_rating_key_t0,
            risk_rating_code_t0,
            risk_rating_level2_key_t0,
            risk_rating_level2_code_t0,
            risk_rating_level2_descr_t0,
            ifrs_stage_t_1,
            days_pastdue_t_1,
            days_pastdue_bucket_t_1,
            provision_category_t_1,
            alloc_provision_amt_t_1,
            on_balance_ratio_ead_t_1,
            performing_ind_t_1,
            risk_rating_key_t_1,
            risk_rating_code_t_1,
            risk_rating_level2_key_t_1,
            risk_rating_level2_code_t_1,
            risk_rating_level2_descr_t_1,
            ifrs_stage_prov,
            days_pastdue_prov,
            days_pastdue_bucket_prov,
            provision_category_prov,
            alloc_provision_amt_prov,
            alloc_provision_amt_prov_lc,
            on_balance_ratio_prov,
            performing_ind_prov,
            risk_rating_level2_code_prov,
            sme_ind,
            finrep_instrument_type,
            finrep_instrument_type_key,
            finrep_instrument_type_descr,
            finrep_product_type,
            finrep_product_type_key,
            finrep_product_type_descr,
            finrep_purpose,
            finrep_purpose_key,
            finrep_purpose_descr,
            finrep_subordinate,
            finrep_subordinate_key,
            finrep_subordinate_descr,
            finrep_sector,
            finrep_sector_key,
            finrep_sector_descr,
            finrep_scope_indicator,
            ifrs_eligible_indicator,
            derecognition_reason_key,
            derecognition_reason_code,
            derecognition_reason_descr,
            derecognition_date,
            secured_by_com_prop_ind,
            secured_by_res_prop_ind,
            secured_by_non_mort_ind,
            com_prop_cover_capped_amt,
            com_prop_cover_capped_amt_lc,
            res_prop_cover_capped_amt,
            res_prop_cover_capped_amt_lc,
            cash_cover_capped_amt,
            cash_cover_capped_amt_lc,
            rest_cover_capped_amt,
            rest_cover_capped_amt_lc,
            finan_guar_cover_capped_amt,
            finan_guar_cover_capped_amt_lc,
            --ORAMIGTHIRDCATCHUP START
            mov_prop_cover_capped_amt,
            mov_prop_cover_capped_amt_LC,
            eq_debt_sec_cover_capped_amt,
            eq_debt_sec_cover_capped_amt_LC,
            --ORAMIGTHIRDCATCHUP END
            intercompany_code,
            customer_base_entity_code,
            ing_group_cons_ind,
            ing_bank_solo_ind,
            ing_belgium_cons_ind,
            ing_belgium_solo_ind,
            ing_slaski_solo_ind,
            ing_direct_australia_solo_ind,
            ing_diba_solo_ind,
            ing_turkey_solo_ind,
            ing_eurasia_solo_ind,
            default_ind_t0,
            impaired_ind_t0,
            forbearance_ind_t0,
            default_ind_t_1,
            impaired_ind_t_1,
            forbearance_ind_t_1,
            default_ind_prov,
            impaired_ind_prov,
            forbearance_ind_prov,
            low_credit_risk_ind,
            product_level2_type_code,
            llp_prov_scope_fin_ac_ind_t0,
            llp_prov_scope_fin_ac_ind_t_1,
            llp_prov_scope_fin_ac_ind_prov,
            irrevocable_facility_ind,
            stat_instrument_type_key,
            stat_instrument_type_code,
            stat_instrument_type_descr,
            stat_instrument_subtype_key,
            stat_instrument_subtype_code,
            stat_instrument_subtype_descr,
            stat_sector_key,
            stat_sector_code,
            stat_sector_descr,
            npe_12m_ind_t0,
            npe_12m_ind_t_1,
            npe_12m_ind_prov,
            npe_fb_ind_t0,
            npe_fb_ind_t_1,
            npe_fb_ind_prov,
            llp_meeting_code_t0,
            llp_meeting_key_t0,
            llp_meeting_descr_t0,
            llp_meeting_code_t_1,
            llp_meeting_key_t_1,
            llp_meeting_descr_t_1,
            llp_meeting_code_prov,
            llp_meeting_key_prov,
            llp_meeting_descr_prov,
            acc_neg_changes_fv_cr_t0,
            acc_neg_changes_fv_cr_t_1,
            acc_neg_changes_fv_cr_prov,securitised_ind
            ,securitised_factor
            ,securitisation_code
            ,securitisation_legal_entity_key
            ,securitisation_descr
            ,retained_position_ind
            --ORAMIGTHIRDCATCHUP START
            ,ltv_ratio
            ,ltv_ratio_class
            ,cre_indicator
            --ORAMIGTHIRDCATCHUP END
            ,gross_carrying_amt_prev_Q4  --ORAMIGCATCHUP4
            ,performing_ind_prev_Q4 --ORAMIGCATCHUP4
            ,finrep_record_type
            -----------------Start of vdd_rrd_catchup_124----------------
            ,segmentation_type_key
            ,accounting_unit_key
            -----------------End of vdd_rrd_catchup_124----------------
            ,cred_deriv_cover_capped_amt
            ,cred_deriv_cover_capped_amt_LC
            ,CREDIT_COMMITMENT_IND --6100295
)
            ( SELECT --top 10
                fbi.reporting_period,
                fbi.record_valid_from,
                fbi.record_valid_until,
                fbi.system_id,
                fbi.source,
                fbi.facility_key,
                fbi.facility_id,
                fbi.higher_level_facility_key,
                fbi.higher_level_facility_id,
                fbi.outstanding_group_id,
                fbi.outstanding_group_key,
                fbi.local_outstanding_id,
                fbi.outstanding_id,
                fbi.outstanding_key,
                fbi.customer_id,
                fbi.customer_key,
                fbi.instrument_id,
                fbi.instrument_type,
                fbi.os_booking_office_key os_booking_office_key,
                bo.code os_booking_office_code,
                fbi.os_booking_base_entity_key os_booking_base_entity_key,
                bobe.code os_booking_base_entity_code,
                bobe.code || bobe.description os_booking_base_entity_descr,         --NJ:SYMBOL '+' CHANGED TO '||' TO RESOLVE 'INVALD NUMBER' : 29-08-2019
                fbi.os_initiating_office_key os_initiating_office_key,
                io.code os_initiating_office_code,
                fbi.os_initiating_base_entity_key os_initiating_base_entity_key,
                iobe.code os_initiating_base_entity_code,
                iobe.code || iobe.description os_initiating_base_entity_descr,      --NJ:SYMBOL '+' CHANGED TO '||' TO RESOLVE 'INVALD NUMBER' : 29-08-2019
                fbi.fac_booking_office_key fac_booking_office_key,
                fac_bo.code fac_booking_office_code,
                fbi.fac_booking_base_entity_key fac_booking_base_entity_key,
                fac_bobe.code fac_booking_base_entity_code,
                fac_bobe.code || fac_bobe.description fac_booking_base_entity_descr,   --NJ:SYMBOL '+' CHANGED TO '||' TO RESOLVE 'INVALD NUMBER' : 29-08-2019
                fbi.fac_initiating_office_key fac_initiating_office_key,
                fac_io.code fac_initiating_office_code,
                fbi.fac_initiating_base_entity_key fac_initiating_base_entity_key,
                fac_iobe.code fac_initiating_base_entity_code,
                fac_iobe.code || fac_iobe.description fac_initiating_base_entity_descr,    --NJ:SYMBOL '+' CHANGED TO '||' TO RESOLVE 'INVALD NUMBER' : 29-08-2019
                fbi.customer_type_key customer_type_key,
                ct.code customer_type_code,
                ct.description customer_type_descr,
                fbi.industry_type_key,
                CAST('' AS VARCHAR2(30) ) industry_type_code,--------  confirm
                CAST('' AS VARCHAR2(100) ) industry_type_nace_2_0,
                CAST('' AS VARCHAR2(30) ) nace_highest_level_code,----- confirm
                fbi.residence_country_key,
                res_ctry.code residence_country_code,
                res_ctry.country_name residence_country_name,
                res_ctry.regulatory_country regulatory_country_code,
                reg_ctry.country_key regulatory_country_key,
                substr(reg_ctry.country_name,0,10) regulatory_country_name,
                fbi.basel_official_approach,
                fbi.exposure_class_original_sa,
                fbi.exposure_class_original_irb,
                fbi.exposure_class_sa_not_def,
                fbi.exposure_class_sec,
                fbi.facility_type_key limit_type_key,
                fac_ty.code limit_type_code,
                fac_ty.description limit_type_descr,
                fbi.product_type_key,
                pt.code product_type_code,
                pt.description product_type_descr,
                pt.highest_level_code risk_category_level1_code,
                pt.highest_level_key risk_category_level1_key,
                fbi.ing_legal_entity_key ing_legal_entity_key,
                fbi.ing_legal_entity_code ing_legal_entity_code,
                acl_ifrs.code ifrs_accounting_classification,
                mc_ifrs.code ifrs_measurement_category,
                fbi.on_balance_sheet_ind,
                fbi.on_balance_sheet_ind,
                fbi.committed_indicator,
                fbi.poci_tp_key poci_type_key,
                poci.code poci_type,
                poci.dsc poci_type_descr,
                ai.code advised_indicator,
                fs.code forbearance_status_code,
                fbi.forbearance_status_key,
                fbi.allocated_limit_amt allocated_limit_amt,
                fbi.allocated_outstanding_amt allocated_outstanding_amt,
                fbi.exposure_original exposure_original,
                cast('' as number(22,4)) carrying_amt,
                fbi.gross_carrying_amt gross_carrying_amt,
                CASE
                      /*WHEN fpt.higher_level_code = 'LOAN_ADV'*/ --Commented for 6189998
                        WHEN fpt.higher_level_code IN ('LOAN_ADV', 'FINAN_GUAR', 'OTH_COMMT') --Added for 6189998
                        THEN fbi.commit_undrawn_amount
                        ELSE 0
                END loan_commitments_given_amt,
                cast('' as number(22,4)) accrued_interest_amt,
                cast('' as number(22,4)) write_off_amt_partial,
                cast('' as number(22,4)) write_off_amt_full,
                diog.ifrs_stage ifrs_stage_t0,
                fbi.days_pastdue days_pastdue_t0,
                CAST('' AS VARCHAR2(100) ) days_pastdue_bucket_t0,
                CAST(diog.provision_category AS VARCHAR2(10) ) provision_category_t0,
                diog.provision_amount alloc_provision_amt_t0,
				fbi.on_balance_ratio_ead on_balance_ratio_ead_t0, --3286312 removed the CASE statement as bug fix
                CASE
                        WHEN fpt.higher_level_code = 'LOAN_ADV'
                             -- AND fbi.committed_indicator = 'C' -- Commented for #6100334
							 AND fbi.credit_commitment_ind in ( 'CCC', 'UCC') -- Added for #6100334
                             AND ( allocated_limit_amt - gross_carrying_amt ) > 0
                        THEN fbi.on_balance_ratio_drawn
                        ELSE 1
                END on_balance_ratio_ca_t0,
                CASE
                        WHEN rr.in_default = 'Y'
                        THEN 'N'
                        ELSE 'Y'
                END performing_ind_t0,
                rr.risk_rating_key risk_rating_key_t0,
                fbi.risk_rating_code risk_rating_code_t0,
                CAST('' AS NUMBER(12)) risk_rating_level2_key_t0,
                CAST('' AS VARCHAR2(10) ) risk_rating_level2_code_t0,
                CAST('' AS VARCHAR2(100) ) risk_rating_level2_descr_t0,
                CAST('' AS VARCHAR2(10) ) ifrs_stage_t_1,
                CAST('' AS NUMBER(12)) days_pastdue_t_1,
                CAST('' AS VARCHAR2(100) ) days_pastdue_bucket_t_1,
                CAST('' AS VARCHAR2(10) ) provision_category_t_1,
                cast('' as number(22,4)) alloc_provision_amt_t_1,
                CAST('' AS NUMBER(10,8)) on_balance_ratio_ead_t_1,
                CAST('' AS VARCHAR2(1) ) performing_ind_t_1,
                CAST('' AS VARCHAR2(10) ) risk_rating_key_t_1,
                CAST('' AS VARCHAR2(10) ) risk_rating_code_t_1,
                CAST('' AS NUMBER(12)) risk_rating_level2_key_t_1,
                CAST('' AS VARCHAR2(10) ) risk_rating_level2_code_t_1,
                CAST('' AS VARCHAR2(100) ) risk_rating_level2_descr_t_1,
                CAST('' AS VARCHAR2(10) ) ifrs_stage_prov,
                CAST('' AS NUMBER(12)) days_pastdue_prov,
                CAST('' AS VARCHAR2(100) ) days_pastdue_bucket_prov,
                CAST('' AS VARCHAR2(10) ) provision_category_prov,
                cast('' as number(22,4)) alloc_provision_amt_prov,
                cast('' as number(22,4)) alloc_provision_amt_prov_lc,
                CAST('' AS NUMBER(10,8)) on_balance_ratio_prov,
                CAST('' AS VARCHAR2(1) ) performing_ind_prov,
                CAST('' AS VARCHAR2(10) ) risk_rating_level2_code_prov,
                CAST('' AS VARCHAR2(1) ) sme_ind,
                CASE
                        WHEN fpt.higher_level_code IS NOT NULL
                        THEN fpt.higher_level_code
                        ELSE 'N/A'
                END finrep_instrument_type,
                CAST('' AS NUMBER(12)) finrep_instrument_type_key,
                substr(CAST('' AS VARCHAR2(30) ),1,30) finrep_instrument_type_descr, --pn added merge for fix STRY1210993
                CASE
                        WHEN pt.finrep_product_type IS NOT NULL
                        THEN pt.finrep_product_type
                        ELSE 'N/A'
                END finrep_product_type,
                CAST(fpt.finrep_product_type_key AS NUMBER(12)) finrep_product_type_key,
                CAST(fpt.description AS VARCHAR2(30) ) finrep_product_type_descr,
                CAST('' AS VARCHAR2(30) ) finrep_purpose,
                CAST('' AS NUMBER(12)) finrep_purpose_key,
                CAST('' AS VARCHAR2(30) ) finrep_purpose_descr,
                fbi.finrep_subordinate finrep_subordinate,
                sub.finrep_subordinate_key finrep_subordinate_key,
                sub.description finrep_subordinate_descr,
                NULL finrep_sector,
                NULL finrep_sector_key,
                CAST('' AS VARCHAR2(30) ) finrep_sector_descr,
                CAST('' AS VARCHAR2(1) ) finrep_scope_indicator,
                diog.ifrs9_eligible ifrs_eligible_indicator,
                fbi.derecognition_reason_key derecognition_reason_key,
                dr.code derecognition_reason_code,
                dr.dsc derecognition_reason_descr,
                fbi.derecognition_date,
                CAST('' AS VARCHAR2(1) ) secured_by_com_prop_ind,
                CAST('' AS VARCHAR2(1) ) secured_by_res_prop_ind,
                CAST('' AS VARCHAR2(1) ) secured_by_non_mort_ind,
                cast('' as number(22,4)) com_prop_cover_capped_amt,
                cast('' as number(22,4)) com_prop_cover_capped_amt_lc,
                cast('' as number(22,4)) res_prop_cover_capped_amt,
                cast('' as number(22,4)) res_prop_cover_capped_amt_lc,
                cast('' as number(22,4)) cash_cover_capped_amt,
                cast('' as number(22,4)) cash_cover_capped_amt_lc,
                cast('' as number(22,4)) rest_cover_capped_amt,
                cast('' as number(22,4)) rest_cover_capped_amt_lc,
                cast('' as number(22,4)) finan_guar_cover_capped_amt,
                cast('' as number(22,4)) finan_guar_cover_capped_amt_lc,
                cast('' as number(22,4)) as mov_prop_cover_capped_amt,
                cast('' as number(22,4))as mov_prop_cover_capped_amt_LC,
                cast('' as number(22,4)) as eq_debt_sec_cover_capped_amt,
                cast('' as number(22,4)) as eq_debt_sec_cover_capped_amt_LC,
                CAST('' AS VARCHAR2(10) ) intercompany_code,
                CAST('' AS VARCHAR2(10) ) customer_base_entity_code,
                0 ing_group_cons_ind,
                0 ing_bank_solo_ind,
                0 ing_belgium_cons_ind,
                0 ing_belgium_solo_ind,
                0 ing_slaski_solo_ind,
                0 ing_direct_australia_solo_ind,
                0 ing_diba_solo_ind,
                0 ing_turkey_solo_ind,
                0 ing_eurasia_solo_ind,
                CASE
                        WHEN rr.in_default = 'Y' THEN
                            'Y'
                        ELSE 'N'
                    END
                default_ind_t0,
                CASE
                        WHEN rr.in_default = 'Y' THEN
                            'Y'
                        ELSE 'N'
                    END
                impaired_ind_t0,
                'N'  as forbearance_ind_T0,  -- defaulted to N, updated later,
                NULL default_ind_t_1,
                NULL impaired_ind_t_1,
                NULL forbearance_ind_t_1,
                NULL default_ind_prov,
                NULL impaired_ind_prov,
                NULL forbearance_ind_prov,
                'N' low_credit_risk_ind,
                CAST('' AS VARCHAR2(10) ) product_level2_type_code,--START EXTRA ATTRIBUTES STRY0504366
                'N' llp_prov_scope_fin_ac_ind_t0,
                CAST('' AS VARCHAR2(1) ) llp_prov_scope_fin_ac_ind_t_1,
                NULL llp_prov_scope_fin_ac_ind_prov,
                'N' irrevocable_facility_ind,
                NULL stat_instrument_type_key,
                '6' stat_instrument_type_code,
                NULL stat_instrument_type_descr,
                NULL stat_instrument_subtype_key,
                '6' stat_instrument_subtype_code,
                NULL stat_instrument_subtype_descr,
                NULL stat_sector_key,
                '6' stat_sector_code,
                NULL stat_sector_descr,
                'N' npe_12m_ind_t0,
                CAST('' AS VARCHAR2(1) ) npe_12m_ind_t_1,
                NULL npe_12m_ind_prov,
                'N' npe_fb_ind_t0,
                CAST('' AS VARCHAR2(1) ) npe_fb_ind_t_1,
                NULL npe_fb_ind_prov,
                'NA' llp_meeting_code_t0,
                NULL llp_meeting_key_t0,
                NULL llp_meeting_descr_t0,
                CAST('' AS VARCHAR2(1) ) llp_meeting_code_t_1,
                NULL llp_meeting_key_t_1,
                NULL llp_meeting_descr_t_1,
                NULL llp_meeting_code_prov,
                NULL llp_meeting_key_prov,
                NULL llp_meeting_descr_prov,
                0 acc_neg_changes_fv_cr_t0,
                cast('' as number(22,4)) acc_neg_changes_fv_cr_t_1,
                NULL acc_neg_changes_fv_cr_prov,
                CASE WHEN fbi.securitised_factor > 0 AND fbi.securitisation_code IS NOT NULL AND fbi.sts_ind = 'NON-STS'
                     THEN 1
                     WHEN fbi.sts_ind = 'NON-STS'
                     THEN 0
                     WHEN fbi.sts_ind = 'STS'
                     THEN  fbi.securitised_ind
                END  AS securitised_ind
                , nvl(fbi.securitised_factor, 0) AS securitised_factor
                , fbi.securitisation_code
                , NULL AS securitisation_legal_entity_key
                , NULL AS securitisation_descr
                , CASE WHEN exposure_class_original_irb = 'SEC_ORIG' AND fbi.sts_ind = 'NON-STS'
                       THEN 1
                       WHEN exposure_class_sec = 'SEC_ORIG' AND fbi.sts_ind = 'NON-STS'
                       THEN 1
                       WHEN fbi.sts_ind = 'NON-STS'
                       THEN 0
                       WHEN fbi.sts_ind = 'STS'
                       THEN  fbi.retained_position_ind
                  END AS retained_position_ind
                --ORAMIGTHIRDCATCHUP START
                , fbi.ltv_ratio AS ltv_ratio
                , null AS ltv_ratio_class
                ,CASE WHEN dcf.finrep_reporting_ind = 'Y' then 'Y' else 'N' END AS cre_indicator --ADDED FOR STORY 2189568(cre_indicator population)
                , NULL AS gross_carrying_amt_prev_Q4  --ORAMIGCATCHUP4
                , NULL AS performing_ind_prev_Q4  --ORAMIGCATCHUP4
                , 'ORIGINAL' AS finrep_record_type
                -----------------Start of vdd_rrd_catchup_124----------------
                , fbi.segmentation_type_key
                , fbi.accounting_unit_key
                 -----------------End of vdd_rrd_catchup_124----------------
                 , NULL AS cred_deriv_cover_capped_amt  --CU6
                , NULL AS cred_deriv_cover_capped_amt_LC --CU6
                ,fbi.CREDIT_COMMITMENT_IND --6100295
              FROM
                tt_tmp_finrep_basic_info fbi
                JOIN office bo
                ON  fbi.os_booking_office_key   = bo.office_key
                JOIN office io
                ON  fbi.os_initiating_office_key   = io.office_key
                LEFT JOIN office_base_entity bobe
                ON  bobe.record_valid_from <= v_reporting_date
                    AND (bobe.record_valid_until IS NULL OR bobe.record_valid_until > v_reporting_date)
                    AND fbi.os_booking_base_entity_key   = bobe.office_base_entity_key
                LEFT JOIN office_base_entity iobe
                ON iobe.record_valid_from <= v_reporting_date
                    AND (iobe.record_valid_until IS NULL OR iobe.record_valid_until > v_reporting_date)
                    AND fbi.os_initiating_base_entity_key   = iobe.office_base_entity_key
                JOIN office fac_bo
                ON fbi.fac_booking_office_key   = fac_bo.office_key
                LEFT JOIN office_base_entity fac_bobe
                ON fac_bobe.record_valid_from <= v_reporting_date
                    AND (fac_bobe.record_valid_until IS NULL OR fac_bobe.record_valid_until > v_reporting_date )
                    AND fbi.fac_booking_base_entity_key   = fac_bobe.office_base_entity_key
                JOIN office fac_io
                ON fbi.fac_initiating_office_key   = fac_io.office_key
                LEFT JOIN office_base_entity fac_iobe
                ON fac_iobe.record_valid_from <= v_reporting_date
                    AND (fac_iobe.record_valid_until IS NULL OR fac_iobe.record_valid_until > v_reporting_date)
                    AND fbi.fac_initiating_base_entity_key   = fac_iobe.office_base_entity_key
                JOIN customer_type ct
                ON fbi.customer_type_key    = ct.customer_type_key
                JOIN tt_facility_type fac_ty
                ON fbi.facility_type_key    = fac_ty.facility_type_key
                    AND fac_ty.level_number = 5
                JOIN tt_facility_type pt
                ON pt.level_number   = 6 AND fbi.product_type_key   = pt.facility_type_key
                JOIN country res_ctry
                ON fbi.residence_country_key   = res_ctry.country_key
                LEFT JOIN country reg_ctry
                ON reg_ctry.record_valid_from <= v_reporting_date
                    AND (reg_ctry.record_valid_until IS NULL OR reg_ctry.record_valid_until > v_reporting_date)
                    AND res_ctry.regulatory_country   = reg_ctry.code
                LEFT JOIN acg_cl_ifrs acl_ifrs
                ON fbi.ifrs9_accounting_classification_key   = acl_ifrs.acg_cl_ifrs_key
                LEFT JOIN msr_cgy_ifrs mc_ifrs
                ON fbi.ifrs9_measurement_category_key   = mc_ifrs.msr_cgy_ifrs_key
                LEFT JOIN adv_ind ai
                ON fbi.advised_key   = ai.adv_ind_key
                LEFT JOIN frbc_st fs
                ON fbi.forbearance_status_key   = fs.frbc_st_key
                LEFT JOIN poci_tp poci
                ON fbi.poci_tp_key   = poci.poci_tp_key
                LEFT JOIN risk_rating rr
                ON fbi.risk_rating_code   = rr.code AND rr.record_valid_from <= v_reporting_date
                    AND (rr.record_valid_until IS NULL OR rr.record_valid_until > v_reporting_date)
                LEFT JOIN finrep_subordinate sub
                ON sub.record_valid_from <= v_reporting_date
                    AND (sub.record_valid_until IS NULL OR sub.record_valid_until > v_reporting_date)
                    AND fbi.finrep_subordinate   = sub.finrep_subordinate_id
                LEFT JOIN drgn_rsn dr
                ON fbi.derecognition_reason_key   = dr.drgn_rsn_key
                LEFT JOIN tt_finrep_product_type fpt
                ON fpt.record_valid_from <= v_reporting_date
                    AND (fpt.record_valid_until IS NULL OR fpt.record_valid_until > v_reporting_date)
                    AND pt.finrep_product_type   = fpt.finrep_product_type_id
                JOIN dwh_ifrs_outstanding_group diog
                ON fbi.outstanding_group_key   = diog.outstanding_group_key AND diog.record_valid_from = v_reporting_date AND   diog.system_id = v_system_id
                LEFT JOIN DWH_CRE_FACILITY dcf ON (dcf.facility_key = fbi.facility_key AND dcf.record_valid_from = v_reporting_date AND dcf.system_id = v_system_id) --ADDED FOR STORY 2189568(cre_indicator population)
            );

    EXCEPTION
        WHEN OTHERS THEN utils.handleerror(sqlcode,sqlerrm);
    END;

    v_debug_msg := $$plsql_line || ' of unit ' || $$plsql_unit || '<<dm count>>' || SQL%rowcount;

    utilities.show_debug(v_debug_msg);
	commit; --per fix
    schema_maint.gather_idx_stats('tmp_vpp_finrep_details_info'); --added for performance jt
    ---ORAMIGSecondcatchup ? Begin
    BEGIN
   IF v_debug = 1 THEN

   BEGIN
      utilities.show_debug (REPLACE('[%1!] 2 b. UPDATE forbearance columns', '%1!', SYSTIMESTAMP));

   END;
   END IF;



-- UPDATE /*+ PARALLEL enable_parallel_dml */  the securitisation columns
MERGE /*+ enable_parallel_dml */ INTO tmp_VPP_FINREP_DETAILS_INFO fd
USING (SELECT fd.ROWID row_id, sle.securitisation_descr, sle.securitisation_legal_entity_key
FROM tmp_VPP_FINREP_DETAILS_INFO fd
       JOIN securitisation_legal_entity sle   ON sle.code = fd.securitisation_code
       AND sle.record_valid_from <= v_reporting_date
       AND ( sle.record_valid_until IS NULL
       OR sle.record_valid_until > v_reporting_date ) ) src
ON ( fd.ROWID = src.row_id )
WHEN MATCHED THEN UPDATE  SET fd.securitisation_descr = src.securitisation_descr,
                             fd.securitisation_legal_entity_key = src.securitisation_legal_entity_key;

commit; --per fix

--ORAMIGTHIRDCATCHUP START
-- UPDATE /*+ PARALLEL enable_parallel_dml */  DPD bucketing
/*MERGE INTO tmp_VPP_FINREP_DETAILS_INFO fdi
USING (SELECT fdi.ROWID row_id, f.finrep_ltv_class_id
FROM tmp_VPP_FINREP_DETAILS_INFO fdi,finrep_ltv_class f
 WHERE fdi.reporting_period = v_reporting_date
  AND fdi.system_id = v_system_id
  AND fdi.ltv_ratio IS NOT NULL
  AND f.low_value <= fdi.ltv_ratio
  AND f.high_value >= fdi.ltv_ratio
  AND f.record_valid_until IS NULL) src
ON ( fdi.ROWID = src.row_id )
WHEN MATCHED THEN UPDATE   SET fdi.ltv_ratio_class = src.finrep_ltv_class_id;*/

 MERGE /*+ enable_parallel_dml */ INTO
 (Select reporting_period,system_id,ltv_ratio,ltv_ratio_class
   from tmp_VPP_FINREP_DETAILS_INFO fdi
    where FDI.REPORTING_PERIOD = v_reporting_date AND FDI.SYSTEM_ID = v_system_id) fdi
  USING finrep_ltv_class  src
ON ( fdi.reporting_period = v_reporting_date
  AND fdi.system_id = v_system_id
  AND fdi.ltv_ratio IS NOT NULL
  AND src.low_value <= fdi.ltv_ratio
  AND src.high_value >= fdi.ltv_ratio
  AND src.record_valid_until IS NULL )
WHEN MATCHED THEN UPDATE  SET fdi.ltv_ratio_class = src.finrep_ltv_class_id;

    --Added hint, modified whole table scan to filtered data to reduce data set  --AB Per fix
commit; --per fix
--ORAMIGTHIRDCATCHUP END


END;
    --PK:Merge Modification : 18-07-2019
    BEGIN
        MERGE /*+ enable_parallel_dml */ INTO tmp_VPP_FINREP_DETAILS_INFO fd
        USING (SELECT /*+ NO_INDEX(f) */ fm1.frbc_msr_key, fm1.code, fm1.dsc, CASE
        WHEN ( fm.code <> fm.mod_rfn ) THEN f.forbearance_measure_key
        ELSE NULL
           END AS pos_5, CASE
        WHEN ( fm.code <> fm.mod_rfn ) THEN fm.code
        ELSE NULL
           END AS pos_6, CASE
        WHEN ( fm.code <> fm.mod_rfn ) THEN fm.dsc
        ELSE NULL
           END AS pos_7,
           f.facility_key,
           f.record_valid_from, -- added to improve performance
           f.system_id
        FROM dwh_facility f
               JOIN frbc_msr fm   ON fm.frbc_msr_key = f.forbearance_measure_key
               JOIN frbc_msr fm1   ON fm1.code = fm.mod_rfn
               AND fm1.record_valid_until IS NULL
         WHERE f.record_valid_from = v_reporting_date AND   f.system_id = v_system_id      ) src
        ON ( src.facility_key = fd.facility_key )
        WHEN MATCHED THEN UPDATE SET fd.forbearance_measure_key = src.frbc_msr_key,
                                     fd.forbearance_measure_code = src.code,
                                     fd.forbearance_measure_descr = src.dsc,
                                     fd.forbearance_measure_1_key -- not level 1
                                      = pos_5,
                                     fd.forbearance_measure_1_code -- not level 1
                                      = pos_6,
                                     fd.forbearance_measure_1_descr -- not level 1
                                      = pos_7,
                                     fd.forbearance_ind_T0 = CASE WHEN ( fd.forbearance_status_key IS NOT NULL ) THEN 'Y' ELSE 'N' END;
    EXCEPTION WHEN OTHERS THEN
        utils.handleerror(sqlcode,sqlerrm);
    END;

commit; --per fix
    --PK:Merge Modifications : 18-07-2019
    BEGIN
        MERGE /*+ enable_parallel_dml */ INTO tmp_VPP_FINREP_DETAILS_INFO fd--rajiv
            USING (SELECT /*+ NO_INDEX(f) */ fm2.frbc_msr_key pos_1, fm2.code pos_2, fm2.dsc pos_3, fm3.frbc_msr_key pos_4, fm3.code pos_5, fm3.dsc pos_6, fm4.frbc_msr_key pos_7, fm4.code pos_8 ,
            fm4.dsc pos_9, fm5.frbc_msr_key pos_10, fm5.code pos_11, fm5.dsc pos_12, f.facility_key,
            f.record_valid_from,f.system_id --added to improve performance
            FROM dwh_facility f
                   LEFT JOIN frbc_msr fm2   ON fm2.frbc_msr_key = f.forbearance_measure_2_key
                   LEFT JOIN frbc_msr fm3   ON fm3.frbc_msr_key = f.forbearance_measure_3_key
                   LEFT JOIN frbc_msr fm4   ON fm4.frbc_msr_key = f.forbearance_measure_4_key
                   LEFT JOIN frbc_msr fm5   ON fm5.frbc_msr_key = f.forbearance_measure_5_key
             WHERE f.record_valid_from = v_reporting_date AND   f.system_id = v_system_id      ) src
            ON ( src.facility_key = fd.facility_key )
        WHEN MATCHED THEN UPDATE SET fd.forbearance_measure_2_key = src.pos_1,
                                     fd.forbearance_measure_2_code = src.pos_2,
                                     fd.forbearance_measure_2_descr = src.pos_3,
                                     fd.forbearance_measure_3_key = src.pos_4,
                                     fd.forbearance_measure_3_code = src.pos_5,
                                     fd.forbearance_measure_3_descr = src.pos_6,
                                     fd.forbearance_measure_4_key = src.pos_7,
                                     fd.forbearance_measure_4_code = src.pos_8,
                                     fd.forbearance_measure_4_descr = src.pos_9,
                                     fd.forbearance_measure_5_key = src.pos_10,
                                     fd.forbearance_measure_5_code = src.pos_11,
                                     fd.forbearance_measure_5_descr = src.pos_12;
    EXCEPTION WHEN OTHERS THEN
        utils.handleerror(sqlcode,sqlerrm);
    END;
	commit; --per fix

      -- Updating the IFRS9 Stage details which need to be used to report the carrying amounts
    IF v_debug = 1 THEN
        BEGIN
            utilities.show_debug (replace('[%1!] 3 a. Updating the IFRS9 Stage details','%1!',systimestamp) );
        END;
    END IF;

    utilities.truncate_table('tt_tmp_FINREP_BASIC_INFO');
    --PK:Merge Modifications : 18-07-2019
    BEGIN
        MERGE /*+ enable_parallel_dml */ INTO tmp_vpp_finrep_details_info fdi USING ( SELECT
            diog.ifrs_stage,
            diog.provision_category,
            diog.provision_amount,
            diog.system_id,
            diog.customer_key,
            diog.facility_key,
            diog.outstanding_group_key
                                                       FROM
            dwh_ifrs_outstanding_group diog
            WHERE
            diog.record_valid_from = v_reporting_date
            AND   diog.system_id = v_system_id )
        src ON ( fdi.customer_key = src.customer_key
                AND fdi.facility_key = src.facility_key AND fdi.outstanding_group_key = src.outstanding_group_key
                AND fdi.reporting_period = v_reporting_date AND fdi.system_id = v_system_id)
        WHEN MATCHED THEN UPDATE SET fdi.ifrs_stage_t0 = src.ifrs_stage,
        fdi.provision_category_t0 = src.provision_category,
        fdi.alloc_provision_amt_t0 = src.provision_amount;
    EXCEPTION
        WHEN OTHERS THEN
            utils.handleerror(
                sqlcode,
                sqlerrm
            );
    END;

    v_debug_msg := $$plsql_line || ' of unit ' || $$plsql_unit || '<<dm count>>' || SQL%rowcount;
    utilities.show_debug(v_debug_msg);
	commit; --per fix
    --PK:Merge Modifications : 18-07-2019
    BEGIN
        MERGE /*+ enable_parallel_dml */ INTO tmp_vpp_finrep_details_info fdi USING ( SELECT
            o.code,
            o.low_value,
            o.high_value,
            o.record_valid_until
            FROM finrep_pastdue_bucket o )
        src ON ( fdi.reporting_period = v_reporting_date
            AND   fdi.system_id = v_system_id AND src.low_value <= nvl(fdi.days_pastdue_t0,0)
            AND   src.high_value >= nvl(fdi.days_pastdue_t0,0)
            AND   src.record_valid_until IS NULL )
        WHEN MATCHED THEN UPDATE SET fdi.days_pastdue_bucket_t0 = src.code;

    EXCEPTION
        WHEN OTHERS THEN
            utils.handleerror(
                sqlcode,
                sqlerrm
            );
    END;

    v_debug_msg := $$plsql_line || ' of unit ' || $$plsql_unit || '<<dm count>>' || SQL%rowcount;

    utilities.show_debug(v_debug_msg);
	commit; --per fix
      -- COMMIT
      -- Updating the T-1 provisions details
    IF v_debug = 1 THEN
        BEGIN
            utilities.show_debug (replace('[%1!] 3 b. Updating the T-1 provisions details and rating details','%1!',systimestamp) );
        END;
    END IF;
commit;


--------------------------------------------
--SD : Performance fix
--------------------------------------------

   utilities.truncate_table('TMP_VPP_STG_INSERT');
    INSERT /*+ APPEND */ INTO TMP_VPP_STG_INSERT
   (
    IFRS_STAGE,DAYS_PAST_DUE,PROVISION_CATEGORY,COMMITTED_INDICATOR,EXPOSURE_CREDIT,
    GROSS_CARRYING_AMOUNT,PROVISION_AMOUNT,ALLOCATED_LIMIT_AMOUNT,CUSTOMER_ID,FACILITY_ID,LOCAL_OUTSTANDING_ID,
    RATING_ORIGINAL,INTERNAL_RATING,RISK_RATING_MASTER_SCALE,EXPOSURE_CLASS_ORIGINAL,
    POS_12,
    CREDIT_COMMITMENT_IND,
    OUTSTANDING_GROUP_KEY,SYSTEM_ID)
    SELECT /*+ NO_INDEX(dvb) NO_INDEX(fac) parallel */ iog.ifrs_stage,dog.days_past_due,iog.provision_category,fac.committed_indicator,iog.exposure_credit,
                   iog.gross_carrying_amount,iog.provision_amount,iog.allocated_limit_amount,dog.customer_id,dog.facility_id,dog.local_outstanding_id,
                   dvb.rating_original,dvr.internal_rating,ers.risk_rating_master_scale,dvr.exposure_class_original,
                   CASE WHEN (fac.forbearance_measure_key IS NULL OR fac.forbearance_status_key IS NULL) THEN 'N' ELSE 'Y' END AS pos_12
					,cci.code as CREDIT_COMMITMENT_IND --6100295	
                    ,dog.outstanding_group_key --Added for 7009457
                    ,v_system_id --Added for 7009457									   
    FROM dwh_outstanding_group dog
    JOIN dwh_ifrs_outstanding_group iog ON iog.record_valid_from = v_reporting_date_t_1
                                        AND iog.system_id = v_system_id --7009457	
                                        AND dog.system_id =  v_system_id --7009457
                                        AND dog.record_valid_from = v_reporting_date_t_1
                                        AND iog.outstanding_group_key = dog.outstanding_group_key
    -- LEFT JOIN dwh_vbr_basel2 dvb 
    LEFT JOIN dwh_recapb4_outstanding_group dvb -- Changed source for #4857458
								 ON dvb.record_valid_from = v_reporting_date_t_1
                                 AND dvb.system_id = v_system_id  --7009457
                                 AND dvb.customer_key = iog.customer_key
                                 AND dvb.facility_key = iog.facility_key
                                 AND dvb.outstanding_group_key = iog.outstanding_group_key
    -- LEFT OUTER JOIN dwh_vre_securitisation_recap dvr 
    LEFT OUTER JOIN dwh_vre_securitisation_recapb4 dvr -- Changed source for #4857458
													 ON dvr.record_valid_from = v_reporting_date_t_1  -- ratings for STS securitisations
                                                     AND dvr.system_id = v_system_id  --7009457
                                                     AND dvr.cover_key IS NULL --added extra condition as per RRD BA's
                                                     AND dvr.customer_key = iog.customer_key
                                                     AND dvr.facility_key = iog.facility_key
                                                     AND dvr.outstanding_group_key = iog.outstanding_group_key
    LEFT OUTER JOIN rating_agency ra ON dvr.rating_agency = ra.rating_agency_key
                                     AND ra.record_valid_from <= dvr.record_valid_from
                                     AND (ra.record_valid_until > dvr.record_valid_from or ra.record_valid_until is null)
    LEFT OUTER JOIN external_rating_scale ers ON  ers.external_rating_scale = dvr.external_rating
                                              AND ra.code = ers.rating_agency_code
                                              AND ers.rating_type = 'LR'
                                              AND ers.record_valid_from <= dvr.record_valid_from
                                              AND (ers.record_valid_until > dvr.record_valid_from or ers.record_valid_until is null)
    JOIN dwh_facility fac ON fac.facility_key = iog.facility_key
                          AND fac.record_valid_from = v_reporting_date_t_1
                          AND fac.system_id =  v_system_id --7009457
                         -- AND nvl(fac.crr2_calc_ind,'Y') != 'N' --added for story 4054104
						 AND NVL(fac.crr3_calc_ind,'Y') != 'N' -- added for story #4857458
    -- #4857458 end
    LEFT JOIN credit_commitment_ind cci --6100295
        ON cci.credit_commitment_ind_key = fac.credit_commitment_key
        AND cci.RECORD_VALID_FROM <= v_reporting_date
        AND (nvl(cci.record_valid_until,utilities.record_default_date) > v_reporting_date );
    utilities.show_debug($$plsql_line || ' of unit ' || $$plsql_unit || '<<dm count>>' || SQL%rowcount);
    schema_maint.gather_idx_stats('TMP_VPP_STG_INSERT');
    COMMIT;

    BEGIN
           MERGE /*+ enable_parallel_dml */ INTO (SELECT customer_id,facility_id,local_outstanding_id,finrep_instrument_type,exposure_class_sec,ifrs_stage_t_1,days_pastdue_t_1,provision_category_t_1,
                                                         performing_ind_t_1,alloc_provision_amt_t_1,risk_rating_code_t_1,risk_rating_key_t_1,on_balance_ratio_ead_t_1,default_ind_t_1,impaired_ind_t_1,
                                                         forbearance_ind_t_1,gross_carrying_amt_t_1
                                                         ,outstanding_group_key  --Added for 7009457
                                                         ,system_id  --Added for 7009457
                                                  FROM tmp_vpp_finrep_details_info
                                                  WHERE reporting_period = v_reporting_date
                                                  AND system_id = v_system_id)tmp USING
           (SELECT /*+ PARALLEL */ vtm.*,rr.code,rr.risk_rating_key,CASE WHEN rr.in_default = 'Y' THEN 'N' ELSE 'Y' END AS pos_5,
           CASE WHEN rr.in_default = 'Y' THEN 'Y' ELSE 'N' END AS pos_6
            FROM TMP_VPP_STG_INSERT vtm
            JOIN risk_rating rr ON rr.record_valid_from <= v_reporting_date_t_1
                                AND (rr.record_valid_until IS NULL OR rr.record_valid_until > v_reporting_date_t_1)
                                AND rr.code = CASE WHEN vtm.exposure_class_original IS NULL THEN vtm.rating_original
                                                    ELSE CASE WHEN vtm.internal_rating IS NOT NULL THEN vtm.internal_rating
                                                              ELSE vtm.risk_rating_master_scale
                                                         END
                                               END
           )src
           ON (src.customer_id = tmp.customer_id AND src.facility_id = tmp.facility_id AND src.local_outstanding_id = tmp.local_outstanding_id
               AND src.system_id = tmp.system_id --Added for 7009457
              )
           WHEN MATCHED THEN UPDATE SET tmp.ifrs_stage_t_1 = src.ifrs_stage,
                                        tmp.days_pastdue_t_1 = src.days_past_due,
                                        tmp.provision_category_t_1 = src.provision_category,
                                        tmp.performing_ind_t_1 = pos_5,
                                        tmp.alloc_provision_amt_t_1 = src.provision_amount,
                                        tmp.risk_rating_code_t_1 = src.code,
                                        tmp.risk_rating_key_t_1 = src.risk_rating_key,
                                        tmp.on_balance_ratio_ead_t_1 = CASE WHEN tmp.finrep_instrument_type = 'LOAN_ADV' 
																			-- AND src.committed_indicator = 'C'  -- Commented for #6100334
																			AND src.credit_commitment_ind in ( 'CCC', 'UCC') -- Added for #6100334
																			AND src.exposure_credit <> 0
                                                                            AND src.exposure_credit IS NOT NULL
                                                                            AND src.allocated_limit_amount - src.gross_carrying_amount > 0
                                                                            AND src.gross_carrying_amount <= src.exposure_credit THEN src.gross_carrying_amount / src.exposure_credit
                                                                            ELSE 1
                                                                       END,
                                        tmp.default_ind_t_1 = pos_6,
                                        tmp.impaired_ind_t_1 = pos_6,
                                        tmp.forbearance_ind_t_1 = pos_12,
                                        tmp.gross_carrying_amt_t_1 = src.gross_carrying_amount;
    EXCEPTION
        WHEN OTHERS THEN
            utils.handleerror(
                sqlcode,
                sqlerrm
            );
    END;
--------------------------------------------
    v_debug_msg := $$plsql_line || ' of unit ' || $$plsql_unit || '<<dm count>>' || SQL%rowcount;

    utilities.show_debug(v_debug_msg);
    IF ( SQL%rowcount = 0 ) THEN
        utilities.show_debug (replace('[%1!] No records found for the previous reporting date','%1!',systimestamp) );
    END IF;
	commit; --per fix
      -- COMMIT
    --Pk:Merge Modifications : 18-07-2019
    BEGIN
        MERGE /*+ enable_parallel_dml */ INTO tmp_vpp_finrep_details_info fdi USING ( SELECT
            o.code,
            o.low_value,
            o.high_value,
            o.record_valid_until
            FROM finrep_pastdue_bucket o )
        src ON ( fdi.reporting_period = v_reporting_date AND fdi.system_id = v_system_id AND fdi.ifrs_stage_t_1 IS NOT NULL
            AND   src.low_value <= nvl(fdi.days_pastdue_t_1,0) AND   src.high_value >= nvl(fdi.days_pastdue_t_1,0)
            AND   src.record_valid_until IS NULL )
        WHEN MATCHED THEN UPDATE SET fdi.days_pastdue_bucket_t_1 = src.code;

    EXCEPTION
        WHEN OTHERS THEN
            utils.handleerror(sqlcode,sqlerrm);
    END;

    v_debug_msg := $$plsql_line || ' of unit ' || $$plsql_unit || '<<dm count>>' || SQL%rowcount;

    utilities.show_debug(v_debug_msg);
	commit; --per fix
    -- subtract nr-of-months
v_begin_of_year := utils.dateadd('MONTH', 1 - utils.datepart('MONTH', v_reporting_date), v_reporting_date) ;-- subtract nr-of-months
v_end_of_last_year := utils.dateadd('DAY', -utils.datepart('DAY', v_begin_of_year), v_begin_of_year) ;


dbms_output.put_line('v_begin_of_year'||v_begin_of_year);
dbms_output.put_line('v_end_of_last_year'||v_end_of_last_year);

      BEGIN                                                                 --ORAMIGCATCHUP4 Begin
        MERGE /*+ enable_parallel_dml */ INTO TMP_VPP_FINREP_DETAILS_INFO fdi USING ( SELECT DISTINCT
            o.system_id,
            o.customer_id,
            o.facility_id,
            o.local_outstanding_id,
            o.reporting_period,
            o.record_valid_from,
            o.PERFORMING_IND_T0,
            o.gross_carrying_amt
            FROM vpp_finrep_details_info o where  o.reporting_period      = v_end_of_last_year
                AND   o.record_valid_from     = v_end_of_last_year)
        src ON ( fdi.system_id  = src.system_id  -- Added for #8511749
                AND                              -- Added for #8511749
                fdi.customer_id           = src.customer_id
                AND   fdi.facility_id           = src.facility_id
                AND   fdi.local_outstanding_id  = src.local_outstanding_id
               -- AND   fdi.reporting_period      = v_end_of_last_year
              --  AND   fdi.record_valid_from     = v_end_of_last_year
              )
        WHEN MATCHED THEN UPDATE  SET fdi.gross_carrying_amt_prev_Q4 = src.gross_carrying_amt
                                 ,fdi.performing_ind_prev_Q4     = src.PERFORMING_IND_T0;

    EXCEPTION
        WHEN OTHERS THEN
            utils.handleerror(sqlcode,sqlerrm);
    END;
   dbms_output.put_line('FOR count '  ||sql%rowcount);                                                                    --ORAMIGCATCHUP4 End
	commit; --per fix

-- Set amounts to 0 for records that are performing, when record was npe in the month before: use gross_carrying_amt_T_1

UPDATE /*+ enable_parallel_dml */  tmp_VPP_FINREP_DETAILS_INFO t
SET t.inflow_npe_gross_carr_amt =  0
   ,t.outflow_npe_gross_carr_amt = CASE WHEN t.performing_ind_prev_Q4 = 'N'
                                        THEN t.gross_carrying_amt_prev_Q4 --ORAMIGCATCHUP4
                                        WHEN t.performing_ind_prev_Q4 IS NULL
                                        THEN 0                   --ORAMIGCATCHUP4
                                        ELSE 0
                                   END
WHERE t.reporting_period = v_reporting_date
  AND t.performing_ind_T0    = 'Y'  ;

  commit; --per fix
-- Set amounts for records that are non-performing.
-- When record was NPE in the Dec before: use the diff between gross_carrying_amt_last_dec and gross_carrying_amt for in- and outflow
-- When no record in the Dec before, newly entered NPE status: set inflow to gross_carrying_amt
--ORAMIGTHIRDCATCHUP START
UPDATE /*+ enable_parallel_dml */  tmp_VPP_FINREP_DETAILS_INFO t
SET t.inflow_npe_gross_carr_amt =  CASE WHEN t.performing_ind_prev_Q4 IS NULL
                                        THEN t.gross_carrying_amt
                                        WHEN t.performing_ind_prev_Q4 = 'Y'
                                        THEN t.gross_carrying_amt
                                        WHEN t.performing_ind_prev_Q4 = 'N' AND t.gross_carrying_amt > nvl(t.gross_carrying_amt_prev_Q4, 0)
                                        THEN t.gross_carrying_amt - nvl(t.gross_carrying_amt_prev_Q4, 0)
                                        ELSE 0
                                   END
   ,t.outflow_npe_gross_carr_amt = CASE WHEN t.performing_ind_prev_Q4 IS NULL
                                        THEN 0
                                        WHEN t.performing_ind_prev_Q4 = 'Y'
                                        THEN 0
                                        WHEN t.performing_ind_prev_Q4 = 'N' AND nvl(t.gross_carrying_amt_prev_Q4, 0) > t.gross_carrying_amt
                                        THEN nvl(t.gross_carrying_amt_prev_Q4, 0) - t.gross_carrying_amt
                                        ELSE 0
                                   END
WHERE t.reporting_period = v_reporting_date
  AND t.performing_ind_T0    = 'N';

  commit; --per fix
  --ORAMIGTHIRDCATCHUP END
      -- COMMIT
      --Update the level2 risk rating code which is usedin Statutary reporting
    IF v_debug = 1 THEN
        BEGIN
            utilities.show_debug (replace('[%1!] 3 c. Update the level2 risk rating code','%1!',systimestamp) );
        END;
    END IF;

    utilities.truncate_table('tt_risk_rating_details');
    BEGIN
        INSERT /*+ APPEND enable_parallel_dml */ INTO tt_risk_rating_details
            ( SELECT
                rr_level5.risk_rating_key level5_rr_key,
                rr_level5.code level5_rr_code,
                rr_level5.description level5_rr_descr,
                rr_level4.risk_rating_key level4_rr_key,
                rr_level4.code level4_rr_code,
                rr_level4.description level4_rr_descr,
                rr_level3.risk_rating_key level3_rr_key,
                rr_level3.code level3_rr_code,
                rr_level3.description level3_rr_descr,
                rr_level2.risk_rating_key level2_rr_key,
                rr_level2.code level2_rr_code,
                rr_level2.description level2_rr_descr
              FROM
                (
                    SELECT
                        *
                    FROM
                        risk_rating
                    WHERE
                        record_valid_from <= v_reporting_date
                        AND   (record_valid_until IS NULL OR    record_valid_until > v_reporting_date)
                        AND   level_number = 5
                ) rr_level5
                LEFT JOIN (
                    SELECT
                        *
                    FROM
                        risk_rating
                    WHERE
                        record_valid_from <= v_reporting_date
                        AND   (record_valid_until IS NULL OR    record_valid_until > v_reporting_date)
                        AND   level_number = 4
                ) rr_level4
                ON rr_level5.higher_level_key   = rr_level4.risk_rating_key
                LEFT JOIN (
                    SELECT
                        *
                    FROM
                        risk_rating
                    WHERE
                        record_valid_from <= v_reporting_date
                        AND   (record_valid_until IS NULL OR    record_valid_until > v_reporting_date)
                        AND   level_number = 3
                        ) rr_level3
                ON rr_level4.higher_level_key   = rr_level3.risk_rating_key
                LEFT JOIN (
                    SELECT
                        *
                    FROM
                        risk_rating
                    WHERE
                        record_valid_from <= v_reporting_date
                        AND   (record_valid_until IS NULL OR    record_valid_until > v_reporting_date)
                        AND   level_number = 2
                ) rr_level2
                ON rr_level3.higher_level_key   = rr_level2.risk_rating_key
            );

    EXCEPTION
        WHEN OTHERS THEN
            utils.handleerror(sqlcode,sqlerrm);
    END;

    v_debug_msg := $$plsql_line || ' of unit ' || $$plsql_unit || '<<dm count>>' || SQL%rowcount;
    utilities.show_debug(v_debug_msg);
	commit; --per fix
    schema_maint.gather_idx_stats('tt_risk_rating_details');

    --Pk:Merge Modifications : 18-07-2019
    BEGIN
        MERGE /*+ enable_parallel_dml */ INTO tmp_vpp_finrep_details_info fdi USING ( SELECT /*+ PARALLEL */
            rrd.level2_rr_key,
            rrd.level2_rr_code,
            rrd.level2_rr_descr,
            rrd.level5_rr_key
            FROM tt_risk_rating_details rrd )
        src ON ( fdi.risk_rating_key_t0 = src.level5_rr_key AND fdi.reporting_period = v_reporting_date AND fdi.system_id = v_system_id )
        WHEN MATCHED THEN UPDATE SET fdi.risk_rating_level2_key_t0 = src.level2_rr_key,
        fdi.risk_rating_level2_code_t0 = src.level2_rr_code,
        fdi.risk_rating_level2_descr_t0 = src.level2_rr_descr;

    EXCEPTION
        WHEN OTHERS THEN
            utils.handleerror(
                sqlcode,
                sqlerrm
            );
    END;

    v_debug_msg := $$plsql_line || ' of unit ' || $$plsql_unit || '<<dm count>>' || SQL%rowcount;

    utilities.show_debug(v_debug_msg);
    COMMIT;
    --MISSING CODE ADDED 16 JULY 2020
    BEGIN
		MERGE /*+ enable_parallel_dml */ INTO ( SELECT
               risk_rating_key_t0,
               reporting_period,
               system_id,
               risk_rating_level2_key_t0,
               risk_rating_level2_code_t0,
               risk_rating_level2_descr_t0
           FROM
               tmp_vpp_finrep_details_info
           WHERE
            reporting_period = v_reporting_date
           AND system_id = v_system_id
           AND risk_rating_level2_key_t0 IS NULL) fdi
        USING (
              SELECT /*+ PARALLEL */
                  DISTINCT rrd.level2_rr_key,
                  rrd.level2_rr_code,
                  rrd.level2_rr_descr,
                  rrd.level4_rr_key
              FROM
                  tt_risk_rating_details rrd) src
        ON ( fdi.risk_rating_key_t0 = src.level4_rr_key)
WHEN MATCHED THEN UPDATE SET fdi.risk_rating_level2_key_t0 = src.level2_rr_key,
                             fdi.risk_rating_level2_code_t0 = src.level2_rr_code,
                             fdi.risk_rating_level2_descr_t0 = src.level2_rr_descr;

    EXCEPTION
        WHEN OTHERS THEN
            utils.handleerror(
                sqlcode,
                sqlerrm
            );
    END;

    v_debug_msg := $$plsql_line || ' of unit ' || $$plsql_unit || '<<dm count>>' || SQL%rowcount;
    utilities.show_debug(v_debug_msg);
    COMMIT;

      -- Updating the T-1 risk rating level2 information
    utilities.truncate_table('tt_risk_rating_details_t_1');
    BEGIN
        INSERT /*+ APPEND enable_parallel_dml */ INTO tt_risk_rating_details_t_1
            ( SELECT
                rr_level5.risk_rating_key level5_rr_key,
                rr_level5.code level5_rr_code,
                rr_level5.description level5_rr_descr,
                rr_level4.risk_rating_key level4_rr_key,
                rr_level4.code level4_rr_code,
                rr_level4.description level4_rr_descr,
                rr_level3.risk_rating_key level3_rr_key,
                rr_level3.code level3_rr_code,
                rr_level3.description level3_rr_descr,
                rr_level2.risk_rating_key level2_rr_key,
                rr_level2.code level2_rr_code,
                rr_level2.description level2_rr_descr
              FROM
                (
                    SELECT
                        *
                    FROM
                        risk_rating
                    WHERE
                        record_valid_from <= v_reporting_date_t_1
                        AND   (record_valid_until IS NULL OR    record_valid_until > v_reporting_date_t_1)
                        AND   level_number = 5
                ) rr_level5
                LEFT JOIN (
                    SELECT
                        *
                    FROM
                        risk_rating
                    WHERE
                        record_valid_from <= v_reporting_date_t_1
                        AND   (record_valid_until IS NULL OR    record_valid_until > v_reporting_date_t_1 )
                        AND   level_number = 4
                ) rr_level4
                ON rr_level5.higher_level_key   = rr_level4.risk_rating_key
                LEFT JOIN (
                    SELECT
                        *
                    FROM
                        risk_rating
                    WHERE
                        record_valid_from <= v_reporting_date_t_1
                        AND  (record_valid_until IS NULL OR    record_valid_until > v_reporting_date_t_1 )
                        AND   level_number = 3
                ) rr_level3
                ON rr_level4.higher_level_key   = rr_level3.risk_rating_key
                LEFT JOIN (
                    SELECT
                        *
                    FROM
                        risk_rating
                    WHERE
                        record_valid_from <= v_reporting_date_t_1
                        AND   (record_valid_until IS NULL OR record_valid_until > v_reporting_date_t_1)
                        AND   level_number = 2
                ) rr_level2
                ON rr_level3.higher_level_key   = rr_level2.risk_rating_key
            );

    EXCEPTION
        WHEN OTHERS THEN
            utils.handleerror(sqlcode,sqlerrm);
    END;

    v_debug_msg := $$plsql_line || ' of unit ' || $$plsql_unit || '<<dm count>>' || SQL%rowcount;
    utilities.show_debug(v_debug_msg);
	commit; --per fix
    schema_maint.gather_idx_stats('tt_risk_rating_details_t_1');

    --Pk:Merge Modifications : 18-07-2019
    BEGIN
        MERGE /*+ enable_parallel_dml */ INTO tmp_vpp_finrep_details_info fdi USING ( SELECT /*+ PARALLEL */
            rrd.level2_rr_key,
            rrd.level2_rr_code,
            rrd.level2_rr_descr,
            rrd.level5_rr_key
            FROM tt_risk_rating_details_t_1 rrd )
        src ON ( fdi.risk_rating_key_t_1 = src.level5_rr_key AND   fdi.reporting_period = v_reporting_date AND   fdi.system_id = v_system_id )
        WHEN MATCHED THEN UPDATE SET fdi.risk_rating_level2_key_t_1 = src.level2_rr_key,
        fdi.risk_rating_level2_code_t_1 = src.level2_rr_code,
        fdi.risk_rating_level2_descr_t_1 = src.level2_rr_descr;

    EXCEPTION
        WHEN OTHERS THEN
            utils.handleerror(sqlcode,sqlerrm);
    END;

    v_debug_msg := $$plsql_line || ' of unit ' || $$plsql_unit || '<<dm count>>' || SQL%rowcount;

    utilities.show_debug(v_debug_msg);
	commit; --per fix


    --ORAMIGCATCHUP3 START

  MERGE /*+ enable_parallel_dml */ INTO (SELECT risk_rating_level2_code_T_1,risk_rating_level2_key_T_1,risk_rating_level2_descr_T_1,risk_rating_key_T_1 FROM tmp_VPP_FINREP_DETAILS_INFO  FDI
  WHERE fdi.reporting_period    = V_reporting_date
  AND fdi.system_id           = V_system_id
  AND fdi.risk_rating_level2_key_T_1 IS NULL) fdi USING (SELECT DISTINCT level4_rr_key,level2_rr_key,level2_rr_code,level2_rr_descr FROM TT_risk_rating_details_t_1 rrd  )RRD
  ON (fdi.risk_rating_key_T_1 = rrd.level4_rr_key)
  WHEN MATCHED THEN UPDATE SET
  fdi.risk_rating_level2_key_T_1   = rrd.level2_rr_key,
    fdi.risk_rating_level2_code_T_1  = rrd.level2_rr_code,
    fdi.risk_rating_level2_descr_T_1 = rrd.level2_rr_descr;

    --ORAMIGCATCHUP3 END
    COMMIT;
      -- Updating the IFRS9 details which needs to be used to report Provision amounts
    IF v_debug = 1 THEN
        BEGIN
            utilities.show_debug (replace('[%1!] 3 d. Updating the IFRS9 details ','%1!',systimestamp) );
        END;
    END IF;

    BEGIN
        UPDATE /*+  enable_parallel_dml */  tmp_vpp_finrep_details_info fdi
            SET
                fdi.ifrs_stage_prov = fdi.ifrs_stage_t0,
                fdi.days_pastdue_prov = fdi.days_pastdue_t0,
                fdi.days_pastdue_bucket_prov = fdi.days_pastdue_bucket_t0,
                fdi.provision_category_prov = fdi.provision_category_t0,
                fdi.alloc_provision_amt_prov = utils.round_(fdi.alloc_provision_amt_t0 * fdi.on_balance_ratio_ead_t0,4),
                fdi.alloc_provision_amt_prov_lc = utils.round_(fdi.alloc_provision_amt_t0 * (1 - fdi.on_balance_ratio_ead_t0),4),
                fdi.on_balance_ratio_prov = fdi.on_balance_ratio_ead_t0,
                fdi.performing_ind_prov = fdi.performing_ind_t0,
                fdi.default_ind_prov = fdi.default_ind_t0,
                fdi.impaired_ind_prov = fdi.impaired_ind_t0,
                fdi.forbearance_ind_prov = fdi.forbearance_ind_t0,
                fdi.risk_rating_level2_code_prov = fdi.risk_rating_level2_code_t0,
                fdi.llp_prov_scope_fin_ac_ind_prov = fdi.llp_prov_scope_fin_ac_ind_t0 --STRY0504366 extra attributes start here
               ,
                fdi.npe_12m_ind_prov = fdi.npe_12m_ind_t0,
                fdi.llp_meeting_code_prov = fdi.llp_meeting_code_t0,
                fdi.llp_meeting_key_prov = fdi.llp_meeting_key_t0,
                fdi.llp_meeting_descr_prov = fdi.llp_meeting_descr_t0,
                fdi.acc_neg_changes_fv_cr_prov = fdi.acc_neg_changes_fv_cr_t0,
                fdi.npe_fb_ind_prov = fdi.npe_fb_ind_t0
        WHERE
            fdi.provision_category_t0 IN ('INDIVIDUAL','IMPAIRMENT','IAS37','IAS37_IND','OTHER', 'POCI_IND')
            AND   fdi.reporting_period = v_reporting_date
            AND   fdi.system_id = v_system_id;

    EXCEPTION
        WHEN OTHERS THEN
            utils.handleerror(sqlcode,sqlerrm);
    END;

    v_debug_msg := $$plsql_line || ' of unit ' || $$plsql_unit || '<<dm count>>' || SQL%rowcount;

    utilities.show_debug(v_debug_msg);
	commit; --per fix
      -- COMMIT
      -- If the reporting date is not a Quarter end then populate the T0 provisoins in the reporting provision columns for the same month
    IF v_debug = 1 THEN
        BEGIN
            utilities.show_debug (replace(
                '[%1!] 3e. Update T0 provisions for non-qtr end',
                '%1!',
                systimestamp
            ) );
        END;
    END IF;

    BEGIN
        UPDATE /*+  enable_parallel_dml */  tmp_vpp_finrep_details_info fdi
            SET
                fdi.ifrs_stage_prov =
                    CASE
                        WHEN ( v_provisions_t_1_insert = 'N' ) THEN
                            fdi.ifrs_stage_t0
                        ELSE fdi.ifrs_stage_t_1
                    END,
                fdi.days_pastdue_prov =
                    CASE
                        WHEN ( v_provisions_t_1_insert = 'N' ) THEN
                            fdi.days_pastdue_t0
                        ELSE fdi.days_pastdue_t_1
                    END,
                fdi.days_pastdue_bucket_prov =
                    CASE
                        WHEN ( v_provisions_t_1_insert = 'N' ) THEN
                            fdi.days_pastdue_bucket_t0
                        ELSE fdi.days_pastdue_bucket_t_1
                    END,
                fdi.provision_category_prov =
                    CASE
                        WHEN ( v_provisions_t_1_insert = 'N' ) THEN
                            fdi.provision_category_t0
                        ELSE fdi.provision_category_t_1
                    END,
                fdi.alloc_provision_amt_prov =
                    CASE
                        WHEN ( v_provisions_t_1_insert = 'N' ) THEN
                            utils.round_(
                                fdi.alloc_provision_amt_t0 * fdi.on_balance_ratio_ead_t0,
                                4
                            )
                        ELSE utils.round_(
                            fdi.alloc_provision_amt_t_1 * fdi.on_balance_ratio_ead_t_1,
                            4
                        )
                    END,
                fdi.alloc_provision_amt_prov_lc =
                    CASE
                        WHEN ( v_provisions_t_1_insert = 'N' ) THEN
                            utils.round_(
                                fdi.alloc_provision_amt_t0 * (1 - fdi.on_balance_ratio_ead_t0),
                                4
                            )
                        ELSE utils.round_(
                            fdi.alloc_provision_amt_t_1 * (1 - fdi.on_balance_ratio_ead_t_1),
                            4
                        )
                    END,
                fdi.on_balance_ratio_prov =
                    CASE
                        WHEN ( v_provisions_t_1_insert = 'N' ) THEN
                            fdi.on_balance_ratio_ead_t0
                        ELSE fdi.on_balance_ratio_ead_t_1
                    END,
                fdi.performing_ind_prov =
                    CASE
                        WHEN ( v_provisions_t_1_insert = 'N' ) THEN
                            fdi.performing_ind_t0
                        ELSE fdi.performing_ind_t_1
                    END,
                fdi.default_ind_prov =
                    CASE
                        WHEN ( v_provisions_t_1_insert = 'N' ) THEN
                            fdi.default_ind_t0
                        ELSE fdi.default_ind_t_1
                    END,
                fdi.impaired_ind_prov =
                    CASE
                        WHEN ( v_provisions_t_1_insert = 'N' ) THEN
                            fdi.impaired_ind_t0
                        ELSE fdi.impaired_ind_t_1
                    END,
                fdi.forbearance_ind_prov =
                    CASE
                        WHEN ( v_provisions_t_1_insert = 'N' ) THEN
                            fdi.forbearance_ind_t0
                        ELSE fdi.forbearance_ind_t_1
                    END,
                fdi.risk_rating_level2_code_prov =
                    CASE
                        WHEN ( v_provisions_t_1_insert = 'N' ) THEN
                            fdi.risk_rating_level2_code_t0
                        ELSE fdi.risk_rating_level2_code_t_1
                    END,
                fdi.llp_prov_scope_fin_ac_ind_prov =
                    CASE
                        WHEN ( v_provisions_t_1_insert = 'N' ) THEN
                            fdi.llp_prov_scope_fin_ac_ind_t0
                        ELSE fdi.llp_prov_scope_fin_ac_ind_t_1 --STRY0504366 extra attributes start here
                    END,
                fdi.npe_12m_ind_prov =
                    CASE
                        WHEN ( v_provisions_t_1_insert = 'N' ) THEN
                            fdi.npe_12m_ind_t0
                        ELSE fdi.npe_12m_ind_t_1
                    END,
                fdi.llp_meeting_code_prov =
                    CASE
                        WHEN ( v_provisions_t_1_insert = 'N' ) THEN
                            fdi.llp_meeting_code_t0
                        ELSE fdi.llp_meeting_code_t_1
                    END,
                fdi.llp_meeting_key_prov =
                    CASE
                        WHEN ( v_provisions_t_1_insert = 'N' ) THEN
                            fdi.llp_meeting_key_t0
                        ELSE fdi.llp_meeting_key_t_1
                    END,
                fdi.llp_meeting_descr_prov =
                    CASE
                        WHEN ( v_provisions_t_1_insert = 'N' ) THEN
                            fdi.llp_meeting_descr_t0
                        ELSE fdi.llp_meeting_descr_t_1
                    END,
                fdi.acc_neg_changes_fv_cr_prov =
                    CASE
                        WHEN ( v_provisions_t_1_insert = 'N' ) THEN
                            fdi.acc_neg_changes_fv_cr_t0
                        ELSE fdi.acc_neg_changes_fv_cr_t_1
                    END,
                fdi.npe_fb_ind_prov =
                    CASE
                        WHEN ( v_provisions_t_1_insert = 'N' ) THEN
                            fdi.npe_fb_ind_t0
                        ELSE fdi.npe_fb_ind_t_1
                    END
        WHERE
            fdi.provision_category_t0 IN (
                'COLLECTIVE',
                'IAS37_COL','POCI_COL'
            ) AND   fdi.reporting_period = v_reporting_date AND   fdi.system_id = v_system_id;

    EXCEPTION
        WHEN OTHERS THEN
            utils.handleerror(
                sqlcode,
                sqlerrm
            );
    END;

    v_debug_msg := $$plsql_line || ' of unit ' || $$plsql_unit || '<<dm count>>' || SQL%rowcount;

    utilities.show_debug(v_debug_msg);
	commit; --per fix

      -- COMMIT
      --4. Update the SME indicator
    IF v_debug = 1 THEN
        BEGIN
            utilities.show_debug (replace(
                '[%1!] 4 a. Update the SME indicator',
                '%1!',
                systimestamp
            ) );
        END;
    END IF;
--ADD the below logic for sme_ind for tmp_vpp_finrep_details_info(after insert) to fetch from dwh_vbr_basel2_irb_appr/dwh_vbr_basel2_sa_appr if reference value is active else keep it NULL
  IF v_is_ind_active = 'Y' THEN
        MERGE /*+ enable_parallel_dml */ INTO (SELECT OUTSTANDING_GROUP_KEY,sme_ind FROM tmp_vpp_finrep_details_info WHERE reporting_period = v_reporting_date AND system_id = v_system_id) fdi USING
        (SELECT /*+ parallel */ distinct EU_OFFICIAL_SME_IND,OUTSTANDING_GROUP_KEY
		 -- FROM dwh_vbr_basel2_irb_appr
		 FROM dwh_recapb4_osg_cover_irb -- Changed source for #4857458
         WHERE record_valid_from = v_reporting_date AND system_id = v_system_id) src
         ON(fdi.OUTSTANDING_GROUP_KEY = src.OUTSTANDING_GROUP_KEY)
         WHEN MATCHED THEN UPDATE SET sme_ind = EU_OFFICIAL_SME_IND;
        COMMIT;

        MERGE /*+ enable_parallel_dml */ INTO (SELECT OUTSTANDING_GROUP_KEY,sme_ind FROM tmp_vpp_finrep_details_info
                                               WHERE reporting_period = v_reporting_date AND system_id = v_system_id
                                               AND (sme_ind <> 'Y' OR sme_ind is NULL)) fdi USING
        (SELECT /*+ parallel */ distinct EU_OFFICIAL_SME_IND,OUTSTANDING_GROUP_KEY
		 -- FROM dwh_vbr_basel2_sa_appr
		 FROM dwh_recapb4_osg_cover_sa  -- Changed source for #4857458
         WHERE record_valid_from = v_reporting_date AND system_id = v_system_id) src
         ON(fdi.OUTSTANDING_GROUP_KEY = src.OUTSTANDING_GROUP_KEY)
         WHEN MATCHED THEN UPDATE SET sme_ind = EU_OFFICIAL_SME_IND;

         v_debug_msg := $$plsql_line || ' of unit ' || $$plsql_unit || '<<dm count>>' || SQL%rowcount;
         utilities.show_debug(v_debug_msg);
         COMMIT;

         UPDATE /*+ enable_parallel_dml */ tmp_vpp_finrep_details_info
         SET sme_ind = 'N'
         WHERE sme_ind is NULL and reporting_period = v_reporting_date AND system_id = v_system_id;

         COMMIT;
  ELSE
    BEGIN
/*        UPDATE tmp_vpp_finrep_details_info fdi
            SET
                fdi.sme_ind = 'Y'
        WHERE
            fdi.basel_official_approach != 'SA' AND   fdi.exposure_class_original_irb IN (
                'RET_SME',
                'RET_MO_SME',
                'CORP_SME'
            ) AND   fdi.reporting_period = v_reporting_date AND   fdi.system_id = v_system_id;
*/
--ORAMIGCATCHUP3 START
MERGE /*+ enable_parallel_dml */ INTO tmp_VPP_FINREP_DETAILS_INFO fdi USING exposure_class ec ON ( fdi.basel_official_approach != 'SA'
and ec.code = fdi.exposure_class_original_irb
and ec.record_valid_until is null and ec.sme_ind = 'Y'
--and fdi.exposure_class_original_irb in ('RET_SME', 'RET_MO_SME','CORP_SM)
and fdi.reporting_period = V_reporting_date and fdi.system_id = V_system_id
)
WHEN MATCHED THEN UPDATE SET fdi.sme_ind = 'Y';
    EXCEPTION
        WHEN OTHERS THEN
            utils.handleerror(
                sqlcode,
                sqlerrm
            );
    END;
--ORAMIGCATCHUP3 END
    v_debug_msg := $$plsql_line || ' of unit ' || $$plsql_unit || '<<dm count>>' || SQL%rowcount;

    utilities.show_debug(v_debug_msg);
	commit; --per fix
    BEGIN
        UPDATE /*+ PARALLEL enable_parallel_dml */  tmp_vpp_finrep_details_info fdi
            SET
                fdi.sme_ind = 'N'
        WHERE
            fdi.basel_official_approach != 'SA' AND   fdi.sme_ind IS NULL AND   fdi.reporting_period = v_reporting_date AND   fdi.system_id = v_system_id;

    EXCEPTION
        WHEN OTHERS THEN
            utils.handleerror(
                sqlcode,
                sqlerrm
            );
    END;

    v_debug_msg := $$plsql_line || ' of unit ' || $$plsql_unit || '<<dm count>>' || SQL%rowcount;

    utilities.show_debug(v_debug_msg);
	commit; --per fix
    BEGIN
      /*  UPDATE tmp_vpp_finrep_details_info fdi
            SET
                fdi.sme_ind = 'Y'
        WHERE
            fdi.basel_official_approach = 'SA' AND   fdi.exposure_class_original_sa IN (
                'RET_SME',
                'CORP_SME',
                'COM_PR_SME',
                'RES_PR_SME'
            ) AND   fdi.reporting_period = v_reporting_date AND   fdi.system_id = v_system_id;
*/


MERGE /*+ enable_parallel_dml */ INTO tmp_VPP_FINREP_DETAILS_INFO fdi USING exposure_class_sa sa ON (fdi.basel_official_approach = 'SA'
and sa.code = fdi.exposure_class_original_sa
and sa.record_valid_until is null and sa.sme_ind = 'Y'
--and fdi.exposure_class_original_sa in ('RET_SME', 'CORP_SME','COM_PR_SME','RES_PR_SME')
and fdi.reporting_period = V_reporting_date and fdi.system_id = V_system_id)
WHEN MATCHED THEN UPDATE SET fdi.sme_ind = 'Y';

    EXCEPTION
        WHEN OTHERS THEN
            utils.handleerror(
                sqlcode,
                sqlerrm
            );
    END;

    v_debug_msg := $$plsql_line || ' of unit ' || $$plsql_unit || '<<dm count>>' || SQL%rowcount;

    utilities.show_debug(v_debug_msg);
	commit; --per fix
    BEGIN
  /*      UPDATE tmp_vpp_finrep_details_info fdi
            SET
                fdi.sme_ind = 'Y'
        WHERE
            fdi.basel_official_approach = 'SA' AND   fdi.exposure_class_sa_not_def IN (
                'RET_SME',
                'CORP_SME',
                'COM_PR_SME',
                'RES_PR_SME'
            ) AND   fdi.reporting_period = v_reporting_date AND   fdi.system_id = v_system_id;
*/





MERGE /*+ enable_parallel_dml */ INTO  tmp_VPP_FINREP_DETAILS_INFO FDI USING exposure_class_sa sa
ON (fdi.basel_official_approach = 'SA'
and sa.code = fdi.exposure_class_sa_not_def
and sa.record_valid_until is null and sa.sme_ind = 'Y'
--and fdi.exposure_class_sa_not_def in ('RET_SME', 'CORP_SME','COM_PR_SME','RES_PR_SME')
and fdi.reporting_period = V_reporting_date and fdi.system_id = V_system_id)
WHEN MATCHED THEN UPDATE SET
fdi.sme_ind = 'Y';
    EXCEPTION
        WHEN OTHERS THEN
            utils.handleerror(
                sqlcode,
                sqlerrm
            );
    END;

    v_debug_msg := $$plsql_line || ' of unit ' || $$plsql_unit || '<<dm count>>' || SQL%rowcount;

    utilities.show_debug(v_debug_msg);
	commit; --per fix
    BEGIN
        UPDATE /*+ PARALLEL enable_parallel_dml */  tmp_vpp_finrep_details_info fdi
            SET
                fdi.sme_ind = 'N'
        WHERE
            fdi.basel_official_approach = 'SA' AND   fdi.sme_ind IS NULL AND   fdi.reporting_period = v_reporting_date AND   fdi.system_id = v_system_id;

    EXCEPTION
        WHEN OTHERS THEN
            utils.handleerror(
                sqlcode,
                sqlerrm
            );
    END;

    v_debug_msg := $$plsql_line || ' of unit ' || $$plsql_unit || '<<dm count>>' || SQL%rowcount;

    utilities.show_debug(v_debug_msg);
    COMMIT;
    END IF;
    ---ORAMIGCATCHUP3 START
    --4b. Update the CRE indicator
/*IF V_debug = 1 THEN
  utilities.show_debug ( '[%1!] 4 b. Update the CRE indicato' ||SYSDATE);
END IF;*/ -- Commented for vdd_rrd_catchup_124

/*MERGE /*+ enable_parallel_dml */ /*INTO tmp_VPP_FINREP_DETAILS_INFO fdi USING  dwh_cre_facility dcf
ON (fdi.record_valid_from = dcf.record_valid_from
  AND fdi.facility_key      = dcf.facility_key
  AND fdi.system_id         = dcf.system_id
  AND fdi.reporting_period  = V_reporting_date
  AND fdi.system_id         = V_system_id)
  WHEN MATCHED THEN UPDATE SET
 fdi.cre_indicator = 'Y';
 commit; */ --per fix -- Commented for vdd_rrd_catchup_124


/*UPDATE /*+ PARALLEL enable_parallel_dml */  /*tmp_VPP_FINREP_DETAILS_INFO fdi
SET   fdi.cre_indicator = 'N'
WHERE fdi.cre_indicator IS NULL;

COMMIT;*/ -- Commented for vdd_rrd_catchup_124
---ORAMIGCATCHUP END
      --STRY0504366: Update the level2 product type code
    IF v_debug = 1 THEN-- Override Finrep sector for STRY0815869
        BEGIN
            utilities.show_debug (replace(
                '[%1!] 4 c. Update the level2 product type code',
                '%1!',
                systimestamp
            ) );
        END;
    END IF;

    utilities.truncate_table('tt_facility_type_tree');
    BEGIN
        INSERT /*+ APPEND enable_parallel_dml */ INTO tt_facility_type_tree
            ( SELECT
                ft_level6.facility_type_key level6_ft_key,
                ft_level6.code level6_ft_code,
                ft_level5.facility_type_key level5_ft_key,
                ft_level5.code level5_ft_code,
                ft_level4.facility_type_key level4_ft_key,
                ft_level4.code level4_ft_code,
                ft_level3.facility_type_key level3_ft_key,
                ft_level3.code level3_ft_code,
                ft_level2.facility_type_key level2_ft_key,
                ft_level2.code level2_ft_code
              FROM
                (
                    SELECT
                        *
                    FROM
                        facility_type
                    WHERE
                        record_valid_from <= v_reporting_date AND   (
                            record_valid_until IS NULL OR    record_valid_until > v_reporting_date
                        ) AND   level_number = 6
                ) ft_level6
                LEFT JOIN (
                    SELECT
                        *
                    FROM
                        facility_type
                    WHERE
                        record_valid_from <= v_reporting_date AND   (
                            record_valid_until IS NULL OR    record_valid_until > v_reporting_date
                        ) AND   level_number = 5
                ) ft_level5
                ON ft_level6.higher_level_key   = ft_level5.facility_type_key
                LEFT JOIN (
                    SELECT
                        *
                    FROM
                        facility_type
                    WHERE
                        record_valid_from <= v_reporting_date AND   (
                            record_valid_until IS NULL OR    record_valid_until > v_reporting_date
                        ) AND   level_number = 4
                ) ft_level4
                ON ft_level5.higher_level_key   = ft_level4.facility_type_key
                LEFT JOIN (
                    SELECT
                        *
                    FROM
                        facility_type
                    WHERE
                        record_valid_from <= v_reporting_date AND   (
                            record_valid_until IS NULL OR    record_valid_until > v_reporting_date
                        ) AND   level_number = 3
                ) ft_level3
                ON ft_level4.higher_level_key   = ft_level3.facility_type_key
                LEFT JOIN (
                    SELECT
                        *
                    FROM
                        facility_type
                    WHERE
                        record_valid_from <= v_reporting_date AND   (
                            record_valid_until IS NULL OR    record_valid_until > v_reporting_date
                        ) AND   level_number = 2
                ) ft_level2
                ON ft_level3.higher_level_key   = ft_level2.facility_type_key
            );

    EXCEPTION
        WHEN OTHERS THEN
            utils.handleerror(
                sqlcode,
                sqlerrm
            );
    END;

    v_debug_msg := $$plsql_line || ' of unit ' || $$plsql_unit || '<<dm count>>' || SQL%rowcount;
    utilities.show_debug(v_debug_msg);
	commit; --per fix
    schema_maint.gather_idx_stats('tt_facility_type_tree');

    --Pk:Merge Modifications : 19-07-2019
    BEGIN
        MERGE /*+ enable_parallel_dml */ INTO tmp_vpp_finrep_details_info fdi USING ( SELECT /*+ PARALLEL */
            ftt.level2_ft_code,
            ftt.level6_ft_key
                                                       FROM
            tt_facility_type_tree ftt )
        src ON ( fdi.product_type_key = src.level6_ft_key AND fdi.reporting_period = v_reporting_date AND fdi.system_id = v_system_id)
        WHEN MATCHED THEN UPDATE SET fdi.product_level2_type_code = src.level2_ft_code;

    EXCEPTION
        WHEN OTHERS THEN
            utils.handleerror(
                sqlcode,
                sqlerrm
            );
    END;

    v_debug_msg := $$plsql_line || ' of unit ' || $$plsql_unit || '<<dm count>>' || SQL%rowcount;

    utilities.show_debug(v_debug_msg);
    COMMIT;
      -- 6.Update FINREP sector and FINREP purpose information
    IF v_debug = 1 THEN
        BEGIN
            utilities.show_debug (replace(
                '[%1!] 6.Update FINREP sector and FINREP purpose information',
                '%1!',
                systimestamp
            ) );
        END;
    END IF;

    --Pk:Merge Modifications : 19-07-2019
    BEGIN
        MERGE /*+ enable_parallel_dml */ INTO tmp_vpp_finrep_details_info fdi USING ( SELECT /*+ PARALLEL */
            distinct iog.finrep_sector,                         --NJ:DISTINCT ADDED TO RESOLVE 'stable set of rows' : 29-08-2019
            iog.finrep_purpose,
            iog.facility_key,
            iog.system_id,
            iog.customer_key,
            iog.outstanding_group_key
            FROM dwh_incap_outstanding_group iog
                                                       WHERE
            iog.record_valid_from = v_reporting_date AND iog.system_id = v_system_id)
        src ON ( fdi.facility_key = src.facility_key AND fdi.system_id = src.system_id AND fdi.customer_key = src.customer_key
                AND fdi.outstanding_group_key = src.outstanding_group_key AND fdi.reporting_period = v_reporting_date AND fdi.system_id = v_system_id )
        WHEN MATCHED THEN UPDATE SET fdi.finrep_sector = src.finrep_sector,
        fdi.finrep_purpose = src.finrep_purpose;

    EXCEPTION
        WHEN OTHERS THEN
            utils.handleerror(
                sqlcode,
                sqlerrm
            );
    END;

    v_debug_msg := $$plsql_line || ' of unit ' || $$plsql_unit || '<<dm count>>' || SQL%rowcount;

    utilities.show_debug(v_debug_msg);
    COMMIT;
    ---ORAMIGSecondcatchup ? Begin
    -- Override Finrep sector for STRY0815869


/*MERGE INTO tmp_vpp_finrep_details_info fdi
USING tt_finrep_sector_override fc
ON ( fdi.customer_id = fc.grid_id )
WHEN MATCHED THEN UPDATE SET finrep_sector = fc.finrep_sector;*/

 MERGE /*+ enable_parallel_dml */ INTO tmp_VPP_FINREP_DETAILS_INFO fdi
USING (SELECT distinct fdi.ROWID row_id, fc.finrep_sector
FROM tmp_VPP_FINREP_DETAILS_INFO fdi ,finrep_sector_override fc   --AB data fix
 WHERE fdi.customer_id = fc.grid_id
 AND  fc.record_valid_from <= V_reporting_date
AND (fc.record_valid_until IS NULL OR fc.record_valid_until > V_reporting_date)) src
ON ( fdi.ROWID = src.row_id )
WHEN MATCHED THEN UPDATE SET finrep_sector = src.finrep_sector;

COMMIT;

    --Pk:Merge Modifications : 19-07-2019
    ---ORAMIGSecondcatchup ? End
    MERGE /*+ enable_parallel_dml */ INTO tmp_vpp_finrep_details_info fdi USING ( SELECT /*+ PARALLEL */
        fs.description,
        fs.finrep_sector_key,
        fs.code
                                                   FROM
        finrep_sector fs
                                                   WHERE
        fs.record_valid_from <= v_reporting_date AND   (
            nvl(fs.record_valid_until,utilities.record_default_date) > v_reporting_date
        ))
    src ON ( fdi.finrep_sector = utils.convert_to_number(src.code,12) AND fdi.reporting_period = v_reporting_date AND fdi.system_id = v_system_id )
    WHEN MATCHED THEN UPDATE SET fdi.finrep_sector_descr = src.description,
                                 fdi.finrep_sector_key = src.finrep_sector_key;

    COMMIT;
    --Pk:Merge Modifications : 19-07-2019
    BEGIN
        MERGE /*+ enable_parallel_dml */ INTO tmp_vpp_finrep_details_info fdi USING ( SELECT /*+ PARALLEL */
            pur.description,
            pur.finrep_purpose_key,
            pur.finrep_purpose_id
                                                       FROM
            finrep_purpose pur
            WHERE pur.record_valid_from <= v_reporting_date AND   (
                nvl(pur.record_valid_until,utilities.record_default_date) > v_reporting_date)
        )
        src ON ( fdi.finrep_purpose = src.finrep_purpose_id AND fdi.reporting_period = v_reporting_date AND fdi.system_id = v_system_id)
        WHEN MATCHED THEN UPDATE SET fdi.finrep_purpose_descr = src.description,
        fdi.finrep_purpose_key = src.finrep_purpose_key;

    EXCEPTION
        WHEN OTHERS THEN
            utils.handleerror(
                sqlcode,
                sqlerrm
            );
    END;

    v_debug_msg := $$plsql_line || ' of unit ' || $$plsql_unit || '<<dm count>>' || SQL%rowcount;

    utilities.show_debug(v_debug_msg);
    COMMIT;
      --7. Update the industry_type and NACE codes
    IF v_debug = 1 THEN
        BEGIN
            utilities.show_debug (replace(
                '[%1!] 7. Update the industry_type and NACE codes',
                '%1!',
                systimestamp
            ) );
        END;
    END IF;

    --Pk:Merge Modifications : 19-07-2019
    BEGIN
        MERGE /*+ enable_parallel_dml */ INTO tmp_vpp_finrep_details_info fdi USING ( SELECT /*+ PARALLEL */
            it.code,
            it.industry_type_key
            FROM industry_type it )
        src ON ( fdi.industry_type_key = src.industry_type_key AND   fdi.reporting_period = v_reporting_date AND   fdi.system_id = v_system_id )
        WHEN MATCHED THEN UPDATE SET fdi.industry_type_code = src.code;

    EXCEPTION
        WHEN OTHERS THEN
            utils.handleerror(
                sqlcode,
                sqlerrm
            );
    END;

    v_debug_msg := $$plsql_line || ' of unit ' || $$plsql_unit || '<<dm count>>' || SQL%rowcount;

    utilities.show_debug(v_debug_msg);
	commit; --per fix
    --Pk:Merge Modifications : 19-07-2019
    BEGIN
        MERGE /*+ enable_parallel_dml */ INTO tmp_vpp_finrep_details_info fdi USING ( SELECT /*+ PARALLEL */
            it.nace_code_2_0,
            it.industry_type_key
                                                       FROM
            industry_type it )
        src ON ( fdi.industry_type_key = src.industry_type_key AND   fdi.reporting_period = v_reporting_date AND   fdi.system_id = v_system_id )
        WHEN MATCHED THEN UPDATE SET fdi.industry_type_nace_2_0 = src.nace_code_2_0;

    EXCEPTION
        WHEN OTHERS THEN
            utils.handleerror(
                sqlcode,
                sqlerrm
            );
    END;

    v_debug_msg := $$plsql_line || ' of unit ' || $$plsql_unit || '<<dm count>>' || SQL%rowcount;

    utilities.show_debug(v_debug_msg);
	commit; --per fix
      -- COMMIT
      --AB:Merge Modifications FOR STRY3444856 : 14-07-2022
      MERGE /*+ enable_parallel_dml */ INTO tmp_vpp_finrep_details_info fdi USING ( SELECT /*+ PARALLEL */
            in2.higher_level_code,
            in4.code,
            in4.record_valid_from,
            in4.record_valid_until
            FROM industry_nace_rev_2_0 in4
            JOIN industry_nace_rev_2_0 in3
            ON in3.code   = in4.higher_level_code AND in3.record_valid_from <= v_reporting_date AND (
                in3.record_valid_until IS NULL OR in3.record_valid_until > v_reporting_date
            )
            JOIN industry_nace_rev_2_0 in2
            ON in2.code   = in3.higher_level_code AND in2.record_valid_from <= v_reporting_date AND (
                in2.record_valid_until IS NULL OR in2.record_valid_until > v_reporting_date
            ) )
        src ON ( src.code   = fdi.industry_type_nace_2_0 AND src.record_valid_from <= v_reporting_date AND
                 ( nvl(src.record_valid_until,utilities.record_default_date) > v_reporting_date )
                 AND fdi.reporting_period = v_reporting_date AND   fdi.system_id = v_system_id)
        WHEN MATCHED THEN UPDATE SET fdi.nace_highest_level_code = src.higher_level_code;


      /*
    BEGIN
        MERGE INTO tmp_vpp_finrep_details_info fdi1 USING ( SELECT
            fdi.rowid row_id,
            itn.highest_level_code
                                                       FROM
            tmp_vpp_finrep_details_info fdi,
            industry_type_nace_2_0 itn
                                                       WHERE
            itn.record_valid_from <= v_reporting_date AND   (
                itn.record_valid_until IS NULL OR    itn.record_valid_until > v_reporting_date
            ) AND   fdi.industry_type_nace_2_0 = itn.code -- confirm
             AND   fdi.reporting_period = v_reporting_date AND   fdi.system_id = v_system_id
        )
        src ON ( fdi1.rowid = src.row_id )
        WHEN MATCHED THEN UPDATE SET fdi1.nace_highest_level_code = src.highest_level_code;

    EXCEPTION
        WHEN OTHERS THEN
            utils.handleerror(
                sqlcode,
                sqlerrm
            );
    END;
*/
    v_debug_msg := $$plsql_line || ' of unit ' || $$plsql_unit || '<<dm count>>' || SQL%rowcount;

    utilities.show_debug(v_debug_msg);
    COMMIT;
      /*
      -- Populate the FINREP Subordinate information

      --Currently this finrep subodrinate information is hardcoded. Future, It will be populated from VRE results where it is derived basedon DECISION list
      update tmp_VPP_FINREP_DETAILS_INFO fdi
      set fdi.finrep_subordinate = 'PROJ_FIN'
      where fdi.exposure_class_original_irb = 'SPLEN'

      update tmp_VPP_FINREP_DETAILS_INFO fdi
      set fdi.finrep_subordinate = 'OTH'
      where fdi.finrep_subordinate is NULL

      update tmp_VPP_FINREP_DETAILS_INFO fdi
      set fdi.finrep_subordinate_descr = sub.description,
          fdi.finrep_subordinate_key = sub.finrep_subordinate_key
      from finrep_subordinate sub
      where fdi.finrep_subordinate = sub.finrep_subordinate_id
      and sub.record_valid_from <= @reporting_date and (sub.record_valid_until is NULL or sub.record_valid_until > @reporting_date)



      -- Populate the FINREP Purpose information

      --Currently this finrep Purpose information is hardcoded. Future, It will be populated from VRE results where it is derived basedon DECISION list
      update tmp_VPP_FINREP_DETAILS_INFO fdi
      set fdi.finrep_purpose = 'HOUS_PUR'
      from dmi_facility_type ft
      where ft.record_valid_from <= @reporting_date and (ft.record_valid_until is NULL or ft.record_valid_until > @reporting_date)
      and fdi.product_type_key = ft.facility_type_key and ft.product_group_level3_code = 'WMOR'

      update tmp_VPP_FINREP_DETAILS_INFO fdi
      set fdi.finrep_purpose = 'CR_CONS'
      where fdi.product_type_code  in ('3764', 'p3764') and fdi.finrep_purpose is NULL

      update tmp_VPP_FINREP_DETAILS_INFO fdi
      set fdi.finrep_purpose = 'CR_CONS'
      from dmi_facility_type ft
      where ft.record_valid_from <= @reporting_date and (ft.record_valid_until is NULL or ft.record_valid_until > @reporting_date)
      and fdi.product_type_key = ft.facility_type_key and ft.product_group_level3_code in ('WSCA', 'WSCL', 'WSPL', 'WSCD')
      and fdi.finrep_purpose is NULL

      update tmp_VPP_FINREP_DETAILS_INFO fdi
      set fdi.finrep_purpose = 'OTH'
      where  fdi.finrep_purpose is NULL


      update tmp_VPP_FINREP_DETAILS_INFO fdi
      set fdi.finrep_purpose_descr = pur.description,
          fdi.finrep_purpose_key = pur.finrep_purpose_key
      from finrep_purpose pur
      where fdi.finrep_purpose = pur.finrep_purpose_id
      and pur.record_valid_from <= @reporting_date and (pur.record_valid_until is NULL or pur.record_valid_until > @reporting_date)
      */
      -- Populate the FINREP Product Type and FINREP Instrument Type information
    IF v_debug = 1 THEN
        BEGIN
            utilities.show_debug (replace(
                '[%1!] 8. Populate the FINREP Product Type and FINREP Instrument Type information',
                '%1!',
                systimestamp
            ) );
        END;
    END IF;
      /*update tmp_VPP_FINREP_DETAILS_INFO fdi
      set fdi.finrep_product_type_key = fpt.finrep_product_type_key,
          fdi.finrep_product_type_descr = fpt.description,
          fdi.finrep_instrument_type = fpt.higher_level_code
      from tt_finrep_product_type fpt
      where fdi.finrep_product_type = fpt.finrep_product_type_id
      and fpt.record_valid_from <= @reporting_date and (fpt.record_valid_until is NULL or fpt.record_valid_until > @reporting_date)
      and fdi.reporting_period = @reporting_date and fdi.system_id = @system_id */
   --utilities.record_default_date
    --Pk:Merge Modifications : 19-07-2019
    BEGIN
       /* MERGE INTO tmp_vpp_finrep_details_info  fdi USING ( SELECT
           distinct fpt.finrep_product_type_key,
            fpt.description,
            fpt.finrep_product_type_id
                                                       FROM
            tt_finrep_product_type fpt
            WHERE fpt.record_valid_from <= v_reporting_date AND   (
                nvl(fpt.record_valid_until, record_valid_until) > v_reporting_date ))
        src ON ( fdi.finrep_instrument_type = src.finrep_product_type_id AND fdi.reporting_period = v_reporting_date AND fdi.system_id = v_system_id)
        WHEN MATCHED THEN UPDATE SET fdi.finrep_instrument_type_key = src.finrep_product_type_key,
                                     fdi.finrep_instrument_type_descr = substr(src.description,1,30);*/

		MERGE /*+ enable_parallel_dml */ INTO tmp_vpp_finrep_details_info  fdi USING ( SELECT /*+ PARALLEL */
           max( fpt.finrep_product_type_key) finrep_product_type_key,
            max(fpt.description) description,
            fpt.finrep_product_type_id
                                                       FROM
            tt_finrep_product_type fpt
            WHERE fpt.record_valid_from <= v_reporting_date AND   (
               -- nvl(fpt.record_valid_until, record_valid_until) > v_reporting_date ))
                nvl(fpt.record_valid_until, utilities.record_default_date) > v_reporting_date )
                GROUP BY  fpt.finrep_product_type_id )
        src ON ( fdi.finrep_instrument_type = src.finrep_product_type_id AND fdi.reporting_period = v_reporting_date AND fdi.system_id = v_system_id)
        WHEN MATCHED THEN UPDATE SET fdi.finrep_instrument_type_key = src.finrep_product_type_key,
                                     fdi.finrep_instrument_type_descr = substr(src.description,1,30);


    EXCEPTION
        WHEN OTHERS THEN
            utils.handleerror(
                sqlcode,
                sqlerrm
            );
    END;

    v_debug_msg := $$plsql_line || ' of unit ' || $$plsql_unit || '<<dm count>>' || SQL%rowcount;

    utilities.show_debug(v_debug_msg);
    COMMIT;
      -- Populate the Write-off amount
      -- Delivered write off amount is always partial amount, so the wite amount full is poulated as 0.
    IF v_debug = 1 THEN
        BEGIN
            utilities.show_debug (replace(
                '[%1!] Populate the Write-off amount',
                '%1!',
                systimestamp
            ) );
        END;
    END IF;

    utilities.truncate_table('tt_write_off_src');
    BEGIN
        INSERT INTO tt_write_off_src
            ( SELECT
                dout.system_id,
                dout.outstanding_group_key,
                SUM(dof.os_amt) write_off_amt
              FROM
                dwh_outstanding dout,
                dwh_outstanding_fact dof
              WHERE
                dout.record_valid_from = v_reporting_date AND   dout.system_id = v_system_id AND   dof.record_valid_from = v_reporting_date AND   dof.system_id = v_system_id
AND   dout.outstanding_key = dof.outstanding_key AND   dof.amt_type = 'AWOB'
              GROUP BY
                dout.system_id,
                dout.outstanding_group_key
            );

    EXCEPTION
        WHEN OTHERS THEN
            utils.handleerror(
                sqlcode,
                sqlerrm
            );
    END;

    v_debug_msg := $$plsql_line || ' of unit ' || $$plsql_unit || '<<dm count>>' || SQL%rowcount;
    utilities.show_debug(v_debug_msg);
	commit; --per fix

    BEGIN
-- Commented for 7249783
--        INSERT /*+ APPEND enable_parallel_dml */ INTO tt_write_off_src
--            ( SELECT
--                dout.system_id,
--                dout.outstanding_group_key,
--                SUM(dof.os_amt) write_off_amt
--              FROM
--                dwh_outstanding dout,
--                dwh_outstanding_fact dof
--              WHERE
--                dout.record_valid_from = v_reporting_date AND   dout.system_id = v_system_id AND   dof.record_valid_from = v_reporting_date AND   dof.system_id = v_system_id
--AND   dout.outstanding_key = dof.outstanding_key AND   dof.amt_type = ( 'OWOB' ) AND   dof.outstanding_key NOT IN (
--                    SELECT
--                        fc.outstanding_key
--                    FROM
--                        dwh_outstanding_fact fc
--                    WHERE
--                        fc.amt_type IN (
--                            'AWOB'
--                        ) AND   fc.system_id = v_system_id AND   fc.record_valid_from = v_reporting_date
--                )
--              GROUP BY
--                dout.system_id,
--                dout.outstanding_group_key
--            );
--		commit; --per fix
        schema_maint.gather_idx_stats('tt_write_off_src');



        MERGE /*+ enable_parallel_dml */ INTO tmp_vpp_finrep_details_info fdi1 USING ( SELECT /*+ PARALLEL */
            fdi.rowid row_id,
            CASE
                    WHEN fdi.derecognition_reason_code IS NULL THEN
                        write_off_src.write_off_amt
                    ELSE 0
                END
            AS pos_2,
            CASE
                    WHEN fdi.derecognition_reason_code IS NULL THEN
                        0
                    ELSE write_off_src.write_off_amt
                END
            AS pos_3
                                                       FROM
            tmp_vpp_finrep_details_info fdi,
            tt_write_off_src write_off_src
                                                       WHERE
            fdi.system_id = write_off_src.system_id AND   fdi.outstanding_group_key = write_off_src.outstanding_group_key AND   fdi.finrep_instrument_type
<> 'LOAN_COMMT' AND   fdi.reporting_period = v_reporting_date AND   fdi.system_id = v_system_id
        )
        src ON ( fdi1.rowid = src.row_id )
        WHEN MATCHED THEN UPDATE SET fdi1.write_off_amt_partial = pos_2,
        fdi1.write_off_amt_full = pos_3;

    EXCEPTION
        WHEN OTHERS THEN
            utils.handleerror(
                sqlcode,
                sqlerrm
            );
    END;

    v_debug_msg := $$plsql_line || ' of unit ' || $$plsql_unit || '<<dm count>>' || SQL%rowcount;

    utilities.show_debug(v_debug_msg);
    COMMIT;
      -- Populate the Accrued Interest excluding the Loan commitment records
    IF v_debug = 1 THEN
        BEGIN
            utilities.show_debug (replace(
                '[%1!] Populate the Accrued Interest excluding the Loan commitment records ',
                '%1!',
                systimestamp
            ) );
        END;
    END IF;

    utilities.truncate_table('tt_acc_int_src');
    commit;
    BEGIN
        INSERT /*+ APPEND enable_parallel_dml */ INTO tt_acc_int_src
            ( SELECT
                dout.system_id,
                dout.outstanding_group_key,
                SUM(dotbf.os_amt) accrued_interest_amt
              FROM
                dwh_outstanding dout,
                dwh_outstanding_time_band_fact dotbf
              WHERE
                dout.record_valid_from = v_reporting_date AND   dout.system_id = v_system_id AND   dotbf.record_valid_from = v_reporting_date AND   dotbf.system_id
= v_system_id AND   dout.outstanding_key = dotbf.outstanding_key AND   dotbf.netting_type = 'AINT' AND   dotbf.amt_type = 'OAMB' AND   dotbf.time_band_key
IN (
                    1,
                    15
                )
              GROUP BY
                dout.system_id,
                dout.outstanding_group_key
            );

    EXCEPTION
        WHEN OTHERS THEN
            utils.handleerror(
                sqlcode,
                sqlerrm
            );
    END;

    v_debug_msg := $$plsql_line || ' of unit ' || $$plsql_unit || '<<dm count>>' || SQL%rowcount;
    utilities.show_debug(v_debug_msg);
	commit; --per fix
    schema_maint.gather_idx_stats('tt_acc_int_src');

    --Pk:Merge Modifications : 19-07-2019
    BEGIN
        MERGE /*+ enable_parallel_dml */ INTO tmp_vpp_finrep_details_info fdi USING ( SELECT /*+ PARALLEL */
            acc_int_src.accrued_interest_amt,
            acc_int_src.system_id,
            acc_int_src.outstanding_group_key
            FROM tt_acc_int_src acc_int_src )
        src ON ( fdi.system_id = src.system_id AND fdi.outstanding_group_key = src.outstanding_group_key AND fdi.finrep_instrument_type <> 'LOAN_COMMT'
            AND fdi.reporting_period = v_reporting_date AND fdi.system_id = v_system_id )
        WHEN MATCHED THEN UPDATE SET fdi.accrued_interest_amt = src.accrued_interest_amt;

    EXCEPTION
        WHEN OTHERS THEN
            utils.handleerror(
                sqlcode,
                sqlerrm
            );
    END;

    v_debug_msg := $$plsql_line || ' of unit ' || $$plsql_unit || '<<dm count>>' || SQL%rowcount;

    utilities.show_debug(v_debug_msg);
	commit; --per fix
      -- Populate the FINREP Scope Indicator based on FINREP Instrument Type
    IF v_debug = 1 THEN
        BEGIN
            utilities.show_debug (replace(
                '[%1!] 8. Populate the FINREP Scope Indicator based on FINREp Instrument Type ',
                '%1!',
                systimestamp
            ) );
        END;
    END IF;

    BEGIN
        UPDATE /*+ PARALLEL enable_parallel_dml */  tmp_vpp_finrep_details_info fdi
            SET
                fdi.finrep_instrument_type = 'OTHERS'
        WHERE
            fdi.finrep_instrument_type IS NULL AND   fdi.reporting_period = v_reporting_date AND   fdi.system_id = v_system_id;
		commit; --per fix
---ORAMIGSecondcatchup ? Begin
       UPDATE /*+ PARALLEL enable_parallel_dml */  tmp_VPP_FINREP_DETAILS_INFO fdi
SET fdi.finrep_scope_indicator = CASE WHEN    fdi.finrep_instrument_type      IN ( 'N/A', 'OTHERS')
                                        --commented for story 4054104
                                        --   OR fdi.system_id                   IN (SELECT /*+ PRECOMPUTE_SUBQUERY */ SYSTEM_ID FROM SOURCE_SYSTEM WHERE pipeline_deal_indicator = 'Y') -- Change for STRY3486977
                                           OR fdi.exposure_class_original_irb = 'SEC_ORIG'
                                           OR fdi.exposure_class_sec          = 'SEC_ORIG'
                                      THEN 'N'
                                      ELSE 'Y'
                                 END
WHERE fdi.reporting_period = v_reporting_date AND fdi.system_id = v_system_id;
---ORAMIGSecondcatchup ? End

    EXCEPTION
        WHEN OTHERS THEN
            utils.handleerror(
                sqlcode,
                sqlerrm
            );
    END;

    v_debug_msg := $$plsql_line || ' of unit ' || $$plsql_unit || '<<dm count>>' || SQL%rowcount;

    utilities.show_debug(v_debug_msg);
    COMMIT;
      -- Update stage migration columns
    IF v_debug = 1 THEN
        BEGIN
            utilities.show_debug (replace(
                '[%1!] Updating stage migration columns ',
                '%1!',
                systimestamp
            ) );
        END;
    END IF;
      -- subtract nr-of-months


    utilities.truncate_table('tt_dwh_outstanding_group');
    BEGIN
        INSERT /*+ APPEND enable_parallel_dml */ INTO tt_dwh_outstanding_group
            ( SELECT
                s.customer_id,
                s.local_outstanding_id,
                s.facility_id,
                s.outstanding_group_key,
                s.outstanding_start_date,
                s.record_valid_from,
                si.ifrs_stage
              FROM
                dwh_outstanding_group s
                JOIN dwh_ifrs_outstanding_group si
                ON si.outstanding_group_key   = s.outstanding_group_key AND si.ifrs9_eligible          = 'Y'
              WHERE
                s.record_valid_from >= v_end_of_last_year AND   s.record_valid_from < v_reporting_date AND
				-- Replaced UTILS part to fix performance #5797959
				/* utils.day_(
                    utils.dateadd(
                        'DAY',
                        1,
                        s.record_valid_from
                    )
                ) */
				TO_NUMBER(TO_CHAR(s.record_valid_from+1,'DD')) = 1 -- only month ends
                 -- AND   s.system_id = v_system_id
            );

    EXCEPTION
        WHEN OTHERS THEN
            utils.handleerror(
                sqlcode,
                sqlerrm
            );
    END;

    v_debug_msg := $$plsql_line || ' of unit ' || $$plsql_unit || '<<dm count>>' || SQL%rowcount;
    utilities.show_debug(v_debug_msg);
	commit; --per fix
    schema_maint.gather_idx_stats('tt_dwh_outstanding_group');
      -- Try to find a historic record for:
      -- STEP 1. system_id + facility_id + local_outstanding_id + customer_id
      --Pk:Merge Modifications : 19-07-2019
    BEGIN
        /*MERGE INTO tmp_vpp_finrep_details_info t USING ( SELECT
            i.ifrs_stage,
            i.record_valid_from,
            '1. system_id + facility_id + local_outstanding_id + customer_id' AS pos_4,
            sub.customer_id,
            sub.local_outstanding_id,
            sub.facility_id
            FROM
            (
                SELECT
                    s.customer_id,
                    s.local_outstanding_id,
                    s.facility_id,
                    MIN(s.outstanding_group_key) min_outstanding_group_key
                FROM
                    tt_dwh_outstanding_group s
                GROUP BY
                    s.customer_id,
                    s.local_outstanding_id,
                    s.facility_id
            ) sub
            JOIN dwh_ifrs_outstanding_group i
            ON i.outstanding_group_key   = min_outstanding_group_key )
        src ON ( src.customer_id = t.customer_id AND src.local_outstanding_id = t.local_outstanding_id AND src.facility_id = t.facility_id
                AND t.ifrs_eligible_indicator = 'Y' AND   t.reporting_period = v_reporting_date AND   t.system_id = v_system_id)
        WHEN MATCHED THEN UPDATE SET t.ifrs_stage_at_start = src.ifrs_stage,
                                     t.ifrs_stage_date_at_start = src.record_valid_from,
                                     t.ifrs_matching_step = pos_4;*/
       MERGE /*+ enable_parallel_dml */ INTO (select /*+ PARALLEL(4) */ facility_id,customer_id,local_outstanding_id,ifrs_stage_at_start ,
      ifrs_stage_date_at_start,ifrs_matching_step from  tmp_vpp_finrep_details_info where ifrs_eligible_indicator = 'Y'
                AND   reporting_period = v_reporting_date
                AND   system_id = v_system_id)  t using (
    SELECT
        i.ifrs_stage,
        i.record_valid_from,
        '1. system_id + facility_id + local_outstanding_id + customer_id' AS pos_4,
        sub.customer_id,
        sub.local_outstanding_id,
        sub.facility_id
    FROM
        (
            SELECT
                s.customer_id,
                s.local_outstanding_id,
                s.facility_id,
                MIN(s.outstanding_group_key) min_outstanding_group_key
            FROM
                tt_dwh_outstanding_group s
            GROUP BY
                s.customer_id,
                s.local_outstanding_id,
                s.facility_id
        ) sub
        JOIN dwh_ifrs_outstanding_group i
        ON i.outstanding_group_key   = min_outstanding_group_key
) src ON (
    src.customer_id = t.customer_id AND src.local_outstanding_id = t.local_outstanding_id AND src.facility_id = t.facility_id
)
WHEN MATCHED THEN UPDATE SET t.ifrs_stage_at_start = src.ifrs_stage,
t.ifrs_stage_date_at_start = src.record_valid_from,
t.ifrs_matching_step = pos_4;

    EXCEPTION
        WHEN OTHERS THEN
            utils.handleerror(
                sqlcode,
                sqlerrm
            );
    END;

    v_debug_msg := $$plsql_line || ' of unit ' || $$plsql_unit || '<<dm count>>' || SQL%rowcount;

    utilities.show_debug(v_debug_msg);
	commit; --per fix
      -- When not found, try to find a historic record for:
      -- STEP 2. system_id + facility_id + local_outstanding_id
      --Pk:Merge Modifications : 19-07-2019
    BEGIN
        MERGE /*+ enable_parallel_dml */ INTO tmp_vpp_finrep_details_info t USING ( SELECT /*+ PARALLEL */
            sub.min_record_valid_from,
            '2. system_id + facility_id + local_outstanding_id' AS pos_3,
            sub.local_outstanding_id,
            sub.facility_id
                                                         FROM
            (
                SELECT
                    s.local_outstanding_id,
                    s.facility_id,
                    MIN(s.record_valid_from) min_record_valid_from
                FROM
                    tt_dwh_outstanding_group s
                GROUP BY
                    s.local_outstanding_id,
                    s.facility_id
            ) sub )
        src ON ( src.local_outstanding_id = t.local_outstanding_id AND src.facility_id = t.facility_id
        AND t.ifrs_eligible_indicator = 'Y' AND t.reporting_period = v_reporting_date AND t.system_id = v_system_id)
        WHEN MATCHED THEN UPDATE SET t.ifrs_stage_date_at_start = src.min_record_valid_from,
                                     t.ifrs_matching_step = pos_3
        WHERE t.ifrs_stage_date_at_start IS NULL;

    EXCEPTION
        WHEN OTHERS THEN
            utils.handleerror(
                sqlcode,
                sqlerrm
            );
    END;

    v_debug_msg := $$plsql_line || ' of unit ' || $$plsql_unit || '<<dm count>>' || SQL%rowcount;

    utilities.show_debug(v_debug_msg);
	commit; --per fix
    --Pk:Merge Modifications : 19-07-2019
    BEGIN
        MERGE /*+ enable_parallel_dml */ INTO tmp_vpp_finrep_details_info t USING ( SELECT /*+ PARALLEL */
            sub.max_stage,
            sub.record_valid_from,
            sub.local_outstanding_id,
            sub.facility_id
                                                         FROM
            (
                SELECT
                    s.record_valid_from,
                    s.local_outstanding_id,
                    s.facility_id,
                    MAX(ifrs_stage) max_stage
                FROM
                    tt_dwh_outstanding_group s
                GROUP BY
                    s.record_valid_from,
                    s.local_outstanding_id,
                    s.facility_id
            ) sub )
        src ON ( src.record_valid_from = t.ifrs_stage_date_at_start AND src.local_outstanding_id = t.local_outstanding_id AND src.facility_id = t.facility_id
            AND t.ifrs_matching_step = '2. system_id + facility_id + local_outstanding_id' AND t.reporting_period = v_reporting_date AND t.system_id = v_system_id)
        WHEN MATCHED THEN UPDATE SET t.ifrs_stage_at_start = src.max_stage;

    EXCEPTION
        WHEN OTHERS THEN
            utils.handleerror(
                sqlcode,
                sqlerrm
            );
    END;

    v_debug_msg := $$plsql_line || ' of unit ' || $$plsql_unit || '<<dm count>>' || SQL%rowcount;

    utilities.show_debug(v_debug_msg);
	commit; --per fix
      -- When not found, try to find a historic record for:
      -- STEP 3. system_id + facility_id + customer_id
      --Pk:Merge Modifications : 19-07-2019
    BEGIN
        MERGE /*+ enable_parallel_dml */ INTO tmp_vpp_finrep_details_info t USING ( SELECT /*+ PARALLEL */
            sub.min_record_valid_from,
            '3. system_id + facility_id + customer_id' AS pos_3,
            sub.customer_id,
            sub.facility_id
                                                         FROM
            (
                SELECT
                    s.customer_id,
                    s.facility_id,
                    MIN(s.record_valid_from) min_record_valid_from
                FROM
                    tt_dwh_outstanding_group s
                GROUP BY
                    s.customer_id,
                    s.facility_id
            ) sub )
        src ON ( src.customer_id = t.customer_id AND src.facility_id = t.facility_id
        AND t.ifrs_eligible_indicator = 'Y' AND t.reporting_period = v_reporting_date AND t.system_id = v_system_id)
        WHEN MATCHED THEN UPDATE SET t.ifrs_stage_date_at_start = src.min_record_valid_from,
        t.ifrs_matching_step = pos_3
        WHERE t.ifrs_stage_date_at_start IS NULL;

    EXCEPTION
        WHEN OTHERS THEN
            utils.handleerror(
                sqlcode,
                sqlerrm
            );
    END;

    v_debug_msg := $$plsql_line || ' of unit ' || $$plsql_unit || '<<dm count>>' || SQL%rowcount;

    utilities.show_debug(v_debug_msg);
	commit; --per fix
    --Pk:Merge Modifications : 19-07-2019
    BEGIN
        MERGE /*+ enable_parallel_dml */ INTO tmp_vpp_finrep_details_info t USING ( SELECT /*+ PARALLEL */
            sub.max_stage,
            sub.record_valid_from,
            sub.customer_id,
            sub.facility_id
                                                         FROM
            (
                SELECT
                    s.record_valid_from,
                    s.customer_id,
                    s.facility_id,
                    MAX(ifrs_stage) max_stage
                FROM
                    tt_dwh_outstanding_group s
                GROUP BY
                    s.record_valid_from,
                    s.customer_id,
                    s.facility_id
            ) sub )
        src ON ( src.record_valid_from = t.ifrs_stage_date_at_start AND src.customer_id = t.customer_id AND src.facility_id = t.facility_id
        AND t.ifrs_matching_step = '3. system_id + facility_id + customer_id' AND   t.reporting_period = v_reporting_date AND   t.system_id = v_system_id)
        WHEN MATCHED THEN UPDATE SET t.ifrs_stage_at_start = src.max_stage;

    EXCEPTION
        WHEN OTHERS THEN
            utils.handleerror(
                sqlcode,
                sqlerrm
            );
    END;

    v_debug_msg := $$plsql_line || ' of unit ' || $$plsql_unit || '<<dm count>>' || SQL%rowcount;

    utilities.show_debug(v_debug_msg);
	commit; --per fix
      -- When not found, try to find a historic record for:
      -- STEP 4. system_id + facility_id + outstanding_start_date
      --Pk:Merge Modifications : 19-07-2019
    BEGIN
        MERGE /*+ enable_parallel_dml */ INTO tmp_vpp_finrep_details_info t USING ( SELECT /*+ PARALLEL */
            sub.min_record_valid_from,
            '4. system_id + facility_id + outstanding_start_date' AS pos_3,
            osg.outstanding_group_key,
            sub.facility_id
                                                         FROM
            dwh_outstanding_group osg
            JOIN (
                SELECT
                    s.outstanding_start_date,
                    s.facility_id,
                    MIN(s.record_valid_from) min_record_valid_from
                FROM
                    tt_dwh_outstanding_group s
                GROUP BY
                    s.outstanding_start_date,
                    s.facility_id
            ) sub
            ON sub.outstanding_start_date   = osg.outstanding_start_date )
        src ON ( src.outstanding_group_key = t.outstanding_group_key AND src.facility_id = t.facility_id AND   t.system_id = v_system_id
        AND t.ifrs_eligible_indicator = 'Y' AND t.reporting_period = v_reporting_date )
        WHEN MATCHED THEN UPDATE SET t.ifrs_stage_date_at_start = src.min_record_valid_from,
                                     t.ifrs_matching_step = pos_3
        WHERE t.ifrs_stage_date_at_start IS NULL;

    EXCEPTION
        WHEN OTHERS THEN
            utils.handleerror(
                sqlcode,
                sqlerrm
            );
    END;

    v_debug_msg := $$plsql_line || ' of unit ' || $$plsql_unit || '<<dm count>>' || SQL%rowcount;

    utilities.show_debug(v_debug_msg);
	commit; --per fix
    --Pk:Merge Modifications : 19-07-2019
    BEGIN
        MERGE /*+ enable_parallel_dml */ INTO tmp_vpp_finrep_details_info t USING ( SELECT /*+ PARALLEL */
            sub.max_stage,
            osg.outstanding_group_key,
            sub.record_valid_from,
            sub.facility_id
                                                         FROM
            dwh_outstanding_group osg
            JOIN (
                SELECT
                    s.record_valid_from,
                    s.outstanding_start_date,
                    s.facility_id,
                    MAX(ifrs_stage) max_stage
                FROM
                    tt_dwh_outstanding_group s
                GROUP BY
                    s.record_valid_from,
                    s.outstanding_start_date,
                    s.facility_id
            ) sub
            ON sub.outstanding_start_date = osg.outstanding_start_date )
        src ON ( src.outstanding_group_key = t.outstanding_group_key AND src.record_valid_from = t.ifrs_stage_date_at_start AND src.facility_id = t.facility_id
        AND t.ifrs_matching_step = '4. system_id + facility_id + outstanding_start_date' AND t.reporting_period = v_reporting_date AND t.system_id = v_system_id)
        WHEN MATCHED THEN UPDATE SET t.ifrs_stage_at_start = src.max_stage;

    EXCEPTION
        WHEN OTHERS THEN
            utils.handleerror(
                sqlcode,
                sqlerrm
            );
    END;

    v_debug_msg := $$plsql_line || ' of unit ' || $$plsql_unit || '<<dm count>>' || SQL%rowcount;

    utilities.show_debug(v_debug_msg);
	commit; --per fix
      -- When not found, try to find a historic record for:
      -- STEP 5. system_id + facility_id
      --Pk:Merge Modifications : 19-07-2019
    MERGE /*+ enable_parallel_dml */ INTO tmp_vpp_finrep_details_info t USING ( SELECT /*+ PARALLEL */
        sub.min_record_valid_from,
        '5. system_id + facility_id' AS pos_3,
        sub.facility_id
                                                     FROM
        (
            SELECT
                s.facility_id,
                MIN(s.record_valid_from) min_record_valid_from
            FROM
                tt_dwh_outstanding_group s
            GROUP BY
                s.facility_id
        ) sub )
    src ON ( src.facility_id   = t.facility_id AND t.ifrs_eligible_indicator = 'Y' AND t.reporting_period = v_reporting_date AND t.system_id = v_system_id)
    WHEN MATCHED THEN UPDATE SET t.ifrs_stage_date_at_start = src.min_record_valid_from,
                                 t.ifrs_matching_step = pos_3
    WHERE t.ifrs_stage_date_at_start IS NULL;
	commit; --per fix

    --Pk:Merge Modifications : 19-07-2019
    MERGE /*+ enable_parallel_dml */ INTO tmp_vpp_finrep_details_info t USING ( SELECT /*+ PARALLEL */
        sub.max_stage,
        sub.record_valid_from,
        sub.facility_id
        FROM
        (
            SELECT
                s.record_valid_from,
                s.facility_id,
                MAX(ifrs_stage) max_stage
            FROM
                tt_dwh_outstanding_group s
            GROUP BY
                s.record_valid_from,
                s.facility_id
        ) sub )
    src ON ( src.record_valid_from = t.ifrs_stage_date_at_start AND src.facility_id = t.facility_id
    AND t.ifrs_matching_step = '5. system_id + facility_id' AND t.reporting_period = v_reporting_date AND t.system_id = v_system_id)
    WHEN MATCHED THEN UPDATE SET t.ifrs_stage_at_start = src.max_stage;
	commit; --per fix
      -- When not found, try to find a historic record for:
      -- STEP 6. system_id + local_outstanding_id + customer_id

    --Pk:Merge Modifications : 19-07-2019
    MERGE /*+ enable_parallel_dml */ INTO tmp_vpp_finrep_details_info t USING ( SELECT /*+ PARALLEL */
        sub.min_record_valid_from,
        '6. system_id + local_outstanding_id + customer_id' AS pos_3,
        sub.local_outstanding_id,
        sub.customer_id
                                                     FROM
        (
            SELECT
                s.local_outstanding_id,
                s.customer_id,
                MIN(s.record_valid_from) min_record_valid_from
            FROM
                tt_dwh_outstanding_group s
            GROUP BY
                s.local_outstanding_id,
                s.customer_id
        ) sub )
    src ON ( src.local_outstanding_id = t.local_outstanding_id AND src.customer_id = t.customer_id
    AND t.ifrs_eligible_indicator = 'Y' AND t.reporting_period = v_reporting_date AND t.system_id = v_system_id)
    WHEN MATCHED THEN UPDATE SET t.ifrs_stage_date_at_start = src.min_record_valid_from,
    t.ifrs_matching_step = pos_3
    WHERE t.ifrs_stage_date_at_start IS NULL;
	commit; --per fix

    --Pk:Merge Modifications : 19-07-2019
    MERGE /*+ enable_parallel_dml */ INTO tmp_vpp_finrep_details_info t USING ( SELECT /*+ PARALLEL */
        sub.max_stage,
        sub.record_valid_from,
        sub.local_outstanding_id,
        sub.customer_id
                                                     FROM
        (
            SELECT
                s.record_valid_from,
                s.local_outstanding_id,
                s.customer_id,
                MAX(ifrs_stage) max_stage
            FROM
                tt_dwh_outstanding_group s
            GROUP BY
                s.record_valid_from,
                s.local_outstanding_id,
                s.customer_id
        ) sub )
    src ON ( src.record_valid_from = t.ifrs_stage_date_at_start AND src.local_outstanding_id = t.local_outstanding_id AND src.customer_id = t.customer_id
    AND t.ifrs_matching_step = '6. system_id + local_outstanding_id + customer_id' AND t.reporting_period = v_reporting_date AND t.system_id = v_system_id)
    WHEN MATCHED THEN UPDATE SET t.ifrs_stage_at_start = src.max_stage;
	commit; --per fix
      -- When not found, try to find a historic record for:
      -- STEP 7. system_id + local_outstanding_id

    --Pk:Merge Modifications : 19-07-2019
    MERGE /*+ enable_parallel_dml */ INTO tmp_vpp_finrep_details_info t USING ( SELECT /*+ PARALLEL */
        sub.min_record_valid_from,
        '7. system_id + local_outstanding_id' AS pos_3,
        sub.local_outstanding_id
        FROM
        (
            SELECT
                s.local_outstanding_id,
                MIN(s.record_valid_from) min_record_valid_from
            FROM
                tt_dwh_outstanding_group s
            GROUP BY
                s.local_outstanding_id
        ) sub )
    src ON ( src.local_outstanding_id = t.local_outstanding_id AND t.ifrs_eligible_indicator = 'Y'
     AND t.reporting_period = v_reporting_date AND t.system_id = v_system_id)
    WHEN MATCHED THEN UPDATE SET t.ifrs_stage_date_at_start = src.min_record_valid_from,
                                 t.ifrs_matching_step = pos_3
    WHERE t.ifrs_stage_date_at_start IS NULL;
	commit; --per fix

    --Pk:Merge Modifications : 19-07-2019
    MERGE /*+ enable_parallel_dml */ INTO tmp_vpp_finrep_details_info t USING ( SELECT /*+ PARALLEL */
        sub.max_stage,
        sub.record_valid_from,
        sub.local_outstanding_id
                                                     FROM
        (
            SELECT
                s.record_valid_from,
                s.local_outstanding_id,
                MAX(ifrs_stage) max_stage
            FROM
                tt_dwh_outstanding_group s
            GROUP BY
                s.record_valid_from,
                s.local_outstanding_id
        ) sub )
    src ON ( src.record_valid_from = t.ifrs_stage_date_at_start AND src.local_outstanding_id = t.local_outstanding_id
    AND t.ifrs_matching_step = '7. system_id + local_outstanding_id' AND t.reporting_period = v_reporting_date AND t.system_id = v_system_id)
    WHEN MATCHED THEN UPDATE SET t.ifrs_stage_at_start = src.max_stage;
	commit; --per fix
      -- When still not found:
      -- STEP 8. No previous record found, use stage and date of current reporting date

    /*MERGE INTO tmp_vpp_finrep_details_info t USING ( SELECT
        t.rowid row_id,
        i.ifrs_stage,
        t.reporting_period,
        '8. No previous record found' AS pos_4
                                                     FROM
        tmp_vpp_finrep_details_info t
        JOIN dwh_ifrs_outstanding_group i
        ON i.outstanding_group_key   = t.outstanding_group_key
                                                     WHERE
        t.ifrs_eligible_indicator = 'Y' AND   t.ifrs_stage_date_at_start IS NULL AND   t.reporting_period = v_reporting_date AND   t.system_id = v_system_id
    )
    src ON ( t.rowid = src.row_id )
    WHEN MATCHED THEN UPDATE SET t.ifrs_stage_at_start = src.ifrs_stage,
    t.ifrs_stage_date_at_start = src.reporting_period,
    t.ifrs_matching_step = pos_4;*/

    --Pk:Merge Modifications : 19-07-2019
    MERGE /*+ enable_parallel_dml */ INTO tmp_vpp_finrep_details_info t USING ( SELECT /*+ PARALLEL */
        i.ifrs_stage,
        '8. No previous record found' AS pos_4,
        i.outstanding_group_key
                                                     FROM
        dwh_ifrs_outstanding_group i )
    src ON ( src.outstanding_group_key   = t.outstanding_group_key
    AND t.ifrs_eligible_indicator = 'Y' AND t.reporting_period = v_reporting_date AND   t.system_id = v_system_id)
    WHEN MATCHED THEN UPDATE SET t.ifrs_stage_at_start = src.ifrs_stage,
    t.ifrs_stage_date_at_start = t.reporting_period,
    t.ifrs_matching_step = pos_4
    WHERE t.ifrs_stage_date_at_start IS NULL;
    ---ORAMIGSecondcatchup ? Begin
	commit; --per fix

    utilities.truncate_TABLE ('tt_dwh_outstanding_group');

COMMIT;

-- START POPULATION npe_12m_ind

v_reporting_date_T_12:= utils.dateadd('MONTH', -12, v_reporting_date) ;

-- Collect all the non-performing records of the last 12 months
utilities.truncate_TABLE ('tt_non_performers');

INSERT /*+ APPEND enable_parallel_dml */ INTO tt_non_performers (
	SELECT S.customer_id ,
        S.outstanding_group_key ,
        S.record_valid_from
	  FROM vpp_finrep_details_info S
	 WHERE  S.performing_ind_T0 = 'N'
           AND S.record_valid_from >= v_reporting_date_T_12
           AND S.record_valid_from < v_reporting_date
           AND utils.day_(utils.dateadd('DAY', 1, S.record_valid_from)) = 1 -- only month ends

           --AND S.system_id = v_system_id
           );
	 commit; --per fix
    schema_maint.gather_idx_stats('tt_non_performers');

/*
Left join the non-performing records on the non-performing records of the previous month, to find a continuous string of months.
When no previous month is found, s2.record_valid_from will be NULL.
Now populate this record_valid_from in s3 by joining on osg_key
Exclude any results which do not contain max(s.record_valid_from) = @reporting_date_T_1, as those are non-continuous up to the @reporting_date

Select the datediff between the max(s3.record_valid_from) and the current reporting_date.
*/

-- Try to find a historic record for:
-- STEP 1. system_id + customer_id
--Pk:Merge Modifications : 19-07-2019
MERGE /*+ enable_parallel_dml */ INTO tmp_vpp_finrep_details_info t USING ( SELECT /*+ PARALLEL */
    'Y',
    '1. system_id + customer_id' AS pos_3,
    sub.customer_id,
     sub.npe_12m_counter,
     CASE WHEN sub.npe_12m_counter = 12 THEN 'Y' ELSE 'N' END POS_4
                                                FROM
    (
        SELECT S.customer_id ,
       utils.datediff('MONTH', MAX(s3.record_valid_from) , v_reporting_date) npe_12m_counter
  FROM tt_non_performers S
         LEFT JOIN tt_non_performers s2   ON S.customer_id = s2.customer_id
         AND utils.dateadd('DAY', -utils.day_(S.record_valid_from), S.record_valid_from) = s2.record_valid_from
         LEFT JOIN tt_non_performers s3   ON S.outstanding_group_key = s3.outstanding_group_key
         AND s2.record_valid_from IS NULL
  GROUP BY S.customer_id
   HAVING MAX(S.record_valid_from)  = v_reporting_date_T_1

    ) sub )
src ON ( src.customer_id = t.customer_id AND t.reporting_period = v_reporting_date AND   t.system_id = v_system_id)
WHEN MATCHED THEN UPDATE SET t.npe_12m_ind_t0 = POS_4,
t.npe_matching_step = pos_3,
t.npe_12m_counter =SRC.npe_12m_counter;

commit; --per fix

utilities.truncate_TABLE ('tt_non_performers');
COMMIT;

-- END POPULATING npe_12m_ind

    ---ORAMIGSecondcatchup ? End


      --8. Populate the cover amounts

    IF v_debug = 1 THEN
        BEGIN
            utilities.show_debug (replace(
                '[%1!] 8. Populate the cover amounts ',
                '%1!',
                systimestamp
            ) );
        END;
    END IF;

    BEGIN
        INSERT INTO tmp_finrep_cover_info(
              reporting_period
            , system_id
            , source
            , facility_key
            , facility_id 
            , outstanding_group_id
            , outstanding_group_key
            , cover_id
            , cover_key 
            , cover_type_key
            , cover_type_code 
            , corep_cover_cluster 
            , reg_cover_type_class
            , reg_cover_type_class_key
            , finrep_cover_type
            , finrep_cover_type_key
            , original_cover_value
            , capped_cover_ratio
            , cover_capped_amount
            -- START: Added for #7941795
            , cover_value_after_index_r
            , local_outstanding_id
            , os_booking_base_entity_code
            , os_booking_base_entity_key 
            -- END: Added for #7941795
        )
        SELECT --top 10
              vci.record_valid_from reporting_period
            , vci.system_id
            , 'B' source
            , vci.facility_key facility_key
            , vci.facility_id facility_id
            , vci.outstanding_group_id outstanding_group_id
            , vci.outstanding_group_key outstanding_group_key
            , vci.cover_id
            , vci.cover_key
            , c.cover_type_key
            , ct.code cover_type_code
            , ct.corep_cover_cluster_irb corep_cover_cluster
            , ct.reg_cover_type_class
            , rctc.reg_cover_type_class_key
            --Commented for 4519630
			--, fct.finrep_cover_type_id finrep_cover_type
            --, fct.finrep_cover_type_key
			, ct.FINREP_COVER_TYPE										--Added for 4519630
			, null finrep_cover_type_key								--Added for 4519630
            , vci.alloc_available_amt_after_index original_cover_value
            , utils.convert_to_number('',10,8) capped_cover_ratio
            --, convert(numeric(10,8),NULL) as on_balance_ratio
            , cast('' as number(22,4)) cover_capped_amount
            -- START: Added for #7941795  
            , recap.alloc_available_amt_after_index AS cover_value_after_index_r 
            , dog.local_outstanding_id 
            , dog.book_base_entity_code AS os_booking_base_entity_code    
            , dog.book_base_entity_key AS os_booking_base_entity_key     
            -- END: Added for #7941795
        FROM dwh_vre_cover_ifrs vci
        --added additional join on dwh_facility for story 4054104
        JOIN dwh_facility fac ON fac.facility_key = vci.facility_key
        AND fac.record_valid_from = vci.record_valid_from
        -- AND nvl(fac.crr2_calc_ind,'Y') != 'N'
		AND NVL(fac.crr3_calc_ind,'Y') != 'N' -- added for story #4857458
        --
        JOIN dwh_cover c
        ON vci.record_valid_from = v_reporting_date 
        AND vci.system_id = v_system_id 
        AND c.record_valid_from = v_reporting_date 
        AND c.system_id = v_system_id
        AND vci.cover_key = c.cover_key 
        AND vci.system_id = c.system_id
        --
        LEFT JOIN cover_type ct
        ON ct.record_valid_from <= v_reporting_date 
        AND (ct.record_valid_until IS NULL OR ct.record_valid_until > v_reporting_date)
        AND c.cover_type_key = ct.cover_type_key
        --
        LEFT JOIN reg_cover_type_class rctc
        ON rctc.record_valid_from <= v_reporting_date
        AND (rctc.record_valid_until IS NULL OR rctc.record_valid_until > v_reporting_date) 
        AND ct.reg_cover_type_class   = rctc.code
  		--Commented for 4519630
        /* LEFT JOIN finrep_cover_type fct
        ON fct.record_valid_from <= v_reporting_date 
        AND (fct.record_valid_until IS NULL OR fct.record_valid_until > v_reporting_date) 
        AND rctc.finrep_cover_type = fct.finrep_cover_type_id 
        */
        -- Start: Added for #7941795
        JOIN dwh_outstanding_group dog  -- to get base entity of instrument
        ON dog.outstanding_group_key  = vci.outstanding_group_key 
        AND dog.record_valid_from = v_reporting_date
        AND dog.system_id = v_system_id
        --
        LEFT JOIN dwh_vre_cover_recapb4 recap
        ON recap.outstanding_group_key  = vci.outstanding_group_key 
        AND recap.cover_key  = vci.cover_key 
        AND recap.configuration_code  = 'RECAP4AIRB'
        AND recap.record_valid_from = v_reporting_date
        AND recap.system_id = v_system_id
        -- End: Added for #7941795
        ;

    EXCEPTION
        WHEN OTHERS THEN
            utils.handleerror(
                sqlcode,
                sqlerrm
            );
    END;

    v_debug_msg := $$plsql_line || ' of unit ' || $$plsql_unit || '<<dm count>>' || SQL%rowcount;

    utilities.show_debug(v_debug_msg);
    COMMIT;

    --5574551 Starts here for collateral_leg
    BEGIN
        INSERT INTO tmp_finrep_cover_info(
            reporting_period
            , system_id
            , source
            , facility_key
            , facility_id 
            , outstanding_group_id
            , outstanding_group_key
            , cover_id
            , cover_key 
            , cover_type_key
            , cover_type_code 
            , corep_cover_cluster 
            , reg_cover_type_class
            , reg_cover_type_class_key
            , finrep_cover_type
            , finrep_cover_type_key
            , original_cover_value
            , capped_cover_ratio
            , cover_capped_amount
            -- START: Added for #7941795
            , cover_value_after_index_r
            , local_outstanding_id
            , os_booking_base_entity_code
            , os_booking_base_entity_key 
            -- END: Added for #7941795
        )
        SELECT
            dc.record_valid_from reporting_period
            ,dc.system_id
            ,'B' source
            ,dc.facility_key facility_key
            ,dc.facility_id facility_id
            ,dog.outstanding_group_id
            ,do.outstanding_group_key outstanding_group_key
            ,dc.cover_id
            ,dc.cover_key
            ,dc.cover_type_key
            ,ct.code cover_type_code
            ,ct.corep_cover_cluster_irb corep_cover_cluster
            ,ct.reg_cover_type_class
            ,rctc.reg_cover_type_class_key
            ,ct.FINREP_COVER_TYPE
            ,null finrep_cover_type_key
            ,COVER_RECAPB4.alloc_available_amt_after_index original_cover_value 
            , utils.convert_to_number( '',10, 8) capped_cover_ratio
            , cast('' as number(22,4)) cover_capped_amount
            -- START: Added for #7941795   
            , recap.alloc_available_amt_after_index AS cover_value_after_index_r 
            , dog.local_outstanding_id 
            , dog.book_base_entity_code AS os_booking_base_entity_code    
            , dog.book_base_entity_key AS os_booking_base_entity_key    
            -- END: Added for #7941795
        FROM 
            (   SELECT * FROM dwh_cover
                WHERE record_valid_from = v_reporting_date
                    AND system_id = v_system_id
            )dc
        JOIN dwh_outstanding do
            ON do.local_outstanding_id = dc.COVER_DEAL_REFERENCE_ID
            AND do.FACILITY_KEY = dc.FACILITY_KEY
            AND do.record_valid_from = v_reporting_date
            AND NVL(do.record_valid_until,utilities.record_default_date) > v_reporting_date
        JOIN dwh_outstanding_group dog
            ON dog.outstanding_group_key = do.outstanding_group_key
            and dog.record_valid_from = v_reporting_date
            and dog.system_id = do.system_id
        LEFT JOIN DWH_VRE_COVER_RECAPB4 COVER_RECAPB4
            ON COVER_RECAPB4.cover_key = dc.cover_key
           -- and COVER_RECAPB4.outstanding_group_key = do.outstanding_group_key
            and COVER_RECAPB4.configuration_code = 'RECAP4AIRB'
            and COVER_RECAPB4.record_valid_from = v_reporting_date 
        LEFT JOIN cover_type ct
            ON ct.record_valid_from <= v_reporting_date AND (
                ct.record_valid_until IS NULL OR ct.record_valid_until > v_reporting_date
            ) AND dc.cover_type_key  = ct.cover_type_key
        LEFT JOIN reg_cover_type_class rctc
            ON rctc.record_valid_from <= v_reporting_date AND (
                rctc.record_valid_until IS NULL OR rctc.record_valid_until > v_reporting_date
            ) AND ct.reg_cover_type_class   = rctc.code
        -- START: Added for #7941795
        LEFT JOIN dwh_vre_cover_recapb4 recap
        ON recap.outstanding_group_key  = dog.outstanding_group_key 
        AND recap.cover_key  = dc.cover_key 
        AND recap.configuration_code  = 'RECAP4AIRB'
        AND recap.record_valid_from = v_reporting_date
        AND recap.system_id = v_system_id
        -- END: Added for #7941795
        WHERE NOT EXISTS ( SELECT 1 FROM tmp_finrep_cover_info TMP_COV
                            WHERE TMP_COV.OUTSTANDING_GROUP_KEY = DO.outstanding_group_key
                            AND TMP_COV.FACILITY_KEY = dc.FACILITY_KEY
                            AND TMP_COV.COVER_ID = DC.cover_id )
        ;


    EXCEPTION
        WHEN OTHERS THEN
            utils.handleerror(
                sqlcode,
                sqlerrm
            );
    END;

    v_debug_msg := $$plsql_line || ' of unit ' || $$plsql_unit || '<<dm count>>' || SQL%rowcount;

    utilities.show_debug(v_debug_msg);
    COMMIT;
    --5574551 Ends here

      /*  -- Commented the code for cover amounts from Basel tables
      select --top 10
      dvb.record_valid_from as reporting_period,
      dvb.system_id,
      'B' as source,
      dog.facility_key as facility_key,
      dvb.facility_id as facility_id,
      dvb.outstanding_group_id as outstanding_group_id,
      dog.outstanding_group_key as outstanding_group_key,
      dvb.outstanding_id as outstanding_id,
      dvb.outstanding_key as outstanding_key,
      dog.local_outstanding_id,
      dvb.customer_id as customer_id,
      dog.customer_key as customer_key,
      dvb.on_balance_sheet_indicator as on_balance_sheet_ind,
      convert(numeric(22,4),NULL) as capped_cover_ratio,

      bia.cover_id,
      c.cover_key,
      c.cover_type_key,
      ct.code as cover_type_code,
      ct.corep_cover_cluster_irb as corep_cover_cluster,
      ct.reg_cover_type_class,
      rctc.reg_cover_type_class_key,
      rctc.finrep_cover_type,

      bia.original_cover_value,
      convert(numeric(22,4),NULL) as cover_capped_amount

      into #tmp_FINREP_COVER_INFO

      from
      dwh_vbr_basel2 dvb
      inner join dwh_outstanding_group dog on dvb.record_valid_from = @reporting_date and dvb.official_approach in ('AIRB','AIRB_OFFIC') and dvb.system_id = @system_id
      and dog.record_valid_from = @reporting_date
      and dog.system_id = @system_id
      and dvb.customer_id = dog.customer_id
      and dvb.facility_key = dog.facility_key
      and dvb.outstanding_group_id = dog.outstanding_group_id

      inner join dwh_vbr_basel2_irb_appr bia on bia.record_valid_from = @reporting_date
                                            and bia.system_id         = @system_id
                                            and dvb.facility_id       = bia.facility_id
                                            and dvb.system_id         = bia.system_id
                                            and dvb.customer_id       = bia.customer_id
                                            and dvb.outstanding_group_id = bia.outstanding_group_id
                                            and dvb.official_approach = bia.basel2_approach

      inner join dwh_cover c on c.record_valid_from = @reporting_date
                            and bia.cover_id = c.cover_id
                            and bia.system_id = c.system_id

      left outer join cover_type ct
      on ct.record_valid_from <= @reporting_date and (ct.record_valid_until is NULL or ct.record_valid_until > @reporting_date)
      and c.cover_type_key = ct.cover_type_key

      left outer join reg_cover_type_class rctc
      on rctc.record_valid_from <= @reporting_date and (rctc.record_valid_until is NULL or rctc.record_valid_until > @reporting_date)
      and ct.reg_cover_type_class = rctc.code

      insert into tmp_FINREP_COVER_INFO
      Select
      dvb.record_valid_from as reporting_period,
      dvb.system_id,
      'B' as source,
      dog.facility_key as facility_key,
      dvb.facility_id as facility_id,
      dvb.outstanding_group_id as outstanding_group_id,
      dog.outstanding_group_key as outstanding_group_key,
      dvb.outstanding_id as outstanding_id,
      dvb.outstanding_key as outstanding_key,
      dog.local_outstanding_id,
      dvb.customer_id as customer_id,
      dog.customer_key as customer_key,
      dvb.on_balance_sheet_indicator as on_balance_sheet_ind,
      convert(numeric(22,4),NULL) as capped_cover_ratio,

      bsa.cover_id,
      c.cover_key,
      c.cover_type_key,
      ct.code as cover_type_code,
      ct.corep_cover_cluster_irb as corep_cover_cluster,
      ct.reg_cover_type_class,
      rctc.reg_cover_type_class_key,
      rctc.finrep_cover_type_id,

      bsa.original_cover_value,
      convert(numeric(22,4),NULL) as cover_capped_amount

      -- into #tmp_FINREP_COVER_INFO

      from
      dwh_vbr_basel2 dvb
      inner join dwh_outstanding_group dog
      on dvb.record_valid_from = @reporting_date and dvb.system_id = @system_id
      and dog.record_valid_from = @reporting_date and dog.system_id = @system_id
      and dvb.customer_id = dog.customer_id and dvb.facility_key = dog.facility_key and dvb.outstanding_group_id = dog.outstanding_group_id

      inner join dwh_vbr_basel2_sa_appr bsa
      on bsa.record_valid_from = @reporting_date and bsa.system_id = @system_id
      and dvb.facility_id = bsa.facility_id and dvb.system_id = bsa.system_id and dvb.customer_id = bsa.customer_id
          and dvb.outstanding_group_id = bsa.outstanding_group_id and dvb.official_approach = bsa.basel2_approach

      inner  join dwh_cover c
      on c.record_valid_from = @reporting_date
      and bsa.cover_id = c.cover_id and bsa.system_id = c.system_id

      left outer join cover_type ct
      on ct.record_valid_from <= @reporting_date and (ct.record_valid_until is NULL or ct.record_valid_until > @reporting_date)
      and c.cover_type_key = ct.cover_type_key

      left outer join reg_cover_type_class rctc
      on rctc.record_valid_from <= @reporting_date and (rctc.record_valid_until is NULL or rctc.record_valid_until > @reporting_date)
      and ct.reg_cover_type_class = rctc.code

      */
      --select * from #tmp_FINREP_COVER_INFO where facility_id = 'FC10019835'
      -- 9. Update the Mortgage indicators
    IF v_debug = 1 THEN
        BEGIN
            utilities.show_debug (replace(
                '[%1!] 9. Update the Mortgage indicators',
                '%1!',
                systimestamp
            ) );
        END;
    END IF;
    --pn added distinct for unstable set of rows
    --Pk:Merge Modifications : 19-07-2019
    MERGE /*+ enable_parallel_dml */ INTO tmp_vpp_finrep_details_info fdi USING ( SELECT /*+ PARALLEL */
       distinct fci.reporting_period,
        fci.system_id,
        fci.source,
        fci.facility_key,
        fci.outstanding_group_key
                                                   FROM
        tmp_finrep_cover_info fci
        WHERE fci.finrep_cover_type = 'COM_PROP' )
    src ON ( fdi.reporting_period = src.reporting_period AND fdi.system_id = src.system_id AND fdi.source = src.source
    AND fdi.facility_key = src.facility_key AND fdi.outstanding_group_key = src.outstanding_group_key
    AND fdi.reporting_period = v_reporting_date AND   fdi.system_id = v_system_id)
    WHEN MATCHED THEN UPDATE SET fdi.secured_by_com_prop_ind = 'Y',
    fdi.secured_by_res_prop_ind = 'N',
    fdi.secured_by_non_mort_ind = 'N';
	commit; --per fix
    --pn added distinct for unstable set of rows
    --Pk:Merge Modifications : 19-07-2019
  /*  MERGE INTO tmp_vpp_finrep_details_info fdi USING ( SELECT
      distinct  fci.reporting_period,
        fci.system_id,
        fci.source,
        fci.facility_key,
        fci.outstanding_group_key
        FROM tmp_finrep_cover_info fci
        WHERE fci.finrep_cover_type = 'RES_PROP' )
    src ON ( fdi.reporting_period = src.reporting_period AND fdi.system_id = src.system_id AND fdi.source = src.source
    AND fdi.facility_key = src.facility_key AND fdi.outstanding_group_key = src.outstanding_group_key
    AND fdi.secured_by_com_prop_ind IS NULL OR fdi.secured_by_com_prop_ind <> 'Y'
    AND fdi.reporting_period = v_reporting_date AND   fdi.system_id = v_system_id)
    WHEN MATCHED THEN UPDATE SET fdi.secured_by_com_prop_ind = 'N',
    fdi.secured_by_res_prop_ind = 'Y',
    fdi.secured_by_non_mort_ind = 'N';*/

        MERGE /*+ enable_parallel_dml */ INTO (SELECT
            secured_by_com_prop_ind,
            secured_by_res_prop_ind,
            secured_by_non_mort_ind,
            reporting_period,
            system_id,
            source,
            facility_key,
            outstanding_group_key
        FROM
            tmp_vpp_finrep_details_info fdi
        WHERE
            (
                fdi.secured_by_com_prop_ind IS NULL
                OR    fdi.secured_by_com_prop_ind <> 'Y'
            )
            AND   fdi.reporting_period = v_reporting_date
            AND   fdi.system_id = v_system_id)fdi using (
            SELECT DISTINCT
                reporting_period,
                system_id,
                source,
                facility_key,
                outstanding_group_key
            FROM
                tmp_finrep_cover_info fci
            WHERE
                fci.finrep_cover_type = 'RES_PROP'
        ) src
          on (
            fdi.reporting_period = src.reporting_period
            AND fdi.system_id = src.system_id
                AND fdi.source = src.source
                    AND fdi.facility_key = src.facility_key
                        AND fdi.outstanding_group_key = src.outstanding_group_key
        )
        WHEN MATCHED THEN UPDATE
            SET
                fdi.secured_by_com_prop_ind = 'N',
                fdi.secured_by_res_prop_ind = 'Y',
                fdi.secured_by_non_mort_ind = 'N';
		commit; --per fix


    --Pk:Merge Modifications : 19-07-2019
    MERGE /*+ enable_parallel_dml */ INTO tmp_vpp_finrep_details_info fdi USING ( SELECT
      distinct fci.reporting_period,                             --NJ:DISTINCT ADDED TO RESOLVE 'stable set of rows' : 29-08-2019
        fci.system_id,
        fci.source,
        fci.facility_key,
        fci.outstanding_group_key
        FROM tmp_finrep_cover_info fci
        WHERE  fci.finrep_cover_type <> 'FINAN_GUAR' AND fci.finrep_cover_type IS NOT NULL AND fci.finrep_cover_type <> 'N/A' )
    src ON ( fdi.reporting_period = src.reporting_period AND   fdi.system_id = src.system_id AND   fdi.source = src.source
    AND fdi.facility_key = src.facility_key AND fdi.outstanding_group_key = src.outstanding_group_key
    AND fdi.reporting_period = v_reporting_date AND   fdi.system_id = v_system_id)
    WHEN MATCHED THEN UPDATE SET fdi.secured_by_com_prop_ind = 'N',
                                fdi.secured_by_res_prop_ind = 'N',
                                fdi.secured_by_non_mort_ind = 'Y'
    WHERE ( fdi.secured_by_com_prop_ind IS NULL OR fdi.secured_by_com_prop_ind <> 'Y')
    AND (fdi.secured_by_res_prop_ind IS NULL OR fdi.secured_by_res_prop_ind <> 'Y') ;

    COMMIT;
    UPDATE /*+ PARALLEL enable_parallel_dml */  tmp_vpp_finrep_details_info fdi
        SET
            fdi.secured_by_com_prop_ind = 'N'
    WHERE
        fdi.secured_by_com_prop_ind IS NULL AND   fdi.reporting_period = v_reporting_date AND   fdi.system_id = v_system_id;
    commit; --per fix

    UPDATE /*+ PARALLEL enable_parallel_dml */  tmp_vpp_finrep_details_info fdi
        SET
            fdi.secured_by_res_prop_ind = 'N'
    WHERE
        fdi.secured_by_res_prop_ind IS NULL AND   fdi.reporting_period = v_reporting_date AND   fdi.system_id = v_system_id;
    commit; --per fix

    UPDATE /*+ PARALLEL enable_parallel_dml */  tmp_vpp_finrep_details_info fdi
        SET
            fdi.secured_by_non_mort_ind = 'N'
    WHERE
        fdi.secured_by_non_mort_ind IS NULL AND   fdi.reporting_period = v_reporting_date AND   fdi.system_id = v_system_id;

    COMMIT;
      -- Update the Consolidation/Solo indicators respective to all ING entities which need to be reported
    IF v_debug = 1 THEN
        BEGIN
            utilities.show_debug (replace(
                '[%1!] Update the Consolidation/Solo indicators respective to all ING entities which need to be reported',
                '%1!',
                systimestamp
            ) );
        END;
    END IF;
      /*Update tmp_VPP_FINREP_DETAILS_INFO fdi
      set  fdi.ing_group_cons_ind = 1,
           fdi.ing_bank_solo_ind = 1,
           fdi.ing_belgium_cons_ind = 1,
           fdi.ing_belgium_solo_ind = 1,
           fdi.ing_slaski_solo_ind = 1,
           fdi.ing_direct_australia_solo_ind = 1,
           fdi.ing_diba_solo_ind = 1,
           fdi.ing_turkey_solo_ind = 1,
           fdi.ing_eurasia_solo_ind = 1
      where fdi.reporting_period = @reporting_date and fdi.system_id = @system_id */

    --Pk:Merge Modifications : 19-07-2019
    MERGE /*+ enable_parallel_dml */ INTO tmp_vpp_finrep_details_info fdi USING ( SELECT /*+ PARALLEL */
        dct.group_level2_code,
        dct.customer_type_key
        FROM dmi_customer_type dct
        WHERE dct.record_valid_from <= v_reporting_date AND   (
            nvl(dct.record_valid_until,utilities.record_default_date) > v_reporting_date
        ) AND   dct.category_level1_code = 'IC' )
    src ON ( fdi.customer_type_key = src.customer_type_key AND fdi.reporting_period = v_reporting_date AND fdi.system_id = v_system_id)
    WHEN MATCHED THEN UPDATE SET fdi.intercompany_code = src.group_level2_code;
	commit; --per fix

    MERGE /*+ enable_parallel_dml */ INTO tmp_vpp_finrep_details_info fdi1 USING ( SELECT /*+ PARALLEL */
        fdi.rowid row_id,
        CASE
                WHEN diile.intermediate_parent_code = '36004387' AND (ll.parent_id IS NULL OR ll.parent_id <> 36004387)
                THEN 1
                ELSE 0
            END
        AS ing_group_cons_ind
                                                   FROM
            tmp_vpp_finrep_details_info fdi
            LEFT JOIN dmi_intermediate_ing_legal_entity diile
            ON  fdi.reporting_period = v_reporting_date and fdi.system_id = v_system_id
                and fdi.ing_legal_entity_key = diile.ing_legal_entity_key
                and diile.intermediate_parent_code = '36004387' and diile.record_valid_from <= v_reporting_date
                and NVL(diile.record_valid_until,utilities.record_default_date) > v_reporting_date
            LEFT JOIN dmi_recent_interm_parent_l ll
            ON fdi.customer_id = ll.customer_id and ll.parent_level = 1
    )
    src ON ( fdi1.rowid = src.row_id )
    WHEN MATCHED THEN UPDATE SET fdi1.ing_group_cons_ind = src.ing_group_cons_ind;
	commit; --per fix

    BEGIN

	   MERGE /*+ enable_parallel_dml */ INTO tmp_vpp_finrep_details_info fdi1 USING ( SELECT /*+ PARALLEL */
            fdi.rowid row_id,
            CASE
                    WHEN diile.intermediate_parent_code = '36000575' AND (ll.parent_id IS NULL OR ll.parent_id <> 36000575)
                    THEN 1
                    ELSE 0
                END
            AS ing_belgium_cons_ind
                                                       FROM
            tmp_vpp_finrep_details_info fdi
            LEFT JOIN dmi_intermediate_ing_legal_entity diile
            ON  fdi.reporting_period = v_reporting_date and fdi.system_id = v_system_id
                and fdi.ing_legal_entity_key = diile.ing_legal_entity_key
                and diile.intermediate_parent_code = '36000575' and diile.record_valid_from <= v_reporting_date
                and NVL(diile.record_valid_until,utilities.record_default_date) > v_reporting_date
            LEFT JOIN dmi_recent_interm_parent_l ll
            ON fdi.customer_id = ll.customer_id and ll.parent_level = 3
        )
        src ON ( fdi1.rowid = src.row_id )
        WHEN MATCHED THEN UPDATE SET fdi1.ing_belgium_cons_ind = src.ing_belgium_cons_ind;
    EXCEPTION
        WHEN OTHERS THEN
            utils.handleerror(
                sqlcode,
                sqlerrm
            );
    END;

    v_debug_msg := $$plsql_line || ' of unit ' || $$plsql_unit || '<<dm count>>' || SQL%rowcount;

    utilities.show_debug(v_debug_msg);
	commit; --per fix
--changes done in merge for defect fix STSK4489953
/*  merge into tmp_vpp_finrep_details_info fdi1 USING ( SELECT
    fdi.rowid row_id,
    CASE
            WHEN diile_c.branch_indicator = 'Y' AND diile_p.ing_legal_entity_code = '36004367' AND CAST(fdi.customer_id AS VARCHAR2(10) ) = CAST(diile_c.customer_id AS VARCHAR2(10) ) THEN
                0
            WHEN diile_c.branch_indicator = 'Y' AND diile_p.ing_legal_entity_code = '36004367' AND CAST(fdi.customer_id AS VARCHAR2(10) ) = CAST(diile_c.parent_code AS VARCHAR2(10) ) THEN
                0
            WHEN diile_c.branch_indicator = 'Y' AND diile_p.ing_legal_entity_code = '36004367' AND cust.branch_indicator = 'Y'
            AND CAST(diile_c.parent_code AS VARCHAR2(10) ) = CAST(cust.parent_code AS VARCHAR2(10) )
            THEN
                0
            WHEN diile_c.branch_indicator = 'Y' AND diile_p.ing_legal_entity_code = '36004367' AND cust.exclude_from_solo = '36004367' THEN
                0
            WHEN diile_c.branch_indicator = 'Y' AND diile_p.ing_legal_entity_code = '36004367' THEN
                1
            WHEN fdi.ing_legal_entity_code = '36004367' AND CAST(fdi.customer_id AS VARCHAR2(10) ) = CAST(diile_c.customer_id AS VARCHAR2(10) ) THEN
                0
            WHEN fdi.ing_legal_entity_code = '36004367' AND cust.branch_indicator = 'Y' AND CAST(diile_c.customer_id AS VARCHAR2(10) ) = CAST(cust.parent_code
AS VARCHAR2(10) ) THEN
                0
            WHEN fdi.ing_legal_entity_code = '36004367' AND cust.exclude_from_solo = '36004367' THEN
                0
            WHEN fdi.ing_legal_entity_code = '36004367' THEN
                1
            ELSE 0
        END
    AS ing_bank_solo_ind

                                            FROM
    tmp_vpp_finrep_details_info fdi,
    dmi_ing_legal_entity diile_c,
    dmi_ing_legal_entity diile_p,
    dmi_ing_legal_entity cust
                                            WHERE
    fdi.reporting_period = v_reporting_date
    AND   fdi.system_id = v_system_id
    AND   fdi.ing_legal_entity_key = diile_c.ing_legal_entity_key
    AND   diile_c.higher_level_key = diile_p.ing_legal_entity_key (+)
    AND   fdi.customer_id = cust.customer_id(+)
    --AND   CAST(fdi.customer_id AS VARCHAR2(10) ) = CAST(cust.customer_id AS VARCHAR2(10)) (+)
    AND diile_c.record_valid_from <= v_reporting_date
    AND (  diile_c.record_valid_until IS NULL OR diile_c.record_valid_until > v_reporting_date)
    AND diile_p.record_valid_from <= v_reporting_date
    AND (    diile_p.record_valid_until IS NULL OR diile_p.record_valid_until > v_reporting_date)
    AND cust.record_valid_from <= v_reporting_date
    AND (    cust.record_valid_until IS NULL OR cust.record_valid_until > v_reporting_date)
    ) src
    ON ( fdi1.rowid = src.row_id )
WHEN MATCHED THEN UPDATE SET fdi1.ing_bank_solo_ind = src.ing_bank_solo_ind; */

    MERGE /*+ enable_parallel_dml */ INTO tmp_vpp_finrep_details_info fdi1 USING ( SELECT
        fdi.rowid row_id,
        CASE
                WHEN diile_c.branch_indicator = 'Y' AND diile_p.ing_legal_entity_code = '36004367' AND fdi.customer_id = diile_c.customer_id
                THEN 0
                WHEN diile_c.branch_indicator = 'Y' AND diile_p.ing_legal_entity_code = '36004367' AND fdi.customer_id  = diile_c.parent_code
                THEN 0
                WHEN diile_c.branch_indicator = 'Y' AND diile_p.ing_legal_entity_code = '36004367' AND cust.branch_indicator = 'Y' AND diile_c.parent_code = cust.parent_code
                THEN 0
                WHEN diile_c.branch_indicator = 'Y' AND diile_p.ing_legal_entity_code = '36004367' AND cust.exclude_from_solo = '36004367'
                THEN 0
                WHEN diile_c.branch_indicator = 'Y' AND diile_p.ing_legal_entity_code = '36004367'
                THEN 1
                WHEN fdi.ing_legal_entity_code = '36004367' AND fdi.customer_id  = diile_c.customer_id
                THEN 0
                WHEN fdi.ing_legal_entity_code = '36004367' AND cust.branch_indicator = 'Y' AND diile_c.customer_id = cust.parent_code
                THEN 0
                WHEN fdi.ing_legal_entity_code = '36004367' AND cust.exclude_from_solo = '36004367'
                THEN 0
                WHEN fdi.ing_legal_entity_code = '36004367'
                THEN 1
                ELSE 0
            END
        AS ing_bank_solo_ind
        from tmp_VPP_FINREP_DETAILS_INFO fdi
            JOIN dmi_ing_legal_entity diile_c
                 ON  fdi.ing_legal_entity_key = diile_c.ing_legal_entity_key
                 and fdi.system_id            = v_system_id
                 and fdi.record_valid_from    = v_reporting_date
            left join dmi_ing_legal_entity diile_p
                ON diile_c.higher_level_key   = diile_p.ing_legal_entity_key
            left JOIN dmi_ing_legal_entity cust
                ON  fdi.customer_id = cust.customer_id
                and  diile_c.record_valid_from <= v_reporting_date and  NVL(diile_c.record_valid_until,utilities.record_default_date) > v_reporting_date
                and  diile_p.record_valid_from <= v_reporting_date and  NVL(diile_p.record_valid_until,utilities.record_default_date) > v_reporting_date
                and  cust.record_valid_from <= v_reporting_date and  NVL(cust.record_valid_until,utilities.record_default_date) > v_reporting_date
        ) src
        ON ( fdi1.rowid = src.row_id )
    WHEN MATCHED THEN UPDATE SET fdi1.ing_bank_solo_ind = src.ing_bank_solo_ind;
	commit; --per fix


    MERGE /*+ enable_parallel_dml */ INTO tmp_vpp_finrep_details_info  fdi1 USING ( SELECT
        fdi.rowid row_id,
        CASE
                WHEN diile_c.branch_indicator = 'Y' AND diile_p.ing_legal_entity_code = '36000575' AND fdi.customer_id  = diile_c.customer_id
                THEN 0
                WHEN diile_c.branch_indicator = 'Y' AND diile_p.ing_legal_entity_code = '36000575' AND fdi.customer_id  = diile_c.parent_code
                THEN 0
                WHEN diile_c.branch_indicator = 'Y' AND diile_p.ing_legal_entity_code = '36000575' AND cust.branch_indicator = 'Y' AND  diile_c.parent_code = cust.parent_code
                THEN 0
                WHEN diile_c.branch_indicator = 'Y' AND diile_p.ing_legal_entity_code = '36000575' AND cust.exclude_from_solo = '36000575'
                THEN 0
                WHEN diile_c.branch_indicator = 'Y' AND diile_p.ing_legal_entity_code = '36000575'
                THEN 1
                WHEN fdi.ing_legal_entity_code = '36000575' AND  fdi.customer_id = diile_c.customer_id
                THEN 0
                WHEN fdi.ing_legal_entity_code = '36000575' AND cust.branch_indicator = 'Y' AND diile_c.customer_id  = cust.parent_code
                THEN 0
                WHEN fdi.ing_legal_entity_code = '36000575' AND cust.exclude_from_solo = '36000575'
                THEN 0
                WHEN fdi.ing_legal_entity_code = '36000575'
                THEN 1
                ELSE 0
            END
        AS ing_belgium_solo_ind
		from tmp_VPP_FINREP_DETAILS_INFO fdi
        JOIN dmi_ing_legal_entity diile_c
             ON  fdi.ing_legal_entity_key = diile_c.ing_legal_entity_key
             and fdi.system_id            = v_system_id
             and fdi.record_valid_from    = v_reporting_date
        left join dmi_ing_legal_entity diile_p
            ON diile_c.higher_level_key   = diile_p.ing_legal_entity_key
        left JOIN dmi_ing_legal_entity cust
            ON  fdi.customer_id = cust.customer_id
            and  diile_c.record_valid_from <= v_reporting_date and  NVL(diile_c.record_valid_until,utilities.record_default_date) > v_reporting_date
            and  diile_p.record_valid_from <= v_reporting_date and  NVL(diile_p.record_valid_until,utilities.record_default_date) > v_reporting_date
            and  cust.record_valid_from <= v_reporting_date and  NVL(cust.record_valid_until,utilities.record_default_date) > v_reporting_date
    )
    src ON ( fdi1.rowid = src.row_id )
    WHEN MATCHED THEN UPDATE SET fdi1.ing_belgium_solo_ind = src.ing_belgium_solo_ind;
	commit; --per fix

    MERGE /*+ enable_parallel_dml */ INTO tmp_vpp_finrep_details_info fdi1 USING ( SELECT
        fdi.rowid row_id,
        CASE
                WHEN diile_c.branch_indicator = 'Y' AND diile_p.ing_legal_entity_code = '36006612' AND fdi.customer_id = diile_c.customer_id
                THEN 0
                WHEN diile_c.branch_indicator = 'Y' AND diile_p.ing_legal_entity_code = '36006612' AND fdi.customer_id = diile_c.parent_code
                THEN 0
                WHEN diile_c.branch_indicator = 'Y' AND diile_p.ing_legal_entity_code = '36006612' AND cust.branch_indicator = 'Y' AND diile_c.parent_code = cust.parent_code
                THEN 0
                WHEN diile_c.branch_indicator = 'Y' AND diile_p.ing_legal_entity_code = '36006612' AND cust.exclude_from_solo = '36006612'
                THEN 0
                WHEN diile_c.branch_indicator = 'Y' AND diile_p.ing_legal_entity_code = '36006612'
                THEN 1
                WHEN fdi.ing_legal_entity_code = '36006612' AND fdi.customer_id = diile_c.customer_id
                THEN 0
                WHEN fdi.ing_legal_entity_code = '36006612' AND cust.branch_indicator = 'Y' AND diile_c.customer_id = cust.parent_code
                THEN 0
                WHEN fdi.ing_legal_entity_code = '36006612' AND cust.exclude_from_solo = '36006612'
                THEN 0
                WHEN fdi.ing_legal_entity_code = '36006612'
                THEN 1
                ELSE 0
            END AS ing_slaski_solo_ind
		from tmp_VPP_FINREP_DETAILS_INFO fdi
        JOIN dmi_ing_legal_entity diile_c
             ON  fdi.ing_legal_entity_key = diile_c.ing_legal_entity_key
             and  fdi.system_id  = v_system_id
             and fdi.record_valid_from =v_reporting_date
        left join dmi_ing_legal_entity diile_p
            ON diile_c.higher_level_key = diile_p.ing_legal_entity_key
        left JOIN dmi_ing_legal_entity cust
            ON  fdi.customer_id = cust.customer_id
            and  diile_c.record_valid_from <= v_reporting_date and  NVL(diile_c.record_valid_until,utilities.record_default_date) > v_reporting_date
            and  diile_p.record_valid_from <= v_reporting_date and  NVL(diile_p.record_valid_until,utilities.record_default_date) > v_reporting_date
            and  cust.record_valid_from <= v_reporting_date and  NVL(cust.record_valid_until,utilities.record_default_date) > v_reporting_date
    )
    src ON ( fdi1.rowid = src.row_id )
    WHEN MATCHED THEN UPDATE SET fdi1.ing_slaski_solo_ind = src.ing_slaski_solo_ind;
	commit; --per fix

    MERGE /*+ enable_parallel_dml */ INTO tmp_vpp_finrep_details_info fdi1 USING ( SELECT
        fdi.rowid row_id,
        CASE
                WHEN diile_c.branch_indicator = 'Y' AND diile_p.ing_legal_entity_code = '36004393' AND fdi.customer_id = diile_c.customer_id
                THEN 0
                WHEN diile_c.branch_indicator = 'Y' AND diile_p.ing_legal_entity_code = '36004393' AND fdi.customer_id = diile_c.parent_code
                THEN 0
                WHEN diile_c.branch_indicator = 'Y' AND diile_p.ing_legal_entity_code = '36004393' AND cust.branch_indicator = 'Y'
                AND diile_c.parent_code  = cust.parent_code
                THEN 0
                WHEN diile_c.branch_indicator = 'Y' AND diile_p.ing_legal_entity_code = '36004393' AND cust.exclude_from_solo = '36004393'
                THEN 0
                WHEN diile_c.branch_indicator = 'Y' AND diile_p.ing_legal_entity_code = '36004393'
                THEN 1
                WHEN fdi.ing_legal_entity_code = '36004393' AND fdi.customer_id =diile_c.customer_id
                THEN 0
                WHEN fdi.ing_legal_entity_code = '36004393' AND cust.branch_indicator = 'Y' AND diile_c.customer_id  = cust.parent_code
                THEN 0
                WHEN fdi.ing_legal_entity_code = '36004393' AND cust.exclude_from_solo = '36004393'
                THEN 0
                WHEN fdi.ing_legal_entity_code = '36004393'
                THEN 1
                ELSE 0
            END AS ing_direct_australia_solo_ind
        from tmp_VPP_FINREP_DETAILS_INFO fdi
        JOIN dmi_ing_legal_entity diile_c
             ON  fdi.ing_legal_entity_key = diile_c.ing_legal_entity_key
             and  fdi.system_id  = v_system_id
             and fdi.record_valid_from =v_reporting_date
        left join dmi_ing_legal_entity diile_p
            ON diile_c.higher_level_key = diile_p.ing_legal_entity_key
        left JOIN dmi_ing_legal_entity cust
            ON  fdi.customer_id = cust.customer_id
            and  diile_c.record_valid_from <= v_reporting_date and  NVL(diile_c.record_valid_until,utilities.record_default_date) > v_reporting_date
            and  diile_p.record_valid_from <= v_reporting_date and  NVL(diile_p.record_valid_until,utilities.record_default_date) > v_reporting_date
            and  cust.record_valid_from <= v_reporting_date and  NVL(cust.record_valid_until,utilities.record_default_date) > v_reporting_date
    )
    src ON ( fdi1.rowid = src.row_id )
    WHEN MATCHED THEN UPDATE SET fdi1.ing_direct_australia_solo_ind = src.ing_direct_australia_solo_ind;
	commit; --per fix

    MERGE /*+ enable_parallel_dml */ INTO tmp_vpp_finrep_details_info fdi1 USING ( SELECT
        fdi.rowid row_id,
        CASE
                WHEN diile_c.branch_indicator = 'Y' AND diile_p.ing_legal_entity_code = '36023761' AND fdi.customer_id = diile_c.customer_id
                THEN 0
                WHEN diile_c.branch_indicator = 'Y' AND diile_p.ing_legal_entity_code = '36023761' AND fdi.customer_id = diile_c.parent_code
                THEN 0
                WHEN diile_c.branch_indicator = 'Y' AND diile_p.ing_legal_entity_code = '36023761' AND cust.branch_indicator = 'Y' AND diile_c.parent_code = cust.parent_code
                THEN 0
                WHEN diile_c.branch_indicator = 'Y' AND diile_p.ing_legal_entity_code = '36023761' AND cust.exclude_from_solo = '36023761'
                THEN 0
                WHEN diile_c.branch_indicator = 'Y' AND diile_p.ing_legal_entity_code = '36023761'
                THEN 1
                WHEN fdi.ing_legal_entity_code = '36023761' AND fdi.customer_id  = diile_c.customer_id
                THEN 0
                WHEN fdi.ing_legal_entity_code = '36023761' AND cust.branch_indicator = 'Y' AND diile_c.customer_id  = cust.parent_code
                THEN 0
                WHEN fdi.ing_legal_entity_code = '36023761' AND cust.exclude_from_solo = '36023761'
                THEN 0
                WHEN fdi.ing_legal_entity_code = '36023761'
                THEN 1
                ELSE 0
            END
        AS ing_diba_solo_ind
         from tmp_VPP_FINREP_DETAILS_INFO fdi
        JOIN dmi_ing_legal_entity diile_c
             ON  fdi.ing_legal_entity_key = diile_c.ing_legal_entity_key
             and  fdi.system_id  = v_system_id
             and fdi.record_valid_from =v_reporting_date
        left join dmi_ing_legal_entity diile_p
            ON diile_c.higher_level_key = diile_p.ing_legal_entity_key
        left JOIN dmi_ing_legal_entity cust
            ON  fdi.customer_id = cust.customer_id
            and  diile_c.record_valid_from <= v_reporting_date and  NVL(diile_c.record_valid_until,utilities.record_default_date) > v_reporting_date
            and  diile_p.record_valid_from <= v_reporting_date and  NVL(diile_p.record_valid_until,utilities.record_default_date) > v_reporting_date
            and  cust.record_valid_from <= v_reporting_date and  NVL(cust.record_valid_until,utilities.record_default_date) > v_reporting_date
    )
    src ON ( fdi1.rowid = src.row_id )
    WHEN MATCHED THEN UPDATE SET fdi1.ing_diba_solo_ind = src.ing_diba_solo_ind;
	commit; --per fix

    MERGE /*+ enable_parallel_dml */ INTO tmp_vpp_finrep_details_info fdi1 USING ( SELECT
        fdi.rowid row_id,
        CASE
                WHEN diile_c.branch_indicator = 'Y' AND diile_p.ing_legal_entity_code = '36006899' AND fdi.customer_id = diile_c.customer_id
                THEN 0
                WHEN diile_c.branch_indicator = 'Y' AND diile_p.ing_legal_entity_code = '36006899' AND fdi.customer_id = diile_c.parent_code
                THEN 0
                WHEN diile_c.branch_indicator = 'Y' AND diile_p.ing_legal_entity_code = '36006899' AND cust.branch_indicator = 'Y' AND diile_c.parent_code = cust.parent_code
                THEN 0
                WHEN diile_c.branch_indicator = 'Y' AND diile_p.ing_legal_entity_code = '36006899' AND cust.exclude_from_solo = '36006899'
                THEN 0
                WHEN diile_c.branch_indicator = 'Y' AND diile_p.ing_legal_entity_code = '36006899'
                THEN 1
                WHEN fdi.ing_legal_entity_code = '36006899' AND fdi.customer_id = diile_c.customer_id
                THEN 0
                WHEN fdi.ing_legal_entity_code = '36006899' AND cust.branch_indicator = 'Y' AND diile_c.customer_id = cust.parent_code
                THEN 0
                WHEN fdi.ing_legal_entity_code = '36006899' AND cust.exclude_from_solo = '36006899'
                THEN 0
                WHEN fdi.ing_legal_entity_code = '36006899'
                THEN 1
                ELSE 0
            END
        AS ing_turkey_solo_ind
             from tmp_VPP_FINREP_DETAILS_INFO fdi
        JOIN dmi_ing_legal_entity diile_c
             ON  fdi.ing_legal_entity_key = diile_c.ing_legal_entity_key
             and  fdi.system_id  = v_system_id
             and fdi.record_valid_from =v_reporting_date
        left join dmi_ing_legal_entity diile_p
            ON diile_c.higher_level_key = diile_p.ing_legal_entity_key
        left JOIN dmi_ing_legal_entity cust
            ON  fdi.customer_id = cust.customer_id
            and  diile_c.record_valid_from <= v_reporting_date and  NVL(diile_c.record_valid_until,utilities.record_default_date) > v_reporting_date
            and  diile_p.record_valid_from <= v_reporting_date and  NVL(diile_p.record_valid_until,utilities.record_default_date) > v_reporting_date
            and  cust.record_valid_from <= v_reporting_date and  NVL(cust.record_valid_until,utilities.record_default_date) > v_reporting_date
    )
    src ON ( fdi1.rowid = src.row_id )
    WHEN MATCHED THEN UPDATE SET fdi1.ing_turkey_solo_ind = src.ing_turkey_solo_ind;
	commit; --per fix

    MERGE /*+ enable_parallel_dml */ INTO tmp_vpp_finrep_details_info fdi1 USING ( SELECT
        fdi.rowid row_id,
        CASE
                WHEN diile_c.branch_indicator = 'Y' AND diile_p.ing_legal_entity_code = '36004372' AND fdi.customer_id = diile_c.customer_id
                THEN 0
                WHEN diile_c.branch_indicator = 'Y' AND diile_p.ing_legal_entity_code = '36004372' AND fdi.customer_id = diile_c.parent_code
                THEN 0
                WHEN diile_c.branch_indicator = 'Y' AND diile_p.ing_legal_entity_code = '36004372' AND cust.branch_indicator = 'Y' AND diile_c.parent_code  = cust.parent_code
                THEN 0
                WHEN diile_c.branch_indicator = 'Y' AND diile_p.ing_legal_entity_code = '36004372' AND cust.exclude_from_solo = '36004372'
                THEN 0
                WHEN diile_c.branch_indicator = 'Y' AND diile_p.ing_legal_entity_code = '36004372'
                THEN 1
                WHEN fdi.ing_legal_entity_code = '36004372' AND fdi.customer_id = diile_c.customer_id
                THEN 0
                WHEN fdi.ing_legal_entity_code = '36004372' AND cust.branch_indicator = 'Y' AND diile_c.customer_id = cust.parent_code
                THEN 0
                WHEN fdi.ing_legal_entity_code = '36004372' AND cust.exclude_from_solo = '36004372'
                THEN 0
                WHEN fdi.ing_legal_entity_code = '36004372'
                THEN 1
                ELSE 0
            END
        AS ing_eurasia_solo_ind
		FROM tmp_VPP_FINREP_DETAILS_INFO fdi
		JOIN dmi_ing_legal_entity diile_c ON  fdi.ing_legal_entity_key = diile_c.ing_legal_entity_key
		                                  AND  fdi.system_id = v_system_id  AND fdi.record_valid_from =v_reporting_date
		LEFT JOIN dmi_ing_legal_entity diile_p ON diile_c.higher_level_key = diile_p.ing_legal_entity_key
		LEFT JOIN dmi_ing_legal_entity cust    ON  fdi.customer_id = cust.customer_id
            AND  diile_c.record_valid_from <= v_reporting_date AND  NVL(diile_c.record_valid_until,utilities.record_default_date) > v_reporting_date
            AND  diile_p.record_valid_from <= v_reporting_date AND  NVL(diile_p.record_valid_until,utilities.record_default_date) > v_reporting_date
            AND  cust.record_valid_from <= v_reporting_date AND  NVL(cust.record_valid_until,utilities.record_default_date) > v_reporting_date
    ) src ON ( fdi1.rowid = src.row_id )
WHEN MATCHED THEN UPDATE SET fdi1.ing_eurasia_solo_ind =
    src.ing_eurasia_solo_ind;
    COMMIT;

   ----------------Start of VDD_RRD_CATCHUP_124-------------------
   --4b. Update the CRE indicator
IF v_debug = 1 THEN
BEGIN
  utilities.show_debug ( '[%1!] 4 b. Update the CRE indicato' ||SYSDATE);
END;
END IF;
--REMOVED OLD LOGIC FOR STORY 2189568(cre_indicator population)
-- rolled back cre changes as part of 3033854
-- MERGE /*+ enable_parallel_dml */ INTO tmp_VPP_FINREP_DETAILS_INFO fdi
-- USING (SELECT DISTINCT record_valid_from as record_valid_from ,facility_key as facility_key,system_id as  system_id FROM dwh_cre_facility where system_id=v_system_id ) dcf   --AB :2021-07-20: Extra condition add for issue ORA-20999: Oracle Error:: unable to get a stable set of rows in the source tables
-- ON (fdi.record_valid_from = dcf.record_valid_from
--  AND fdi.facility_key      = dcf.facility_key
--   AND fdi.system_id         = dcf.system_id
--   AND fdi.reporting_period  = V_reporting_date
--   AND fdi.system_id         = V_system_id)
--   WHEN MATCHED THEN UPDATE SET
--  fdi.cre_scope_vre = 'Y';
--  commit;


-- UPDATE /*+ PARALLEL enable_parallel_dml */ tmp_VPP_FINREP_DETAILS_INFO fdi
-- SET   fdi.cre_scope_vre = 'N'
-- WHERE fdi.cre_scope_vre IS NULL;

-- COMMIT;


-- MERGE /*+ enable_parallel_dml */ INTO tmp_VPP_FINREP_DETAILS_INFO maintab
-- USING
-- (
-- SELECT /*+ parallel */
-- distinct vpp.rowid AS rowidentifier,
-- CASE WHEN io.executive_centre_level3_code = 'ECEU' AND au3.accounting_unit = 'LERE3'                         THEN 'Real Estate Finance WB'
--                            WHEN bo.management_centre_level4_code = 'BUWUVF'                                                        THEN 'WestlandUtrecht Vastgoedfinanciering (5)'
--                            WHEN bo.management_centre_level4_code = 'BC_1509'                                                       THEN 'RB Australia (CPF)'
--                            WHEN au4.accounting_unit = 'LELECO' AND ct2.code ='REAL'                                                THEN 'ING General Lease Core_Real Estate'
--                            WHEN au4.accounting_unit = 'LELENC' AND ct2.code ='REAL'                                                THEN 'ING General Lease Run-off_Real Estate'
--                            WHEN io.branch_level7_code IN ('BC13056', 'BC13057','BC13058' ,'BC13059', 'BC13060') AND it1.code ='22' THEN 'Record Retail_Real Estate'
--                            WHEN (
--                                   (   io.management_centre_level4_code IN ('MCIN' ,'MCNL' ,'MCRT')
--                                    OR bo.management_centre_level4_code IN ('MCIN' ,'MCNL' ,'MCRT')
--                                   )
--                                 AND it4.code IN ('531120', '531130' ,'531190', '531210' ,'531311', '531312' ,'531451', '531452','531453' ,'531454' ,'531455', '531456', '531110')
--                                 AND (
--                                       io.business_unit_level5_code IN ('BUBBK' ,'BULNL', 'BUMKB' ,'BUPBK', 'BUCFNL')
--                                       OR io.branch_level7_code = 'BC_63'  AND st4.code= 'MCRNL'
--                                       OR io.region_level6_code = 'REGIBN' AND vpp.system_id IN ('ISN', 'AML')
--                                     )
--                                 )                                                                                                  THEN 'DBNL - CVOG'
--                            WHEN (io.management_centre_level4_code IN ('MCIN' ,'MCNL' ,'MCRT')
--                                  OR bo.management_centre_level4_code IN ('MCIN' ,'MCNL' ,'MCRT')
--                                 )
--                                 AND it4.code IN ('531120', '531130' ,'531190', '531210' ,'531311', '531312' ,'531451', '531452','531453' ,'531454' ,'531455', '531456', '531110')
--                                                                                                                                    THEN 'DBNL - Other'
--                            WHEN bo.region_level6_code='REGSIN' AND it1.code = '22'                                                 THEN 'Real Estate Singapore WB'
--                                                                                                                                    ELSE NULL
--                       END AS cre_scope_int
-- --,vpp.rowid AS rowidentifier
--    FROM tmp_vpp_finrep_details_info vpp

--       INNER JOIN industry_type it4 ON vpp.industry_type_key = it4.industry_type_key
--       INNER JOIN industry_type it3 ON it3.industry_type_key = it4.higher_level_key
--       INNER JOIN industry_type it2 ON it2.industry_type_key = it3.higher_level_key
--       INNER JOIN industry_type it1 ON it1.industry_type_key = it2.higher_level_key
--       INNER JOIN segmentation_type st5 ON vpp.segmentation_type_key = st5.segmentation_type_key
--       INNER JOIN segmentation_type st4 ON st4.segmentation_type_key = st5.higher_level_key

--       INNER JOIN office_flattened_buss bo ON vpp.os_booking_office_key 	  = bo.office_key
--       INNER JOIN office_flattened_buss io ON vpp.os_initiating_office_key = io.office_key

--       INNER JOIN accounting_unit au6 ON au6.accounting_unit_key = vpp.accounting_unit_key
--       INNER JOIN accounting_unit au5 ON au6.higher_level_key = au5.accounting_unit_key
--       INNER JOIN accounting_unit au4 ON au5.higher_level_key = au4.accounting_unit_key
--       INNER JOIN accounting_unit au3 ON au4.higher_level_key = au3.accounting_unit_key

--       INNER JOIN customer_type ct3 ON vpp.customer_type_key = ct3.customer_type_key
--       INNER JOIN customer_type ct2 ON ct3.higher_level_key  = ct2.customer_type_key

--       INNER JOIN facility_type ftype ON ftype.facility_type_key = vpp.product_type_key
--  --     INNER JOIN office_base_entity obe ON vpp.os_booking_base_entity_code = obe.code
--  --                and obe.record_valid_from <= @reporting_date and (obe.record_valid_until is NULL or obe.record_valid_until > @reporting_date) and obe.cre_eligible = 'I'
--       LEFT OUTER JOIN anacredit_instrument_type ait ON ftype.anacredit_instr_type = ait.code

--       WHERE (vpp.intercompany_code <> 'NBNK' OR vpp.intercompany_code IS NULL)

--       AND vpp.risk_category_level1_code IN ('IS', 'MM', 'WS')
--       AND vpp.system_id NOT IN (SELECT /*+ PRECOMPUTE_SUBQUERY */ SYSTEM_ID FROM SOURCE_SYSTEM WHERE pipeline_deal_indicator = 'Y') -- Change for STRY3486977
--       AND NVL(ct3.anacredit_natural_pers_ind,'x') <> 'NP'
-- ) srctab
-- ON (maintab.rowid = srctab.rowidentifier)
-- WHEN MATCHED THEN UPDATE SET maintab.cre_scope_int = srctab.cre_scope_int;

-- COMMIT;

-- MERGE /*+ enable_parallel_dml */ INTO tmp_vpp_finrep_details_info maintab
-- USING
-- (
-- SELECT /*+ parallel */ finref.cre_scope_vre AS cre_scope_vre
--       ,obe.code AS code
--       ,finref.rowid AS rowidentifier
--   FROM office_base_entity obe
--  INNER
--   JOIN tmp_vpp_finrep_details_info finref
--     ON  (finref.os_booking_base_entity_code = obe.code)
--  WHERE obe.record_valid_from <= v_reporting_date and (obe.record_valid_until is NULL or obe.record_valid_until > v_reporting_date)
--    AND obe.cre_eligible = 'Y'
-- ) srctab
-- ON (maintab.rowid = srctab.rowidentifier)
-- WHEN MATCHED THEN UPDATE SET maintab.cre_indicator = srctab.cre_scope_vre;

-- COMMIT;

-- UPDATE /*+ enable_parallel_dml */ tmp_vpp_finrep_details_info finrep
-- SET finrep.cre_indicator =  'Y'
-- WHERE finrep.cre_scope_int IS NOT NULL
--   AND EXISTS (SELECT /*+ parallel */ 1
--                 FROM office_base_entity obe
--                WHERE obe.record_valid_from <= v_reporting_date and (obe.record_valid_until is NULL or obe.record_valid_until > v_reporting_date)
--                  AND finrep.os_booking_base_entity_code = obe.code
--                  AND obe.cre_eligible = 'I'
--              );

-- COMMIT;

-- update  tmp_vpp_finrep_details_info
--   set cre_indicator =  'N'
--   where cre_indicator IS NULL;

-- COMMIT;
   ----------------End of VDD_RRD_CATCHUP_124---------------------

      -- Take the T Individual provision from FINREP details Info table
      --Insert all the Collective provisions from T-1 to the temp_VPP_FINREP_DETAILS_INFO table except facilities which have Individual provisions
      --If we need to insert only the collective provisions for Facilities which
      --This will ease the capping funtionality and breakdown functinality even though duplicate data exists.
    IF v_debug = 1 THEN
        BEGIN
            utilities.show_debug (replace(
                '[%1!] IF @provisions_T_1_insert = Y Take the T Individual provision from FINREP details Info table',
                '%1!',
                systimestamp
            ) );
        END;
    END IF;

    SELECT
        COUNT(1)
    INTO
        v_number_of_records
    FROM
        tmp_vpp_finrep_details_info;

    IF ( v_provisions_t_1_insert = 'Y' AND v_number_of_records > 0 ) THEN
        BEGIN
            INSERT INTO tmp_vpp_finrep_details_info
            ---ORAMIGSecondcatchup ? Begin
            (reporting_period
,record_valid_from
,record_valid_until
,system_id
,source
,facility_key
,facility_id
,higher_level_facility_key
,higher_level_facility_id
,outstanding_group_id
,outstanding_group_key
,local_outstanding_id
,outstanding_id
,outstanding_key
,customer_id
,customer_key
,instrument_id
,instrument_type
,os_booking_office_key
,os_booking_office_code
,os_booking_base_entity_key
,os_booking_base_entity_code
,os_booking_base_entity_descr
,os_initiating_office_key
,os_initiating_office_code
,os_initiating_base_entity_key
,os_initiating_base_entity_code
,os_initiating_base_entity_descr
,fac_booking_office_key
,fac_booking_office_code
,fac_booking_base_entity_key
,fac_booking_base_entity_code
,fac_booking_base_entity_descr
,fac_initiating_office_key
,fac_initiating_office_code
,fac_initiating_base_entity_key
,fac_initiating_base_entity_code
,fac_initiating_base_entity_descr
,customer_type_key
,customer_type_code
,customer_type_descr
,industry_type_key
,industry_type_code
,industry_type_nace_2_0
,nace_highest_level_code
,residence_country_key
,residence_country_code
,residence_country_name
,regulatory_country_code
,regulatory_country_key
,regulatory_country_name
,basel_official_approach
,exposure_class_original_sa
,exposure_class_original_irb
,exposure_class_sa_not_def
,exposure_class_sec
,limit_type_key
,limit_type_code
,limit_type_descr
,product_type_key
,product_type_code
,product_type_descr
,risk_category_level1_code
,risk_category_level1_key
,ing_legal_entity_key
,ing_legal_entity_code
,ifrs_accounting_classification
,ifrs_measurement_category
,on_balance_sheet_ind
,on_balance_ind
,committed_indicator
,poci_type_key
,poci_type
,poci_type_descr
,advised_indicator
,forbearance_measure_key
,forbearance_measure_code
,forbearance_measure_descr
,forbearance_measure_1_key
,forbearance_measure_1_code
,forbearance_measure_1_descr
,forbearance_measure_2_key
,forbearance_measure_2_code
,forbearance_measure_2_descr
,forbearance_measure_3_key
,forbearance_measure_3_code
,forbearance_measure_3_descr
,forbearance_measure_4_key
,forbearance_measure_4_code
,forbearance_measure_4_descr
,forbearance_measure_5_key
,forbearance_measure_5_code
,forbearance_measure_5_descr
,forbearance_status_key
,forbearance_status_code
,allocated_limit_amt
,allocated_outstanding_amt
,exposure_original
,carrying_amt
,gross_carrying_amt
,loan_commitments_given_amt
,accrued_interest_amt
,write_off_amt_partial
,write_off_amt_full
,ifrs_stage_T0
,days_pastdue_T0
,days_pastdue_bucket_T0
,provision_category_T0
,alloc_provision_amt_T0
,on_balance_ratio_EAD_T0
,on_balance_ratio_CA_T0
,performing_ind_T0
,risk_rating_key_T0
,risk_rating_code_T0
,risk_rating_level2_key_T0
,risk_rating_level2_code_T0
,risk_rating_level2_descr_T0
,ifrs_stage_T_1
,days_pastdue_T_1
,days_pastdue_bucket_T_1
,provision_category_T_1
,alloc_provision_amt_T_1
,on_balance_ratio_EAD_T_1
,performing_ind_T_1
,risk_rating_key_T_1
,risk_rating_code_T_1
,risk_rating_level2_key_T_1
,risk_rating_level2_code_T_1
,risk_rating_level2_descr_T_1
,ifrs_stage_PROV
,days_pastdue_PROV
,days_pastdue_bucket_PROV
,provision_category_PROV
,alloc_provision_amt_PROV
,alloc_provision_amt_PROV_LC
,on_balance_ratio_PROV
,performing_ind_PROV
,risk_rating_level2_code_PROV
,sme_ind
,finrep_instrument_type
,finrep_instrument_type_key
,finrep_instrument_type_descr
,finrep_product_type
,finrep_product_type_key
,finrep_product_type_descr
,finrep_purpose
,finrep_purpose_key
,finrep_purpose_descr
,finrep_subordinate
,finrep_subordinate_key
,finrep_subordinate_descr
,finrep_sector
,finrep_sector_key
,finrep_sector_descr
,finrep_scope_indicator
,ifrs_eligible_indicator
,derecognition_reason_key
,derecognition_reason_code
,derecognition_reason_descr
,derecognition_date
,secured_by_com_prop_ind
,secured_by_res_prop_ind
,secured_by_non_mort_ind
,com_prop_cover_capped_amt
,com_prop_cover_capped_amt_LC
,res_prop_cover_capped_amt
,res_prop_cover_capped_amt_LC
,cash_cover_capped_amt
,cash_cover_capped_amt_LC
,rest_cover_capped_amt
,rest_cover_capped_amt_LC
,finan_guar_cover_capped_amt
,finan_guar_cover_capped_amt_LC

--ORAMIGCATCHIP3 START
,mov_prop_cover_capped_amt
,mov_prop_cover_capped_amt_LC
,eq_debt_sec_cover_capped_amt
,eq_debt_sec_cover_capped_amt_LC
--ORAMIGCATCHIP3 END
,intercompany_code
,customer_base_entity_code
,ing_group_cons_ind
,ing_bank_solo_ind
,ing_belgium_cons_ind
,ing_belgium_solo_ind
,ing_slaski_solo_ind
,ing_direct_australia_solo_ind
,ing_diba_solo_ind
,ing_turkey_solo_ind
,ing_eurasia_solo_ind
,default_ind_T0
,impaired_ind_T0
,forbearance_ind_T0
,default_ind_T_1
,impaired_ind_T_1
,forbearance_ind_T_1
,default_ind_PROV
,impaired_ind_PROV
,forbearance_ind_PROV
,low_credit_risk_ind
,product_level2_type_code
,llp_prov_scope_fin_ac_ind_T0
,llp_prov_scope_fin_ac_ind_T_1
,llp_prov_scope_fin_ac_ind_PROV
,irrevocable_facility_ind
,stat_instrument_type_key
,stat_instrument_type_code
,stat_instrument_type_descr
,stat_instrument_subtype_key
,stat_instrument_subtype_code
,stat_instrument_subtype_descr
,stat_sector_key
,stat_sector_code
,stat_sector_descr
,npe_matching_step
,npe_12m_counter
,npe_12m_ind_T0
,npe_12m_ind_T_1
,npe_12m_ind_PROV
,npe_fb_ind_T0
,npe_fb_ind_T_1
,npe_fb_ind_PROV
,llp_meeting_code_T0
,llp_meeting_key_T0
,llp_meeting_descr_T0
,llp_meeting_code_T_1
,llp_meeting_key_T_1
,llp_meeting_descr_T_1
,llp_meeting_code_PROV
,llp_meeting_key_PROV
,llp_meeting_descr_PROV
,acc_neg_changes_fv_cr_T0
,acc_neg_changes_fv_cr_T_1
,acc_neg_changes_fv_cr_PROV
,ifrs_stage_at_start
,ifrs_stage_date_at_start
,ifrs_matching_step
-- for movements
,origination_date
,forbearance_start_date
,orig_event_prov_amt
,orig_event_prov_amt_LC
,derec_event_prov_amt
,derec_event_prov_amt_LC
,derec_writeoff_event_prov_amt
,derec_writeoff_event_prov_amt_LC
,forb_event_prov_amt
,forb_event_prov_amt_LC
,reforb_event_prov_amt
,reforb_event_prov_amt_LC
,ifrs9_model_event_prov_amt
,ifrs9_model_event_prov_amt_LC
,basel_model_event_prov_amt
,basel_model_event_prov_amt_LC
,securitised_ind
,securitised_factor
,securitisation_code
,securitisation_legal_entity_key
,securitisation_descr
,retained_position_ind,
--ORAMIGCATCHUP3 START
ltv_ratio
,ltv_ratio_class
,inflow_npe_gross_carr_amt
,outflow_npe_gross_carr_amt
,gross_carrying_amt_T_1
,cre_indicator
--ORAMIGCATCHUP3 END
,gross_carrying_amt_prev_Q4--ORAMIGCATCHUP4
,performing_ind_prev_Q4--ORAMIGCATCHUP4
,finrep_record_type
-----start of vdd_rrd_catchup_124---------
--,cre_scope_vre -- rolled back cre changes as part of 3033854
--,cre_scope_int -- rolled back cre changes as part of 3033854
-----end of vdd_rrd_catchup_124---------
,cred_deriv_cover_capped_amt
,cred_deriv_cover_capped_amt_LC
,CREDIT_COMMITMENT_IND --6100295
)
---ORAMIGSecondcatchup ? End
                (select
v_reporting_date,
record_valid_from,
record_valid_until,
system_id,
'B',
facility_key,
facility_id,
higher_level_facility_key,
higher_level_facility_id,
outstanding_group_id,
outstanding_group_key,
local_outstanding_id,
outstanding_id,
outstanding_key,
customer_id,
customer_key,
instrument_id,
instrument_type,
os_booking_office_key,
os_booking_office_code,
os_booking_base_entity_key ,
os_booking_base_entity_code,
os_booking_base_entity_descr,
os_initiating_office_key,
os_initiating_office_code,
os_initiating_base_entity_key,
os_initiating_base_entity_code,
os_initiating_base_entity_descr,
fac_booking_office_key,
fac_booking_office_code,
fac_booking_base_entity_key ,
fac_booking_base_entity_code,
fac_booking_base_entity_descr,
fac_initiating_office_key,
fac_initiating_office_code,
fac_initiating_base_entity_key,
fac_initiating_base_entity_code,
fac_initiating_base_entity_descr,
customer_type_key,
customer_type_code,
customer_type_descr,
industry_type_key,
industry_type_code,
industry_type_nace_2_0,
nace_highest_level_code	,
residence_country_key	,
residence_country_code,
residence_country_name,
regulatory_country_code,
regulatory_country_key,
regulatory_country_name	,
basel_official_approach ,
exposure_class_original_sa ,
exposure_class_original_irb,
exposure_class_sa_not_def,
exposure_class_sec,
limit_type_key,
limit_type_code,
limit_type_descr,
product_type_key,
product_type_code,
product_type_descr,
risk_category_level1_code,
risk_category_level1_key,
ing_legal_entity_key,
ing_legal_entity_code,
ifrs_accounting_classification,
ifrs_measurement_category,
on_balance_sheet_ind    ,
on_balance_ind,
committed_indicator     ,
poci_type_key,
poci_type,
poci_type_descr,
advised_indicator       ,
forbearance_measure_key     ,
forbearance_measure_code    ,
forbearance_measure_descr   ,
forbearance_measure_1_key   ,
forbearance_measure_1_code  ,
forbearance_measure_1_descr ,
forbearance_measure_2_key   ,
forbearance_measure_2_code  ,
forbearance_measure_2_descr ,
forbearance_measure_3_key   ,
forbearance_measure_3_code  ,
forbearance_measure_3_descr ,
forbearance_measure_4_key   ,
forbearance_measure_4_code  ,
forbearance_measure_4_descr ,
forbearance_measure_5_key   ,
forbearance_measure_5_code  ,
forbearance_measure_5_descr ,
forbearance_status_key      ,
forbearance_status_code     ,
0,
0,
0,
0,
0,
0,
0,
0,
0,
ifrs_stage_T0,
days_pastdue_T0,
days_pastdue_bucket_T0,  ------check
provision_category_T0,
0,
on_balance_ratio_EAD_T0,
on_balance_ratio_CA_T0,
performing_ind_T0,
risk_rating_key_T0 ,
risk_rating_code_T0 ,
risk_rating_level2_key_T0,
risk_rating_level2_code_T0,
risk_rating_level2_descr_T0,
ifrs_stage_T_1,
days_pastdue_T_1,
days_pastdue_bucket_T_1,
provision_category_T_1,
0,
on_balance_ratio_EAD_T_1,
performing_ind_T_1,
risk_rating_key_T_1 ,
risk_rating_code_T_1 ,
risk_rating_level2_key_T_1,
risk_rating_level2_code_T_1,
risk_rating_level2_descr_T_1,
ifrs_stage_PROV,               --- this was T0
days_pastdue_PROV,          --- this was T0
days_pastdue_bucket_PROV,          --- this was T0
provision_category_PROV,          --- this was T0
alloc_provision_amt_PROV,          --- this was T0
alloc_provision_amt_PROV_LC,
on_balance_ratio_PROV,
performing_ind_PROV,          --- this was T0
risk_rating_level2_code_PROV,
sme_ind ,
finrep_instrument_type,
finrep_instrument_type_key,
substr(finrep_instrument_type_descr,1,30), --pn added merge for fix STRY1210993
finrep_product_type,
finrep_product_type_key,
finrep_product_type_descr,
finrep_purpose  ,
finrep_purpose_key,
finrep_purpose_descr,
finrep_subordinate,
finrep_subordinate_key,
finrep_subordinate_descr,
finrep_sector   ,
finrep_sector_key,
finrep_sector_descr     ,
finrep_scope_indicator        , -- field to be created asap
ifrs_eligible_indicator ,
derecognition_reason_key,
derecognition_reason_code,
derecognition_reason_descr,
derecognition_date,
secured_by_com_prop_ind ,
secured_by_res_prop_ind ,
secured_by_non_mort_ind ,
0,
0,
0,
0,
0,
0,
0,
0,
0,
0,
0,
0,
0,
0,
intercompany_code,
customer_base_entity_code,
ing_group_cons_ind,
ing_bank_solo_ind,
ing_belgium_cons_ind,
ing_belgium_solo_ind,
ing_slaski_solo_ind,
ing_direct_australia_solo_ind,
ing_diba_solo_ind,
ing_turkey_solo_ind,
ing_eurasia_solo_ind,
default_ind_T0,
impaired_ind_T0,
forbearance_ind_T0,
default_ind_T_1,
impaired_ind_T_1,
forbearance_ind_T_1,
default_ind_PROV,
impaired_ind_PROV,
forbearance_ind_PROV,
low_credit_risk_ind,
product_level2_type_code,     --START EXTRA ATTRIBUTES
llp_prov_scope_fin_ac_ind_T0,
llp_prov_scope_fin_ac_ind_T_1,
llp_prov_scope_fin_ac_ind_PROV,
irrevocable_facility_ind,
stat_instrument_type_key,
stat_instrument_type_code,
stat_instrument_type_descr,
stat_instrument_subtype_key,
stat_instrument_subtype_code,
stat_instrument_subtype_descr,
stat_sector_key,
stat_sector_code,
stat_sector_descr,
npe_matching_step,
npe_12m_counter,--ORAMIGCATCHP3
npe_12m_ind_T0,
npe_12m_ind_T_1,
npe_12m_ind_PROV,
npe_fb_ind_T0,
npe_fb_ind_T_1,
npe_fb_ind_PROV,
llp_meeting_code_T0,
llp_meeting_key_T0,
llp_meeting_descr_T0,
llp_meeting_code_T_1,
llp_meeting_key_T_1,
llp_meeting_descr_T_1,
llp_meeting_code_PROV,
llp_meeting_key_PROV,
llp_meeting_descr_PROV,
acc_neg_changes_fv_cr_T0,
acc_neg_changes_fv_cr_T_1,
acc_neg_changes_fv_cr_PROV,
NULL as ifrs_stage_at_start,
NULL as ifrs_stage_date_at_start,
NULL as ifrs_matching_step
---ORAMIGSecondcatchup ? Begin
,origination_date
,forbearance_start_date
,0 as orig_event_prov_amt
,0 as orig_event_prov_amt_LC
,0 as derec_event_prov_amt
,0 as derec_event_prov_amt_LC
,0 as derec_writeoff_event_prov_amt
,0 as derec_writeoff_event_prov_amt_LC
,0 as forb_event_prov_amt
,0 as forb_event_prov_amt_LC
,0 as reforb_event_prov_amt
,0 as reforb_event_prov_amt_LC
,0 as ifrs9_model_event_prov_amt
,0 as ifrs9_model_event_prov_amt_LC
,0 as basel_model_event_prov_amt
,0 as basel_model_event_prov_amt_LC
,0 as securitised_ind
,0 as securitised_factor
,NULL as securitisation_code
,NULL as securitisation_legal_entity_key
,NULL as securitisation_descr
,0    as retained_position_ind
---ORAMIGSecondcatchup ? End
---ORAMIGThirdcatchup ? Start
, fdi.ltv_ratio as ltv_ratio
, fdi.ltv_ratio_class as ltv_ratio_class
,0 as inflow_npe_gross_carr_amt
,0 as outflow_npe_gross_carr_amt
, fdi.gross_carrying_amt as gross_carrying_amt_T_1
, fdi.cre_indicator
---ORAMIGThirdcatchup ? End
,0 as gross_carrying_amt_prev_Q4  --ORAMIGCATCHUP4
, fdi.performing_ind_prev_Q4 --ORAMIGCATCHUP4
, 'PREV_MTH_COLL_PROV' as finrep_record_type
-----Start of vdd_rrd_catchup_124-----
--, fdi.cre_scope_vre -- rolled back cre changes as part of 3033854
--, fdi.cre_scope_int -- rolled back cre changes as part of 3033854
-----End if vdd_rrd_catchup_124-------
,0 as cred_deriv_cover_capped_amt --CU6
,0 as cred_deriv_cover_capped_amt_LC --CU6
,fdi.CREDIT_COMMITMENT_IND --6100295
                  FROM
                    vpp_finrep_details_info fdi
                  WHERE
                    fdi.reporting_period = v_reporting_date_t_1 AND   fdi.system_id = v_system_id AND   fdi.finrep_scope_indicator = 'Y' AND   fdi.provision_category_prov
IN (
                        'COLLECTIVE',
                        'IAS37_COL','POCI_COL'
                    ) AND   (
                        fdi.alloc_provision_amt_prov > 0 OR    fdi.alloc_provision_amt_prov_lc > 0
                    ) AND/*   ( CAST(rtrim(
                        fdi.facility_id
                    ) AS VARCHAR2(30) ) + CAST(fdi.customer_id AS VARCHAR2(30) ) + CAST(rtrim(
                        fdi.local_outstanding_id --+ convert(varchar,fdi.outstanding_id) )
                    ) AS VARCHAR2(30) ) ) NOT IN (*/
                    ((rtrim(fdi.facility_id)) || fdi.customer_id || rtrim(fdi.local_outstanding_id) ) not in(
                        SELECT DISTINCT
                            /*( CAST(rtrim(
                                tmp.facility_id
                            ) AS VARCHAR2(30) ) + CAST(tmp.customer_id AS VARCHAR2(30) ) + CAST(rtrim(
                                tmp.local_outstanding_id -- + convert(varchar,tmp.outstanding_id) )
                            ) AS VARCHAR2(30) ) )*/
                            (rtrim(tmp.facility_id) || tmp.customer_id || rtrim(tmp.local_outstanding_id) )
                        FROM
                            tmp_vpp_finrep_details_info tmp
                        WHERE
                            tmp.reporting_period = v_reporting_date AND   tmp.system_id = v_system_id AND   tmp.provision_category_prov IS NOT NULL
                    )
                );

        EXCEPTION
            WHEN OTHERS THEN
                utils.handleerror(
                    sqlcode,
                    sqlerrm
                );
        END;

        v_debug_msg := $$plsql_line || ' of unit ' || $$plsql_unit || '<<dm count>>' || SQL%rowcount;

        utilities.show_debug(v_debug_msg);
        COMMIT;

    END IF;

    IF v_debug = 1 THEN
        BEGIN
            utilities.show_debug (replace(
                '[%1!] Update the carrying amount',
                '%1!',
                systimestamp
            ) );
        END;
    END IF;

    UPDATE /*+ PARALLEL enable_parallel_dml */  tmp_vpp_finrep_details_info fdi
        SET
            fdi.carrying_amt =
                CASE
                    WHEN fdi.on_balance_sheet_ind = 'N' THEN
                        fdi.gross_carrying_amt
                    WHEN ( fdi.gross_carrying_amt - nvl(
                        alloc_provision_amt_prov,
                        0
                    ) ) < 0 THEN
                        0
                    ELSE ( fdi.gross_carrying_amt - nvl(
                        alloc_provision_amt_prov,
                        0
                    ) )
                END
    WHERE
        reporting_period = v_reporting_date AND   system_id = v_system_id;

    COMMIT;
      --and (fdi.gross_carrying_amt  + fdi.loan_commitments_given_amt) > 0

      --Populate the carrying_amt into the respective bucket
        begin
            vpp_pop_nsfr_rw_buckets (v_system_id, v_reporting_date);
        exception when others then
            DBMS_OUTPUT.PUT_LINE(REPLACE('[%1!] Execution of Stored Procedure vpp_pop_nsfr_rw_buckets failed', '%1!', SYSTIMESTAMP));
            raise;
        end;

/*        IF v_retstatus <> 0
          BEGIN
            print '[%1!] Execution of Stored Procedure vpp_pop_nsfr_rw_buckets failed', getdate()
            raiserror @@error
            RETURN 1
          END*/
        COMMIT;

      -- Take the T-1 Cumulative provisions fo the facilities (which do not have Individual provisions in T0) from FINREP details Info history table
      /*
      select --top 10
      fcdi.reporting_period,
      fcdi.system_id,
      fcdi.source,
      fcdi.facility_id,
      sum(fcdi.alloc_provision_amt_PROV) as total_provision_amt
      into #tmp_FINREP_PROVISIONS_T_1
      from VPP_FINREP_DETAILS_INFO fcdi
      where fcdi.reporting_period = @reporting_date_t_1 and fcdi.system_id = @system_id
      and fcdi.facility_id not in (select distinct facility_id from tmp_FINREP_COVER_CAPPED_INFO where provision_category_T0 NOT IN ('INDIVIDUAL','IAS37_IND'))
      group by
      fcdi.reporting_period,
      fcdi.system_id,
      fcdi.source,
      fcdi.facility_id

      select --top 10
      diog.system_id,
       'B' as source,
      diog.facility_id,
      sum(diog.provision_amount) as total_provision_amt
      into #tmp_FINREP_PROVISIONS_T_1
      from DWH_IFRS_OUTSTANDING_GROUP diog
      where diog.record_valid_from = @reporting_date_t_1 and diog.system_id = @system_id
      and diog.provision_category NOT IN ('INDIVIDUAL','IAS37_IND','POCI_IND')
      and diog.facility_id not in (select distinct facility_id from tmp_FINREP_COVER_CAPPED_INFO)
      group by
      diog.system_id,
      'B',
      diog.facility_id



      --Update the T-1 Cumulative provisions in the main table tmp_FINREP_COVER_CAPPED_INFO

      Update tmp_FINREP_COVER_CAPPED_INFO fcci
      set fcci.total_provision_amt = fp_T_1.total_provision_amt
      from #tmp_FINREP_PROVISIONS_T_1 fp_T_1
      where fcci.system_id  = fp_T_1.system_id and fcci.facility_id  = fp_T_1.facility_id

      */
    IF v_debug = 1 THEN
        BEGIN
            utilities.show_debug (replace(
                '[%1!] Populate the Cover Capped info table',
                '%1!',
                systimestamp
            ) );
        END;
    END IF;

    BEGIN
        INSERT INTO tmp_finrep_cover_capped_info
            ( SELECT --top 10
                fcdi.reporting_period,
                fcdi.system_id,
                fcdi.source,
                fcdi.facility_key,
                fcdi.facility_id,
                fcdi.outstanding_group_key,
                fcdi.outstanding_group_id,
                SUM(fcdi.allocated_limit_amt) allocated_limit_amt,
                SUM(fcdi.allocated_outstanding_amt) allocated_outstanding_amt,
                SUM(fcdi.exposure_original) exposure_original,
                SUM(fcdi.gross_carrying_amt) total_gross_carrying_amt,
                SUM(fcdi.alloc_provision_amt_prov + fcdi.alloc_provision_amt_prov_lc) total_provision_amt,
                SUM(fcdi.carrying_amt + fcdi.loan_commitments_given_amt - nvl(fcdi.alloc_provision_amt_prov_lc,0)) maximum_cover_amt, --deduct off balance amount for story 3373580
                utils.convert_to_number(
                    '',
                    22,
                    4
                ) total_cover_amt,
                utils.convert_to_number(
                    '',
                    22,
                    4
                ) total_capped_cover_amt,
                utils.convert_to_number(
                    '',
                    10,
                    8
                ) capped_cover_ratio
              FROM
                tmp_vpp_finrep_details_info fcdi
              WHERE
                fcdi.reporting_period = v_reporting_date AND   fcdi.system_id = v_system_id AND   fcdi.record_valid_from = v_reporting_date
              GROUP BY
                fcdi.reporting_period,
                fcdi.system_id,
                fcdi.source,
                fcdi.facility_key,
                fcdi.facility_id,
                fcdi.outstanding_group_key,
                fcdi.outstanding_group_id
            );

        COMMIT;
    EXCEPTION
        WHEN OTHERS THEN
            utils.handleerror(
                sqlcode,
                sqlerrm
            );
    END;

    v_debug_msg := $$plsql_line || ' of unit ' || $$plsql_unit || '<<dm count>>' || SQL%rowcount;

    utilities.show_debug(v_debug_msg);
      -- Take the total cover amounts (which are in scope for FINREP) per limit
/*    utilities.truncate_table('tt_tmp_FINREP_COVER_AGGR');
    BEGIN
        INSERT  INTO tt_tmp_finrep_cover_aggr
            ( SELECT
                fci.reporting_period,
                fci.system_id,
                fci.source,
                fci.facility_key,
                fci.facility_id,
                fci.outstanding_group_key,
                fci.outstanding_group_id,
                SUM(original_cover_value) total_cover_amt
              FROM
                tmp_finrep_cover_info fci
              WHERE
                fci.reporting_period = v_reporting_date AND   fci.system_id = v_system_id AND   fci.finrep_cover_type IS NOT NULL AND   fci.finrep_cover_type <> 'N/A'
AND   original_cover_value > 0
              GROUP BY
                fci.reporting_period,
                fci.system_id,
                fci.source,
                fci.facility_key,
                fci.facility_id,
                fci.outstanding_group_key,
                fci.outstanding_group_id
            );
		commit; --per fix
        schema_maint.gather_idx_stats('tt_tmp_finrep_cover_aggr');

       /* MERGE INTO tmp_finrep_cover_capped_info fcci1 USING ( SELECT
            fcci.rowid row_id,
            fca.total_cover_amt,
            CASE
                    WHEN fcci.maximum_cover_amt <= 0 THEN
                        0
                    WHEN fca.total_cover_amt > fcci.maximum_cover_amt AND fca.total_cover_amt <> 0 THEN
                        fcci.maximum_cover_amt
                    ELSE fca.total_cover_amt
                END
            AS pos_3,
            CASE
                    WHEN fcci.maximum_cover_amt <= 0 THEN
                        0
                    WHEN fca.total_cover_amt > fcci.maximum_cover_amt AND fca.total_cover_amt <> 0 THEN
                        fcci.maximum_cover_amt / fca.total_cover_amt
                    ELSE 1
                END
            AS pos_4
                                                        FROM
            tmp_finrep_cover_capped_info fcci,
            tt_tmp_finrep_cover_aggr fca
                                                        WHERE
            fcci.reporting_period = v_reporting_date AND   fcci.system_id = v_system_id AND   fcci.reporting_period = fca.reporting_period AND   fcci.system_id
= fca.system_id AND   fcci.source = fca.source AND   fcci.facility_key = fca.facility_key AND   fcci.facility_id = fca.facility_id AND   fcci.outstanding_group_key
= fca.outstanding_group_key AND   fcci.outstanding_group_id = fca.outstanding_group_id
        )
        src ON ( fcci1.rowid = src.row_id )
        WHEN MATCHED THEN UPDATE SET fcci1.total_cover_amt = src.total_cover_amt,
        fcci1.total_capped_cover_amt = pos_3,
        fcci1.capped_cover_ratio = pos_4;


  MERGE  INTO (SELECT
    total_cover_amt,
    maximum_cover_amt,
    system_id,
    reporting_period,
    source,
    facility_key,
    outstanding_group_key,
    outstanding_group_id,
    total_capped_cover_amt,
    capped_cover_ratio,
    facility_id
FROM
    tmp_finrep_cover_capped_info fcci
WHERE
    fcci.reporting_period = v_reporting_date
    AND   fcci.system_id = v_system_id)fcci
  using (SELECT
    system_id,
    reporting_period,
    source,
    facility_key,
    outstanding_group_key,
    outstanding_group_id,
    total_cover_amt,
    facility_id
FROM
    tt_tmp_finrep_cover_aggr fca)fca
   on (fcci.reporting_period = fca.reporting_period
    AND   fcci.system_id = fca.system_id
    AND   fcci.source = fca.source
    AND   fcci.facility_key = fca.facility_key
    AND   fcci.facility_id = fca.facility_id
    AND   fcci.outstanding_group_key = fca.outstanding_group_key
    AND   fcci.outstanding_group_id = fca.outstanding_group_id)
 WHEN MATCHED THEN UPDATE SET fcci.total_cover_amt = fca.total_cover_amt,
    fcci.total_capped_cover_amt = CASE
    WHEN fcci.maximum_cover_amt <= 0 THEN 0
    WHEN fca.total_cover_amt > fcci.maximum_cover_amt
    AND fca.total_cover_amt <> 0 THEN fcci.maximum_cover_amt
    ELSE fca.total_cover_amt
    END,
    fcci.capped_cover_ratio = CASE
    WHEN fcci.maximum_cover_amt <= 0 THEN 0
    WHEN fca.total_cover_amt > fcci.maximum_cover_amt
    AND fca.total_cover_amt <> 0
    then fcci.maximum_cover_amt / fca.total_cover_amt else 1 end;

    EXCEPTION
        WHEN OTHERS THEN
            utils.handleerror(
                sqlcode,
                sqlerrm
            );
    END;

    v_debug_msg := $$plsql_line || ' of unit ' || $$plsql_unit || '<<dm count>>' || SQL%rowcount;

    utilities.show_debug(v_debug_msg);
	commit; --per fix */
      -- COMMIT
   /* MERGE INTO tmp_finrep_cover_info fci1 USING ( SELECT
       distinct fci.rowid row_id,              --NJ:DISTINCT ADDED TO RESOLVE 'stable set of rows' : 29-08-2019
        CASE
                WHEN fcci.total_cover_amt > 0 AND fci.finrep_cover_type <> 'N/A' THEN
                    utils.round_(
                        fcci.total_capped_cover_amt * (fci.original_cover_value / fcci.total_cover_amt),
                        4
                    )
                ELSE 0
            END
        AS pos_2,
        CASE
                WHEN fcci.total_cover_amt > 0 AND fci.finrep_cover_type <> 'N/A' THEN
                    utils.round_(
                        (fci.original_cover_value / fcci.total_cover_amt),
                        8
                    )
                ELSE 1
            END
        AS pos_3
                                             FROM
        tmp_finrep_cover_info fci,
        tmp_finrep_cover_capped_info fcci
                                             WHERE
        fci.reporting_period = v_reporting_date AND   fci.system_id = v_system_id AND   fci.reporting_period = fcci.reporting_period AND   fci.system_id = fcci
.system_id AND   fci.source = fcci.source AND   fci.facility_key = fcci.facility_key AND   fci.facility_id = fcci.facility_id AND   fci.outstanding_group_key
= fcci.outstanding_group_key AND   fci.outstanding_group_id = fcci.outstanding_group_id
    )
    src ON ( fci1.rowid = src.row_id )
    WHEN MATCHED THEN UPDATE SET fci1.cover_capped_amount = pos_2,
    fci1.capped_cover_ratio = pos_3;*/


/*
    MERGE  INTO (SELECT
    system_id,
    reporting_period,
    source,
    facility_key,
    outstanding_group_key,
    outstanding_group_id,
    cover_capped_amount,
    capped_cover_ratio,
    facility_id,
    original_cover_value,
    finrep_cover_type
FROM
    tmp_finrep_cover_info fci1
WHERE
    fci1.reporting_period = v_reporting_date AND fci1.system_id = v_system_id)fci1
  using (SELECT
    system_id,
    reporting_period,
    source,
    facility_key,
    outstanding_group_key,
    outstanding_group_id,
    total_cover_amt,
    facility_id,
    total_capped_cover_amt
FROM
    tmp_finrep_cover_capped_info fcci)fcci
   on (fci1.reporting_period = fcci.reporting_period
    AND   fci1.system_id = fcci.system_id
    AND   fci1.source = fcci.source
    AND   fci1.facility_key = fcci.facility_key
    AND   fci1.facility_id = fcci.facility_id
    AND   fci1.outstanding_group_key = fcci.outstanding_group_key
    AND   fci1.outstanding_group_id = fcci.outstanding_group_id)
 WHEN MATCHED THEN UPDATE SET
        fci1.cover_capped_amount =
        CASE
            WHEN fcci.total_cover_amt > 0
                 AND fci1.finrep_cover_type <> 'N/A' THEN utils.round_(fcci.total_capped_cover_amt * (fci1.original_cover_value / fcci.total_cover_amt),4)
            ELSE 0
        END,
        fci1.capped_cover_ratio =
        CASE
            WHEN fcci.total_cover_amt > 0
                 AND fci1.finrep_cover_type <> 'N/A' THEN utils.round_( (fci1.original_cover_value / fcci.total_cover_amt),8)
            ELSE 1
        END; */

--//2021017
	utilities.truncate_table('tmp_finrep_cover_allocation');
	BEGIN
		INSERT /*+ APPEND enable_parallel_dml */ INTO tmp_finrep_cover_allocation(
			PRIORITY,
			RANK,
			OUTSTANDING_GROUP_KEY,
			COVER_KEY,
			ORIGINAL_COVER_VALUE,
			COVER_CAPPED_AMOUNT,
			CARRYING_AND_LOAN_COMM_AMT,
			FINREP_COVER_TYPE
			)
		SELECT /*+ PARALLEL */
			 t.priority
			,RANK() OVER (partition by c.outstanding_group_key  ORDER BY c.outstanding_group_key,t.priority, c.cover_key ASC) rank
			,c.OUTSTANDING_GROUP_KEY
			,c.COVER_KEY
			,c.ORIGINAL_COVER_VALUE
			,c.COVER_CAPPED_AMOUNT
			--,NVL(o.CARRYING_AMT,0) + NVL(o.LOAN_COMMITMENTS_GIVEN_AMT,0) - CASE WHEN nvl(fcdi.alloc_provision_amt_prov_lc,0) < 0 THEN 0 ELSE nvl(fcdi.alloc_provision_amt_prov_lc,0) END  CARRYING_AND_LOAN_COMM_AMT
			,NVL(o.CARRYING_AMT,0) + CASE WHEN NVL(o.LOAN_COMMITMENTS_GIVEN_AMT,0) - nvl(o.alloc_provision_amt_prov_lc,0) < 0
            THEN 0 ELSE NVL(o.LOAN_COMMITMENTS_GIVEN_AMT,0) - nvl(o.alloc_provision_amt_prov_lc,0) END CARRYING_AND_LOAN_COMM_AMT
            ,c.finrep_cover_type
		FROM tmp_finrep_cover_info c
		JOIN   (SELECT CASE WHEN finrep_cover_type = 'COM_PROP' AND o.cre_indicator = 'N' THEN 2
							WHEN finrep_cover_type = 'RES_PROP' AND o.cre_indicator = 'Y' THEN 2
							ELSE t.priority
					   END AS priority
					  ,c.outstanding_group_key
					  ,c.cover_key
				FROM tmp_finrep_cover_info c
				JOIN tmp_vpp_finrep_details_info o ON c.outstanding_group_key = o.outstanding_group_key
				JOIN tt_finrep_cover_type t ON finrep_cover_type = finrep_cover_type_id) t
			ON t.outstanding_group_key = c.outstanding_group_key
			AND t.cover_key = c.cover_key
		JOIN tmp_vpp_finrep_details_info o
			ON c.outstanding_group_key = o.outstanding_group_key;

		EXCEPTION
			WHEN OTHERS THEN
				utils.handleerror(
					sqlcode,
					sqlerrm
				);
    END;
	COMMIT;
	BEGIN
		UPDATE /*+ enable_parallel_dml */ tmp_finrep_cover_allocation
		SET COVER_CAPPED_AMOUNT = LEAST( (CARRYING_AND_LOAN_COMM_AMT) ,ORIGINAL_COVER_VALUE)
		WHERE rank =  1;

		EXCEPTION
			WHEN OTHERS THEN
				utils.handleerror(
					sqlcode,
					sqlerrm
				);
    END;
	COMMIT;
	BEGIN
		SELECT MIN(rank) INTO v_min_rank from tmp_finrep_cover_allocation where rank >  1;
		SELECT MAX(rank) INTO v_max_rank from tmp_finrep_cover_allocation;

		WHILE (v_min_rank <= v_max_rank) LOOP
			BEGIN
				BEGIN
					MERGE /*+ enable_parallel_dml */ INTO tmp_finrep_cover_allocation t
					USING (SELECT /*+ PARALLEL */ OUTSTANDING_GROUP_KEY, SUM(COVER_CAPPED_AMOUNT) as COVER_CAPPED_AMOUNT_AGGR
							FROM tmp_finrep_cover_allocation
							WHERE rank < v_min_rank
							GROUP BY OUTSTANDING_GROUP_KEY
							) src
					ON ( t.OUTSTANDING_GROUP_KEY = src.OUTSTANDING_GROUP_KEY
						 AND t.rank =  v_min_rank )
					WHEN MATCHED THEN UPDATE SET t.COVER_CAPPED_AMOUNT = LEAST(original_cover_value,(CARRYING_AND_LOAN_COMM_AMT-COVER_CAPPED_AMOUNT_AGGR));

					EXCEPTION
					WHEN no_data_found THEN
					NULL;
					WHEN OTHERS THEN
					utils.handleerror(sqlcode,sqlerrm);
				END	 ;
				COMMIT;
				SELECT MIN(rank) INTO v_min_rank from tmp_finrep_cover_allocation WHERE rank > v_min_rank;
			END;
		END LOOP ;
	END;

	BEGIN
		MERGE /*+ enable_parallel_dml */ INTO (SELECT
		outstanding_group_key,
		outstanding_group_id,
		cover_capped_amount,
		cover_key
	FROM
		tmp_finrep_cover_info fci1
	WHERE
		fci1.reporting_period = v_reporting_date AND fci1.system_id = v_system_id)fci1
	  using (SELECT /*+ PARALLEL */
		cover_capped_amount,
		outstanding_group_key,
		cover_key
	FROM
		tmp_finrep_cover_allocation fcci)fcci
	   on (   fci1.outstanding_group_key = fcci.outstanding_group_key
		AND   fci1.cover_key = fcci.cover_key)
	 WHEN MATCHED THEN UPDATE SET
			fci1.cover_capped_amount = fcci.cover_capped_amount;
    EXCEPTION
        WHEN OTHERS THEN
            utils.handleerror(
                sqlcode,
                sqlerrm
            );
    END;

    COMMIT;
	BEGIN
		MERGE /*+ enable_parallel_dml */ INTO tmp_vpp_finrep_details_info fdi USING ( SELECT /*+ PARALLEL */
		    DISTINCT fci.reporting_period,
			fci.system_id,
			fci.source,
			fci.facility_key,
			fci.outstanding_group_key
			FROM
			tmp_finrep_cover_info fci
			WHERE fci.finrep_cover_type IN ('COM_PROP','RES_PROP')
			AND EXISTS(SELECT 1 FROM tmp_finrep_cover_info WHERE outstanding_group_key = fci.outstanding_group_key AND finrep_cover_type = 'COM_PROP')
			AND EXISTS(SELECT 1 FROM tmp_finrep_cover_info WHERE outstanding_group_key = fci.outstanding_group_key AND finrep_cover_type = 'RES_PROP')
			)
		src ON ( fdi.reporting_period = src.reporting_period AND fdi.system_id = src.system_id AND fdi.source = src.source
		AND fdi.facility_key = src.facility_key AND fdi.outstanding_group_key = src.outstanding_group_key
		AND fdi.reporting_period = v_reporting_date AND   fdi.system_id = v_system_id)
		WHEN MATCHED THEN UPDATE SET fdi.secured_by_com_prop_ind = CASE WHEN fdi.cre_indicator = 'Y' THEN 'Y' ELSE 'N' END,
									 fdi.secured_by_res_prop_ind = CASE WHEN fdi.cre_indicator = 'N' THEN 'Y' ELSE 'N' END;

    EXCEPTION
        WHEN OTHERS THEN
            utils.handleerror(
                sqlcode,
                sqlerrm
            );
    END;
	COMMIT;
      --10. Populate the aggregated cover amounts
    IF v_debug = 1 THEN
        BEGIN
            utilities.show_debug (replace(
                '[%1!] 10. Populate the aggregated cover amounts ',
                '%1!',
                systimestamp
            ) );
        END;
    END IF;
 -- Code commented for story 2020652 - FINREP - Change FINREP Collateral Allocation between Drawn and Undrawn Exposure
 /*   utilities.truncate_table('tt_tmp_finrep_cover_aggr_info');
    BEGIN
        INSERT   INTO tt_tmp_finrep_cover_aggr_info
            ( SELECT --top 10
                fci.reporting_period,
                fci.system_id,
                fci.source,
                fci.facility_key,
                fci.facility_id,
                fci.outstanding_group_id,
                fci.outstanding_group_key,
                SUM(
                    CASE
                        WHEN fci.finrep_cover_type = 'COM_PROP' THEN
                            fci.cover_capped_amount
                        ELSE 0
                    END
                ) com_prop_capped_cover_amt,
                SUM(
                    CASE
                        WHEN fci.finrep_cover_type = 'RES_PROP' THEN
                            fci.cover_capped_amount
                        ELSE 0
                    END
                ) res_prop_capped_cover_amt,
                SUM(
                    CASE
                        WHEN fci.finrep_cover_type = 'CASH' THEN
                            fci.cover_capped_amount
                        ELSE 0
                    END
                ) cash_capped_cover_amt,
                SUM(
                    CASE
                        WHEN fci.finrep_cover_type = 'REST' THEN
                            fci.cover_capped_amount
                        ELSE 0
                    END
                ) rest_capped_cover_amt,
                SUM(
                    CASE
                        WHEN fci.finrep_cover_type = 'FINAN_GUAR' THEN
                            fci.cover_capped_amount
                        ELSE 0
                    END
                ) finan_guar_capped_cover_amt,
                sum(case when fci.finrep_cover_type = 'MOV_PROP' then fci.cover_capped_amount else 0 end)  mov_prop_cover_capped_amt,
                sum(case when fci.finrep_cover_type = 'EQ_DEB_SEC' then fci.cover_capped_amount else 0 end)  eq_debt_sec_cover_capped_amt,
                sum(case when fci.finrep_cover_type = 'CRED_DERIV' then fci.cover_capped_amount else 0 end) cred_deriv_cover_capped_amt --CU6
              FROM
                tmp_finrep_cover_info fci
              WHERE
                fci.reporting_period = v_reporting_date AND   fci.system_id = v_system_id
              GROUP BY
                fci.reporting_period,
                fci.system_id,
                fci.source,
                fci.facility_key,
                fci.facility_id,
                fci.outstanding_group_id,
                fci.outstanding_group_key
            );

    EXCEPTION
        WHEN OTHERS THEN
            utils.handleerror(
                sqlcode,
                sqlerrm
            );
    END;

    v_debug_msg := $$plsql_line || ' of unit ' || $$plsql_unit || '<<dm count>>' || SQL%rowcount;
    utilities.show_debug(v_debug_msg);
	commit; --per fix
    schema_maint.gather_idx_stats('tt_tmp_finrep_cover_aggr_info');
      --select * from tt_tmp_FINREP_COVER_AGGR_INFO where facility_id = 'FC10007291/BLO!AIDDB2'
      --11. Update the capped cover amount in FINREP Details table by splitting on/off balance sheet records
    MERGE   INTO tmp_vpp_finrep_details_info fdi1 USING ( SELECT
        fdi.rowid row_id,
        fdi.on_balance_ratio_ca_t0 * fcai.com_prop_capped_cover_amt AS pos_2,
        ( 1 - fdi.on_balance_ratio_ca_t0 ) * fcai.com_prop_capped_cover_amt AS pos_3,
        fdi.on_balance_ratio_ca_t0 * fcai.res_prop_capped_cover_amt AS pos_4,
        ( 1 - fdi.on_balance_ratio_ca_t0 ) * fcai.res_prop_capped_cover_amt AS pos_5,
        fdi.on_balance_ratio_ca_t0 * fcai.cash_capped_cover_amt AS pos_6,
        ( 1 - fdi.on_balance_ratio_ca_t0 ) * fcai.cash_capped_cover_amt AS pos_7,
        fdi.on_balance_ratio_ca_t0 * fcai.rest_capped_cover_amt AS pos_8,
		( 1 - fdi.on_balance_ratio_ca_t0 ) * fcai.rest_capped_cover_amt AS pos_9,
        fdi.on_balance_ratio_ca_t0 * fcai.finan_guar_capped_cover_amt AS pos_10,
        ( 1 - fdi.on_balance_ratio_ca_t0 ) * fcai.finan_guar_capped_cover_amt AS pos_11,
        fdi.on_balance_ratio_CA_T0 * fcai.mov_prop_cover_capped_amt AS pos_12,
        (1 - fdi.on_balance_ratio_CA_T0) * fcai.mov_prop_cover_capped_amt AS pos_13,
         fdi.on_balance_ratio_CA_T0 * fcai.eq_debt_sec_cover_capped_amt AS pos_14,
        (1 - fdi.on_balance_ratio_CA_T0) * fcai.eq_debt_sec_cover_capped_amt   AS pos_15,
        fdi.on_balance_ratio_CA_T0 * fcai.cred_deriv_cover_capped_amt AS pos_16, --CU6
        (1 - fdi.on_balance_ratio_CA_T0) * fcai.cred_deriv_cover_capped_amt AS pos_17 --CU6
 FROM
        tmp_vpp_finrep_details_info fdi,
        tt_tmp_finrep_cover_aggr_info fcai
        WHERE fdi.reporting_period = v_reporting_date
        AND   fdi.system_id = v_system_id
        AND   fdi.record_valid_from = v_reporting_date
        AND   fdi.reporting_period= fcai.reporting_period
        AND   fdi.system_id = fcai.system_id
        AND   fdi.source = fcai.source
        AND   fdi.facility_key = fcai.facility_key
        AND   fdi.outstanding_group_key= fcai.outstanding_group_key
    )
    src ON ( fdi1.rowid = src.row_id )
    WHEN MATCHED THEN UPDATE SET fdi1.com_prop_cover_capped_amt = pos_2,
    fdi1.com_prop_cover_capped_amt_lc = pos_3,
    fdi1.res_prop_cover_capped_amt = pos_4,
    fdi1.res_prop_cover_capped_amt_lc = pos_5,
    fdi1.cash_cover_capped_amt -- confirm
     = pos_6,
    fdi1.cash_cover_capped_amt_lc = pos_7,
    fdi1.rest_cover_capped_amt -- confirm
     = pos_8,
    fdi1.rest_cover_capped_amt_lc = pos_9,
    fdi1.finan_guar_cover_capped_amt -- confirm
     = pos_10,
    fdi1.finan_guar_cover_capped_amt_lc = pos_11,
    fdi1.mov_prop_cover_capped_amt =pos_12,
    fdi1.mov_prop_cover_capped_amt_LC = pos_13,
    fdi1.eq_debt_sec_cover_capped_amt=pos_14,
    fdi1.eq_debt_sec_cover_capped_amt_LC=pos_15,
    fdi1.cred_deriv_cover_capped_amt= pos_16, --CU6
    fdi1.cred_deriv_cover_capped_amt_LC= pos_17; --CU6

*/
    COMMIT;

 -------------------------------------------
 --2020652 - FINREP - Change FINREP Collateral Allocation between Drawn and Undrawn Exposure
 -------------------------------------------
utilities.truncate_table('tmp_finrep_cover_allocation_aggr');

BEGIN
    INSERT /*+ APPEND enable_parallel_dml */ INTO tmp_finrep_cover_allocation_aggr (
        outstanding_group_key,
        rank,
        cover_capped_amount,
        carrying_amt,
        loan_commitments_given_amt,
        finrep_cover_type
    )
        SELECT /*+ PARALLEL */
            c.outstanding_group_key,
            MIN(rank),
            SUM(cover_capped_amount),
            MAX(nvl(o.carrying_amt, 0)),
            MAX(nvl(o.loan_commitments_given_amt, 0)),
            finrep_cover_type
        FROM
                 tmp_finrep_cover_allocation c
            JOIN tmp_vpp_finrep_details_info o ON c.outstanding_group_key = o.outstanding_group_key
        GROUP BY
            c.outstanding_group_key,
            finrep_cover_type;

EXCEPTION
    WHEN OTHERS THEN
        utils.handleerror(sqlcode, sqlerrm);
END;

v_debug_msg := $$plsql_line
               || ' of plsql unit '
               || 'tmp_finrep_cover_allocation_aggr count :: '
               || SQL%rowcount;

utilities.show_debug(v_debug_msg);

COMMIT;


BEGIN
    UPDATE /*+ enable_parallel_dml */ tmp_finrep_cover_allocation_aggr
    SET
        cover_capped_amt_c = least(cover_capped_amount, carrying_amt),
        cover_capped_amt_lc = least((cover_capped_amount - least(cover_capped_amount, carrying_amt)),
                                    loan_commitments_given_amt)
    WHERE
        rank = 1;

END;

COMMIT;


BEGIN
    SELECT MIN(rank) INTO v_min_rank from tmp_finrep_cover_allocation_aggr where rank >  1;
    SELECT MAX(rank) INTO v_max_rank from tmp_finrep_cover_allocation_aggr;

    WHILE (v_min_rank <= v_max_rank) LOOP
        BEGIN
            BEGIN
                MERGE /*+ enable_parallel_dml */ INTO tmp_finrep_cover_allocation_aggr t
                USING (SELECT /*+ PARALLEL */ OUTSTANDING_GROUP_KEY, NVL(SUM(COVER_CAPPED_AMT_C),0) as COVER_CAPPED_AMT_C_AGGR,
                             NVL(SUM(COVER_CAPPED_AMT_LC),0) as COVER_CAPPED_AMT_LC_AGGR
                        FROM tmp_finrep_cover_allocation_aggr
                        WHERE rank < v_min_rank
                        GROUP BY OUTSTANDING_GROUP_KEY) src
                ON ( t.OUTSTANDING_GROUP_KEY = src.OUTSTANDING_GROUP_KEY AND t.rank =  v_min_rank )
                WHEN MATCHED THEN UPDATE SET t.COVER_CAPPED_AMT_C = LEAST(t.cover_capped_amount,(t.CARRYING_AMT-src.COVER_CAPPED_AMT_C_AGGR)),
                                             t.COVER_CAPPED_AMT_LC = LEAST( (t.cover_capped_amount - LEAST(t.cover_capped_amount,(t.CARRYING_AMT-src.COVER_CAPPED_AMT_C_AGGR))),t.LOAN_COMMITMENTS_GIVEN_AMT - src.COVER_CAPPED_AMT_LC_AGGR );

                EXCEPTION
                WHEN no_data_found THEN
                NULL;
                WHEN OTHERS THEN
                utils.handleerror(sqlcode,sqlerrm);
            END ;
            COMMIT;
            SELECT MIN(rank) INTO v_min_rank from tmp_finrep_cover_allocation_aggr WHERE rank > v_min_rank;
        END;
    END LOOP ;
END;

  COMMIT;

 BEGIN
MERGE /*+ enable_parallel_dml */ INTO tmp_vpp_finrep_details_info fdi1 USING ( SELECT /*+ PARALLEL */
    fdi.outstanding_group_key,
    SUM(CASE WHEN fcai.finrep_cover_type = 'COM_PROP' THEN fcai.COVER_CAPPED_AMT_C ELSE 0 END)  com_prop_cover_capped_amt,
    SUM(CASE WHEN fcai.finrep_cover_type = 'COM_PROP' THEN fcai.COVER_CAPPED_AMT_LC ELSE 0 END) com_prop_cover_capped_amt_lc,
    SUM(CASE WHEN fcai.finrep_cover_type = 'RES_PROP' THEN fcai.COVER_CAPPED_AMT_C ELSE 0 END)  res_prop_cover_capped_amt,
    SUM(CASE WHEN fcai.finrep_cover_type = 'RES_PROP' THEN fcai.COVER_CAPPED_AMT_LC ELSE 0 END) res_prop_cover_capped_amt_lc,
    SUM(CASE WHEN fcai.finrep_cover_type = 'CASH' THEN fcai.COVER_CAPPED_AMT_C ELSE 0 END)  cash_cover_capped_amt,
    SUM(CASE WHEN fcai.finrep_cover_type = 'CASH' THEN fcai.COVER_CAPPED_AMT_LC ELSE 0 END) cash_cover_capped_amt_lc,
    SUM(CASE WHEN fcai.finrep_cover_type = 'REST' THEN fcai.COVER_CAPPED_AMT_C ELSE 0 END)  rest_cover_capped_amt,
    SUM(CASE WHEN fcai.finrep_cover_type = 'REST' THEN fcai.COVER_CAPPED_AMT_LC ELSE 0 END) rest_cover_capped_amt_lc,
    SUM(CASE WHEN fcai.finrep_cover_type = 'FINAN_GUAR' THEN fcai.COVER_CAPPED_AMT_C ELSE 0 END)  finan_guar_cover_capped_amt,
    SUM(CASE WHEN fcai.finrep_cover_type = 'FINAN_GUAR' THEN fcai.COVER_CAPPED_AMT_LC ELSE 0 END) finan_guar_cover_capped_amt_lc,
    SUM(CASE WHEN fcai.finrep_cover_type = 'MOV_PROP' THEN fcai.COVER_CAPPED_AMT_C ELSE 0 END)  mov_prop_cover_capped_amt,
    SUM(CASE WHEN fcai.finrep_cover_type = 'MOV_PROP' THEN fcai.COVER_CAPPED_AMT_LC ELSE 0 END) mov_prop_cover_capped_amt_LC,
    SUM(CASE WHEN fcai.finrep_cover_type = 'EQ_DEB_SEC' THEN fcai.COVER_CAPPED_AMT_C ELSE 0 END)  eq_debt_sec_cover_capped_amt,
    SUM(CASE WHEN fcai.finrep_cover_type = 'EQ_DEB_SEC' THEN fcai.COVER_CAPPED_AMT_LC ELSE 0 END) eq_debt_sec_cover_capped_amt_LC,
    SUM(CASE WHEN fcai.finrep_cover_type = 'CRED_DERIV' THEN fcai.COVER_CAPPED_AMT_C ELSE 0 END)  cred_deriv_cover_capped_amt,
    SUM(CASE WHEN fcai.finrep_cover_type = 'CRED_DERIV' THEN fcai.COVER_CAPPED_AMT_LC ELSE 0 END) cred_deriv_cover_capped_amt_LC

FROM
    tmp_vpp_finrep_details_info fdi,
    tmp_finrep_cover_allocation_aggr fcai
    WHERE fdi.outstanding_group_key= fcai.outstanding_group_key GROUP BY fdi.outstanding_group_key
)
src ON ( fdi1.outstanding_group_key = src.outstanding_group_key )
WHEN MATCHED THEN UPDATE SET fdi1.com_prop_cover_capped_amt = src.com_prop_cover_capped_amt,
                            fdi1.com_prop_cover_capped_amt_lc = src.com_prop_cover_capped_amt_lc,
                            fdi1.res_prop_cover_capped_amt = src.res_prop_cover_capped_amt,
                            fdi1.res_prop_cover_capped_amt_lc = src.res_prop_cover_capped_amt_lc,
                            fdi1.cash_cover_capped_amt = src.cash_cover_capped_amt,
                            fdi1.cash_cover_capped_amt_lc = src.cash_cover_capped_amt_lc,
                            fdi1.rest_cover_capped_amt = src.rest_cover_capped_amt,
                            fdi1.rest_cover_capped_amt_lc = src.rest_cover_capped_amt_lc,
                            fdi1.finan_guar_cover_capped_amt = src.finan_guar_cover_capped_amt,
                            fdi1.finan_guar_cover_capped_amt_lc = src.finan_guar_cover_capped_amt_lc,
                            fdi1.mov_prop_cover_capped_amt = src.mov_prop_cover_capped_amt,
                            fdi1.mov_prop_cover_capped_amt_LC = src.mov_prop_cover_capped_amt_LC,
                            fdi1.eq_debt_sec_cover_capped_amt = src.eq_debt_sec_cover_capped_amt,
                            fdi1.eq_debt_sec_cover_capped_amt_LC = src.eq_debt_sec_cover_capped_amt_LC,
                            fdi1.cred_deriv_cover_capped_amt = src.cred_deriv_cover_capped_amt,
                            fdi1.cred_deriv_cover_capped_amt_LC = src.cred_deriv_cover_capped_amt_LC;

     EXCEPTION
        WHEN OTHERS THEN
            utils.handleerror(sqlcode,sqlerrm);
    END;


    COMMIT;
 -------------------------------------------

      -- Update statutory columns
    IF v_debug = 1 THEN
        BEGIN
            utilities.show_debug (replace(
                '[%1!] 12. Updating statatory columns and irrevocable_facility_ind ',
                '%1!',
                systimestamp
            ) );
        END;
    END IF;

/*    MERGE INTO tmp_vpp_finrep_details_info fdi1 USING ( SELECT
        fdi.rowid row_id,
        p.statutory_product_type_key,
        p.code as pcode,
        p.description,
        sp.statutory_product_type_key as sp_statutory_product_type_key,
        sp.code as spcode,
        sp.description as sp_descr
                                                       FROM
        tmp_vpp_finrep_details_info fdi
        JOIN facility_type ft
        ON ft.facility_type_key   = fdi.product_type_key
        JOIN statutory_product_type sp
        ON sp.code   = ft.statutory_product_type AND sp.record_valid_from <= v_reporting_date AND (
            sp.record_valid_until IS NULL OR sp.record_valid_until > v_reporting_date
        )
        JOIN statutory_product_type p
        ON p.statutory_product_type_key   = sp.higher_level_key
                                                       WHERE
        fdi.reporting_period = v_reporting_date AND   fdi.system_id = v_system_id
    )
    src ON ( fdi1.rowid = src.row_id )
    WHEN MATCHED THEN UPDATE SET fdi1.stat_instrument_type_key = src.sp_statutory_product_type_key,
    fdi1.stat_instrument_type_code = src.pcode,
    fdi1.stat_instrument_type_descr = src.description,
    fdi1.stat_instrument_subtype_key = src.statutory_product_type_key,
    fdi1.stat_instrument_subtype_code = src.spcode,
    fdi1.stat_instrument_subtype_descr = src.sp_descr; */

	MERGE /*+ enable_parallel_dml */ INTO tmp_vpp_finrep_details_info fdi1 USING ( SELECT /*+ PARALLEL */
        fdi.rowid row_id,
        p.statutory_product_type_key,
        p.code as pcode,
        p.description,
        sp.statutory_product_type_key as sp_statutory_product_type_key,
        sp.code as spcode,
        sp.description as sp_descr
                                                       FROM
        tmp_vpp_finrep_details_info fdi
        JOIN facility_type ft
        ON ft.facility_type_key   = fdi.product_type_key
        JOIN statutory_product_type sp
        ON sp.code   = ft.statutory_product_type AND sp.record_valid_from <= v_reporting_date AND (
            sp.record_valid_until IS NULL OR sp.record_valid_until > v_reporting_date
        )
        JOIN statutory_product_type p
        ON p.statutory_product_type_key   = sp.higher_level_key
                                                       WHERE
        fdi.reporting_period = v_reporting_date AND   fdi.system_id = v_system_id
    )
    src ON ( fdi1.rowid = src.row_id )
    WHEN MATCHED THEN UPDATE SET fdi1.stat_instrument_type_key = src.statutory_product_type_key,--src.sp_statutory_product_type_key,
    fdi1.stat_instrument_type_code = src.pcode,
    fdi1.stat_instrument_type_descr = src.description,
    fdi1.stat_instrument_subtype_key = src.sp_statutory_product_type_key,--src.statutory_product_type_key,
    fdi1.stat_instrument_subtype_code = src.spcode,
    fdi1.stat_instrument_subtype_descr = src.sp_descr;

    --PK:Merge Modifications : 19-07-2019
    COMMIT;
    MERGE /*+ enable_parallel_dml */ INTO tmp_vpp_finrep_details_info fdi USING ( SELECT /*+ PARALLEL */
        fs.code,
        fs.finrep_sector_key,
        fs.description,
        it.industry_type_key
        FROM
        industry_type it
        JOIN finrep_sector fs
        ON fs.code = it.statutory_sector AND fs.record_valid_from <= v_reporting_date AND (
            nvl(fs.record_valid_until, utilities.record_default_date) > v_reporting_date ) )
    src ON ( src.industry_type_key = fdi.industry_type_key AND fdi.reporting_period = v_reporting_date AND   fdi.system_id = v_system_id)
    WHEN MATCHED THEN UPDATE SET fdi.stat_sector_code = src.code,
    fdi.stat_sector_key = src.finrep_sector_key,
    fdi.stat_sector_descr = src.description;

    COMMIT;
    UPDATE /*+ PARALLEL enable_parallel_dml */  tmp_vpp_finrep_details_info fdi
        SET
            irrevocable_facility_ind =
                CASE
                    WHEN ( finrep_instrument_type = 'LOAN_ADV' )
					-- AND ( committed_indicator = 'C' ) THEN -- Commented for #6100334
					AND ( CREDIT_COMMITMENT_IND in ( 'CCC', 'UCC') ) THEN  -- Added for #6100334
                        'Y'
                    ELSE 'N'
                END
    WHERE
        fdi.reporting_period = v_reporting_date AND   fdi.system_id = v_system_id;

    COMMIT;
      -- fill the tmp-table tmp_vpp_movement_event_transpose based on vpp_movement_event
    fill_tmp_vpp_movement_event_transpose(
        reporting_date   => v_reporting_date,
        system_id        => v_system_id,
        batch_id         => v_batch_id,
        debug            => v_debug
    );
      -- 1. Update the movement-event-attributes for matching records current month

    MERGE /*+ enable_parallel_dml */ INTO tmp_vpp_finrep_details_info t1 USING ( SELECT /*+ PARALLEL */
        distinct t.rowid row_id,
        me.origination_date,
        me.forbearance_start_date,
        utils.round_(t.on_balance_ratio_ead_t0 * me.orig_event_prov_amt,4) AS pos_4,
        utils.round_((1 - t.on_balance_ratio_ead_t0) * me.orig_event_prov_amt,4) AS pos_5,
        utils.round_(t.on_balance_ratio_ead_t0 * me.derec_event_prov_amt,4) AS pos_6,
        utils.round_((1 - t.on_balance_ratio_ead_t0) * me.derec_event_prov_amt,4) AS pos_7,
        utils.round_( t.on_balance_ratio_ead_t0 * me.derec_writeoff_event_prov_amt, 4) AS pos_8,
        utils.round_((1 - t.on_balance_ratio_ead_t0) * me.derec_writeoff_event_prov_amt,4) AS pos_9,
        utils.round_(t.on_balance_ratio_ead_t0 * me.forb_event_prov_amt,4) AS pos_10,
        utils.round_((1 - t.on_balance_ratio_ead_t0) * me.forb_event_prov_amt,4) AS pos_11,
        utils.round_(t.on_balance_ratio_ead_t0 * me.reforb_event_prov_amt,4) AS pos_12,
        utils.round_((1 - t.on_balance_ratio_ead_t0) * me.reforb_event_prov_amt,4) AS pos_13,
        utils.round_(t.on_balance_ratio_ead_t0 * me.ifrs9_model_event_prov_amt,4) AS pos_14,
        utils.round_((1 - t.on_balance_ratio_ead_t0) * me.ifrs9_model_event_prov_amt,4) AS pos_15,
        utils.round_(t.on_balance_ratio_ead_t0 * me.basel_model_event_prov_amt,4) AS pos_16,
        utils.round_((1 - t.on_balance_ratio_ead_t0) * me.basel_model_event_prov_amt,4) AS pos_17
                                                     FROM
        tmp_vpp_finrep_details_info t
        JOIN tmp_vpp_movement_event_transpose me
        ON me.outstanding_group_key   = t.outstanding_group_key
           --AND me.reporting_date        = t.reporting_period -- don't join on reporting_date because it should als update the added provision-records of previous period
                                                     WHERE
        t.reporting_period = v_reporting_date
    )
    src ON ( t1.rowid = src.row_id )
    WHEN MATCHED THEN UPDATE SET t1.origination_date = src.origination_date,
    t1.forbearance_start_date = src.forbearance_start_date,
    t1.orig_event_prov_amt = pos_4,
    t1.orig_event_prov_amt_lc = pos_5,
    t1.derec_event_prov_amt = pos_6,
    t1.derec_event_prov_amt_lc = pos_7,
    t1.derec_writeoff_event_prov_amt = pos_8,
    t1.derec_writeoff_event_prov_amt_LC = pos_9,
    t1.forb_event_prov_amt = pos_10,
    t1.forb_event_prov_amt_lc = pos_11,
    t1.reforb_event_prov_amt = pos_12,
    t1.reforb_event_prov_amt_lc = pos_13,
    t1.ifrs9_model_event_prov_amt = pos_14,
    t1.ifrs9_model_event_prov_amt_lc = pos_15,
    t1.basel_model_event_prov_amt = pos_16,
    t1.basel_model_event_prov_amt_lc = pos_17;
      -- 2. Insert the missing records in the current reporting period from previous month which has movements, I don't know if this happens because before we add also records for provisions of previous period.
	commit; --per fix
 -- Added Gather Stats for #5797959
	SCHEMA_MAINT.gather_idx_stats ('tmp_vpp_movement_event_transpose');
	SCHEMA_MAINT.gather_idx_stats ('tmp_vpp_finrep_details_info');


    BEGIN
       INSERT INTO tmp_vpp_finrep_details_info (
    reporting_period,
    record_valid_from,
    record_valid_until,
    system_id,
    source,
    facility_key,
    facility_id,
    higher_level_facility_key,
    higher_level_facility_id,
    outstanding_group_id,
    outstanding_group_key,
    local_outstanding_id,
    outstanding_id,
    outstanding_key,
    customer_id,
    customer_key,
    instrument_id,
    instrument_type,
    os_booking_office_key,
    os_booking_office_code,
    os_booking_base_entity_key,
    os_booking_base_entity_code,
    os_booking_base_entity_descr,
    os_initiating_office_key,
    os_initiating_office_code,
    os_initiating_base_entity_key,
    os_initiating_base_entity_code,
    os_initiating_base_entity_descr,
    fac_booking_office_key,
    fac_booking_office_code,
    fac_booking_base_entity_key,
    fac_booking_base_entity_code,
    fac_booking_base_entity_descr,
    fac_initiating_office_key,
    fac_initiating_office_code,
    fac_initiating_base_entity_key,
    fac_initiating_base_entity_code,
    fac_initiating_base_entity_descr,
    customer_type_key,
    customer_type_code,
    customer_type_descr,
    industry_type_key,
    industry_type_code,
    industry_type_nace_2_0,
    nace_highest_level_code,
    residence_country_key,
    residence_country_code,
    residence_country_name,
    regulatory_country_code,
    regulatory_country_key,
    regulatory_country_name,
    basel_official_approach,
    exposure_class_original_sa,
    exposure_class_original_irb,
    exposure_class_sa_not_def,
    exposure_class_sec,
    limit_type_key,
    limit_type_code,
    limit_type_descr,
    product_type_key,
    product_type_code,
    product_type_descr,
    risk_category_level1_code,
    risk_category_level1_key,
    ing_legal_entity_key,
    ing_legal_entity_code,
    ifrs_accounting_classification,
    ifrs_measurement_category,
    on_balance_sheet_ind,
    on_balance_ind,
    committed_indicator,
    poci_type_key,
    poci_type,
    poci_type_descr,
    advised_indicator,
            ---ORAMIGSecondcatchup ? Begin
    forbearance_measure_key,
    forbearance_measure_code,
    forbearance_measure_descr,
    forbearance_measure_1_key,
    forbearance_measure_1_code,
    forbearance_measure_1_descr,
    forbearance_measure_2_key,
    forbearance_measure_2_code,
    forbearance_measure_2_descr,
    forbearance_measure_3_key,
    forbearance_measure_3_code,
    forbearance_measure_3_descr,
    forbearance_measure_4_key,
    forbearance_measure_4_code,
    forbearance_measure_4_descr,
    forbearance_measure_5_key,
    forbearance_measure_5_code,
    forbearance_measure_5_descr,
    forbearance_status_key,
    forbearance_status_code,
---ORAMIGSecondcatchup ? End
    allocated_limit_amt,
    allocated_outstanding_amt,
    exposure_original,
    carrying_amt,
    gross_carrying_amt,
    loan_commitments_given_amt,
    accrued_interest_amt,
    write_off_amt_partial,
    write_off_amt_full,
    ifrs_stage_t0,
    days_pastdue_t0,
    days_pastdue_bucket_t0,
    provision_category_t0,
    alloc_provision_amt_t0,
    on_balance_ratio_ead_t0,
    on_balance_ratio_ca_t0,
    performing_ind_t0,
    risk_rating_key_t0,
    risk_rating_code_t0,
    risk_rating_level2_key_t0,
    risk_rating_level2_code_t0,
    risk_rating_level2_descr_t0,
    ifrs_stage_t_1,
    days_pastdue_t_1,
    days_pastdue_bucket_t_1,
    provision_category_t_1,
    alloc_provision_amt_t_1,
    on_balance_ratio_ead_t_1,
    performing_ind_t_1,
    risk_rating_key_t_1,
    risk_rating_code_t_1,
    risk_rating_level2_key_t_1,
    risk_rating_level2_code_t_1,
    risk_rating_level2_descr_t_1,
    ifrs_stage_prov,
    days_pastdue_prov,
    days_pastdue_bucket_prov,
    provision_category_prov,
    alloc_provision_amt_prov,
    alloc_provision_amt_prov_lc,
    on_balance_ratio_prov,
    performing_ind_prov,
    risk_rating_level2_code_prov,
    sme_ind,
    finrep_instrument_type,
    finrep_instrument_type_key,
    finrep_instrument_type_descr,
    finrep_product_type,
    finrep_product_type_key,
    finrep_product_type_descr,
    finrep_purpose,
    finrep_purpose_key,
    finrep_purpose_descr,
    finrep_subordinate,
    finrep_subordinate_key,
    finrep_subordinate_descr,
    finrep_sector,
    finrep_sector_key,
    finrep_sector_descr,
    finrep_scope_indicator,
    ifrs_eligible_indicator,
    derecognition_reason_key,
    derecognition_reason_code,
    derecognition_reason_descr,
    derecognition_date,
    secured_by_com_prop_ind,
    secured_by_res_prop_ind,
    secured_by_non_mort_ind,
    com_prop_cover_capped_amt,
    com_prop_cover_capped_amt_lc,
    res_prop_cover_capped_amt,
    res_prop_cover_capped_amt_lc,
    cash_cover_capped_amt,
    cash_cover_capped_amt_lc,
    rest_cover_capped_amt,
    rest_cover_capped_amt_lc,
    finan_guar_cover_capped_amt,
    finan_guar_cover_capped_amt_lc
    ,mov_prop_cover_capped_amt
,mov_prop_cover_capped_amt_LC
,eq_debt_sec_cover_capped_amt
,eq_debt_sec_cover_capped_amt_LC,
    intercompany_code,
    customer_base_entity_code,
    ing_group_cons_ind,
    ing_bank_solo_ind,
    ing_belgium_cons_ind,
    ing_belgium_solo_ind,
    ing_slaski_solo_ind,
    ing_direct_australia_solo_ind,
    ing_diba_solo_ind,
    ing_turkey_solo_ind,
    ing_eurasia_solo_ind,
    default_ind_t0,
    impaired_ind_t0,
    forbearance_ind_t0,
    default_ind_t_1,
    impaired_ind_t_1,
    forbearance_ind_t_1,
    default_ind_prov,
    impaired_ind_prov,
    forbearance_ind_prov,
    low_credit_risk_ind,
    product_level2_type_code,
    llp_prov_scope_fin_ac_ind_t0,
    llp_prov_scope_fin_ac_ind_t_1,
    llp_prov_scope_fin_ac_ind_prov,
    irrevocable_facility_ind,
    stat_instrument_type_key,
    stat_instrument_type_code,
    stat_instrument_type_descr,
    stat_instrument_subtype_key,
    stat_instrument_subtype_code,
    stat_instrument_subtype_descr,
    stat_sector_key,
    stat_sector_code,
    stat_sector_descr,
    npe_matching_step
,npe_12m_counter  ,
    npe_12m_ind_t0,
    npe_12m_ind_t_1,
    npe_12m_ind_prov,
    npe_fb_ind_t0,
    npe_fb_ind_t_1,
    npe_fb_ind_prov,
    llp_meeting_code_t0,
    llp_meeting_key_t0,
    llp_meeting_descr_t0,
    llp_meeting_code_t_1,
    llp_meeting_key_t_1,
    llp_meeting_descr_t_1,
    llp_meeting_code_prov,
    llp_meeting_key_prov,
    llp_meeting_descr_prov,
    acc_neg_changes_fv_cr_t0,
    acc_neg_changes_fv_cr_t_1,
    acc_neg_changes_fv_cr_prov,
    ifrs_stage_at_start,
    ifrs_stage_date_at_start,
    ifrs_matching_step
      -- for movements
   ,
    origination_date,
    forbearance_start_date,
    orig_event_prov_amt,
    orig_event_prov_amt_lc,
    derec_event_prov_amt,
    derec_event_prov_amt_lc,
    derec_writeoff_event_prov_amt,
    derec_writeoff_event_prov_amt_lc,
    forb_event_prov_amt,
    forb_event_prov_amt_lc,
    reforb_event_prov_amt,
    reforb_event_prov_amt_lc,
    ifrs9_model_event_prov_amt,
    ifrs9_model_event_prov_amt_lc,
    basel_model_event_prov_amt,
    basel_model_event_prov_amt_lc
            ---ORAMIGSecondcatchup ? Begin
   ,
    securitised_ind,
    securitised_factor,
    securitisation_code,
    securitisation_legal_entity_key,
    securitisation_descr,
    retained_position_ind
---ORAMIGSecondcatchup ? End
,ltv_ratio
,ltv_ratio_class
,inflow_npe_gross_carr_amt
,outflow_npe_gross_carr_amt
,gross_carrying_amt_T_1
,cre_indicator
,gross_carrying_amt_prev_Q4
,performing_ind_prev_Q4
,finrep_record_type
-------Start of vdd_rrd_catchup_124------------
--,cre_scope_vre -- rolled back cre changes as part of 3033854
--,cre_scope_int -- rolled back cre changes as part of 3033854
-------End of vdd_rrd_catchup_124--------------
,cred_deriv_cover_capped_amt --CU6
,cred_deriv_cover_capped_amt_LC --CU6
,CREDIT_COMMITMENT_IND --6100295
)
    ( SELECT
        v_reporting_date reporting_period,
        t.record_valid_from,
        t.record_valid_until,
        t.system_id,
        t.source,
        t.facility_key,
        t.facility_id,
        t.higher_level_facility_key,
        t.higher_level_facility_id,
        t.outstanding_group_id,
        t.outstanding_group_key,
        t.local_outstanding_id,
        t.outstanding_id,
        t.outstanding_key,
        t.customer_id,
        t.customer_key,
        t.instrument_id,
        t.instrument_type,
        t.os_booking_office_key,
        t.os_booking_office_code,
        t.os_booking_base_entity_key,
        t.os_booking_base_entity_code,
        t.os_booking_base_entity_descr,
        t.os_initiating_office_key,
        t.os_initiating_office_code,
        t.os_initiating_base_entity_key,
        t.os_initiating_base_entity_code,
        t.os_initiating_base_entity_descr,
        t.fac_booking_office_key,
        t.fac_booking_office_code,
        t.fac_booking_base_entity_key,
        t.fac_booking_base_entity_code,
        t.fac_booking_base_entity_descr,
        t.fac_initiating_office_key,
        t.fac_initiating_office_code,
        t.fac_initiating_base_entity_key,
        t.fac_initiating_base_entity_code,
        t.fac_initiating_base_entity_descr,
        t.customer_type_key,
        t.customer_type_code,
        t.customer_type_descr,
        t.industry_type_key,
        t.industry_type_code,
        t.industry_type_nace_2_0,
        t.nace_highest_level_code,
        t.residence_country_key,
        t.residence_country_code,
        t.residence_country_name,
        t.regulatory_country_code,
        t.regulatory_country_key,
        t.regulatory_country_name,
        t.basel_official_approach,
        t.exposure_class_original_sa,
        t.exposure_class_original_irb,
        t.exposure_class_sa_not_def,
        t.exposure_class_sec,
        t.limit_type_key,
        t.limit_type_code,
        t.limit_type_descr,
        t.product_type_key,
        t.product_type_code,
        t.product_type_descr,
        t.risk_category_level1_code,
        t.risk_category_level1_key,
        t.ing_legal_entity_key,
        t.ing_legal_entity_code,
        t.ifrs_accounting_classification,
        t.ifrs_measurement_category,
        t.on_balance_sheet_ind,
        t.on_balance_ind,
        t.committed_indicator,
        t.poci_type_key,
        t.poci_type,
        t.poci_type_descr,
        t.advised_indicator,
                ---ORAMIGSecondcatchup ? Begin
        t.forbearance_measure_key,
        t.forbearance_measure_code,
        t.forbearance_measure_descr,
        t.forbearance_measure_1_key,
        t.forbearance_measure_1_code,
        t.forbearance_measure_1_descr,
        t.forbearance_measure_2_key,
        t.forbearance_measure_2_code,
        t.forbearance_measure_2_descr,
        t.forbearance_measure_3_key,
        t.forbearance_measure_3_code,
        t.forbearance_measure_3_descr,
        t.forbearance_measure_4_key,
        t.forbearance_measure_4_code,
        t.forbearance_measure_4_descr,
        t.forbearance_measure_5_key,
        t.forbearance_measure_5_code,
        t.forbearance_measure_5_descr,
        t.forbearance_status_key,
---ORAMIGSecondcatchup ? End
        t.forbearance_status_code,
        0 allocated_limit_amt,
        0 allocated_outstanding_amt,
        0 exposure_original,
        0 carrying_amt,
        0 gross_carrying_amt,
        0 loan_commitments_given_amt,
        0 accrued_interest_amt,
        0 write_off_amt_partial,
        0 write_off_amt_full,
        t.ifrs_stage_t0,
        t.days_pastdue_t0,
        t.days_pastdue_bucket_t0,
        t.provision_category_t0,
        0 alloc_provision_amt_t0,
        t.on_balance_ratio_ead_t0,
        t.on_balance_ratio_ca_t0,
        t.performing_ind_t0,
        t.risk_rating_key_t0,
        t.risk_rating_code_t0,
        t.risk_rating_level2_key_t0,
        t.risk_rating_level2_code_t0,
        t.risk_rating_level2_descr_t0,
        t.ifrs_stage_t_1,
        t.days_pastdue_t_1,
        t.days_pastdue_bucket_t_1,
        t.provision_category_t_1,
        0 alloc_provision_amt_t_1,
        t.on_balance_ratio_ead_t_1,
        t.performing_ind_t_1,
        t.risk_rating_key_t_1,
        t.risk_rating_code_t_1,
        t.risk_rating_level2_key_t_1,
        t.risk_rating_level2_code_t_1,
        t.risk_rating_level2_descr_t_1,
        t.ifrs_stage_prov,
        t.days_pastdue_prov,
        t.days_pastdue_bucket_prov,
        t.provision_category_prov,
        0 alloc_provision_amt_prov,
        0 alloc_provision_amt_prov_lc,
        t.on_balance_ratio_prov,
        t.performing_ind_prov,
        t.risk_rating_level2_code_prov,
        t.sme_ind,
        t.finrep_instrument_type,
        t.finrep_instrument_type_key,
        substr(t.finrep_instrument_type_descr,1,30),  --pn added merge for story STRY1210993
        t.finrep_product_type,
        t.finrep_product_type_key,
        t.finrep_product_type_descr,
        t.finrep_purpose,
        t.finrep_purpose_key,
        t.finrep_purpose_descr,
        t.finrep_subordinate,
        t.finrep_subordinate_key,
        t.finrep_subordinate_descr,
        t.finrep_sector,
        t.finrep_sector_key,
        t.finrep_sector_descr,
        t.finrep_scope_indicator,
        t.ifrs_eligible_indicator,
        t.derecognition_reason_key,
        t.derecognition_reason_code,
        t.derecognition_reason_descr,
        t.derecognition_date,
        t.secured_by_com_prop_ind,
        t.secured_by_res_prop_ind,
        t.secured_by_non_mort_ind,
        0 com_prop_cover_capped_amt,
        0 com_prop_cover_capped_amt_lc,
        0 res_prop_cover_capped_amt,
        0 res_prop_cover_capped_amt_lc,
        0 cash_cover_capped_amt,
        0 cash_cover_capped_amt_lc,
        0 rest_cover_capped_amt,
        0 rest_cover_capped_amt_lc,
        0 finan_guar_cover_capped_amt,
        0 finan_guar_cover_capped_amt_lc,
        0                             AS mov_prop_cover_capped_amt
        ,0                             AS mov_prop_cover_capped_amt_LC
        ,0                             AS eq_debt_sec_cover_capped_amt
        ,0                             AS eq_debt_sec_cover_capped_amt_LC  ,
        t.intercompany_code,
        t.customer_base_entity_code,
        t.ing_group_cons_ind,
        t.ing_bank_solo_ind,
        t.ing_belgium_cons_ind,
        t.ing_belgium_solo_ind,
        t.ing_slaski_solo_ind,
        t.ing_direct_australia_solo_ind,
        t.ing_diba_solo_ind,
        t.ing_turkey_solo_ind,
        t.ing_eurasia_solo_ind,
        t.default_ind_t0,
        t.impaired_ind_t0,
        t.forbearance_ind_t0,
        t.default_ind_t_1,
        t.impaired_ind_t_1,
        t.forbearance_ind_t_1,
        t.default_ind_prov,
        t.impaired_ind_prov,
        t.forbearance_ind_prov,
        t.low_credit_risk_ind,
        t.product_level2_type_code,
        t.llp_prov_scope_fin_ac_ind_t0,
        t.llp_prov_scope_fin_ac_ind_t_1,
        t.llp_prov_scope_fin_ac_ind_prov,
        t.irrevocable_facility_ind,
        t.stat_instrument_type_key,
        t.stat_instrument_type_code,
        t.stat_instrument_type_descr,
        t.stat_instrument_subtype_key,
        t.stat_instrument_subtype_code,
        t.stat_instrument_subtype_descr,
        t.stat_sector_key,
        t.stat_sector_code,
        t.stat_sector_descr
        ,t.npe_matching_step
        ,t.npe_12m_counter ,
        t.npe_12m_ind_t0,
        t.npe_12m_ind_t_1,
        t.npe_12m_ind_prov,
        t.npe_fb_ind_t0,
        t.npe_fb_ind_t_1,
        t.npe_fb_ind_prov,
        t.llp_meeting_code_t0,
        t.llp_meeting_key_t0,
        t.llp_meeting_descr_t0,
        t.llp_meeting_code_t_1,
        t.llp_meeting_key_t_1,
        t.llp_meeting_descr_t_1,
        t.llp_meeting_code_prov,
        t.llp_meeting_key_prov,
        t.llp_meeting_descr_prov,
        t.acc_neg_changes_fv_cr_t0,
        t.acc_neg_changes_fv_cr_t_1,
        t.acc_neg_changes_fv_cr_prov,
        t.ifrs_stage_at_start,
        t.ifrs_stage_date_at_start,
        t.ifrs_matching_step,
                 -- for movements
        me.origination_date origination_date,
        me.forbearance_start_date forbearance_start_date,
        utils.round_(t.on_balance_ratio_ead_t0 * me.orig_event_prov_amt,4) orig_event_prov_amt,
        utils.round_( (1 - t.on_balance_ratio_ead_t0) * me.orig_event_prov_amt,4) orig_event_prov_amt_lc,
        utils.round_(t.on_balance_ratio_ead_t0 * me.derec_event_prov_amt,4) derec_event_prov_amt,
        utils.round_( (1 - t.on_balance_ratio_ead_t0) * me.derec_event_prov_amt,4) derec_event_prov_amt_lc,
        utils.round_(t.on_balance_ratio_ead_t0 * me.derec_writeoff_event_prov_amt,4) derec_writeoff_event_prov_amt,
        utils.round_( (1 - t.on_balance_ratio_ead_t0) * me.derec_writeoff_event_prov_amt,4) derec_writeoff_event_prov_amt_,
        utils.round_(t.on_balance_ratio_ead_t0 * me.forb_event_prov_amt,4) forb_event_prov_amt,
        utils.round_( (1 - t.on_balance_ratio_ead_t0) * me.forb_event_prov_amt,4) forb_event_prov_amt_lc,
        utils.round_(t.on_balance_ratio_ead_t0 * me.reforb_event_prov_amt,4) reforb_event_prov_amt,
        utils.round_( (1 - t.on_balance_ratio_ead_t0) * me.reforb_event_prov_amt,4) reforb_event_prov_amt_lc,
        utils.round_(t.on_balance_ratio_ead_t0 * me.ifrs9_model_event_prov_amt,4) ifrs9_model_event_prov_amt,
        utils.round_( (1 - t.on_balance_ratio_ead_t0) * me.ifrs9_model_event_prov_amt,4) ifrs9_model_event_prov_amt_lc,
        utils.round_(t.on_balance_ratio_ead_t0 * me.basel_model_event_prov_amt,4) basel_model_event_prov_amt,
        utils.round_( (1 - t.on_balance_ratio_ead_t0) * me.basel_model_event_prov_amt,4) basel_model_event_prov_amt_lc
                ---ORAMIGSecondcatchup ? Begin
       ,
        t.securitised_ind,
        t.securitised_factor,
        t.securitisation_code,
        t.securitisation_legal_entity_key,
        t.securitisation_descr,
        t.retained_position_ind
---ORAMIGSecondcatchup ? END
, t.ltv_ratio
, t.ltv_ratio_class
, 0 as inflow_npe_gross_carr_amt
 ,CASE WHEN t.record_valid_from = V_end_of_last_year AND t.performing_ind_T0 = 'N' THEN t.gross_carrying_amt ELSE 0 END AS outflow_npe_gross_carr_amt
, t.gross_carrying_amt
, t.cre_indicator
, 0 as gross_carrying_amt_prev_Q4
, t.performing_ind_prev_Q4
, 'PREV_MTH_MOV_EVENT' as finrep_record_type
-----Start of vdd_rrd_catchup_124-------
--, t.cre_scope_vre -- rolled back cre changes as part of 3033854
--, t.cre_scope_int -- rolled back cre changes as part of 3033854
-----End of vdd_rrd_catchup_124---------
, 0 as cred_deriv_cover_capped_amt --CU6
, 0 as cred_deriv_cover_capped_amt_LC --CU6
,t.CREDIT_COMMITMENT_IND --6100295
      FROM
        vpp_finrep_details_info t
        JOIN tmp_vpp_movement_event_transpose me ON me.reporting_date = t.reporting_period -- previous month
                                                    AND me.reporting_period = v_reporting_date
                                                    AND me.system_id = t.system_id
                                                    AND me.facility_key = t.facility_key
                                                    AND me.outstanding_group_key = t.outstanding_group_key
      WHERE
        t.reporting_period = v_reporting_date_t_1 -- previous month
        AND   t.record_valid_from = t.reporting_period
		-- Changed cast to 88 for loan IQ changes #4971394
        --AND   ( CAST(rtrim(t.system_id) AS VARCHAR2(30) ) || CAST(t.facility_key AS VARCHAR2(30) ) || CAST(rtrim(t.outstanding_group_key) AS VARCHAR2(30) ) )
		AND   ( CAST(rtrim(t.system_id) AS VARCHAR2(30) ) || CAST(t.facility_key AS VARCHAR2(88) ) || CAST(rtrim(t.outstanding_group_key) AS VARCHAR2(30) ) )
NOT IN (
            SELECT
		-- Changed cast to 88 for loan IQ changes #4971394
                -- ( CAST(rtrim(system_id) AS VARCHAR2(30) ) || CAST(facility_key AS VARCHAR2(30) ) || CAST(rtrim(outstanding_group_key) AS VARCHAR2(30) ) )
				( CAST(rtrim(system_id) AS VARCHAR2(30) ) || CAST(facility_key AS VARCHAR2(88) ) || CAST(rtrim(outstanding_group_key) AS VARCHAR2(30) ) )
            FROM
                tmp_vpp_finrep_details_info
            WHERE
                reporting_period = v_reporting_date
                --AND   record_valid_from = v_reporting_date_t_1
        )
		-- Added for #5797959 start
		AND (t.facility_id, t.facility_key,t.OUTSTANDING_GROUP_KEY) IN
		( SELECT p.facility_id, p.facility_key,p.OUTSTANDING_GROUP_KEY
		FROM vpp_finrep_details_info p
		WHERE
		p.reporting_period = v_reporting_date_t_1 -- previous month
		AND   p.record_valid_from = p.reporting_period
		AND   NOT EXISTS( SELECT 1 FROM dwh_facility d WHERE p.facility_id = d.facility_id AND d.record_valid_from = v_reporting_date AND d.system_id <> V_system_id )
		UNION
		SELECT p.facility_id, p.facility_key,p.OUTSTANDING_GROUP_KEY
		FROM vpp_finrep_details_info p
		WHERE
		p.reporting_period = v_reporting_date_t_1 -- previous month
		AND   p.record_valid_from = p.reporting_period
		AND NOT EXISTS(SELECT 1 FROM dwh_outstanding WHERE local_outstanding_id = RTRIM(p.local_outstanding_id) AND record_valid_from = v_reporting_date)
		)
		-- Added for #5797959 end

		-- Commented for #5797959
	/*
AND (NOT EXISTS( SELECT 1 FROM dwh_facility d WHERE t.facility_id = d.facility_id AND d.record_valid_from = V_reporting_date AND d.system_id <> V_system_id)
    OR
    NOT EXISTS(SELECT 1 FROM dwh_outstanding where local_outstanding_id = rtrim(t.local_outstanding_id) AND record_valid_from = v_reporting_date)
    )
	*/
    );

    EXCEPTION
        WHEN OTHERS THEN
            utils.handleerror(
                sqlcode,
                sqlerrm
            );
    END;

    v_debug_msg := $$plsql_line || ' of unit ' || $$plsql_unit || '<<dm count>>' || SQL%rowcount;

    utilities.show_debug(v_debug_msg);
	commit; --per fix
    --ORAMIGCATCHUP3 START
    -- 3. Insert the missing matured records in the current reporting period from previous month which were non-performing to get the outflow amounts.

INSERT INTO tmp_VPP_FINREP_DETAILS_INFO
(reporting_period
,record_valid_from
,record_valid_until
,system_id
,source
,facility_key
,facility_id
,higher_level_facility_key
,higher_level_facility_id
,outstanding_group_id
,outstanding_group_key
,local_outstanding_id
,outstanding_id
,outstanding_key
,customer_id
,customer_key
,instrument_id
,instrument_type
,os_booking_office_key
,os_booking_office_code
,os_booking_base_entity_key
,os_booking_base_entity_code
,os_booking_base_entity_descr
,os_initiating_office_key
,os_initiating_office_code
,os_initiating_base_entity_key
,os_initiating_base_entity_code
,os_initiating_base_entity_descr
,fac_booking_office_key
,fac_booking_office_code
,fac_booking_base_entity_key
,fac_booking_base_entity_code
,fac_booking_base_entity_descr
,fac_initiating_office_key
,fac_initiating_office_code
,fac_initiating_base_entity_key
,fac_initiating_base_entity_code
,fac_initiating_base_entity_descr
,customer_type_key
,customer_type_code
,customer_type_descr
,industry_type_key
,industry_type_code
,industry_type_nace_2_0
,nace_highest_level_code
,residence_country_key
,residence_country_code
,residence_country_name
,regulatory_country_code
,regulatory_country_key
,regulatory_country_name
,basel_official_approach
,exposure_class_original_sa
,exposure_class_original_irb
,exposure_class_sa_not_def
,exposure_class_sec
,limit_type_key
,limit_type_code
,limit_type_descr
,product_type_key
,product_type_code
,product_type_descr
,risk_category_level1_code
,risk_category_level1_key
,ing_legal_entity_key
,ing_legal_entity_code
,ifrs_accounting_classification
,ifrs_measurement_category
,on_balance_sheet_ind
,on_balance_ind
,committed_indicator
,poci_type_key
,poci_type
,poci_type_descr
,advised_indicator
,forbearance_measure_key
,forbearance_measure_code
,forbearance_measure_descr
,forbearance_measure_1_key
,forbearance_measure_1_code
,forbearance_measure_1_descr
,forbearance_measure_2_key
,forbearance_measure_2_code
,forbearance_measure_2_descr
,forbearance_measure_3_key
,forbearance_measure_3_code
,forbearance_measure_3_descr
,forbearance_measure_4_key
,forbearance_measure_4_code
,forbearance_measure_4_descr
,forbearance_measure_5_key
,forbearance_measure_5_code
,forbearance_measure_5_descr
,forbearance_status_key
,forbearance_status_code
,allocated_limit_amt
,allocated_outstanding_amt
,exposure_original
,carrying_amt
,gross_carrying_amt
,loan_commitments_given_amt
,accrued_interest_amt
,write_off_amt_partial
,write_off_amt_full
,ifrs_stage_T0
,days_pastdue_T0
,days_pastdue_bucket_T0
,provision_category_T0
,alloc_provision_amt_T0
,on_balance_ratio_EAD_T0
,on_balance_ratio_CA_T0
,performing_ind_T0
,risk_rating_key_T0
,risk_rating_code_T0
,risk_rating_level2_key_T0
,risk_rating_level2_code_T0
,risk_rating_level2_descr_T0
,ifrs_stage_T_1
,days_pastdue_T_1
,days_pastdue_bucket_T_1
,provision_category_T_1
,alloc_provision_amt_T_1
,on_balance_ratio_EAD_T_1
,performing_ind_T_1
,risk_rating_key_T_1
,risk_rating_code_T_1
,risk_rating_level2_key_T_1
,risk_rating_level2_code_T_1
,risk_rating_level2_descr_T_1
,ifrs_stage_PROV
,days_pastdue_PROV
,days_pastdue_bucket_PROV
,provision_category_PROV
,alloc_provision_amt_PROV
,alloc_provision_amt_PROV_LC
,on_balance_ratio_PROV
,performing_ind_PROV
,risk_rating_level2_code_PROV
,sme_ind
,finrep_instrument_type
,finrep_instrument_type_key
,finrep_instrument_type_descr
,finrep_product_type
,finrep_product_type_key
,finrep_product_type_descr
,finrep_purpose
,finrep_purpose_key
,finrep_purpose_descr
,finrep_subordinate
,finrep_subordinate_key
,finrep_subordinate_descr
,finrep_sector
,finrep_sector_key
,finrep_sector_descr
,finrep_scope_indicator
,ifrs_eligible_indicator
,derecognition_reason_key
,derecognition_reason_code
,derecognition_reason_descr
,derecognition_date
,secured_by_com_prop_ind
,secured_by_res_prop_ind
,secured_by_non_mort_ind
,com_prop_cover_capped_amt
,com_prop_cover_capped_amt_LC
,res_prop_cover_capped_amt
,res_prop_cover_capped_amt_LC
,cash_cover_capped_amt
,cash_cover_capped_amt_LC
,rest_cover_capped_amt
,rest_cover_capped_amt_LC
,finan_guar_cover_capped_amt
,finan_guar_cover_capped_amt_LC
,mov_prop_cover_capped_amt
,mov_prop_cover_capped_amt_LC
,eq_debt_sec_cover_capped_amt
,eq_debt_sec_cover_capped_amt_LC
,intercompany_code
,customer_base_entity_code
,ing_group_cons_ind
,ing_bank_solo_ind
,ing_belgium_cons_ind
,ing_belgium_solo_ind
,ing_slaski_solo_ind
,ing_direct_australia_solo_ind
,ing_diba_solo_ind
,ing_turkey_solo_ind
,ing_eurasia_solo_ind
,default_ind_T0
,impaired_ind_T0
,forbearance_ind_T0
,default_ind_T_1
,impaired_ind_T_1
,forbearance_ind_T_1
,default_ind_PROV
,impaired_ind_PROV
,forbearance_ind_PROV
,low_credit_risk_ind
,product_level2_type_code
,llp_prov_scope_fin_ac_ind_T0
,llp_prov_scope_fin_ac_ind_T_1
,llp_prov_scope_fin_ac_ind_PROV
,irrevocable_facility_ind
,stat_instrument_type_key
,stat_instrument_type_code
,stat_instrument_type_descr
,stat_instrument_subtype_key
,stat_instrument_subtype_code
,stat_instrument_subtype_descr
,stat_sector_key
,stat_sector_code
,stat_sector_descr
,npe_matching_step
,npe_12m_counter
,npe_12m_ind_T0
,npe_12m_ind_T_1
,npe_12m_ind_PROV
,npe_fb_ind_T0
,npe_fb_ind_T_1
,npe_fb_ind_PROV
,llp_meeting_code_T0
,llp_meeting_key_T0
,llp_meeting_descr_T0
,llp_meeting_code_T_1
,llp_meeting_key_T_1
,llp_meeting_descr_T_1
,llp_meeting_code_PROV
,llp_meeting_key_PROV
,llp_meeting_descr_PROV
,acc_neg_changes_fv_cr_T0
,acc_neg_changes_fv_cr_T_1
,acc_neg_changes_fv_cr_PROV
,ifrs_stage_at_start
,ifrs_stage_date_at_start
,ifrs_matching_step
,origination_date
,forbearance_start_date
,orig_event_prov_amt
,orig_event_prov_amt_LC
,derec_event_prov_amt
,derec_event_prov_amt_LC
,derec_writeoff_event_prov_amt
,derec_writeoff_event_prov_amt_LC
,forb_event_prov_amt
,forb_event_prov_amt_LC
,reforb_event_prov_amt
,reforb_event_prov_amt_LC
,ifrs9_model_event_prov_amt
,ifrs9_model_event_prov_amt_LC
,basel_model_event_prov_amt
,basel_model_event_prov_amt_LC
,securitised_ind
,securitised_factor
,securitisation_code
,securitisation_legal_entity_key
,securitisation_descr
,retained_position_ind
,inflow_npe_gross_carr_amt
,outflow_npe_gross_carr_amt
,gross_carrying_amt_T_1
,cre_indicator
,gross_carrying_amt_prev_Q4  --ORAMIGCATCHUP4
,performing_ind_prev_Q4  --ORAMIGCATCHUP4
,finrep_record_type
-----------Start of vdd_rrd_catchup_124----
--,cre_scope_vre -- rolled back cre changes as part of 3033854
--,cre_scope_int -- rolled back cre changes as part of 3033854
-----------End of vdd_rrd_catchup_124------
,cred_deriv_cover_capped_amt --CU6
,cred_deriv_cover_capped_amt_LC --CU6
,CREDIT_COMMITMENT_IND --6100295
)
SELECT V_reporting_date AS reporting_period
, fdi.record_valid_from
, fdi.record_valid_until
, fdi.system_id
, fdi.source
, fdi.facility_key
, fdi.facility_id
, fdi.higher_level_facility_key
, fdi.higher_level_facility_id
, fdi.outstanding_group_id
, fdi.outstanding_group_key
, fdi.local_outstanding_id
, fdi.outstanding_id
, fdi.outstanding_key
, fdi.customer_id
, fdi.customer_key
, fdi.instrument_id
, fdi.instrument_type
, fdi.os_booking_office_key
, fdi.os_booking_office_code
, fdi.os_booking_base_entity_key
, fdi.os_booking_base_entity_code
, fdi.os_booking_base_entity_descr
, fdi.os_initiating_office_key
, fdi.os_initiating_office_code
, fdi.os_initiating_base_entity_key
, fdi.os_initiating_base_entity_code
, fdi.os_initiating_base_entity_descr
, fdi.fac_booking_office_key
, fdi.fac_booking_office_code
, fdi.fac_booking_base_entity_key
, fdi.fac_booking_base_entity_code
, fdi.fac_booking_base_entity_descr
, fdi.fac_initiating_office_key
, fdi.fac_initiating_office_code
, fdi.fac_initiating_base_entity_key
, fdi.fac_initiating_base_entity_code
, fdi.fac_initiating_base_entity_descr
, fdi.customer_type_key
, fdi.customer_type_code
, fdi.customer_type_descr
, fdi.industry_type_key
, fdi.industry_type_code
, fdi.industry_type_nace_2_0
, fdi.nace_highest_level_code
, fdi.residence_country_key
, fdi.residence_country_code
, fdi.residence_country_name
, fdi.regulatory_country_code
, fdi.regulatory_country_key
, fdi.regulatory_country_name
, fdi.basel_official_approach
, fdi.exposure_class_original_sa
, fdi.exposure_class_original_irb
, fdi.exposure_class_sa_not_def
, fdi.exposure_class_sec
, fdi.limit_type_key
, fdi.limit_type_code
, fdi.limit_type_descr
, fdi.product_type_key
, fdi.product_type_code
, fdi.product_type_descr
, fdi.risk_category_level1_code
, fdi.risk_category_level1_key
, fdi.ing_legal_entity_key
, fdi.ing_legal_entity_code
, fdi.ifrs_accounting_classification
, fdi.ifrs_measurement_category
, fdi.on_balance_sheet_ind
, fdi.on_balance_ind
, fdi.committed_indicator
, fdi.poci_type_key
, fdi.poci_type
, fdi.poci_type_descr
, fdi.advised_indicator
, fdi.forbearance_measure_key
, fdi.forbearance_measure_code
, fdi.forbearance_measure_descr
, fdi.forbearance_measure_1_key
, fdi.forbearance_measure_1_code
, fdi.forbearance_measure_1_descr
, fdi.forbearance_measure_2_key
, fdi.forbearance_measure_2_code
, fdi.forbearance_measure_2_descr
, fdi.forbearance_measure_3_key
, fdi.forbearance_measure_3_code
, fdi.forbearance_measure_3_descr
, fdi.forbearance_measure_4_key
, fdi.forbearance_measure_4_code
, fdi.forbearance_measure_4_descr
, fdi.forbearance_measure_5_key
, fdi.forbearance_measure_5_code
, fdi.forbearance_measure_5_descr
, fdi.forbearance_status_key
, fdi.forbearance_status_code
,0                            AS allocated_limit_amt
,0                            AS allocated_outstanding_amt
,0                            AS exposure_original
,0                            AS carrying_amt
,0                            AS gross_carrying_amt
,0                            AS loan_commitments_given_amt
,0                            AS accrued_interest_amt
,0                            AS write_off_amt_partial
,0                            AS write_off_amt_full
, fdi.ifrs_stage_T0
, fdi.days_pastdue_T0
, fdi.days_pastdue_bucket_T0
, fdi.provision_category_T0
,0                            AS alloc_provision_amt_T0
, fdi.on_balance_ratio_EAD_T0
, fdi.on_balance_ratio_CA_T0
, fdi.performing_ind_T0
, fdi.risk_rating_key_T0
, fdi.risk_rating_code_T0
, fdi.risk_rating_level2_key_T0
, fdi.risk_rating_level2_code_T0
, fdi.risk_rating_level2_descr_T0
, fdi.ifrs_stage_T_1
, fdi.days_pastdue_T_1
, fdi.days_pastdue_bucket_T_1
, fdi.provision_category_T_1
,0                            AS alloc_provision_amt_T_1
, fdi.on_balance_ratio_EAD_T_1
, fdi.performing_ind_T_1
, fdi.risk_rating_key_T_1
, fdi.risk_rating_code_T_1
, fdi.risk_rating_level2_key_T_1
, fdi.risk_rating_level2_code_T_1
, fdi.risk_rating_level2_descr_T_1
, fdi.ifrs_stage_PROV
, fdi.days_pastdue_PROV
, fdi.days_pastdue_bucket_PROV
, fdi.provision_category_PROV
,0                            AS alloc_provision_amt_PROV
,0                            AS alloc_provision_amt_PROV_LC
, fdi.on_balance_ratio_PROV
, fdi.performing_ind_PROV
, fdi.risk_rating_level2_code_PROV
, fdi.sme_ind
, fdi.finrep_instrument_type
, fdi.finrep_instrument_type_key
, fdi.finrep_instrument_type_descr
, fdi.finrep_product_type
, fdi.finrep_product_type_key
, fdi.finrep_product_type_descr
, fdi.finrep_purpose
, fdi.finrep_purpose_key
, fdi.finrep_purpose_descr
, fdi.finrep_subordinate
, fdi.finrep_subordinate_key
, fdi.finrep_subordinate_descr
, fdi.finrep_sector
, fdi.finrep_sector_key
, fdi.finrep_sector_descr
, fdi.finrep_scope_indicator
, fdi.ifrs_eligible_indicator
, fdi.derecognition_reason_key
, fdi.derecognition_reason_code
, fdi.derecognition_reason_descr
, fdi.derecognition_date
, fdi.secured_by_com_prop_ind
, fdi.secured_by_res_prop_ind
, fdi.secured_by_non_mort_ind
,0                             AS com_prop_cover_capped_amt
,0                             AS com_prop_cover_capped_amt_LC
,0                             AS res_prop_cover_capped_amt
,0                             AS res_prop_cover_capped_amt_LC
,0                             AS cash_cover_capped_amt
,0                             AS cash_cover_capped_amt_LC
,0                             AS rest_cover_capped_amt
,0                             AS rest_cover_capped_amt_LC
,0                             AS finan_guar_cover_capped_amt
,0                             AS finan_guar_cover_capped_amt_LC
,0                             AS mov_prop_cover_capped_amt
,0                             AS mov_prop_cover_capped_amt_LC
,0                             AS eq_debt_sec_cover_capped_amt
,0                             AS eq_debt_sec_cover_capped_amt_LC
, fdi.intercompany_code
, fdi.customer_base_entity_code
, fdi.ing_group_cons_ind
, fdi.ing_bank_solo_ind
, fdi.ing_belgium_cons_ind
, fdi.ing_belgium_solo_ind
, fdi.ing_slaski_solo_ind
, fdi.ing_direct_australia_solo_ind
, fdi.ing_diba_solo_ind
, fdi.ing_turkey_solo_ind
, fdi.ing_eurasia_solo_ind
, fdi.default_ind_T0
, fdi.impaired_ind_T0
, fdi.forbearance_ind_T0
, fdi.default_ind_T_1
, fdi.impaired_ind_T_1
, fdi.forbearance_ind_T_1
, fdi.default_ind_PROV
, fdi.impaired_ind_PROV
, fdi.forbearance_ind_PROV
, fdi.low_credit_risk_ind
, fdi.product_level2_type_code
, fdi.llp_prov_scope_fin_ac_ind_T0
, fdi.llp_prov_scope_fin_ac_ind_T_1
, fdi.llp_prov_scope_fin_ac_ind_PROV
, fdi.irrevocable_facility_ind
, fdi.stat_instrument_type_key
, fdi.stat_instrument_type_code
, fdi.stat_instrument_type_descr
, fdi.stat_instrument_subtype_key
, fdi.stat_instrument_subtype_code
, fdi.stat_instrument_subtype_descr
, fdi.stat_sector_key
, fdi.stat_sector_code
, fdi.stat_sector_descr
, fdi.npe_matching_step
, fdi.npe_12m_counter
, fdi.npe_12m_ind_T0
, fdi.npe_12m_ind_T_1
, fdi.npe_12m_ind_PROV
, fdi.npe_fb_ind_T0
, fdi.npe_fb_ind_T_1
, fdi.npe_fb_ind_PROV
, fdi.llp_meeting_code_T0
, fdi.llp_meeting_key_T0
, fdi.llp_meeting_descr_T0
, fdi.llp_meeting_code_T_1
, fdi.llp_meeting_key_T_1
, fdi.llp_meeting_descr_T_1
, fdi.llp_meeting_code_PROV
, fdi.llp_meeting_key_PROV
, fdi.llp_meeting_descr_PROV
, fdi.acc_neg_changes_fv_cr_T0
, fdi.acc_neg_changes_fv_cr_T_1
, fdi.acc_neg_changes_fv_cr_PROV
, fdi.ifrs_stage_at_start
, fdi.ifrs_stage_date_at_start
, fdi.ifrs_matching_step
, fdi.origination_date
, fdi.forbearance_start_date
,0 as orig_event_prov_amt
,0 as orig_event_prov_amt_LC
,0 as derec_event_prov_amt
,0 as derec_event_prov_amt_LC
,0 as derec_writeoff_event_prov_amt
,0 as derec_writeoff_event_prov_amt_LC
,0 as forb_event_prov_amt
,0 as forb_event_prov_amt_LC
,0 as reforb_event_prov_amt
,0 as reforb_event_prov_amt_LC
,0 as ifrs9_model_event_prov_amt
,0 as ifrs9_model_event_prov_amt_LC
,0 as basel_model_event_prov_amt
,0 as basel_model_event_prov_amt_LC
, fdi.securitised_ind
, fdi.securitised_factor
, fdi.securitisation_code
, fdi.securitisation_legal_entity_key
, fdi.securitisation_descr
, fdi.retained_position_ind
, 0                        --no inflows for mature NPE
, fdi.gross_carrying_amt   -- mature NPE results in outflow
,0-- fdi.gross_carrying_amt
, fdi.cre_indicator
,0 as gross_carrying_amt_prev_Q4 --ORAMIGCATCHUP4
, fdi.performing_ind_prev_Q4 --ORAMIGCATCHUP4
, 'PREV_DEC_OUTFLOWS' as finrep_record_type
-----Start of vdd_rrd_catchup_124-----------
--, fdi.cre_scope_vre -- rolled back cre changes as part of 3033854
--, fdi.cre_scope_int -- rolled back cre changes as part of 3033854
-----End of vdd_rrd_catchup_124-------
, 0 as cred_deriv_cover_capped_amt --CU6
, 0 as cred_deriv_cover_capped_amt_LC --CU6
,fdi.CREDIT_COMMITMENT_IND --6100295
from vpp_finrep_details_info fdi
where fdi.record_valid_from = v_end_of_last_year-- AND fdi.reporting_period = v_reporting_date_t_1  --ORAMIGCATCHUP4
and fdi.system_id = v_system_id
and fdi.finrep_scope_indicator = 'Y'
and fdi.performing_ind_T0 = 'N'
and fdi.gross_carrying_amt > 0
and ((rtrim(fdi.facility_id)) || fdi.customer_id || rtrim(fdi.local_outstanding_id) )
not in ( select distinct (rtrim(tmp.facility_id) || tmp.customer_id || rtrim(tmp.local_outstanding_id) )
   from tmp_VPP_FINREP_DETAILS_INFO tmp
   where tmp.reporting_period = V_reporting_date and tmp.system_id = V_system_id
   and tmp.finrep_record_type<>'PREV_MTH_MOV_EVENT'  --added for story 4479268
  )
AND (NOT EXISTS( SELECT 1 FROM dwh_facility d WHERE fdi.facility_id = d.facility_id AND d.record_valid_from = V_reporting_date AND d.system_id <> V_system_id)
    OR
    NOT EXISTS(SELECT 1 FROM dwh_outstanding where local_outstanding_id = rtrim(fdi.local_outstanding_id) AND record_valid_from = v_reporting_date)
    )
  AND NOT EXISTS (SELECT 1 FROM vpp_finrep_details_info fdi2                 --ORAMIGCATCHUP4
                WHERE fdi2.reporting_period       > v_end_of_last_year
                AND   fdi2.reporting_period       < v_reporting_date
                AND   fdi2.record_valid_from      = fdi.record_valid_from
                --AND   fdi2.system_id              = fdi.system_id
                AND   fdi2.customer_id            = fdi.customer_id
                AND   fdi2.facility_id            = fdi.facility_id
                AND   fdi2.local_outstanding_id   = fdi.local_outstanding_id
                AND   fdi2.finrep_scope_indicator = 'Y'
                AND   fdi2.performing_ind_T0      = 'N');  --ORAMIGCATCHUP4
commit; --per fix

		MERGE /*+ enable_parallel_dml */ INTO tmp_vpp_finrep_details_info fdi USING ( SELECT /*+ PARALLEL */
        in2.higher_level_code,
        in2.code NACE_LEVEL2_CODE,    --Added as part of STRY3444856
        in3.code NACE_LEVEL3_CODE,    --Added as part of STRY3444856
        in4.code,
        in4.record_valid_from,
        in4.record_valid_until
        FROM industry_nace_rev_2_0 in4
        JOIN industry_nace_rev_2_0 in3
        ON in3.code   = in4.higher_level_code AND in3.record_valid_from <= v_reporting_date AND (
            in3.record_valid_until IS NULL OR in3.record_valid_until > v_reporting_date
        )
        JOIN industry_nace_rev_2_0 in2
        ON in2.code   = in3.higher_level_code AND in2.record_valid_from <= v_reporting_date AND (
            in2.record_valid_until IS NULL OR in2.record_valid_until > v_reporting_date
        ) )
    src ON ( src.code   = fdi.industry_type_nace_2_0 AND src.record_valid_from <= v_reporting_date AND
             ( nvl(src.record_valid_until,utilities.record_default_date) > v_reporting_date )
             AND fdi.reporting_period = v_reporting_date AND   fdi.system_id = v_system_id)
    WHEN MATCHED THEN UPDATE SET --fdi.nace_highest_level_code = src.higher_level_code
                                 fdi.NACE_LEVEL2_CODE = src.NACE_LEVEL2_CODE
                                ,fdi.NACE_LEVEL3_CODE = src.NACE_LEVEL3_CODE;

    v_debug_msg := $$plsql_line || ' of unit ' || $$plsql_unit || '<<dm count>>' || SQL%rowcount;

    utilities.show_debug(v_debug_msg);
    COMMIT;

      -- vpp_finrep_cover_info
    BEGIN
        SELECT
            1
        INTO
            v_temp
        FROM
            dual
        WHERE
            EXISTS (
                SELECT
                    system_id
                FROM
                    vpp_finrep_cover_info
                WHERE
                    reporting_period = v_reporting_date AND   system_id = v_system_id
            );

    EXCEPTION
        WHEN OTHERS THEN
            NULL;
    END;

    IF v_temp = 1 THEN
        BEGIN
            DELETE vpp_finrep_cover_info
            WHERE
                reporting_period = v_reporting_date AND   system_id = v_system_id;

        END;
    END IF;

    BEGIN
      --select * from tmp_VPP_FINREP_DETAILS_INFO --where facility_id = 'FC10019835'  and outstanding_group_id = 2247
        INSERT INTO vpp_finrep_cover_info(
        	-- START: Added for #7941795
        	  reporting_period
        	, system_id
        	, source
        	, facility_key
        	, facility_id
        	, outstanding_group_key
        	, outstanding_group_id
        	, cover_key
        	, cover_id
        	, cover_type_key
        	, cover_type_code
        	, corep_cover_cluster
        	, reg_cover_type_class
        	, reg_cover_type_class_key
        	, finrep_cover_type
        	, finrep_cover_type_key
        	, original_cover_value
        	, capped_cover_ratio
        	, cover_capped_amount
        	, batch_id
        	, update_time
        	, cover_value_after_index_r
        	, local_outstanding_id
        	, os_booking_base_entity_code
        	, os_booking_base_entity_key
        	-- END: Added for #7941795 
        )
        SELECT
            reporting_period,
            system_id,
            source,
            facility_key,
            facility_id,
            outstanding_group_key,
            outstanding_group_id,
            cover_key,
            cover_id,
            cover_type_key,
            cover_type_code,
            corep_cover_cluster,
            reg_cover_type_class,
            reg_cover_type_class_key,
            finrep_cover_type,
            finrep_cover_type_key,
            original_cover_value,
            capped_cover_ratio,
            cover_capped_amount,
            v_batch_id AS batch_id,
            systimestamp AS update_time,
            -- START: Added for #7941795
            cover_value_after_index_r,
            local_outstanding_id,
            os_booking_base_entity_code,
            os_booking_base_entity_key 
            -- END: Added for #7941795
        FROM tmp_finrep_cover_info
        WHERE reporting_period = v_reporting_date 
        AND system_id = v_system_id
        ;

    EXCEPTION
        WHEN OTHERS THEN
            utils.handleerror(
                sqlcode,
                sqlerrm
            );
    END;

    v_debug_msg := $$plsql_line || ' of unit ' || $$plsql_unit || '<<dm count>>' || SQL%rowcount;

    utilities.show_debug(v_debug_msg);
	commit; --per fix

    --  UPDATE FINREP_RECORD_TYPE_KEY FROM SDM
       MERGE /*+ enable_parallel_dml */ INTO tmp_VPP_FINREP_DETAILS_INFO tmp
        USING (SELECT tmp.ROWID row_id, frt.finrep_record_type_key
               FROM tmp_VPP_FINREP_DETAILS_INFO tmp,finrep_record_type frt
               WHERE frt.code = tmp.finrep_record_type
               AND frt.record_valid_from <= v_reporting_date
               AND (nvl(frt.record_valid_until,utilities.record_default_date) > v_reporting_date )) src
        ON ( tmp.ROWID = src.row_id )
        WHEN MATCHED THEN UPDATE SET tmp.finrep_record_type_key = src.finrep_record_type_key;
    commit;
    BEGIN
        vpp_finrep_details_ins(
            v_reporting_date,
            v_system_id,
            v_batch_id,
            v_debug
        );
    EXCEPTION
        WHEN OTHERS THEN
            utilities.show_debug (replace(
                '[%1!] Execution of Stored Procedure vpp_finrep_details_ins failed - error while transfering data to vpp_finrep_details_info table and vpp_finrep_aggr_info ....',
                '%1!',
                systimestamp
            ) );
            utils.handleerror(
                sqlcode,
                sqlerrm
            );
    END;
      -- Cleanup data from temporary tables

    DELETE tmp_finrep_cover_info
    WHERE
        reporting_period = v_reporting_date AND   system_id = v_system_id;
	commit; --per fix

    DELETE tmp_finrep_cover_capped_info
    WHERE
        reporting_period = v_reporting_date AND   system_id = v_system_id;
	commit; --per fix
          DELETE /*+ PARALLEL enable_parallel_dml */ tmp_vpp_finrep_details_info
          Where reporting_period = v_reporting_date AND   system_id = v_system_id;

  SCHEMA_MAINT.gather_idx_stats ('TMP_VPP_FINREP_DETAILS_INFO');
	commit; --per fix

    BEGIN
        vxx_done(
            v_system_id,
            v_reporting_date,
            v_event_processed
        );
    EXCEPTION
        WHEN OTHERS THEN
            utilities.show_debug (replace(
                '[%1!] Execution of Stored Procedure vxx_done failed VDE for finre_export event will not be processed....',
                '%1!',
                systimestamp
            ) );
            utils.handleerror(
                sqlcode,
                sqlerrm
            );
    END;
    COMMIT;
	-- Added for #4335652 start
	BEGIN
		FOR rec IN (
			SELECT DISTINCT
				system_id
			FROM
				v_finrep_details_dbnl_pregl
			WHERE system_id = v_system_id
			) LOOP

			SELECT COUNT(*)
			INTO v_cnt
			FROM
			(
				SELECT DISTINCT
					system_id
				FROM
					v_finrep_details_dbnl_pregl
				WHERE
					reporting_date > v_reporting_date - 60
				MINUS
				SELECT DISTINCT system_id
				FROM
					v_finrep_details_dbnl_pregl
				WHERE reporting_date = v_reporting_date
			);

			IF v_cnt = 0 THEN
				null;
				v_event_processed :='dbnl_pregl_export';
				BEGIN
					vxx_done(
                    NULL,
					v_reporting_date,
					v_event_processed
					);
				EXCEPTION
				WHEN OTHERS THEN
					utilities.show_debug (replace(
					'[%1!] Execution of Stored Procedure vxx_done failed VDE for PREGL finrep_export event will not be processed....','%1!', systimestamp) );
					utils.handleerror(sqlcode,sqlerrm);
				END;

			END IF;
		END LOOP;
	EXCEPTION
		WHEN OTHERS THEN
			utilities.show_debug (replace(
			'[%1!] Execution of Stored Procedure failed... PREGL finrep_export event will not be processed....','%1!', systimestamp) );
			utils.handleerror(sqlcode,sqlerrm);
	END;

	-- Added for #4335652 end
    utilities.show_debug (replace(
        '[%1!] vpp_finrep_details_b4 DONE',
        '%1!',
        systimestamp
    ) );
     v_debug_msg := $$plsql_line || ' of unit ' || $$plsql_unit || '<<END>>' ;

    utilities.show_debug(v_debug_msg);
    EXECUTE IMMEDIATE 'ALTER SESSION DISABLE PARALLEL QUERY'; --added by AB

exception
 WHEN others then
     utils.handleerror(sqlcode,sqlerrm);
END;
/
SHOW ERROR;
GRANT EXECUTE ON vpp_finrep_details_b4 TO vortex_buss_read_grp;	