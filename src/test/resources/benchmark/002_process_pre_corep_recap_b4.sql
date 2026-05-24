create or replace PROCEDURE process_pre_corep_recap_b4(
  v_reporting_date IN DATE,
  v_system_id IN CHAR,
  v_batch_id IN NUMBER DEFAULT NULL ,
  v_debug IN NUMBER DEFAULT 0
) AS


    v_err NUMBER(12);
    v_csv_list CLOB;
    v_sql CLOB;--ORAIQ_P9 varchar(32000) changed with varchar(16384)
    v_offset NUMBER(12);
    v_configuration_code pkg_subtype.general_code;
    v_switch_date DATE;
    v_debug_msg pkg_subtype.debug_msg;
    v_proc_name pkg_subtype.procedure_name := $$plsql_unit;
    v_is_ind_active varchar2(5 CHAR); --new variable to apply switch for STRY3563101
    v_exp_class_sa_switch NUMBER(12); --new variable for STRY3676741
    v_max_key PKG_SUBTYPE.GENERAL_KEY;

BEGIN
    utilities.truncate_table('tmp_corep_vbr_basel4');
    utilities.truncate_table('tmp_corep_recap_b4');
    utilities.truncate_table('tmp_corep_recap_factor_b4');
    utilities.truncate_table('tmp_corep_recap_measure_pre_b4');
    utilities.truncate_table('tmp_corep_recap_measure_b4');

   ----------------------------------------------------------------------------------------------
   -- ReFill DM static data tables
   ----------------------------------------------------------------------------------------------
	insert_dmb_log_corep(v_detail_level    => 103,
							   v_log_descr       => 'process_pre_corep_recap_b4',
							   v_activity_code   => 'fill_dm_facility_tables',
							   v_result_code     => 'START',
							   v_system_id       => v_system_id,v_reporting_date       => v_reporting_date
							  );

			BEGIN
				process_basel4_exp_class_irb_corep();
				EXCEPTION
				WHEN OTHERS THEN utils.handleerror(sqlcode,sqlerrm);
			END;

			BEGIN
				process_basel4_exp_class_sa_corep();
				EXCEPTION
				WHEN OTHERS THEN utils.handleerror(sqlcode,sqlerrm);
			END;

			BEGIN
				process_facility_type_corep();
				EXCEPTION
				WHEN OTHERS THEN utils.handleerror(sqlcode,sqlerrm);
			END;

			BEGIN
				process_facility_purpose_corep();
				EXCEPTION
				WHEN OTHERS THEN utils.handleerror(sqlcode,sqlerrm);
			END;

			BEGIN
				PROCESS_RISK_RATING_COREP();
				EXCEPTION
				WHEN OTHERS THEN utils.handleerror(sqlcode,sqlerrm);
			END;

			BEGIN
				PROCESS_SEC_LEGAL_ENTITY_COREP();
				EXCEPTION
				WHEN OTHERS THEN utils.handleerror(sqlcode,sqlerrm);
			END;

     insert_dmb_log_corep(v_detail_level    => 103,
                                   v_log_descr       => 'process_pre_corep_recap_b4',
                                   v_activity_code   => 'fill_dm_facility_type',
                                   v_result_code     => 'FINOK',
                                   v_system_id       => v_system_id,v_reporting_date       => v_reporting_date
                                  );

    insert_dmb_log_corep(v_detail_level => 103,
                         v_log_descr => 'process_pre_corep_recap_b4',
                         v_activity_code => 'vbr insert',
                         v_result_code => 'START',
                         v_system_id => v_system_id,
                         v_reporting_date => v_reporting_date);

    v_debug_msg := $$plsql_line|| ' of plsql unit '|| $$plsql_unit|| ' '|| systimestamp|| ' Rows Affected:- '|| SQL%rowcount;
    utilities.show_debug(v_debug_msg);

    BEGIN
        SELECT TEXT_VALUE INTO v_is_ind_active FROM functional_parameter WHERE CODE = 'SME_INDICATOR_VPP_LR_SWITCH' AND RECORD_VALID_UNTIL IS NULL;
    EXCEPTION
        WHEN NO_DATA_FOUND THEN v_is_ind_active := NULL;
    END;

    /* Added for STRY3676741 - Update COREP data mart with revised exposure classes on secured and unsecured level */
    BEGIN
        SELECT 1 INTO v_exp_class_sa_switch FROM control_parameter WHERE code = 'EXPOSURE_CLASS_SA_COVER_LEVEL' AND indicator_value = 'Y';
    EXCEPTION
        WHEN no_data_found THEN v_exp_class_sa_switch := 0;
         WHEN OTHERS THEN  RAISE;
    END;
    ----------------------------------------------------------------------------------------------
    -- Retrieve data from basel table
    ----------------------------------------------------------------------------------------------
    BEGIN
        INSERT  /*+ APPEND  */ INTO tmp_corep_vbr_basel4 (
            system_id, --  modification corep_vpp
            reporting_date, --  modification corep_vpp
            basel2_portfolio_code,
            credit_quality_step_original,
            customer_id,
            customer_key,
            effective_maturity,
            exposure_class_original,
            exposure_class_sa_original,
            facility_id,
            facility_key,
            official_approach,
            outstanding_group_id,
            outstanding_group_key,
            outstanding_id,
            outstanding_key,
            rating_original_key,
            supervised_financial_indicator,
            direct_cost_percentage,
            indirect_cost_percentage,
            cure_rate,
            unsecured_recovery,
            unsecured_recovery_discounted,
            discount_factor_unsecured,
            secured_recovery,
            secured_recovery_discounted,
            ccp_counterparty_indicator,
            --large_asset_indicator,
            rating_agency_original_key,
            external_rating_original,
            securitisation_rating_approach,
            allocated_limit_amt,
            allocated_outstanding_amt,
            exposure_class_sa_not_def_sec,
            exposure_class_sa_not_def,
            effective_regulated_indicator,
            netted_indicator,
            calculated_add_on,
            finrep_subordination_code,
            zero_rrw_sov_indicator,
             basel_local_official_approach,
            remaining_maturity_in_months,
            residual_maturity_bucket_code,
            ppu_sa_ind, --CU7
            pd_original_after_multipliers, --CU7
            --macro_prud_rw_ltv,    --New column added AB STRY3055404
            RETAINED_POSITION_IND,
			ead_exclusion_ind,
            res_imm_prop_ind,
            com_imm_prop_ind)  --added as part of 20231130
        (SELECT
            v_system_id system_id 	,
            v_reporting_date reporting_date 	,
            vb.basel2_portfolio_code basel2_portfolio_code	,
            vb.credit_quality_step_original	            credit_quality_step_original	,
            vb.customer_id	            customer_id	,
            vb.customer_key	            customer_key	,
            vb.effective_maturity	            effective_maturity	,
            vb.exposure_class_original	            exposure_class_original	,
            vb.exposure_class_sa_original	            exposure_class_sa_original	,
            vb.facility_id	            facility_id	,
            vb.facility_key	            facility_key	,
            vb.official_approach	            official_approach	,
            vb.outstanding_group_id	            outstanding_group_id	,
            vb.outstanding_group_key	            outstanding_group_key	,
            vb.outstanding_id	            outstanding_id	,
            vb.outstanding_key	            outstanding_key	,
            vb.rating_original_key	            rating_original_key	,
            vb.supervised_financial_indicator	            supervised_financial_indicator	,
            vb.direct_cost_percentage	            direct_cost_percentage	,
            vb.indirect_cost_percentage	            indirect_cost_percentage	,
            vb.cure_rate	            cure_rate	,
            vb.unsecured_recovery	            unsecured_recovery	,
            vb.unsecured_recovery_discounted	            unsecured_recovery_discounted	,
            vb.discount_factor_unsecured	            discount_factor_unsecured	,
            vb.secured_recovery	            secured_recovery	,
            vb.secured_recovery_discounted	            secured_recovery_discounted	,
            vb.ccp_counterparty_indicator	            ccp_counterparty_indicator	,
            --NULL	            --large_asset_indicator	,
            vb.rating_agency_original	            rating_agency_original_key	,
            vb.external_rating_original	            external_rating_original	,
            vb.securitisation_rating_approach	            securitisation_rating_approach	,
            vb.alloc_limit_amount	            allocated_limit_amt	,
            vb.alloc_outstanding_amount	            allocated_outstanding_amt	,
            vb.exposure_class_sa_not_def_sec	            exposure_class_sa_not_def_sec	,
            vb.exposure_class_sa_not_def	            exposure_class_sa_not_def	,
            vb.eff_regulated_indicator_orig	            effective_regulated_indicator	,
            CASE WHEN vb.netted_indicator = 'Y' THEN 1 ELSE 0 END col,	            --netted_indicator	,
            vb.calculated_add_on_amount	            calculated_add_on	,
            vb.finrep_subordination_code	            finrep_subordination_code	,
            CASE WHEN vb.zero_rrw_sov_indicator IS NULL THEN NULL WHEN vb.zero_rrw_sov_indicator = 'Y' THEN 1 ELSE 0 END zero_rrw_sov_indicator ,
            vb.local_official_approach  	            basel_local_official_approach	,
            vb.remaining_maturity_in_months	            remaining_maturity_in_months	,
            mb.ccrm_code	            residual_maturity_bucket_code	,
            case when  vb.ppu_sa_ind = 'Y' THEN 1 ELSE 0 END 	            ppu_sa_ind 	,
            vb.pd_original_after_multipliers 	            pd_original_after_multipliers 	,
            --vb.macro_prud_rw_ltv 	            --macro_prud_rw_ltv    --New column added AB STRY3055404	,
			CASE WHEN vb.exposure_class_original = 'SEC_ORIG' THEN 1 ELSE 0 END  RETAINED_POSITION_IND	,
            vb.ead_exclusion_ind   ead_exclusion_ind,
            CASE WHEN vb.res_imm_prop_ind = 'Y' THEN 1 ELSE 0 END AS res_imm_prop_ind,
            CASE WHEN vb.com_imm_prop_ind = 'Y' THEN 1 ELSE 0 END AS com_imm_prop_ind
        FROM dwh_recapb4_outstanding_group vb,maturity_age_class MB
        WHERE vb.system_id = v_system_id --  modification corep_vpp
        AND vb.record_valid_from = v_reporting_date --  modification corep_vpp
        AND vb.rwa_calculated_indicator = 'Y' -- 4020446 new filter condiition to exclude pipeline deals
        AND (NVL(vb.remaining_maturity_in_months, 0) >= (CASE WHEN MB.low_value = 0 THEN -1 ELSE MB.low_value END)
        AND NVL(vb.remaining_maturity_in_months, 0) < (MB.high_value + 1) ) );
    EXCEPTION
        WHEN OTHERS THEN utils.handleerror(sqlcode,sqlerrm);
    END;

    v_debug_msg := $$plsql_line|| ' of plsql unit '|| $$plsql_unit|| ' '|| systimestamp|| ' Rows Affected:- '|| SQL%rowcount;
    utilities.show_debug(v_debug_msg);
    COMMIT;
    schema_maint.gather_idx_stats('tmp_corep_vbr_basel4');

    insert_dmb_log_corep(v_detail_level => 103,
                                   v_log_descr => 'process_pre_corep_recap_b4',
                                   v_activity_code => 'vbr insert',
                                   v_result_code => 'FINOK',
                                   v_system_id => v_system_id,
                                   v_reporting_date => v_reporting_date);


    insert_dmb_log_corep(v_detail_level => 103,
                                   v_log_descr => 'process_pre_corep_recap_b4',
                                   v_activity_code => 'IRB insert',
                                   v_result_code => 'START',
                                   v_system_id       => v_system_id,
                                   v_reporting_date       => v_reporting_date);

    BEGIN
        INSERT /*+ APPEND */ INTO tmp_corep_recap_b4 (
            record_id,
            exposure_class_applied,
            cover_id,
            capital_requirement,
            expected_loss,
            exposure_at_default,
            loss_given_default,
            outstanding_group_id,
            pd_applied,
            alloc_provision_amt,
            risk_weighted_assets,
            risk_weight_factor,
            rating_applied_key,
            exposure_original,
            exposure_original_drawn,
            exposure_original_undrawn,
            exposure_pre_ccf,
            exposure_pre_ccf_drawn,
            exposure_pre_ccf_undrawn,
            basel_approach,
            original_cover_value,
            g_factor,
            k_factor,
            regulator,
            residual_value_amount,
            residual_value_capital_req,
            residual_value_risk_weight,
            residual_value_risk_weight_asset,
            record_valid_from,
            system_id,
            credit_conversion_factor,
            --risk_weighted_assets_due_dill,
            --risk_weighted_assets_sec_mat_mism,
            --risk_degree_code,
            --credit_quality_step_sec,
            on_balance_ratio,
            --on_balance_ratio_on_balance,
            source_table,
            h_factor,
            --e_factor,
            pro_rata_factor,
            risk_weight_asset_original,
            --cover_market_value,
            risk_weight_asset_pre_sme_fact,
            subject_to_sme_factor_ind,
            --ccf_reduction,
            lr_on_balance_ratio,
            lr_on_balance_ratio_exposure,
            lr_k_factor,
            lr_g_factor,
            lre_amount,
            lre_on_balance,
            lre_off_balance_before_ccf,
            lre_off_balance_after_ccf,
            LR_CCF_10PERCENT,
            LR_CCF_20PERCENT,
            LR_CCF_40PERCENT,
            LR_CCF_50PERCENT,
            LR_CCF_100PERCENT,
            off_supp_credit_indicator,
            --ccf_0percent_irb,
            correlation_factor,
           -- large_asset_indicator,
            risk_weight_add_on_factor,
            risk_weight_add_on_term,
            risk_weight_factor_original,
            --rwa_pre_sme_including_addonterm,
            --rwa_including_addonterm,
            rwa_including_addon,
            rwa_pre_sme_including_addon,
            rwa_add_on_report_classification,
      --      rwa_ex_add_on,             --oramigcontinuouscatchup start
            rwa_pre_sme_fact_ex_add_on,
         --   rw_dod_add_on_f_global_charge,
         --   rwa_add_on_for_dod,
       --     rwa_add_on_for_term_factor  --oramigcontinuouscatchup end
            ------cu6 start
           subject_to_infra_factor_ind
    ,       risk_weight_asset_pre_infra_fact
   -- ,       rwa_pre_infra_fct_ex_add_on
    --,       rwa_pre_infra_fct_ex_strict_prud
    ,       rwa_sme_support_amt
    ,       rwa_infra_support_amt
    ,       lgd_pre_cds
            ------cu6 End
            --MEGERE statement fields
            ,facility_key,
            customer_id,
            outstanding_group_key,
            exposure_class,
            customer_key,
            effective_maturity,
            facility_id,
            outstanding_id,
            outstanding_key,
            rating_key,
            credit_quality_step,
            basel2_portfolio_code,
            basel2_official_approach,
            ccp_counterparty_indicator,
            rating_agency_original_key,
            external_rating_original,
            sec_rating_approach,
            allocated_limit_amt,
            allocated_outstanding_amt,
            exposure_class_sa_not_def_sec,
            exposure_class_sa_not_def,
            effective_regulated_indicator,
            netted_indicator,
            calculated_add_on,
            finrep_subordination_code,
            zero_rrw_sov_indicator,
            basel_local_official_approach,
            remaining_maturity_in_months,
            residual_maturity_bucket_code,
            ----cu6 start
            ppu_sa_ind,
            pd_original_after_multipliers,
            ----cu6 end
            direct_cost,
            indirect_cost,
            cure_rate,
            unsecured_recovery_amounts,
            unsecured_recovery_amounts_discounted,
            unsecured_discount_factor,
            secured_recovery_amounts,
            secured_recovery_amounts_discounted,
            sec_category,
            securitised_factor,
            official_approach_indicator,
            increase_correlation_ind,
            sme_ind,
            risk_weight_factor_macro_prud,--New column added AB 5033337
            rwa_pre_sme_fact_macro_prud,--New column added AB 5033337
            rwa_pre_infra_fact_macro_prud,--New column added AB 5033337
            rwa_macro_prud,--New column added AB 5033337
            macro_prud_rw_ltv,  -- New column added AB STRY3055404
            leverage_sme_ind, -- New Column added for STRY3563101 SD
			reporting_date, --  modification corep_vpp
			retained_position_ind,
            risk_weight_asset_orig_obligor, --added as part of STRY2099796
            lgd_model_code, --added as part of 2119302
            substitution_method, --added as part of 2119302
            rw_substitution_method, --added as part of 2119302
            rw_floor, --added as part of 2119302
            official_approach_applied, --added as part of 2119302
            risk_weight_substitution, --added as part of 2119302
            CREDIT_QUALITY_STEP_SA_APPLIED,
            ead_exclusion_ind,
            exposure_class_sa_in_irb,
            res_imm_prop_ind,
            com_imm_prop_ind,
            regulatory_large_corp_ind,
			ccf_100percent ,
			guar_ppu_sa_ind,
            ccf_0percent,
            ccf_10percent,
            ccf_20percent,
            ccf_40percent,
            ccf_50percent,
            ccf_100percent_irb,
            regulatory_ead_applied,
            rating_guarantor,
            exposure_class_sa_original,
			risk_weight_asset_pre_fx_mm,
            on_balance_ratio_exp_pre_ccf, -- added to fix exposure_pre_ccf/original_cover_value validation issue
			securitisation_code,  ----added new for 7324855
		    unsecuritised_factor, --added new for 7324855
			sec_pro_rata_factor,
			ccf_modelled_amount
			        )
			SELECT
				ROWNUM	            record_id,
                CASE when vbia.official_approach_applied = 'SA' then vbia.exposure_class_sa_applied	else vbia.exposure_class_applied end exposure_class_applied,
				vbia.cover_id	            cover_id,
				vbia.capital_requirement	            capital_requirement,
				vbia.expected_loss	            expected_loss,
				vbia.exposure_at_default	            exposure_at_default,
				vbia.loss_given_default	            loss_given_default,
				vbia.outstanding_group_id	            outstanding_group_id,
				vbia.pd_applied	            pd_applied,
				vbia.alloc_provision_amount	            alloc_provision_amt,
				vbia.risk_weight_asset 	            risk_weighted_assets,
				vbia.risk_weight_factor	            risk_weight_factor,
				vbia.rating_applied_key	            rating_applied_key,
				vbia.exposure_original	            exposure_original,
				vbia.exposure_original_drawn	            exposure_original_drawn,
				CASE WHEN vbia.exposure_original - vbia.exposure_original_drawn < 0 THEN 0 ELSE vbia.exposure_original - vbia.exposure_original_drawn END	            exposure_original_undrawn,
				vbia.exposure_pre_ccf	            exposure_pre_ccf,
				vbia.exposure_pre_ccf_drawn	            exposure_pre_ccf_drawn,
				CASE WHEN vbia.exposure_pre_ccf - vbia.exposure_pre_ccf_drawn < 0 THEN 0 ELSE vbia.exposure_pre_ccf - vbia.exposure_pre_ccf_drawn END	            exposure_pre_ccf_undrawn,
				vbia.basel_approach	            basel_approach,
				vbia.original_cover_value	            original_cover_value,
				vbia.g_factor	            g_factor,
				vbia.k_factor	            k_factor,
				vbia.regulator	            regulator,
				vbia.residual_value_amount	            residual_value_amount,
				vbia.residual_value_capital_req	            residual_value_capital_req,
				vbia.residual_value_risk_weight	            residual_value_risk_weight,
				vbia.residual_value_risk_weight_asset	            residual_value_risk_weight_asset,
				vbia.record_valid_from	            record_valid_from,
				vbia.system_id	            system_id,
				vbia.credit_conversion_factor	            credit_conversion_factor,
				vbia.on_balance_ratio	            on_balance_ratio,
				--CASE WHEN vbia.on_balance_ratio = 0 THEN 0 ELSE 1 END 	            on_balance_ratio_on_balance,
				'IRB'	            source_table,
				vbia.h_factor	            h_factor,
				--vbia.e_factor	            e_factor,
				vbia.pro_rata_factor	            pro_rata_factor,
				vbia.risk_weight_asset_original	            risk_weight_asset_original,
				--NULL	            cover_market_value,
				vbia.risk_weight_asset_pre_sme_fact             risk_weight_asset_pre_sme_fact,
				CASE WHEN vbia.subject_to_sme_factor_ind = 'Y' THEN 1 ELSE 0 END 	            subject_to_sme_factor_ind,
				--vbia.ccf_reduction	            ccf_reduction,
				vbia.lr_on_balance_ratio	            lr_on_balance_ratio,
				vbia.lr_on_balance_ratio_exposure	            lr_on_balance_ratio_exposure,
				vbia.lr_k_factor	            lr_k_factor,
				vbia.lr_g_factor	            lr_g_factor,
				vbia.lre_amount	            lre_amount,
				vbia.lre_on_balance	            lre_on_balance,
				vbia.lre_off_balance_before_ccf	            lre_off_balance_before_ccf,
				vbia.lre_off_balance_after_ccf	            lre_off_balance_after_ccf,
				vbia.LR_CCF_10PERCENT	            LR_CCF_10PERCENT,
				vbia.LR_CCF_20PERCENT	            LR_CCF_20PERCENT,
                vbia.LR_CCF_40PERCENT	            LR_CCF_40PERCENT,
				vbia.LR_CCF_50PERCENT	            LR_CCF_50PERCENT,
				vbia.LR_CCF_100PERCENT	            LR_CCF_100PERCENT,
				CASE WHEN vbia.off_supp_credit_indicator = 'Y' THEN 1 ELSE 0 END 	            off_supp_credit_indicator,
				vbia.correlation	            correlation_factor,
				--vbia.large_asset_indicator	            large_asset_indicator,
				vbia.risk_weight_add_on_factor	            risk_weight_add_on_factor,
				vbia.risk_weight_add_on_term	            risk_weight_add_on_term,
				vbia.risk_weight_factor_original	            risk_weight_factor_original,
				--vbia.risk_weight_asset_pre_sme_fact	            rwa_pre_sme_including_addonterm,
				--vbia.risk_weight_asset	            rwa_including_addonterm,
				vbia.risk_weight_asset	            rwa_including_addon,
				vbia.risk_weight_asset_pre_sme_fact	            rwa_pre_sme_including_addon,
				vbia.rw_add_on_report_classification	            rwa_add_on_report_classification,
				vbia.rwa_pre_sme_fact_ex_add_on	            rwa_pre_sme_fact_ex_add_on,
				--vbia.rw_dod_add_on_f_global_charge	            rw_dod_add_on_f_global_charge,
				--vbia.risk_weight_asset - vbia.rwa_ex_dod_add_on	            rwa_add_on_for_dod,
				  case when vbia.subject_to_infra_factor_ind = 'Y' THEN 1 ELSE 0 END	           subject_to_infra_factor_ind,
				vbia.risk_weight_asset_pre_infra_fact 	           risk_weight_asset_pre_infra_fact,
				--vbia.rwa_pre_infra_fct_ex_add_on	           rwa_pre_infra_fct_ex_add_on,
				--NULL	           rwa_pre_infra_fct_ex_strict_prud,
				vbia.risk_weight_asset_pre_infra_fact  -  vbia.risk_weight_asset_pre_sme_fact	           rwa_sme_support_amt,
                (vbia.risk_weight_asset  - vbia.risk_weight_asset_pre_infra_fact)  rwa_infra_support_amt,
				vbia.lgd_pre_cds	           lgd_pre_cds,
				vb.facility_key	            facility_key,
				vb.customer_id	            customer_id,
				vb.outstanding_group_key	            outstanding_group_key,
				vb.exposure_class_original	            exposure_class,
				vb.customer_key	            customer_key,
				vb.effective_maturity	            effective_maturity,
				vb.facility_id	            facility_id,
				vb.outstanding_id	            outstanding_id,
				vb.outstanding_key	            outstanding_key,
				vb.rating_original_key	            rating_key,
				vb.credit_quality_step_original	            credit_quality_step,
				vb.basel2_portfolio_code	            basel2_portfolio_code,
				vb.official_approach	            basel2_official_approach,
				vb.ccp_counterparty_indicator	            ccp_counterparty_indicator,
				vb.rating_agency_original_key	            rating_agency_original_key,
				vb.external_rating_original	            external_rating_original,
				vb.securitisation_rating_approach	            sec_rating_approach,
				vbia.ALLOC_LIMIT_AMOUNT	            allocated_limit_amt,                    --SS Changed for IRB as part of 7801523
				vbia.alloc_outstanding_amount	            allocated_outstanding_amt,      --SS Changed for IRB as part of 7801523
				vb.exposure_class_sa_not_def_sec	            exposure_class_sa_not_def_sec,
				vb.exposure_class_sa_not_def	            exposure_class_sa_not_def,
				vb.effective_regulated_indicator	            effective_regulated_indicator,
				vb.netted_indicator	            netted_indicator,
				round(vbia.pro_rata_factor * vb.calculated_add_on,2)	            calculated_add_on,
				vb.finrep_subordination_code	            finrep_subordination_code,
				vb.zero_rrw_sov_indicator	            zero_rrw_sov_indicator,
				vb.basel_local_official_approach	            basel_local_official_approach,
				vb.remaining_maturity_in_months	            remaining_maturity_in_months,
				vb.residual_maturity_bucket_code	            residual_maturity_bucket_code,
				vb.ppu_sa_ind	            ppu_sa_ind,
				vb.pd_original_after_multipliers	            pd_original_after_multipliers,
				round(vbia.exposure_at_default * vb.direct_cost_percentage,2)	            direct_cost,
				round(vbia.exposure_at_default * vb.indirect_cost_percentage,2)	            indirect_cost,
				vb.cure_rate	            cure_rate,
				round(vbia.exposure_at_default * vb.unsecured_recovery,2)	            unsecured_recovery_amounts,
				round(vbia.exposure_at_default * vb.unsecured_recovery_discounted,2)	            unsecured_recovery_amounts_discounted,
				vb.discount_factor_unsecured	            unsecured_discount_factor,
				round(vbia.exposure_at_default * vb.secured_recovery,2)	            secured_recovery_amounts,
				round(vbia.exposure_at_default * vb.secured_recovery_discounted,2)	            secured_recovery_amounts_discounted,
				CASE WHEN vb.exposure_class_original = 'SEC'      THEN 'I' WHEN vb.exposure_class_original = 'SEC_SPON' THEN 'S' WHEN vb.exposure_class_original = 'SEC_ORIG' THEN 'O' END	            sec_category,
				dsf.securitised_factor * dsf.sec_pro_rata_factor      securitised_factor, -- changed logic
				CASE WHEN (vb.official_approach = vbia.basel_approach ) THEN 1 ELSE 0 END	            official_approach_indicator,
				vbia.increased_correlation_ind	            increase_correlation_ind,
				CASE WHEN vbia.internal_sme_ind = 'Y' THEN 1 ELSE 0 END	            sme_ind,
                vbia.risk_weight_factor_macro,--New column added AB 5033337
                vbia.rwa_pre_sme_fact_macro_prud,--New column added AB 5033337
                vbia.rwa_pre_infra_fact_macro_prud,--New column added AB 5033337
                vbia.rwa_macro_prud,--New column added AB 5033337
				vb.macro_prud_rw_ltv  	            macro_prud_rw_ltv,
				CASE WHEN v_is_ind_active = 'Y' THEN CASE WHEN vbia.leverage_sme_ind = 'Y' THEN 1 ELSE 0 END ELSE NULL END	            leverage_sme_ind,
				v_reporting_date	            reporting_date,
				vb.RETAINED_POSITION_IND	            retained_position_ind,
				NULL 	            risk_weight_asset_orig_obligor,
				vbia.lgd_model_applied	            lgd_model_code,
				vbia.substitution_method	            substitution_method,
				vbia.rw_substitution_method 	            rw_substitution_method,
				vbia.rw_floor 	            rw_floor,
				vbia.official_approach_applied 	            official_approach_applied,
				CASE WHEN vbia.riskweight_substitution = 'Y' THEN 1 WHEN vbia.riskweight_substitution = 'N' THEN 0 END 	            risk_weight_substitution,
				vbia.CREDIT_QUALITY_STEP_SA_APPLIED	            CREDIT_QUALITY_STEP_SA_APPLIED,
                vb.ead_exclusion_ind,
                vbia.exposure_class_sa_applied exposure_class_sa_in_irb,
                vb.res_imm_prop_ind,
                vb.com_imm_prop_ind,
                CASE WHEN vbia.regulatory_large_corp_ind = 'Y' THEN 1 ELSE 0 END AS regulatory_large_corp_ind,
				CASE WHEN vbia.riskweight_substitution = 'Y' THEN vbia.sa_ccf_100percent END ccf_100percent,
				 vbia.guar_ppu_sa_ind,
                vbia.ccf_0percent,
                vbia.ccf_10percent,
                vbia.ccf_20percent,
                vbia.ccf_40percent,
                vbia.ccf_50percent,
                vbia.ccf_100percent,
                CASE WHEN vbia.regulatory_ead_applied = 'Y' THEN 1 WHEN vbia.regulatory_ead_applied = 'N' THEN 0 END regulatory_ead_applied,
                vbia.rating_guarantor	            rating_guarantor,
                vb.exposure_class_sa_original,
                CASE WHEN vbia.riskweight_substitution = 'Y' and vbia.official_approach_applied = 'SA' THEN vbia.risk_weight_asset_pre_sme_fact END risk_weight_asset_pre_fx_mm,
                vbia.on_balance_ratio_exp_pre_ccf, -- added to fix exposure_pre_ccf/original_cover_value validation issue
				dsf.securitisation_code,  ----added new for 7324855
				(1- dsf.securitised_factor) * dsf.sec_pro_rata_factor unsecuritised_factor,  --added new for 7324855
				dsf.sec_pro_rata_factor,
				vbia.ccf_modelled_amount
              FROM dwh_recapb4_osg_cover_irb vbia,tmp_corep_vbr_basel4 vb, dmb_securitised_rwa dsf -- added join for multiple securitised_factors
              WHERE vbia.record_valid_from = v_reporting_date
			  AND vbia.system_id = v_system_id
			  AND vbia.basel_approach IN ( 'AIRB','AIRB_OFFIC','FIRB' )
              AND vbia.outstanding_group_id = vb.outstanding_group_id(+)
              AND vb.outstanding_group_id = dsf.outstanding_group_id(+)
              AND nvl(vbia.cover_id,' ')= nvl(dsf.cover_id(+),' ')
              AND vbia.basel_approach=dsf.basel_approach(+)
			 -- AND vbia.facility_id = dsf.facility_id(+)
			  AND dsf.system_id(+) = v_system_id  --make sure the join on dwh_securitised_facility remains left join.
			  AND dsf.record_valid_from(+) <= V_REPORTING_DATE --securitised_factor
			  AND (dsf.record_valid_until(+) > v_reporting_date or dsf.record_valid_until(+) is null)

                            ;




    EXCEPTION
        WHEN OTHERS THEN utils.handleerror(sqlcode,sqlerrm);
    END;

    v_offset := SQL%rowcount;
    v_debug_msg := $$plsql_line|| ' of plsql unit '|| $$plsql_unit|| ' '|| systimestamp|| ' Rows Affected:- '|| SQL%rowcount;
    utilities.show_debug(v_debug_msg);
    COMMIT;

    insert_dmb_log_corep(v_detail_level => 103,
                                   v_log_descr => 'process_pre_corep_recap_b4',
                                   v_activity_code => 'IRB insert',
                                   v_result_code => 'FINOK',
                                   v_system_id       => v_system_id,v_reporting_date       => v_reporting_date);

    insert_dmb_log_corep(v_detail_level => 103,
                                   v_log_descr => 'process_pre_corep_recap_b4',
                                   v_activity_code => 'SA insert',
                                   v_result_code => 'START',
                                   v_system_id       => v_system_id,v_reporting_date       => v_reporting_date);

    BEGIN
        INSERT /*+ APPEND */ INTO tmp_corep_recap_b4 (
            record_id,
            exposure_class_applied,
            cover_id,
            capital_requirement,
            exposure_at_default,
            --off_balance_after_ccf,
            outstanding_group_id,
            record_valid_from,
            risk_weighted_assets,
            risk_weight_factor,
            risk_weight_factor_original,
            exposure_original,
            exposure_original_drawn,
            exposure_original_undrawn,
            exposure_pre_ccf,
            exposure_pre_ccf_drawn,
            exposure_pre_ccf_undrawn,
            basel_approach,
            original_cover_value,
            system_id,
            g_factor,
            k_factor,
            regulator,
            credit_quality_step_applied,
            --credit_quality_step_sec,
            alloc_provision_amt,
            risk_weight_substitution,
            on_balance_ratio,
            on_balance_ratio_exposure,
            on_balance_ratio_collateral_sa,
            --on_balance_ratio_on_balance,
            fully_adjusted_exposure_on_sa,
            fully_adjusted_exposure_off_sa,
            financial_collateral_sa,
            exposure_net_provision_sa,
            credit_conversion_factor,
            volatility_maturity_adj,
            ccf_0percent,
            ccf_20percent,
            ccf_50percent,
            ccf_100percent,
            --risk_weighted_assets_due_dill,
            --risk_weighted_assets_sec_mat_mism,
            --risk_degree_code,
            residual_value_amount,
            residual_value_capital_req,
            residual_value_risk_weight,
            residual_value_risk_weight_asset,
            source_table,
            h_factor,
            pro_rata_factor,
            risk_weight_asset_original,
            rating_agency_applied_key,
            --external_rating_applied,
            on_balance_ratio_fin_coll,
            --cover_market_value,
            risk_weight_asset_pre_sme_fact,
            subject_to_sme_factor_ind,
            lr_on_balance_ratio,
            lr_on_balance_ratio_exposure,
            lr_k_factor,
            lr_g_factor,
            lre_amount,
            lre_on_balance,
            lre_off_balance_before_ccf,
            lre_off_balance_after_ccf,
            LR_CCF_10PERCENT,
            LR_CCF_20PERCENT,
            LR_CCF_40PERCENT,
            LR_CCF_50PERCENT,
            LR_CCF_100PERCENT,
            off_supp_credit_indicator,
            risk_weight_add_on_factor,
            risk_weight_add_on_term,
            --rwa_pre_sme_including_addonterm,
            --rwa_including_addonterm,
            rwa_including_addon,
            rwa_pre_sme_including_addon,
            rwa_add_on_report_classification,
            strict_prudential_rw_ind,
            rwa_ex_add_on,
            rwa_pre_sme_fact_ex_add_on
           --,rwa_add_on_for_term_factor
             ,       risk_weight_excl_strict_prud
             ,       rwa_pre_sme_fact_ex_strict_prud
             ,       rwa_ex_strict_prud
             ,       subject_to_infra_factor_ind
             ,       risk_weight_asset_pre_infra_fact
            -- ,       rwa_pre_infra_fct_ex_add_on
             ,       rwa_pre_infra_fct_ex_strict_prud
             ,       rwa_sme_support_amt
             ,       rwa_infra_support_amt  ,

            --MEGERE statement fields
            customer_id,
            outstanding_group_key,
            exposure_class,
            customer_key,
            effective_maturity,
            facility_id,
            facility_key,
            outstanding_id,
            outstanding_key,
            rating_key,
            credit_quality_step,
            basel2_portfolio_code,
            basel2_official_approach,
            ccp_counterparty_indicator,
            rating_agency_original_key,
            external_rating_original,
            sec_rating_approach,
            allocated_limit_amt,
            allocated_outstanding_amt,
            exposure_class_sa_not_def_sec,
            exposure_class_sa_not_def,
            effective_regulated_indicator,
            netted_indicator,
            calculated_add_on,
            finrep_subordination_code,
            zero_rrw_sov_indicator,
            basel_local_official_approach,
            remaining_maturity_in_months,
            residual_maturity_bucket_code,
            ppu_sa_ind,    -------cu6
            pd_original_after_multipliers,
            sec_category,
            securitised_factor,
            official_approach_indicator,
            cqs_cen_gov_ind,
            sme_ind,
            leverage_sme_ind, -- New Column added for STRY3563101 SD
			reporting_date, --  modification corep_vpp
			RETAINED_POSITION_IND,
            risk_weight_asset_orig_obligor,
            external_rating_applied,
            ead_exclusion_ind,
            condition_outcome_code,
            ccf_10percent ,
            ccf_40percent,
            COVER_SPLIT_KEY,
            property_ratio_from,
            property_ratio_until,
            --EAD_RATIO,
            --COLLATERALISATION_RATIO,
            exposure_class_irb_in_sa,
            ccf_ucc_transitional ,
            rwa_non_ccf_ucc_trans,
            SPLIT_RATIO,
            ucc_non_trans_on_balance_ratio_exposure,
            exposure_class_sa_original,
			risk_weight_asset_pre_fx_mm,
			risk_weight_factor_pre_fx_mm,
			loan_split_derogation_ind,
            risk_weight_art378,
			exposure_amount_art378,
			rwa_art378,
			book_risk_category,
			settlement_date,
			days_unsettled_after_due_date,
			settlement_amount,
			securitisation_code,  ----added new for 7324855
		    unsecuritised_factor, --added new for 7324855
			sec_pro_rata_factor
        )
            (  SELECT
                v_offset + ROWNUM	            record_id,
                CASE WHEN split_sa.cover_id IS NOT NULL THEN split_sa.exposure_class_sa_applied ELSE vbia.exposure_class_sa_applied END   exposure_class_applied,
                CASE WHEN split_sa.cover_id IS NOT NULL THEN split_sa.cover_id ELSE vbia.cover_id END cover_id,
                CASE WHEN split_sa.cover_id IS NOT NULL THEN split_sa.capital_requirement ELSE vbia.capital_requirement END capital_requirement,
                CASE WHEN split_sa.cover_id IS NOT NULL THEN split_sa.exposure_amount_sa ELSE vbia.exposure_amount_sa END  exposure_at_default,
                --vbia.off_balance_after_ccf	            off_balance_after_ccf,
                CASE WHEN split_sa.cover_id IS NOT NULL THEN split_sa.outstanding_group_id ELSE vbia.outstanding_group_id END outstanding_group_id,
                CASE WHEN split_sa.cover_id IS NOT NULL THEN split_sa.record_valid_from ELSE vbia.record_valid_from END	 record_valid_from,
                CASE WHEN split_sa.cover_id IS NOT NULL THEN split_sa.risk_weight_asset ELSE vbia.risk_weight_asset END  risk_weighted_assets,
                CASE WHEN split_sa.cover_id IS NOT NULL THEN split_sa.risk_weight_factor ELSE vbia.risk_weight_factor END  risk_weight_factor,
                CASE WHEN split_sa.cover_id IS NOT NULL THEN split_sa.risk_weight_factor_original ELSE vbia.risk_weight_factor_original	END  risk_weight_factor_original,
                CASE WHEN split_sa.cover_id IS NOT NULL THEN split_sa.exposure_original ELSE vbia.exposure_original	END  exposure_original,
                CASE WHEN split_sa.cover_id IS NOT NULL THEN split_sa.exposure_original_drawn ELSE vbia.exposure_original_drawn END  exposure_original_drawn,
                CASE WHEN ((CASE WHEN split_sa.cover_id IS NOT NULL THEN split_sa.exposure_original ELSE vbia.exposure_original	END) - (CASE WHEN split_sa.cover_id IS NOT NULL THEN split_sa.exposure_original_drawn ELSE vbia.exposure_original_drawn END)) < 0 THEN 0
                     ELSE ((CASE WHEN split_sa.cover_id IS NOT NULL THEN split_sa.exposure_original ELSE vbia.exposure_original	END) - (CASE WHEN split_sa.cover_id IS NOT NULL THEN split_sa.exposure_original_drawn ELSE vbia.exposure_original_drawn END))
                END exposure_original_undrawn,
                CASE WHEN split_sa.cover_id IS NOT NULL THEN split_sa.exposure_pre_ccf ELSE vbia.exposure_pre_ccf END  exposure_pre_ccf,
                CASE WHEN split_sa.cover_id IS NOT NULL THEN split_sa.exposure_pre_ccf_drawn ELSE vbia.exposure_pre_ccf_drawn END   exposure_pre_ccf_drawn,
                CASE WHEN ((CASE WHEN split_sa.cover_id IS NOT NULL THEN split_sa.exposure_pre_ccf ELSE vbia.exposure_pre_ccf END) - (CASE WHEN split_sa.cover_id IS NOT NULL THEN split_sa.exposure_pre_ccf_drawn ELSE vbia.exposure_pre_ccf_drawn END)) < 0 THEN 0
                     ELSE ((CASE WHEN split_sa.cover_id IS NOT NULL THEN split_sa.exposure_pre_ccf ELSE vbia.exposure_pre_ccf END) - (CASE WHEN split_sa.cover_id IS NOT NULL THEN split_sa.exposure_pre_ccf_drawn ELSE vbia.exposure_pre_ccf_drawn END)) END exposure_pre_ccf_undrawn,
                CASE WHEN split_sa.cover_id IS NOT NULL THEN split_sa.basel_approach ELSE vbia.basel_approach END  basel_approach,
                CASE WHEN split_sa.cover_id IS NOT NULL THEN split_sa.original_cover_value ELSE vbia.original_cover_value END  original_cover_value,
                vbia.system_id	system_id,
                vbia.g_factor g_factor,
                vbia.k_factor k_factor,
                CASE WHEN split_sa.cover_id IS NOT NULL THEN split_sa.regulator ELSE vbia.regulator END  regulator,
                vbia.credit_quality_step_applied  credit_quality_step_applied,
                --vbia.credit_quality_step_sec	            credit_quality_step_sec,
                CASE WHEN split_sa.cover_id IS NOT NULL THEN split_sa.alloc_provision_amount ELSE vbia.alloc_provision_amount END alloc_provision_amt,
                CASE WHEN vbia.riskweight_substitution = 'Y' THEN 1 WHEN vbia.riskweight_substitution = 'N' THEN 0 END         risk_weight_substitution,
                vbia.on_balance_ratio	            on_balance_ratio,
                --CASE WHEN split_sa.cover_id IS NOT NULL THEN split_sa.on_balance_ratio_exposure ELSE vbia.on_balance_ratio_exposure	END  on_balance_ratio_exposure,
                vbia.on_balance_ratio_exposure	on_balance_ratio_exposure,
                vbia.on_balance_ratio_collateral	            on_balance_ratio_collateral_sa,
                --CASE WHEN vbia.on_balance_ratio = 0 THEN 0 ELSE 1 END 	            on_balance_ratio_on_balance,
                CASE WHEN split_sa.cover_id IS NOT NULL THEN split_sa.fully_adjusted_exposure_on ELSE vbia.fully_adjusted_exposure_on END  fully_adjusted_exposure_on_sa,
                CASE WHEN split_sa.cover_id IS NOT NULL THEN split_sa.fully_adjusted_exposure_off ELSE vbia.fully_adjusted_exposure_off END fully_adjusted_exposure_off_sa,
                CASE WHEN split_sa.cover_id IS NOT NULL THEN split_sa.financial_collateral ELSE vbia.financial_collateral END   financial_collateral_sa,
                CASE WHEN split_sa.cover_id IS NOT NULL THEN split_sa.exposure_net_provision ELSE vbia.exposure_net_provision END  exposure_net_provision_sa,
                vbia.credit_conversion_factor	            credit_conversion_factor,
                CASE WHEN split_sa.cover_id IS NOT NULL THEN split_sa.volatility_maturity_adj ELSE vbia.volatility_maturity_adj	END volatility_maturity_adj,
                CASE WHEN split_sa.cover_id IS NOT NULL THEN split_sa.ccf_0percent ELSE vbia.ccf_0percent END ccf_0percent,
                CASE WHEN split_sa.cover_id IS NOT NULL THEN split_sa.ccf_20percent ELSE vbia.ccf_20percent	END ccf_20percent,
                CASE WHEN split_sa.cover_id IS NOT NULL THEN split_sa.ccf_50percent ELSE vbia.ccf_50percent	 END ccf_50percent,
                CASE WHEN split_sa.cover_id IS NOT NULL THEN split_sa.ccf_100percent ELSE vbia.ccf_100percent	END ccf_100percent,
                CASE WHEN split_sa.cover_id IS NOT NULL THEN split_sa.residual_value_amount ELSE vbia.residual_value_amount	END  residual_value_amount,
                CASE WHEN split_sa.cover_id IS NOT NULL THEN split_sa.residual_value_capital_req ELSE vbia.residual_value_capital_req END residual_value_capital_req,
                CASE WHEN split_sa.cover_id IS NOT NULL THEN split_sa.residual_value_risk_weight ELSE vbia.residual_value_risk_weight END  residual_value_risk_weight,
                vbia.residual_value_risk_weight_asset residual_value_risk_weight_asset,
                'SA'	            source_table,
                vbia.h_factor	            h_factor,
                vbia.pro_rata_factor	            pro_rata_factor,
                CASE WHEN split_sa.cover_id IS NOT NULL THEN split_sa.risk_weight_asset_original ELSE vbia.risk_weight_asset_original END  risk_weight_asset_original,
                vbia.rating_agency_applied	            rating_agency_applied_key,
                --vbia.external_rating_applied	            external_rating_applied,
                vbia.on_balance_ratio_fin_coll	            on_balance_ratio_fin_coll,
                --NULL	            cover_market_value,
                CASE WHEN split_sa.cover_id IS NOT NULL THEN split_sa.risk_weight_asset_pre_sme_fact ELSE vbia.risk_weight_asset_pre_sme_fact END  risk_weight_asset_pre_sme_fact,
                CASE WHEN vbia.subject_to_sme_factor_ind = 'Y' THEN 1 ELSE 0 END 	            subject_to_sme_factor_ind,
                vbia.lr_on_balance_ratio	            lr_on_balance_ratio,
                vbia.lr_on_balance_ratio_exposure	            lr_on_balance_ratio_exposure,
                vbia.lr_k_factor	            lr_k_factor,
                vbia.lr_g_factor	            lr_g_factor,
                CASE WHEN split_sa.cover_id IS NOT NULL THEN split_sa.lre_amount ELSE vbia.lre_amount END  lre_amount,
                CASE WHEN split_sa.cover_id IS NOT NULL THEN split_sa.lre_on_balance ELSE  vbia.lre_on_balance	END  lre_on_balance,
                CASE WHEN split_sa.cover_id IS NOT NULL THEN split_sa.lre_off_balance_before_ccf ELSE vbia.lre_off_balance_before_ccf	END lre_off_balance_before_ccf,
                CASE WHEN split_sa.cover_id IS NOT NULL THEN split_sa.lre_off_balance_after_ccf ELSE vbia.lre_off_balance_after_ccf	END lre_off_balance_after_ccf,
                CASE WHEN split_sa.cover_id IS NOT NULL THEN split_sa.LR_CCF_10PERCENT ELSE vbia.LR_CCF_10PERCENT END  LR_CCF_10PERCENT,
                CASE WHEN split_sa.cover_id IS NOT NULL THEN split_sa.LR_CCF_20PERCENT ELSE vbia.LR_CCF_20PERCENT END LR_CCF_20PERCENT,
                CASE WHEN split_sa.cover_id IS NOT NULL THEN split_sa.LR_CCF_40PERCENT ELSE vbia.LR_CCF_40PERCENT END  LR_CCF_40PERCENT,
                CASE WHEN split_sa.cover_id IS NOT NULL THEN split_sa.LR_CCF_50PERCENT ELSE vbia.LR_CCF_50PERCENT END  LR_CCF_50PERCENT,
                CASE WHEN split_sa.cover_id IS NOT NULL THEN split_sa.LR_CCF_100PERCENT ELSE vbia.LR_CCF_100PERCENT	END LR_CCF_100PERCENT,
                CASE WHEN vbia.off_supp_credit_indicator = 'Y' THEN 1 ELSE 0 END off_supp_credit_indicator,
                vbia.risk_weight_add_on_factor	risk_weight_add_on_factor,
                vbia.risk_weight_add_on_term risk_weight_add_on_term,
                --vbia.risk_weight_asset_pre_sme_fact	            rwa_pre_sme_including_addonterm,
                --vbia.risk_weight_asset	            rwa_including_addonterm,
                CASE WHEN split_sa.cover_id IS NOT NULL THEN split_sa.risk_weight_asset ELSE vbia.risk_weight_asset END rwa_including_addon,
                CASE WHEN split_sa.cover_id IS NOT NULL THEN split_sa.risk_weight_asset_pre_sme_fact ELSE vbia.risk_weight_asset_pre_sme_fact	END rwa_pre_sme_including_addon,
                vbia.rw_add_on_report_classification rwa_add_on_report_classification,
--                vbia.strict_prudential_rw_ind           strict_prudential_rw_ind,
                CASE WHEN split_sa.cover_key IS NOT NULL THEN split_sa.strict_prudential_rw_ind ELSE vbia.strict_prudential_rw_ind END	strict_prudential_rw_ind,
                CASE WHEN split_sa.cover_id IS NOT NULL THEN split_sa.rwa_ex_add_on ELSE vbia.rwa_ex_add_on	END rwa_ex_add_on,
                vbia.rwa_pre_sme_fact_ex_add_on	            rwa_pre_sme_fact_ex_add_on,
                --vbia.risk_weight_asset - vbia.rwa_ex_add_on          rwa_add_on_for_term_factor ,
                --vbia.risk_weight_excl_strict_prud	                    risk_weight_excl_strict_prud,
                CASE WHEN split_sa.cover_id IS NOT NULL THEN split_sa.risk_weight_excl_strict_prud  ELSE vbia.risk_weight_excl_strict_prud END risk_weight_excl_strict_prud,
                --vbia.rwa_pre_sme_fact_ex_strict_prud	                  rwa_pre_sme_fact_ex_strict_prud,
                CASE WHEN split_sa.cover_id IS NOT NULL THEN split_sa.rwa_pre_sme_fact_ex_strict_prud  ELSE vbia.rwa_pre_sme_fact_ex_strict_prud END rwa_pre_sme_fact_ex_strict_prud,
                --vbia.rwa_ex_strict_prud	                   rwa_ex_strict_prud,
                CASE WHEN split_sa.cover_id IS NOT NULL THEN split_sa.rwa_ex_strict_prud  ELSE vbia.rwa_ex_strict_prud END rwa_ex_strict_prud,
                case when vbia.subject_to_infra_factor_ind = 'Y' THEN 1 ELSE 0 END	          subject_to_infra_factor_ind,
                CASE WHEN split_sa.cover_id IS NOT NULL THEN split_sa.risk_weight_asset_pre_infra_fact  ELSE vbia.risk_weight_asset_pre_infra_fact END risk_weight_asset_pre_infra_fact,
                --vbia.rwa_pre_infra_fct_ex_add_on	                  rwa_pre_infra_fct_ex_add_on,
                --vbia.rwa_pre_infra_fct_ex_strict_prud	                rwa_pre_infra_fct_ex_strict_prud,
                CASE WHEN split_sa.cover_id IS NOT NULL THEN split_sa.rwa_pre_infra_fct_ex_strict_prud  ELSE vbia.rwa_pre_infra_fct_ex_strict_prud END rwa_pre_infra_fct_ex_strict_prud,
                (CASE WHEN split_sa.cover_id IS NOT NULL THEN split_sa.risk_weight_asset_pre_infra_fact  ELSE vbia.risk_weight_asset_pre_infra_fact END) -
                (CASE WHEN split_sa.cover_id IS NOT NULL THEN split_sa.risk_weight_asset_pre_sme_fact ELSE vbia.risk_weight_asset_pre_sme_fact	END)    rwa_sme_support_amt,
                (CASE WHEN split_sa.cover_id IS NOT NULL THEN split_sa.risk_weight_asset ELSE vbia.risk_weight_asset END)  - (CASE WHEN split_sa.cover_id IS NOT NULL THEN split_sa.risk_weight_asset_pre_infra_fact  ELSE vbia.risk_weight_asset_pre_infra_fact END)	                 rwa_infra_support_amt  ,
                vb.customer_id	            customer_id,
                vb.outstanding_group_key	            outstanding_group_key,
                CASE WHEN v_exp_class_sa_switch = 1 THEN
                     CASE WHEN vbia.riskweight_substitution = 'Y' THEN vb.exposure_class_sa_original
                          ELSE
                              CASE WHEN split_sa.cover_id IS NOT NULL THEN split_sa.exposure_class_sa_applied ELSE vbia.exposure_class_sa_applied END
                     END
                ELSE vb.exposure_class_sa_original
                END  exposure_class,
                vb.customer_key	            customer_key,
                vb.effective_maturity	            effective_maturity,
                vb.facility_id	            facility_id,
                vb.facility_key	            facility_key,
                vb.outstanding_id	            outstanding_id,
                vb.outstanding_key	            outstanding_key,
                vb.rating_original_key	            rating_key,
                vb.credit_quality_step_original	            credit_quality_step,
                vb.basel2_portfolio_code	            basel2_portfolio_code,
                vb.official_approach	            basel2_official_approach,
                vb.ccp_counterparty_indicator	            ccp_counterparty_indicator,
                vb.rating_agency_original_key	            rating_agency_original_key,
                vb.external_rating_original	            external_rating_original,
                vb.securitisation_rating_approach	            sec_rating_approach,
                CASE WHEN split_sa.cover_id IS NOT NULL THEN  split_sa.alloc_limit_amount ELSE vbia.ALLOC_LIMIT_AMOUNT END allocated_limit_amt,                   --SS Changed for SA as part of 7801523
                CASE WHEN split_sa.cover_id IS NOT NULL THEN  split_sa.alloc_outstanding_amount ELSE vbia.ALLOC_OUTSTANDING_AMOUNT END allocated_outstanding_amt,  --SS Changed for SA as part of 7801523
                vb.exposure_class_sa_not_def_sec	            exposure_class_sa_not_def_sec,
                CASE WHEN v_exp_class_sa_switch = 1 THEN vbia.exposure_class_sa_not_def ELSE vb.exposure_class_sa_not_def END              exposure_class_sa_not_def,
                vb.effective_regulated_indicator	            effective_regulated_indicator,
                vb.netted_indicator	            netted_indicator,
                round(vbia.pro_rata_factor * vb.calculated_add_on,2)	            calculated_add_on,
                vb.finrep_subordination_code	            finrep_subordination_code,
                vb.zero_rrw_sov_indicator	            zero_rrw_sov_indicator,
                vb.basel_local_official_approach	            basel_local_official_approach,
                vb.remaining_maturity_in_months	            remaining_maturity_in_months,
                vb.residual_maturity_bucket_code	            residual_maturity_bucket_code,
                vb.ppu_sa_ind           ppu_sa_ind,
                vb.pd_original_after_multipliers	            pd_original_after_multipliers,
                CASE WHEN vb.exposure_class_original = 'SEC' THEN 'I'  WHEN vb.exposure_class_original = 'SEC_SPON' THEN 'S' WHEN vb.exposure_class_original = 'SEC_ORIG' THEN 'O' End	sec_category,
                dsf.securitised_factor * dsf.sec_pro_rata_factor     securitised_factor,  --changed logic
                CASE WHEN vb.official_approach = vbia.basel_approach THEN 1 ELSE 0 END	            official_approach_indicator,
                CASE WHEN (CASE WHEN split_sa.cover_id IS NOT NULL THEN split_sa.exposure_class_sa_applied ELSE vbia.exposure_class_sa_applied END) = 'CEN_GOV' AND vbia.riskweight_substitution = 'Y' THEN 1 ELSE 0 END	            cqs_cen_gov_ind,
                CASE WHEN vbia.internal_sme_ind = 'Y' THEN 1 ELSE 0 END          sme_ind,
                CASE WHEN v_is_ind_active = 'Y' THEN CASE WHEN vbia.leverage_sme_ind = 'Y' THEN 1 ELSE 0 END ELSE NULL END	            leverage_sme_ind,
                v_reporting_date	reporting_date,
				vb.RETAINED_POSITION_IND	RETAINED_POSITION_IND,
                NULL AS risk_weight_asset_orig_obligor,
                vbia.external_rating_applied,
                vb.ead_exclusion_ind,
                CASE WHEN split_sa.cover_id IS NOT NULL THEN split_sa.condition_outcome_code ELSE vbia.condition_outcome_code END condition_outcome_code,
                CASE WHEN split_sa.cover_id IS NOT NULL THEN split_sa.ccf_10percent ELSE vbia.ccf_10percent END ccf_10percent,
                CASE WHEN split_sa.cover_id IS NOT NULL THEN split_sa.ccf_40percent ELSE vbia.ccf_40percent END ccf_40percent,
                split_sa.COVER_SPLIT_KEY COVER_SPLIT_KEY,
                split_sa.property_ratio_from property_ratio_from,
                split_sa.property_ratio_until property_ratio_until,
                --split_sa.EAD_RATIO EAD_RATIO,
                --split_sa.COLLATERALISATION_RATIO COLLATERALISATION_RATIO,
                vbia.exposure_class_applied exposure_class_irb_in_sa,
                CASE WHEN split_sa.cover_id IS NOT NULL THEN split_sa.ccf_ucc_transitional  ELSE vbia.ccf_ucc_transitional  END ccf_ucc_transitional ,
                CASE WHEN split_sa.cover_id IS NOT NULL THEN split_sa.rwa_non_ccf_ucc_trans  ELSE vbia.rwa_non_ccf_ucc_trans  END rwa_non_ccf_ucc_trans,
                split_sa.SPLIT_RATIO,
                CASE WHEN
                    NVL(vbia.rwa_non_ccf_ucc_trans ,0) = 0 then null
                else round((vbia.RISK_WEIGHT_ASSET * vbia.on_balance_ratio_exposure)/vbia.rwa_non_ccf_ucc_trans ,8) END ucc_non_trans_on_balance_ratio_exposure,
                vb.exposure_class_sa_original,
				CASE WHEN split_sa.cover_id IS NOT NULL THEN split_sa.risk_weight_asset_pre_fx_mm  ELSE vbia.risk_weight_asset_pre_fx_mm  END risk_weight_asset_pre_fx_mm,
				CASE WHEN split_sa.cover_id IS NOT NULL THEN split_sa.risk_weight_factor_pre_fx_mm  ELSE vbia.risk_weight_factor_pre_fx_mm  END risk_weight_factor_pre_fx_mm,
				NVL(vbia.loan_split_derogation_ind,'N') loan_split_derogation_ind,
                vbia.risk_weight_art378,
				vbia.exposure_art378,
				vbia.rwa_art378,
				null book_risk_category,
				null settlement_date,
				null days_unsettled_after_due_date,
				null settlement_amount,
				dsf.securitisation_code,  ----added new for 7324855
				(1- dsf.securitised_factor) * dsf.sec_pro_rata_factor unsecuritised_factor, --added new for 7324855
				dsf.sec_pro_rata_factor
              FROM dwh_recapb4_osg_cover_sa vbia,tmp_corep_vbr_basel4 vb,dwh_recapb4_cover_split_sa split_sa, dmb_securitised_rwa dsf -- added join for multiple securitised_factors
              WHERE vbia.record_valid_from = v_reporting_date AND vbia.system_id = v_system_id AND vbia.basel_approach IN ('SA','SA_TR')
              AND vbia.outstanding_group_id = vb.outstanding_group_id(+)
              AND vbia.cover_id = split_sa.cover_id(+)
              AND vbia.basel_approach = split_sa.basel_approach(+)
			  AND vbia.record_valid_from = split_sa.record_valid_from (+)
              AND vbia.system_id = split_sa.system_id(+)
              and vbia.outstanding_group_id = split_sa.outstanding_group_id(+)
              and vb.outstanding_group_id = dsf.outstanding_group_id(+)
			  AND nvl(vbia.cover_id,' ')= nvl(dsf.cover_id(+),' ')
              AND vbia.basel_approach=dsf.basel_approach(+)
			  --  AND vb.facility_id = dsf.facility_id(+)
			  AND dsf.system_id(+) = v_system_id  --make sure the join on dwh_securitised_facility remains left join.
			  AND dsf.record_valid_from(+) <= V_REPORTING_DATE --securitised_factor
			  AND (dsf.record_valid_until(+) > v_reporting_date or dsf.record_valid_until(+) is null));

    EXCEPTION
        WHEN OTHERS THEN utils.handleerror(sqlcode,sqlerrm);
    END;

    v_debug_msg := $$plsql_line|| ' of plsql unit '|| $$plsql_unit|| ' '|| systimestamp|| ' Rows Affected:- '|| SQL%rowcount;
    v_offset := v_offset + SQL%rowcount;  --ORAMIGCATCHUP3
    utilities.show_debug(v_debug_msg);
    COMMIT;

    insert_dmb_log_corep(v_detail_level => 103,
                                   v_log_descr => 'process_pre_corep_recap_b4',
                                   v_activity_code => 'SA insert',
                                   v_result_code => 'FINOK',
                                   v_system_id       => v_system_id,v_reporting_date       => v_reporting_date);

    insert_dmb_log_corep(v_detail_level => 103,
                                   v_log_descr => 'process_pre_corep_recap_b4',
                                   v_activity_code => 'Upd VBR',
                                   v_result_code => 'START',
                                   v_system_id       => v_system_id,v_reporting_date       => v_reporting_date);
    schema_maint.gather_idx_stats('tmp_corep_recap_b4');

    insert_dmb_log_corep(v_detail_level    => 103,
                                   v_log_descr       => 'process_pre_corep_recap_b4',
                                   v_activity_code   => 'Upd VBR',
                                   v_result_code     => 'FINOK',
                                   v_system_id       => v_system_id,v_reporting_date       => v_reporting_date
                                   );

    insert_dmb_log_corep(v_detail_level => 103,
                                    v_log_descr => 'process_pre_corep_recap_b4',
                                    v_activity_code => 'Ins STS',
                                    v_result_code => 'START',
                                    v_system_id       => v_system_id,v_reporting_date       => v_reporting_date) ;



   INSERT /*+ APPEND */ INTO tmp_corep_recap_b4
    (       record_id	,
			outstanding_group_id	,
			outstanding_group_key	,
			customer_id	,
			customer_key	,
			facility_id	,
			facility_key	,
			outstanding_id	,
			outstanding_key	,
			cover_id	,
			record_valid_from	,
			system_id	,
			capital_requirement	,
			exposure_at_default	,
			exposure_original	,
			exposure_class	,
			exposure_class_applied	,
			official_approach_indicator	,
			allocated_limit_amt	,
			allocated_outstanding_amt	,
			alloc_provision_amt	,
			exposure_original_drawn	,
			exposure_original_undrawn	,
			exposure_pre_ccf	,
			exposure_pre_ccf_drawn	,
			exposure_pre_ccf_undrawn	,
			loss_given_default	,
			on_balance_ratio	,
			on_balance_ratio_exposure	,
			--on_balance_ratio_on_balance	,
			risk_weighted_assets	,
			risk_weight_factor	,
			risk_weight_substitution	,
			risk_weight_asset_pre_sme_fact	,
			credit_quality_step_sec	,
			source_table	,
			risk_weight_asset_original	,
			--rating_agency_sec_key	,
			--external_rating_sec	,
			--cover_market_value	,
			pro_rata_factor	,
			risk_weight_factor_original	,
			--rwa_including_addonterm	,
			rwa_including_addon	,
			regulator	,
			external_rating_original	,
			sec_rating_approach	,
			sec_category	,
			securitised_factor	,
			sts_indicator	,
			sec_calculation_method	,
			subject_to_sme_factor_ind	,
			zero_rrw_sov_indicator	,
			ccf_0percent	,
			ccf_100percent	,
			basel_approach	,
			basel2_official_approach	,
			pd_applied	,
			effective_maturity	,
			exposure_net_provision_sa	,
			fully_adjusted_exposure	,
			credit_conversion_factor	,
			original_cover_value	,
			financial_collateral_sa	,
			fully_adjusted_exposure_on_sa	,
			fully_adjusted_exposure_off_sa	,
			exposure_weighted_avg_lgd	,
			k_a_parameter_w	,
			k_irb	,
			k_sa	,
			subject_to_infra_factor_ind	,
			risk_weight_asset_pre_infra_fact	,
			--rwa_pre_infra_fct_ex_add_on	,
			--rwa_pre_infra_fct_ex_strict_prud	,
			rwa_sme_support_amt	,
			rwa_infra_support_amt	,
			cqs_cen_gov_ind	,
			sme_ind	,
			leverage_sme_ind	,
			reporting_date	,
			RETAINED_POSITION_IND	,
			risk_weight_asset_orig_obligor	,
			risk_weight_asset_sec_erba	,
			risk_weight_asset_sec_sa,
            risk_weight_asset_sec_tr,
            risk_weighted_assets_due_dill,
            risk_weighted_assets_sec_mat_mism,
            configuration_code
			--securitised_factor
    )
  SELECT        v_offset + rownum	record_id	,
				vbia.outstanding_group_id	outstanding_group_id	,
				vbia.outstanding_group_key	outstanding_group_key	,
				vbia.customer_id	customer_id	,
				vbia.customer_key	customer_key	,
				vbia.facility_id	facility_id	,
				vbia.facility_key	facility_key	,
				vbia.outstanding_id	outstanding_id	,
				vbia.outstanding_key	outstanding_key	,
				vbia.cover_id	cover_id	,
				vbia.record_valid_from	record_valid_from	,
				vbia.system_id	system_id	,
				vbia.capital_requirement	capital_requirement	,
				vbia.exposure_at_default	exposure_at_default	,
				vbia.exposure_original	exposure_original	,
				vbia.exposure_class_original	exposure_class	,
				vbia.exposure_class_applied	exposure_class_applied	,
				case when vbia.configuration_code = 'SECSTS4TR' THEN 0 ELSE 1 END	official_approach_indicator, --#7926026
				vbia.alloc_limit_amount	allocated_limit_amt	,
				vbia.alloc_outstanding_amount	allocated_outstanding_amt	,
				vbia.alloc_provision_amount	alloc_provision_amt	,
				vbia.exposure_original_drawn	exposure_original_drawn	,
				CASE WHEN vbia.exposure_original - vbia.exposure_original_drawn < 0 THEN 0 ELSE vbia.exposure_original - vbia.exposure_original_drawn END	exposure_original_undrawn	,
				CASE WHEN vbia.exposure_original >= vbia.exposure_original_drawn THEN vbia.exposure_original ELSE vbia.exposure_original_drawn END	exposure_pre_ccf	,
				vbia.exposure_original_drawn	exposure_pre_ccf_drawn	,
				CASE WHEN CASE WHEN vbia.exposure_original >= vbia.exposure_original_drawn THEN vbia.exposure_original ELSE vbia.exposure_original_drawn END - vbia.exposure_original_drawn < 0 THEN 0 ELSE CASE WHEN vbia.exposure_original >= vbia.exposure_original_drawn THEN vbia.exposure_original ELSE vbia.exposure_original_drawn END - vbia.exposure_original_drawn END	exposure_pre_ccf_undrawn	,
				vbia.lgd_guarantor	loss_given_default	,
				vbia.on_balance_ratio	on_balance_ratio	,
				vbia.on_balance_ratio_exposure 	on_balance_ratio_exposure	,
				--CASE WHEN vbia.on_balance_ratio = 0 THEN 0 ELSE 1 END	on_balance_ratio_on_balance	,
				vbia.risk_weight_asset	risk_weighted_assets	,
				vbia.risk_weight_factor	risk_weight_factor	,
				CASE WHEN vbia.riskweight_substitution = 'Y' THEN 1 WHEN vbia.riskweight_substitution = 'N' THEN 0 END	risk_weight_substitution	,
				vbia.risk_weight_asset_pre_sme_fact	risk_weight_asset_pre_sme_fact	,
				vbia.credit_quality_step	credit_quality_step_sec	,
				'SEC'	source_table	,
				vbia.risk_weight_asset_original	risk_weight_asset_original	,
				--vbia.rating_agency	rating_agency_sec_key	,
				--vbia.external_rating	external_rating_sec	,
				--NULL	cover_market_value	,
				vbia.pro_rata_factor	pro_rata_factor	,
				vbia.risk_weight_factor_original	risk_weight_factor_original	,
				--vbia.risk_weight_asset	rwa_including_addonterm	,
				vbia.risk_weight_asset	rwa_including_addon	,
				'NL'	regulator	,
				vbia.external_rating	external_rating_original	,
				vbia.configuration_code	sec_rating_approach	,
				CASE WHEN vbia.exposure_class_original = 'SEC' THEN 'I' WHEN vbia.exposure_class_original = 'SEC_SPON' THEN 'S' WHEN vbia.exposure_class_original = 'SEC_ORIG' THEN 'O' END sec_category	,
				NVL(vbia.securitised_factor,0)	securitised_factor	,
				vbia.sts_indicator	sts_indicator	,
				vbia.sec_calculation_method	sec_calculation_method	,
				case when vbia.subject_to_sme_factor_ind = 'Y' THEN 1 ELSE 0 END	subject_to_sme_factor_ind	,
				CASE WHEN vbia.zero_rrw_sov_indicator IS NULL THEN NULL WHEN vbia.zero_rrw_sov_indicator = 'Y' THEN 1 ELSE 0 END	zero_rrw_sov_indicator	,
				vbia.ccf_0percent	ccf_0percent	,
				vbia.ccf_100percent	ccf_100percent	,
				vbia.rw_substitution_approach	basel_approach	,
				vbia.rw_substitution_approach	basel2_official_approach	,
				vbia.pd_guarantor	pd_applied	,
				vbia.maturity_factor_guarantor	effective_maturity	,
				vbia.exposure_net_provision	exposure_net_provision_sa	,
				(nvl(vbia.exposure_net_provision,0) - nvl(vbia.collateral,0))	fully_adjusted_exposure	,
				vbia.credit_conversion_factor	credit_conversion_factor	,
				vbia.original_cover_value	original_cover_value	,
				vbia.collateral	financial_collateral_sa	,
				(nvl(vbia.exposure_net_provision,0) - nvl(vbia.collateral,0))  *  vbia.on_balance_ratio	fully_adjusted_exposure_on_sa	,
				(nvl(vbia.exposure_net_provision,0) - nvl(vbia.collateral,0))  *  ( 1 - vbia.on_balance_ratio )	fully_adjusted_exposure_off_sa	,
				vbia.exposure_weighted_avg_lgd	exposure_weighted_avg_lgd	,
				vbia.k_a_parameter_w	k_a_parameter_w	,
				vbia.k_irb	k_irb	,
				vbia.k_sa	k_sa	,
				case when vbia.subject_to_infra_factor_ind = 'Y' THEN 1 ELSE 0 END	subject_to_infra_factor_ind	,
				vbia.risk_weight_asset_pre_infra_fact	risk_weight_asset_pre_infra_fact	,
				--vbia.risk_weight_asset_pre_infra_fact	rwa_pre_infra_fct_ex_add_on	,
				--NULL	rwa_pre_infra_fct_ex_strict_prud	,
				vbia.risk_weight_asset_pre_infra_fact - vbia.risk_weight_asset_pre_sme_fact	rwa_sme_support_amt	,
				vbia.risk_weight_asset - vbia.risk_weight_asset_pre_infra_fact	rwa_infra_support_amt	,
				CASE WHEN vbia.exposure_class_applied = 'CEN_GOV' AND vbia.riskweight_substitution = 'Y' THEN 1 ELSE 0 END	cqs_cen_gov_ind	,
				0 sme_ind	,
				NULL leverage_sme_ind	,
				v_reporting_date	reporting_date	,
				CASE WHEN vbia.exposure_class_original = 'SEC_ORIG' THEN 1 ELSE 0 END	RETAINED_POSITION_IND	,
				vbia.risk_weight_asset_orig_obligor	risk_weight_asset_orig_obligor	,
				CASE WHEN  vbia.sec_calculation_method = 'SEC-ERBA' THEN NULL ELSE risk_weight_asset_sec_erba END	risk_weight_asset_sec_erba	,
				CASE WHEN  vbia.sec_calculation_method = 'SEC-SA' THEN NULL ELSE risk_weight_asset_sec_sa  END	risk_weight_asset_sec_sa,
				NULL risk_weight_asset_sec_tr	, -- As per latest RIS Changes
                vbia.risk_weight_asset_art_122a risk_weighted_assets_due_dill,
                vbia.risk_weight_asset_sec_mm risk_weighted_assets_sec_mat_mism,
                vbia.configuration_code
				--vbia.securitised_factor
    FROM  dwh_vre_securitisation_recapb4 vbia
    WHERE vbia.system_id = v_system_id
    AND vbia.record_valid_from = v_reporting_date
	AND vbia.rwa_calculated_indicator = 'Y';

    COMMIT;
    schema_maint.gather_idx_stats('tmp_corep_recap_b4');

    MERGE INTO tmp_corep_recap_b4 rm USING
    (SELECT rm.ROWID row_id, max(rr.risk_rating_key) risk_rating_key
     FROM tmp_corep_recap_b4 rm,dwh_vre_securitisation_recapb4 vbia
     LEFT JOIN rating_agency ra ON CAST(vbia.rating_agency AS NUMBER(18)) = ra.rating_agency_key
                                AND ra.record_valid_from <= vbia.record_valid_from
                                AND (ra.record_valid_until > vbia.record_valid_from OR ra.record_valid_until IS NULL)
     LEFT JOIN external_rating_scale ers ON ers.external_rating_scale = vbia.external_rating
                                         AND ra.code = ers.rating_agency_code
                                         AND ers.rating_type = 'LR'
                                         AND ers.record_valid_from <= vbia.record_valid_from
                                         AND (ers.record_valid_until > vbia.record_valid_from OR ers.record_valid_until IS NULL)
     JOIN risk_rating rr ON CASE WHEN vbia.internal_rating IS NOT NULL THEN vbia.internal_rating
                                 ELSE ers.risk_rating_master_scale
                            END = rr.code
                         AND vbia.record_valid_from >= rr.record_valid_from
                         AND (vbia.record_valid_from < rr.record_valid_until OR rr.record_valid_until IS NULL)
     WHERE rm.source_table = 'SEC'
     AND rm.outstanding_group_key = vbia.outstanding_group_key
     AND rm.record_valid_from = vbia.record_valid_from
     group by rm.ROWID) src
     ON ( rm.ROWID = src.row_id )
     WHEN MATCHED THEN UPDATE SET rm.rating_key = src.risk_rating_key;

    COMMIT;

    insert_dmb_log_corep(v_detail_level => 103,
                                v_log_descr => 'process_pre_corep_recap_b4',
                                v_activity_code => 'Ins STS',
                                v_result_code => 'FINOK',
                                v_system_id       => v_system_id,v_reporting_date       => v_reporting_date) ;



    insert_dmb_log_corep(
                                    v_detail_level    => 103,
                                    v_log_descr       => 'process_pre_corep_recap_b4',
                                    v_activity_code   => 'otb amounts',
                                    v_result_code     => 'START',
                                    v_system_id       => v_system_id,v_reporting_date       => v_reporting_date
                                );

    utilities.truncate_table('TMP_COREP_OUTSTANDING_TIME_BAND_FACT_B4');
    BEGIN
        INSERT /*+ APPEND */ INTO TMP_COREP_OUTSTANDING_TIME_BAND_FACT_B4
        (outstanding_key,time_band_key,netting_type,os_amt)
        ( SELECT osf.outstanding_key,osf.time_band_key,osf.netting_type,osf.os_amt
          FROM dwh_outstanding_time_band_fact osf --,tmp_basel_combined_uploads cu
          WHERE  osf.record_valid_from = v_reporting_date --  modification corep_vpp
           AND osf.system_id = v_system_id --  modification corep_vpp
          AND osf.amt_type = 'OAMB'
          AND osf.netting_type IN --('SACCR_GC_R','SACCR_CC_R','SACCR_NC_R','NO','SACCR_VC_R', 'SACCR_VO_R','SACCR_IM_R',  'SACCR_RC_C', 'SACCRAddon', 'SACCR_VC_L', 'SACCR_RC_L')--added from the next insert for TMP_COREP_OUTSTANDING_TIME_BAND_FACT_VPP --CU7
                ('GC','CC','NC','GIR','CIR','NIR','GCR','CCR','NCR','ON','NO','SACCR_VC_R', 'SACCR_VO_R', 'SACCR_IM_R',  'SACCR_RC_C', 'SACCRAddon', 'SACCR_VC_L', 'SACCR_RC_L')
        );
    EXCEPTION
        WHEN OTHERS THEN utils.handleerror(sqlcode,sqlerrm);
    END;
    COMMIT;
    schema_maint.gather_idx_stats('TMP_COREP_OUTSTANDING_TIME_BAND_FACT_B4');

    BEGIN
        --JT Query tune for performance issue
        MERGE /*+ enable_parallel_dml */ INTO ( SELECT netting_type,time_band_key,outstanding_key,first_timeband FROM  TMP_COREP_OUTSTANDING_TIME_BAND_FACT_B4 ) t1 USING
        (SELECT outstanding_key,netting_type,MIN(time_band_key) time_band_key
         FROM TMP_COREP_OUTSTANDING_TIME_BAND_FACT_B4
         GROUP BY outstanding_key,netting_type
        ) t2
        ON (t1.outstanding_key = t2.outstanding_key AND t1.netting_type = t2.netting_type AND t1.time_band_key = t2.time_band_key)
       WHEN MATCHED THEN UPDATE SET t1.first_timeband = 1;
    EXCEPTION
        WHEN OTHERS THEN utils.handleerror(sqlcode,sqlerrm);
    END;

    v_debug_msg := $$plsql_line|| ' of plsql unit '|| $$plsql_unit|| ' '|| systimestamp|| ' Rows Affected:- '|| SQL%rowcount;
    utilities.show_debug(v_debug_msg);
    COMMIT;
    --force gather first timeband statistics
    DBMS_STATS.gather_table_stats(ownname=>'VORTEX_BUSS_OWNER', tabname=>'TMP_COREP_OUTSTANDING_TIME_BAND_FACT_B4', force=>true);

    BEGIN --JT Query tune for performance issue
        MERGE /*+ enable_parallel_dml +*/ INTO (SELECT outstanding_key,outstanding_group_key
                                                FROM TMP_COREP_OUTSTANDING_TIME_BAND_FACT_B4 WHERE first_timeband = 1) otb USING
        (SELECT o.outstanding_group_key,o.outstanding_key
         FROM dwh_outstanding o--,tmp_basel_combined_uploads cu
         WHERE --cu.load_key_n = o.load_key
         o.record_valid_from = v_reporting_date --  modification corep_vpp
           AND o.system_id = v_system_id --  modification corep_vpp
        )src
        ON ( otb.outstanding_key = src.outstanding_key )
        WHEN MATCHED THEN UPDATE SET otb.outstanding_group_key = src.outstanding_group_key;
    EXCEPTION
        WHEN OTHERS THEN utils.handleerror(sqlcode,sqlerrm);
    END;

    v_debug_msg := $$plsql_line|| ' of plsql unit '|| $$plsql_unit|| ' '|| systimestamp|| ' Rows Affected:- '|| SQL%rowcount;
    utilities.show_debug(v_debug_msg);
    COMMIT;

    BEGIN
    MERGE /*+ enable_parallel_dml +*/ INTO
    (SELECT outstanding_group_key,after_coll_regulatory_os_amt,system_id,basel_approach,pro_rata_factor,
           gross_regulatory_os_amt,regulatory_os_amt,old_regulatory_os_amt,notional_amount,
           ccr_variation_margin,ccr_net_indep_collat_amt,ccr_replacement_cost,ccr_addon,lre_ccr_variation_margin,lre_ccr_replacement_cost,split_ratio
     FROM tmp_corep_recap_b4)rm USING
     (SELECT outstanding_group_key,
--            NULL cir_amt,
--            NULL ccr_amt,
--            SUM(CASE WHEN otba.netting_type = 'SACCR_CC_R' THEN otba.os_amt END) cc_amt,
--            NULL gir_amt,
--            NULL gcr_amt,
--            SUM(CASE WHEN otba.netting_type = 'SACCR_GC_R' THEN otba.os_amt END) gc_amt,
--            NULL nir_amt,
--            NULL ncr_amt,
--            SUM(CASE WHEN otba.netting_type = 'SACCR_NC_R' THEN otba.os_amt END) nc_amt,
--            NULL on_amt,
        SUM(CASE WHEN otba.netting_type = 'NO' THEN otba.os_amt END) notional_amount,--added from merge statement for netting type 'NO'
        SUM(CASE WHEN otba.netting_type IN('SACCR_VC_R','SACCR_VO_R') THEN otba.os_amt END) AS ccr_variation_margin,
        SUM(CASE WHEN otba.netting_type = 'SACCR_IM_R' THEN otba.os_amt END) AS ccr_net_indep_collat_amt,
        SUM(CASE WHEN otba.netting_type = 'SACCR_RC_C' THEN otba.os_amt END) AS ccr_replacement_cost,
        SUM(CASE WHEN otba.netting_type = 'SACCRAddon' THEN otba.os_amt END) AS ccr_addon,
        SUM(CASE WHEN otba.netting_type = 'SACCR_VC_L' THEN otba.os_amt END) AS lre_ccr_variation_margin,
        SUM(CASE WHEN otba.netting_type = 'SACCR_RC_L' THEN otba.os_amt END) AS lre_ccr_replacement_cost
      FROM TMP_COREP_OUTSTANDING_TIME_BAND_FACT_B4 otba
      WHERE otba.first_timeband = 1
      GROUP BY otba.outstanding_group_key) t
    ON ( rm.outstanding_group_key = t.outstanding_group_key )
    WHEN MATCHED THEN UPDATE SET
--                                 rm.after_coll_regulatory_os_amt = CASE WHEN rm.system_id = 'CRS' AND rm.basel_approach = 'AIRB' THEN round(t.cir_amt * rm.pro_rata_factor,2)
--                                                                        WHEN rm.system_id = 'CRS' AND rm.basel_approach IN ('SA','SA_TR') THEN round(t.ccr_amt * rm.pro_rata_factor,2)
--                                                                        ELSE round(t.cc_amt * rm.pro_rata_factor,2)
--                                                                   END,
--                                 rm.gross_regulatory_os_amt = CASE WHEN rm.system_id = 'CRS' AND rm.basel_approach = 'AIRB' THEN round(t.gir_amt * rm.pro_rata_factor,2)
--                                                                   WHEN rm.system_id = 'CRS' AND rm.basel_approach IN ('SA','SA_TR') THEN round(t.gcr_amt * rm.pro_rata_factor,2)
--                                                                   ELSE round(t.gc_amt * rm.pro_rata_factor,2)
--                                                              END,
--                                 rm.regulatory_os_amt = CASE WHEN rm.system_id = 'CRS' AND rm.basel_approach = 'AIRB' THEN round(t.nir_amt * rm.pro_rata_factor,2)
--                                                             WHEN rm.system_id = 'CRS' AND rm.basel_approach IN ('SA','SA_TR') THEN round(t.ncr_amt * rm.pro_rata_factor,2)
--                                                             ELSE round(t.nc_amt * rm.pro_rata_factor,2)
--                                                        END,
--                                 rm.old_regulatory_os_amt = CASE WHEN rm.system_id = 'CRS' AND rm.basel_approach = 'AIRB' THEN round(t.nir_amt * rm.pro_rata_factor,2)
--                                                                 WHEN rm.system_id = 'CRS' AND rm.basel_approach IN ('SA','SA_TR') THEN round(t.ncr_amt * rm.pro_rata_factor,2)
--                                                                 WHEN rm.system_id = 'CRS' AND t.on_amt IS NOT NULL THEN round(t.on_amt * rm.pro_rata_factor,2)
--                                                                 ELSE round(t.nc_amt * rm.pro_rata_factor,2)
--                                                            END,
                                 rm.notional_amount = round(round(t.notional_amount * rm.pro_rata_factor,2)* nvl(rm.split_ratio,1),2),
                                 rm.ccr_variation_margin = round(t.ccr_variation_margin * rm.pro_rata_factor,2),
                                 rm.ccr_net_indep_collat_amt = round(t.ccr_net_indep_collat_amt * rm.pro_rata_factor,2),
                                 rm.ccr_replacement_cost = round(t.ccr_replacement_cost * rm.pro_rata_factor,2),
                                 rm.ccr_addon = round(t.ccr_addon * rm.pro_rata_factor,2),
                                 rm.lre_ccr_variation_margin = round(t.lre_ccr_variation_margin * rm.pro_rata_factor,2),
                                 rm.lre_ccr_replacement_cost = round(t.lre_ccr_replacement_cost * rm.pro_rata_factor,2);
    EXCEPTION
        WHEN OTHERS THEN utils.handleerror(sqlcode,sqlerrm);
    END;

    v_debug_msg := $$plsql_line|| ' of plsql unit '|| $$plsql_unit|| ' '|| systimestamp|| ' Rows Affected:- '|| SQL%rowcount;
    utilities.show_debug(v_debug_msg);
    COMMIT;

    utilities.truncate_table('TMP_COREP_OUTSTANDING_TIME_BAND_FACT_B4');
    BEGIN
        INSERT /*+ APPEND +*/ INTO TMP_COREP_OUTSTANDING_TIME_BAND_FACT_B4 (outstanding_key,time_band_key,netting_type,os_amt)
        (SELECT osf.outstanding_key,NULL,osf.amt_type,osf.os_amt -- added amt_type to seperate values and use this column in below merge
         FROM dwh_outstanding_fact osf --,tmp_basel_combined_uploads cu
         WHERE osf.record_valid_from = v_reporting_date --  modification corep_vpp
           AND osf.system_id = v_system_id --  modification corep_vpp
         AND osf.amt_type IN('OMVB','OLEB')--added from next INSERT
        );

        v_debug_msg := $$plsql_line|| ' of plsql unit '|| $$plsql_unit|| ' '|| systimestamp|| ' Rows Affected:- '|| SQL%rowcount;
        utilities.show_debug(v_debug_msg);
        COMMIT;
    EXCEPTION
        WHEN OTHERS THEN utils.handleerror(sqlcode,sqlerrm);
    END;

    schema_maint.gather_idx_stats('TMP_COREP_OUTSTANDING_TIME_BAND_FACT_B4');

    BEGIN --JT Query tune for performance issue
        MERGE /*+ enable_parallel_dml */ INTO ( SELECT outstanding_key,outstanding_group_key FROM TMP_COREP_OUTSTANDING_TIME_BAND_FACT_B4) otb USING
        (SELECT o.outstanding_group_key,o.outstanding_key
         FROM dwh_outstanding o--,tmp_basel_combined_uploads cu
         WHERE o.record_valid_from = v_reporting_date --  modification corep_vpp
           AND o.system_id = v_system_id --  modification corep_vpp
        ) src
        ON ( otb.outstanding_key = src.outstanding_key )
        WHEN MATCHED THEN UPDATE SET otb.outstanding_group_key = src.outstanding_group_key;
    EXCEPTION
        WHEN OTHERS THEN utils.handleerror(sqlcode,sqlerrm);
    END;

    v_debug_msg := $$plsql_line|| ' of plsql unit '|| $$plsql_unit|| ' '|| systimestamp|| ' Rows Affected:- '|| SQL%rowcount;
    utilities.show_debug(v_debug_msg);
    COMMIT;

    BEGIN --JT Query tune for performance issue
        MERGE /*+ enable_parallel_dml */ INTO (SELECT outstanding_group_key,pro_rata_factor,mtm_amount,add_on,split_ratio FROM tmp_corep_recap_b4) rm USING
        (SELECT outstanding_group_key,
         SUM(CASE WHEN otba.netting_type = 'OMVB' THEN otba.os_amt END) mtm_amount,
         SUM(CASE WHEN otba.netting_type = 'OLEB' THEN otba.os_amt END) add_on
         FROM TMP_COREP_OUTSTANDING_TIME_BAND_FACT_B4 otba
         GROUP BY otba.outstanding_group_key) src
        ON ( rm.outstanding_group_key = src.outstanding_group_key )
        WHEN MATCHED THEN UPDATE SET rm.mtm_amount = round(round(src.mtm_amount * rm.pro_rata_factor,2)* nvl(rm.split_ratio,1),2),
                                     rm.add_on = round(src.add_on * rm.pro_rata_factor,2);

        v_debug_msg := $$plsql_line|| ' of plsql unit '|| $$plsql_unit|| ' '|| systimestamp|| ' Rows Affected:- '|| SQL%rowcount;
        utilities.show_debug(v_debug_msg);
    EXCEPTION
        WHEN OTHERS THEN utils.handleerror(sqlcode,sqlerrm);
    END;
    COMMIT;

    -------------oramigcu7 start

    --------------------------------------------------------------------------------------------------
    --TRUNCATE TABLE TMP_COREP_OUTSTANDING_TIME_BAND_FACT_B4
        utilities.truncate_table('TMP_COREP_OUTSTANDING_TIME_BAND_FACT_B4');
        INSERT /*+ APPEND +*/ INTO TMP_COREP_OUTSTANDING_TIME_BAND_FACT_B4
        (      outstanding_key
        ,      time_band_key
        ,      netting_type
        ,      os_amt
        )
        SELECT os.outstanding_key
        ,      null
        ,      null
        ,      sum(osf.os_component_amt)
        FROM   dwh_outstanding_component_amt osf,
                dwh_outstanding_component  os
        --,      tmp_basel_combined_uploads   cu
        WHERE   osf.os_amt_tp_code = 'SACCRPFE_C'
        AND osf.outstanding_component_key = os.outstanding_component_key       --AB 20220201
        AND osf.record_valid_from = v_reporting_date --  modification corep_vpp
        AND osf.system_id = v_system_id --  modification corep_vpp
        AND os.record_valid_from = v_reporting_date --  modification corep_vpp
        AND os.system_id = v_system_id --  modification corep_vpp
        group by os.outstanding_key;
commit;

        schema_maint.gather_idx_stats('TMP_COREP_OUTSTANDING_TIME_BAND_FACT_B4');

        MERGE INTO (select outstanding_group_key,outstanding_key from  TMP_COREP_OUTSTANDING_TIME_BAND_FACT_B4 )otb
        USING (SELECT  o.outstanding_group_key,o.outstanding_key
        FROM dwh_outstanding o --,        tmp_basel_combined_uploads cu
        WHERE o.record_valid_from = v_reporting_date --  modification corep_vpp
           AND o.system_id = v_system_id --  modification corep_vpp
         ) src
        ON ( otb.outstanding_key = src.outstanding_key )
        WHEN MATCHED THEN UPDATE SET otb.outstanding_group_key = src.outstanding_group_key;

commit;

        MERGE INTO ( select pro_rata_factor,ccr_potential_future_exp,outstanding_group_key from tmp_corep_recap_b4 )rm
        USING ( SELECT         otba.outstanding_group_key ,
                               SUM(otba.os_amt) as  ccr_potential_future_exp
                               FROM TMP_COREP_OUTSTANDING_TIME_BAND_FACT_B4 otba
                               GROUP BY otba.outstanding_group_key ) t
        on ( rm.outstanding_group_key = t.outstanding_group_key)
        WHEN MATCHED THEN UPDATE SET rm.ccr_potential_future_exp = ROUND(t.ccr_potential_future_exp * rm.pro_rata_factor,2);
commit;
--------------------------------------------------------------------------------------------------
    --TRUNCATE TABLE TMP_COREP_OUTSTANDING_TIME_BAND_FACT_B4
  utilities.truncate_table('TMP_COREP_OUTSTANDING_TIME_BAND_FACT_B4');
        INSERT /*+ APPEND +*/ INTO TMP_COREP_OUTSTANDING_TIME_BAND_FACT_B4
        (      outstanding_key
        ,      time_band_key
        ,      netting_type
        ,      os_amt
        )
        SELECT os.outstanding_key
        ,      null
        ,      null
        ,      sum(osf.os_component_amt)
        FROM   dwh_outstanding_component_amt osf, dwh_outstanding_component  os
        --,      tmp_basel_combined_uploads   cu
        WHERE  osf.os_amt_tp_code = 'SACCR_NC_R'
        AND osf.outstanding_component_key = os.outstanding_component_key       --AB  20220201
        AND osf.record_valid_from = v_reporting_date --  modification corep_vpp
        AND osf.system_id = v_system_id --  modification corep_vpp
        AND os.record_valid_from = v_reporting_date --  modification corep_vpp
        AND os.system_id = v_system_id --  modification corep_vpp
        group by os.outstanding_key;
        commit;
        schema_maint.gather_idx_stats('TMP_COREP_OUTSTANDING_TIME_BAND_FACT_B4');

        MERGE INTO (select outstanding_group_key,outstanding_key from  TMP_COREP_OUTSTANDING_TIME_BAND_FACT_B4) otb
        USING (SELECT  o.outstanding_group_key,o.outstanding_key
        FROM dwh_outstanding o --,             tmp_basel_combined_uploads cu
        WHERE o.record_valid_from = v_reporting_date --  modification corep_vpp
        AND o.system_id = v_system_id --  modification corep_vpp
        ) src
        on ( otb.outstanding_key = src.outstanding_key)
        WHEN MATCHED THEN UPDATE SET otb.outstanding_group_key = src.outstanding_group_key;

commit;

       MERGE INTO (select pro_rata_factor,ccr_exp_value_pre_crm,outstanding_group_key from  tmp_corep_recap_b4 )rm USING
       (SELECT otba.outstanding_group_key , SUM(otba.os_amt)  as ccr_exp_value_pre_crm
        FROM TMP_COREP_OUTSTANDING_TIME_BAND_FACT_B4 otba
        GROUP BY otba.outstanding_group_key ) t
       on ( rm.outstanding_group_key = t.outstanding_group_key)
       WHEN MATCHED THEN UPDATE SET rm.ccr_exp_value_pre_crm = ROUND(t.ccr_exp_value_pre_crm * rm.pro_rata_factor,2);

commit;

--------------------------------------------------------------------------------------------------
    ---TRUNCATE TABLE TMP_COREP_OUTSTANDING_TIME_BAND_FACT_B4
    utilities.truncate_table('TMP_COREP_OUTSTANDING_TIME_BAND_FACT_B4');

        INSERT /*+ APPEND +*/ INTO TMP_COREP_OUTSTANDING_TIME_BAND_FACT_B4
        (      outstanding_key
        ,      time_band_key
        ,      netting_type
        ,      os_amt
        )
        SELECT os.outstanding_key
        ,      null
        ,      null
        ,      sum(osf.os_component_amt)
        FROM   dwh_outstanding_component_amt osf, dwh_outstanding_component  os
        --,      tmp_basel_combined_uploads   cu
        WHERE   osf.os_amt_tp_code = 'SACCR_CC_R'
        AND osf.outstanding_component_key = os.outstanding_component_key     --AB  20220201
        AND osf.record_valid_from = v_reporting_date --  modification corep_vpp
        AND osf.system_id = v_system_id --  modification corep_vpp
        AND os.record_valid_from = v_reporting_date --  modification corep_vpp
        AND os.system_id = v_system_id --  modification corep_vpp
        group by os.outstanding_key;
        commit;

        schema_maint.gather_idx_stats('TMP_COREP_OUTSTANDING_TIME_BAND_FACT_B4');
        MERGE INTO TMP_COREP_OUTSTANDING_TIME_BAND_FACT_B4 t
        USING (SELECT otb.ROWID row_id, o.outstanding_group_key
        FROM TMP_COREP_OUTSTANDING_TIME_BAND_FACT_B4 otb,dwh_outstanding o --,tmp_basel_combined_uploads cu
        WHERE o.record_valid_from = v_reporting_date --  modification corep_vpp
        AND o.system_id = v_system_id --  modification corep_vpp
        AND otb.outstanding_key = o.outstanding_key) src
        ON ( t.ROWID = src.row_id )
        WHEN MATCHED THEN UPDATE SET t.outstanding_group_key = src.outstanding_group_key;

commit;


        MERGE INTO (select pro_rata_factor,ccr_exp_value_post_crm,outstanding_group_key from  tmp_corep_recap_b4 )rm
        USING ( SELECT         otba.outstanding_group_key ,
                               SUM(otba.os_amt)  as ccr_exp_value_post_crm
                        FROM TMP_COREP_OUTSTANDING_TIME_BAND_FACT_B4 otba
                          GROUP BY otba.outstanding_group_key ) t
 on ( rm.outstanding_group_key = t.outstanding_group_key)

WHEN MATCHED THEN UPDATE SET rm.ccr_exp_value_post_crm = ROUND(t.ccr_exp_value_post_crm * rm.pro_rata_factor,2);

commit;

------------oramigcu7 end

    insert_dmb_log_corep(v_detail_level    => 103,
                                   v_log_descr       => 'process_pre_corep_recap_b4',
                                   v_activity_code   => 'otb amounts',
                                   v_result_code     => 'FINOK',
                                   v_system_id       => v_system_id,v_reporting_date       => v_reporting_date
                                  );

    insert_dmb_log_corep(v_detail_level    => 103,
                                   v_log_descr       => 'process_pre_corep_recap_b4',
                                   v_activity_code   => 'Provisions',
                                   v_result_code     => 'START',
                                   v_system_id       => v_system_id,v_reporting_date       => v_reporting_date
                                  );

    utilities.truncate_table('tmp_corep_llp_outstanding_group_b4');
    BEGIN
        SELECT date_value INTO v_switch_date
        FROM functional_parameter
        WHERE code = 'USE_IFRS_UPWARD_REP_DATE'
        AND record_valid_until IS NULL;
    EXCEPTION
        WHEN no_data_found THEN NULL;
    END;

    BEGIN
        INSERT /*+ APPEND +*/ INTO tmp_corep_llp_outstanding_group_b4 (system_id,record_valid_from,outstanding_group_id,provision_amount,provision_category)
        (SELECT  llp.system_id,llp.record_valid_from,llp.outstanding_group_id,llp.provision_amount,llp.provision_category
         FROM dwh_llp_outstanding_group llp --,tmp_basel_combined_uploads bcu
         WHERE llp.system_id = v_system_id --bcu.system_id
         AND llp.record_valid_from = v_reporting_date --bcu.reporting_date
         AND llp.configuration_code = 'LLPPIT'
         AND llp.record_valid_from < v_switch_date
         UNION ALL
         SELECT  llp.system_id,llp.record_valid_from,llp.outstanding_group_id,llp.provision_amount,
                CASE WHEN provision_category = 'IMPAIRMENT' THEN 'IMPAIRMENT'
                     ELSE CASE WHEN provision_category IN ('INDIVIDUAL','IAS37','IAS37_IND','POCI_IND') THEN 'ISFA'
                                ELSE CASE WHEN ifrs_stage = '3' THEN 'INSFA'
                                          ELSE 'IBNR'
                                     END
                          END
                END col
         FROM dwh_ifrs_outstanding_group llp
         WHERE llp.system_id = v_system_id --  modification corep_vpp
		 AND llp.record_valid_from = v_reporting_date --  modification corep_vpp
		 AND llp.record_valid_from >= v_switch_date --  modification corep_vpp
        );
    EXCEPTION
        WHEN OTHERS THEN utils.handleerror(sqlcode,sqlerrm);
    END;

    v_debug_msg := $$plsql_line|| ' of plsql unit '|| $$plsql_unit|| ' '|| systimestamp|| ' Rows Affected:- '|| SQL%rowcount;
    utilities.show_debug(v_debug_msg);
    COMMIT;
    schema_maint.gather_idx_stats('tmp_corep_llp_outstanding_group_b4');

    BEGIN --JT Query tune for performance issue
         MERGE /*+ enable_parallel_dml */ INTO (SELECT outstanding_group_id,system_id,record_valid_from,provision_category FROM tmp_corep_recap_b4) t USING
         (SELECT outstanding_group_id,system_id,record_valid_from,provision_category
          FROM tmp_corep_llp_outstanding_group_b4
         )src
        ON (t.outstanding_group_id = src.outstanding_group_id AND t.system_id = src.system_id AND t.record_valid_from = src.record_valid_from)
        WHEN MATCHED THEN UPDATE SET t.provision_category = src.provision_category;
    EXCEPTION
        WHEN OTHERS THEN utils.handleerror(sqlcode,sqlerrm);
    END;

    v_debug_msg := $$plsql_line|| ' of plsql unit '|| $$plsql_unit|| ' '|| systimestamp|| ' Rows Affected:- '|| SQL%rowcount;
    utilities.show_debug(v_debug_msg);
    COMMIT;

   ----------------------------------------------------------------------------------------------
   -- Update in_default_ind
   ----------------------------------------------------------------------------------------------

    insert_dmb_log_corep(
        v_detail_level    => 103,
        v_log_descr       => 'process_pre_corep_recap_b4',
        v_activity_code   => 'Default',
        v_result_code     => 'START',
        v_system_id       => v_system_id,v_reporting_date       => v_reporting_date
    );

    v_debug_msg := $$plsql_line|| ' of plsql unit '|| $$plsql_unit|| ' '|| systimestamp|| ' Rows Affected:- '|| SQL%rowcount;
    utilities.show_debug(v_debug_msg);
    --SEC
    BEGIN
        MERGE /*+ enable_parallel_dml +*/ INTO ( SELECT rating_key,in_default_ind,in_default_ind_original
                                                 FROM tmp_corep_recap_b4 WHERE  source_table IN ( 'SEC')  ) rm USING
        (SELECT CASE WHEN in_default = 'Y' THEN 1 ELSE 0 END AS in_default_ind, risk_rating_key
         FROM risk_rating) src
        ON ( rm.rating_key = src.risk_rating_key )
        WHEN MATCHED THEN UPDATE SET rm.in_default_ind = src.in_default_ind,
                                     rm.in_default_ind_original = src.in_default_ind;
    EXCEPTION
        WHEN OTHERS THEN utils.handleerror(sqlcode,sqlerrm);
    END;

    v_debug_msg := $$plsql_line|| ' of plsql unit '|| $$plsql_unit|| ' '|| systimestamp|| ' Rows Affected:- '|| SQL%rowcount;
    utilities.show_debug(v_debug_msg);
    COMMIT;
     --IRB  in_default_ind_original
    BEGIN
        MERGE /*+ enable_parallel_dml +*/ INTO ( SELECT rating_key,in_default_ind,in_default_ind_original
                                                 FROM tmp_corep_recap_b4 WHERE  source_table IN ('IRB')  ) rm USING
        (SELECT CASE WHEN in_default = 'Y' THEN 1 ELSE 0 END AS in_default_ind, risk_rating_key
         FROM risk_rating) src
        ON ( rm.rating_key = src.risk_rating_key )
        WHEN MATCHED THEN UPDATE SET rm.in_default_ind_original = src.in_default_ind;
    EXCEPTION
        WHEN OTHERS THEN utils.handleerror(sqlcode,sqlerrm);
    END;

    v_debug_msg := $$plsql_line|| ' of plsql unit '|| $$plsql_unit|| ' '|| systimestamp|| ' Rows Affected:- '|| SQL%rowcount;
    utilities.show_debug(v_debug_msg);
    COMMIT;
    -- IRB  in_default_ind
    BEGIN
        MERGE /*+ enable_parallel_dml +*/ INTO ( SELECT rating_applied_key,in_default_ind,in_default_ind_original
                                                 FROM tmp_corep_recap_b4 WHERE  source_table IN ('IRB','FIRB', 'SEC')  ) rm USING
        (SELECT CASE WHEN in_default = 'Y' THEN 1 ELSE 0 END AS in_default_ind, risk_rating_key
         FROM risk_rating) src
        ON ( rm.rating_applied_key = src.risk_rating_key  )
        WHEN MATCHED THEN UPDATE SET rm.in_default_ind = src.in_default_ind;
    EXCEPTION
        WHEN OTHERS THEN utils.handleerror(sqlcode,sqlerrm);
    END;

    v_debug_msg := $$plsql_line|| ' of plsql unit '|| $$plsql_unit|| ' '|| systimestamp|| ' Rows Affected:- '|| SQL%rowcount;
    utilities.show_debug(v_debug_msg);
    COMMIT;

    BEGIN
   MERGE /*+ enable_parallel_dml +*/ INTO
   (SELECT rating_applied_key,in_default_ind,in_default_ind_original,official_approach_applied,rating_guarantor
     FROM tmp_corep_recap_b4 WHERE  source_table IN ('IRB','FIRB', 'SEC') AND official_approach_applied = 'SA'  ) rm USING
   (SELECT distinct CASE WHEN in_default = 'Y' THEN 1 ELSE 0 END AS in_default_ind,code
     FROM risk_rating
     where record_valid_from <= v_reporting_date AND nvl(record_valid_until,'31-DEC-9999') > v_reporting_date) src
     ON ( rm.rating_guarantor = src.code)
    WHEN MATCHED THEN UPDATE SET rm.in_default_ind = src.in_default_ind;


    EXCEPTION
        WHEN OTHERS THEN utils.handleerror(sqlcode,sqlerrm);
    END;

    v_debug_msg := $$plsql_line|| ' of plsql unit '|| $$plsql_unit|| ' '|| systimestamp|| ' Rows Affected:- '|| SQL%rowcount;
    utilities.show_debug(v_debug_msg);
    COMMIT;


--Separating below update into two as the data from RIS has and was changed leading to unstable set of rows. STRY3681867
    BEGIN
        MERGE /*+ enable_parallel_dml */ INTO (SELECT source_table,exposure_class_applied,in_default_ind
                    FROM tmp_corep_recap_b4 WHERE source_table = 'SA')rm using
        (SELECT code,in_default_ind
         FROM basel4_exposure_class_sa
         WHERE record_valid_until IS NULL
         AND in_default_ind = 'Y') src
        ON ( rm.exposure_class_applied = src.code)
        WHEN MATCHED THEN UPDATE SET rm.in_default_ind = 1;

    END;
    COMMIT;

    BEGIN
        MERGE /*+ enable_parallel_dml */ INTO (SELECT source_table,in_default_ind_original,exposure_class
                    FROM tmp_corep_recap_b4 WHERE source_table = 'SA')rm using
        (SELECT code,in_default_ind
         FROM basel4_exposure_class_sa
         WHERE record_valid_until IS NULL
         AND in_default_ind = 'Y') src
        ON ( rm.exposure_class = src.code)
        WHEN MATCHED THEN UPDATE SET rm.in_default_ind_original = 1;
    END;
    COMMIT;

    BEGIN
        UPDATE /*+ enable_parallel_dml */ tmp_corep_recap_b4 rm
        SET rm.in_default_ind = CASE WHEN rm.in_default_ind IS NULL AND rm.source_table = 'SA' THEN 0 ELSE rm.in_default_ind END,
            rm.in_default_ind_original = CASE WHEN rm.in_default_ind_original IS NULL AND rm.source_table = 'SA' THEN 0 ELSE rm.in_default_ind_original END;
    END;
    COMMIT;

    insert_dmb_log_corep(v_detail_level    => 103,
                                   v_log_descr       => 'process_pre_corep_recap_b4',
                                   v_activity_code   => 'Default',
                                   v_result_code     => 'FINOK',
                                   v_system_id       => v_system_id,v_reporting_date       => v_reporting_date
                                   );
   ----------------------------------------------------------------------------------------------
   -- Increase correlation ind
   ----------------------------------------------------------------------------------------------

    insert_dmb_log_corep(v_detail_level    => 103,
                                   v_log_descr       => 'process_pre_corep_recap_b4',
                                   v_activity_code   => 'Incr Corr',
                                   v_result_code     => 'START',
                                   v_system_id       => v_system_id,v_reporting_date       => v_reporting_date
                                   );

    insert_dmb_log_corep(v_detail_level => 103,
                                   v_log_descr => 'process_pre_corep_recap_b4',
                                   v_activity_code => 'Incr Corr',
                                   v_result_code => 'FINOK',
                                   v_system_id       => v_system_id,v_reporting_date       => v_reporting_date) ;
   ----------------------------------------------------------------------------------------------
   -- cqs cen gov indicator
   ----------------------------------------------------------------------------------------------
   insert_dmb_log_corep(v_detail_level => 103,
                                v_log_descr => 'process_pre_corep_recap_b4',
                                v_activity_code => 'CQS cengov',
                                v_result_code => 'START',
                                v_system_id       => v_system_id,v_reporting_date       => v_reporting_date) ;

   insert_dmb_log_corep(v_detail_level => 103,
                                  v_log_descr => 'process_pre_corep_recap_b4',
                                  v_activity_code => 'CQS cengov',
                                  v_result_code => 'FINOK',
                                  v_system_id       => v_system_id,v_reporting_date       => v_reporting_date) ;
BEGIN

	MERGE /*+ enable_parallel_dml */INTO tmp_corep_recap_b4 t USING ( SELECT
            sle.SECURITISATION_LEGAL_ENTITY_KEY securitisation_key,code securitisation_code,record_valid_from,record_valid_until
             FROM
            securitisation_legal_entity sle
        )
        src ON ( t.securitisation_code IS NOT NULL
        AND   t.securitisation_code = src.securitisation_code
        AND   t.record_valid_from >= src.record_valid_from
        AND   (
                t.record_valid_from < src.record_valid_until
                OR    src.record_valid_until IS NULL ))
        WHEN MATCHED THEN UPDATE SET t.securitisation_key = src.securitisation_key;
    EXCEPTION
        WHEN OTHERS THEN
            utils.handleerror(
                sqlcode,
                sqlerrm
            );
    END;

    v_debug_msg := $$plsql_line || ' of unit ' || $$plsql_unit || ' dml count>>' || SQL%rowcount;
    utilities.show_debug(v_debug_msg);
    COMMIT;

    BEGIN
    UPDATE /*+ ENABLE_PARALLEL_DML */ tmp_corep_recap_b4
    SET securitised_factor = NVL(securitised_factor,0)
    WHERE securitisation_key IS NOT NULL;
    EXCEPTION WHEN OTHERS THEN
        RAISE;
    END;
    v_debug_msg := $$plsql_line || ' of unit ' || $$plsql_unit || ' dml count>>' || SQL%rowcount;
    utilities.show_debug(v_debug_msg);
    COMMIT;

   insert_dmb_log_corep(v_detail_level => 103,
                                  v_log_descr => 'process_pre_corep_recap_b4',
                                  v_activity_code => 'Security',
                                  v_result_code => 'START',
                                  v_system_id       => v_system_id,v_reporting_date       => v_reporting_date) ;


    BEGIN

        MERGE /*+ enable_parallel_dml */ INTO ( SELECT retained_position_ind,committed_indicator,outstanding_group_key --,sync_key_n--,securitised_ind --CP STRY2732387 changes
                     FROM tmp_corep_recap_b4 ) t
        USING (         SELECT
                        MAX(dog.retained_position_ind) retained_position_ind,
                        MAX(dog.committed_indicator) committed_indicator,
                        dog.outstanding_group_key
                        --dog.sync_key
                        --,MAX(dog.securitised_ind) securitised_ind --CP STRY2732387 changes
                    FROM
                        tmp_corep_basic_info_b4 dog
                    WHERE --(dog.record_valid_from, dog.system_id) IN  ( SELECT /*+ PRECOMPUTE_SUBQUERY */ reporting_date, system_id FROM tmp_basel_combined_uploads)
					dog.system_id = v_system_id --  modification corep_vpp
                    AND dog.record_valid_from = v_reporting_date --  modification corep_vpp
                    GROUP BY
                        dog.outstanding_group_key
                        --dog.sync_key
                )
        src ON ( t.outstanding_group_key = src.outstanding_group_key
                 --AND t.sync_key_n = src.sync_key
				 )
        WHEN MATCHED THEN UPDATE SET t.retained_position_ind = src.retained_position_ind,
                                     t.committed_indicator = src.committed_indicator;
                                     --,t.securitised_ind = src.securitised_ind; --CP STRY2732387 changes
    EXCEPTION
        WHEN OTHERS then utils.handleerror(sqlcode,sqlerrm);
    END;
    COMMIT;

    BEGIN--JT Query tune for performance issue
        MERGE/*+ enable_parallel_dml */ INTO (SELECT retained_position_ind,customer_id,record_valid_from,securitisation_key,securitised_factor
        FROM tmp_corep_recap_b4 WHERE retained_position_ind = 1) t1 USING --Retained positions
        (SELECT securitisation_grid_id, max(securitisation_legal_entity_key) securitisation_key,0 AS securitised_factor
        FROM securitisation_legal_entity WHERE record_valid_from <= V_REPORTING_DATE AND NVL(record_valid_until,utilities.record_default_date)  > V_REPORTING_DATE
        GROUP BY securitisation_grid_id) src
        ON (t1.customer_id = src.securitisation_grid_id)
        WHEN MATCHED THEN UPDATE SET t1.securitisation_key = src.securitisation_key,
                                     t1.securitised_factor = NVL(src.securitised_factor,0);
    exception
          when others then utils.handleerror(sqlcode,sqlerrm);
    end;

    v_debug_msg := $$plsql_line || ' of plsql unit ' || $$plsql_unit ||' '|| systimestamp ||' Rows Affected:- '||SQL%ROWCOUNT;
    utilities.show_debug(v_debug_msg);
    COMMIT;

    UPDATE tmp_corep_recap_b4
    SET securitised_ind = 0
    WHERE NVL(securitised_ind,0) <> 1;

	COMMIT;


	-- Position changed for sme_nl fix
	UPDATE   tmp_corep_recap_b4 rm
    SET      securitised_ind = 1
	WHERE EXISTS (  SELECT 1 FROM tmp_corep_recap_b4 crm
					WHERE rm.outstanding_group_key = crm.outstanding_group_key
					AND rm.securitisation_key IS NOT NULL
                    AND rm.retained_position_ind = 0
					);
    COMMIT;

    insert_dmb_log_corep(v_detail_level => 103,
                                   v_log_descr => 'process_pre_corep_recap_b4',
                                   v_activity_code => 'Security',
                                   v_result_code => 'FINOK',
                                   v_system_id       => v_system_id,v_reporting_date       => v_reporting_date) ;

   utilities.truncate_table('TT_TMP_COVER_CDS');
	BEGIN
		INSERT /*+ APPEND +*/ INTO TT_TMP_COVER_CDS	(cover_key, cover_type_key, cover_provider, cover_provider_key, cover_ctry_key,cover_id)
		SELECT  c.cover_key, c.cover_type_key, c.cover_provider, c.cover_provider_key, c.cover_ctry_key,c.cover_id --,c.sync_key
		FROM dwh_cover c
		WHERE c.system_id = v_system_id
		AND c.record_valid_from = v_reporting_date
		UNION
		SELECT  cd.cover_key, cd.cover_type_key, cd.cover_provider, cd.cover_provider_key, cd.cover_ctry_key,cd.cover_id --,c.sync_key
		FROM dwh_cover_cds cd
		WHERE cd.system_id = v_system_id
		AND cd.record_valid_from = v_reporting_date	;
		exception
		  when others then
		  utils.handleerror(sqlcode,sqlerrm);
      END;
	v_debug_msg                  := $$plsql_line || ' of plsql unit ' || $$plsql_unit ||' '|| systimestamp ||' Rows Affected:- '||SQL%ROWCOUNT;
	utilities.show_debug(v_debug_msg);
	COMMIT;

    BEGIN
        MERGE INTO (SELECT system_id,inscription_value,cover_id FROM tmp_corep_recap_b4 WHERE cover_id IS NOT NULL) t1 USING
        (SELECT SUM(d.cover_amt ) inscription_value,d.system_id,t.cover_id
        FROM dwh_cover_fact d , (select cover_id,cover_key from TT_TMP_COVER_CDS group by cover_id,cover_key) t
		WHERE d.record_valid_from <= V_REPORTING_DATE
		AND NVL(d.record_valid_until,utilities.record_default_date)  > V_REPORTING_DATE
        AND d.cover_key = t.cover_key
		AND d.amt_type = 'CTRB'  --'CIVB' using CTRB jst for testing on OD
        GROUP BY t.cover_id,d.system_id) src
        ON (t1.cover_id = src.cover_id AND t1.system_id = src.system_id)
        WHEN MATCHED THEN UPDATE SET t1.inscription_value = src.inscription_value;
    exception
          when others then utils.handleerror(sqlcode,sqlerrm);
    end;

	v_debug_msg := $$plsql_line || ' of plsql unit ' || $$plsql_unit ||' '|| systimestamp ||' Rows Affected:- '||SQL%ROWCOUNT;
	utilities.show_debug(v_debug_msg);
	COMMIT;

   ----------------------------------------------------------------------------------------------
   -- Record split logic - On off balance
   ----------------------------------------------------------------------------------------------
   insert_dmb_log_corep(v_detail_level => 103,
                                v_log_descr => 'process_pre_corep_recap_b4',
                                v_activity_code => 'Split1',
                                v_result_code => 'START',
                                v_system_id       => v_system_id,v_reporting_date       => v_reporting_date) ;


BEGIN
   INSERT /*+ APPEND */  INTO tmp_corep_recap_factor_b4
     ( record_id,
on_balance_ind,
conversion_ratio,
conversion_ratio_exposure,
conversion_ratio_fin_coll,
conversion_ratio_on_balance,
conversion_ratio_off_balance,
securitised_factor,
securitised_ind,
risk_weight_substitution,
conversion_ratio_exposure_lr,
ucc_non_trans_conversion_ratio_exposure,
conversion_ratio_exp_pre_ccf,
unsecuritised_factor)
     (SELECT  record_id ,
              1 ,
              on_balance_ratio ,
              on_balance_ratio_exposure ,
              on_balance_ratio_fin_coll ,
              CASE WHEN rp.on_balance_ratio = 0 THEN 0 ELSE 1 END,
              0 ,
              securitised_factor ,
              securitised_ind ,
              risk_weight_substitution ,
              lr_on_balance_ratio_exposure,
              ucc_non_trans_on_balance_ratio_exposure,
              on_balance_ratio_exp_pre_ccf,
			  unsecuritised_factor
      FROM tmp_corep_recap_b4 rp
      WHERE  rp.on_balance_ratio > 0 -- Rows that have an on-balance part.
      UNION
      SELECT record_id ,
              0 ,
              1 - on_balance_ratio ,
              1 - on_balance_ratio_exposure ,
              1 - on_balance_ratio_fin_coll ,
              1 - (CASE WHEN rp.on_balance_ratio = 0 THEN 0 ELSE 1 END),
              1 ,
              securitised_factor ,
              securitised_ind ,
              risk_weight_substitution ,
              1 - lr_on_balance_ratio_exposure,
              1 - ucc_non_trans_on_balance_ratio_exposure,
              1 - on_balance_ratio_exp_pre_ccf,
			  unsecuritised_factor
      FROM tmp_corep_recap_b4 rp
     WHERE  (rp.on_balance_ratio < 1 OR rp.lr_on_balance_ratio < 1) -- Rows that have an off-balance part.
	  --WHERE  (rp.on_balance_ratio < 1 OR rp.lr_on_balance_ratio < 1 OR rp.on_balance_ratio_exp_pre_ccf<1)
      UNION ALL
      SELECT record_id ,
              0 ,
              0 ,
              0 ,
              0 ,
              0 ,
              1 ,
              securitised_factor ,
              securitised_ind ,
              risk_weight_substitution ,
              0,
              0,
              1 - on_balance_ratio_exp_pre_ccf --on_balance_ratio_exp_pre_ccf
			  ,unsecuritised_factor
      FROM tmp_corep_recap_b4 rp
      WHERE  rp.on_balance_ratio = 1 -- Rows that have only on-balance part, but off balance figures
      AND rp.lr_on_balance_ratio = 1
      AND (rp.exposure_original_undrawn > 0 OR rp.exposure_pre_ccf_undrawn > 0 ) );
exception
      when others then utils.handleerror(sqlcode,sqlerrm);
      end;

      v_debug_msg := $$plsql_line || ' of plsql unit ' || $$plsql_unit ||' '|| systimestamp ||' Rows Affected:- '||SQL%ROWCOUNT;
      utilities.show_debug(v_debug_msg);
      COMMIT;

   insert_dmb_log_corep(v_detail_level => 103,
                                  v_log_descr => 'process_pre_corep_recap_b4',
                                  v_activity_code => 'Split1',
                                  v_result_code => 'FINOK',
                                  v_system_id       => v_system_id,v_reporting_date       => v_reporting_date) ;
   ----------------------------------------------------------------------------------------------
   -- Record split logic - Securitisations
   ----------------------------------------------------------------------------------------------
   insert_dmb_log_corep(v_detail_level => 103,
                                v_log_descr => 'process_pre_corep_recap_b4',
                                v_activity_code => 'Split2',
                                v_result_code => 'START',
                                v_system_id       => v_system_id,v_reporting_date       => v_reporting_date) ;
   BEGIN
   INSERT /*+ APPEND */ INTO tmp_corep_recap_factor_b4
     ( record_id, on_balance_ind, conversion_ratio, conversion_ratio_exposure, conversion_ratio_fin_coll, conversion_ratio_off_balance, conversion_ratio_on_balance, securitised_factor, securitised_ind, risk_weight_substitution, conversion_ratio_exposure_lr,ucc_non_trans_conversion_ratio_exposure,conversion_ratio_exp_pre_ccf,unsecuritised_factor )
     ( SELECT  record_id ,
              on_balance_ind ,
              round(conversion_ratio * unsecuritised_factor, 8) ,
              round(conversion_ratio_exposure * unsecuritised_factor, 8) ,
              round(conversion_ratio_fin_coll * unsecuritised_factor, 8) ,
              round(conversion_ratio_off_balance * unsecuritised_factor, 8) ,
              round(conversion_ratio_on_balance * unsecuritised_factor, 8) ,
              round(unsecuritised_factor, 8) ,
              0 ,
              risk_weight_substitution ,
              round(conversion_ratio_exposure_lr * unsecuritised_factor, 8),
              round(ucc_non_trans_conversion_ratio_exposure * unsecuritised_factor, 8),
              round(conversion_ratio_exp_pre_ccf * unsecuritised_factor, 8),
			  unsecuritised_factor
       FROM tmp_corep_recap_factor_b4 rp
        WHERE  securitised_factor IS NOT NULL
                 AND securitised_ind = 1 );
exception
      when others then
      utils.handleerror(sqlcode,sqlerrm);
      end;
v_debug_msg                  := $$plsql_line || ' of plsql unit ' || $$plsql_unit ||' '|| systimestamp ||' Rows Affected:- '||SQL%ROWCOUNT;
utilities.show_debug(v_debug_msg);
COMMIT;
   UPDATE /*+ enable_parallel_dml */ tmp_corep_recap_factor_b4
      SET conversion_ratio = round(conversion_ratio * securitised_factor, 8),
          conversion_ratio_exposure = round(conversion_ratio_exposure * securitised_factor, 8),
          conversion_ratio_fin_coll = round(conversion_ratio_fin_coll * securitised_factor, 8),
          conversion_ratio_off_balance = round(conversion_ratio_off_balance * securitised_factor, 8),
          conversion_ratio_on_balance = round(conversion_ratio_on_balance * securitised_factor, 8),
          conversion_ratio_exposure_lr = round(conversion_ratio_exposure_lr * securitised_factor, 8),
          ucc_non_trans_conversion_ratio_exposure = round(ucc_non_trans_conversion_ratio_exposure * securitised_factor, 8),
          conversion_ratio_exp_pre_ccf = round(conversion_ratio_exp_pre_ccf * securitised_factor, 8)
    WHERE  securitised_factor IS NOT NULL
     AND securitised_ind = 1;
COMMIT;
--   UPDATE /*+ enable_parallel_dml */ tmp_corep_recap_factor_b4
--      SET securitised_factor = 1
--    WHERE  securitised_factor = 0;
--COMMIT;
   insert_dmb_log_corep(v_detail_level => 103,
                                v_log_descr => 'process_pre_corep_recap_b4',
                                v_activity_code => 'Split2',
                                v_result_code => 'FINOK',
                                v_system_id       => v_system_id,v_reporting_date       => v_reporting_date) ;
   ----------------------------------------------------------------------------------------------
   -- Record split logic - Original / Applied
   ----------------------------------------------------------------------------------------------
   insert_dmb_log_corep(v_detail_level => 103,
                                v_log_descr => 'process_pre_corep_recap_b4',
                                v_activity_code => 'Split3',
                                v_result_code => 'START',
                                v_system_id       => v_system_id,v_reporting_date       => v_reporting_date) ;
   UPDATE /*+ enable_parallel_dml */ tmp_corep_recap_factor_b4
      SET original_ind = 1,
          applied_ind = CASE
                             WHEN NVL(risk_weight_substitution, 0) = 1 THEN 0
          ELSE 1
             END;
v_debug_msg                  := $$plsql_line || ' of plsql unit ' || $$plsql_unit ||' '|| systimestamp ||' Rows Affected:- '||SQL%ROWCOUNT;
utilities.show_debug(v_debug_msg);
COMMIT;
   -- Add applied records
   INSERT /*+ APPEND +*/ INTO tmp_corep_recap_factor_b4
     ( record_id, on_balance_ind, conversion_ratio, conversion_ratio_exposure, conversion_ratio_fin_coll, conversion_ratio_off_balance, conversion_ratio_on_balance, securitised_factor, securitised_ind,
     risk_weight_substitution, conversion_ratio_exposure_lr, original_ind, applied_ind,ucc_non_trans_conversion_ratio_exposure,conversion_ratio_exp_pre_ccf,unsecuritised_factor )
     ( SELECT  record_id ,
              on_balance_ind ,
              conversion_ratio ,
              conversion_ratio_exposure ,
              conversion_ratio_fin_coll ,
              conversion_ratio_off_balance ,
              conversion_ratio_on_balance ,
              securitised_factor ,
              securitised_ind ,
              risk_weight_substitution ,
              conversion_ratio_exposure_lr ,
              0 ,
              1,
              ucc_non_trans_conversion_ratio_exposure,
              conversion_ratio_exp_pre_ccf,
			  unsecuritised_factor
       FROM tmp_corep_recap_factor_b4
        WHERE  risk_weight_substitution = 1 );
v_debug_msg := $$plsql_line || ' of plsql unit ' || $$plsql_unit ||' '|| systimestamp ||' Rows Affected:- '||SQL%ROWCOUNT;
utilities.show_debug(v_debug_msg);
COMMIT;

   schema_maint.gather_idx_stats('tmp_corep_recap_factor_b4');

   insert_dmb_log_corep(v_detail_level => 103,
                                v_log_descr => 'process_pre_corep_recap_b4',
                                v_activity_code => 'Split3',
                                v_result_code => 'FINOK',
                                v_system_id       => v_system_id,v_reporting_date       => v_reporting_date) ;


 --Position of insert statement changed due to logic of  double_default_classification used in below insert
       utilities.truncate_table('TMP_COREP_VRE_COVER_RECAP_B4');
BEGIN
    INSERT /*+ APPEND +*/ INTO TMP_COREP_VRE_COVER_RECAP_B4 (system_id,record_valid_from,outstanding_group_key,cover_key,fx_haircut,
                                                          discount_factor_cover,configuration_code,double_default_classification,
                                                          country_key, alloc_available_amount_after_hc)
    (SELECT c.system_id,c.record_valid_from,c.outstanding_group_key,c.cover_key,c.fx_haircut,c.discount_factor_cover,
       c.configuration_code,c.double_default_classification,dc.cover_ctry_key, c.alloc_available_amount_after_hc
     FROM dwh_vre_cover_recapb4 c,dwh_cover dc
     WHERE c.record_valid_from = v_reporting_date AND c.system_id = v_system_id
     AND c.cover_key = dc.cover_key(+) AND dc.system_id(+) = v_system_id AND dc.record_valid_from(+) = v_reporting_date--  modification corep_vpp
     );
EXCEPTION
    WHEN OTHERS THEN utils.handleerror(sqlcode,sqlerrm);
END;

v_debug_msg := $$plsql_line|| ' of plsql unit '|| $$plsql_unit|| ' '|| systimestamp|| ' Rows Affected:- '|| SQL%rowcount;
utilities.show_debug(v_debug_msg);
COMMIT;

schema_maint.gather_idx_stats('TMP_COREP_VRE_COVER_RECAP_B4');

BEGIN
    MERGE /*+ ENABLE_PARALLEL_DML +*/ INTO tmp_corep_recap_b4 t1 USING
    (SELECT 1 official_challenger_indicator, t.ROWID row_id
    FROM tmp_corep_basic_info_b4 b, tmp_corep_recap_b4 t
    WHERE b.outstanding_group_key = t.outstanding_group_key
    AND (t.official_approach_indicator = 1 or exists(select 1 from corep_model_reporting where b.ead_model_code = ead_challenger_model_code
                                                 and t.basel_approach = challenger_basel_approach
                                                 and EFF_DT <= v_reporting_date
                                                 and (END_DT > v_reporting_date or END_DT is null)))
    and not exists(select 1 from corep_model_reporting where b.ead_model_code = ead_challenger_model_code
                                                 and t.basel_approach <> challenger_basel_approach and challenger_basel_approach is not null
                                                 and EFF_DT <= v_reporting_date
                                                 and (END_DT > v_reporting_date or END_DT is null))) src
   ON ( t1.ROWID = src.row_id)
   WHEN MATCHED THEN UPDATE SET t1.official_challenger_indicator = src.official_challenger_indicator;

EXCEPTION
    WHEN OTHERS THEN utils.handleerror(sqlcode,sqlerrm);
END;

v_debug_msg := $$plsql_line || ' of plsql unit ' || $$plsql_unit ||' '|| systimestamp ||' Rows Affected:- '||SQL%ROWCOUNT;
utilities.show_debug(v_debug_msg);
COMMIT;


 update tmp_corep_recap_b4
 set OFFICIAL_CHALLENGER_INDICATOR =nvl(OFFICIAL_CHALLENGER_INDICATOR ,0);
  commit;
   ----------------------------------------------------------------------------------------------
   --  INSERT
   ----------------------------------------------------------------------------------------------
   insert_dmb_log_corep(v_detail_level => 103,
                                v_log_descr => 'process_pre_corep_recap_b4',
                                v_activity_code => 'Insert tmp',
                                v_result_code => 'START',
                                v_system_id       => v_system_id,v_reporting_date       => v_reporting_date) ;
   utilities.truncate_table('tt_tmp_corep_recap_measure_b4');

BEGIN
   INSERT /*+ APPEND +*/ INTO tt_tmp_corep_recap_measure_b4 (
		ALLOCATED_LIMIT_AMT,
		ALLOCATED_OUTSTANDING_AMT,
	    exposure_class	,
		cover_id	,
		capital_requirement	,
		expected_loss	,
		exposure_at_default	,
		loss_given_default	,
		outstanding_group_id	,
		outstanding_group_key	,
		pd	,
		alloc_provision_amt	,
		risk_weighted_assets	,
		risk_weight_factor	,
		rating_key	,
		exposure_original	,
		exposure_original_drawn	,
		exposure_pre_ccf	,
		exposure_pre_ccf_drawn	,
		conversion_ratio	,
		basel_approach	,
		original_cover_value	,
		g_factor	,
		k_factor	,
		regulator	,
		on_balance_ind	,
		credit_quality_step	,
		residual_value_amount	,
		residual_value_capital_req	,
		residual_value_risk_weight	,
		record_valid_from	,
		system_id	,
		credit_conversion_factor	,
		risk_weight_substitution	,
		conversion_ratio_exposure	,
		conversion_ratio_fin_coll	,
		conversion_ratio_on_balance	,
		fully_adjusted_exposure_on_sa	,
		fully_adjusted_exposure_off_sa	,
		financial_collateral_sa	,
		exposure_net_provision_sa	,
		volatility_maturity_adj	,
		ccf_0percent	,
		ccf_20percent	,
		ccf_50percent	,
		ccf_100percent	,
		conversion_ratio_off_balance	,
		retained_position_ind	,
		securitisation_key	,
		securitised_ind	,
		exposure_original_undrawn	,
		exposure_pre_ccf_undrawn	,
		source_table	,
		original_ind	,
		applied_ind	,
		customer_key	,
		customer_id	,
		effective_maturity	,
		facility_id	,
		outstanding_id	,
		outstanding_key	,
		official_approach_indicator	,
		basel2_official_approach	,
		sec_category	,
		large_or_unregulated_fin_entity_ind	,
		h_factor	,
		cure_rate	,
		unsecured_discount_factor	,
		facility_key	,
		committed_indicator	,
		after_coll_regulatory_os_amt	,
		gross_regulatory_os_amt	,
		regulatory_os_amt	,
		old_regulatory_os_amt 	,
		ccp_counterparty_indicator	,
		in_default_ind	,
		pro_rata_factor	,
		risk_weight_asset_original	,
		residual_value_risk_weight_asset	,
		source	,
		inflow	,
		fully_adjusted_exposure	,
		sec_rating_approach	,
		cqs_cen_gov_ind	,
		on_balance_ratio	,
		on_balance_ratio_exposure	,
		on_balance_ratio_collateral_sa	,
		on_balance_ratio_fin_coll	,
		securitised_factor	,
		provision_category	,
		exposure_class_sa_not_def_sec	,
		risk_weight_asset_pre_sme_fact	,
		subject_to_sme_factor_ind	,
		exposure_class_sa_not_def	,
		lr_on_balance_ratio	,
		lr_on_balance_ratio_exposure	,
		conversion_ratio_exposure_lr	,
		lr_k_factor	,
		lr_g_factor	,
		lre_amount	,
		lre_on_balance	,
		lre_off_balance_before_ccf	,
		lre_off_balance_after_ccf	,
		LR_CCF_10PERCENT	,
		LR_CCF_20PERCENT	,
        LR_CCF_40PERCENT,
		LR_CCF_50PERCENT	,
		LR_CCF_100PERCENT	,
		effective_regulated_indicator	,
		netted_indicator	,
		off_supp_credit_indicator	,
		notional_amount	,
		mtm_amount	,
		add_on	,
		correlation_factor	,
		in_default_ind_original	,
		sme_ind	,
		risk_weight_add_on_factor	,
		risk_weight_add_on_term	,
		risk_weight_factor_original	,
		basel_local_official_approach	,
		gross_carrying_amt	,
		residual_maturity_months	,
		residual_maturity_bucket_code	,
		ifrs_accounting_classification	,
		ifrs_measurement_category	,
		rwa_including_addon	,
		rwa_pre_sme_including_addon	,
		rwa_add_on_report_classification	,
		sts_indicator	,
		sec_calculation_method	,
		sts_qualif_diff_treatment_ind	,
		capital_requirement_c_09_04  	,
		exposure_at_default_c_09_04   	,
		zero_rrw_sov_indicator 	,
		strict_prudential_rw_ind 	,
		strict_lgd_floor_ind	,
		rwa_pre_sme_fact_ex_add_on	,
		exposure_weighted_avg_lgd	,
		k_a_parameter_w	,
		k_irb	,
		k_sa	,
		ppu_sa_ind	,
		rwa_ex_strict_prud	,
		subject_to_infra_factor_ind	,
		risk_weight_asset_pre_infra_fact	,
		rwa_sme_support_amt	,
        rwa_ex_add_on,
		lgd_pre_cds	,
		pd_original_after_multipliers	,
		ccr_variation_margin  	,
		ccr_net_indep_collat_amt	,
		ccr_replacement_cost	,
		ccr_addon	,
		ccr_potential_future_exp	,
		ccr_exp_value_pre_crm	,
		ccr_exp_value_post_crm 	,
		lre_ccr_variation_margin	,
		lre_ccr_replacement_cost	,
		exposure_class_original	,
		exposure_class_applied	,
		exposure_amount 	,
		cover_key 	,
		cover_type_key 	,
		cover_provider_id 	,
		cover_provider_key 	,
		cover_ctry_key 	,
		cover_ctry_code 	,
		finrep_sector 	,
		large_exposure_sector	,
		leverage_sme_ind 	,
		reporting_date	,
		risk_weight_asset_orig_obligor	,
		risk_weight_asset_sec_erba 	,
		risk_weight_asset_sec_sa 	,
		exposure_at_default_abs 	,
		original_cover_value_abs	,
		residual_value_amount_abs 	,
		outflow	,
		lgd_model_code 	,
		substitution_method 	,
		rw_substitution_method 	,
		--rw_floor 	,
		official_approach_applied 	,
		risk_weighted_assets_pre_cds,
		direct_cost,
		indirect_cost,
		SECURED_RECOVERY_AMOUNTS,
		SECURED_RECOVERY_AMOUNTS_DISCOUNTED	,
		UNSECURED_RECOVERY_AMOUNTS,
		UNSECURED_RECOVERY_AMOUNTS_DISCOUNTED,
		CREDIT_QUALITY_STEP_SEC,
		rating_agency_key,
        external_rating,
        risk_weight_asset_sec_tr,
        risk_weighted_assets_due_dill,
        risk_weighted_assets_sec_mat_mism,
        rwa_infra_support_amt,
        ead_exclusion_ind,
		configuration_code,
        condition_outcome_code,
        ccf_10percent ,
        ccf_40percent,
        COVER_SPLIT_KEY,
        property_ratio_from,
        property_ratio_until,
        EAD_RATIO,
        COLLATERALISATION_RATIO,
        rwa_pre_infra_fct_ex_strict_prud,
        rwa_pre_sme_fact_ex_strict_prud,
        risk_weight_excl_strict_prud,
        exposure_class_irb_in_sa,
        exposure_class_sa_in_irb,
        res_imm_prop_ind,
        com_imm_prop_ind,
        regulatory_large_corp_ind,
		ccf_ucc_transitional,
        rwa_non_ccf_ucc_trans ,
        SPLIT_RATIO,
        ucc_non_trans_on_balance_ratio_exposure,
        ucc_non_trans_conversion_ratio_exposure,
        basel_approach_original,
		guar_ppu_sa_ind,
		ccf_100percent_irb,
		regulatory_ead_applied,
		risk_weight_factor_macro_prud,--New column added AB 5033337
        rwa_pre_sme_fact_macro_prud,--New column added AB 5033337
        rwa_pre_infra_fact_macro_prud,--New column added AB 5033337
        rwa_macro_prud, --New column added AB 5033337
        exposure_class_sa_original,
        risk_weight_asset_pre_fx_mm,
		risk_weight_factor_pre_fx_mm,
        conversion_ratio_exp_pre_ccf,
		loan_split_derogation_ind,
        risk_weight_art378,
		exposure_amount_art378,
		rwa_art378,
		book_risk_category,
		settlement_date,
		days_unsettled_after_due_date,
		settlement_amount,
        securitisation_code,
        unsecuritised_factor,
		sec_pro_rata_factor,
		official_challenger_indicator,
        on_balance_ratio_exp_pre_ccf,
		modelled_ccf,
		inscription_value
    )
      SELECT
        CASE WHEN f.original_ind = 1 THEN round(vbia.allocated_limit_amt * f.conversion_ratio, 2) END allocated_limit_amt,
		CASE WHEN f.original_ind = 1 THEN round(vbia.allocated_outstanding_amt * f.conversion_ratio, 2) END allocated_outstanding_amt,
        CASE WHEN f.original_ind = 1 THEN vbia.exposure_class ELSE vbia.exposure_class_applied END 	exposure_class	,
		vbia.cover_id	cover_id	,
		CASE WHEN f.applied_ind = 1 THEN round(vbia.capital_requirement * f.conversion_ratio, 2) END	capital_requirement	,
		CASE WHEN f.applied_ind = 1 THEN round(vbia.expected_loss * f.conversion_ratio, 2) END	expected_loss	,
		CASE WHEN f.applied_ind = 1 THEN round(vbia.exposure_at_default * f.conversion_ratio, 4) END	exposure_at_default	,
		CASE WHEN f.applied_ind = 1 THEN vbia.loss_given_default ELSE lgd_unsecured END 	loss_given_default	,
		vbia.outstanding_group_id	outstanding_group_id	,
		vbia.outstanding_group_key	outstanding_group_key	,
		CASE WHEN f.applied_ind = 1 THEN vbia.pd_applied ELSE vbia.pd_original_after_multipliers END	pd	,
		CASE WHEN f.original_ind = 1 THEN round(vbia.alloc_provision_amt * f.conversion_ratio, 2) END	alloc_provision_amt	,
		CASE WHEN f.applied_ind = 1 THEN round(vbia.risk_weighted_assets * f.conversion_ratio, 4) END	risk_weighted_assets	,
		CASE WHEN f.applied_ind = 1 THEN vbia.risk_weight_factor ELSE vbia.risk_weight_factor_original END	risk_weight_factor	,
		CASE WHEN f.original_ind = 1 THEN vbia.rating_key ELSE vbia.rating_applied_key END 	rating_key	,
		CASE WHEN f.original_ind = 1 THEN round(vbia.exposure_original * f.conversion_ratio, 2) END	exposure_original	,
		CASE WHEN f.original_ind = 1 THEN round(vbia.exposure_original_drawn * f.conversion_ratio_on_balance, 2) END	exposure_original_drawn	,
		--CASE WHEN f.original_ind = 1 THEN round(vbia.exposure_pre_ccf * f.conversion_ratio, 2) END	exposure_pre_ccf	,
        --CASE WHEN f.original_ind = 1 THEN round(vbia.exposure_pre_ccf * f.conversion_ratio_exp_pre_ccf, 2) END	exposure_pre_ccf	,
        NULL exposure_pre_ccf,
		CASE WHEN f.original_ind = 1 THEN round(vbia.exposure_pre_ccf_drawn * f.conversion_ratio_on_balance, 2) END	exposure_pre_ccf_drawn	,
		f.conversion_ratio	conversion_ratio	,
		CASE WHEN f.original_ind = 1 THEN vbia.basel_approach ELSE official_approach_applied END AS	basel_approach	,
		--CASE WHEN f.original_ind = 1 THEN round(vbia.original_cover_value * f.conversion_ratio, 2) END	original_cover_value	,
--        CASE WHEN f.original_ind = 1 AND vbia.risk_weight_substitution <> 1 THEN round(vbia.original_cover_value * f.conversion_ratio, 2)
--             WHEN f.original_ind = 1 AND vbia.risk_weight_substitution = 1 THEN round(vbia.original_cover_value * f.conversion_ratio_exp_pre_ccf, 2)
--        END	original_cover_value	,
        NULL original_cover_value,
		CASE WHEN f.applied_ind = 1 THEN vbia.g_factor END	g_factor	,
		CASE WHEN f.applied_ind = 1 THEN vbia.k_factor END	k_factor	,
		vbia.regulator	regulator	,
		f.on_balance_ind	on_balance_ind	,
		CASE WHEN f.original_ind = 1 THEN vbia.credit_quality_step ELSE vbia.credit_quality_step_sa_applied END	credit_quality_step	,
		CASE WHEN f.applied_ind = 1 THEN round(vbia.residual_value_amount * f.conversion_ratio, 2) END	residual_value_amount	,
		CASE WHEN f.applied_ind = 1 THEN round(vbia.residual_value_capital_req * f.conversion_ratio, 2) END	residual_value_capital_req	,
		CASE WHEN f.applied_ind = 1 THEN vbia.residual_value_risk_weight END	residual_value_risk_weight	,
		vbia.record_valid_from	record_valid_from	,
		vbia.system_id	system_id	,
		vbia.credit_conversion_factor	credit_conversion_factor	,
		vbia.risk_weight_substitution	,
		NULL	conversion_ratio_exposure	,
		NULL	conversion_ratio_fin_coll	,
		f.conversion_ratio_on_balance	conversion_ratio_on_balance	,
		NULL	fully_adjusted_exposure_on_sa	,
		NULL	fully_adjusted_exposure_off_sa	,
		NULL	financial_collateral_sa	,
		NULL	exposure_net_provision_sa	,
		NULL	volatility_maturity_adj	,
		CASE WHEN f.applied_ind = 1 THEN round(vbia.ccf_0percent * f.conversion_ratio_off_balance, 4) END 	ccf_0percent	,
		CASE WHEN f.applied_ind = 1 THEN round(vbia.ccf_20percent * f.conversion_ratio_off_balance, 4) END 	ccf_20percent	,
		CASE WHEN f.applied_ind = 1 THEN round(vbia.ccf_50percent * f.conversion_ratio_off_balance, 4) END 	ccf_50percent	,
		CASE WHEN f.applied_ind = 1 THEN round(vbia.ccf_100percent * f.conversion_ratio_off_balance, 4) END ccf_100percent	,
		f.conversion_ratio_off_balance	conversion_ratio_off_balance	,
		vbia.retained_position_ind	retained_position_ind	,
		vbia.securitisation_key	securitisation_key	,
		f.securitised_ind	securitised_ind	,
		CASE WHEN f.original_ind = 1 THEN round(vbia.exposure_original_undrawn * f.conversion_ratio_off_balance, 2) END	exposure_original_undrawn	,
		CASE WHEN f.original_ind = 1 THEN round(vbia.exposure_pre_ccf_undrawn * f.conversion_ratio_off_balance, 2) END	exposure_pre_ccf_undrawn	,
		vbia.source_table	source_table	,
		f.original_ind	original_ind	,
		f.applied_ind	applied_ind	,
		vbia.customer_key	customer_key	,
		vbia.customer_id	customer_id	,
		vbia.effective_maturity	effective_maturity	,
		vbia.facility_id	facility_id	,
		vbia.outstanding_id	outstanding_id	,
		vbia.outstanding_key	outstanding_key	,
		vbia.official_approach_indicator	official_approach_indicator	,
		vbia.basel2_official_approach	basel2_official_approach	,
		vbia.sec_category	sec_category	,
		CASE WHEN vbia.increase_correlation_ind = 'Y' THEN 1 ELSE 0 END large_or_unregulated_fin_entity_ind	,
		vbia.h_factor	h_factor	,
		vbia.cure_rate	cure_rate	,
		vbia.unsecured_discount_factor	unsecured_discount_factor	,
		vbia.facility_key	facility_key	,
		committed_indicator	committed_indicator	,
		CASE WHEN f.original_ind = 1 THEN round(vbia.after_coll_regulatory_os_amt * f.conversion_ratio_on_balance, 2) END	after_coll_regulatory_os_amt	,
		CASE WHEN f.original_ind = 1 THEN round(vbia.gross_regulatory_os_amt * f.conversion_ratio_on_balance, 2) END	gross_regulatory_os_amt	,
		CASE WHEN f.original_ind = 1 THEN round(vbia.regulatory_os_amt * f.conversion_ratio_on_balance, 2) END	regulatory_os_amt	,
		CASE WHEN f.original_ind = 1 THEN ROUND(vbia.old_regulatory_os_amt * f.conversion_ratio_on_balance,2) END	 old_regulatory_os_amt 	,
		vbia.ccp_counterparty_indicator	ccp_counterparty_indicator	,
		vbia.in_default_ind	in_default_ind	,
		vbia.pro_rata_factor	pro_rata_factor	,
		case when f.applied_ind = 1 THEN round(vbia.risk_weight_asset_original * f.conversion_ratio, 2) END	risk_weight_asset_original	,
		case when f.applied_ind = 1 THEN ROUND(vbia.residual_value_risk_weight_asset * f.conversion_ratio,2) END	residual_value_risk_weight_asset	,
		'B'	source	,
		--case when f.applied_ind = 1 and vbia.risk_weight_substitution=1 THEN ROUND(vbia.exposure_pre_ccf * f.conversion_ratio,2) END	inflow	,
        NULL inflow,
		case when f.applied_ind = 1 and vbia.risk_weight_substitution=1 THEN ROUND(vbia.exposure_at_default * f.conversion_ratio,2) END	fully_adjusted_exposure	,
		--NULL	external_rating	,
		vbia.sec_rating_approach	sec_rating_approach	,
		NULL	cqs_cen_gov_ind	,
		vbia.on_balance_ratio	on_balance_ratio	,
		vbia.on_balance_ratio_exposure	on_balance_ratio_exposure	,
		vbia.on_balance_ratio_collateral_sa	on_balance_ratio_collateral_sa	,
		vbia.on_balance_ratio_fin_coll	on_balance_ratio_fin_coll	,
		f.securitised_factor	securitised_factor	,
		vbia.provision_category	provision_category	,
		NULL	exposure_class_sa_not_def_sec	,
		case when f.applied_ind = 1 THEN round(vbia.risk_weight_asset_pre_sme_fact * f.conversion_ratio, 4) END	risk_weight_asset_pre_sme_fact	,
		vbia.subject_to_sme_factor_ind	subject_to_sme_factor_ind	,
		NULL	exposure_class_sa_not_def	,
		vbia.lr_on_balance_ratio	lr_on_balance_ratio	,
		vbia.lr_on_balance_ratio_exposure	lr_on_balance_ratio_exposure	,
		f.conversion_ratio_exposure_lr	conversion_ratio_exposure_lr	,
		vbia.lr_k_factor	lr_k_factor	,
		vbia.lr_g_factor	lr_g_factor	,
		case when f.original_ind = 1 THEN round(vbia.lre_amount * f.conversion_ratio_exposure_lr, 2) END	lre_amount	,
		case when f.original_ind = 1 THEN round(vbia.lre_on_balance * f.conversion_ratio_on_balance, 2) END	lre_on_balance	,
		case when f.original_ind = 1 THEN round(vbia.lre_off_balance_before_ccf * f.conversion_ratio_off_balance, 2) END	lre_off_balance_before_ccf	,
		case when f.original_ind = 1 THEN round(vbia.lre_off_balance_after_ccf * f.conversion_ratio_off_balance, 2) END	lre_off_balance_after_ccf	,
		case when f.original_ind = 1 THEN round(vbia.LR_CCF_10PERCENT * f.conversion_ratio_off_balance, 2) END	LR_CCF_10PERCENT	,
		case when f.original_ind = 1 THEN round(vbia.LR_CCF_20PERCENT * f.conversion_ratio_off_balance, 2) END	LR_CCF_20PERCENT	,
        case when f.original_ind = 1 THEN round(vbia.LR_CCF_40PERCENT * f.conversion_ratio_off_balance, 2) END	LR_CCF_40PERCENT	,
		case when f.original_ind = 1 THEN round(vbia.LR_CCF_50PERCENT * f.conversion_ratio_off_balance, 2) END	LR_CCF_50PERCENT	,
		case when f.original_ind = 1 THEN round(vbia.LR_CCF_100PERCENT * f.conversion_ratio_off_balance, 2) END	LR_CCF_100PERCENT	,
		vbia.effective_regulated_indicator	effective_regulated_indicator	,
		vbia.netted_indicator	netted_indicator	,
		vbia.off_supp_credit_indicator	off_supp_credit_indicator	,
		case when f.applied_ind = 1 THEN round(vbia.notional_amount * f.conversion_ratio_on_balance, 2) END	notional_amount	,
		case when f.applied_ind = 1 THEN round(vbia.mtm_amount * f.conversion_ratio_on_balance, 2) END	mtm_amount	,
		case when f.applied_ind = 1 THEN round(vbia.add_on * f.conversion_ratio_on_balance, 2) END	add_on	,
		vbia.correlation_factor	correlation_factor	,
		vbia.in_default_ind_original	in_default_ind_original	,
		vbia.sme_ind	sme_ind	,
		vbia.risk_weight_add_on_factor	risk_weight_add_on_factor	,
		vbia.risk_weight_add_on_term	risk_weight_add_on_term	,
		vbia.risk_weight_factor_original	risk_weight_factor_original	,
		vbia.basel_local_official_approach	basel_local_official_approach	,
		NULL	gross_carrying_amt	,
		vbia.remaining_maturity_in_months	residual_maturity_months	,
		vbia.residual_maturity_bucket_code	residual_maturity_bucket_code	,
		NULL	ifrs_accounting_classification	,
		NULL 	ifrs_measurement_category	,
		case when f.applied_ind = 1 THEN ROUND(vbia.rwa_including_addon  * f.conversion_ratio,4) END	rwa_including_addon	,
		case when f.applied_ind = 1 THEN ROUND(vbia.rwa_pre_sme_including_addon  * f.conversion_ratio,4) END	rwa_pre_sme_including_addon	,
		vbia.rwa_add_on_report_classification	rwa_add_on_report_classification	,
		vbia.sts_indicator 	sts_indicator	,
		vbia.sec_calculation_method	sec_calculation_method	,
		vbia.sts_qualif_diff_treatment_ind	sts_qualif_diff_treatment_ind	,
		case when f.original_ind = 1 THEN ROUND(vbia.capital_requirement* f.conversion_ratio,2) ELSE 0 END 	capital_requirement_c_09_04  	,
		case when f.original_ind = 1 THEN ROUND(vbia.exposure_at_default* f.conversion_ratio,4) ELSE 0 END 	exposure_at_default_c_09_04   	,
		vbia.zero_rrw_sov_indicator  	zero_rrw_sov_indicator 	,
		vbia.strict_prudential_rw_ind     	strict_prudential_rw_ind 	,
		vbia.strict_lgd_floor_ind	strict_lgd_floor_ind	,
		case when f.applied_ind = 1 THEN ROUND(vbia.rwa_pre_sme_fact_ex_add_on * f.conversion_ratio, 4) END	rwa_pre_sme_fact_ex_add_on	,
		NULL 	exposure_weighted_avg_lgd	,
		NULL 	k_a_parameter_w	,
		NULL 	k_irb	,
		NULL 	k_sa	,
		0	ppu_sa_ind	,
		CASE WHEN f.applied_ind = 1 THEN ROUND(vbia.rwa_ex_strict_prud  * f.conversion_ratio,4) END	rwa_ex_strict_prud	,
		vbia.subject_to_infra_factor_ind 	subject_to_infra_factor_ind	,
		CASE WHEN f.applied_ind = 1 THEN ROUND(vbia.risk_weight_asset_pre_infra_fact * f.conversion_ratio, 4) END	risk_weight_asset_pre_infra_fact	,
		CASE WHEN f.applied_ind = 1 THEN ROUND(vbia.rwa_sme_support_amt  * f.conversion_ratio, 4) END	rwa_sme_support_amt	,
        case when f.applied_ind = 1 THEN ROUND(vbia.rwa_ex_add_on * f.conversion_ratio, 4) END  rwa_ex_add_on,
		vbia.lgd_pre_cds	lgd_pre_cds	,
		vbia.pd_original_after_multipliers	pd_original_after_multipliers	,
		case when f.original_ind = 1 THEN ROUND(vbia.ccr_variation_margin * f.conversion_ratio_on_balance,2) END 	ccr_variation_margin  	,
		case when f.original_ind = 1 THEN ROUND(vbia.ccr_net_indep_collat_amt * f.conversion_ratio_on_balance,2) END 	ccr_net_indep_collat_amt	,
		case when f.original_ind = 1 THEN ROUND(vbia.ccr_replacement_cost * f.conversion_ratio_on_balance,2) END 	ccr_replacement_cost	,
		case when f.original_ind = 1 THEN ROUND(vbia.ccr_addon * f.conversion_ratio_on_balance,2) END 	ccr_addon	,
		case when f.original_ind = 1 THEN ROUND(vbia.ccr_potential_future_exp * f.conversion_ratio_on_balance,2) END 	ccr_potential_future_exp	,
		case when f.original_ind = 1 THEN ROUND(vbia.ccr_exp_value_pre_crm * f.conversion_ratio_on_balance,2) END 	ccr_exp_value_pre_crm	,
		case when f.original_ind = 1 THEN ROUND(vbia.ccr_exp_value_post_crm * f.conversion_ratio_on_balance,2) END 	ccr_exp_value_post_crm 	,
		case when f.original_ind = 1 THEN ROUND(vbia.lre_ccr_variation_margin * f.conversion_ratio_on_balance,2) END 	lre_ccr_variation_margin	,
		case when f.original_ind = 1 THEN ROUND(vbia.lre_ccr_replacement_cost * f.conversion_ratio_on_balance,2) END 	lre_ccr_replacement_cost	,
		vbia.exposure_class	exposure_class_original	,
		vbia.exposure_class_applied	exposure_class_applied	,
		case when f.original_ind = 1 THEN ROUND(vbia.allocated_limit_amt * f.conversion_ratio,2)  END	exposure_amount 	,
		src.cover_key	cover_key 	,
		src.cover_type_key	cover_type_key 	,
		src.cover_provider	cover_provider_id 	,
		src.cover_provider_key	cover_provider_key 	,
		src.cover_ctry_key	cover_ctry_key 	,
		dc.country_code	cover_ctry_code 	,
		diog.finrep_sector	finrep_sector 	,
		diog.le_sector	large_exposure_sector	,
		vbia.leverage_sme_ind	leverage_sme_ind 	,
		v_reporting_date	reporting_date	,
		NULL	risk_weight_asset_orig_obligor	,
		vbia.risk_weight_asset_sec_erba 	risk_weight_asset_sec_erba 	,
		vbia.risk_weight_asset_sec_sa    	risk_weight_asset_sec_sa 	,
		abs(CASE WHEN f.applied_ind = 1 THEN round(vbia.exposure_at_default * f.conversion_ratio, 4) END)	exposure_at_default_abs 	,
		abs(CASE WHEN f.original_ind = 1 THEN round(vbia.original_cover_value * f.conversion_ratio, 2) END) 	original_cover_value_abs	,
		abs(CASE WHEN f.applied_ind = 1 THEN round(vbia.residual_value_amount * f.conversion_ratio, 2) END) 	residual_value_amount_abs 	,
		--case when f.original_ind = 1 and vbia.risk_weight_substitution = 1 and vbia.source_table = 'IRB' THEN ROUND(vbia.exposure_pre_ccf * f.conversion_ratio,2) END 	outflow	,
        NULL outflow,
		vbia.LGD_MODEL_CODE 	lgd_model_code 	,
		vbia.substitution_method 	substitution_method 	,
		vbia.rw_substitution_method 	rw_substitution_method 	,
		--vbia.rw_floor 	rw_floor 	, direct_cost
		vbia.official_approach_applied 	official_approach_applied 	,
		CASE WHEN f.original_ind = 1 AND vbia.basel_approach IN ('AIRB_OFFIC','AIRB','FIRB') THEN ROUND(( CASE WHEN c.double_default_classification = 'B' THEN vbia.risk_weighted_assets ELSE vbia.risk_weighted_assets * ( nvl(vbia.lgd_pre_cds,0) / CASE WHEN  vbia.loss_given_default IS NULL THEN 1 WHEN  vbia.loss_given_default = 0 THEN 1 ELSE  vbia.loss_given_default  END ) END ) * f.conversion_ratio, 4) END	risk_weighted_assets_pre_cds,
        case when f.applied_ind = 1 THEN ROUND(vbia.direct_cost * f.conversion_ratio,2) END direct_cost,
        case when f.applied_ind = 1 THEN round(vbia.indirect_cost * f.conversion_ratio, 2) END indirect_cost,
        case when f.applied_ind = 1 THEN round(vbia.secured_recovery_amounts * f.conversion_ratio, 2) END secured_recovery_amounts,
        case when f.applied_ind = 1 THEN round(vbia.secured_recovery_amounts_discounted * f.conversion_ratio, 2) END secured_recovery_amounts_discounted,
        case when f.applied_ind = 1 THEN round(vbia.unsecured_recovery_amounts * f.conversion_ratio, 2) END unsecured_recovery_amounts,
        case when f.applied_ind = 1 THEN round(vbia.unsecured_recovery_amounts_discounted * f.conversion_ratio, 2) END unsecured_recovery_amounts_discounted,
		CREDIT_QUALITY_STEP_SEC,
	    NULL rating_agency_key,
        NULL external_rating,
        NULL risk_weight_asset_sec_tr,
        NULL risk_weighted_assets_due_dill,
        NULL risk_weighted_assets_sec_mat_mism,
        CASE WHEN f.applied_ind = 1 THEN ROUND(vbia.rwa_infra_support_amt * f.conversion_ratio, 4) END rwa_infra_support_amt,
        vbia.ead_exclusion_ind,
		NULL configuration_code,
        NULL condition_outcome_code,
        CASE WHEN f.applied_ind = 1 THEN round(vbia.ccf_10percent * f.conversion_ratio_off_balance, 4) END ccf_10percent,
        CASE WHEN f.applied_ind = 1 THEN round(vbia.ccf_40percent * f.conversion_ratio_off_balance, 4) END ccf_40percent,
        -- ccf_10percent ,
        -- ccf_40percent,
        NULL COVER_SPLIT_KEY,
        NULL property_ratio_from,
        NULL property_ratio_until,
        NULL EAD_RATIO,
        NULL COLLATERALISATION_RATIO,
        NULL rwa_pre_infra_fct_ex_strict_prud,
        NULL rwa_pre_sme_fact_ex_strict_prud,
        NULL risk_weight_excl_strict_prud,
        NULL exposure_class_irb_in_sa,
        vbia.exposure_class_sa_in_irb,
        vbia.res_imm_prop_ind,
        vbia.com_imm_prop_ind,
        vbia.regulatory_large_corp_ind,
		NULL ccf_ucc_transitional 	,
		NULL rwa_non_ccf_ucc_trans ,
        NULL SPLIT_RATIO,
        NULL ucc_non_trans_on_balance_ratio_exposure,
        NULL ucc_non_trans_conversion_ratio_exposure,
		vbia.basel_approach basel_approach_original,
		vbia.guar_ppu_sa_ind,
        CASE WHEN f.applied_ind = 1 THEN round(vbia.ccf_100percent_irb * f.conversion_ratio_off_balance, 4) END ccf_100percent_irb,
		vbia.regulatory_ead_applied,
	    vbia.risk_weight_factor_macro_prud,-- New column added AB STRY3055404
		CASE WHEN f.applied_ind = 1 THEN round(vbia.rwa_pre_sme_fact_macro_prud * f.conversion_ratio,4) END AS rwa_pre_sme_fact_macro_prud, --New column added AB 5033337
		CASE WHEN f.applied_ind = 1 THEN round(vbia.rwa_pre_infra_fact_macro_prud * f.conversion_ratio,4) END AS rwa_pre_infra_fact_macro_prud, --New column added  AB STRY3055404
		CASE WHEN f.applied_ind = 1 THEN round(vbia.rwa_macro_prud * f.conversion_ratio,4) END AS rwa_macro_prud, --New column added  AB STRY3055404
        vbia.exposure_class_sa_original,
        CASE WHEN f.applied_ind = 1 THEN round(vbia.risk_weight_asset_pre_fx_mm * f.conversion_ratio ,4) END AS risk_weight_asset_pre_fx_mm,
		case when f.original_ind = 0 THEN vbia.risk_weight_factor
		     WHEN f.original_ind = 1 THEN vbia.risk_weight_factor_original  END   risk_weight_factor_pre_fx_mm,
         f.conversion_ratio_exp_pre_ccf conversion_ratio_exp_pre_ccf,
		 NULL loan_split_derogation_ind,
        NULL risk_weight_art378,
		NULL exposure_amount_art378,
		NULL	rwa_art378,
        NULL	book_risk_category,
		NULL	settlement_date ,
		NULL    days_unsettled_after_due_date,
		NULL    settlement_amount,
		vbia.securitisation_code,
--        CASE WHEN applied_ind =1 and rm.on_balance_sheet_ind = 0 and rm.regulatory_ead_applied=0 then round((vbia.exposure_pre_ccf_drawn * f.conversion_ratio_on_balance) + (vbia.exposure_pre_ccf_undrawn * f.conversion_ratio_off_balance),2)
--             WHEN applied_ind =1 and rm.on_balance_sheet_ind = 1 and rm.on_balance_ind = 0 and regulatory_ead_applied=0 then round(vbia.exposure_pre_ccf_undrawn * f.conversion_ratio_off_balance, 2)
--        END
        f.unsecuritised_factor,
		vbia.sec_pro_rata_factor,
        vbia.official_challenger_indicator,
		f.conversion_ratio_exp_pre_ccf ON_BALANCE_RATIO_EXP_PRE_CCF,
		CASE WHEN f.applied_ind = 1 then round((vbia.ccf_modelled_amount  * f.conversion_ratio_on_balance),4) END modelled_ccf,
		CASE WHEN f.original_ind = 1 THEN round(vbia.inscription_value * f.conversion_ratio ,4) END AS  inscription_value
      FROM tmp_corep_recap_b4 vbia
      INNER JOIN tmp_corep_recap_factor_b4 f ON (vbia.record_id = f.record_id AND vbia.source_table = 'IRB')
      LEFT OUTER JOIN TT_TMP_COVER_CDS src ON (vbia.cover_id = src.cover_id)
      LEFT OUTER JOIN (SELECT  code country_code,country_key FROM country)dc ON(src.cover_ctry_key = dc.country_key)
      LEFT OUTER JOIN dwh_incap_outstanding_group diog
	  ON (diog.outstanding_group_key = vbia.outstanding_group_key AND diog.configuration_code = 'INCAPTTCDT'
	  AND   diog.system_id = v_system_id
	  AND diog.record_valid_from = v_reporting_date
	  )
      LEFT OUTER JOIN TMP_COREP_VRE_COVER_RECAP_B4 c     ON nvl(c.cover_key,' ') = nvl(src.cover_key,' ') AND c.outstanding_group_key = vbia.outstanding_group_key
                                                         AND vbia.basel_approach_original = decode(c.configuration_code,'RECAP4AIRO','AIRB_OFFIC','RECAP4AIRB','AIRB','RECAP4SA','SA','RECAP4FIRB','FIRB','RECAP4SATR','SA_TR')
    UNION ALL
	  SELECT CASE WHEN f.original_ind = 1 THEN round(vbia.allocated_limit_amt * f.conversion_ratio, 2) END allocated_limit_amt ,
       CASE WHEN f.original_ind = 1 THEN round(vbia.allocated_outstanding_amt * f.conversion_ratio_on_balance, 2) END allocated_outstanding_amt,
       CASE WHEN f.original_ind = 1 THEN vbia.exposure_class ELSE vbia.exposure_class_applied END exposure_class	,
	    vbia.cover_id 	cover_id	,
		CASE  WHEN f.applied_ind = 1 THEN round(vbia.capital_requirement * f.conversion_ratio_exposure, 2)
              --WHEN f.applied_ind = 1 AND f.conversion_ratio_exposure = nvl(vbia.split_ratio,1)  THEN round(vbia.capital_requirement, 2)
              --WHEN f.applied_ind = 1 and vbia.split_ratio is not null THEN round(vbia.capital_requirement , 2)
        END capital_requirement	,
		NULL 	expected_loss	,
		CASE WHEN f.applied_ind = 1 THEN round(vbia.exposure_at_default * f.conversion_ratio_exposure, 4)
             --WHEN f.applied_ind = 1 and vbia.split_ratio is not null THEN round(vbia.exposure_at_default, 4)
        END exposure_at_default	,
		NULL 	loss_given_default	,
		vbia.outstanding_group_id 	outstanding_group_id	,
		vbia.outstanding_group_key 	outstanding_group_key	,
		NULL 	pd	,
		CASE WHEN f.original_ind = 1 THEN round(vbia.alloc_provision_amt * f.conversion_ratio, 2) END 	alloc_provision_amt	,
		CASE WHEN f.applied_ind = 1 THEN round(vbia.risk_weighted_assets * f.conversion_ratio_exposure, 4)
             --WHEN f.applied_ind = 1 and vbia.split_ratio is not null THEN round(vbia.risk_weighted_assets, 4)
        END risk_weighted_assets	,
		--CASE WHEN f.applied_ind = 1 THEN vbia.risk_weight_factor ELSE vbia.risk_weight_factor_original END	risk_weight_factor	,
        CASE WHEN f.original_ind = 1 THEN vbia.risk_weight_factor_original ELSE vbia.risk_weight_factor END	risk_weight_factor	,
		CASE WHEN f.original_ind = 1 THEN vbia.rating_key ELSE vbia.rating_applied_key END 	rating_key	,
		CASE WHEN f.original_ind = 1 THEN round(vbia.exposure_original * f.conversion_ratio, 2) END exposure_original	,
		CASE WHEN f.original_ind = 1 THEN round(vbia.exposure_original_drawn * f.conversion_ratio_on_balance, 2) END exposure_original_drawn	,
		CASE WHEN f.original_ind = 1 THEN round(vbia.exposure_pre_ccf * f.conversion_ratio, 2) END 	exposure_pre_ccf	,
		CASE WHEN f.original_ind = 1 THEN round(vbia.exposure_pre_ccf_drawn * f.conversion_ratio_on_balance, 2) END 	exposure_pre_ccf_drawn	,
		f.conversion_ratio 	conversion_ratio	,
		vbia.basel_approach 	basel_approach	,
		CASE WHEN f.original_ind = 1 THEN round(vbia.original_cover_value * f.conversion_ratio, 2) END 	original_cover_value	,
		CASE WHEN f.applied_ind = 1 THEN vbia.g_factor   END 	g_factor	,
		CASE WHEN f.applied_ind = 1 THEN vbia.k_factor   END 	k_factor	,
		vbia.regulator 	regulator	,
		f.on_balance_ind 	on_balance_ind	,
		CASE WHEN f.original_ind = 1 THEN vbia.credit_quality_step ELSE vbia.credit_quality_step_applied END 	credit_quality_step	,
		CASE WHEN f.applied_ind = 1 THEN round(vbia.residual_value_amount * f.conversion_ratio, 2) END 	residual_value_amount	,
		CASE WHEN f.applied_ind = 1 THEN round(vbia.residual_value_capital_req * f.conversion_ratio, 2) END 	residual_value_capital_req	,
		CASE WHEN f.applied_ind = 1 THEN vbia.residual_value_risk_weight END residual_value_risk_weight	,
		vbia.record_valid_from 	record_valid_from	,
		vbia.system_id 	system_id	,
		CASE WHEN f.applied_ind = 1 THEN vbia.credit_conversion_factor   END 	credit_conversion_factor	,
		vbia.risk_weight_substitution 	risk_weight_substitution	,
		f.conversion_ratio_exposure 	conversion_ratio_exposure	,
		f.conversion_ratio_fin_coll 	conversion_ratio_fin_coll	,
		f.conversion_ratio_on_balance 	conversion_ratio_on_balance	,
		CASE WHEN f.applied_ind = 1 THEN round(vbia.fully_adjusted_exposure_on_sa * f.conversion_ratio_on_balance, 4) END 	fully_adjusted_exposure_on_sa	,
		CASE WHEN f.applied_ind = 1 THEN round(vbia.fully_adjusted_exposure_off_sa * f.conversion_ratio_off_balance, 4) END 	fully_adjusted_exposure_off_sa	,
		CASE WHEN f.applied_ind = 1 THEN round(vbia.financial_collateral_sa * f.conversion_ratio_fin_coll, 2) END 	financial_collateral_sa	,
		CASE WHEN f.original_ind = 1 THEN round(vbia.exposure_net_provision_sa * f.conversion_ratio, 2) END exposure_net_provision_sa	,
		CASE WHEN f.applied_ind = 1 THEN round(vbia.volatility_maturity_adj * f.conversion_ratio_fin_coll, 2) END 	volatility_maturity_adj	,
		CASE WHEN f.applied_ind = 1 THEN round(vbia.ccf_0percent * f.conversion_ratio_off_balance, 4) END 	ccf_0percent	,
		CASE WHEN f.applied_ind = 1 THEN round(vbia.ccf_20percent * f.conversion_ratio_off_balance, 4) END 	ccf_20percent	,
		CASE WHEN f.applied_ind = 1 THEN round(vbia.ccf_50percent * f.conversion_ratio_off_balance, 4) END 	ccf_50percent	,
		CASE WHEN f.applied_ind = 1 THEN round(vbia.ccf_100percent * f.conversion_ratio_off_balance, 4) END ccf_100percent	,
		f.conversion_ratio_off_balance 	conversion_ratio_off_balance	,
		vbia.retained_position_ind 	retained_position_ind	,
		vbia.securitisation_key 	securitisation_key	,
		f.securitised_ind 	securitised_ind	,
		CASE WHEN f.original_ind = 1 THEN round(vbia.exposure_original_undrawn * f.conversion_ratio_off_balance, 2) END exposure_original_undrawn	,
		CASE WHEN f.original_ind = 1 THEN round(vbia.exposure_pre_ccf_undrawn * f.conversion_ratio_off_balance, 2) END 	exposure_pre_ccf_undrawn	,
		vbia.source_table 	source_table	,
		f.original_ind 	original_ind	,
		f.applied_ind 	applied_ind	,
		vbia.customer_key 	customer_key	,
		vbia.customer_id 	customer_id	,
		vbia.effective_maturity 	effective_maturity	,
		vbia.facility_id 	facility_id	,
		vbia.outstanding_id 	outstanding_id	,
		vbia.outstanding_key 	outstanding_key	,
		vbia.official_approach_indicator 	official_approach_indicator	,
		vbia.basel2_official_approach 	basel2_official_approach	,
		vbia.sec_category 	sec_category	,
		NULL 	large_or_unregulated_fin_entity_ind	,
		CASE WHEN f.original_ind = 1 THEN vbia.h_factor END 	h_factor	,
		NULL 	cure_rate	,
		NULL 	unsecured_discount_factor	,
		vbia.facility_key 	facility_key	,
		committed_indicator 	committed_indicator	,
		CASE WHEN f.original_ind = 1 THEN round(vbia.after_coll_regulatory_os_amt * f.conversion_ratio_on_balance, 2) END 	after_coll_regulatory_os_amt	,
		CASE WHEN f.original_ind = 1 THEN round(vbia.gross_regulatory_os_amt * f.conversion_ratio_on_balance, 2) END 	gross_regulatory_os_amt	,
		CASE WHEN f.original_ind = 1 THEN round(vbia.regulatory_os_amt * f.conversion_ratio_on_balance, 2) END 	regulatory_os_amt	,
		CASE WHEN f.original_ind = 1 THEN ROUND(vbia.old_regulatory_os_amt * f.conversion_ratio_on_balance,2) END 	 old_regulatory_os_amt 	,
		vbia.ccp_counterparty_indicator 	ccp_counterparty_indicator	,
		vbia.in_default_ind 	in_default_ind	,
		vbia.pro_rata_factor 	pro_rata_factor	,
		CASE WHEN f.applied_ind = 1 THEN round(vbia.risk_weight_asset_original * f.conversion_ratio_exposure, 2)
             --WHEN f.applied_ind = 1 and vbia.split_ratio is not NULL THEN round(vbia.risk_weight_asset_original, 2)
        END risk_weight_asset_original	,
		vbia.residual_value_risk_weight_asset 	residual_value_risk_weight_asset	,
		'B' 	source	,
		CASE WHEN f.applied_ind = 1 AND vbia.risk_weight_substitution = 1 THEN round(vbia.exposure_net_provision_sa * f.conversion_ratio, 2) END 	inflow	,
		NULL 	fully_adjusted_exposure	,
		vbia.sec_rating_approach 	sec_rating_approach	,
		vbia.cqs_cen_gov_ind 	cqs_cen_gov_ind	,
		vbia.on_balance_ratio 	on_balance_ratio	,
		vbia.on_balance_ratio_exposure 	on_balance_ratio_exposure	,
		vbia.on_balance_ratio_collateral_sa 	on_balance_ratio_collateral_sa	,
		vbia.on_balance_ratio_fin_coll 	on_balance_ratio_fin_coll	,
		f.securitised_factor 	securitised_factor	,
		vbia.provision_category 	provision_category	,
		exposure_class_sa_not_def_sec 	exposure_class_sa_not_def_sec	,
		CASE WHEN f.applied_ind = 1 THEN round(vbia.risk_weight_asset_pre_sme_fact * f.conversion_ratio_exposure, 4)
        END risk_weight_asset_pre_sme_fact	,
		vbia.subject_to_sme_factor_ind 	subject_to_sme_factor_ind	,
		vbia.exposure_class_sa_not_def 	exposure_class_sa_not_def	,
		vbia.lr_on_balance_ratio 	lr_on_balance_ratio	,
		vbia.lr_on_balance_ratio_exposure 	lr_on_balance_ratio_exposure	,
		f.conversion_ratio_exposure_lr 	conversion_ratio_exposure_lr	,
		vbia.lr_k_factor 	lr_k_factor	,
		vbia.lr_g_factor 	lr_g_factor	,
		CASE WHEN f.original_ind = 1 THEN round(vbia.lre_amount * f.conversion_ratio_exposure_lr, 2) END 	lre_amount	,
		CASE WHEN f.original_ind = 1 THEN round(vbia.lre_on_balance * f.conversion_ratio_on_balance, 2) END 	lre_on_balance	,
		CASE WHEN f.original_ind = 1 THEN round(vbia.lre_off_balance_before_ccf * f.conversion_ratio_off_balance, 2) END 	lre_off_balance_before_ccf	,
		CASE WHEN f.original_ind = 1 THEN round(vbia.lre_off_balance_after_ccf * f.conversion_ratio_off_balance, 2) END 	lre_off_balance_after_ccf	,
		CASE WHEN f.original_ind = 1 THEN round(vbia.LR_CCF_10PERCENT * f.conversion_ratio_off_balance, 2) END 	LR_CCF_10PERCENT	,
		CASE WHEN f.original_ind = 1 THEN round(vbia.LR_CCF_20PERCENT * f.conversion_ratio_off_balance, 2) END 	LR_CCF_20PERCENT	,
        CASE WHEN f.original_ind = 1 THEN round(vbia.LR_CCF_40PERCENT * f.conversion_ratio_off_balance, 2) END 	LR_CCF_40PERCENT	,
		CASE WHEN f.original_ind = 1 THEN round(vbia.LR_CCF_50PERCENT * f.conversion_ratio_off_balance, 2) END 	LR_CCF_50PERCENT	,
		CASE WHEN f.original_ind = 1 THEN round(vbia.LR_CCF_100PERCENT * f.conversion_ratio_off_balance, 2) END 	LR_CCF_100PERCENT	,
		vbia.effective_regulated_indicator 	effective_regulated_indicator	,
		vbia.netted_indicator 	netted_indicator	,
		vbia.off_supp_credit_indicator 	off_supp_credit_indicator	,
		CASE WHEN f.applied_ind = 1 THEN round(vbia.notional_amount * f.conversion_ratio_on_balance, 2) END 	notional_amount	,
		CASE WHEN f.applied_ind = 1 THEN round(vbia.mtm_amount * f.conversion_ratio_on_balance, 2) END 	mtm_amount	,
		CASE WHEN f.applied_ind = 1 THEN round(vbia.add_on * f.conversion_ratio_on_balance, 2)   END 	add_on	,
		NULL 	correlation_factor	,
		vbia.in_default_ind_original 	in_default_ind_original	,
		vbia.sme_ind 	sme_ind	,
		vbia.risk_weight_add_on_factor 	risk_weight_add_on_factor	,
		vbia.risk_weight_add_on_term 	risk_weight_add_on_term	,
		vbia.risk_weight_factor_original 	risk_weight_factor_original	,
		vbia.basel_local_official_approach 	basel_local_official_approach	,
		NULL	gross_carrying_amt	,
		vbia.remaining_maturity_in_months 	residual_maturity_months	,
		vbia.residual_maturity_bucket_code 	residual_maturity_bucket_code	,
		NULL 	ifrs_accounting_classification	,
		NULL  	ifrs_measurement_category	,
		CASE WHEN f.applied_ind = 1 THEN ROUND(vbia.rwa_including_addon  * f.conversion_ratio_exposure,4)
             --WHEN f.applied_ind = 1 and vbia.split_ratio is not NULL THEN ROUND(vbia.rwa_including_addon,4)
        END rwa_including_addon	,
		CASE WHEN f.applied_ind = 1 THEN ROUND(vbia.rwa_pre_sme_including_addon  * f.conversion_ratio_exposure,4)
             --WHEN f.applied_ind = 1 and vbia.split_ratio is not NULL THEN ROUND(vbia.rwa_pre_sme_including_addon,4)
        END rwa_pre_sme_including_addon	,
		vbia.rwa_add_on_report_classification	rwa_add_on_report_classification	,
		vbia.sts_indicator	sts_indicator	,
		vbia.sec_calculation_method	sec_calculation_method	,
		vbia.sts_qualif_diff_treatment_ind	sts_qualif_diff_treatment_ind	,
		CASE WHEN f.original_ind = 1 THEN round(vbia.capital_requirement* f.conversion_ratio_exposure,2)
             --WHEN f.original_ind = 1 and vbia.split_ratio is not NULL THEN round(vbia.capital_requirement,2)
             ELSE 0
        END capital_requirement_c_09_04  	,
		CASE WHEN  f.original_ind = 1 THEN round(vbia.exposure_at_default* f.conversion_ratio_exposure,4)
             --WHEN  f.original_ind = 1 and vbia.split_ratio is not NULL THEN round(vbia.exposure_at_default,4)
             ELSE 0
        END exposure_at_default_c_09_04   	,
		vbia.zero_rrw_sov_indicator	zero_rrw_sov_indicator 	,
		vbia.strict_prudential_rw_ind 	strict_prudential_rw_ind 	,
		vbia.strict_lgd_floor_ind	strict_lgd_floor_ind	,
		CASE WHEN f.applied_ind = 1 THEN round(round(vbia.rwa_pre_sme_fact_ex_add_on * f.conversion_ratio_exposure,4) * nvl(split_ratio,1),4)
             --WHEN f.applied_ind = 1 and vbia.split_ratio is not NULL THEN round(vbia.rwa_pre_sme_fact_ex_add_on,4)
        END rwa_pre_sme_fact_ex_add_on	,
		NULL 	exposure_weighted_avg_lgd	,
		NULL 	k_a_parameter_w	,
		NULL 	k_irb	,
		NULL 	k_sa	,
		vbia.ppu_sa_ind	ppu_sa_ind	,
		case when f.applied_ind = 1 THEN ROUND(vbia.rwa_ex_strict_prud  * f.conversion_ratio_exposure,4) END	rwa_ex_strict_prud	,
        --CASE WHEN f.applied_ind = 1 THEN round(vbia.rwa_ex_strict_prud * f.conversion_ratio, 2) END 	rwa_ex_strict_prud	,
		vbia.subject_to_infra_factor_ind	subject_to_infra_factor_ind	,
		case when f.applied_ind = 1 THEN ROUND(vbia.risk_weight_asset_pre_infra_fact * f.conversion_ratio_exposure, 4)
             --when f.applied_ind = 1 and vbia.split_ratio is not NULL THEN ROUND(vbia.risk_weight_asset_pre_infra_fact , 4)
        END risk_weight_asset_pre_infra_fact	,
		case when f.applied_ind = 1 THEN ROUND(vbia.rwa_sme_support_amt  * f.conversion_ratio_exposure, 4)
             --when f.applied_ind = 1 and vbia.split_ratio is not NULL THEN ROUND(vbia.rwa_sme_support_amt, 4)
        END rwa_sme_support_amt	,
        CASE WHEN f.applied_ind = 1 THEN ROUND(vbia.rwa_ex_add_on * f.conversion_ratio_exposure,4)
             --WHEN f.applied_ind = 1 and vbia.split_ratio is not NULL THEN ROUND(vbia.rwa_ex_add_on,4)
             ELSE NULL
        END rwa_ex_add_on,
		NULL	lgd_pre_cds	,
		vbia.pd_original_after_multipliers	pd_original_after_multipliers	,
		case when f.original_ind = 1 THEN ROUND(vbia.ccr_variation_margin        * f.conversion_ratio_on_balance,2) END	ccr_variation_margin  	,
		case when f.original_ind = 1 THEN ROUND(vbia.ccr_net_indep_collat_amt        * f.conversion_ratio_on_balance,2) END	ccr_net_indep_collat_amt	,
		case when f.original_ind = 1 THEN ROUND(vbia.ccr_replacement_cost        * f.conversion_ratio_on_balance,2) END	ccr_replacement_cost	,
		case when f.original_ind = 1 THEN ROUND(vbia.ccr_addon        * f.conversion_ratio_on_balance,2) END	ccr_addon	,
		case when f.original_ind = 1 THEN ROUND(vbia.ccr_potential_future_exp        * f.conversion_ratio_on_balance,2) END	ccr_potential_future_exp	,
		case when f.original_ind = 1 THEN ROUND(vbia.ccr_exp_value_pre_crm        * f.conversion_ratio_on_balance,2) END	ccr_exp_value_pre_crm	,
		case when f.original_ind = 1 THEN ROUND(vbia.ccr_exp_value_post_crm        * f.conversion_ratio_on_balance,2) END	ccr_exp_value_post_crm 	,
		case when f.original_ind = 1 THEN ROUND(vbia.lre_ccr_variation_margin        * f.conversion_ratio_on_balance,2) END	lre_ccr_variation_margin	,
		case when f.original_ind = 1 THEN ROUND(vbia.lre_ccr_replacement_cost        * f.conversion_ratio_on_balance,2) END	lre_ccr_replacement_cost	,
		vbia.exposure_class	exposure_class_original	,
		vbia.exposure_class_applied	exposure_class_applied	,
		(CASE WHEN committed_indicator = 'C' THEN (CASE WHEN f.original_ind = 1 THEN round(vbia.exposure_original * f.conversion_ratio, 2) END)
		ELSE (CASE WHEN f.original_ind = 1 THEN round(vbia.allocated_outstanding_amt * f.conversion_ratio_on_balance, 2)   END ) END)	exposure_amount 	,
		src.cover_key 	cover_key 	,
		src.cover_type_key 	cover_type_key 	,
		src.cover_provider 	cover_provider_id 	,
		src.cover_provider_key 	cover_provider_key 	,
		src.cover_ctry_key 	cover_ctry_key 	,
		dc.country_code	cover_ctry_code 	,
		diog.finrep_sector	finrep_sector 	,
		diog.le_sector 	large_exposure_sector	,
		vbia.leverage_sme_ind 	leverage_sme_ind 	,
		v_reporting_date	reporting_date	,
		NULL risk_weight_asset_orig_obligor	,
		vbia.risk_weight_asset_sec_erba	risk_weight_asset_sec_erba 	,
		vbia.risk_weight_asset_sec_sa  	risk_weight_asset_sec_sa 	,
		NULL 	exposure_at_default_abs 	,
		NULL 	original_cover_value_abs	,
		NULL 	residual_value_amount_abs 	,
		NULL 	outflow	,
		NULL 	lgd_model_code 	,
		NULL 	substitution_method 	,
		NULL 	rw_substitution_method 	,
		--NULL 	rw_floor 	,
		NULL 	official_approach_applied 	,
		NULL  	risk_weighted_assets_pre_cds
		,vbia.direct_cost
		,vbia.indirect_cost,
		SECURED_RECOVERY_AMOUNTS,
		SECURED_RECOVERY_AMOUNTS_DISCOUNTED	,
		UNSECURED_RECOVERY_AMOUNTS,
		UNSECURED_RECOVERY_AMOUNTS_DISCOUNTED,
		CREDIT_QUALITY_STEP_SEC,
		CASE WHEN f.original_ind = 1 THEN vbia.rating_agency_original_key ELSE vbia.rating_agency_applied_key END rating_agency_key,
        CASE WHEN f.original_ind = 1 THEN vbia.external_rating_original ELSE vbia.external_rating_applied END external_rating,
		NULL risk_weight_asset_sec_tr,
        NULL risk_weighted_assets_due_dill,
        NULL risk_weighted_assets_sec_mat_mism,
        case when f.applied_ind = 1 THEN ROUND(vbia.rwa_infra_support_amt * f.conversion_ratio_exposure, 4)
             --when f.applied_ind = 1 and vbia.split_ratio is not NULL THEN ROUND(vbia.rwa_infra_support_amt, 4)
        END rwa_infra_support_amt,
        vbia.ead_exclusion_ind,
        NULL configuration_code,
        vbia.condition_outcome_code,
        CASE WHEN f.applied_ind = 1 THEN round(vbia.ccf_10percent * f.conversion_ratio_off_balance, 4) END 	ccf_10percent,
		CASE WHEN f.applied_ind = 1 THEN round(vbia.ccf_40percent * f.conversion_ratio_off_balance, 4) END 	ccf_40percent,
        vbia.COVER_SPLIT_KEY,
        vbia.property_ratio_from property_ratio_from,
        vbia.property_ratio_until property_ratio_until,
        vbia.EAD_RATIO,
        vbia.COLLATERALISATION_RATIO,
        CASE WHEN f.applied_ind = 1 THEN round(vbia.rwa_pre_infra_fct_ex_strict_prud * f.CONVERSION_RATIO_EXPOSURE, 2) END 	rwa_pre_infra_fct_ex_strict_prud	,
        CASE WHEN f.applied_ind = 1 THEN round(vbia.rwa_pre_sme_fact_ex_strict_prud * f.CONVERSION_RATIO_EXPOSURE, 2) END 	rwa_pre_sme_fact_ex_strict_prud	,
        vbia.risk_weight_excl_strict_prud   risk_weight_excl_strict_prud,
        vbia.exposure_class_irb_in_sa  exposure_class_irb_in_sa,
        NULL exposure_class_sa_in_irb,
        NULL res_imm_prop_ind,
        NULL com_imm_prop_ind,
        NULL regulatory_large_corp_ind,
		case when f.applied_ind = 1 THEN ROUND(vbia.ccf_ucc_transitional  * f.conversion_ratio_off_balance,4) END ccf_ucc_transitional 	,
		case when f.applied_ind = 1 THEN ROUND(vbia.rwa_non_ccf_ucc_trans  * f.ucc_non_trans_conversion_ratio_exposure,4) END rwa_non_ccf_ucc_trans ,
        vbia.SPLIT_RATIO SPLIT_RATIO,
        ucc_non_trans_on_balance_ratio_exposure ucc_non_trans_on_balance_ratio_exposure,
        f.ucc_non_trans_conversion_ratio_exposure,
		vbia.basel_approach basel_approach_original,
		NULL guar_ppu_sa_ind,
		NULL ccf_100percent_irb,
		NULL regulatory_ead_applied,
		NULL  risk_weight_factor_macro_prud,--New column added AB 5033337
        NULL  rwa_pre_sme_fact_macro_prud,--New column added AB 5033337
        NULL  rwa_pre_infra_fact_macro_prud,--New column added AB 5033337
        NULL  rwa_macro_prud, --New column added AB 5033337
        vbia.exposure_class_sa_original,
        case when f.applied_ind = 1 THEN round(vbia.risk_weight_asset_pre_fx_mm * f.conversion_ratio_exposure, 4) END	risk_weight_asset_pre_fx_mm	,
		case when f.original_ind = 0 THEN vbia.risk_weight_factor_pre_fx_mm
		     WHEN f.original_ind = 1 THEN vbia.risk_weight_factor_original  END   risk_weight_factor_pre_fx_mm,
        NULL conversion_ratio_exp_pre_ccf,
		vbia.loan_split_derogation_ind	loan_split_derogation_ind,
        vbia.risk_weight_art378,
		case when f.applied_ind = 1 THEN round(vbia.exposure_amount_art378 * f.conversion_ratio_exposure, 4) END	exposure_amount_art378,
		case when f.applied_ind = 1 THEN round(vbia.rwa_art378 * f.conversion_ratio_exposure, 4) END	rwa_art378,
		vbia.book_risk_category,
		vbia.settlement_date ,
		vbia.days_unsettled_after_due_date,
		vbia.settlement_amount,
        vbia.securitisation_code,
		f.unsecuritised_factor,
		vbia.sec_pro_rata_factor,
        vbia.official_challenger_indicator,
		NULL on_balance_ratio_exp_pre_ccf,
		NULL modelled_ccf,
		CASE WHEN f.original_ind = 1 THEN round(vbia.inscription_value * f.conversion_ratio * NVL(vbia.split_ratio,1),4) END AS  inscription_value
      FROM tmp_corep_recap_b4 vbia
      INNER JOIN tmp_corep_recap_factor_b4 f ON (vbia.record_id = f.record_id AND vbia.source_table = 'SA')
      LEFT OUTER JOIN TT_TMP_COVER_CDS src ON (vbia.cover_id = src.cover_id )
      LEFT OUTER JOIN (SELECT  code country_code,country_key FROM country)dc ON(src.cover_ctry_key = dc.country_key)
      LEFT OUTER JOIN dwh_incap_outstanding_group diog ON (diog.outstanding_group_key = vbia.outstanding_group_key AND diog.configuration_code = 'INCAPTTCDT')
	  AND diog.system_id = v_system_id
	  AND diog.record_valid_from = v_reporting_date
        UNION ALL
		SELECT  CASE WHEN f.original_ind = 1 THEN round(vbia.allocated_limit_amt * f.conversion_ratio, 2)   END allocated_limit_amt ,
        CASE WHEN f.original_ind = 1 THEN round(vbia.allocated_outstanding_amt * f.conversion_ratio_on_balance, 2) END allocated_outstanding_amt,
		CASE WHEN f.applied_ind = 1 THEN vbia.exposure_class_applied ELSE vbia.exposure_class  END 	exposure_class	,
		vbia.cover_id	cover_id	,
		CASE  WHEN f.applied_ind = 1 THEN round(vbia.capital_requirement * f.conversion_ratio_exposure,2)  END 	capital_requirement	,
		CASE  WHEN f.applied_ind = 1 THEN round(vbia.expected_loss * f.conversion_ratio_exposure,2)  END 	expected_loss	,
		CASE  WHEN f.applied_ind = 1 THEN round(vbia.exposure_at_default * f.conversion_ratio_exposure,2)  END 	exposure_at_default	,
		CASE  WHEN f.applied_ind = 1 THEN vbia.loss_given_default  END 	loss_given_default	,
		vbia.outstanding_group_id	outstanding_group_id	,
		vbia.outstanding_group_key	outstanding_group_key	,
		CASE  WHEN f.applied_ind = 1 THEN vbia.pd_applied  END 	pd	,
		CASE  WHEN f.original_ind = 1 THEN round(vbia.alloc_provision_amt * f.conversion_ratio,2)  END 	alloc_provision_amt	,
		CASE  WHEN f.applied_ind = 1 THEN round(vbia.risk_weighted_assets * f.conversion_ratio_exposure,4)  END 	risk_weighted_assets	,
		CASE  WHEN f.original_ind = 1 THEN vbia.risk_weight_factor_original ELSE vbia.risk_weight_factor  END 	risk_weight_factor	,
		vbia.rating_key	rating_key	,
		CASE  WHEN   f.original_ind = 1 THEN round(vbia.exposure_original * f.conversion_ratio,2)  END   	exposure_original	,
		CASE  WHEN   f.original_ind = 1 THEN round(vbia.exposure_original_drawn * f.conversion_ratio_on_balance,2)  END   	exposure_original_drawn	,
		CASE  WHEN   f.original_ind = 1 THEN round(vbia.exposure_pre_ccf * f.conversion_ratio,2)  END   	exposure_pre_ccf	,
		CASE  WHEN   f.original_ind = 1 THEN round(vbia.exposure_pre_ccf_drawn * f.conversion_ratio_on_balance,2)  END   	exposure_pre_ccf_drawn	,
		f.conversion_ratio	conversion_ratio	,
		CASE  WHEN f.applied_ind  = 1 THEN vbia.basel_approach  END    	basel_approach	,
		CASE  WHEN  f.original_ind = 1 THEN round(vbia.original_cover_value * f.conversion_ratio,2)  END 	original_cover_value	,
		vbia.g_factor	g_factor	,
		vbia.k_factor	k_factor	,
		vbia.regulator	regulator	,
		f.on_balance_ind	on_balance_ind	,
        CASE  WHEN f.applied_ind = 1 AND vbia.risk_weight_substitution = 1 THEN vbia.credit_quality_step_sec END credit_quality_step ,
		CASE  WHEN f.applied_ind = 1 THEN round(vbia.residual_value_amount * f.conversion_ratio,2)  END 	residual_value_amount	,
		CASE  WHEN f.applied_ind = 1 THEN round(vbia.residual_value_capital_req * f.conversion_ratio,2)  END 	residual_value_capital_req	,
		vbia.residual_value_risk_weight	residual_value_risk_weight	,
		vbia.record_valid_from	record_valid_from	,
		vbia.system_id	system_id	,
		vbia.credit_conversion_factor	credit_conversion_factor	,
		vbia.risk_weight_substitution    	risk_weight_substitution	,
		f.conversion_ratio_exposure  	conversion_ratio_exposure	,
		NULL	conversion_ratio_fin_coll	,
		f.conversion_ratio_on_balance	conversion_ratio_on_balance	,
		case when f.applied_ind = 1 THEN ROUND(vbia.fully_adjusted_exposure_on_sa *  f.conversion_ratio_on_balance,4)  END  	fully_adjusted_exposure_on_sa	,
		case when f.applied_ind = 1 THEN ROUND(vbia.fully_adjusted_exposure_off_sa  * f.conversion_ratio_off_balance,4) END  	fully_adjusted_exposure_off_sa	,
		case when f.applied_ind = 1 THEN ROUND(vbia.financial_collateral_sa * f.conversion_ratio,2)  END 	financial_collateral_sa	,
		CASE  WHEN f.original_ind = 1 THEN round(vbia.exposure_net_provision_sa * f.conversion_ratio,2)  END  	exposure_net_provision_sa	,
		NULL 	volatility_maturity_adj	,
		CASE  WHEN f.applied_ind = 1 THEN round(vbia.ccf_0percent   * f.conversion_ratio_off_balance,4)  END 	ccf_0percent	,
		CASE  WHEN f.applied_ind = 1 THEN round(vbia.ccf_20percent  * f.conversion_ratio_off_balance,4)  END 	ccf_20percent	,
		CASE  WHEN f.applied_ind = 1 THEN round(vbia.ccf_50percent  * f.conversion_ratio_off_balance,4)  END 	ccf_50percent	,
		CASE  WHEN f.applied_ind = 1 and basel_approach='SA' THEN round(vbia.ccf_100percent * f.conversion_ratio_off_balance,4)  END   	ccf_100percent	,
		f.conversion_ratio_off_balance	conversion_ratio_off_balance	,
		vbia.retained_position_ind	retained_position_ind	,
		vbia.securitisation_key	securitisation_key	,
		f.securitised_ind	securitised_ind	,
		CASE  WHEN  f.original_ind = 1 THEN  round(vbia.exposure_original_undrawn * f.conversion_ratio_off_balance,2) END 	exposure_original_undrawn	,
		CASE  WHEN f.original_ind = 1 THEN  round(vbia.exposure_pre_ccf_undrawn  * f.conversion_ratio_off_balance,2) END 	exposure_pre_ccf_undrawn	,
		vbia.source_table	source_table	,
		f.original_ind	original_ind	,
		f.applied_ind	applied_ind	,
		vbia.customer_key	customer_key	,
		vbia.customer_id	customer_id	,
		vbia.effective_maturity	effective_maturity	,
		vbia.facility_id	facility_id	,
		vbia.outstanding_id	outstanding_id	,
		vbia.outstanding_key	outstanding_key	,
		vbia.official_approach_indicator	official_approach_indicator	,
		CASE  WHEN f.applied_ind  = 1 THEN vbia.basel2_official_approach  END   	basel2_official_approach	,
		CASE  WHEN f.original_ind = 1 THEN vbia.sec_category  END 	sec_category	,
		CASE  WHEN f.applied_ind = 1 AND vbia.risk_weight_substitution = 1 THEN 0  END  	large_or_unregulated_fin_entity_ind	,
		vbia.h_factor	h_factor	,
		vbia.cure_rate	cure_rate	,
		vbia.unsecured_discount_factor	unsecured_discount_factor	,
		vbia.facility_key	facility_key	,
		vbia.committed_indicator	committed_indicator	,
		CASE WHEN  f.original_ind = 1 THEN round(vbia.after_coll_regulatory_os_amt * f.conversion_ratio_on_balance,2) END 	after_coll_regulatory_os_amt	,
		CASE WHEN  f.original_ind = 1 THEN round(vbia.gross_regulatory_os_amt * f.conversion_ratio_on_balance,2) END 	gross_regulatory_os_amt	,
		CASE WHEN  f.original_ind = 1 THEN round(vbia.regulatory_os_amt * f.conversion_ratio_on_balance,2)  END 	regulatory_os_amt	,
		CASE WHEN  f.original_ind = 1 THEN round(vbia.old_regulatory_os_amt * f.conversion_ratio_on_balance,2) END 	 old_regulatory_os_amt 	,
		vbia.ccp_counterparty_indicator	ccp_counterparty_indicator	,
		vbia.in_default_ind	in_default_ind	,
		vbia.pro_rata_factor	pro_rata_factor	,
		CASE WHEN f.applied_ind = 1 THEN round(vbia.risk_weight_asset_original * f.conversion_ratio_exposure,2)  END  	risk_weight_asset_original	,
		vbia.residual_value_risk_weight_asset	residual_value_risk_weight_asset	,
		'B' 	source	,
		CASE WHEN f.applied_ind = 1 AND vbia.risk_weight_substitution = 1 THEN round(vbia.exposure_net_provision_sa * f.conversion_ratio,2) END  	inflow	,
		CASE WHEN f.applied_ind = 1 THEN round(vbia.fully_adjusted_exposure * f.conversion_ratio,2)  END  	fully_adjusted_exposure	,
		CASE WHEN f.original_ind = 1 THEN vbia.sec_rating_approach  END  	sec_rating_approach	,
		vbia.cqs_cen_gov_ind 	cqs_cen_gov_ind	,
		vbia.on_balance_ratio	on_balance_ratio	,
		vbia.on_balance_ratio_exposure	on_balance_ratio_exposure	,
		vbia.on_balance_ratio_collateral_sa	on_balance_ratio_collateral_sa	,
		vbia.on_balance_ratio_fin_coll	on_balance_ratio_fin_coll	,
		f.securitised_factor	securitised_factor	,
		vbia.provision_category	provision_category	,
		NULL	exposure_class_sa_not_def_sec	,
		case when f.applied_ind = 1 THEN  round(vbia.risk_weight_asset_pre_sme_fact * f.conversion_ratio_exposure,4)   END 	risk_weight_asset_pre_sme_fact	,
		vbia.subject_to_sme_factor_ind	subject_to_sme_factor_ind	,
		NULL	exposure_class_sa_not_def	,
		vbia.lr_on_balance_ratio	lr_on_balance_ratio	,
		vbia.lr_on_balance_ratio_exposure	lr_on_balance_ratio_exposure	,
		f.conversion_ratio_exposure_lr	conversion_ratio_exposure_lr	,
		vbia.lr_k_factor	lr_k_factor	,
		vbia.lr_g_factor	lr_g_factor	,
		CASE WHEN  f.original_ind = 1 THEN round(vbia.lre_amount * f.conversion_ratio_exposure_lr,2) END 	lre_amount	,
		CASE WHEN  f.original_ind = 1 THEN round(vbia.lre_on_balance * f.conversion_ratio_on_balance,2)  END 	lre_on_balance	,
		CASE WHEN  f.original_ind = 1 THEN round(vbia.lre_off_balance_before_ccf * f.conversion_ratio_off_balance,2) END 	lre_off_balance_before_ccf	,
		CASE WHEN  f.original_ind = 1 THEN round(vbia.lre_off_balance_after_ccf * f.conversion_ratio_off_balance,2) END 	lre_off_balance_after_ccf	,
		CASE WHEN  f.original_ind = 1 THEN round(vbia.LR_CCF_10PERCENT * f.conversion_ratio_off_balance,2) END 	LR_CCF_10PERCENT	,
		CASE WHEN  f.original_ind = 1 THEN round(vbia.LR_CCF_20PERCENT * f.conversion_ratio_off_balance,2) END 	LR_CCF_20PERCENT	,
        CASE WHEN  f.original_ind = 1 THEN round(vbia.LR_CCF_40PERCENT * f.conversion_ratio_off_balance,2) END 	LR_CCF_40PERCENT	,
		CASE WHEN  f.original_ind = 1 THEN round(vbia.LR_CCF_50PERCENT * f.conversion_ratio_off_balance,2) END 	LR_CCF_50PERCENT	,
		CASE WHEN  f.original_ind = 1 THEN round(vbia.LR_CCF_100PERCENT * f.conversion_ratio_off_balance,2) END LR_CCF_100PERCENT	,
		vbia.effective_regulated_indicator	effective_regulated_indicator	,
		vbia.netted_indicator	netted_indicator	,
		vbia.off_supp_credit_indicator	off_supp_credit_indicator	,
		CASE WHEN  f.applied_ind = 1 THEN round(vbia.notional_amount * f.conversion_ratio_on_balance,2) END 	notional_amount	,
		CASE WHEN  f.applied_ind = 1 THEN round(vbia.mtm_amount * f.conversion_ratio_on_balance,2) END 	mtm_amount	,
		CASE WHEN  f.applied_ind = 1 THEN round(vbia.add_on * f.conversion_ratio_on_balance,2) END 	add_on	,
		vbia.correlation_factor	correlation_factor	,
		vbia.in_default_ind_original	in_default_ind_original	,
		vbia.sme_ind	sme_ind	,
		vbia.risk_weight_add_on_factor	risk_weight_add_on_factor	,
		vbia.risk_weight_add_on_term	risk_weight_add_on_term	,
		vbia.risk_weight_factor_original	risk_weight_factor_original	,
		vbia.basel_local_official_approach	basel_local_official_approach	,
		NULL 	gross_carrying_amt	,
		vbia.remaining_maturity_in_months 	residual_maturity_months	,
		vbia.residual_maturity_bucket_code 	residual_maturity_bucket_code	,
		NULL 	ifrs_accounting_classification	,
		NULL 	ifrs_measurement_category	,
		CASE WHEN f.applied_ind = 1 THEN round(vbia.rwa_including_addon  * f.conversion_ratio_exposure,4)  END 	rwa_including_addon	,
		CASE WHEN f.applied_ind = 1 THEN round(vbia.rwa_pre_sme_including_addon  * f.conversion_ratio_exposure,4)  END 	rwa_pre_sme_including_addon	,
		vbia.rwa_add_on_report_classification	rwa_add_on_report_classification	,
		CASE WHEN f.original_ind = 1 THEN vbia.sts_indicator  END 	sts_indicator	,
		CASE WHEN f.original_ind = 1 THEN vbia.sec_calculation_method  END 	sec_calculation_method	,
		CASE WHEN f.original_ind = 1 THEN vbia.sts_qualif_diff_treatment_ind  END 	sts_qualif_diff_treatment_ind	,
		CASE WHEN f.original_ind = 1 THEN round(vbia.capital_requirement * f.conversion_ratio_exposure,2) ELSE 0 END  	capital_requirement_c_09_04  	,
		CASE WHEN f.original_ind = 1 THEN ROUND(vbia.exposure_at_default * f.conversion_ratio_exposure,4) ELSE 0 END  	exposure_at_default_c_09_04   	,
		vbia.zero_rrw_sov_indicator	zero_rrw_sov_indicator 	,
		vbia.strict_prudential_rw_ind	strict_prudential_rw_ind 	,
		vbia.strict_lgd_floor_ind	strict_lgd_floor_ind	,
		NULL 	rwa_pre_sme_fact_ex_add_on	,
		vbia.exposure_weighted_avg_lgd	exposure_weighted_avg_lgd	,
		vbia.k_a_parameter_w	k_a_parameter_w	,
		vbia.k_irb	k_irb	,
		vbia.k_sa	k_sa	,
		0	ppu_sa_ind	,
		NULL	rwa_ex_strict_prud	,
		vbia.subject_to_infra_factor_ind	subject_to_infra_factor_ind	,
		case when f.applied_ind = 1 THEN ROUND(vbia.risk_weight_asset_pre_infra_fact * f.conversion_ratio_exposure, 4) END	risk_weight_asset_pre_infra_fact	,
		case when f.applied_ind = 1 THEN ROUND(vbia.rwa_sme_support_amt  * f.conversion_ratio_exposure, 4) END	rwa_sme_support_amt	,
        NULL rwa_ex_add_on,
		case when f.applied_ind = 1 AND vbia.risk_weight_substitution = 1 THEN vbia.loss_given_default  END  	lgd_pre_cds	,
		vbia.pd_original_after_multipliers	pd_original_after_multipliers	,
		case when f.original_ind = 1 THEN ROUND(vbia.ccr_variation_margin * f.conversion_ratio_on_balance,2) END	ccr_variation_margin  	,
		case when f.original_ind = 1 THEN ROUND(vbia.ccr_net_indep_collat_amt * f.conversion_ratio_on_balance,2) END	ccr_net_indep_collat_amt	,
		case when f.original_ind = 1 THEN ROUND(vbia.ccr_replacement_cost * f.conversion_ratio_on_balance,2) END	ccr_replacement_cost	,
		case when f.original_ind = 1 THEN ROUND(vbia.ccr_addon * f.conversion_ratio_on_balance,2) END	ccr_addon	,
		case when f.original_ind = 1 THEN ROUND(vbia.ccr_potential_future_exp * f.conversion_ratio_on_balance,2) END	ccr_potential_future_exp	,
		case when f.original_ind = 1 THEN ROUND(vbia.ccr_exp_value_pre_crm  * f.conversion_ratio_on_balance,2) END	ccr_exp_value_pre_crm	,
		case when f.original_ind = 1 THEN ROUND(vbia.ccr_exp_value_post_crm * f.conversion_ratio_on_balance,2) END	ccr_exp_value_post_crm 	,
		case when f.original_ind = 1 THEN ROUND(vbia.lre_ccr_variation_margin * f.conversion_ratio_on_balance,2) END	lre_ccr_variation_margin	,
		case when f.original_ind = 1 THEN ROUND(vbia.lre_ccr_replacement_cost  * f.conversion_ratio_on_balance,2) END	lre_ccr_replacement_cost	,
		vbia.exposure_class	exposure_class_original	,
		vbia.exposure_class_applied	exposure_class_applied	,
		CASE WHEN vbia.committed_indicator = 'C'
             THEN CASE WHEN  f.original_ind = 1 THEN round(vbia.exposure_original * f.conversion_ratio,2) END
             ELSE CASE WHEN  f.original_ind = 1 THEN round(vbia.allocated_outstanding_amt * f.conversion_ratio_on_balance,2) END
        END exposure_amount,
		src.cover_key	cover_key 	,
		src.cover_type_key	cover_type_key 	,
		src.cover_provider 	cover_provider_id 	,
		src.cover_provider_key 	cover_provider_key 	,
		src.cover_ctry_key 	cover_ctry_key 	,
		dc.country_code 	cover_ctry_code 	,
		diog.finrep_sector	finrep_sector 	,
		diog.le_sector 	large_exposure_sector	,
		NULL 	leverage_sme_ind 	,
		v_reporting_date	reporting_date	,
		CASE WHEN f.original_ind = 1 THEN ROUND(vbia.risk_weight_asset_orig_obligor * f.conversion_ratio_exposure,2) END risk_weight_asset_orig_obligor	,
		vbia.risk_weight_asset_sec_erba	risk_weight_asset_sec_erba 	,
		vbia.risk_weight_asset_sec_sa  	risk_weight_asset_sec_sa 	,
		NULL 	exposure_at_default_abs 	,
		NULL 	original_cover_value_abs	,
		NULL 	residual_value_amount_abs 	,
		NULL 	outflow	,
		NULL 	lgd_model_code 	,
		NULL 	substitution_method 	,
		NULL 	rw_substitution_method 	,
		--NULL 	rw_floor 	,
		NULL	official_approach_applied 	,
		NULL 	risk_weighted_assets_pre_cds
		,vbia.direct_cost
		,vbia.indirect_cost,
		SECURED_RECOVERY_AMOUNTS,
		SECURED_RECOVERY_AMOUNTS_DISCOUNTED	,
		UNSECURED_RECOVERY_AMOUNTS,
		UNSECURED_RECOVERY_AMOUNTS_DISCOUNTED,
		CREDIT_QUALITY_STEP_SEC,
		NULL rating_agency_key,
        NULL external_rating,
        vbia.risk_weight_asset_sec_tr risk_weight_asset_sec_tr,
        CASE  WHEN f.applied_ind = 1 THEN round(vbia.risk_weighted_assets_due_dill * f.conversion_ratio_exposure,2)  END risk_weighted_assets_due_dill,
        CASE  WHEN f.applied_ind = 1 THEN round(vbia.risk_weighted_assets_sec_mat_mism * f.conversion_ratio_exposure,2)  END risk_weighted_assets_sec_mat_mism,
        CASE  WHEN f.applied_ind = 1 THEN ROUND(vbia.rwa_infra_support_amt * f.conversion_ratio_exposure, 4) END rwa_infra_support_amt,
        vbia.ead_exclusion_ind,
        NULL configuration_code,
        NULL condition_outcome_code,
        NULL ccf_10percent ,
        NULL ccf_40percent,
        NULL COVER_SPLIT_KEY,
        NULL property_ratio_from,
        NULL property_ratio_until,
        NULL EAD_RATIO,
        NULL COLLATERALISATION_RATIO,
        NULL rwa_pre_infra_fct_ex_strict_prud,
        NULL rwa_pre_sme_fact_ex_strict_prud,
        NULL risk_weight_excl_strict_prud,
        NULL exposure_class_irb_in_sa,
        NULL exposure_class_sa_in_irb,
        NULL res_imm_prop_ind,
        NULL com_imm_prop_ind,
        NULL regulatory_large_corp_ind,
		NULL ccf_ucc_transitional 	,
		NULL rwa_non_ccf_ucc_trans ,
        NULL SPLIT_RATIO,
        NULL ucc_non_trans_on_balance_ratio_exposure,
        NULL ucc_non_trans_conversion_ratio_exposure,
		vbia.basel_approach basel_approach_original ,
		NULL guar_ppu_sa_ind,
		CASE  WHEN f.applied_ind = 1 and basel_approach in ('AIRB','AIRB_OFFIC','FIRB') THEN round(vbia.ccf_100percent * f.conversion_ratio_off_balance,4) END ccf_100percent_irb,
		NULL regulatory_ead_applied,
		NULL  risk_weight_factor_macro_prud,--New column added AB 5033337
        NULL  rwa_pre_sme_fact_macro_prud,--New column added AB 5033337
        NULL  rwa_pre_infra_fact_macro_prud,--New column added AB 5033337
        NULL  rwa_macro_prud, --New column added AB 5033337
        NULL exposure_class_sa_original,
		CASE WHEN f.applied_ind = 1 THEN round(vbia.risk_weight_asset_pre_sme_fact * f.conversion_ratio_exposure, 4) END risk_weight_asset_pre_fx_mm,
		case when f.original_ind = 0 THEN vbia.risk_weight_factor
		     WHEN f.original_ind = 1 THEN vbia.risk_weight_factor_original END risk_weight_factor_pre_fx_mm,
        NULL conversion_ratio_exp_pre_ccf,
		NULL loan_split_derogation_ind,
        NULL risk_weight_art378,
		NULL exposure_amount_art378,
		NULL	rwa_art378,
		NULL    book_risk_category,
		NULL    settlement_date,
		NULL    days_unsettled_after_due_date,
		NULL settlement_amount,
        NULL securitisation_code,
		f.unsecuritised_factor,
		vbia.sec_pro_rata_factor,
        vbia.official_challenger_indicator,
		NULL on_balance_ratio_exp_pre_ccf,
		NULL modelled_ccf,
		NULL inscription_value
      FROM tmp_corep_recap_b4 vbia
      INNER JOIN tmp_corep_recap_factor_b4 f ON (vbia.record_id = f.record_id AND vbia.source_table = 'SEC')
      LEFT OUTER JOIN TT_TMP_COVER_CDS src ON (vbia.cover_id = src.cover_id)
      LEFT OUTER JOIN (SELECT  code country_code,country_key FROM country)dc ON(src.cover_ctry_key = dc.country_key)
      LEFT OUTER JOIN dwh_incap_outstanding_group diog ON (diog.outstanding_group_key = vbia.outstanding_group_key AND diog.configuration_code = 'INCAPTTCDT'
	  AND diog.system_id = v_system_id
	  AND diog.record_valid_from = v_reporting_date
	  );

exception
      when others then utils.handleerror(sqlcode,sqlerrm);
end;

v_debug_msg := $$plsql_line || ' of plsql unit ' || $$plsql_unit ||' '|| systimestamp ||' Rows Affected:- '||SQL%ROWCOUNT;
utilities.show_debug(v_debug_msg);
schema_maint.gather_idx_stats('tt_tmp_corep_recap_measure_b4');
   utilities.truncate_table('TT_TMP_COVER_CDS');
COMMIT;

   insert_dmb_log_corep(v_detail_level => 103,
                                  v_log_descr => 'process_pre_corep_recap_b4',
                                  v_activity_code => 'Insert tmp',
                                  v_result_code => 'FINOK',
                                  v_system_id       => v_system_id,v_reporting_date       => v_reporting_date) ;

   insert_dmb_log_corep(v_detail_level => 103,
                                  v_log_descr => 'process_pre_corep_recap_b4',
                                  v_activity_code => 'Exposure amt',
                                  v_result_code => 'START',
                                  v_system_id       => v_system_id,v_reporting_date       => v_reporting_date) ;

   insert_dmb_log_corep(v_detail_level => 103,
                                v_log_descr => 'process_pre_corep_recap_b4',
                                v_activity_code => 'Exposure amt',
                                v_result_code => 'FINOK',
                                v_system_id       => v_system_id,v_reporting_date       => v_reporting_date) ;
   ----------------------------------------------------------------------------------------------
   -- Update cover attributes
   ----------------------------------------------------------------------------------------------
   insert_dmb_log_corep(v_detail_level => 103,
                                  v_log_descr => 'process_pre_corep_recap_b4',
                                  v_activity_code => 'Upd Cover1',
                                  v_result_code => 'START',
                                  v_system_id       => v_system_id,v_reporting_date       => v_reporting_date) ;

   insert_dmb_log_corep(v_detail_level => 103,
                                v_log_descr => 'process_pre_corep_recap_b4',
                                v_activity_code => 'Upd Cover1',
                                v_result_code => 'FINOK',
                                v_system_id       => v_system_id,v_reporting_date       => v_reporting_date) ;
   insert_dmb_log_corep(v_detail_level => 103,
                                v_log_descr => 'process_pre_corep_recap_b4',
                                v_activity_code => 'Upd Cover2',
                                v_result_code => 'START',
                                v_system_id       => v_system_id,v_reporting_date       => v_reporting_date) ;



   utilities.truncate_table('TT_DMI_COREP_CUSTOMER');

    INSERT  INTO tt_dmi_corep_customer (  --+ APPEND
        customer_key,
        ctry_of_incorporation_key,
        legal_imm_parent_id,
        branch_indicator
    )
        ( SELECT customer_key,
            ctry_of_incorporation_key,
            legal_imm_parent_id,
            CASE
                WHEN branch_indicator = 'Y' THEN
                    1
                ELSE
                    0
            END AS branch_indicator
        FROM dwh_derived_customer c
            left outer join dwh_basic_customer b ON c.basic_customer_key = b.basic_customer_key
        WHERE
            c.customer_key IN (
                SELECT
                    customer_key
                FROM
                    TT_tmp_corep_recap_measure_b4
                UNION
                SELECT
                    cover_provider_key
                FROM
                    TT_tmp_corep_recap_measure_b4
                UNION
                SELECT
                    principal_borrower_key
                FROM
                    tmp_corep_basic_info_b4  --to be renamed
            )
        );

   COMMIT;
   schema_maint.gather_idx_stats('TT_DMI_COREP_CUSTOMER');



      --JT Query tune for performance issue
INSERT/*+ APPEND +*/ INTO tmp_corep_recap_measure_pre_b4 (
		exposure_class,
		cover_id,
		capital_requirement,
		expected_loss,
		exposure_at_default,
		loss_given_default,
		outstanding_group_id,
		outstanding_group_key,
		pd,
		alloc_provision_amt,
		risk_weighted_assets,
		risk_weight_factor,
		rating_key,
		exposure_original,
		exposure_original_drawn,
		allocated_limit_amt,
		exposure_pre_ccf,
		allocated_outstanding_amt,
		exposure_pre_ccf_drawn,
		conversion_ratio,
		basel_approach,
		original_cover_value,
		g_factor,
		k_factor,
		regulator,
		on_balance_ind,
		credit_quality_step,
		credit_quality_step_sec,
		residual_value_amount,
		residual_value_capital_req,
		residual_value_risk_weight,
		record_valid_from,
		system_id,
		credit_conversion_factor,
		risk_weighted_assets_due_dill,
		risk_weighted_assets_sec_mat_mism,
		risk_degree_code,
		risk_weight_substitution,
		conversion_ratio_exposure,
		conversion_ratio_fin_coll,
		conversion_ratio_on_balance,
		fully_adjusted_exposure_on_sa,
		fully_adjusted_exposure_off_sa,
		financial_collateral_sa,
		exposure_net_provision_sa,
		volatility_maturity_adj,
		conversion_ratio_off_balance,
		retained_position_ind,
		securitisation_key,
		securitised_ind,
		exposure_original_undrawn,
		exposure_pre_ccf_undrawn,
		source_table,
		original_ind,
		applied_ind,
		customer_key,
		customer_id,
		effective_maturity,
		facility_id,
		outstanding_id,
		outstanding_key,
		official_approach_indicator,
		basel2_official_approach,
		sec_category,
		large_or_unregulated_fin_entity_ind,
		h_factor,
		--e_factor,
		direct_cost,
		indirect_cost,
		cure_rate,
		unsecured_recovery_amounts,
		unsecured_recovery_amounts_discounted,
		unsecured_discount_factor,
		secured_recovery_amounts,
		secured_recovery_amounts_discounted,
		facility_key,
		committed_indicator,
		after_coll_regulatory_os_amt,
		gross_regulatory_os_amt,
		regulatory_os_amt,
		old_regulatory_os_amt,
		ccp_counterparty_indicator,
		in_default_ind,
		pro_rata_factor,
		risk_weight_asset_original,
		source,
		inflow,
		external_rating,
		--rating_agency_sec_key,
		--external_rating_sec,
		sec_rating_approach,
		cqs_cen_gov_ind,
		on_balance_ratio,
		on_balance_ratio_exposure,
		on_balance_ratio_collateral_sa,
		on_balance_ratio_fin_coll,
		securitised_factor,
		provision_category,
		exposure_class_sa_not_def_sec,
		risk_weight_asset_pre_sme_fact,
		subject_to_sme_factor_ind,
		exposure_class_sa_not_def,
		lr_on_balance_ratio,
		lr_on_balance_ratio_exposure,
		conversion_ratio_exposure_lr,
		lr_k_factor,
		lr_g_factor,
		lre_amount,
		lre_on_balance,
		lre_off_balance_before_ccf,
		lre_off_balance_after_ccf,
		LR_CCF_10PERCENT,
		LR_CCF_20PERCENT,
        LR_CCF_40PERCENT,
		LR_CCF_50PERCENT,
		LR_CCF_100PERCENT,
		effective_regulated_indicator,
		netted_indicator,
		off_supp_credit_indicator,
		notional_amount,
		mtm_amount,
		add_on,
		calculated_add_on,
		net_mtm_amount,
		ccf_0percent_irb,
		--ccf_20percent_irb,
		--ccf_50percent_irb,
		--ccf_100percent_irb,
		--cva_exposure,
		--cva_effective_maturity,
		--cva_risk_weight,
		--diversification_cva_ratio,
		--diversified_cva_capital,
		correlation_factor,
		in_default_ind_original,
		--provision_amount_llp,
		--provision_category_llp,
		sme_ind,
		risk_weight_add_on_factor,
		risk_weight_add_on_term,
		risk_weight_factor_original,
		basel_local_official_approach,
		--rwa_pre_sme_including_addonterm,
		--rwa_including_addonterm,
		gross_carrying_amt,
		residual_maturity_months,
		residual_maturity_bucket_code,
		ifrs_accounting_classification,
		ifrs_measurement_category,
		rwa_including_addon,
		rwa_pre_sme_including_addon,
		rwa_add_on_report_classification,
		sts_indicator,
		sec_calculation_method,
		sts_qualif_diff_treatment_ind,
		capital_requirement_c_09_04,
		exposure_at_default_c_09_04,
		zero_rrw_sov_indicator,
		strict_prudential_rw_ind,
		strict_lgd_floor_ind,
		rwa_ex_add_on,
		rwa_pre_sme_fact_ex_add_on,
		--rw_dod_add_on_f_global_charge,
		--rwa_add_on_for_dod,
		--rwa_add_on_for_term_factor,
		exposure_amount,
		cover_key,
		cover_type_key,
		cover_provider_id,
		cover_provider_key,
		cover_ctry_key,
		cover_ctry_code,
		finrep_sector,
		cover_ctry_ec_ind,
		--next_review_date,
		--principal_next_review_date,
		--econ_parent_review_date_bucket_key,
		--legal_parent_review_date_bucket_key,
        intercompany_code,
		--review_date_bucket_key,
		--legal_ult_parent_risk_rating_key,
		--legal_ult_parent_risk_rating_owner_key,
		--econ_ult_parent_risk_rating_key,
		--econ_ult_parent_risk_rating_owner_key,
		legal_principal_ult_parent_id,
		principal_borrower_id,
		ctry_of_incorporation_key,
		ctry_of_residence_key,
		customer_type_key,
		econ_ult_parent_id,
		--econ_ult_parent_key,
		--industry_type_key,
		segmentation_type_key,
		--worst_ctry_of_risk_key,
		legal_ult_parent_id,
		--legal_ult_parent_key,
		--cust_status_key,
		booking_office_key,
		initiating_office_key,
		mis_raroc_product_type_key,
		original_ccy_key,
		risk_rating_key,
		--risk_rating_owner_key,
		auth_combination_key,
		--next_review_date_cdd,
		--review_date_cdd_bucket_key,
		--lup_review_date_cdd_bucket_key,
		--eup_review_date_cdd_bucket_key,
		--next_review_date_mifid,
		--review_date_mifid_bucket_key,
		--lup_review_date_mifid_bucket_key,
		--eup_review_date_mifid_bucket_key,
		--next_review_date_br,
		--review_date_br_bucket_key,
		--lup_review_date_br_bucket_key,
		--eup_review_date_br_bucket_key,
		--review_date_cdd_owner_key,
		--lup_review_date_cdd_owner_key,
		--eup_review_date_cdd_owner_key,
		--review_date_mifid_owner_key,
		--lup_review_date_mifid_owner_key,
		--eup_review_date_mifid_owner_key,
		--review_date_br_owner_key,
		--lup_review_date_br_owner_key,
		--eup_review_date_br_owner_key,
		--customer_type_cdd_key,
		--customer_type_mifid_key,
		--classification_mifid_key,
		--classification_mifid_code,
		--risk_level_cdd_key,
		--risk_level_cdd_code,
		ead_model_code,
		lgd_model_code,
		ead_model_key,
		lgd_model_key,
		os_accounting_unit_key,
		os_ing_legal_entity_key,
		product_type_key,
		--segmentation_type_poland_key,
		--segmentation_type_belgium_key,
		--segmentation_type_india_key,
		--segmentation_type_netherlands_key,
		--segmentation_type_romania_key,
		--segmentation_type_turkey_key,
		maximum_limit_amt,
		booking_base_entity_key,
		initiating_base_entity_key,
		--compliance_department_key,
		--lup_compliance_department_key,
		--eup_compliance_department_key,
		--maintenance_unit_key,
		--lup_maintenance_unit_key,
		--eup_maintenance_unit_key,
		local_outstanding_id,
		--generated_record,
		secondary_currency_key,
		fac_accounting_unit_key,
		fac_booking_office_key,
		fac_ing_legal_entity_key,
		fac_initiating_office_key,
		--fac_original_ccy_key,
		facility_purpose_key,
		facility_type_key,
		limit_end_date,
		orig_end_date,
		limit_start_date,
		orig_start_date,
		risk_rating_type,
		cover_type_combination_key,
		higher_level_facility_key,
		limit_type_indicator,
		--segmentation_code_up_pb_hf,
		principal_borrower_key,
		fac_mis_raroc_product_type_key,
		multi_ccy_indicator,
		--fac_generated_record,
		higher_level_facility_id,
		highest_level_facility_id,
		fac_booking_base_entity_key,
		fac_initiating_base_entity_key,
		security_id,
		security_id_type,
		exposure_class_code,
		facility_hierarchy_level,
		maturity_date,
		orig_maturity_date,
		bond_rating_agency_code,
		bond_rating_code,
		--exchange_rate,
		os_max_remaining_tenor,
		fac_max_remaining_tenor,
		master_scale_level4_code,
		risk_rating_code,
		ctry_of_residence_code,
		ctry_of_incorporation_code,
		--ctry_of_incorp_pr_borr_key,
		--ctry_of_incorp_pr_borr_code,
		ctry_of_incorp_guarantor_key,
		ctry_of_incorp_guarantor_code,
		risk_degree_key,
		facility_type_code,
		facility_purpose_code,
		cover_type_code,
		corep_cover_cluster,
		product_type_code,
		default_fund_contr_ind,
		--qccp_initial_margin,
		corep_counterparty_cluster,
		lr_deriv_classification,
		finrep_product_code,
		risk_category_level1_code,
		risk_category_level1_key,
		booking_office_code,
		initiating_office_code,
		--fac_booking_office_code,
		--fac_initiating_office_code,
		securitisation_code,
		rating_agency_code,
		--rating_agency_sec_code,
		credit_qual_step_sec_inc,
		grouping_key,
		with_cai_ind,
		counterparty_ind,
		--cva_cap_eligible_recap,
		permanent_sa_ind,
		outflow,
		original_cover_value_abs,
		fully_adjusted_exposure,
		residual_value_risk_weight_asset,
		exposure_at_default_abs,
		residual_value_amount_abs,
		ccf_0percent,
		ccf_20percent,
		ccf_50percent,
		ccf_100percent,
		e_factor_limit,
		e_factor_os,
		on_balance_sheet_ind,
		negative_limit_ind,
		sec_ccf_drawn_bucket,
		--gk_factor,
		sec_ccf_undrawn_bucket,
		lr_counterparty_cluster,
		customer_type_level3_code,
		lr_covered_bond_ind,
		trade_finance_ind,
		lr_exposure_classification,
		lr_customer_type,
		exposure_weighted_avg_lgd,
		k_a_parameter_w,
		k_irb,
		k_sa,
		ppu_sa_ind,
		risk_weight_excl_strict_prud,
		rwa_pre_sme_fact_ex_strict_prud,
		rwa_ex_strict_prud,
		subject_to_infra_factor_ind,
		risk_weight_asset_pre_infra_fact,
		--rwa_pre_infra_fct_ex_add_on,
		rwa_pre_infra_fct_ex_strict_prud,
		rwa_sme_support_amt,
		rwa_infra_support_amt,
		lgd_pre_cds,
		pd_original_after_multipliers,
		branch_indicator,
		legal_imm_parent_id,
		exposure_class_original,
		exposure_class_applied,
		large_exposure_sector,
		ccr_replacement_cost,
		ccr_addon,
		ccr_potential_future_exp,
		ccr_exp_value_pre_crm,
		ccr_exp_value_post_crm,
		lre_ccr_replacement_cost,
		ccr_variation_margin,
		lre_ccr_variation_margin,
		ccr_net_indep_collat_amt,
		eca_indicator,
		secured_by_com_prop_ind,
		secured_by_res_prop_ind,
		cdspb_facility_ind,
		local_official_approach_indicator,
		--finan_guarantee_given_ind,
		--days_past_due,
		--secured_by_com_prop_os_ind,
		--secured_by_res_prop_os_ind,
		--secured_by_non_mort_os_ind,
		default_fund_ind,
		ccr_wrong_way_risk_indicator,
		observed_new_default_ip_ind,
		observed_new_default_ind,
		--cva_amount,
		--dva_amount,
		incurredcva_amount,
		risk_weight_factor_macro_prud,
		rwa_pre_sme_fact_macro_prud,
		rwa_pre_infra_fact_macro_prud,
		rwa_macro_prud,
		--macro_prud_rw_ltv,
		leverage_sme_ind,
		reporting_date,
		risk_weight_asset_orig_obligor,
		risk_weight_asset_sec_erba,
		risk_weight_asset_sec_sa,
		substitution_method,
		rw_substitution_method,
		--rw_floor,
		official_approach_applied,
		risk_weighted_assets_pre_cds,
        risk_weight_asset_sec_tr,
        ead_exclusion_ind,
        configuration_code,
        condition_outcome_code,
        ccf_10percent,
        ccf_40percent,
        COVER_SPLIT_KEY,
        property_ratio_from,
        property_ratio_until,
        EAD_RATIO,
        COLLATERALISATION_RATIO,
        exposure_class_irb_in_sa,
        exposure_class_sa_in_irb,
        res_imm_prop_ind,
        com_imm_prop_ind,
        regulatory_large_corp_ind,
		ccf_ucc_transitional 	,
		rwa_non_ccf_ucc_trans ,
        SPLIT_RATIO,
        ucc_non_trans_on_balance_ratio_exposure,
        ucc_non_trans_conversion_ratio_exposure,
		basel_approach_original,
		ccf_100percent_irb,
		regulatory_ead_applied,
        exposure_class_sa_original,
		risk_weight_asset_pre_fx_mm,
		risk_weight_factor_pre_fx_mm,
        conversion_ratio_exp_pre_ccf,
		loan_split_derogation_ind,
		risk_weight_art378,
		exposure_amount_art378,
		rwa_art378,
		book_risk_category,
		settlement_date,
		days_unsettled_after_due_date,
		settlement_amount,
		unsecuritised_factor,
		sec_pro_rata_factor,
        official_challenger_indicator,
		on_balance_ratio_exp_pre_ccf,
		modelled_ccf,
		inscription_value
)
SELECT
		t.exposure_class		exposure_class,
		t.cover_id		cover_id,
		t.capital_requirement		capital_requirement,
		t.expected_loss		expected_loss,
		t.exposure_at_default		exposure_at_default,
		t.loss_given_default		loss_given_default,
		t.outstanding_group_id		outstanding_group_id,
		t.outstanding_group_key		outstanding_group_key,
		t.pd		pd,
		t.alloc_provision_amt		alloc_provision_amt,
		t.risk_weighted_assets		risk_weighted_assets,
		t.risk_weight_factor		risk_weight_factor,
		t.rating_key		rating_key,
		t.exposure_original		exposure_original,
		t.exposure_original_drawn		exposure_original_drawn,
		CASE
			WHEN t.source_table = 'SA'
				 AND src18.risk_category_level1_code = 'FM' THEN t.exposure_pre_ccf
			ELSE t.allocated_limit_amt
		END		allocated_limit_amt,
		t.exposure_pre_ccf		exposure_pre_ccf,
		CASE
			WHEN t.source_table = 'SA'
				 AND src18.risk_category_level1_code = 'FM' THEN t.exposure_pre_ccf_drawn
			ELSE t.allocated_outstanding_amt
		END		allocated_outstanding_amt,
		t.exposure_pre_ccf_drawn		exposure_pre_ccf_drawn,
		t.conversion_ratio		conversion_ratio,
		t.basel_approach		basel_approach,
		t.original_cover_value		original_cover_value,
		t.g_factor		g_factor,
		t.k_factor		k_factor,
		t.regulator		regulator,
		t.on_balance_ind		on_balance_ind,
		t.credit_quality_step		credit_quality_step,
		t.credit_quality_step_sec		credit_quality_step_sec,
		t.residual_value_amount		residual_value_amount,
		t.residual_value_capital_req		residual_value_capital_req,
		t.residual_value_risk_weight		residual_value_risk_weight,
		t.record_valid_from		record_valid_from,
		t.system_id		system_id,
		t.credit_conversion_factor		credit_conversion_factor,
		t.risk_weighted_assets_due_dill		risk_weighted_assets_due_dill,
		t.risk_weighted_assets_sec_mat_mism		risk_weighted_assets_sec_mat_mism,
		t.risk_degree_code		risk_degree_code,
		t.risk_weight_substitution		risk_weight_substitution,
		t.conversion_ratio_exposure		conversion_ratio_exposure,
		t.conversion_ratio_fin_coll		conversion_ratio_fin_coll,
		t.conversion_ratio_on_balance		conversion_ratio_on_balance,
		t.fully_adjusted_exposure_on_sa		fully_adjusted_exposure_on_sa,
		t.fully_adjusted_exposure_off_sa		fully_adjusted_exposure_off_sa,
		t.financial_collateral_sa		financial_collateral_sa,
		t.exposure_net_provision_sa		exposure_net_provision_sa,
		t.volatility_maturity_adj		volatility_maturity_adj,
		t.conversion_ratio_off_balance		conversion_ratio_off_balance,
		t.retained_position_ind		retained_position_ind,
		t.securitisation_key		securitisation_key,
		t.securitised_ind		securitised_ind,
		CASE
			WHEN t.source_table = 'SA'
				 AND src18.risk_category_level1_code = 'FM' THEN t.exposure_pre_ccf_undrawn
			ELSE t.exposure_original_undrawn
		END		exposure_original_undrawn,
		t.exposure_pre_ccf_undrawn		exposure_pre_ccf_undrawn,
		t.source_table		source_table,
		t.original_ind		original_ind,
		t.applied_ind		applied_ind,
		t.customer_key		customer_key,
		t.customer_id		customer_id,
		t.effective_maturity		effective_maturity,
		t.facility_id		facility_id,
		t.outstanding_id		outstanding_id,
		t.outstanding_key		outstanding_key,
		t.official_approach_indicator		official_approach_indicator,
		t.basel2_official_approach		basel2_official_approach,
		t.sec_category		sec_category,
		t.large_or_unregulated_fin_entity_ind		large_or_unregulated_fin_entity_ind,
		t.h_factor		h_factor,
		--t.e_factor		e_factor,
		t.direct_cost		direct_cost,
		t.indirect_cost		indirect_cost,
		t.cure_rate		cure_rate,
		t.unsecured_recovery_amounts		unsecured_recovery_amounts,
		t.unsecured_recovery_amounts_discounted		unsecured_recovery_amounts_discounted,
		t.unsecured_discount_factor		unsecured_discount_factor,
		t.secured_recovery_amounts		secured_recovery_amounts,
		t.secured_recovery_amounts_discounted		secured_recovery_amounts_discounted,
		t.facility_key		facility_key,
		t.committed_indicator		committed_indicator,
		t.after_coll_regulatory_os_amt		after_coll_regulatory_os_amt,
		NVL(t.gross_regulatory_os_amt,0)		gross_regulatory_os_amt,
		NVL(t.regulatory_os_amt,0)		regulatory_os_amt,
		t.old_regulatory_os_amt		old_regulatory_os_amt,
		t.ccp_counterparty_indicator		ccp_counterparty_indicator,
		t.in_default_ind		in_default_ind,
		t.pro_rata_factor		pro_rata_factor,
		t.risk_weight_asset_original		risk_weight_asset_original,
		t.source		source,
		t.inflow		inflow,
		t.external_rating		external_rating,
		--t.rating_agency_sec_key		rating_agency_sec_key,
		--t.external_rating_sec		external_rating_sec,
		t.sec_rating_approach		sec_rating_approach,
		t.cqs_cen_gov_ind		cqs_cen_gov_ind,
		t.on_balance_ratio		on_balance_ratio,
		t.on_balance_ratio_exposure		on_balance_ratio_exposure,
		t.on_balance_ratio_collateral_sa		on_balance_ratio_collateral_sa,
		t.on_balance_ratio_fin_coll		on_balance_ratio_fin_coll,
		t.securitised_factor		securitised_factor,
		t.provision_category		provision_category,
		t.exposure_class_sa_not_def_sec		exposure_class_sa_not_def_sec,
		t.risk_weight_asset_pre_sme_fact		risk_weight_asset_pre_sme_fact,
		t.subject_to_sme_factor_ind		subject_to_sme_factor_ind,
		t.exposure_class_sa_not_def		exposure_class_sa_not_def,
		t.lr_on_balance_ratio		lr_on_balance_ratio,
		t.lr_on_balance_ratio_exposure		lr_on_balance_ratio_exposure,
		t.conversion_ratio_exposure_lr		conversion_ratio_exposure_lr,
		t.lr_k_factor		lr_k_factor,
		t.lr_g_factor		lr_g_factor,
		t.lre_amount		lre_amount,
		t.lre_on_balance		lre_on_balance,
		t.lre_off_balance_before_ccf		lre_off_balance_before_ccf,
		t.lre_off_balance_after_ccf		lre_off_balance_after_ccf,
		t.LR_CCF_10PERCENT		LR_CCF_10PERCENT,
		t.LR_CCF_20PERCENT		LR_CCF_20PERCENT,
        t.LR_CCF_40PERCENT		LR_CCF_40PERCENT,
		t.LR_CCF_50PERCENT		LR_CCF_50PERCENT,
		t.LR_CCF_100PERCENT		LR_CCF_100PERCENT,
		t.effective_regulated_indicator		effective_regulated_indicator,
		t.netted_indicator		netted_indicator,
		t.off_supp_credit_indicator		off_supp_credit_indicator,
		t.notional_amount		notional_amount,
		NVL(t.mtm_amount,0)		mtm_amount,
		NVL(t.add_on,0)		add_on,
		NVL(t.calculated_add_on,0)		calculated_add_on,
		NVL(t.net_mtm_amount,0)* nvl(t.split_ratio,1)		net_mtm_amount,
		t.ccf_0percent_irb		ccf_0percent_irb,
		--t.ccf_20percent_irb		ccf_20percent_irb,
		--t.ccf_50percent_irb		ccf_50percent_irb,
		--t.ccf_100percent_irb		ccf_100percent_irb,
		--t.cva_exposure		cva_exposure,
		--t.cva_effective_maturity		cva_effective_maturity,
		--t.cva_risk_weight		cva_risk_weight,
		--t.diversification_cva_ratio		diversification_cva_ratio,
		--t.diversified_cva_capital		diversified_cva_capital,
		t.correlation_factor		correlation_factor,
		t.in_default_ind_original		in_default_ind_original,
		--t.provision_amount_llp		provision_amount_llp,
		--t.provision_category_llp		provision_category_llp,
		t.sme_ind		sme_ind,
		t.risk_weight_add_on_factor		risk_weight_add_on_factor,
		t.risk_weight_add_on_term		risk_weight_add_on_term,
		t.risk_weight_factor_original		risk_weight_factor_original,
		t.basel_local_official_approach		basel_local_official_approach,
		--t.rwa_pre_sme_including_addonterm		rwa_pre_sme_including_addonterm,
		--t.rwa_including_addonterm		rwa_including_addonterm,
		t.gross_carrying_amt		gross_carrying_amt,
		t.residual_maturity_months		residual_maturity_months,
		t.residual_maturity_bucket_code		residual_maturity_bucket_code,
		t.ifrs_accounting_classification		ifrs_accounting_classification,
		t.ifrs_measurement_category		ifrs_measurement_category,
		t.rwa_including_addon		rwa_including_addon,
		t.rwa_pre_sme_including_addon		rwa_pre_sme_including_addon,
		t.rwa_add_on_report_classification		rwa_add_on_report_classification,
		t.sts_indicator		sts_indicator,
		t.sec_calculation_method		sec_calculation_method,
		t.sts_qualif_diff_treatment_ind		sts_qualif_diff_treatment_ind,
		t.capital_requirement_c_09_04		capital_requirement_c_09_04,
		t.exposure_at_default_c_09_04		exposure_at_default_c_09_04,
		t.zero_rrw_sov_indicator		zero_rrw_sov_indicator,
		t.strict_prudential_rw_ind		strict_prudential_rw_ind,
		t.strict_lgd_floor_ind		strict_lgd_floor_ind,
		t.rwa_ex_add_on		rwa_ex_add_on,
		t.rwa_pre_sme_fact_ex_add_on		rwa_pre_sme_fact_ex_add_on,
		--t.rw_dod_add_on_f_global_charge		rw_dod_add_on_f_global_charge,
		--t.rwa_add_on_for_dod		rwa_add_on_for_dod,
		--t.rwa_add_on_for_term_factor		rwa_add_on_for_term_factor,
		t.exposure_amount		exposure_amount,
		t.cover_key		cover_key,
		t.cover_type_key		cover_type_key,
		t.cover_provider_id		cover_provider_id,
		t.cover_provider_key		cover_provider_key,
		t.cover_ctry_key		cover_ctry_key,
		t.cover_ctry_code		cover_ctry_code,
		t.finrep_sector		finrep_sector,
		src1.cover_ctry_ec_ind		cover_ctry_ec_ind,
		--src2.next_review_date		next_review_date,
		--src2.principal_next_review_date		principal_next_review_date,
		--src2.econ_parent_review_date_bucket_key		econ_parent_review_date_bucket_key,
		--src2.legal_parent_review_date_bucket_key		legal_parent_review_date_bucket_key,
		src2.intercompany_code		intercompany_code,
		--src2.review_date_bucket_key		review_date_bucket_key,
		--src2.legal_ult_parent_risk_rating_key		legal_ult_parent_risk_rating_key,
		--src2.legal_ult_parent_risk_rating_owner_key		legal_ult_parent_risk_rating_owner_key,
		--src2.econ_ult_parent_risk_rating_key		econ_ult_parent_risk_rating_key,
		--src2.econ_ult_parent_risk_rating_owner_key		econ_ult_parent_risk_rating_owner_key,
		src2.legal_principal_ult_parent_id		legal_principal_ult_parent_id,
		src2.principal_borrower_id		principal_borrower_id,
		src2.ctry_of_incorporation_key		ctry_of_incorporation_key,
		src2.ctry_of_residence_key		ctry_of_residence_key,
		src2.customer_type_key		customer_type_key,
		src2.econ_ult_parent_id		econ_ult_parent_id,
		--src2.econ_ult_parent_key		econ_ult_parent_key,
		--src2.industry_type_key		industry_type_key,
		src2.segmentation_type_key		segmentation_type_key,
		--src2.worst_ctry_of_risk_key		worst_ctry_of_risk_key,
		src2.legal_ult_parent_id		legal_ult_parent_id,
		--src2.legal_ult_parent_key		legal_ult_parent_key,
		--src2.cust_status_key		cust_status_key,
		src2.booking_office_key		booking_office_key,
		src2.initiating_office_key		initiating_office_key,
		src2.mis_raroc_product_type_key		mis_raroc_product_type_key,
		src2.original_ccy_key		original_ccy_key,
		src2.risk_rating_key		risk_rating_key,
		--src2.risk_rating_owner_key		risk_rating_owner_key,
		src2.auth_combination_key		auth_combination_key,
		--src2.next_review_date_cdd		next_review_date_cdd,
		--src2.review_date_cdd_bucket_key		review_date_cdd_bucket_key,
		--src2.lup_review_date_cdd_bucket_key		lup_review_date_cdd_bucket_key,
		--src2.eup_review_date_cdd_bucket_key		eup_review_date_cdd_bucket_key,
		--src2.next_review_date_mifid		next_review_date_mifid,
		--src2.review_date_mifid_bucket_key		review_date_mifid_bucket_key,
		--src2.lup_review_date_mifid_bucket_key		lup_review_date_mifid_bucket_key,
		--src2.eup_review_date_mifid_bucket_key		eup_review_date_mifid_bucket_key,
		--src2.next_review_date_br		next_review_date_br,
		--src2.review_date_br_bucket_key		review_date_br_bucket_key,
		--src2.lup_review_date_br_bucket_key		lup_review_date_br_bucket_key,
		--src2.eup_review_date_br_bucket_key		eup_review_date_br_bucket_key,
		--src2.review_date_cdd_owner_key		review_date_cdd_owner_key,
		--src2.lup_review_date_cdd_owner_key		lup_review_date_cdd_owner_key,
		--src2.eup_review_date_cdd_owner_key		eup_review_date_cdd_owner_key,
		--src2.review_date_mifid_owner_key		review_date_mifid_owner_key,
		--src2.lup_review_date_mifid_owner_key		lup_review_date_mifid_owner_key,
		--src2.eup_review_date_mifid_owner_key		eup_review_date_mifid_owner_key,
		--src2.review_date_br_owner_key		review_date_br_owner_key,
		--src2.lup_review_date_br_owner_key		lup_review_date_br_owner_key,
		--src2.eup_review_date_br_owner_key		eup_review_date_br_owner_key,
		--src2.customer_type_cdd_key		customer_type_cdd_key,
		--src2.customer_type_mifid_key		customer_type_mifid_key,
		--src2.classification_mifid_key		classification_mifid_key,
		--src2.classification_mifid_code		classification_mifid_code,
		--src2.risk_level_cdd_key		risk_level_cdd_key,
		--src2.risk_level_cdd_code		risk_level_cdd_code,
		src2.ead_model_code		ead_model_code,
		t.lgd_model_code 		lgd_model_code,
		src2.ead_model_key		ead_model_key,
		src2.lgd_model_key		lgd_model_key,
		src2.accounting_unit_key 		os_accounting_unit_key,
		src2.ing_legal_entity_key 		os_ing_legal_entity_key,
		src2.product_type_key		product_type_key,
		--src2.segmentation_type_poland_key		segmentation_type_poland_key,
		--src2.segmentation_type_belgium_key		segmentation_type_belgium_key,
		--src2.segmentation_type_india_key		segmentation_type_india_key,
		--src2.segmentation_type_netherlands_key		segmentation_type_netherlands_key,
		--src2.segmentation_type_romania_key		segmentation_type_romania_key,
		--src2.segmentation_type_turkey_key		segmentation_type_turkey_key,
		src2.maximum_limit_amt maximum_limit_amt, --no need to split since deriving from facility_fact
		src2.booking_base_entity_key		booking_base_entity_key,
		src2.initiating_base_entity_key		initiating_base_entity_key,
		--src2.compliance_department_key		compliance_department_key,
		--src2.lup_compliance_department_key		lup_compliance_department_key,
		--src2.eup_compliance_department_key		eup_compliance_department_key,
		--src2.maintenance_unit_key		maintenance_unit_key,
		--src2.lup_maintenance_unit_key		lup_maintenance_unit_key,
		--src2.eup_maintenance_unit_key		eup_maintenance_unit_key,
		src2.local_outstanding_id		local_outstanding_id,
--		CASE
--			WHEN src2.generated_record = 'Y' THEN 1
--			WHEN src2.generated_record = 'N' THEN 0
--		END		generated_record,
		src2.secondary_currency_key		secondary_currency_key,
		src2.fac_accounting_unit_key		fac_accounting_unit_key,
		src2.fac_booking_office_key		fac_booking_office_key,
		src2.fac_ing_legal_entity_key		fac_ing_legal_entity_key,
		src2.fac_initiating_office_key		fac_initiating_office_key,
		--src2.fac_original_ccy_key		fac_original_ccy_key,
		src2.facility_purpose_key		facility_purpose_key,
		src2.facility_type_key		facility_type_key,
		src2.limit_end_date		limit_end_date,
		src2.orig_end_date		orig_end_date,
		src2.limit_start_date		limit_start_date,
		src2.orig_start_date		orig_start_date,
		src2.risk_rating_type		risk_rating_type,
		src2.cover_type_combination_key		cover_type_combination_key,
		src2.higher_level_facility_key		higher_level_facility_key,
		src2.limit_type_indicator		limit_type_indicator,
		--src2.segmentation_code_up_pb_hf		segmentation_code_up_pb_hf,
		src2.principal_borrower_key		principal_borrower_key,
		src2.fac_mis_raroc_product_type_key		fac_mis_raroc_product_type_key,
		CASE
			WHEN src2.multi_ccy_indicator = 'Y' THEN 1
			WHEN src2.multi_ccy_indicator = 'N' THEN 0
		END		multi_ccy_indicator,
--		CASE
--			WHEN src2.fac_generated_record = 'Y' THEN 1
--			WHEN src2.fac_generated_record = 'N' THEN 0
--		END		fac_generated_record,
		src2.higher_level_facility_id		higher_level_facility_id,
		src2.highest_level_facility_id		highest_level_facility_id,
		src2.fac_booking_base_entity_key		fac_booking_base_entity_key,
		src2.fac_initiating_base_entity_key		fac_initiating_base_entity_key,
		src2.security_id 		security_id,
		src2.security_id_type 		security_id_type,
		src2.exposure_class_code		exposure_class_code,
		src2.facility_hierarchy_level		facility_hierarchy_level,
		src2.maturity_date		maturity_date,
		src2.orig_maturity_date		orig_maturity_date,
		src2.bond_rating_agency_code		bond_rating_agency_code,
		src2.bond_rating_code		bond_rating_code,
		--src2.exchange_rate		exchange_rate,
		src2.maturity_date - t.record_valid_from		os_max_remaining_tenor,
		src2.limit_end_date - t.record_valid_from		fac_max_remaining_tenor,
		src5.master_scale_level4_code		master_scale_level4_code,
		src6.risk_rating_code		risk_rating_code,
		src7.country_code		ctry_of_residence_code,
		src8.country_code		ctry_of_incorporation_code,
		--src9.ctry_of_incorporation_key		ctry_of_incorp_pr_borr_key,
		--src10.country_code		ctry_of_incorp_pr_borr_code,
		src11.ctry_of_incorporation_key		ctry_of_incorp_guarantor_key,
		src12.country_code		ctry_of_incorp_guarantor_code,
		src13.risk_degree_key		risk_degree_key,
		src14.facility_type_code		facility_type_code,
		src15.facility_purpose_code		facility_purpose_code,
		src16.code		cover_type_code,
		CASE
			WHEN t.source_table IN (
				'IRB',
				'SEC'
			) THEN src16.cover_cluster_corep_irb
			WHEN t.source_table = 'SA' THEN src16.cover_cluster_corep_sa
		END 		corep_cover_cluster,
		src17.code		product_type_code,
		src17.pos_3		default_fund_contr_ind,
		--src17.qccp_initial_margin		qccp_initial_margin,
		src17.corep_counterparty_cluster		corep_counterparty_cluster,
		src17.lr_deriv_classification		lr_deriv_classification,
		src17.finrep_product_type		finrep_product_code,
		src18.risk_category_level1_code		risk_category_level1_code,
		src18.risk_category_level1_key		risk_category_level1_key,
		src19.code		booking_office_code,
		src20.code		initiating_office_code,
		--src21.code		fac_booking_office_code,
		--src22.code		fac_initiating_office_code,
		CASE WHEN t.securitisation_code is null then src23.securitisation_code else t.securitisation_code end securitisation_code,
		src24.code		rating_agency_code,
		--src25.code		rating_agency_sec_code,
		CASE
			WHEN t.sec_category IN (
				'O',
				'S',
				'I'
			) THEN 0
		END		credit_qual_step_sec_inc,
		ROWNUM		grouping_key,
		CASE
			WHEN t.credit_quality_step IS NULL THEN NULL
			WHEN t.credit_quality_step = 0 THEN 0
			ELSE 1
		END		with_cai_ind,
		CASE
			WHEN ( src17.corep_counterparty_cluster IN (
				'SECFIN',
				'DERIV'
			) ) THEN 1
			ELSE 0
		END 		counterparty_ind,
		--0		cva_cap_eligible_recap,
		CASE
			WHEN src19.office_key = src2.booking_office_key
				 AND t.source_table = 'SA' THEN src19.permanent_sa_ind
			WHEN t.source_table IN (
				'SA' --,
				--'IRB'
			) THEN 0
			WHEN t.source_table = 'IRB' THEN CASE WHEN t.risk_weight_substitution=1 AND t.applied_ind = 1 AND t.guar_ppu_sa_ind = 'Y' THEN 1 ELSE 0 END
		END		permanent_sa_ind,
		CASE WHEN ( t.basel_approach IN ('SA','SA_TR') OR t.source_table = 'SEC' ) AND t.risk_weight_substitution = 1 AND t.original_ind = 1 THEN t.exposure_net_provision_sa
			 ELSE t.outflow
		END		outflow,
		CASE WHEN ( t.basel_approach IN ('SA','SA_TR') OR t.source_table = 'SEC' ) AND t.original_ind = 1 THEN abs(original_cover_value)
			 ELSE t.original_cover_value_abs
		END		original_cover_value_abs,
		CASE
			WHEN t.applied_ind = 1
				 AND t.source_table = 'IRB'
				 AND t.sec_category IN (
				'I',
				'S',
				'O'
			) THEN t.allocated_limit_amt
			WHEN t.applied_ind = 1
				 AND t.source_table = 'SA'
				 AND ( t.fully_adjusted_exposure_on_sa IS NOT NULL
					   OR t.fully_adjusted_exposure_off_sa IS NOT NULL ) THEN nvl(t.fully_adjusted_exposure_on_sa,0) + nvl(t.fully_adjusted_exposure_off_sa
					  ,0)
			ELSE t.fully_adjusted_exposure
		END		fully_adjusted_exposure,
		CASE
			WHEN t.applied_ind = 1 THEN round(t.residual_value_risk_weight * t.residual_value_amount,2)
			ELSE t.residual_value_risk_weight_asset
		END		residual_value_risk_weight_asset,
		CASE WHEN t.applied_ind = 1 AND ( t.basel_approach IN ('SA','SA_TR') OR t.source_table = 'SEC' ) THEN abs(t.exposure_at_default) ELSE t.exposure_at_default_abs END		exposure_at_default_abs,
		CASE WHEN t.applied_ind = 1 AND ( t.basel_approach IN ('SA','SA_TR') OR t.source_table = 'SEC' ) THEN abs(t.residual_value_amount) ELSE t.residual_value_amount_abs END		residual_value_amount_abs,
		t.ccf_0percent,
		t.ccf_20percent,
		t.ccf_50percent,
		t.ccf_100percent ccf_100percent,
		CASE
			WHEN t.source_table = 'IRB'
				 AND t.applied_ind = 1 THEN
				 (CASE WHEN nvl(src2.maximum_limit_amt,0) = 0 THEN 0
			ELSE 0--t.e_factor
		END) END		e_factor_limit,
		CASE
			WHEN t.source_table = 'IRB'
				 AND t.applied_ind = 1 THEN
				 (CASE WHEN nvl(src2.maximum_limit_amt,0) = 0 THEN 0--t.e_factor --double check for this columns
			ELSE 0
		END) END		e_factor_os,
		src17.on_balance_sheet_ind		on_balance_sheet_ind,
		CASE
			WHEN t.exposure_original < 0 THEN 1
			ELSE 0
		END		negative_limit_ind,
		CASE
			WHEN t.g_factor = 0
				 AND t.source_table = 'IRB' THEN 0
			WHEN t.g_factor > 0
				 AND t.g_factor <= 0.2
				 AND t.source_table = 'IRB' THEN 0.2
			WHEN t.g_factor > 0.2
				 AND t.g_factor <= 0.5
				 AND t.source_table = 'IRB' THEN 0.5
			WHEN t.g_factor > 0.5
				 AND t.source_table = 'IRB' THEN 1
		END		sec_ccf_drawn_bucket,
		--t.g_factor * t.k_factor		gk_factor,
		CASE
			WHEN ( t.g_factor * t.k_factor ) = 0
				 AND t.source_table IN (
				'IRB',
				'SEC'
			) THEN 0
			WHEN ( t.g_factor * t.k_factor ) > 0
				 AND ( t.g_factor * t.k_factor ) <= 0.2
				 AND t.source_table IN (
				'IRB',
				'SEC'
			) THEN 0.2
			WHEN ( t.g_factor * t.k_factor ) > 0.2
				 AND ( t.g_factor * t.k_factor ) <= 0.5
				 AND t.source_table IN (
				'IRB',
				'SEC'
			) THEN 0.5
			WHEN ( t.g_factor * t.k_factor ) > 0.5
				 AND t.source_table IN (
				'IRB',
				'SEC'
			) THEN 1
		END		sec_ccf_undrawn_bucket,
		src17.lr_counterparty_cluster		lr_counterparty_cluster,
		src27.customer_type_code		customer_type_level3_code,
		0		lr_covered_bond_ind,
		0		trade_finance_ind,
		CASE
			WHEN src17.lr_counterparty_cluster = 'OTH'
				 AND t.on_balance_ind = 0
				 AND t.exposure_class NOT IN (
				'SEC',
				'SEC_SPON',
				'SEC_ORIG'
			) THEN 'OFFBAL'
			WHEN src17.lr_counterparty_cluster = 'DERIV'
				 AND t.exposure_class NOT IN (
				'SEC',
				'SEC_SPON',
				'SEC_ORIG'
			) THEN 'DERIV'
			WHEN src17.lr_counterparty_cluster = 'SFT' THEN 'SFT'
			ELSE 'OTH'
		END		lr_exposure_classification,
		src28.customer_cluster_exp_class_b4		lr_customer_type,
		t.exposure_weighted_avg_lgd		exposure_weighted_avg_lgd,
		t.k_a_parameter_w		k_a_parameter_w,
		t.k_irb		k_irb,
		t.k_sa		k_sa,
		t.ppu_sa_ind		ppu_sa_ind,
		t.risk_weight_excl_strict_prud		risk_weight_excl_strict_prud,
		t.rwa_pre_sme_fact_ex_strict_prud		rwa_pre_sme_fact_ex_strict_prud,
		t.rwa_ex_strict_prud		rwa_ex_strict_prud,
		t.subject_to_infra_factor_ind		subject_to_infra_factor_ind,
		t.risk_weight_asset_pre_infra_fact		risk_weight_asset_pre_infra_fact,
		--t.rwa_pre_infra_fct_ex_add_on		rwa_pre_infra_fct_ex_add_on,
		t.rwa_pre_infra_fct_ex_strict_prud		rwa_pre_infra_fct_ex_strict_prud,
		t.rwa_sme_support_amt		rwa_sme_support_amt,
		t.rwa_infra_support_amt		rwa_infra_support_amt,
		t.lgd_pre_cds		lgd_pre_cds,
		t.pd_original_after_multipliers		pd_original_after_multipliers,
		src29.branch_indicator 		branch_indicator,
		src29.legal_imm_parent_id 		legal_imm_parent_id,
		t.exposure_class_original		exposure_class_original,
		t.exposure_class_applied 		exposure_class_applied,
		t.large_exposure_sector		large_exposure_sector,
		t.ccr_replacement_cost		ccr_replacement_cost,
		t.ccr_addon		ccr_addon,
		t.ccr_potential_future_exp		ccr_potential_future_exp,
		t.ccr_exp_value_pre_crm		ccr_exp_value_pre_crm,
		t.ccr_exp_value_post_crm		ccr_exp_value_post_crm,
		t.lre_ccr_replacement_cost		lre_ccr_replacement_cost,
		t.ccr_variation_margin		ccr_variation_margin,
		t.lre_ccr_variation_margin		lre_ccr_variation_margin,
		t.ccr_net_indep_collat_amt		ccr_net_indep_collat_amt,
		0		eca_indicator,
		CASE WHEN CASE  WHEN t.source_table IN ( 'IRB', 'SEC' ) THEN src16.cover_cluster_corep_irb  WHEN t.source_table = 'SA' THEN src16.cover_cluster_corep_sa END IN ( 'COM_PROP' ) THEN 1 ELSE 0 END               		secured_by_com_prop_ind,
		0		secured_by_res_prop_ind,
		0		cdspb_facility_ind,
		0		local_official_approach_indicator,
		--0		finan_guarantee_given_ind,
		--0		days_past_due,
		--0		secured_by_com_prop_os_ind,
		--0		secured_by_res_prop_os_ind,
		--0		secured_by_non_mort_os_ind,
		0		default_fund_ind,
		0		ccr_wrong_way_risk_indicator,
		0		observed_new_default_ip_ind,
		0		observed_new_default_ind,
		--0		cva_amount,
		--0		dva_amount,
		0		incurredcva_amount,
		t.risk_weight_factor_macro_prud		risk_weight_factor_macro_prud,
		t.rwa_pre_sme_fact_macro_prud		rwa_pre_sme_fact_macro_prud,
		t.rwa_pre_infra_fact_macro_prud		rwa_pre_infra_fact_macro_prud,
		t.rwa_macro_prud		rwa_macro_prud,
		--t.macro_prud_rw_ltv  		macro_prud_rw_ltv,
		t.leverage_sme_ind 		leverage_sme_ind,
		v_reporting_date		reporting_date,
		t.risk_weight_asset_orig_obligor  		risk_weight_asset_orig_obligor,
		t.risk_weight_asset_sec_erba 		risk_weight_asset_sec_erba,
		t.risk_weight_asset_sec_sa    		risk_weight_asset_sec_sa,
		t.substitution_method 		substitution_method,
		t.rw_substitution_method 		rw_substitution_method,
		--t.rw_floor 		rw_floor,
		t.official_approach_applied 		official_approach_applied,
		t.risk_weighted_assets_pre_cds 		risk_weighted_assets_pre_cds,
        t.risk_weight_asset_sec_tr risk_weight_asset_sec_tr,
        t.ead_exclusion_ind,
        t.configuration_code,
        t.condition_outcome_code,
        t.ccf_10percent,
        t.ccf_40percent,
        t.COVER_SPLIT_KEY,
        t.property_ratio_from,
        t.property_ratio_until,
        t.EAD_RATIO,
        t.COLLATERALISATION_RATIO,
        t.exposure_class_irb_in_sa,
        t.exposure_class_sa_in_irb,
        t.res_imm_prop_ind,
        t.com_imm_prop_ind,
        t.regulatory_large_corp_ind,
		t.ccf_ucc_transitional 	,
		t.rwa_non_ccf_ucc_trans ,
        t.SPLIT_RATIO,
        t.ucc_non_trans_on_balance_ratio_exposure,
        t.ucc_non_trans_conversion_ratio_exposure,
		t.basel_approach_original,
		t.ccf_100percent_irb,
		t.regulatory_ead_applied,
        t.exposure_class_sa_original,
        t.risk_weight_asset_pre_fx_mm,
		t.risk_weight_factor_pre_fx_mm,
        t.conversion_ratio_exp_pre_ccf,
		t.loan_split_derogation_ind,
		t.risk_weight_art378,
		t.exposure_amount_art378,
		t.rwa_art378,
		t.book_risk_category,
		t.settlement_date,
		t.days_unsettled_after_due_date,
		t.settlement_amount,
		t.unsecuritised_factor,
		t.sec_pro_rata_factor,
        t.official_challenger_indicator,
		t.on_balance_ratio_exp_pre_ccf,
		t.modelled_ccf,
		t.inscription_value
    FROM
        TT_tmp_corep_recap_measure_b4 t
        LEFT OUTER JOIN (
            SELECT DISTINCT
                c.cover_key,
                c.outstanding_group_key,
                CASE
                    WHEN ctry.ec_indicator = 'Y' THEN 1
                    ELSE 0
                END AS cover_ctry_ec_ind
            FROM
                TMP_COREP_VRE_COVER_RECAP_B4 c,
                country ctry
            WHERE
                c.country_key = ctry.country_key
        ) src1 ON ( src1.cover_key = t.cover_key
                    AND src1.outstanding_group_key = t.outstanding_group_key )
        LEFT OUTER JOIN tmp_corep_basic_info_b4 src2 ON ( src2.outstanding_group_key = t.outstanding_group_key )

          LEFT OUTER JOIN (
              SELECT
                master_scale_level4_code,
                risk_rating_key
            FROM
                dm_risk_rating
        ) src5 ON ( t.rating_key = src5.risk_rating_key )
        LEFT OUTER JOIN (
            SELECT
                risk_rating_key,
                risk_rating_code
            FROM
                dm_risk_rating
        ) src6 ON ( src2.risk_rating_key = src6.risk_rating_key )
        LEFT OUTER JOIN (
            SELECT
                country_key,
                code country_code
            FROM
                country
        ) src7 ON ( src2.ctry_of_residence_key = src7.country_key )
        LEFT OUTER JOIN (
            SELECT
                country_key,
                code country_code
            FROM
                country
        ) src8 ON ( src2.ctry_of_incorporation_key = src8.country_key )
        LEFT OUTER JOIN tt_dmi_corep_customer src9 ON ( src2.principal_borrower_key = src9.customer_key )
        LEFT OUTER JOIN (
            SELECT
                country_key,
                code country_code
            FROM
                country
        ) src10 ON ( src9.ctry_of_incorporation_key = src10.country_key )
        LEFT OUTER JOIN tt_dmi_corep_customer src11 ON ( t.cover_provider_key = src11.customer_key )
        LEFT OUTER JOIN (
            SELECT
                country_key,
                code country_code
            FROM
                country
        ) src12 ON ( src11.ctry_of_incorporation_key = src12.country_key )
        LEFT OUTER JOIN (
            SELECT
                risk_degree_code,
                record_valid_from,
                record_valid_until,
                risk_degree_key
            FROM
                dmi_securitisation_risk_degree
        ) src13 ON ( src13.risk_degree_code = t.risk_degree_code
                     AND src13.record_valid_from <= t.record_valid_from
                     AND nvl(src13.record_valid_until,utilities.record_default_date) > t.record_valid_from )
        LEFT OUTER JOIN (
            SELECT
                facility_type_key,
                facility_type_code
            FROM
                dm_facility_type
        ) src14 ON ( src14.facility_type_key = src2.facility_type_key )
        LEFT OUTER JOIN (
            SELECT
                facility_purpose_key,
                facility_purpose_code
            FROM
                dm_facility_purpose
        ) src15 ON ( src2.facility_purpose_key = src15.facility_purpose_key )
        LEFT OUTER JOIN (
            SELECT
                cc.cover_cluster_corep_irb,
                cc.cover_cluster_corep_sa,
                cc.cover_type,
                c.cover_type_key,
                c.code
            FROM
                cover_type c,
                cover_type_cluster cc
            WHERE
                c.code = cc.cover_type
                AND cc.record_valid_from <= c.record_valid_from
                AND nvl(cc.record_valid_until,utilities.record_default_date) > c.record_valid_from
        ) src16 ON ( src16.cover_type_key = t.cover_type_key )
        LEFT OUTER JOIN (
            SELECT
                f.qccp_initial_margin,
                f.corep_counterparty_cluster,
                f.lr_deriv_classification,
                f.facility_type_key,
                f.code,
                CASE
                    WHEN nvl(f.qccp_default_fund,'N') = 'Y' THEN 1
                    ELSE 0
                END AS pos_3,
                finrep_product_type,
                CASE
                    WHEN on_balance_sheet_indicator = 'Y' THEN 1
                    ELSE 0
                END AS on_balance_sheet_ind,
                lr_counterparty_cluster
            FROM
                facility_type f
        ) src17 ON ( src17.facility_type_key = src2.product_type_key )
        LEFT OUTER JOIN (
            SELECT
                risk_category_level1_key,
                risk_category_level1_code,
                facility_type_key
            FROM
                dm_facility_type
        ) src18 ON ( src18.facility_type_key = src2.product_type_key )
        LEFT OUTER JOIN (
            SELECT
                code,
                office_key,
                CASE
                    WHEN permanent_sa = 'Y' THEN 1
                    ELSE 0
                END AS permanent_sa_ind
            FROM
                office
        ) src19 ON ( src19.office_key = src2.booking_office_key )
        LEFT OUTER JOIN (
            SELECT
                code,
                office_key
            FROM
                office
        ) src20 ON ( src20.office_key = src2.initiating_office_key )
        LEFT OUTER JOIN (
            SELECT
                code,
                office_key
            FROM
                office
        ) src21 ON ( src21.office_key = src2.fac_booking_office_key )
        LEFT OUTER JOIN (
            SELECT
                code,
                office_key
            FROM
                office
        ) src22 ON ( src22.office_key = src2.fac_initiating_office_key )
        LEFT OUTER JOIN (
            SELECT
                securitisation_legal_entity_key securitisation_key,
                code securitisation_code
            FROM
                securitisation_legal_entity
        ) src23 ON ( src23.securitisation_key = t.securitisation_key )
        LEFT OUTER JOIN (
            SELECT
                rating_agency_key,
                code
            FROM
                rating_agency
        ) src24 ON ( src24.rating_agency_key = t.rating_agency_key )
        /*LEFT OUTER JOIN (
            SELECT
                rating_agency_key,
                code
            FROM
                rating_agency
        ) src25 ON ( src25.rating_agency_key = t.rating_agency_sec_key )*/
        LEFT OUTER JOIN (
            SELECT
                code customer_type_code,
                customer_type_key
            FROM
                customer_type
        ) src27 ON ( src2.customer_type_key = src27.customer_type_key )
        LEFT OUTER JOIN (
            SELECT
                customer_type,
                record_valid_from,
                record_valid_until,
                customer_cluster_exp_class_b4
            FROM
                customer_type_cluster
        ) src28 ON ( src27.customer_type_code = src28.customer_type
                     AND src28.record_valid_from <= t.record_valid_from
                     AND nvl(src28.record_valid_until,utilities.record_default_date) > t.record_valid_from )
         LEFT OUTER JOIN tt_dmi_corep_customer src29 ON ( t.customer_key = src29.customer_key );

COMMIT;
schema_maint.gather_idx_stats('tmp_corep_recap_measure_pre_b4');

   insert_dmb_log_corep(v_detail_level => 103,
                                v_log_descr => 'process_pre_corep_recap_b4',
                                v_activity_code => 'Upd Cover2',
                                v_result_code => 'FINOK',
                                v_system_id       => v_system_id,v_reporting_date       => v_reporting_date) ;

   ----------------------------------------------------------------------------------------------
   -- Retrieve attributes from the dmi_credit_risk_measure_og table
   ----------------------------------------------------------------------------------------------
   insert_dmb_log_corep(v_detail_level => 103,
                                  v_log_descr => 'process_pre_corep_recap_b4',
                                  v_activity_code => 'Upd CRM',
                                  v_result_code => 'START',
                                  v_system_id       => v_system_id,v_reporting_date       => v_reporting_date) ;

   insert_dmb_log_corep(v_detail_level => 103,
                                v_log_descr => 'process_pre_corep_recap_b4',
                                v_activity_code => 'Upd CRM',
                                v_result_code => 'FINOK',
                                v_system_id       => v_system_id,v_reporting_date       => v_reporting_date) ;

   insert_dmb_log_corep(v_detail_level => 103,
                                v_log_descr => 'process_pre_corep_recap_b4',
                                v_activity_code => 'Tenors',
                                v_result_code => 'START',
                                v_system_id       => v_system_id,v_reporting_date       => v_reporting_date) ;

   insert_dmb_log_corep(v_detail_level => 103,
                                  v_log_descr => 'process_pre_corep_recap_b4',
                                  v_activity_code => 'Tenors',
                                  v_result_code => 'FINOK',
                                  v_system_id       => v_system_id,v_reporting_date       => v_reporting_date) ;

   insert_dmb_log_corep(v_detail_level => 103,
                                  v_log_descr => 'process_pre_corep_recap_b4',
                                  v_activity_code => 'ISIN Code',
                                  v_result_code => 'START',
                                  v_system_id       => v_system_id,v_reporting_date       => v_reporting_date) ;

    utilities.truncate_table('TMP_COREP_ISIN_VPP');
    BEGIN
        INSERT  /*+ APPEND */ INTO TMP_COREP_ISIN_VPP ( outstanding_group_key, security_id, security_id_type )
        WITH bloomberg AS (
         SELECT DISTINCT t.outstanding_group_key, t.record_valid_from, s.bloomberg_code
         FROM tmp_corep_recap_measure_pre_b4 t
         INNER JOIN scs_combined_security_data s ON (t.security_id = s.security_id AND t.security_id_type = s.security_id_type AND s.record_valid_from <= t.record_valid_from
         AND (s.record_valid_until > t.record_valid_from OR s.record_valid_until IS NULL ))
         WHERE s.security_id_type <> 'ISIN' )
        SELECT t.outstanding_group_key, s.security_id, s.security_id_type
        FROM bloomberg t
        INNER JOIN scs_combined_security_data s ON (t.bloomberg_code = s.bloomberg_code AND s.record_valid_from <= t.record_valid_from
        AND (s.record_valid_until > t.record_valid_from OR s.record_valid_until IS NULL ))
        WHERE s.security_id_type = 'ISIN';
    EXCEPTION
        WHEN OTHERS THEN utils.handleerror(sqlcode,sqlerrm);
    END;

    COMMIT;
    schema_maint.gather_idx_stats('TMP_COREP_ISIN_VPP');


   insert_dmb_log_corep(v_detail_level => 103,
                                v_log_descr => 'process_pre_corep_recap_b4',
                                v_activity_code => 'ISIN Code',
                                v_result_code => 'FINOK',
                                v_system_id       => v_system_id,v_reporting_date       => v_reporting_date) ;
   insert_dmb_log_corep(v_detail_level => 103,
                                v_log_descr => 'process_pre_corep_recap_b4',
                                v_activity_code => 'Upd Codes',
                                v_result_code => 'START',
                                v_system_id       => v_system_id,v_reporting_date       => v_reporting_date) ;

COMMIT;
    ----------------------------------------------------------------------------------------------
    -- eca indicator - STRY1887670
    ----------------------------------------------------------------------------------------------

 UPDATE tmp_corep_recap_measure_pre_b4 t
   SET t.eca_indicator = 1
 WHERE  EXISTS ( SELECT 1
                 FROM cover_type ct1
                  WHERE  ct1.cover_type_key = t.cover_type_key
                           AND ct1.highest_level_key IN ( SELECT ct2.cover_type_key
                                                          FROM cover_type ct2
                                                           WHERE  ct2.code = 'ECA'
                                                                    AND ct2.record_valid_from <= ct1.record_valid_from
                                                                    AND ( ct2.record_valid_until > ct1.record_valid_from
                                                                    OR ct2.record_valid_until IS NULL ) ));

COMMIT;

   --JT not changing due to lack of joininh columns
   MERGE /*+ ENABLE_PARALLEL_DML +*/ INTO tmp_corep_recap_measure_pre_b4 t1 USING
   ( SELECT t.ROWID row_id
    FROM clearinghouse ch ,facility_type ft ,tmp_corep_recap_measure_pre_b4 t
    WHERE ch.code = CAST(t.customer_id AS VARCHAR2(30 CHAR))
    AND ch.record_valid_from <= t.record_valid_from
    AND ( ch.record_valid_until > t.record_valid_from OR ch.record_valid_until IS NULL)
    AND t.product_type_key = ft.facility_type_key
    AND ft.qccp_default_fund = 'P') src
   ON ( t1.ROWID = src.row_id )
   WHEN MATCHED THEN UPDATE SET t1.default_fund_contr_ind = 1;
  COMMIT;

   --JT Query tune for performance issue
    MERGE /*+ enable_parallel_dml */ INTO tmp_corep_recap_measure_pre_b4 rm
    USING (SELECT  t.ROWID row_id, sle.credit_qual_step_sec_inc
    FROM tmp_corep_recap_measure_pre_b4 t ,securitisation_tranche sle
        WHERE t.sec_category = 'O'
              AND sle.facility_id = t.facility_id
              AND sle.system_id_retained_position = t.system_id
              AND sle.record_valid_from <= t.record_valid_from
              AND ( sle.record_valid_until > t.record_valid_from
            OR sle.record_valid_until IS NULL )) src
            ON ( rm.ROWID = src.row_id )
        WHEN MATCHED THEN UPDATE SET rm.credit_qual_step_sec_inc = src.credit_qual_step_sec_inc;
    COMMIT;
    --JT Query tune for performance issue
    MERGE /*+ enable_parallel_dml */ INTO tmp_corep_recap_measure_pre_b4 rm
    USING (SELECT  t.ROWID row_id, sle.credit_qual_step_sec_inc
            FROM tmp_corep_recap_measure_pre_b4 t ,securitisation_sponsor sle
            WHERE t.sec_category = 'S'
                AND cast(sle.code as number(12)) = t.customer_id
                AND sle.record_valid_from <= t.record_valid_from
                AND ( sle.record_valid_until > t.record_valid_from OR sle.record_valid_until IS NULL )) src
      ON ( rm.ROWID = src.row_id )
    WHEN MATCHED THEN UPDATE SET rm.credit_qual_step_sec_inc = src.credit_qual_step_sec_inc;

    COMMIT;
    --JT Query tune for performance issue
    MERGE INTO tmp_corep_recap_measure_pre_b4 rm
    USING (SELECT t.ROWID row_id, max(sle.credit_qual_step_sec_inc) as credit_qual_step_sec_inc
    FROM tmp_corep_recap_measure_pre_b4 t,securitisation_investor sle
        WHERE t.sec_category = 'I'
              AND cast(sle.code as number(12)) = t.customer_id
              AND sle.record_valid_from <= t.record_valid_from
              AND ( sle.record_valid_until > t.record_valid_from
      OR sle.record_valid_until IS NULL )group by t.ROWID ) src
    ON ( rm.ROWID = src.row_id )
    WHEN MATCHED THEN UPDATE SET rm.credit_qual_step_sec_inc = src.credit_qual_step_sec_inc;

    v_debug_msg := $$plsql_line || ' of plsql unit ' || $$plsql_unit ||' '|| systimestamp ||' Rows Affected:- '||SQL%ROWCOUNT;
    utilities.show_debug(v_debug_msg);
    COMMIT;
insert_dmb_log_corep(v_detail_level => 103,
                                v_log_descr => 'process_pre_corep_recap_b4',
                                v_activity_code => 'Upd Codes',
                                v_result_code => 'FINOK',
                                v_system_id       => v_system_id,v_reporting_date       => v_reporting_date) ;


insert_dmb_log_corep(v_detail_level => 103,
                                v_log_descr => 'process_pre_corep_recap_b4',
                                v_activity_code => 'Newcolumnupdate',
                                v_result_code => 'start',
                                v_system_id       => v_system_id,v_reporting_date       => v_reporting_date) ;

		MERGE INTO (select settlement_date,outstanding_key,book_risk_category from tmp_corep_recap_measure_pre_b4) target
		USING (
		SELECT T1.code,t2.outstanding_key,t2.settlement_date
		FROM book_risk_category t1 RIGHT JOIN dwh_outstanding t2 ON T1.book_risk_category_key = T2.book_risk_category_key
		Where  t2.System_id = v_system_id
		AND t2.record_valid_from <= V_REPORTING_DATE
        AND V_REPORTING_DATE < NVL(t2.record_valid_until,utilities.record_default_date)
		) source
		ON (target.outstanding_key = source.outstanding_key )
		WHEN MATCHED THEN
		UPDATE SET target.book_risk_category = source.code,
				   target.settlement_date = source.settlement_date;
		COMMIT;

insert_dmb_log_corep(v_detail_level => 103,
                                v_log_descr => 'process_pre_corep_recap_b4',
                                v_activity_code => 'update Done',
                                v_result_code => 'FinOk',
                                v_system_id       => v_system_id,v_reporting_date       => v_reporting_date) ;

   -------------------------------------------------------------------------
   -- Generate the regulator combinations
   -------------------------------------------------------------------------
   insert_dmb_log_corep(v_detail_level => 103,
                                v_log_descr => 'process_pre_corep_recap_b4',
                                v_activity_code => 'Regul comb',
                                v_result_code => 'START',
                                v_system_id       => v_system_id,v_reporting_date       => v_reporting_date) ;


   BEGIN
	   process_pre_corep_reg_com_b4();
	   EXCEPTION
		  WHEN OTHERS THEN
		  UTILS.HANDLEERROR(SQLCODE,SQLERRM);
	 END;
	 COMMIT;

 	 BEGIN
	   process_corep_reg_com_b4();
	   EXCEPTION
		  WHEN OTHERS THEN
		  UTILS.HANDLEERROR(SQLCODE,SQLERRM);
	 END;
	 COMMIT;

   insert_dmb_log_corep(v_detail_level => 103,
                                v_log_descr => 'process_pre_corep_recap_b4',
                                v_activity_code => 'Regul comb',
                                v_result_code => 'FINOK',
                                v_system_id       => v_system_id,v_reporting_date       => v_reporting_date) ;


   insert_dmb_log_corep(v_detail_level    => 103,
                                   v_log_descr       => 'process_pre_corep_recap_b4',
                                   v_activity_code   => 'SECUR',
                                   v_result_code     => 'START',
                                   v_system_id       => v_system_id,v_reporting_date       => v_reporting_date
                                   );

    --JT Query tune for performance issue
    MERGE /*+ enable_parallel_dml */ INTO (SELECT facility_id,securitisation_code,record_valid_from,seniority_basel_class FROM tmp_corep_recap_measure_pre_b4 WHERE exposure_class = 'SEC_ORIG' ) t USING
    (SELECT facility_id,securitisation_code,record_valid_from,record_valid_until,seniority_basel_class
     FROM securitisation_tranche
     --WHERE record_valid_until IS NULL  --STSK5288430 issue fixed by commenting wrong code in where condition.
    ) src
    ON (t.facility_id = src.facility_id AND t.securitisation_code = src.securitisation_code AND src.record_valid_from <= t.record_valid_from
        AND NVL(src.record_valid_until,utilities.record_default_date)  > t.record_valid_from )
    WHEN MATCHED THEN UPDATE SET t.seniority_basel_class = src.seniority_basel_class;
    COMMIT;


    --JT Query tune for performance issue
    MERGE /*+ enable_parallel_dml */ INTO ( SELECT record_valid_from,securitisation_sponsor_key,customer_id,seniority_basel_class FROM tmp_corep_recap_measure_pre_b4 WHERE sec_category = 'S') t USING
    (SELECT securitisation_sponsor_key,code,record_valid_from,record_valid_until,seniority_basel_class
     FROM securitisation_sponsor
    ) src
    ON (src.code = CAST(t.customer_id AS VARCHAR2(10 CHAR)) AND t.record_valid_from >= src.record_valid_from
         AND t.record_valid_from < NVL(src.record_valid_until,utilities.record_default_date))
    WHEN MATCHED THEN UPDATE SET t.securitisation_sponsor_key = src.securitisation_sponsor_key,
                                 t.seniority_basel_class =src.seniority_basel_class; -- added missing code for data mismatch issue SD
    COMMIT;

    MERGE/*+ enable_parallel_dml */ INTO tmp_corep_recap_measure_pre_b4 t USING
    (SELECT t.rowid row_id,max(i.securitisation_investor_key) securitisation_investor_key,max(i.seniority_basel_class) seniority_basel_class
     FROM securitisation_investor i,tmp_corep_recap_measure_pre_b4 t
     WHERE --t.security_id = i.security_id    --Added This condition As per RRD BA's Mail Task no.- STSK5497791
     --AND
     t.sec_category = 'I'
     AND i.code = CAST(t.customer_id AS VARCHAR2(10 CHAR))
     AND t.record_valid_from >= i.record_valid_from
     AND (t.record_valid_from < nvl(i.record_valid_until,utilities.record_default_date) )
     GROUP BY t.rowid
     ) src
    ON ( t.rowid = src.row_id )
    WHEN MATCHED THEN UPDATE SET t.securitisation_investor_key = src.securitisation_investor_key,
                                 t.seniority_basel_class =src.seniority_basel_class;-- added missing code for data mismatch issue SD

    v_debug_msg := $$plsql_line|| ' of plsql unit '|| $$plsql_unit|| ' '|| systimestamp|| ' Rows Affected:- '|| SQL%rowcount;
    utilities.show_debug(v_debug_msg);

    COMMIT;

    insert_dmb_log_corep(v_detail_level    => 103,
                                   v_log_descr       => 'process_pre_corep_recap_b4',
                                   v_activity_code   => 'SECUR',
                                   v_result_code     => 'FINOK',
                                   v_system_id       => v_system_id,v_reporting_date       => v_reporting_date
                                  );

   ----------------------------------------------------------------------------------------------
   -- Indicator values
   ----------------------------------------------------------------------------------------------
   insert_dmb_log_corep(v_detail_level => 103,
                                v_log_descr => 'process_pre_corep_recap_b4',
                                v_activity_code => 'Indicator',
                                v_result_code => 'START',
                                v_system_id       => v_system_id,v_reporting_date       => v_reporting_date) ;


   UPDATE /*+ enable_parallel_dml */ tmp_corep_recap_measure_pre_b4
   SET secured_by_com_prop_ind = 1
   WHERE  corep_cover_cluster IN ('RES_PROP')
   AND outstanding_group_key IN (SELECT tmp_corep_recap_measure_pre_b4.outstanding_group_key
                                 FROM tmp_corep_recap_measure_pre_b4
                                 WHERE  tmp_corep_recap_measure_pre_b4.secured_by_com_prop_ind = 1 );
   COMMIT;

   UPDATE /*+ enable_parallel_dml */ tmp_corep_recap_measure_pre_b4
      SET secured_by_res_prop_ind = 1
    WHERE  corep_cover_cluster IN ( 'RES_PROP' )
     AND outstanding_group_key NOT IN ( SELECT tmp_corep_recap_measure_pre_b4.outstanding_group_key
                                        FROM tmp_corep_recap_measure_pre_b4
                                         WHERE  tmp_corep_recap_measure_pre_b4.secured_by_com_prop_ind = 1 );
    COMMIT;

    ------------------------------------------oramig cu6 start
    	--  update using PPU_SA_IND
    UPDATE /*+ enable_parallel_dml */ tmp_corep_recap_measure_pre_b4
    SET permanent_sa_ind = 1
    WHERE source_table = 'SA'
    AND   ppu_sa_ind = 1
    AND   permanent_sa_ind = 0;
COMMIT;
    -------------------------------------------oramig cu6 end

   insert_dmb_log_corep(v_detail_level => 103,
                                v_log_descr => 'process_pre_corep_recap_b4',
                                v_activity_code => 'Indicator',
                                v_result_code => 'FINOK',
                                v_system_id       => v_system_id,v_reporting_date       => v_reporting_date) ;
   ----------------------------------------------------------------------------------------------
   -- Original updates
   ----------------------------------------------------------------------------------------------
   insert_dmb_log_corep(v_detail_level => 103,
                                v_log_descr => 'process_pre_corep_recap_b4',
                                v_activity_code => 'Orig amt',
                                v_result_code => 'START',
                                v_system_id       => v_system_id,v_reporting_date       => v_reporting_date) ;

   insert_dmb_log_corep(v_detail_level => 103,
                                v_log_descr => 'process_pre_corep_recap_b4',
                                v_activity_code => 'Orig amt',
                                v_result_code => 'FINOK',
                                v_system_id       => v_system_id,v_reporting_date       => v_reporting_date) ;
   ----------------------------------------------------------------------------------------------
   -- Applied updates
   ----------------------------------------------------------------------------------------------
   insert_dmb_log_corep(v_detail_level => 103,
                                v_log_descr => 'process_pre_corep_recap_b4',
                                v_activity_code => 'Appl amt',
                                v_result_code => 'START',
                                v_system_id       => v_system_id,v_reporting_date       => v_reporting_date) ;


   insert_dmb_log_corep(v_detail_level    => 103,
                                  v_log_descr       => 'process_pre_corep_recap_b4',
                                  v_activity_code   => 'Appl amt',
                                  v_result_code     => 'FINOK',
                                  v_system_id       => v_system_id,v_reporting_date       => v_reporting_date
                                  );

    insert_dmb_log_corep(v_detail_level    => 103,
                                   v_log_descr       => 'process_pre_corep_recap_b4',
                                   v_activity_code   => 'Perf. bits',
                                   v_result_code     => 'START',
                                   v_system_id       => v_system_id,v_reporting_date       => v_reporting_date
                                   );

    insert_dmb_log_corep(
        v_detail_level    => 103,
        v_log_descr       => 'process_pre_corep_recap_b4',
        v_activity_code   => 'Perf. bits',
        v_result_code     => 'FINOK',
        v_system_id       => v_system_id,v_reporting_date       => v_reporting_date
    );

    insert_dmb_log_corep(
        v_detail_level    => 103,
        v_log_descr       => 'process_pre_corep_recap_b4',
        v_activity_code   => 'ob_sheet_ind',
        v_result_code     => 'START',
        v_system_id       => v_system_id,v_reporting_date       => v_reporting_date
    );

    insert_dmb_log_corep(
        v_detail_level    => 103,
        v_log_descr       => 'process_pre_corep_recap_b4',
        v_activity_code   => 'ob_sheet_ind',
        v_result_code     => 'FINOK',
        v_system_id       => v_system_id,v_reporting_date       => v_reporting_date
    );

    insert_dmb_log_corep(
        v_detail_level    => 103,
        v_log_descr       => 'process_pre_corep_recap_b4',
        v_activity_code   => 'updateccfirb',
        v_result_code     => 'START',
        v_system_id       => v_system_id,v_reporting_date       => v_reporting_date
    );

    insert_dmb_log_corep(
        v_detail_level    => 103,
        v_log_descr       => 'process_pre_corep_recap_b4',
        v_activity_code   => 'updateccfirb',
        v_result_code     => 'START',
        v_system_id       => v_system_id,v_reporting_date       => v_reporting_date
    );


    insert_dmb_log_corep(
        v_detail_level    => 103,
        v_log_descr       => 'process_pre_corep_recap_b4',
        v_activity_code   => 'correct SA PS',
        v_result_code     => 'START',
        v_system_id       => v_system_id,v_reporting_date       => v_reporting_date
    );


    insert_dmb_log_corep(
        v_detail_level    => 103,
        v_log_descr       => 'process_pre_corep_recap_b4',
        v_activity_code   => 'correct SA PS',
        v_result_code     => 'FINOK',
        v_system_id       => v_system_id,v_reporting_date       => v_reporting_date
    );

    insert_dmb_log_corep(
        v_detail_level    => 103,
        v_log_descr       => 'process_pre_corep_recap_b4',
        v_activity_code   => 'ccf_drawn_b',
        v_result_code     => 'START',
        v_system_id       => v_system_id,v_reporting_date       => v_reporting_date
    );



    insert_dmb_log_corep(
        v_detail_level    => 103,
        v_log_descr       => 'process_pre_corep_recap_b4',
        v_activity_code   => 'ccf_drawn_b',
        v_result_code     => 'FINOK',
        v_system_id       => v_system_id,v_reporting_date       => v_reporting_date
    );

    insert_dmb_log_corep(
        v_detail_level    => 103,
        v_log_descr       => 'process_pre_corep_recap_b4',
        v_activity_code   => 'ccf_undrawn',
        v_result_code     => 'START',
        v_system_id       => v_system_id,v_reporting_date       => v_reporting_date
    );


    insert_dmb_log_corep(v_detail_level    => 103,
                                   v_log_descr       => 'process_pre_corep_recap_b4',
                                   v_activity_code   => 'ccf_undrawn',
                                   v_result_code     => 'FINOK',
                                   v_system_id       => v_system_id,v_reporting_date       => v_reporting_date
                                   );

    insert_dmb_log_corep(v_detail_level    => 103,
                                   v_log_descr       => 'process_pre_corep_recap_b4',
                                   v_activity_code   => 'lev_ratio',
                                   v_result_code     => 'START',
                                   v_system_id       => v_system_id,v_reporting_date       => v_reporting_date
                                   );

    --JT Query tune for performance issue
    commit; ----added by sd
    MERGE /*+ enable_parallel_dml */ INTO (SELECT product_type_key,record_valid_from,lr_covered_bond_ind FROM tmp_corep_recap_measure_pre_b4 ) t USING
    (SELECT pt.facility_type_key,c.record_valid_until,c.record_valid_from
     FROM facility_type pt,product_type_cluster c
     WHERE pt.code = c.product_type
     AND c.product_cluster_exp_class_b4 = 'COVBOND'
    )src
    ON (t.product_type_key = src.facility_type_key AND src.record_valid_from <= t.record_valid_from AND NVL(src.record_valid_until,utilities.record_default_date) > t.record_valid_from)
    WHEN MATCHED THEN UPDATE SET t.lr_covered_bond_ind = 1;
    COMMIT;


    --JT Query tune for performance issue
    MERGE /*+ enable_parallel_dml */ INTO (SELECT product_type_key,record_valid_from,trade_finance_ind FROM tmp_corep_recap_measure_pre_b4 ) t USING
    (SELECT pt.facility_type_key,c.record_valid_until,c.record_valid_from
     FROM facility_type pt,product_type_cluster c
     WHERE pt.code = c.product_type
     AND c.product_cluster_b2_ste = 'TRFIN') src
    ON (t.product_type_key = src.facility_type_key AND src.record_valid_from <= t.record_valid_from AND NVL(src.record_valid_until,utilities.record_default_date) > t.record_valid_from )
    WHEN MATCHED THEN UPDATE SET t.trade_finance_ind = 1;
   COMMIT;


    -- lr_exposure_type SA

    UPDATE /*+ enable_parallel_dml */ tmp_corep_recap_measure_pre_b4
    SET lr_exposure_type =

    case when in_default_ind = 1 OR exposure_class IN (select BASEL4_EXPOSURE_CLASS_SA_CODE
	from dm_interm_basel4_exp_class_sa_corep where INTERMEDIATE_PARENT_CODE in 'IN_DEFAULT' AND hierarchy_level = 3
	AND record_valid_from <= v_reporting_date AND (record_valid_until > v_reporting_date OR record_valid_until IS NULL )) then 'INDEFAULT'


    WHEN in_default_ind = 0 AND exposure_class IN (select BASEL4_EXPOSURE_CLASS_SA_CODE
    from dm_interm_basel4_exp_class_sa_corep where INTERMEDIATE_PARENT_CODE in 'COV_BONDS'
        AND hierarchy_level = 3 AND record_valid_from <= v_reporting_date
        AND (record_valid_until > v_reporting_date OR record_valid_until IS NULL )) THEN 'COVBOND'

    WHEN in_default_ind = 0 AND (exposure_class IN (select BASEL4_EXPOSURE_CLASS_SA_CODE from dm_interm_basel4_exp_class_sa_corep
        where (INTERMEDIATE_PARENT_CODE in 'C_GV_BNK_2' OR INTERMEDIATE_PARENT_CODE in 'PSE_CG' OR INTERMEDIATE_PARENT_CODE in 'REG_GOV_CG'
        OR INTERMEDIATE_PARENT_CODE in 'SPEC_ORG' OR INTERMEDIATE_PARENT_CODE in 'MDB') AND hierarchy_level = 3
        AND record_valid_from <= v_reporting_date AND (record_valid_until > v_reporting_date OR record_valid_until IS NULL ))) THEN 'SOVEREIGN'

    WHEN in_default_ind = 0 AND (exposure_class IN (select basel4_exposure_class_sa_code from dm_interm_basel4_exp_class_sa_corep
        where (intermediate_parent_code in 'REG_GOV' or intermediate_parent_code in 'PSE'  or intermediate_parent_code in 'MDB_OTHER')
        and hierarchy_level = 3 and record_valid_from <= v_reporting_date and (record_valid_until > v_reporting_date or record_valid_until is null ))) THEN 'NOTSOVEREIGN'

    WHEN in_default_ind = 0 AND exposure_class IN (select basel4_exposure_class_sa_code from dm_interm_basel4_exp_class_sa_corep
        where intermediate_parent_code in 'INST' and hierarchy_level = 3 and record_valid_from <= v_reporting_date
        and (record_valid_until > v_reporting_date or record_valid_until is null )) THEN 'INSTIT'

    WHEN in_default_ind = 0 AND exposure_class IN (select basel4_exposure_class_sa_code from dm_interm_basel4_exp_class_sa_corep
        where intermediate_parent_code in 'SECURED' and hierarchy_level = 3 and record_valid_from <= v_reporting_date
        and (record_valid_until > v_reporting_date or record_valid_until is null ))  THEN 'SECMOR'

    WHEN in_default_ind = 0 AND exposure_class IN (select basel4_exposure_class_sa_code from dm_interm_basel4_exp_class_sa_corep
        where intermediate_parent_code in 'RETAIL' and hierarchy_level = 3 and record_valid_from <= v_reporting_date
        and (record_valid_until > v_reporting_date or record_valid_until is null )) THEN 'RETAIL'

    WHEN in_default_ind = 0 AND exposure_class IN (select basel4_exposure_class_sa_code from dm_interm_basel4_exp_class_sa_corep
        where intermediate_parent_code in 'CORPORATE' and hierarchy_level = 3 and record_valid_from <= v_reporting_date
        and (record_valid_until > v_reporting_date or record_valid_until is null )) THEN 'CORP'

    WHEN in_default_ind = 0 AND exposure_class IN (select basel4_exposure_class_sa_code from dm_interm_basel4_exp_class_sa_corep
        where intermediate_parent_code IN ('COLL_IU','EQUITY','SUBOR_DEBT','SECUR') and hierarchy_level = 3 and record_valid_from <= v_reporting_date
        and (record_valid_until > v_reporting_date or record_valid_until is null )) THEN 'OTH'
    ELSE 'UNCLASSIFIED'
    END
        WHERE  BASEL_APPROACH IN ('SA','SA_TR');
    COMMIT;



















    UPDATE /*+ enable_parallel_dml */ tmp_corep_recap_measure_pre_b4
    SET lr_exposure_type = CASE WHEN BASEL_APPROACH IN ('AIRB','AIRB_OFFIC','FIRB') AND in_default_ind = 1 THEN 'INDEFAULT'

    WHEN BASEL_APPROACH IN ('AIRB','AIRB_OFFIC','FIRB') AND lr_covered_bond_ind = 1 AND in_default_ind = 0 AND exposure_class NOT IN
        (select BASEL4_EXPOSURE_CLASS_IRB_CODE from dm_interm_basel4_exp_class_irb_corep where INTERMEDIATE_PARENT_CODE in 'SECUR'
        and hierarchy_level = 3 AND record_valid_from <= v_reporting_date AND (record_valid_until > v_reporting_date OR record_valid_until IS NULL )) THEN 'COVBOND'

    WHEN BASEL_APPROACH IN ('AIRB','AIRB_OFFIC','FIRB') AND in_default_ind = 0 AND exposure_class IN (select BASEL4_EXPOSURE_CLASS_IRB_CODE
        from dm_interm_basel4_exp_class_irb_corep where INTERMEDIATE_PARENT_CODE in 'CGCB' and hierarchy_level = 3
        AND record_valid_from <= v_reporting_date AND (record_valid_until > v_reporting_date OR record_valid_until IS NULL )) THEN 'SOVEREIGN'

    WHEN BASEL_APPROACH IN ('AIRB','AIRB_OFFIC','FIRB') AND in_default_ind = 0 AND exposure_class IN (select BASEL4_EXPOSURE_CLASS_IRB_CODE
        from dm_interm_basel4_exp_class_irb_corep where INTERMEDIATE_PARENT_CODE in ('RGLA','PSE') and hierarchy_level = 3
        AND record_valid_from <= v_reporting_date AND (record_valid_until > v_reporting_date OR record_valid_until IS NULL )) THEN 'NOTSOVEREIGN'

    WHEN BASEL_APPROACH IN ('AIRB','AIRB_OFFIC','FIRB') AND in_default_ind = 0 AND exposure_class IN (select BASEL4_EXPOSURE_CLASS_IRB_CODE
        from dm_interm_basel4_exp_class_irb_corep where INTERMEDIATE_PARENT_CODE in 'INSTIT' and hierarchy_level = 3
        AND record_valid_from <= v_reporting_date AND (record_valid_until > v_reporting_date OR record_valid_until IS NULL )) AND lr_covered_bond_ind = 0 THEN 'INSTIT'

    WHEN BASEL_APPROACH IN ('AIRB','AIRB_OFFIC','FIRB') AND in_default_ind = 0 AND exposure_class IN (select BASEL4_EXPOSURE_CLASS_IRB_CODE
        from dm_interm_basel4_exp_class_irb_corep where INTERMEDIATE_PARENT_CODE in ('RET','CORP') and hierarchy_level = 3
        AND record_valid_from <= v_reporting_date AND (record_valid_until > v_reporting_date OR record_valid_until IS NULL ))
        AND (secured_by_com_prop_ind = 1 OR secured_by_res_prop_ind = 1) THEN 'SECMOR'

    WHEN BASEL_APPROACH IN ('AIRB','AIRB_OFFIC','FIRB') AND in_default_ind = 0 AND exposure_class IN (select BASEL4_EXPOSURE_CLASS_IRB_CODE
        from dm_interm_basel4_exp_class_irb_corep where INTERMEDIATE_PARENT_CODE in ('RET') and hierarchy_level = 3
        AND record_valid_from <= v_reporting_date AND (record_valid_until > v_reporting_date OR record_valid_until IS NULL ))
        AND (secured_by_com_prop_ind = 0 AND secured_by_res_prop_ind = 0) THEN 'RETAIL'

    WHEN BASEL_APPROACH IN ('AIRB','AIRB_OFFIC','FIRB') AND in_default_ind = 0 AND exposure_class IN (select BASEL4_EXPOSURE_CLASS_IRB_CODE
        from dm_interm_basel4_exp_class_irb_corep where INTERMEDIATE_PARENT_CODE in ('CORP') and hierarchy_level = 3
        AND record_valid_from <= v_reporting_date AND (record_valid_until > v_reporting_date OR record_valid_until IS NULL ))
        AND (secured_by_com_prop_ind = 0 AND secured_by_res_prop_ind = 0) THEN 'CORP'

    WHEN BASEL_APPROACH IN ('AIRB','AIRB_OFFIC','FIRB') AND in_default_ind = 0 AND exposure_class IN (select BASEL4_EXPOSURE_CLASS_IRB_CODE from dm_interm_basel4_exp_class_irb_corep
        where INTERMEDIATE_PARENT_CODE in ('EQUITY','SECUR') and hierarchy_level = 3
        AND record_valid_from <= v_reporting_date AND (record_valid_until > v_reporting_date OR record_valid_until IS NULL )) THEN 'OTH'

    WHEN BASEL_APPROACH IN ('AIRB','AIRB_OFFIC','FIRB') THEN 'UNCLASSIFIED'
    END
    WHERE (BASEL_APPROACH IN ('AIRB','AIRB_OFFIC','FIRB') OR source_table = 'SEC');
    COMMIT;







    UPDATE /*+ enable_parallel_dml */ tmp_corep_recap_measure_pre_b4
    SET lr_exposure_type_original =

    case when in_default_ind_original = 1 then 'INDEFAULT'

    WHEN in_default_ind_original = 0 AND exposure_class_original IN (select BASEL4_EXPOSURE_CLASS_SA_CODE
    from dm_interm_basel4_exp_class_sa_corep where INTERMEDIATE_PARENT_CODE in 'COV_BONDS'
        AND hierarchy_level = 3 AND record_valid_from <= v_reporting_date
        AND (record_valid_until > v_reporting_date OR record_valid_until IS NULL )) THEN 'COVBOND'

    WHEN in_default_ind_original = 0 AND (exposure_class_original IN (select BASEL4_EXPOSURE_CLASS_SA_CODE from dm_interm_basel4_exp_class_sa_corep
        where (INTERMEDIATE_PARENT_CODE in 'C_GV_BNK_2' OR INTERMEDIATE_PARENT_CODE in 'PSE_CG' OR INTERMEDIATE_PARENT_CODE in 'REG_GOV_CG'
        OR INTERMEDIATE_PARENT_CODE in 'SPEC_ORG' OR INTERMEDIATE_PARENT_CODE in 'MDB') AND hierarchy_level = 3
        AND record_valid_from <= v_reporting_date AND (record_valid_until > v_reporting_date OR record_valid_until IS NULL ))) THEN 'SOVEREIGN'

    WHEN in_default_ind_original = 0 AND (exposure_class_original IN (select basel4_exposure_class_sa_code from dm_interm_basel4_exp_class_sa_corep
        where (intermediate_parent_code in 'REG_GOV' or intermediate_parent_code in 'PSE'  or intermediate_parent_code in 'MDB_OTHER')
        and hierarchy_level = 3 and record_valid_from <= v_reporting_date and (record_valid_until > v_reporting_date or record_valid_until is null ))) THEN 'NOTSOVEREIGN'

    WHEN in_default_ind_original = 0 AND exposure_class_original IN (select basel4_exposure_class_sa_code from dm_interm_basel4_exp_class_sa_corep
        where intermediate_parent_code in 'INST' and hierarchy_level = 3 and record_valid_from <= v_reporting_date
        and (record_valid_until > v_reporting_date or record_valid_until is null )) THEN 'INSTIT'

    WHEN in_default_ind_original = 0 AND exposure_class_original IN (select basel4_exposure_class_sa_code from dm_interm_basel4_exp_class_sa_corep
        where intermediate_parent_code in 'SECURED' and hierarchy_level = 3 and record_valid_from <= v_reporting_date
        and (record_valid_until > v_reporting_date or record_valid_until is null ))  THEN 'SECMOR'

    WHEN in_default_ind_original = 0 AND exposure_class_original IN (select basel4_exposure_class_sa_code from dm_interm_basel4_exp_class_sa_corep
        where intermediate_parent_code in 'RETAIL' and hierarchy_level = 3 and record_valid_from <= v_reporting_date
        and (record_valid_until > v_reporting_date or record_valid_until is null )) THEN 'RETAIL'

    WHEN in_default_ind_original = 0 AND exposure_class_original IN (select basel4_exposure_class_sa_code from dm_interm_basel4_exp_class_sa_corep
        where intermediate_parent_code in 'CORPORATE' and hierarchy_level = 3 and record_valid_from <= v_reporting_date
        and (record_valid_until > v_reporting_date or record_valid_until is null )) THEN 'CORP'

    WHEN in_default_ind_original = 0 AND exposure_class_original IN (select basel4_exposure_class_sa_code from dm_interm_basel4_exp_class_sa_corep
        where intermediate_parent_code IN ('COLL_IU','EQUITY','SUBOR_DEBT','SECUR') and hierarchy_level = 3 and record_valid_from <= v_reporting_date
        and (record_valid_until > v_reporting_date or record_valid_until is null )) THEN 'OTH'
    ELSE 'UNCLASSIFIED'
    END
        WHERE  BASEL_APPROACH_ORIGINAL IN ('SA','SA_TR');
    COMMIT;












    UPDATE /*+ enable_parallel_dml */ tmp_corep_recap_measure_pre_b4
    SET lr_exposure_type_original = CASE WHEN BASEL_APPROACH_ORIGINAL IN ('AIRB','AIRB_OFFIC','FIRB') AND in_default_ind_original = 1 THEN 'INDEFAULT'



    WHEN BASEL_APPROACH_ORIGINAL IN ('AIRB','AIRB_OFFIC','FIRB') AND lr_covered_bond_ind = 1 AND in_default_ind_original = 0 AND exposure_class_original NOT IN
        (select BASEL4_EXPOSURE_CLASS_IRB_CODE from dm_interm_basel4_exp_class_irb_corep where INTERMEDIATE_PARENT_CODE in 'SECUR'
        and hierarchy_level = 3 AND record_valid_from <= v_reporting_date AND (record_valid_until > v_reporting_date OR record_valid_until IS NULL )) THEN 'COVBOND'

    WHEN BASEL_APPROACH_ORIGINAL IN ('AIRB','AIRB_OFFIC','FIRB') AND in_default_ind_original = 0 AND exposure_class_original IN (select BASEL4_EXPOSURE_CLASS_IRB_CODE
        from dm_interm_basel4_exp_class_irb_corep where INTERMEDIATE_PARENT_CODE in 'CGCB' and hierarchy_level = 3
        AND record_valid_from <= v_reporting_date AND (record_valid_until > v_reporting_date OR record_valid_until IS NULL )) THEN 'SOVEREIGN'



    WHEN BASEL_APPROACH_ORIGINAL IN ('AIRB','AIRB_OFFIC','FIRB') AND in_default_ind_original = 0 AND exposure_class_original IN (select BASEL4_EXPOSURE_CLASS_IRB_CODE
        from dm_interm_basel4_exp_class_irb_corep where INTERMEDIATE_PARENT_CODE in ('RGLA','PSE') and hierarchy_level = 3
        AND record_valid_from <= v_reporting_date AND (record_valid_until > v_reporting_date OR record_valid_until IS NULL )) THEN 'NOTSOVEREIGN'






























    WHEN BASEL_APPROACH_ORIGINAL IN ('AIRB','AIRB_OFFIC','FIRB') AND in_default_ind_original = 0 AND exposure_class_original IN (select BASEL4_EXPOSURE_CLASS_IRB_CODE
        from dm_interm_basel4_exp_class_irb_corep where INTERMEDIATE_PARENT_CODE in 'INSTIT' and hierarchy_level = 3
        AND record_valid_from <= v_reporting_date AND (record_valid_until > v_reporting_date OR record_valid_until IS NULL )) AND lr_covered_bond_ind = 0 THEN 'INSTIT'

    WHEN BASEL_APPROACH_ORIGINAL IN ('AIRB','AIRB_OFFIC','FIRB') AND in_default_ind_original = 0 AND exposure_class_original IN (select BASEL4_EXPOSURE_CLASS_IRB_CODE
        from dm_interm_basel4_exp_class_irb_corep where INTERMEDIATE_PARENT_CODE in ('RET','CORP') and hierarchy_level = 3
        AND record_valid_from <= v_reporting_date AND (record_valid_until > v_reporting_date OR record_valid_until IS NULL ))
        AND (secured_by_com_prop_ind = 1 OR secured_by_res_prop_ind = 1) THEN 'SECMOR'




    WHEN BASEL_APPROACH_ORIGINAL IN ('AIRB','AIRB_OFFIC','FIRB') AND in_default_ind_original = 0 AND exposure_class_original IN (select BASEL4_EXPOSURE_CLASS_IRB_CODE
        from dm_interm_basel4_exp_class_irb_corep where INTERMEDIATE_PARENT_CODE in ('RET') and hierarchy_level = 3
        AND record_valid_from <= v_reporting_date AND (record_valid_until > v_reporting_date OR record_valid_until IS NULL ))
        AND (secured_by_com_prop_ind = 0 AND secured_by_res_prop_ind = 0) THEN 'RETAIL'

    WHEN BASEL_APPROACH_ORIGINAL IN ('AIRB','AIRB_OFFIC','FIRB') AND in_default_ind_original = 0 AND exposure_class_original IN (select BASEL4_EXPOSURE_CLASS_IRB_CODE
        from dm_interm_basel4_exp_class_irb_corep where INTERMEDIATE_PARENT_CODE in ('CORP') and hierarchy_level = 3
        AND record_valid_from <= v_reporting_date AND (record_valid_until > v_reporting_date OR record_valid_until IS NULL ))
        AND (secured_by_com_prop_ind = 0 AND secured_by_res_prop_ind = 0) THEN 'CORP'

    WHEN BASEL_APPROACH_ORIGINAL IN ('AIRB','AIRB_OFFIC','FIRB') AND in_default_ind_original = 0 AND exposure_class_original IN (select BASEL4_EXPOSURE_CLASS_IRB_CODE from dm_interm_basel4_exp_class_irb_corep
        where INTERMEDIATE_PARENT_CODE in ('EQUITY','SECUR') and hierarchy_level = 3
        AND record_valid_from <= v_reporting_date AND (record_valid_until > v_reporting_date OR record_valid_until IS NULL )) THEN 'OTH'

    WHEN BASEL_APPROACH_ORIGINAL IN ('AIRB','AIRB_OFFIC','FIRB') THEN 'UNCLASSIFIED'
    END
    WHERE (BASEL_APPROACH_ORIGINAL IN ('AIRB','AIRB_OFFIC','FIRB') OR source_table = 'SEC');
    COMMIT;






		UPDATE/*+ enable_parallel_dml */ tmp_corep_recap_measure_pre_b4
		SET lr_exposure_subtype = 'SECMORRES'
		WHERE basel_approach IN ('SA','SA_TR')
		AND exposure_class IN (select BASEL4_EXPOSURE_CLASS_SA_CODE from dm_interm_basel4_exp_class_sa_corep where INTERMEDIATE_PARENT_CODE in 'S_RES_PR_2'
		AND hierarchy_level = 3 AND record_valid_from <= v_reporting_date AND (record_valid_until > v_reporting_date OR record_valid_until IS NULL ));
		v_debug_msg := $$plsql_line|| ' of plsql unit '|| $$plsql_unit|| ' '|| systimestamp|| ' Rows Affected:- '|| SQL%rowcount;
		utilities.show_debug(v_debug_msg);
		COMMIT;

		UPDATE/*+ enable_parallel_dml */ tmp_corep_recap_measure_pre_b4
		SET lr_exposure_subtype = 'RETSME'
		WHERE basel_approach IN ('SA','SA_TR')
		AND lr_exposure_type = 'RETAIL' and leverage_sme_ind = 1;
		v_debug_msg := $$plsql_line|| ' of plsql unit '|| $$plsql_unit|| ' '|| systimestamp|| ' Rows Affected:- '|| SQL%rowcount;
		utilities.show_debug(v_debug_msg);
		COMMIT;

		UPDATE/*+ enable_parallel_dml */ tmp_corep_recap_measure_pre_b4
		SET lr_exposure_subtype = 'CORPSME'
		WHERE basel_approach IN ('SA','SA_TR')
		AND lr_exposure_type = 'CORP' and leverage_sme_ind = 1;
		v_debug_msg := $$plsql_line|| ' of plsql unit '|| $$plsql_unit|| ' '|| systimestamp|| ' Rows Affected:- '|| SQL%rowcount;
		utilities.show_debug(v_debug_msg);
		COMMIT;

		-- Remove the single update for CORPOTH and put it inside existing IF ELSE condition
		UPDATE/*+ enable_parallel_dml */ tmp_corep_recap_measure_pre_b4
		SET lr_exposure_subtype = 'CORPOTH'
		WHERE basel_approach IN ('SA','SA_TR')
		AND lr_exposure_type = 'CORP' and leverage_sme_ind = 0;
		v_debug_msg := $$plsql_line|| ' of plsql unit '|| $$plsql_unit|| ' '|| systimestamp|| ' Rows Affected:- '|| SQL%rowcount;
		utilities.show_debug(v_debug_msg);
		COMMIT;

		UPDATE/*+ enable_parallel_dml */ tmp_corep_recap_measure_pre_b4
		SET lr_exposure_subtype = 'SECURIT'
		WHERE basel_approach IN ('SA','SA_TR')
		AND exposure_class IN (select BASEL4_EXPOSURE_CLASS_SA_CODE from dm_interm_basel4_exp_class_sa_corep where INTERMEDIATE_PARENT_CODE in 'SECUR'
		AND hierarchy_level = 3 AND record_valid_from <= v_reporting_date AND (record_valid_until > v_reporting_date OR record_valid_until IS NULL ));
		v_debug_msg := $$plsql_line|| ' of plsql unit '|| $$plsql_unit|| ' '|| systimestamp|| ' Rows Affected:- '|| SQL%rowcount;
		utilities.show_debug(v_debug_msg);
		COMMIT;



		UPDATE/*+ enable_parallel_dml */ tmp_corep_recap_measure_pre_b4
		SET lr_exposure_subtype = 'OTH'
		WHERE basel_approach IN ('SA','SA_TR')
		AND lr_exposure_subtype IS NULL;
		v_debug_msg := $$plsql_line|| ' of plsql unit '|| $$plsql_unit|| ' '|| systimestamp|| ' Rows Affected:- '|| SQL%rowcount;
		utilities.show_debug(v_debug_msg);
		COMMIT;





		-- lr_exposure_subtype IRB
		UPDATE/*+ enable_parallel_dml */ tmp_corep_recap_measure_pre_b4
		SET lr_exposure_subtype = 'SECMORRES'
		WHERE basel_approach IN ('AIRB', 'AIRB_OFFIC','FIRB')
		AND secured_by_res_prop_ind = 1;
		v_debug_msg := $$plsql_line|| ' of plsql unit '|| $$plsql_unit|| ' '|| systimestamp|| ' Rows Affected:- '|| SQL%rowcount;
		utilities.show_debug(v_debug_msg);
		COMMIT;

		UPDATE/*+ enable_parallel_dml */ tmp_corep_recap_measure_pre_b4
		SET lr_exposure_subtype = 'RETSME'
		WHERE basel_approach IN ('AIRB', 'AIRB_OFFIC','FIRB')
		AND lr_exposure_type = 'RETAIL' and leverage_sme_ind = 1;
		v_debug_msg := $$plsql_line|| ' of plsql unit '|| $$plsql_unit|| ' '|| systimestamp|| ' Rows Affected:- '|| SQL%rowcount;
		utilities.show_debug(v_debug_msg);
		COMMIT;


		UPDATE/*+ enable_parallel_dml */ tmp_corep_recap_measure_pre_b4
		SET lr_exposure_subtype = 'CORPSME'
		WHERE basel_approach IN ('AIRB', 'AIRB_OFFIC','FIRB')
		AND lr_exposure_type = 'CORP' and leverage_sme_ind = 1;
		v_debug_msg := $$plsql_line|| ' of plsql unit '|| $$plsql_unit|| ' '|| systimestamp|| ' Rows Affected:- '|| SQL%rowcount;
		utilities.show_debug(v_debug_msg);
		COMMIT;

		-- Remove the single update for CORPOTH and put it inside existing IF ELSE condition



		UPDATE/*+ enable_parallel_dml */ tmp_corep_recap_measure_pre_b4
		SET lr_exposure_subtype = 'CORPOTH'
		WHERE basel_approach IN ('AIRB', 'AIRB_OFFIC','FIRB')
		AND lr_exposure_type = 'CORP' and leverage_sme_ind = 0;

		v_debug_msg := $$plsql_line|| ' of plsql unit '|| $$plsql_unit|| ' '|| systimestamp|| ' Rows Affected:- '|| SQL%rowcount;
		utilities.show_debug(v_debug_msg);
		COMMIT;


		UPDATE/*+ enable_parallel_dml */ tmp_corep_recap_measure_pre_b4
		SET lr_exposure_subtype = 'SECURIT'
		WHERE (basel_approach IN ('AIRB', 'AIRB_OFFIC','FIRB') OR source_table = 'SEC')
		AND exposure_class IN (select BASEL4_EXPOSURE_CLASS_IRB_CODE from dm_interm_basel4_exp_class_irb_corep where INTERMEDIATE_PARENT_CODE in 'SECUR'
		AND hierarchy_level = 3 AND record_valid_from <= v_reporting_date AND (record_valid_until > v_reporting_date OR record_valid_until IS NULL ));










		v_debug_msg := $$plsql_line|| ' of plsql unit '|| $$plsql_unit|| ' '|| systimestamp|| ' Rows Affected:- '|| SQL%rowcount;
		utilities.show_debug(v_debug_msg);
		COMMIT;


		UPDATE/*+ enable_parallel_dml */ tmp_corep_recap_measure_pre_b4
		SET lr_exposure_subtype = 'OTH'
		WHERE basel_approach IN ('AIRB', 'AIRB_OFFIC','FIRB')
		AND lr_exposure_subtype IS NULL;
		v_debug_msg := $$plsql_line|| ' of plsql unit '|| $$plsql_unit|| ' '|| systimestamp|| ' Rows Affected:- '|| SQL%rowcount;
		utilities.show_debug(v_debug_msg);
		COMMIT;


		UPDATE/*+ enable_parallel_dml */ tmp_corep_recap_measure_pre_b4
		SET lr_exposure_subtype_original = 'SECMORRES'
		WHERE BASEL_APPROACH_ORIGINAL IN ('SA','SA_TR')
		AND exposure_class_original IN (select BASEL4_EXPOSURE_CLASS_SA_CODE from dm_interm_basel4_exp_class_sa_corep where INTERMEDIATE_PARENT_CODE in 'S_RES_PR_2'
		AND hierarchy_level = 3 AND record_valid_from <= v_reporting_date AND (record_valid_until > v_reporting_date OR record_valid_until IS NULL ));
		v_debug_msg := $$plsql_line|| ' of plsql unit '|| $$plsql_unit|| ' '|| systimestamp|| ' Rows Affected:- '|| SQL%rowcount;
		utilities.show_debug(v_debug_msg);
		COMMIT;

		UPDATE/*+ enable_parallel_dml */ tmp_corep_recap_measure_pre_b4
		SET lr_exposure_subtype_original = 'RETSME'
		WHERE BASEL_APPROACH_ORIGINAL IN ('SA','SA_TR')
		AND lr_exposure_type_original = 'RETAIL' and leverage_sme_ind = 1;
		v_debug_msg := $$plsql_line|| ' of plsql unit '|| $$plsql_unit|| ' '|| systimestamp|| ' Rows Affected:- '|| SQL%rowcount;
		utilities.show_debug(v_debug_msg);
		COMMIT;

		UPDATE/*+ enable_parallel_dml */ tmp_corep_recap_measure_pre_b4
		SET lr_exposure_subtype_original = 'CORPSME'
		WHERE BASEL_APPROACH_ORIGINAL IN ('SA','SA_TR')
		AND lr_exposure_type_original = 'CORP' and leverage_sme_ind = 1;
		v_debug_msg := $$plsql_line|| ' of plsql unit '|| $$plsql_unit|| ' '|| systimestamp|| ' Rows Affected:- '|| SQL%rowcount;
		utilities.show_debug(v_debug_msg);
		COMMIT;

		-- Remove the single update for CORPOTH and put it inside existing IF ELSE condition
		UPDATE/*+ enable_parallel_dml */ tmp_corep_recap_measure_pre_b4
		SET lr_exposure_subtype_original = 'CORPOTH'
		WHERE BASEL_APPROACH_ORIGINAL IN ('SA','SA_TR')
		AND lr_exposure_type_original = 'CORP' and leverage_sme_ind = 0;
		v_debug_msg := $$plsql_line|| ' of plsql unit '|| $$plsql_unit|| ' '|| systimestamp|| ' Rows Affected:- '|| SQL%rowcount;
		utilities.show_debug(v_debug_msg);
		COMMIT;

		UPDATE/*+ enable_parallel_dml */ tmp_corep_recap_measure_pre_b4
		SET lr_exposure_subtype_original = 'SECURIT'
		WHERE BASEL_APPROACH_ORIGINAL IN ('SA','SA_TR')
		AND exposure_class_original IN (select BASEL4_EXPOSURE_CLASS_SA_CODE from dm_interm_basel4_exp_class_sa_corep where INTERMEDIATE_PARENT_CODE in 'SECUR'
		AND hierarchy_level = 3 AND record_valid_from <= v_reporting_date AND (record_valid_until > v_reporting_date OR record_valid_until IS NULL ));
		v_debug_msg := $$plsql_line|| ' of plsql unit '|| $$plsql_unit|| ' '|| systimestamp|| ' Rows Affected:- '|| SQL%rowcount;
		utilities.show_debug(v_debug_msg);
		COMMIT;

		UPDATE/*+ enable_parallel_dml */ tmp_corep_recap_measure_pre_b4
		SET lr_exposure_subtype_original = 'OTH'
		WHERE BASEL_APPROACH_ORIGINAL IN ('SA','SA_TR')
		AND lr_exposure_subtype_original IS NULL;
		v_debug_msg := $$plsql_line|| ' of plsql unit '|| $$plsql_unit|| ' '|| systimestamp|| ' Rows Affected:- '|| SQL%rowcount;
		utilities.show_debug(v_debug_msg);
		COMMIT;


		-- lr_exposure_subtype_original IRB
		UPDATE/*+ enable_parallel_dml */ tmp_corep_recap_measure_pre_b4
		SET lr_exposure_subtype_original = 'SECMORRES'
		WHERE BASEL_APPROACH_ORIGINAL IN ('AIRB', 'AIRB_OFFIC','FIRB')
		AND secured_by_res_prop_ind = 1;
		v_debug_msg := $$plsql_line|| ' of plsql unit '|| $$plsql_unit|| ' '|| systimestamp|| ' Rows Affected:- '|| SQL%rowcount;
		utilities.show_debug(v_debug_msg);
		COMMIT;

		UPDATE/*+ enable_parallel_dml */ tmp_corep_recap_measure_pre_b4
		SET lr_exposure_subtype_original = 'RETSME'
		WHERE BASEL_APPROACH_ORIGINAL IN ('AIRB', 'AIRB_OFFIC','FIRB')
		AND lr_exposure_type_original = 'RETAIL' and leverage_sme_ind = 1;
		v_debug_msg := $$plsql_line|| ' of plsql unit '|| $$plsql_unit|| ' '|| systimestamp|| ' Rows Affected:- '|| SQL%rowcount;
		utilities.show_debug(v_debug_msg);
		COMMIT;

		UPDATE/*+ enable_parallel_dml */ tmp_corep_recap_measure_pre_b4
		SET lr_exposure_subtype_original = 'CORPSME'
		WHERE BASEL_APPROACH_ORIGINAL IN ('AIRB', 'AIRB_OFFIC','FIRB')
		AND lr_exposure_type_original = 'CORP' and leverage_sme_ind = 1;
		v_debug_msg := $$plsql_line|| ' of plsql unit '|| $$plsql_unit|| ' '|| systimestamp|| ' Rows Affected:- '|| SQL%rowcount;
		utilities.show_debug(v_debug_msg);
		COMMIT;

		-- Remove the single update for CORPOTH and put it inside existing IF ELSE condition
		UPDATE/*+ enable_parallel_dml */ tmp_corep_recap_measure_pre_b4
		SET lr_exposure_subtype_original = 'CORPOTH'
		WHERE BASEL_APPROACH_ORIGINAL IN ('AIRB', 'AIRB_OFFIC','FIRB')
		AND lr_exposure_type_original = 'CORP' and leverage_sme_ind = 0;
		v_debug_msg := $$plsql_line|| ' of plsql unit '|| $$plsql_unit|| ' '|| systimestamp|| ' Rows Affected:- '|| SQL%rowcount;
		utilities.show_debug(v_debug_msg);
		COMMIT;

		UPDATE/*+ enable_parallel_dml */ tmp_corep_recap_measure_pre_b4
		SET lr_exposure_subtype_original = 'SECURIT'
		WHERE (BASEL_APPROACH_ORIGINAL IN ('AIRB', 'AIRB_OFFIC','FIRB') OR source_table = 'SEC')
		AND exposure_class_original IN (select BASEL4_EXPOSURE_CLASS_IRB_CODE from dm_interm_basel4_exp_class_irb_corep where INTERMEDIATE_PARENT_CODE in 'SECUR'
		AND hierarchy_level = 3 AND record_valid_from <= v_reporting_date AND (record_valid_until > v_reporting_date OR record_valid_until IS NULL ));
		v_debug_msg := $$plsql_line|| ' of plsql unit '|| $$plsql_unit|| ' '|| systimestamp|| ' Rows Affected:- '|| SQL%rowcount;
		utilities.show_debug(v_debug_msg);
		COMMIT;

		UPDATE/*+ enable_parallel_dml */ tmp_corep_recap_measure_pre_b4
		SET lr_exposure_subtype_original = 'OTH'
		WHERE BASEL_APPROACH_ORIGINAL IN ('AIRB', 'AIRB_OFFIC','FIRB')
		AND lr_exposure_subtype_original IS NULL;
		v_debug_msg := $$plsql_line|| ' of plsql unit '|| $$plsql_unit|| ' '|| systimestamp|| ' Rows Affected:- '|| SQL%rowcount;
		utilities.show_debug(v_debug_msg);
		COMMIT;


    insert_dmb_log_corep(v_detail_level    => 103,
                                   v_log_descr       => 'process_pre_corep_recap_b4',
                                   v_activity_code   => 'lev_ratio',
                                   v_result_code     => 'FINOK',
                                   v_system_id       => v_system_id,v_reporting_date       => v_reporting_date
                                );

    insert_dmb_log_corep(v_detail_level    => 103,
                                   v_log_descr       => 'process_pre_corep_recap_b4',
                                   v_activity_code   => 'obs_new_def',
                                   v_result_code     => 'START',
                                   v_system_id       => v_system_id,v_reporting_date       => v_reporting_date
                                   );


   INSERT INTO tt_past_dates
     ( SELECT 0 ,
              0 ,
              v_reporting_date ,
              v_reporting_date
         FROM DUAL  );
COMMIT;
   UPDATE tt_past_dates
      SET curr_month_number = utils.datepart('MONTH', v_reporting_date);
COMMIT;
   UPDATE tt_past_dates
      SET curr_year_number = utils.datepart('YEAR', v_reporting_date);
COMMIT;
   UPDATE tt_past_dates
      SET last_quarter_date = TO_DATE(CASE
                                   WHEN curr_month_number IN ( 1,2,3 )
                                    THEN to_char(curr_year_number - 1) || '1231'
                                   WHEN curr_month_number IN ( 4,5,6 )
                                    THEN to_char(curr_year_number) || '0331'
                                   WHEN curr_month_number IN ( 7,8,9 )
                                    THEN to_char(curr_year_number) || '0630'
          ELSE to_char(curr_year_number) || '0930'
             END,'YYYYMMDD' ) ;
COMMIT;
   UPDATE tt_past_dates
      SET last_year_date = TO_DATE(UTILS.CONVERT_TO_VARCHAR2(curr_year_number - 1,30) || '1231','YYYYMMDD' );
COMMIT;

   --  modification corep_vpp
   UPDATE tmp_corep_recap_measure_pre_b4
      SET observed_new_default_ind = 0,
          observed_new_default_ip_ind = 0;
COMMIT;
   MERGE INTO tmp_corep_recap_measure_pre_b4 rm
   USING
   (
       SELECT distinct last_quarter_date
       FROM tt_past_dates
    ) bu
   ON ( rm.record_valid_from = v_reporting_date --  modification corep_vpp
         AND rm.system_id = v_system_id --  modification corep_vpp
         AND rm.in_default_ind_original = 1
         AND NOT EXISTS ( SELECT 1
                          FROM dwh_derived_customer c
                           WHERE  rm.customer_id = c.customer_id
                                AND c.record_valid_from <= bu.last_quarter_date
                                AND ( c.record_valid_until > bu.last_quarter_date OR c.record_valid_until IS NULL )
                                AND c.risk_rating_key IN ( SELECT risk_rating_key
                                                           FROM risk_rating
                                                            WHERE  in_default = 'Y' )
                    )
        )
   WHEN MATCHED THEN UPDATE SET rm.observed_new_default_ind = 1;
COMMIT;
   MERGE INTO tmp_corep_recap_measure_pre_b4 rm
   USING
   (
       SELECT distinct
        last_year_date
       FROM tt_past_dates bu
    ) src
   ON ( rm.record_valid_from = v_reporting_date --  modification corep_vpp
         AND rm.system_id = v_system_id --  modification corep_vpp
         AND rm.in_default_ind_original = 1
         AND NOT EXISTS ( SELECT 1
                          FROM dwh_derived_customer c
                           WHERE  rm.customer_id = c.customer_id
                                    AND c.record_valid_from <= src.last_year_date
                                    AND ( c.record_valid_until > src.last_year_date OR c.record_valid_until IS NULL )
                                    AND c.risk_rating_key IN ( SELECT risk_rating_key
                                                               FROM risk_rating
                                                                WHERE  in_default = 'Y' )
                        )
        )
   WHEN MATCHED THEN UPDATE SET rm.observed_new_default_ip_ind = 1;

   commit;

    insert_dmb_log_corep(v_detail_level    => 103,
                                   v_log_descr       => 'process_pre_corep_recap_b4',
                                   v_activity_code   => 'obs_new_def',
                                   v_result_code     => 'FINOK',
                                   v_system_id       => v_system_id,v_reporting_date       => v_reporting_date
                                   );

    --utils.commit_transaction;
    insert_dmb_log_corep(v_detail_level    => 103,
                                   v_log_descr       => 'process_pre_corep_recap_b4',
                                   v_activity_code   => 'CVA',
                                   v_result_code     => 'START',
                                   v_system_id       => v_system_id,v_reporting_date       => v_reporting_date
                                   );

    utilities.truncate_table('TMP_COREP_OUTSTANDING_TIME_BAND_FACT_B4');
    INSERT /*+ APPEND +*/ INTO TMP_COREP_OUTSTANDING_TIME_BAND_FACT_B4 (outstanding_key,time_band_key,netting_type,os_amt)
    (SELECT osf.outstanding_key,osf.time_band_key,osf.netting_type,osf.os_amt
     FROM dwh_outstanding_time_band_fact osf
     WHERE --(osf.record_valid_from, osf.system_id, osf.load_key) IN  ( SELECT /*+ PRECOMPUTE_SUBQUERY */ reporting_date, system_id, load_key_n FROM tmp_basel_combined_uploads)
	 osf.system_id = v_system_id --  modification corep_vpp
	 AND osf.record_valid_from = v_reporting_date --  modification corep_vpp
     AND osf.amt_type = 'OAMB'
--     AND osf.netting_type IN ('CVA','DVA','SACCR_NC_R','SACCR_CC_R') --CU7
    AND osf.netting_type IN ('CVA','DVA','NC','CC','NET_1') --CU7
    );
    COMMIT;
     --JT Query tune for performance issue
    MERGE /*+ enable_parallel_dml */ INTO (SELECT outstanding_key,netting_type,time_band_key,first_timeband FROM TMP_COREP_OUTSTANDING_TIME_BAND_FACT_B4) t1 USING
    (SELECT outstanding_key,netting_type,MIN(time_band_key) time_band_key
     FROM TMP_COREP_OUTSTANDING_TIME_BAND_FACT_B4
     GROUP BY outstanding_key,netting_type
    ) t2
    ON (t1.outstanding_key = t2.outstanding_key AND t1.netting_type = t2.netting_type AND t1.time_band_key = t2.time_band_key)
    WHEN MATCHED THEN UPDATE SET t1.first_timeband = 1;
    COMMIT;
    --JT Query tune for performance issue
    MERGE /*+ enable_parallel_dml */ INTO (SELECT outstanding_key,outstanding_group_key FROM TMP_COREP_OUTSTANDING_TIME_BAND_FACT_B4 WHERE first_timeband = 1 ) otb USING
    (SELECT o.outstanding_key,o.outstanding_group_key
     FROM dwh_outstanding o
     WHERE --(o.record_valid_from, o.system_id, o.load_key) IN  ( SELECT /*+ PRECOMPUTE_SUBQUERY */ reporting_date, system_id, load_key_n FROM tmp_basel_combined_uploads)
	 o.system_id = v_system_id --  modification corep_vpp
	 AND o.record_valid_from = v_reporting_date --  modification corep_vpp
    ) src
    ON (otb.outstanding_key = src.outstanding_key )
    WHEN MATCHED THEN UPDATE SET otb.outstanding_group_key = src.outstanding_group_key;
    COMMIT;

--    update tmp_corep_recap_measure_pre_b4
--    set pro_rata_factor =0.5,
--       conversion_ratio_on_balance=0.2 ;
--       commit;
	--setting settlement_amount for tmp_corep_recap_measure_pre_b4

	MERGE INTO ( Select applied_ind,outstanding_key,settlement_amount,pro_rata_factor,conversion_ratio_on_balance from tmp_corep_recap_measure_pre_b4 ) t USING
			   ( Select outstanding_key,
						SUM(CASE WHEN otba.netting_type = 'NET_1' THEN otba.os_amt END) settlement_amount
				   FROM TMP_COREP_OUTSTANDING_TIME_BAND_FACT_B4 otba GROUP BY otba.outstanding_key
			   )
	src ON ( t.outstanding_key = src.outstanding_key )
	WHEN MATCHED THEN UPDATE SET t.settlement_amount = case when applied_ind = 1 then nvl(round(src.settlement_amount * t.pro_rata_factor * t.conversion_ratio_on_balance,2),0) end ;
	Commit;

    --JT Query tune for performance issue
    --CU7 START
MERGE INTO ( SELECT
               outstanding_group_key,
               cva_amount,
               --dva_amount,
               incurredcva_amount,
--               nc_amount,
--               cc_amount,
               pro_rata_factor,
               conversion_ratio,
               ccr_exp_value_pre_crm,
               corep_counterparty_cluster,
               conversion_ratio_on_balance,
               ccr_exp_value_post_crm,
               applied_ind

           FROM
               tmp_corep_recap_measure_pre_b4
           )
t USING (
            SELECT
                outstanding_group_key,
--                 SUM(CASE WHEN otba.netting_type = 'CVA' THEN otba.os_amt END) cva_amount,
--                SUM(CASE WHEN otba.netting_type = 'DVA' THEN otba.os_amt END) dva_amount,
--                SUM(CASE WHEN otba.netting_type = 'SACCR_NC_R' THEN otba.os_amt END) nc_amount,--cu7
--                SUM(CASE WHEN otba.netting_type = 'SACCR_CC_R' THEN otba.os_amt END) cc_amount--cu7
                SUM(CASE
                    WHEN otba.netting_type = 'CVA' THEN otba.os_amt
                END) cva_amount,
                SUM(CASE
                    WHEN otba.netting_type = 'DVA' THEN otba.os_amt
                END) dva_amount,
                SUM(CASE
                    WHEN otba.netting_type = 'NC' THEN otba.os_amt
                END) nc_amount,--cu7
                SUM(CASE
                    WHEN otba.netting_type = 'CC' THEN otba.os_amt
                END) cc_amount--cu7
            FROM
                TMP_COREP_OUTSTANDING_TIME_BAND_FACT_B4 otba
            WHERE
                otba.first_timeband = 1
            GROUP BY
                otba.outstanding_group_key
        )
src ON ( t.outstanding_group_key = src.outstanding_group_key )
WHEN MATCHED THEN UPDATE SET t.cva_amount = nvl(round(src.cva_amount * t.pro_rata_factor * t.conversion_ratio,2),0),
                             --t.dva_amount = nvl(round(src.dva_amount * t.pro_rata_factor * t.conversion_ratio,2),0),
                             t.incurredcva_amount = CASE WHEN t.applied_ind =1 THEN nvl(round(src.cva_amount * t.pro_rata_factor * t.conversion_ratio,2),0) END, -- fix for duplicate incurredcva_amount issue
                             t.ccr_exp_value_pre_crm = CASE WHEN t.corep_counterparty_cluster = 'SECFIN'
                             THEN nvl(round(src.nc_amount * t.pro_rata_factor * t.conversion_ratio_on_balance,2),0)
                             ELSE t.ccr_exp_value_pre_crm END,
                             t.ccr_exp_value_post_crm = CASE WHEN t.corep_counterparty_cluster = 'SECFIN'
                             THEN nvl(round(src.cc_amount * t.pro_rata_factor * t.conversion_ratio_on_balance,2),0)
                             ELSE t.ccr_exp_value_post_crm END;
   COMMIT;
--CU7 END

   UPDATE /*+ enable_parallel_dml */ tmp_corep_recap_measure_pre_b4
   SET cva_amount = 0
   ,   incurredcva_amount = 0
   WHERE cva_amount IS NULL;
   COMMIT;
--
--   UPDATE /*+ enable_parallel_dml */ tmp_corep_recap_measure_pre_b4
--   SET dva_amount = 0
--   WHERE dva_amount IS NULL;
--   COMMIT;

    insert_dmb_log_corep(v_detail_level    => 103,
                                   v_log_descr       => 'process_pre_corep_recap_b4',
                                   v_activity_code   => 'CVA',
                                   v_result_code     => 'FINOK',
                                   v_system_id       => v_system_id,v_reporting_date       => v_reporting_date
                                   );

-----------------------------------

    utilities.insert_dmi_log_basel(
                                    v_detail_level    => 103,
                                    v_log_descr       => 'process_pre_corep_recap_b4',
                                    v_activity_code   => 'regos amounts',
                                    v_result_code     => 'START',
                                    v_system_id       => ' '
                                );

    utilities.truncate_table('TMP_COREP_OUTSTANDING_TIME_BAND_FACT_B4');
    BEGIN
        INSERT /*+ APPEND enable_parallel_dml */ INTO TMP_COREP_OUTSTANDING_TIME_BAND_FACT_B4
        (outstanding_key,time_band_key,netting_type,os_amt)
        ( SELECT osf.outstanding_key,osf.time_band_key,osf.netting_type,osf.os_amt
          FROM dwh_outstanding_time_band_fact osf
          WHERE osf.system_id = v_system_id
	      AND osf.record_valid_from = v_reporting_date
          AND osf.amt_type = 'OAMB'
          AND osf.netting_type IN ('SACCR_GC_R','SACCR_CC_R','SACCR_NC_R','GC','CC','NC','GIR','CIR','NIR','GCR','CCR','NCR','ON','NO','SACCR_VC_R', 'SACCR_VO_R',
                                    'SACCR_IM_R',  'SACCR_RC_C', 'SACCRAddon', 'SACCR_VC_L', 'SACCR_RC_L')
									     );
    EXCEPTION
        WHEN OTHERS THEN utils.handleerror(sqlcode,sqlerrm);
    END;
    COMMIT;
    schema_maint.gather_idx_stats('TMP_COREP_OUTSTANDING_TIME_BAND_FACT_B4');

    BEGIN

        MERGE /*+ enable_parallel_dml */ INTO ( SELECT netting_type,time_band_key,outstanding_key,first_timeband FROM  TMP_COREP_OUTSTANDING_TIME_BAND_FACT_B4 ) t1 USING
        (SELECT outstanding_key,netting_type,MIN(time_band_key) time_band_key
         FROM TMP_COREP_OUTSTANDING_TIME_BAND_FACT_B4
         GROUP BY outstanding_key,netting_type
        ) t2
        ON (t1.outstanding_key = t2.outstanding_key AND t1.netting_type = t2.netting_type AND t1.time_band_key = t2.time_band_key)
       WHEN MATCHED THEN UPDATE SET t1.first_timeband = 1;
    EXCEPTION
        WHEN OTHERS THEN utils.handleerror(sqlcode,sqlerrm);
    END;

    v_debug_msg := $$plsql_line|| ' of plsql unit '|| $$plsql_unit|| ' '|| systimestamp|| ' Rows Affected:- '|| SQL%rowcount;
    utilities.show_debug(v_debug_msg);
    COMMIT;
    --force gather first timeband statistics
    DBMS_STATS.gather_table_stats(ownname=>'VORTEX_BUSS_OWNER', tabname=>'TMP_COREP_OUTSTANDING_TIME_BAND_FACT_B4', force=>true);

    BEGIN
        MERGE /*+ enable_parallel_dml +*/ INTO (SELECT outstanding_key,outstanding_group_key
                                                FROM TMP_COREP_OUTSTANDING_TIME_BAND_FACT_B4 WHERE first_timeband = 1) otb USING
        (SELECT o.outstanding_group_key,o.load_key,o.outstanding_key
         FROM dwh_outstanding o
         WHERE o.system_id = v_system_id
	      AND o.record_valid_from = v_reporting_date
        )src
        ON ( otb.outstanding_key = src.outstanding_key )
        WHEN MATCHED THEN UPDATE SET otb.outstanding_group_key = src.outstanding_group_key;
    EXCEPTION
        WHEN OTHERS THEN utils.handleerror(sqlcode,sqlerrm);
    END;

    v_debug_msg := $$plsql_line|| ' of plsql unit '|| $$plsql_unit|| ' '|| systimestamp|| ' Rows Affected:- '|| SQL%rowcount;
    utilities.show_debug(v_debug_msg);
    COMMIT;

    BEGIN
    MERGE /*+ enable_parallel_dml +*/ INTO
    (SELECT outstanding_group_key,after_coll_regulatory_os_amt,system_id,basel_approach,pro_rata_factor,corep_counterparty_cluster,
           gross_regulatory_os_amt,regulatory_os_amt,old_regulatory_os_amt,notional_amount,
           ccr_variation_margin,ccr_net_indep_collat_amt,ccr_replacement_cost,ccr_addon,lre_ccr_variation_margin,lre_ccr_replacement_cost
     FROM tmp_corep_recap_measure_pre_b4)rm USING
     (       SELECT outstanding_group_key,
            SUM(CASE WHEN otba.netting_type = 'SACCR_CC_R' THEN otba.os_amt END) cc_amt_deriv,
            SUM(CASE WHEN otba.netting_type = 'SACCR_GC_R' THEN otba.os_amt END) gc_amt_deriv,
            SUM(CASE WHEN otba.netting_type = 'SACCR_NC_R' THEN otba.os_amt END) nc_amt_deriv,
		SUM(CASE WHEN otba.netting_type = 'CIR' THEN otba.os_amt END) cir_amt,
        SUM(CASE WHEN otba.netting_type = 'CCR' THEN otba.os_amt END) ccr_amt,
        SUM(CASE WHEN otba.netting_type = 'CC' THEN otba.os_amt END) cc_amt,
        SUM(CASE WHEN otba.netting_type = 'GIR' THEN otba.os_amt END) gir_amt,
        SUM(CASE WHEN otba.netting_type = 'GCR' THEN otba.os_amt END) gcr_amt,
        SUM(CASE WHEN otba.netting_type = 'GC' THEN otba.os_amt END) gc_amt,
        SUM(CASE WHEN otba.netting_type = 'NIR' THEN otba.os_amt END) nir_amt,
        SUM(CASE WHEN otba.netting_type = 'NCR' THEN otba.os_amt END) ncr_amt,
        SUM(CASE WHEN otba.netting_type = 'NC' THEN otba.os_amt END) nc_amt,
        SUM(CASE WHEN otba.netting_type = 'ON' THEN otba.os_amt END) on_amt
      FROM TMP_COREP_OUTSTANDING_TIME_BAND_FACT_B4 otba
      WHERE otba.first_timeband = 1
      GROUP BY otba.outstanding_group_key) t
    ON ( rm.outstanding_group_key = t.outstanding_group_key )
	    WHEN MATCHED THEN UPDATE SET rm.after_coll_regulatory_os_amt = CASE WHEN rm.system_id = 'CRS' AND rm.basel_approach = 'AIRB' AND rm.corep_counterparty_cluster <> 'DERIV'
																		THEN round(t.cir_amt * rm.pro_rata_factor,2)
                                                                        WHEN rm.system_id = 'CRS' AND rm.basel_approach = 'SA' AND rm.corep_counterparty_cluster <> 'DERIV'
																		THEN round(t.ccr_amt * rm.pro_rata_factor,2)
                                                                        ELSE CASE WHEN rm.corep_counterparty_cluster = 'DERIV'
																				  THEN round(t.cc_amt_deriv * rm.pro_rata_factor,2)
																				  ELSE round(t.cc_amt * rm.pro_rata_factor,2)
																			 END
                                                                   END,
                                 rm.gross_regulatory_os_amt = CASE 	WHEN rm.system_id = 'CRS' AND rm.basel_approach = 'AIRB' AND rm.corep_counterparty_cluster <> 'DERIV'
																	THEN round(t.gir_amt * rm.pro_rata_factor,2)
                                                                   WHEN rm.system_id = 'CRS' AND rm.basel_approach = 'SA' AND rm.corep_counterparty_cluster <> 'DERIV'
																   THEN round(t.gcr_amt * rm.pro_rata_factor,2)
                                                                   ELSE CASE WHEN rm.corep_counterparty_cluster = 'DERIV'
																				  THEN round(t.gc_amt_deriv * rm.pro_rata_factor,2)
																				  ELSE round(t.gc_amt * rm.pro_rata_factor,2)
																		END
                                                              END,
                                 rm.regulatory_os_amt = CASE WHEN rm.system_id = 'CRS' AND rm.basel_approach = 'AIRB' AND rm.corep_counterparty_cluster <> 'DERIV'
															 THEN round(t.nir_amt * rm.pro_rata_factor,2)
                                                             WHEN rm.system_id = 'CRS' AND rm.basel_approach = 'SA' AND rm.corep_counterparty_cluster <> 'DERIV'
															 THEN round(t.ncr_amt * rm.pro_rata_factor,2)
                                                             ELSE CASE WHEN rm.corep_counterparty_cluster = 'DERIV'
																				  THEN round(t.nc_amt_deriv * rm.pro_rata_factor,2)
																				  ELSE round(t.nc_amt * rm.pro_rata_factor,2)
																  END
                                                        END,
                                 rm.old_regulatory_os_amt = CASE WHEN rm.system_id = 'CRS' AND rm.basel_approach = 'AIRB' AND rm.corep_counterparty_cluster <> 'DERIV'
																 THEN round(t.nir_amt * rm.pro_rata_factor,2)
                                                                 WHEN rm.system_id = 'CRS' AND rm.basel_approach = 'SA' AND rm.corep_counterparty_cluster <> 'DERIV'
																 THEN round(t.ncr_amt * rm.pro_rata_factor,2)
                                                                 WHEN rm.system_id = 'CRS' AND t.on_amt IS NOT NULL AND rm.corep_counterparty_cluster <> 'DERIV'
																 THEN round(t.on_amt * rm.pro_rata_factor,2)
                                                                 ELSE CASE WHEN rm.corep_counterparty_cluster = 'DERIV'
																				  THEN round(t.nc_amt_deriv * rm.pro_rata_factor,2)
																				  ELSE round(t.nc_amt * rm.pro_rata_factor,2)
																  END
                                                            END;
        END;
COMMIT;

UPDATE tmp_corep_recap_measure_pre_b4
SET after_coll_regulatory_os_amt = CASE WHEN original_ind = 1 THEN round(after_coll_regulatory_os_amt * conversion_ratio_on_balance,2) ELSE NULL END,
	gross_regulatory_os_amt 	 = CASE WHEN original_ind = 1 THEN round(gross_regulatory_os_amt * conversion_ratio_on_balance,2) ELSE NULL END,
	regulatory_os_amt 			 = CASE WHEN original_ind = 1 THEN round(regulatory_os_amt * conversion_ratio_on_balance,2) ELSE NULL END,
	old_regulatory_os_amt 		 = CASE WHEN original_ind = 1 THEN round(old_regulatory_os_amt * conversion_ratio_on_balance,2) ELSE NULL END;
COMMIT;

    utilities.insert_dmi_log_basel(
                                    v_detail_level    => 103,
                                    v_log_descr       => 'process_pre_corep_recap_b4',
                                    v_activity_code   => 'regos amounts',
                                    v_result_code     => 'FINOK',
                                    v_system_id       => ' '
                                );
-----------------------------------

    insert_dmb_log_corep(v_detail_level    => 103,
                                   v_log_descr       => 'process_pre_corep_recap_b4',
                                   v_activity_code   => 'CCR',
                                   v_result_code     => 'START',
                                   v_system_id       => v_system_id,v_reporting_date       => v_reporting_date
                                   );

/* Code block for DPM3.0 SACCR new feilds STRY2194233*/
MERGE INTO tmp_corep_recap_measure_pre_b4 t
USING (SELECT t.ROWID row_id, CASE
WHEN t.corep_counterparty_cluster = 'SECFIN' AND o.agreement_id IS NULL THEN 0                                            -- Change story 3579360
WHEN t.corep_counterparty_cluster = 'DERIV' AND oms.code = 'UNMARGINED' and t.customer_type_level3_code <> 'FCCP' THEN 0  -- Change story 3579360
WHEN t.corep_counterparty_cluster NOT IN ( 'SECFIN','DERIV') THEN NULL                                                    -- Change story 3579360
ELSE 1 END AS ccr_margined_indicator                                                                                      -- Change story 3579360
FROM tmp_corep_recap_measure_pre_b4 t
       JOIN dwh_outstanding o   ON t.outstanding_key = o.outstanding_key AND
	       o.system_id = v_system_id --  modification corep_vpp
	   AND o.record_valid_from = v_reporting_date --  modification corep_vpp
       LEFT JOIN os_margin_status oms   ON o.os_margin_status_key = oms.os_margin_status_key ) src
ON ( t.ROWID = src.row_id )
WHEN MATCHED THEN UPDATE SET t.ccr_margined_indicator = src.ccr_margined_indicator;
commit;
utilities.truncate_table('TMP_COREP_OUTSTANDING_COMPONENT_B4');

INSERT INTO TMP_COREP_OUTSTANDING_COMPONENT_B4
  ( outstanding_key, min_component_per_ipa, min_component_per_outstanding, outstanding_component_id, ast_clss_ipa_code, os_comp_security_type_code, os_comp_direction_code, hedging_set, os_comp_direction_key )
  SELECT oc.outstanding_key ,
         CASE
              WHEN (ROW_NUMBER() OVER ( PARTITION BY oc.outstanding_key, oc.ast_clss_ipa_key ORDER BY CAST(oc.outstanding_component_id AS NUMBER(18)) ASC  )) = 1 THEN 1
         ELSE 0
            END min_component_per_ipa  ,
         CASE
              WHEN (ROW_NUMBER() OVER ( PARTITION BY oc.outstanding_key ORDER BY CAST(oc.outstanding_component_id AS NUMBER(18)) ASC  )) = 1 THEN 1
         ELSE 0
            END min_component_per_outstanding  ,
         oc.outstanding_component_id outstanding_component_id  ,
         aci.code ast_clss_ipa_code  ,
         ocst.code os_comp_security_type_code  ,
         ocd.code os_comp_direction_code  ,
         oc.hedging_set ,
         oc.os_comp_direction_key
    FROM dwh_outstanding_component oc
           LEFT JOIN ast_clss_ipa aci   ON oc.ast_clss_ipa_key = aci.ast_clss_ipa_key
           LEFT JOIN os_comp_security_type ocst   ON oc.os_comp_security_type_key = ocst.os_comp_security_type_key
           LEFT JOIN os_comp_direction ocd   ON oc.os_comp_direction_key = ocd.os_comp_direction_key
   WHERE --(oc.record_valid_from, oc.system_id) IN  ( SELECT /*+ PRECOMPUTE_SUBQUERY */ reporting_date, system_id FROM tmp_basel_combined_uploads)
       oc.system_id = v_system_id --  modification corep_vpp
   AND oc.record_valid_from = v_reporting_date --  modification corep_vpp
   AND EXISTS ( SELECT 1
                   FROM tmp_corep_recap_measure_pre_b4
                    WHERE  outstanding_key = oc.outstanding_key );
commit;
MERGE INTO tmp_corep_recap_measure_pre_b4 p
USING (SELECT s.ROWID row_id, t.cnt_ast_clss_ipa_code
FROM tmp_corep_recap_measure_pre_b4 s,( SELECT outstanding_key ,
                                           COUNT(DISTINCT ast_clss_ipa_code)  cnt_ast_clss_ipa_code
                                    FROM TMP_COREP_OUTSTANDING_COMPONENT_B4 toc
                                      GROUP BY toc.outstanding_key ) t
 WHERE s.outstanding_key = t.outstanding_key) src
ON ( p.ROWID = src.row_id )
WHEN MATCHED THEN UPDATE SET p.ccr_nr_of_risk_categories = src.cnt_ast_clss_ipa_code;
commit;
MERGE INTO tmp_corep_recap_measure_pre_b4 p
USING (SELECT s.ROWID row_id, t.ast_clss_ipa_code
FROM tmp_corep_recap_measure_pre_b4 s,( SELECT outstanding_key ,
                                           MAX(ast_clss_ipa_code)  ast_clss_ipa_code
                                    FROM TMP_COREP_OUTSTANDING_COMPONENT_B4 toc
                                     WHERE  toc.min_component_per_outstanding = 1
                                      GROUP BY toc.outstanding_key ) t
 WHERE s.outstanding_key = t.outstanding_key) src
ON ( p.ROWID = src.row_id )
WHEN MATCHED THEN UPDATE SET p.ccr_material_risk_category = src.ast_clss_ipa_code;
commit;

MERGE INTO tmp_corep_recap_measure_pre_b4 rm USING (
        SELECT
            s.rowid   row_id,
            t.cred_deriv_direction_key,
            t.ccr_hedging_set_interest_rate,
            t.ccr_hedging_set_forex,
            t.ccr_hedging_set_equity,
            t.ccr_hedging_set_commodity,
            t.ccr_hedging_set_credit_risk
        FROM
            tmp_corep_recap_measure_pre_b4 s,
            (
                SELECT
                    toc.outstanding_key,
                    MAX(CASE
                        WHEN toc.ast_clss_ipa_code = 'CR' THEN toc.os_comp_direction_key
                    END) cred_deriv_direction_key,
                    MAX(CASE
                        WHEN toc.ast_clss_ipa_code = 'IR' THEN nvl(toc.hedging_set,'IR_NULL'
                        )
                    END) ccr_hedging_set_interest_rate,
                    MAX(CASE
                        WHEN toc.ast_clss_ipa_code = 'FX' THEN nvl(toc.hedging_set,'FX_NULL'
                        )
                    END) ccr_hedging_set_forex,
                    MAX(CASE
                        WHEN toc.ast_clss_ipa_code = 'EQ' THEN toc.os_comp_security_type_code
                    END) ccr_hedging_set_equity,
                    MAX(CASE
                        WHEN toc.ast_clss_ipa_code = 'CO' THEN nvl(toc.hedging_set,'CO_NULL'
                        )
                    END) ccr_hedging_set_commodity,
                    MAX(CASE
                        WHEN toc.ast_clss_ipa_code = 'CR' THEN toc.os_comp_security_type_code
                    END) ccr_hedging_set_credit_risk
                FROM
                    TMP_COREP_OUTSTANDING_COMPONENT_B4 toc
                WHERE
                    toc.min_component_per_ipa = 1
                GROUP BY
                    toc.outstanding_key
            ) t
        WHERE
            s.outstanding_key = t.outstanding_key
    )
src ON ( rm.rowid = src.row_id )
WHEN MATCHED THEN UPDATE SET cred_deriv_direction_key = src.cred_deriv_direction_key,
                            ccr_hedging_set_interest_rate = src.ccr_hedging_set_interest_rate,
                            ccr_hedging_set_forex = src.ccr_hedging_set_forex,
                            ccr_hedging_set_equity = src.ccr_hedging_set_equity,
                            ccr_hedging_set_commodity = src.ccr_hedging_set_commodity,
                            ccr_hedging_set_credit_risk = src.ccr_hedging_set_credit_risk;


commit;
MERGE INTO tmp_corep_recap_measure_pre_b4 rm
USING (SELECT rm.ROWID row_id, CASE
WHEN t.outstanding_key IS NOT NULL THEN 1
ELSE 0
   END AS saccr_calculation_indicator
FROM tmp_corep_recap_measure_pre_b4 rm
       LEFT JOIN ( SELECT TMP_COREP_OUTSTANDING_COMPONENT_B4.outstanding_key
                   FROM TMP_COREP_OUTSTANDING_COMPONENT_B4
                     GROUP BY TMP_COREP_OUTSTANDING_COMPONENT_B4.outstanding_key ) t   ON rm.outstanding_key = t.outstanding_key
 WHERE rm.corep_counterparty_cluster = 'DERIV') src
ON ( rm.ROWID = src.row_id )
WHEN MATCHED THEN UPDATE SET rm.saccr_calculation_indicator = src.saccr_calculation_indicator;
commit;
UPDATE TMP_COREP_OUTSTANDING_COMPONENT_B4 t
   SET t.os_comp_direction_code = 'LONG'
 WHERE  EXISTS ( SELECT 1
                 FROM TMP_COREP_OUTSTANDING_COMPONENT_B4
                  WHERE  TMP_COREP_OUTSTANDING_COMPONENT_B4.outstanding_key = t.outstanding_key
                           AND TMP_COREP_OUTSTANDING_COMPONENT_B4.os_comp_direction_code = 'LONG' );


UPDATE TMP_COREP_OUTSTANDING_COMPONENT_B4 t
   SET t.os_comp_direction_code = 'LONG'
 WHERE  NOT EXISTS ( SELECT 1
                     FROM TMP_COREP_OUTSTANDING_COMPONENT_B4
                      WHERE  TMP_COREP_OUTSTANDING_COMPONENT_B4.outstanding_key = t.outstanding_key
                               AND TMP_COREP_OUTSTANDING_COMPONENT_B4.os_comp_direction_code <> 'NONE' );
commit;

UPDATE TMP_COREP_OUTSTANDING_COMPONENT_B4
   SET os_comp_direction_code = 'SHORT'
 WHERE  os_comp_direction_code = 'NONE';
commit;
MERGE INTO tmp_corep_recap_measure_pre_b4 p
USING (SELECT s.ROWID row_id, t.os_comp_direction_key
FROM tmp_corep_recap_measure_pre_b4 s,( SELECT outstanding_key ,
                                           MAX(ocd.os_comp_direction_key)  os_comp_direction_key
                                    FROM TMP_COREP_OUTSTANDING_COMPONENT_B4 toc,
                                         os_comp_direction ocd
                                     WHERE  toc.os_comp_direction_code = ocd.code
                                              AND ocd.record_valid_until IS NULL
                                      GROUP BY toc.outstanding_key ) t
 WHERE s.outstanding_key = t.outstanding_key) src
ON ( p.ROWID = src.row_id )
WHEN MATCHED THEN UPDATE SET os_comp_direction_key = src.os_comp_direction_key;
commit;
    insert_dmb_log_corep(v_detail_level    => 103,
                                   v_log_descr       => 'process_pre_corep_recap_b4',
                                   v_activity_code   => 'CCR',
                                   v_result_code     => 'FINOK',
                                   v_system_id       => v_system_id,v_reporting_date       => v_reporting_date
                                   );
    BEGIN
        INSERT /*+ APPEND +*/ INTO tmp_corep_recap_measure_b4
        (
        exposure_class,
        cover_id,
        capital_requirement,
        expected_loss,
        exposure_at_default,
        loss_given_default,
        outstanding_group_id,
        outstanding_group_key,
        pd,
        alloc_provision_amt,
        risk_weighted_assets,
        risk_weight_factor,
        rating_key,
        exposure_original,
        exposure_original_drawn,
        allocated_limit_amt,
        exposure_pre_ccf,
        allocated_outstanding_amt,
        exposure_pre_ccf_drawn,
        conversion_ratio,
        basel_approach,
        original_cover_value,
        g_factor,
        k_factor,
        regulator,
       -- sync_key,
       -- sync_key_n,
        on_balance_ind,
        credit_quality_step,
        credit_quality_step_sec,
        residual_value_amount,
        residual_value_capital_req,
        residual_value_risk_weight,
        record_valid_from,
        system_id,
        credit_conversion_factor,
        risk_weighted_assets_due_dill,
        risk_weighted_assets_sec_mat_mism,
        risk_degree_code,
        risk_weight_substitution,
        conversion_ratio_exposure,
        conversion_ratio_fin_coll,
        conversion_ratio_on_balance,
        fully_adjusted_exposure_on_sa,
        fully_adjusted_exposure_off_sa,
        financial_collateral_sa,
        exposure_net_provision_sa,
        volatility_maturity_adj,
        conversion_ratio_off_balance,
        retained_position_ind,
        securitisation_key,
        securitised_ind,
        exposure_original_undrawn,
        exposure_pre_ccf_undrawn,
        source_table,
        original_ind,
        applied_ind,
        customer_key,
        customer_id,
        effective_maturity,
        facility_id,
        outstanding_id,
        outstanding_key,
        official_approach_indicator,
        --basel2_portfolio_code,
        basel2_official_approach,
        sec_category,
        large_or_unregulated_fin_entity_ind,
        h_factor,
        --e_factor,
        direct_cost,
        indirect_cost,
        cure_rate,
        unsecured_recovery_amounts,
        unsecured_recovery_amounts_discounted,
        unsecured_discount_factor,
        secured_recovery_amounts,
        secured_recovery_amounts_discounted,
        facility_key,
        committed_indicator,
        after_coll_regulatory_os_amt,
        gross_regulatory_os_amt,
        regulatory_os_amt,
        old_regulatory_os_amt,
        ccp_counterparty_indicator,
        in_default_ind,
        pro_rata_factor,
        risk_weight_asset_original,
        source,
        inflow,
        --rating_agency_key,
        external_rating,
        --rating_agency_sec_key,
        --external_rating_sec,
        sec_rating_approach,
        cqs_cen_gov_ind,
        on_balance_ratio,
        on_balance_ratio_exposure,
        on_balance_ratio_collateral_sa,
        on_balance_ratio_fin_coll,
        securitised_factor,
        provision_category,
        exposure_class_sa_not_def_sec,
        risk_weight_asset_pre_sme_fact,
        subject_to_sme_factor_ind,
        exposure_class_sa_not_def,
        lr_on_balance_ratio,
        lr_on_balance_ratio_exposure,
        conversion_ratio_exposure_lr,
        lr_k_factor,
        lr_g_factor,
        lre_amount,
        lre_on_balance,
        lre_off_balance_before_ccf,
        lre_off_balance_after_ccf,
        LR_CCF_10PERCENT,
        LR_CCF_20PERCENT,
        LR_CCF_40PERCENT,
        LR_CCF_50PERCENT,
        LR_CCF_100PERCENT,
        effective_regulated_indicator,
        netted_indicator,
        off_supp_credit_indicator,
        notional_amount,
        mtm_amount,
        add_on,
        calculated_add_on,
        net_mtm_amount,
        ccf_0percent_irb,
        --ccf_20percent_irb,
        --ccf_50percent_irb,
        --ccf_100percent_irb,
        --cva_exposure,
        --cva_effective_maturity,
        --cva_risk_weight,
        --diversification_cva_ratio,
        --diversified_cva_capital,
        correlation_factor,
        in_default_ind_original,
        --provision_amount_llp,
        --provision_category_llp,
        --finrep_subordination_code,
        sme_ind,
        risk_weight_add_on_factor,
        risk_weight_add_on_term,
        risk_weight_factor_original,
        basel_local_official_approach,
        --rwa_pre_sme_including_addonterm,
        --rwa_including_addonterm,
        --accrued_interest_amt,
        residual_maturity_months,
        residual_maturity_bucket_code,
        ifrs_accounting_classification,
        ifrs_measurement_category,
        rwa_including_addon,
        rwa_pre_sme_including_addon,
        rwa_add_on_report_classification,
        sts_indicator,
        sec_calculation_method,
        sts_qualif_diff_treatment_ind,
        capital_requirement_c_09_04,
        exposure_at_default_c_09_04,
        zero_rrw_sov_indicator,
        strict_prudential_rw_ind,
        strict_lgd_floor_ind,
        rwa_ex_add_on,
        rwa_pre_sme_fact_ex_add_on,
        --rw_dod_add_on_f_global_charge,
        --rwa_add_on_for_dod,
        --rwa_add_on_for_term_factor,
        exposure_amount,
        cover_key,
        cover_type_key,
        cover_provider_id,
        cover_provider_key,
        cover_ctry_key,
        cover_ctry_code,
        finrep_sector,
        cover_ctry_ec_ind,
        --next_review_date,
        --principal_next_review_date,
        --econ_parent_review_date_bucket_key,
        --legal_parent_review_date_bucket_key,
        intercompany_code,
        --review_date_bucket_key,
        --legal_ult_parent_risk_rating_key,
        --legal_ult_parent_risk_rating_owner_key,
        --econ_ult_parent_risk_rating_key,
        --econ_ult_parent_risk_rating_owner_key,
        legal_principal_ult_parent_id,
        principal_borrower_id,
        ctry_of_incorporation_key,
        ctry_of_residence_key,
        customer_type_key,
        econ_ult_parent_id,
        --econ_ult_parent_key,
        --industry_type_key,
        segmentation_type_key,
        --worst_ctry_of_risk_key,
        legal_ult_parent_id,
        --legal_ult_parent_key,
        --cust_status_key,
        booking_office_key,
        initiating_office_key,
        mis_raroc_product_type_key,
        original_ccy_key,
        risk_rating_key,
        --risk_rating_owner_key,
        auth_combination_key,
        --next_review_date_cdd,
        --review_date_cdd_bucket_key,
        --lup_review_date_cdd_bucket_key,
        --eup_review_date_cdd_bucket_key,
        --next_review_date_mifid,
        --review_date_mifid_bucket_key,
        --lup_review_date_mifid_bucket_key,
        --eup_review_date_mifid_bucket_key,
        --next_review_date_br,
        --review_date_br_bucket_key,
        --lup_review_date_br_bucket_key,
        --eup_review_date_br_bucket_key,
        --review_date_cdd_owner_key,
        --lup_review_date_cdd_owner_key,
        --eup_review_date_cdd_owner_key,
        --review_date_mifid_owner_key,
        --lup_review_date_mifid_owner_key,
        --eup_review_date_mifid_owner_key,
        --review_date_br_owner_key,
        --lup_review_date_br_owner_key,
        --eup_review_date_br_owner_key,
        --customer_type_cdd_key,
        --customer_type_mifid_key,
        --classification_mifid_key,
        --classification_mifid_code,
        --risk_level_cdd_key,
        --risk_level_cdd_code,
        ead_model_code,
        lgd_model_code,
        ead_model_key,
        lgd_model_key,
        os_accounting_unit_key,
        os_ing_legal_entity_key,
        product_type_key,
        --segmentation_type_poland_key,
        --segmentation_type_belgium_key,
        --segmentation_type_india_key,
        --segmentation_type_netherlands_key,
        --segmentation_type_romania_key,
        --segmentation_type_turkey_key,
        maximum_limit_amt,
        booking_base_entity_key,
        initiating_base_entity_key,
        --compliance_department_key,
        --lup_compliance_department_key,
        --eup_compliance_department_key,
        --maintenance_unit_key,
        --lup_maintenance_unit_key,
        --eup_maintenance_unit_key,
        local_outstanding_id,
        --generated_record,
        secondary_currency_key,
        fac_accounting_unit_key,
        fac_booking_office_key,
        fac_ing_legal_entity_key,
        fac_initiating_office_key,
        --fac_original_ccy_key,
        facility_purpose_key,
        facility_type_key,
        limit_end_date,
        orig_end_date,
        limit_start_date,
        orig_start_date,
        risk_rating_type,
        cover_type_combination_key,
        higher_level_facility_key,
        limit_type_indicator,
        --segmentation_code_up_pb_hf,
        principal_borrower_key,
        fac_mis_raroc_product_type_key,
        multi_ccy_indicator,
        --fac_generated_record,
        higher_level_facility_id,
        highest_level_facility_id,
        fac_booking_base_entity_key,
        fac_initiating_base_entity_key,
        exposure_class_code,
        facility_hierarchy_level,
        maturity_date,
        orig_maturity_date,
        bond_rating_agency_code,
        bond_rating_code,
        --exchange_rate,
        os_max_remaining_tenor,
        fac_max_remaining_tenor,
        master_scale_level4_code,
        risk_rating_code,
        ctry_of_residence_code,
        ctry_of_incorporation_code,
        --ctry_of_incorp_pr_borr_key,
        --ctry_of_incorp_pr_borr_code,
        ctry_of_incorp_guarantor_key,
        ctry_of_incorp_guarantor_code,
        risk_degree_key,
        facility_type_code,
        facility_purpose_code,
        cover_type_code,
        corep_cover_cluster,
        product_type_code,
        default_fund_contr_ind,
        --qccp_initial_margin,
        corep_counterparty_cluster,
        lr_deriv_classification,
        finrep_product_code,
        risk_category_level1_code,
        risk_category_level1_key,
        booking_office_code,
        initiating_office_code,
        --fac_booking_office_code,
        --fac_initiating_office_code,
        securitisation_code,
        rating_agency_code,
        --rating_agency_sec_code,
        credit_qual_step_sec_inc,
        --grouping_key,
        with_cai_ind,
        counterparty_ind,
        --cva_cap_eligible_recap,
        permanent_sa_ind,
        outflow,
        original_cover_value_abs,
        fully_adjusted_exposure,
        residual_value_risk_weight_asset,
        --residual_value_risk_weight_asset_abs,
        exposure_at_default_abs,
        residual_value_amount_abs,
        ccf_0percent,
        ccf_20percent,
        ccf_50percent,
        ccf_100percent,
        e_factor_limit,
        e_factor_os,
        --endmonth_indicator,
        --endmonth_3m_indicator,
        --endmonth_6m_indicator,
        --endmonth_12m_indicator,
        --endmonth_vortexi_indicator,
        --quarter_5q_indicator,
        --recent_indicator,
        on_balance_sheet_ind,
        negative_limit_ind,
        sec_ccf_drawn_bucket,
        --gk_factor,
        sec_ccf_undrawn_bucket,
        lr_counterparty_cluster,
        customer_type_level3_code,
        lr_covered_bond_ind,
        trade_finance_ind,
        lr_exposure_classification,
        lr_customer_type,
        exposure_weighted_avg_lgd,
        k_a_parameter_w,
        k_irb,
        k_sa,
        ppu_sa_ind,
        risk_weight_excl_strict_prud,
        rwa_pre_sme_fact_ex_strict_prud,
        rwa_ex_strict_prud,
        subject_to_infra_factor_ind,
        risk_weight_asset_pre_infra_fact,
        --rwa_pre_infra_fct_ex_add_on,
        rwa_pre_infra_fct_ex_strict_prud,
        rwa_sme_support_amt,
        rwa_infra_support_amt,
        lgd_pre_cds,
        pd_original_after_multipliers,
        branch_indicator, --ADDED FROM MERGE CU7
        legal_imm_parent_id, --ADDED FROM MERGE CU7
        exposure_class_original,--CU7
        exposure_class_applied, --CU7
        large_exposure_sector, --CU7 missing code
        ccr_replacement_cost,
        ccr_addon,
        ccr_potential_future_exp,
        ccr_exp_value_pre_crm,
        ccr_exp_value_post_crm,
        lre_ccr_replacement_cost,
        ccr_variation_margin,
        lre_ccr_variation_margin,
        ccr_net_indep_collat_amt,
        eca_indicator,
        secured_by_com_prop_ind,
        secured_by_res_prop_ind,
        cdspb_facility_ind,
        local_official_approach_indicator,
        --finan_guarantee_given_ind,
        --days_past_due,
        --secured_by_com_prop_os_ind,
        --secured_by_res_prop_os_ind,
        --secured_by_non_mort_os_ind,
        default_fund_ind,
        ccr_wrong_way_risk_indicator,
        observed_new_default_ip_ind,
        observed_new_default_ind,
        --cva_amount,
        --dva_amount,
        incurredcva_amount,
        seniority_basel_class,
        securitisation_sponsor_key,
        securitisation_investor_key,
        lr_exposure_type,
        lr_exposure_subtype,
        ccr_margined_indicator,
        ccr_nr_of_risk_categories,
        ccr_material_risk_category,
        cred_deriv_direction_key,
        ccr_hedging_set_interest_rate,
        ccr_hedging_set_forex,
        ccr_hedging_set_equity,
        ccr_hedging_set_commodity,
        ccr_hedging_set_credit_risk,
        saccr_calculation_indicator,
        os_comp_direction_key,
	    cover_fx_haircut,
        secured_discount_factor,
        dd_classification,
        risk_weighted_assets_pre_cds,
        regulator_combination_key,
        risk_weight_factor_bucket_key,
		risk_weight_factor_bucket_code,
		lr_risk_weight_bucket_code,
        ccf_irb,
		corep_pd_range,
		cover_amount_after_hc,
		--advised_indicator,
		--accounting_classification,
		--finrep_limit_type1_code,
		--finrep_limit_type2_code,
		--industry_nace20_level1_code,
		gross_carrying_amt,
		csa_key,
		security_id,
        security_id_type,
        risk_weight_factor_macro_prud,--New column added AB 5033337
        rwa_pre_sme_fact_macro_prud,--New column added   AB STRY3055404
        rwa_pre_infra_fact_macro_prud,--New column added AB 5033337
        rwa_macro_prud,--New column added AB 5033337
		--macro_prud_rw_ltv,  -- New column added AB STRY3055404
        leverage_sme_ind, -- New column for story STRY3563101
		reporting_date,
        risk_weight_asset_orig_obligor,  --added as part of STRY2099796
        risk_weight_asset_sec_erba, --STRY3694837   AB
        risk_weight_asset_sec_sa,    --STRY3694837  AB
        country_of_incorporation, -- New column Added for Story 2244791
		substitution_method, --added as part of 2119302
		rw_substitution_method, --added as part of 2119302
		--rw_floor, --added as part of 2119302
		official_approach_applied, --added as part of 2119302
		ead_exclusion_ind,  --added as part of 20231130 Check again for B4
		--risk_weight_asset_sec_tr,
        configuration_code,
        condition_outcome_code,
        ccf_10percent,
        ccf_40percent,
        COVER_SPLIT_KEY,
        property_ratio_from,
        property_ratio_until,
        EAD_RATIO,
        COLLATERALISATION_RATIO,
        exposure_class_irb_in_sa,
        exposure_class_sa_in_irb,
        res_imm_prop_ind,
        com_imm_prop_ind,
        regulatory_large_corp_ind,
		ccf_ucc_transitional 	,
		rwa_non_ccf_ucc_trans 	,
        SPLIT_RATIO,
        ucc_non_trans_on_balance_ratio_exposure,
        ucc_non_trans_conversion_ratio_exposure,
		basel_approach_original,
		ccf_100percent_irb,
        regulatory_ead_applied,
        exposure_class_sa_original,
		lr_exposure_type_original,
		lr_exposure_subtype_original,
		risk_weight_asset_pre_fx_mm,
		risk_weight_factor_pre_fx_mm,
		rw_factor_pre_fx_mm_bucket_code,
        modelled_ccf,
		loan_split_derogation_ind,
		risk_weight_art378,
		exposure_amount_art378,
		rwa_art378,
		book_risk_category,
		settlement_date,
        days_unsettled_after_due_date,
		settlement_amount,
		unsecuritised_factor,
		sec_pro_rata_factor,
        official_challenger_indicator,
		on_balance_ratio_exp_pre_ccf,
		inscription_value
		)
		    SELECT
		    crm.exposure_class,
            crm.cover_id,
            crm.capital_requirement,
            crm.expected_loss,
            crm.exposure_at_default,
            crm.loss_given_default,
            crm.outstanding_group_id,
            crm.outstanding_group_key,
            crm.pd,
            crm.alloc_provision_amt,
            crm.risk_weighted_assets,
            crm.risk_weight_factor,
            crm.rating_key,
            crm.exposure_original,
            crm.exposure_original_drawn,
            crm.allocated_limit_amt,
            --crm.exposure_pre_ccf,
            case when crm.source_table = 'IRB' and crm.original_ind = 1 and crm.on_balance_sheet_ind=0 then round((tmp.exposure_pre_ccf_drawn * crm.conversion_ratio_on_balance) + (tmp.exposure_pre_ccf_undrawn * crm.conversion_ratio_off_balance),2)
                 when crm.source_table = 'IRB' and crm.original_ind = 1 and crm.on_balance_sheet_ind = 1 and crm.on_balance_ind = 1 then round(tmp.exposure_pre_ccf_drawn * crm.conversion_ratio_on_balance, 2)
                 when crm.source_table = 'IRB' and crm.original_ind = 1 and crm.on_balance_sheet_ind = 1 and crm.on_balance_ind = 0 then round(tmp.exposure_pre_ccf_undrawn * crm.conversion_ratio_off_balance, 2)
                 else crm.exposure_pre_ccf
            END AS exposure_pre_ccf,
            crm.allocated_outstanding_amt,
            crm.exposure_pre_ccf_drawn,
            crm.conversion_ratio,
            crm.basel_approach,
            --crm.original_cover_value,
            case when crm.source_table = 'IRB' and crm.original_ind = 1 and crm.risk_weight_substitution<>1 then round(tmp.original_cover_value * crm.conversion_ratio, 2)
                 when crm.source_table = 'IRB' and crm.original_ind = 1 and crm.risk_weight_substitution=1 and crm.on_balance_sheet_ind=0 then round(tmp.original_cover_value, 2)
                 when crm.source_table = 'IRB' and crm.original_ind = 1 and crm.risk_weight_substitution=1 and crm.on_balance_sheet_ind = 1 then round(tmp.original_cover_value * crm.conversion_ratio_exp_pre_ccf, 2)
                 else crm.original_cover_value
            END AS original_cover_value,
            crm.g_factor,
            crm.k_factor,
            crm.regulator,
            --crm.sync_key,
            --crm.sync_key_n,
            crm.on_balance_ind,
            crm.credit_quality_step,
            crm.credit_quality_step_sec,
            crm.residual_value_amount,
            crm.residual_value_capital_req,
            crm.residual_value_risk_weight,
            crm.record_valid_from,
            crm.system_id,
            crm.credit_conversion_factor,
            crm.risk_weighted_assets_due_dill,
            crm.risk_weighted_assets_sec_mat_mism,
            crm.risk_degree_code,
            crm.risk_weight_substitution,
            crm.conversion_ratio_exposure,
            crm.conversion_ratio_fin_coll,
            crm.conversion_ratio_on_balance,
            crm.fully_adjusted_exposure_on_sa,
            crm.fully_adjusted_exposure_off_sa,
            crm.financial_collateral_sa,
            crm.exposure_net_provision_sa,
            crm.volatility_maturity_adj,
            crm.conversion_ratio_off_balance,
            crm.retained_position_ind,
            crm.securitisation_key,
            crm.securitised_ind,
            crm.exposure_original_undrawn,
            crm.exposure_pre_ccf_undrawn,
            crm.source_table,
            crm.original_ind,
            crm.applied_ind,
            crm.customer_key,
            crm.customer_id,
            crm.effective_maturity,
            crm.facility_id,
            crm.outstanding_id,
            crm.outstanding_key,
            crm.official_approach_indicator,
            --crm.basel2_portfolio_code,
            crm.basel2_official_approach,
            crm.sec_category,
            crm.large_or_unregulated_fin_entity_ind,
            crm.h_factor,
            --crm.e_factor,
            crm.direct_cost,
            crm.indirect_cost,
            crm.cure_rate,
            crm.unsecured_recovery_amounts,
            crm.unsecured_recovery_amounts_discounted,
            crm.unsecured_discount_factor,
            crm.secured_recovery_amounts,
            crm.secured_recovery_amounts_discounted,
            crm.facility_key,
            crm.committed_indicator,
            crm.after_coll_regulatory_os_amt,
            crm.gross_regulatory_os_amt,
            crm.regulatory_os_amt,
            crm.old_regulatory_os_amt,
            crm.ccp_counterparty_indicator,
            crm.in_default_ind,
            crm.pro_rata_factor,
            crm.risk_weight_asset_original,
            crm.source,
            --crm.inflow,
            case when crm.source_table = 'IRB' AND crm.applied_ind = 1 and crm.risk_weight_substitution=1 and crm.on_balance_sheet_ind=0 then round((tmp.exposure_pre_ccf_drawn * crm.conversion_ratio_on_balance) + (tmp.exposure_pre_ccf_undrawn * crm.conversion_ratio_off_balance),2)
                 when crm.source_table = 'IRB' AND crm.applied_ind = 1 and crm.risk_weight_substitution=1 and crm.on_balance_sheet_ind = 1 and crm.on_balance_ind = 1 then round(tmp.exposure_pre_ccf_drawn * crm.conversion_ratio_on_balance, 2)
                 when crm.source_table = 'IRB' AND crm.applied_ind = 1 and crm.risk_weight_substitution=1 and crm.on_balance_sheet_ind = 1 and crm.on_balance_ind = 0 then round(tmp.exposure_pre_ccf_undrawn * crm.conversion_ratio_off_balance, 2)
                 else crm.inflow
            END AS INFLOW,
            --crm.rating_agency_key,
            crm.external_rating,
            --crm.rating_agency_sec_key,
            --crm.external_rating_sec,
            crm.sec_rating_approach,
            crm.cqs_cen_gov_ind,
            crm.on_balance_ratio,
            crm.on_balance_ratio_exposure,
            crm.on_balance_ratio_collateral_sa,
            crm.on_balance_ratio_fin_coll,
            crm.securitised_factor,
            crm.provision_category,
            crm.exposure_class_sa_not_def_sec,
            crm.risk_weight_asset_pre_sme_fact,
            crm.subject_to_sme_factor_ind,
            crm.exposure_class_sa_not_def,
            crm.lr_on_balance_ratio,
            crm.lr_on_balance_ratio_exposure,
            crm.conversion_ratio_exposure_lr,
            crm.lr_k_factor,
            crm.lr_g_factor,
            crm.lre_amount,
            crm.lre_on_balance,
            crm.lre_off_balance_before_ccf,
            crm.lre_off_balance_after_ccf,
            crm.LR_CCF_10PERCENT,
            crm.LR_CCF_20PERCENT,
            crm.LR_CCF_40PERCENT,
            crm.LR_CCF_50PERCENT,
            crm.LR_CCF_100PERCENT,
            crm.effective_regulated_indicator,
            crm.netted_indicator,
            crm.off_supp_credit_indicator,
            crm.notional_amount,
            crm.mtm_amount,
            crm.add_on,
            crm.calculated_add_on,
            crm.net_mtm_amount,
            crm.ccf_0percent_irb,
            --crm.ccf_20percent_irb,
            --crm.ccf_50percent_irb,
            --crm.ccf_100percent_irb,
            --crm.cva_exposure,
            --crm.cva_effective_maturity,
            --crm.cva_risk_weight,
            --crm.diversification_cva_ratio,
            --crm.diversified_cva_capital,
            crm.correlation_factor,
            crm.in_default_ind_original,
            --crm.provision_amount_llp,
            --crm.provision_category_llp,
            --crm.finrep_subordination_code,
            crm.sme_ind,
            crm.risk_weight_add_on_factor,
            crm.risk_weight_add_on_term,
            crm.risk_weight_factor_original,
            crm.basel_local_official_approach,
            --crm.rwa_pre_sme_including_addonterm,
            --crm.rwa_including_addonterm,
            --crm.accrued_interest_amt,
            crm.residual_maturity_months,
            crm.residual_maturity_bucket_code,
            crm.ifrs_accounting_classification,
            crm.ifrs_measurement_category,
            crm.rwa_including_addon,
            crm.rwa_pre_sme_including_addon,
            crm.rwa_add_on_report_classification,
            crm.sts_indicator,
            crm.sec_calculation_method,
            crm.sts_qualif_diff_treatment_ind,
            crm.capital_requirement_c_09_04,
            crm.exposure_at_default_c_09_04,
            crm.zero_rrw_sov_indicator,
            crm.strict_prudential_rw_ind,
            crm.strict_lgd_floor_ind,
            crm.rwa_ex_add_on,
            crm.rwa_pre_sme_fact_ex_add_on,
            --crm.rw_dod_add_on_f_global_charge,
            --crm.rwa_add_on_for_dod,
            --crm.rwa_add_on_for_term_factor,
            crm.exposure_amount,
            crm.cover_key,
            crm.cover_type_key,
            crm.cover_provider_id,
            crm.cover_provider_key,
            crm.cover_ctry_key,
            crm.cover_ctry_code,
            crm.finrep_sector,
            crm.cover_ctry_ec_ind,
            --crm.next_review_date,
            --crm.principal_next_review_date,
            --crm.econ_parent_review_date_bucket_key,
            --crm.legal_parent_review_date_bucket_key,
            crm.intercompany_code,
            --crm.review_date_bucket_key,
            --crm.legal_ult_parent_risk_rating_key,
            --crm.legal_ult_parent_risk_rating_owner_key,
            --crm.econ_ult_parent_risk_rating_key,
            --crm.econ_ult_parent_risk_rating_owner_key,
            crm.legal_principal_ult_parent_id,
            crm.principal_borrower_id,
            crm.ctry_of_incorporation_key,
            crm.ctry_of_residence_key,
            crm.customer_type_key,
            crm.econ_ult_parent_id,
            --crm.econ_ult_parent_key,
            --crm.industry_type_key,
            crm.segmentation_type_key,
            --crm.worst_ctry_of_risk_key,
            crm.legal_ult_parent_id,
            --crm.legal_ult_parent_key,
            --crm.cust_status_key,
            crm.booking_office_key,
            crm.initiating_office_key,
            crm.mis_raroc_product_type_key,
            crm.original_ccy_key,
            crm.risk_rating_key,
            --crm.risk_rating_owner_key,
            crm.auth_combination_key,
            --crm.next_review_date_cdd,
            --crm.review_date_cdd_bucket_key,
            --crm.lup_review_date_cdd_bucket_key,
            --crm.eup_review_date_cdd_bucket_key,
            --crm.next_review_date_mifid,
            --crm.review_date_mifid_bucket_key,
            --crm.lup_review_date_mifid_bucket_key,
            --crm.eup_review_date_mifid_bucket_key,
            --crm.next_review_date_br,
            --crm.review_date_br_bucket_key,
            --crm.lup_review_date_br_bucket_key,
            --crm.eup_review_date_br_bucket_key,
            --crm.review_date_cdd_owner_key,
            --crm.lup_review_date_cdd_owner_key,
            --crm.eup_review_date_cdd_owner_key,
            --crm.review_date_mifid_owner_key,
            --crm.lup_review_date_mifid_owner_key,
            --crm.eup_review_date_mifid_owner_key,
            --crm.review_date_br_owner_key,
            --crm.lup_review_date_br_owner_key,
            --crm.eup_review_date_br_owner_key,
            --crm.customer_type_cdd_key,
            --crm.customer_type_mifid_key,
            --crm.classification_mifid_key,
            --crm.classification_mifid_code,
            --crm.risk_level_cdd_key,
            --crm.risk_level_cdd_code,
            crm.ead_model_code,
            crm.lgd_model_code,
            crm.ead_model_key,
            crm.lgd_model_key,
            crm.os_accounting_unit_key,
            crm.os_ing_legal_entity_key,
            crm.product_type_key,
            --crm.segmentation_type_poland_key,
            --crm.segmentation_type_belgium_key,
            --crm.segmentation_type_india_key,
            --crm.segmentation_type_netherlands_key,
            --crm.segmentation_type_romania_key,
            --crm.segmentation_type_turkey_key,
            crm.maximum_limit_amt,
            crm.booking_base_entity_key,
            crm.initiating_base_entity_key,
            --crm.compliance_department_key,
            --crm.lup_compliance_department_key,
            --crm.eup_compliance_department_key,
            --crm.maintenance_unit_key,
            --crm.lup_maintenance_unit_key,
            --crm.eup_maintenance_unit_key,
            crm.local_outstanding_id,
            --crm.generated_record,
            crm.secondary_currency_key,
            crm.fac_accounting_unit_key,
            crm.fac_booking_office_key,
            crm.fac_ing_legal_entity_key,
            crm.fac_initiating_office_key,
            --crm.fac_original_ccy_key,
            crm.facility_purpose_key,
            crm.facility_type_key,
            crm.limit_end_date,
            crm.orig_end_date,
            crm.limit_start_date,
            crm.orig_start_date,
            crm.risk_rating_type,
            crm.cover_type_combination_key,
            crm.higher_level_facility_key,
            crm.limit_type_indicator,
            --crm.segmentation_code_up_pb_hf,
            crm.principal_borrower_key,
            crm.fac_mis_raroc_product_type_key,
            crm.multi_ccy_indicator,
            --crm.fac_generated_record,
            crm.higher_level_facility_id,
            crm.highest_level_facility_id,
            crm.fac_booking_base_entity_key,
            crm.fac_initiating_base_entity_key,
            crm.exposure_class_code,
            crm.facility_hierarchy_level,
            crm.maturity_date,
            crm.orig_maturity_date,
            crm.bond_rating_agency_code,
            crm.bond_rating_code,
            --crm.exchange_rate,
            crm.os_max_remaining_tenor,
            crm.fac_max_remaining_tenor,
            crm.master_scale_level4_code,
            crm.risk_rating_code,
            crm.ctry_of_residence_code,
            crm.ctry_of_incorporation_code,
            --crm.ctry_of_incorp_pr_borr_key,
            --crm.ctry_of_incorp_pr_borr_code,
            crm.ctry_of_incorp_guarantor_key,
            crm.ctry_of_incorp_guarantor_code,
            crm.risk_degree_key,
            crm.facility_type_code,
            crm.facility_purpose_code,
            crm.cover_type_code,
            crm.corep_cover_cluster,
            crm.product_type_code,
            crm.default_fund_contr_ind,
            --crm.qccp_initial_margin,
            crm.corep_counterparty_cluster,
            crm.lr_deriv_classification,
            crm.finrep_product_code,
            crm.risk_category_level1_code,
            crm.risk_category_level1_key,
            crm.booking_office_code,
            crm.initiating_office_code,
            --crm.fac_booking_office_code,
            --crm.fac_initiating_office_code,
            crm.securitisation_code,
            crm.rating_agency_code,
            --crm.rating_agency_sec_code,
            crm.credit_qual_step_sec_inc,
            --crm.grouping_key,
            crm.with_cai_ind,
            crm.counterparty_ind,
            --crm.cva_cap_eligible_recap,
            crm.permanent_sa_ind,
--            crm.outflow,
            case when crm.source_table = 'IRB' and crm.original_ind = 1 and crm.risk_weight_substitution=1 and crm.on_balance_sheet_ind=0 then round((tmp.exposure_pre_ccf_drawn * crm.conversion_ratio_on_balance) + (tmp.exposure_pre_ccf_undrawn * crm.conversion_ratio_off_balance),2)
                 when crm.source_table = 'IRB' and crm.original_ind = 1 and crm.risk_weight_substitution=1 and crm.on_balance_sheet_ind = 1 and crm.on_balance_ind = 1 then round(tmp.exposure_pre_ccf_drawn * crm.conversion_ratio_on_balance, 2)
                 when crm.source_table = 'IRB' and crm.original_ind = 1 and crm.risk_weight_substitution=1 and crm.on_balance_sheet_ind = 1 and crm.on_balance_ind = 0 then round(tmp.exposure_pre_ccf_undrawn * crm.conversion_ratio_off_balance, 2)
                 else crm.outflow
            END AS OUTFLOW,
            crm.original_cover_value_abs,
            crm.fully_adjusted_exposure,
            crm.residual_value_risk_weight_asset,
            --crm.residual_value_risk_weight_asset_abs,
            crm.exposure_at_default_abs,
            crm.residual_value_amount_abs,
            crm.ccf_0percent,
            crm.ccf_20percent,
            crm.ccf_50percent,
            crm.ccf_100percent,
            crm.e_factor_limit,
            crm.e_factor_os,
            --crm.endmonth_indicator,
            --crm.endmonth_3m_indicator,
            --crm.endmonth_6m_indicator,
            --crm.endmonth_12m_indicator,
            --crm.endmonth_vortexi_indicator,
            --crm.quarter_5q_indicator,
            --crm.recent_indicator,
            crm.on_balance_sheet_ind,
            crm.negative_limit_ind,
            crm.sec_ccf_drawn_bucket,
            --crm.gk_factor,
            crm.sec_ccf_undrawn_bucket,
            crm.lr_counterparty_cluster,
            crm.customer_type_level3_code,
            crm.lr_covered_bond_ind,
            crm.trade_finance_ind,
            crm.lr_exposure_classification,
            crm.lr_customer_type,
            crm.exposure_weighted_avg_lgd,
            crm.k_a_parameter_w,
            crm.k_irb,
            crm.k_sa,
            crm.ppu_sa_ind,
            crm.risk_weight_excl_strict_prud,
            crm.rwa_pre_sme_fact_ex_strict_prud,
            crm.rwa_ex_strict_prud,
            crm.subject_to_infra_factor_ind,
            crm.risk_weight_asset_pre_infra_fact,
            --crm.rwa_pre_infra_fct_ex_add_on,
            crm.rwa_pre_infra_fct_ex_strict_prud,
            crm.rwa_sme_support_amt,
            crm.rwa_infra_support_amt,
            crm.lgd_pre_cds,
            crm.pd_original_after_multipliers,
            crm.branch_indicator, --ADDED FROM MERGE CU7
            crm.legal_imm_parent_id, --ADDED FROM MERGE CU7
            crm.exposure_class_original,--CU7
            crm.exposure_class_applied, --CU7
            crm.large_exposure_sector, --CU7 missing code
            crm.ccr_replacement_cost,
            crm.ccr_addon,
            crm.ccr_potential_future_exp,
            crm.ccr_exp_value_pre_crm,
            crm.ccr_exp_value_post_crm,
            crm.lre_ccr_replacement_cost,
            crm.ccr_variation_margin,
            crm.lre_ccr_variation_margin,
            crm.ccr_net_indep_collat_amt,
            crm.eca_indicator,
            crm.secured_by_com_prop_ind,
            crm.secured_by_res_prop_ind,
            crm.cdspb_facility_ind,
            crm.local_official_approach_indicator,
            --crm.finan_guarantee_given_ind,
            --crm.days_past_due,
            --crm.secured_by_com_prop_os_ind,
            --crm.secured_by_res_prop_os_ind,
            --crm.secured_by_non_mort_os_ind,
            crm.default_fund_ind,
            crm.ccr_wrong_way_risk_indicator,
            crm.observed_new_default_ip_ind,
            crm.observed_new_default_ind,
            --crm.cva_amount,
            --crm.dva_amount,
            crm.incurredcva_amount,
            crm.seniority_basel_class,
            crm.securitisation_sponsor_key,
            crm.securitisation_investor_key,
            crm.lr_exposure_type,
            crm.lr_exposure_subtype,
            crm.ccr_margined_indicator,
            crm.ccr_nr_of_risk_categories,
            crm.ccr_material_risk_category,
            crm.cred_deriv_direction_key,
            crm.ccr_hedging_set_interest_rate,
            crm.ccr_hedging_set_forex,
            crm.ccr_hedging_set_equity,
            crm.ccr_hedging_set_commodity,
            crm.ccr_hedging_set_credit_risk,
            crm.saccr_calculation_indicator,
            crm.os_comp_direction_key,
            CASE WHEN crm.original_ind = 1 THEN c.fx_haircut END AS cover_fx_haircut,
            CASE WHEN crm.original_ind = 1 AND crm.basel_approach IN ('AIRB_OFFIC','AIRB','FIRB') THEN c.discount_factor_cover END AS secured_discount_factor,
            c.double_default_classification AS dd_classification,
--            CASE WHEN crm.original_ind = 1 AND crm.basel_approach IN ('AIRB_OFFIC','AIRB') THEN
--               ROUND(( CASE WHEN c.double_default_classification = 'B' THEN crm.risk_weighted_assets
--                     ELSE crm.risk_weighted_assets * ( nvl(crm.lgd_pre_cds,0) /
--                                                              CASE WHEN  crm.loss_given_default IS NULL THEN 1
--                                                                   WHEN  crm.loss_given_default = 0 THEN 1
--                                                                   ELSE  crm.loss_given_default  END )
--                       END ) * crm.conversion_ratio, 4) END AS risk_weighted_assets_pre_cds ,
            crm.risk_weighted_assets_pre_cds,
            comb.combination_key AS regulator_combination_key,
            CASE WHEN crm.source_table IN ('SA', 'SEC','IRB') THEN rw_sa.risk_weight_bucket_sa_key  END AS risk_weight_factor_bucket_key,
            CASE WHEN crm.source_table IN ('SA', 'SEC','IRB') THEN rw_sa.code END AS risk_weight_factor_bucket_code,
            rw_lr.code AS lr_risk_weight_bucket_code,
            CASE WHEN crm.source_table = 'IRB' THEN
            crm.exposure_at_default / (
            		CASE
            			WHEN
            				CASE
            					WHEN crm.on_balance_sheet_ind = 0 THEN crm.exposure_pre_ccf
            					WHEN crm.on_balance_sheet_ind = 1 THEN
            						CASE
            							WHEN crm.on_balance_ind = 1 THEN crm.exposure_pre_ccf_drawn
            							WHEN crm.on_balance_ind = 0 THEN crm.exposure_pre_ccf_undrawn
            						END
            				END = 0 THEN 1
            		ELSE
            			CASE
            				WHEN crm.on_balance_sheet_ind = 0 THEN crm.exposure_pre_ccf
            				WHEN crm.on_balance_sheet_ind = 1 THEN
            					CASE
            						WHEN crm.on_balance_ind = 1 THEN crm.exposure_pre_ccf_drawn
            						WHEN crm.on_balance_ind = 0 THEN crm.exposure_pre_ccf_undrawn
            					END
            			END
            		END)
            END AS ccf_irb,
            pd.code AS corep_pd_range,
            CASE WHEN crm.source_table = 'IRB' AND crm.original_ind = 1 THEN
			     CASE WHEN crm.risk_weight_substitution <>1 THEN ROUND(c.alloc_available_amount_after_hc * crm.conversion_ratio, 2)
				      WHEN crm.risk_weight_substitution = 1 AND crm.on_balance_sheet_ind = 0 THEN ROUND(c.alloc_available_amount_after_hc, 2)
					  WHEN crm.risk_weight_substitution=1 AND crm.on_balance_sheet_ind = 1 THEN ROUND(c.alloc_available_amount_after_hc * crm.conversion_ratio_exp_pre_ccf, 2)
					  ELSE c.alloc_available_amount_after_hc
				 END
			     WHEN crm.source_table <> 'IRB' AND crm.original_ind = 1 THEN ROUND(c.alloc_available_amount_after_hc * crm.conversion_ratio * nvl(crm.split_ratio,1),2)
			END AS cover_amount_after_hc,  --7442301
            --a.code AS advised_indicator,
            --o.accounting_classification AS accounting_classification,
--            ft.finrep_lim_type_1 AS finrep_limit_type1_code,
--            ft.finrep_lim_type_2 AS finrep_limit_type2_code,
            --i.level1_code AS industry_nace20_level1_code,
            CASE WHEN crm.original_ind = 1 THEN
                 CASE WHEN crm.source_table IN ('SA') THEN round(round(ifrs.gross_carrying_amount * crm.pro_rata_factor * crm.conversion_ratio_on_balance,4)* nvl(crm.split_ratio,1),4 ) --need a split so multiplying with split ratio, added nvl in case the split is not present
                      ELSE round(ifrs.gross_carrying_amount * crm.pro_rata_factor * crm.conversion_ratio_on_balance,4)
                 END
            END AS gross_carrying_amt,
            dog.csa_key AS csa_key,
            NVL(isin.security_id,crm.security_id) AS security_id,
            NVL(isin.security_id_type,crm.security_id_type) AS security_id_type,
		    crm.risk_weight_factor_macro_prud,--New column added AB 5033337
            crm.rwa_pre_sme_fact_macro_prud,--New column added AB 5033337
            crm.rwa_pre_infra_fact_macro_prud,--New column added AB 5033337
            crm.rwa_macro_prud, --New column added AB 5033337
			--crm.macro_prud_rw_ltv,  -- New column added AB STRY3055404
            crm.leverage_sme_ind, -- New column for story STRY3563101
			crm.reporting_date,
            crm.risk_weight_asset_orig_obligor,  --added as part of STRY2099796
            crm.risk_weight_asset_sec_erba, --STRY3694837   AB
            crm.risk_weight_asset_sec_sa,    --STRY3694837  AB
            Case when crm.original_ind = 1 then crm.ctry_of_incorporation_code else crm.ctry_of_incorp_guarantor_code end AS country_of_incorporation, --New column Added for Story 2244791
            crm.substitution_method, --added as part of 2119302
			crm.rw_substitution_method, --added as part of 2119302
			--crm.rw_floor, --added as part of 2119302
			crm.official_approach_applied, --added as part of 2119302
            crm.ead_exclusion_ind,  --added as part of 20231130
			--crm.risk_weight_asset_sec_tr risk_weight_asset_sec_tr,
            crm.configuration_code,
            crm.condition_outcome_code,
            crm.ccf_10percent,
            crm.ccf_40percent,
            crm.COVER_SPLIT_KEY,
            crm.property_ratio_from,
            crm.property_ratio_until,
            crm.EAD_RATIO,
            crm.COLLATERALISATION_RATIO,
            crm.exposure_class_irb_in_sa,
            crm.exposure_class_sa_in_irb,
            crm.res_imm_prop_ind,
            crm.com_imm_prop_ind,
            crm.regulatory_large_corp_ind,
			crm.ccf_ucc_transitional 	,
			crm.rwa_non_ccf_ucc_trans ,
            crm.SPLIT_RATIO,
            crm.ucc_non_trans_on_balance_ratio_exposure,
            crm.ucc_non_trans_conversion_ratio_exposure,
			crm.basel_approach_original,
			crm.ccf_100percent_irb,
		    crm.regulatory_ead_applied,
            crm.exposure_class_sa_original,
			crm.lr_exposure_type_original,
			crm.lr_exposure_subtype_original,
			crm.risk_weight_asset_pre_fx_mm,
		    crm.risk_weight_factor_pre_fx_mm,
            rw_fx.code as rw_factor_pre_fx_mm_bucket_code,
            crm.modelled_ccf,
			crm.loan_split_derogation_ind,
			crm.risk_weight_art378,
			crm.exposure_amount_art378,
			crm.rwa_art378,
			crm.book_risk_category,
		    crm.settlement_date,
			crm.days_unsettled_after_due_date,
			crm.settlement_amount,
			crm.unsecuritised_factor,
			crm.sec_pro_rata_factor,
            crm.official_challenger_indicator,
			crm.conversion_ratio_exp_pre_ccf,
			crm.inscription_value
            FROM tmp_corep_recap_measure_pre_b4 crm
            LEFT OUTER JOIN (select distinct exposure_pre_ccf_drawn,exposure_pre_ccf_undrawn,original_cover_value,OUTSTANDING_GROUP_KEY,COVER_ID,basel_approach,source_table from tmp_corep_recap_b4 ) tmp ON (tmp.OUTSTANDING_GROUP_KEY = crm.OUTSTANDING_GROUP_KEY AND nvl(tmp.COVER_ID,0) = nvl(crm.COVER_ID,0) AND crm.basel_approach_original = tmp.basel_approach AND tmp.source_table = 'IRB')
            LEFT OUTER JOIN TMP_COREP_VRE_COVER_RECAP_B4 c     ON c.cover_key = crm.cover_key AND c.outstanding_group_key = crm.outstanding_group_key
                                                           -- AND crm.basel_approach = decode(c.configuration_code,'RECAPAIRBO','AIRB_OFFIC','RECAPAIRB','AIRB','RECAPSA','SA','RECAPFIRB','FIRB')
                                                         AND crm.basel_approach_original = decode(c.configuration_code,'RECAP4AIRO','AIRB_OFFIC','RECAP4AIRB','AIRB','RECAP4SA','SA','RECAP4FIRB','FIRB','RECAP4SATR','SA_TR')
            LEFT OUTER JOIN tmb_combination_result comb     ON comb.raroc_facility_key = crm.grouping_key
			LEFT OUTER JOIN risk_weight_bucket_sa rw_fx ON crm.risk_weight_factor_pre_fx_mm  = rw_fx.risk_factor
																		AND rw_fx.record_valid_from <= crm.record_valid_from
                                                            AND NVL(rw_fx.record_valid_until,utilities.record_default_date) > crm.record_valid_from
            LEFT OUTER JOIN risk_weight_bucket_sa rw_sa ON crm.risk_weight_factor = rw_sa.risk_factor AND rw_sa.record_valid_from <= crm.record_valid_from
                                                            AND NVL(rw_sa.record_valid_until,utilities.record_default_date) > crm.record_valid_from
            LEFT OUTER JOIN lr_risk_weight_bucket rw_lr     ON crm.risk_weight_factor >= rw_lr.rw_from AND crm.risk_weight_factor < rw_lr.rw_until AND rw_lr.record_valid_from <= crm.record_valid_from
                                                            AND NVL(rw_lr.record_valid_until,utilities.record_default_date)  > crm.record_valid_from
                                                            AND rw_lr.rw_from IS NOT NULL
            LEFT OUTER JOIN corep_pd_range pd               ON  crm.pd >= pd.low_value AND crm.pd < pd.high_value AND pd.record_valid_from <= crm.record_valid_from
                                                            AND NVL(pd.record_valid_until,utilities.record_default_date)  > crm.record_valid_from
            LEFT OUTER JOIN dwh_facility f                  ON  crm.facility_key = f.facility_key AND --(f.record_valid_from, f.system_id) IN  ( SELECT /*+ PRECOMPUTE_SUBQUERY */ reporting_date, system_id FROM tmp_basel_combined_uploads)
																f.system_id = v_system_id --  modification corep_vpp
															AND f.record_valid_from = v_reporting_date --  modification corep_vpp
            LEFT OUTER JOIN dwh_ifrs_outstanding_group ifrs ON  crm.outstanding_group_key = ifrs.outstanding_group_key AND --(ifrs.record_valid_from, ifrs.system_id) IN  ( SELECT /*+ PRECOMPUTE_SUBQUERY */ reporting_date, system_id FROM tmp_basel_combined_uploads)
															    ifrs.system_id = v_system_id --  modification corep_vpp
															AND ifrs.record_valid_from = v_reporting_date --  modification corep_vpp
            LEFT OUTER JOIN dwh_outstanding_group dog       ON  crm.outstanding_group_key = dog.outstanding_group_key AND --(dog.record_valid_from, dog.system_id) IN  ( SELECT /*+ PRECOMPUTE_SUBQUERY */ reporting_date, system_id FROM tmp_basel_combined_uploads)
																dog.system_id = v_system_id --  modification corep_vpp
															AND dog.record_valid_from = v_reporting_date --  modification corep_vpp
            LEFT OUTER JOIN TMP_COREP_ISIN_VPP        isin      ON  crm.outstanding_group_key = isin.outstanding_group_key;
    EXCEPTION
        WHEN OTHERS THEN utils.handleerror(sqlcode,sqlerrm);
    END;
    COMMIT;

    schema_maint.gather_idx_stats('tmp_corep_recap_measure_b4');

insert_dmb_log_corep(v_detail_level    => 103,
                       v_log_descr       => 'process_pre_corep_recap_b4',
                        v_activity_code   => 'days_unsettle_due_date',
                        v_result_code     => 'START',
                        v_system_id       => v_system_id,v_reporting_date       => v_reporting_date );

MERGE INTO (select outstanding_group_key, days_unsettled_after_due_date from tmp_corep_recap_measure_b4) tgt
USING (
  SELECT
    outstanding_group_key,
    settlement_date,
    record_valid_from,
     (TRUNC(record_valid_from) - TRUNC(settlement_date) + 1)
    - 2 * (FLOOR((TRUNC(record_valid_from) - TRUNC(settlement_date) + TO_CHAR(settlement_date, 'D') - 1) / 7))
         - CASE
        WHEN TO_CHAR(settlement_date, 'D') = '7' THEN 1
        WHEN TO_CHAR(record_valid_from, 'D') = '1' THEN 1
             ELSE 0
           END AS weekdays
  FROM (
    SELECT outstanding_group_key, settlement_date, record_valid_from,
           ROW_NUMBER() OVER (PARTITION BY outstanding_group_key ORDER BY record_valid_from DESC) AS rn
    FROM tmp_corep_recap_measure_pre_b4 WHERE settlement_date IS NOT NULL
  )
  WHERE rn = 1
) src
ON (tgt.outstanding_group_key = src.outstanding_group_key)
WHEN MATCHED THEN
     UPDATE SET tgt.days_unsettled_after_due_date = case when src.weekdays < 0 then 0 else src.weekdays end;
Commit;

  insert_dmb_log_corep(v_detail_level    => 103,
                       v_log_descr       => 'process_pre_corep_recap_b4',
                        v_activity_code   => 'days_unsettle_date',
                        v_result_code     => 'Done',
                        v_system_id       => v_system_id,v_reporting_date       => v_reporting_date );

    insert_dmb_log_corep(v_detail_level    => 103,
                                   v_log_descr       => 'process_pre_corep_recap_b4',
                                   v_activity_code   => 'MTM',
                                   v_result_code     => 'START',
                                   v_system_id       => v_system_id,v_reporting_date       => v_reporting_date
                                   );
   -- process ACR data
    process_corep_acr_b4(         v_reporting_date   => v_reporting_date,
                                   v_system_id        => v_system_id,
                                   v_batch_id         => v_batch_id,
                                   v_debug            => v_debug
                                  );

    insert_dmb_log_corep(v_detail_level    => 103,
                                   v_log_descr       => 'process_pre_corep_recap_b4',
                                   v_activity_code   => 'MTM',
                                   v_result_code     => 'FINOK',
                                   v_system_id       => v_system_id,v_reporting_date       => v_reporting_date
                                   );

    insert_dmb_log_corep(v_detail_level    => 103,
                                   v_log_descr       => 'process_pre_corep_recap_b4',
                                   v_activity_code   => 'LOSS',
                                   v_result_code     => 'START',
                                   v_system_id       => v_system_id,v_reporting_date       => v_reporting_date
                                  );
   --STRY0479738: Find the latest record_valid_from where the current defaults were not defaulted
   --7226915: After basel4 implementation we need to look at 2 datamarts for historical data to find the correct dates of default and non default.
    utilities.truncate_table('tt_last_non_default');

	    utilities.truncate_table('tt_last_non_default');
    BEGIN
        INSERT /*+ APPEND +*/ INTO tt_last_non_default
		SELECT customer_id,system_id, MAX(record_valid_from) FROM
			(SELECT t1.customer_id,t1.system_id,MAX(record_valid_from) record_valid_from
			 FROM dmi_recap_measure t1
			 WHERE t1.risk_rating_key IN (SELECT risk_rating_key FROM risk_rating WHERE in_default = 'N')
			 AND t1.record_valid_from IN (SELECT /*+ PRECOMPUTE_SUBQUERY */ DISTINCT record_valid_from FROM v_dmi_basel_reporting_period rp)
			 AND t1.record_valid_from <= TO_DATE('31122024','DDMMYYYY')           --Old datamart
			 AND t1.sync_key IN (SELECT sync_key FROM v_dmi_basel_reporting_period rp)
			 AND t1.system_id = v_system_id
			 AND EXISTS (SELECT 1
						 FROM tmp_corep_recap_measure_b4 t2
						 WHERE t2.in_default_ind_original = 1
						 AND t2.customer_id = t1.customer_id
						 AND t2.system_id = t1.system_id
						 AND t2.record_valid_from > t1.record_valid_from
						)
			 GROUP BY t1.customer_id,t1.system_id
			 UNION
			 SELECT t1.customer_id,t1.system_id,MAX(record_valid_from) record_valid_from
			 FROM dm_corep_recap_measure_b4 t1
			 WHERE t1.risk_rating_key IN (SELECT risk_rating_key FROM risk_rating WHERE in_default = 'N')
			 AND t1.record_valid_from > TO_DATE('31122024','DDMMYYYY')             --New basel4 datamart
			 AND t1.system_id = v_system_id
			 AND EXISTS (SELECT 1
						 FROM tmp_corep_recap_measure_b4 t2
						 WHERE t2.in_default_ind_original = 1
						 AND t2.customer_id = t1.customer_id
						 AND t2.system_id = t1.system_id
						 AND t2.record_valid_from > t1.record_valid_from
						)
			 GROUP BY t1.customer_id,t1.system_id
			 )
		GROUP BY customer_id,system_id;
    EXCEPTION
        WHEN OTHERS THEN utils.handleerror(sqlcode,sqlerrm);
    END;
    COMMIT;

   utilities.show_debug('Rows inserted in tt_last_non_default '||sql%rowcount);
   schema_maint.gather_idx_stats('tt_last_non_default');

   -- select the old defaults that means current set of default customer's first default date right after they were last performing.
   --This date can be the current reporting date as well in case the customer is newly defaulted this month.
    utilities.truncate_table('TT_OLD_DEFAULTS_B4');
    BEGIN
        INSERT /*+ APPEND +*/ INTO TT_OLD_DEFAULTS_B4(
			CUSTOMER_ID,
			SYSTEM_ID,
			RECORD_VALID_FROM,
			RECORD_VALID_FROM_LP,
			SYNC_KEY)
		SELECT customer_id,system_id,MIN(record_valid_from) record_valid_from ,MAX(RECORD_VALID_FROM_LP) RECORD_VALID_FROM_LP, MAX(sync_key) FROM
			(SELECT t1.customer_id,t1.system_id,MIN(t1.record_valid_from) record_valid_from ,MAX(lnd.record_valid_from) RECORD_VALID_FROM_LP,0 sync_key
			 FROM dm_corep_recap_measure_b4 t1 ,tt_last_non_default lnd
			 WHERE t1.system_id = v_system_id --  modification corep_vpp
			 AND t1.record_valid_from <= v_reporting_date
			 AND t1.customer_id = lnd.customer_id(+) --STRY0479738
			 AND t1.system_id = lnd.system_id(+) --STRY0479738
			 AND t1.record_valid_from >= nvl(lnd.record_valid_from,TO_DATE('19950101','YYYYMMDD')) --STRY0479738
			 AND t1.risk_rating_key IN (SELECT risk_rating_key  FROM risk_rating WHERE in_default = 'Y' )
			 AND t1.record_valid_from = LAST_DAY(t1.record_valid_from)
			 AND EXISTS (SELECT 1
						 FROM tmp_corep_recap_measure_b4 t2
						 WHERE t2.in_default_ind_original = 1 --STRY0479738: changed to all defaults
						 AND t2.customer_id = t1.customer_id
						 AND t2.system_id = t1.system_id
						 AND t2.record_valid_from > t1.record_valid_from --7226915
					)
			 AND t1.record_valid_from > TO_DATE('20241231','YYYYMMDD')
			 GROUP BY t1.customer_id,t1.system_id
			 UNION
			 SELECT t1.customer_id,t1.system_id,MIN(t1.record_valid_from) record_valid_from ,MAX(lnd.record_valid_from) RECORD_VALID_FROM_LP,MIN(t1.sync_key) sync_key
			 FROM dmi_recap_measure t1 ,tt_last_non_default lnd
			 WHERE t1.risk_rating_key IN (SELECT risk_rating_key  FROM risk_rating WHERE in_default = 'Y' )
			 AND t1.sync_key IN (SELECT sync_key FROM v_dmi_basel_reporting_period rp)
			 AND t1.system_id = v_system_id
			 AND t1.record_valid_from <= TO_DATE('20241231','YYYYMMDD')
			 AND t1.record_valid_from IN (SELECT /*+ PRECOMPUTE_SUBQUERY */ DISTINCT record_valid_from FROM v_dmi_basel_reporting_period rp)
			 AND t1.customer_id = lnd.customer_id(+) --STRY0479738
			 AND t1.system_id = lnd.system_id(+) --STRY0479738
			 AND t1.record_valid_from >= nvl(lnd.record_valid_from,TO_DATE('19950101','YYYYMMDD')) --STRY0479738
			 AND EXISTS (SELECT 1
						 FROM tmp_corep_recap_measure_b4 t2
						 WHERE t2.in_default_ind_original = 1 --STRY0479738: changed to all defaults
						 AND t2.customer_id = t1.customer_id
						 AND t2.system_id = t1.system_id
						 AND t2.record_valid_from > t1.record_valid_from
					)
			 GROUP BY t1.customer_id,t1.system_id
			)
		GROUP BY customer_id,system_id;
    EXCEPTION
        WHEN OTHERS THEN utils.handleerror(sqlcode,sqlerrm);
    END;

    COMMIT;

   --collect EAD,cover amount values for current reporting date grouped on facility_id,rm.system_id,basel_approach_original
    utilities.truncate_table('TT_EXPOSURE_IP_B4');
    BEGIN
        INSERT /*+ APPEND +*/ INTO TT_EXPOSURE_IP_B4(CUSTOMER_ID,
            FACILITY_ID ,
            SYSTEM_ID ,
            BASEL2_APPROACH ,
            EAD ,
			EAD_1 ,
            READ_1 ,
            READ_OLD ,
            PROVISION_AMT ,
			alloc_provision_amt,
            COVER_AMT ,
            NEW_DEFAULT_AT_REPORTING_DATE,
            ip_recovery_estimate_amt,
			inscription_value,
			in_default_ind_original,
			observed_new_default_ip_ind )
        (SELECT rm.CUSTOMER_ID,rm.facility_id,rm.system_id,rm.basel_approach_original,
          --SUM(CASE WHEN basel_approach_original IN ('SA','SA_TR') THEN nvl(exposure_at_default,0) + nvl(alloc_provision_amt,0) ELSE exposure_at_default END) AS ead,
		  SUM(CASE WHEN(secured_by_res_prop_ind = 1 OR secured_by_com_prop_ind = 1) THEN exposure_at_default END) AS ead,
		  SUM(CASE WHEN(secured_by_res_prop_ind = 1 OR secured_by_com_prop_ind = 1) THEN
		           CASE WHEN basel_approach_original IN ('SA','SA_TR') THEN nvl(exposure_at_default,0) + nvl(alloc_provision_amt,0) ELSE exposure_at_default END END) AS ead_1,
          SUM(CASE WHEN(secured_by_res_prop_ind = 1 OR secured_by_com_prop_ind = 1) THEN exposure_at_default END) AS read_1,
		  
		  SUM(CASE WHEN (secured_by_res_prop_ind = 1 OR secured_by_com_prop_ind = 1) AND basel_approach_original IN ('SA','SA_TR')
                  THEN nvl(exposure_at_default,0) + nvl(alloc_provision_amt,0)
                  WHEN (secured_by_res_prop_ind = 1 OR secured_by_com_prop_ind = 1) AND basel_approach_original in ('AIRB', 'FIRB', 'AIRB_OFFIC' )
                  THEN nvl(exposure_at_default,0)
                  ELSE 0
                  END
             )read_old,
          --SUM(CASE WHEN observed_new_default_ip_ind = 1 AND provision_category IN('ISFA','INSFA') THEN alloc_provision_amt ELSE 0 END) AS provision_amt,
		  SUM(CASE WHEN(secured_by_res_prop_ind = 1 OR secured_by_com_prop_ind = 1) THEN alloc_provision_amt END) AS provision_amt,
		  SUM(alloc_provision_amt) As alloc_provision_amt,
          SUM(CASE WHEN secured_by_res_prop_ind = 1 THEN original_cover_value
                   WHEN secured_by_com_prop_ind = 1 THEN original_cover_value
                   ELSE 0
              END) AS cover_amt,
          1 AS new_default_at_reporting_date,
		  /*SUM(CASE WHEN(secured_by_res_prop_ind = 1 OR secured_by_com_prop_ind = 1) then
		           CASE WHEN basel_approach_original IN ('SA','SA_TR') THEN nvl(exposure_at_default,0)
						ELSE nvl(exposure_at_default,0) - nvl(alloc_provision_amt,0)
				   END
				   ELSE 0
			   END)*/ 
		   NULL AS ip_recovery_estimate_amt,
		   SUM(CASE WHEN(secured_by_res_prop_ind = 1 OR secured_by_com_prop_ind = 1) THEN inscription_value END) inscription_value,
		   in_default_ind_original,
		   observed_new_default_ip_ind
         FROM tmp_corep_recap_measure_b4 rm
         --WHERE in_default_ind_original = 1
         GROUP BY rm.CUSTOMER_ID,facility_id,rm.system_id,basel_approach_original,in_default_ind_original,
		   observed_new_default_ip_ind );--STRY0479738
    EXCEPTION
        WHEN OTHERS THEN utils.handleerror(sqlcode,sqlerrm);
    END;

    v_debug_msg := $$plsql_line|| ' of plsql unit '|| $$plsql_unit|| ' '|| systimestamp|| ' Rows Affected:- '|| SQL%rowcount;
    utilities.show_debug(v_debug_msg);
    COMMIT;

   -- retrieve old default data (exposure and secured covers)
   -- retrieve cover amount of old defaults
    utilities.truncate_table('TT_TMP_EXPOSURE_OLD_B4');
    BEGIN
        INSERT /*+ APPEND +*/ INTO TT_TMP_EXPOSURE_OLD_B4(CUSTOMER_ID,FACILITY_ID,SYSTEM_ID,BASEL2_APPROACH,EAD,COVER_AMT_OLD,READ_OLD,def_flag)
		SELECT CUSTOMER_ID,facility_id,system_id,basel_approach,sum(ead) ead,NULL cover_amt_old,sum(read_old) read_old, def_flag FROM
        (SELECT rm.CUSTOMER_ID,facility_id,rm.system_id,basel_approach_original basel_approach,
         --SUM(CASE WHEN basel_approach_original IN ('SA','SA_TR') THEN nvl(exposure_at_default,0) + nvl(alloc_provision_amt,0) ELSE exposure_at_default END) ead,
		 SUM(CASE WHEN(secured_by_res_prop_ind = 1 OR secured_by_com_prop_ind = 1) THEN exposure_at_default END) AS ead,
         SUM(CASE WHEN (secured_by_res_prop_ind = 1 OR secured_by_com_prop_ind = 1) AND basel_approach_original IN ('SA','SA_TR')
                  THEN nvl(exposure_at_default,0) + nvl(alloc_provision_amt,0)
                  WHEN (secured_by_res_prop_ind = 1 OR secured_by_com_prop_ind = 1) AND basel_approach_original in ('AIRB', 'FIRB', 'AIRB_OFFIC' )
                  THEN nvl(exposure_at_default,0)
                  ELSE 0
                  END
             )read_old, 1 def_flag
         FROM dm_corep_recap_measure_b4 rm
         JOIN TT_OLD_DEFAULTS_B4 od ON rm.customer_id = od.customer_id and rm.record_valid_from = od.record_valid_from and rm.system_id = od.system_id
		                            AND od.record_valid_from < v_reporting_date
		 WHERE rm.record_valid_from > TO_DATE('20241231','YYYYMMDD')   --basel4 went live in 2025
         GROUP BY rm.CUSTOMER_ID,facility_id,rm.system_id,basel_approach_original
		 UNION
		 SELECT rm.CUSTOMER_ID,facility_id,rm.system_id,basel_approach_original basel_approach,
         NULL ead,
         NULL read_old, 0 def_flag
         FROM dm_corep_recap_measure_b4 rm
         JOIN tt_last_non_default od ON rm.customer_id = od.customer_id and rm.record_valid_from = od.record_valid_from and rm.system_id = od.system_id
		 WHERE rm.record_valid_from > TO_DATE('20241231','YYYYMMDD')   --basel4 went live in 2025
         GROUP BY rm.CUSTOMER_ID,facility_id,rm.system_id,basel_approach_original
		 UNION
		 SELECT rm.CUSTOMER_ID,facility_id,rm.system_id,basel2_approach basel_approach,
         --SUM(CASE WHEN basel2_approach = 'SA' THEN nvl(exposure_at_default,0) + nvl(alloc_provision_amt,0) ELSE exposure_at_default END) ead,
		 SUM(CASE WHEN basel2_approach = 'SA' AND cc.cover_cluster_corep_sa IN('COM_PROP','RES_PROP') THEN nvl(exposure_at_default,0) 
                  WHEN basel2_approach <> 'SA' AND cc.cover_cluster_corep_irb IN('COM_PROP','RES_PROP') THEN nvl(exposure_at_default,0)	 
			 END) ead,
         SUM(CASE WHEN cc.cover_cluster_corep_sa IN('COM_PROP','RES_PROP') AND basel2_approach = 'SA'
                  THEN nvl(exposure_at_default,0) + nvl(alloc_provision_amt,0)
                  WHEN cc.cover_cluster_corep_irb IN('COM_PROP','RES_PROP') AND basel2_approach <> 'SA'
                  THEN nvl(exposure_at_default,0)
                  ELSE 0
                  END
             )read_old, 1 def_flag
         FROM dmi_recap_measure rm
         JOIN TT_OLD_DEFAULTS_B4 od ON rm.customer_id = od.customer_id AND rm.sync_key = od.sync_key and rm.record_valid_from = od.record_valid_from
		                            AND od.record_valid_from <= TO_DATE('20241231','YYYYMMDD')
         LEFT JOIN cover_type c ON rm.cover_type_key = c.cover_type_key
         LEFT JOIN cover_type_cluster cc ON c.code = cc.cover_type AND cc.record_valid_from <= c.record_valid_from
               AND (nvl(cc.record_valid_until,utilities.record_default_date) > c.record_valid_from)
         GROUP BY rm.CUSTOMER_ID,facility_id,rm.system_id,basel2_approach
		 UNION
		 SELECT rm.CUSTOMER_ID,facility_id,rm.system_id,basel2_approach basel_approach,
         NULL ead,
         NULL read_old, 0 def_flag
         FROM dmi_recap_measure rm
         JOIN tt_last_non_default od ON rm.customer_id = od.customer_id 
         and rm.record_valid_from = od.record_valid_from 
         and rm.system_id = od.system_id
		 WHERE rm.record_valid_from <= TO_DATE('20241231','YYYYMMDD')   --basel4 went live in 2025
         GROUP BY rm.CUSTOMER_ID,facility_id,rm.system_id,basel2_approach
		 )
		 GROUP BY CUSTOMER_ID,facility_id,system_id,basel_approach,def_flag;
    EXCEPTION
        WHEN OTHERS THEN utils.handleerror(sqlcode,sqlerrm);
    END;
    COMMIT;

BEGIN
        MERGE INTO (select * from TT_TMP_EXPOSURE_OLD_B4 where def_flag = 0) told USING(
		SELECT CUSTOMER_ID,facility_id,system_id,basel_approach,sum(cover_amt_old) cover_amt_old FROM
        (SELECT rm.CUSTOMER_ID,facility_id,rm.system_id,basel_approach_original basel_approach,
         SUM(CASE WHEN cc.cover_cluster_corep_irb = 'COM_PROP' OR cc.cover_cluster_corep_sa = 'COM_PROP' THEN original_cover_value
                  WHEN cc.cover_cluster_corep_irb = 'RES_PROP' OR cc.cover_cluster_corep_sa = 'RES_PROP' THEN original_cover_value
             ELSE 0
             END) cover_amt_old
         FROM dm_corep_recap_measure_b4 rm
         JOIN tt_last_non_default lp ON rm.customer_id = lp.customer_id and rm.record_valid_from = lp.record_valid_from and rm.system_id = lp.system_id
         LEFT JOIN cover_type c ON rm.cover_type_key = c.cover_type_key
         LEFT JOIN cover_type_cluster cc ON c.code = cc.cover_type AND cc.record_valid_from <= c.record_valid_from
               AND (nvl(cc.record_valid_until,utilities.record_default_date) > c.record_valid_from)
		 WHERE rm.record_valid_from > TO_DATE('20241231','YYYYMMDD')
         GROUP BY rm.CUSTOMER_ID,facility_id,rm.system_id,basel_approach_original
		 UNION
		 SELECT rm.CUSTOMER_ID,facility_id,rm.system_id,basel2_approach basel_approach,
         SUM(CASE WHEN cc.cover_cluster_corep_irb = 'COM_PROP' OR cc.cover_cluster_corep_sa = 'COM_PROP' THEN original_cover_value
                  WHEN cc.cover_cluster_corep_irb = 'RES_PROP' OR cc.cover_cluster_corep_sa = 'RES_PROP' THEN original_cover_value
             ELSE 0
             END) cover_amt_old
         FROM dmi_recap_measure rm
         JOIN tt_last_non_default lp ON rm.customer_id = lp.customer_id and rm.record_valid_from = lp.record_valid_from and rm.system_id = lp.system_id
         LEFT JOIN cover_type c ON rm.cover_type_key = c.cover_type_key
         LEFT JOIN cover_type_cluster cc ON c.code = cc.cover_type AND cc.record_valid_from <= c.record_valid_from
               AND (nvl(cc.record_valid_until,utilities.record_default_date) > c.record_valid_from)
         WHERE rm.record_valid_from <= TO_DATE('20241231','YYYYMMDD')
         GROUP BY rm.CUSTOMER_ID,facility_id,rm.system_id,basel2_approach)
		 GROUP BY CUSTOMER_ID,facility_id,system_id,basel_approach
		 )src ON (told.CUSTOMER_ID = src.CUSTOMER_ID AND told.facility_id = src.facility_id AND told.system_id = src.system_id AND told.basel2_approach = src.basel_approach)
        WHEN MATCHED THEN UPDATE SET told.cover_amt_old = src.cover_amt_old;
    EXCEPTION
        WHEN OTHERS THEN utils.handleerror(sqlcode,sqlerrm);
    END;
    COMMIT;

    MERGE INTO (SELECT CUSTOMER_ID,facility_id,system_id,basel2_approach,new_default_at_reporting_date,ead,cover_amt,read_old FROM TT_EXPOSURE_IP_B4
				WHERE in_default_ind_original = 1	) t USING
    (SELECT CUSTOMER_ID,ead,cover_amt_old,read_old,facility_id,system_id,basel2_approach FROM TT_TMP_EXPOSURE_OLD_B4 where def_flag = 0) src
    ON ( t.CUSTOMER_ID = src.CUSTOMER_ID AND t.facility_id = src.facility_id AND t.system_id = src.system_id AND t.basel2_approach = src.basel2_approach )
    WHEN MATCHED THEN UPDATE SET t.cover_amt = src.cover_amt_old,
                                 t.new_default_at_reporting_date = 0;
    COMMIT;
	
    MERGE INTO (SELECT CUSTOMER_ID,facility_id,system_id,basel2_approach,new_default_at_reporting_date,ead,cover_amt,read_old FROM TT_EXPOSURE_IP_B4
				WHERE in_default_ind_original = 1	) t USING
    (SELECT CUSTOMER_ID,ead,cover_amt_old,read_old,facility_id,system_id,basel2_approach FROM TT_TMP_EXPOSURE_OLD_B4 where def_flag = 1) src
    ON ( t.CUSTOMER_ID = src.CUSTOMER_ID AND t.facility_id = src.facility_id AND t.system_id = src.system_id AND t.basel2_approach = src.basel2_approach )
    WHEN MATCHED THEN UPDATE SET t.read_old = src.read_old,
                                 t.new_default_at_reporting_date = 0;
    COMMIT;
    utilities.truncate_table('TT_PROV_COV_B4');

    BEGIN
        INSERT /*+ APPEND +*/ INTO TT_PROV_COV_B4(CUSTOMER_ID,BASEL2_APPROACH,
													FACILITY_ID,
													SYSTEM_ID,
													IP_LOSS_COL010,
													IP_LOSS_COL030,
													IP_LOSS_COL050,
													EAD_1,
													READ_1,
													IP_RECOVERY_ESTIMATE_AMT,
													in_default_ind_original,
													observed_new_default_ip_ind)

 --ip_loss_col010 = min((IP_EAD_REF_DEF_DATE capped at min(Inscription_value, 55%* IP_COVER_AMT_REF_NON_DEF_DATE) - recovery_estimate), alloc_provision_amt)
        (SELECT CUSTOMER_ID,basel2_approach,facility_id,system_id,
                LEAST( LEAST( CASE WHEN nvl(inscription_value,0) > 0 THEN (LEAST(nvl(inscription_value,0), 0.55 * nvl(cover_amt,0))) ELSE 0.55 * nvl(cover_amt,0) END
								,nvl(read_old,0)
							  ) - (CASE WHEN 
                                    (CASE WHEN in_default_ind_original = 1 THEN 
										CASE WHEN BASEL2_APPROACH IN ('SA','SA_TR') THEN nvl(ead,0)
											 ELSE nvl(ead,0) - nvl(provision_amt,0)
										END 
										ELSE 0
									END) --- formula for ip_recovery_estimate_amt
                                    < 0 THEN 0 ELSE
                                    (CASE WHEN in_default_ind_original = 1 THEN 
										CASE WHEN BASEL2_APPROACH IN ('SA','SA_TR') THEN nvl(ead,0)
											 ELSE nvl(ead,0) - nvl(provision_amt,0)
										END 
										ELSE 0
									END) --- formula for ip_recovery_estimate_amt
                                   END)
						, alloc_provision_amt
					  ) AS ip_loss_col010,
 --ip_loss_col030 = min((IP_EAD_REF_DEF_DATE capped at min(Inscription_value, IP_COVER_AMT_REF_NON_DEF_DATE) - recovery_estimate), alloc_provision_amt)
                LEAST( LEAST( CASE WHEN nvl(inscription_value,0) > 0 THEN (LEAST(nvl(inscription_value,0),  nvl(cover_amt,0))) ELSE nvl(cover_amt,0) END
								,nvl(read_old,0)
							  ) - (CASE WHEN 
                                    (CASE WHEN in_default_ind_original = 1 THEN 
										CASE WHEN BASEL2_APPROACH IN ('SA','SA_TR') THEN nvl(ead,0)
											 ELSE nvl(ead,0) - nvl(provision_amt,0)
										END 
										ELSE 0
									END) --- formula for ip_recovery_estimate_amt
                                    < 0 THEN 0 ELSE
                                    (CASE WHEN in_default_ind_original = 1 THEN 
										CASE WHEN BASEL2_APPROACH IN ('SA','SA_TR') THEN nvl(ead,0)
											 ELSE nvl(ead,0) - nvl(provision_amt,0)
										END 
										ELSE 0
									END) --- formula for ip_recovery_estimate_amt
                                   END)
						, alloc_provision_amt
					  ) AS ip_loss_col030,
				CASE WHEN in_default_ind_original = 1 AND observed_new_default_ip_ind = 1
					 THEN LEAST( nvl(read_old,0)   ,CASE WHEN nvl(inscription_value,0) > 0 THEN LEAST(nvl(inscription_value,0), nvl(cover_amt,0)) ELSE nvl(cover_amt,0) END )
					 WHEN in_default_ind_original = 1 AND observed_new_default_ip_ind = 0
					 THEN LEAST( nvl(ead_1,0),CASE WHEN nvl(inscription_value,0) > 0 THEN LEAST(nvl(inscription_value,0), nvl(cover_amt,0)) ELSE nvl(cover_amt,0) END )
					 WHEN in_default_ind_original = 0
					 THEN LEAST( nvl(ead_1,0),CASE WHEN nvl(inscription_value,0) > 0 THEN LEAST(nvl(inscription_value,0), nvl(cover_amt,0)) ELSE nvl(cover_amt,0) END )
				END AS ip_loss_col050,
                      ead_1 AS ead_1,
					  read_1 AS read_1,
		        CASE WHEN in_default_ind_original = 1 THEN 
					CASE WHEN BASEL2_APPROACH IN ('SA','SA_TR') THEN nvl(ead,0)
						 ELSE nvl(ead,0) - nvl(provision_amt,0)
					END 
					ELSE 0
				END As ip_recovery_estimate_amt,
				in_default_ind_original,
				observed_new_default_ip_ind
         FROM TT_EXPOSURE_IP_B4);
    EXCEPTION
        WHEN OTHERS THEN utils.handleerror(sqlcode,sqlerrm);
    END;
    COMMIT;

    -- floored to  0
    UPDATE /*+ enable_parallel_dml */ TT_PROV_COV_B4
    SET ip_loss_col010 = 0
    WHERE ip_loss_col010 < 0;
    COMMIT;

    UPDATE /*+ enable_parallel_dml */ TT_PROV_COV_B4
    SET ip_loss_col030 = 0
    WHERE ip_loss_col030 < 0;
    COMMIT;

    UPDATE /*+ enable_parallel_dml */ TT_PROV_COV_B4
    SET ip_loss_col050 = 0
    WHERE ip_loss_col050 < 0;
    COMMIT;

    UPDATE /*+ enable_parallel_dml */ TT_PROV_COV_B4
    SET ip_recovery_estimate_amt = 0
    WHERE ip_recovery_estimate_amt < 0;
    COMMIT;    


--Calculate ip_factor and IP_RECOVERY_ESTIMATE_AMT and update in datamart.
    MERGE /*+ enable_parallel_dml */ INTO (SELECT CUSTOMER_ID,facility_id,system_id,basel_approach_original ,exposure_at_default,ip_factor,IP_RECOVERY_ESTIMATE_AMT
	       ,in_default_ind_original,alloc_provision_amt
                FROM tmp_corep_recap_measure_b4
                WHERE secured_by_res_prop_ind = 1 OR secured_by_com_prop_ind = 1 ) t USING
    (SELECT tp.CUSTOMER_ID,tp.facility_id,tp.system_id,basel2_approach,MAX(READ_1) READ_1 ,MAX(EAD_1) EAD_1,MAX(tp.IP_RECOVERY_ESTIMATE_AMT) IP_RECOVERY_ESTIMATE_AMT
	,tp.IN_DEFAULT_IND_ORIGINAL,max(cnt.count_nr) count_nr
     FROM TT_PROV_COV_B4 tp,
			(SELECT CUSTOMER_ID,facility_id,system_id,basel_approach_original ,IN_DEFAULT_IND_ORIGINAL,count(*) count_nr
			FROM tmp_corep_recap_measure_b4
			WHERE secured_by_res_prop_ind = 1 OR secured_by_com_prop_ind = 1 group by CUSTOMER_ID,facility_id,system_id,basel_approach_original,IN_DEFAULT_IND_ORIGINAL ) cnt
	 WHERE tp.CUSTOMER_ID = cnt.CUSTOMER_ID AND tp.facility_id = cnt.facility_id AND tp.system_id = cnt.system_id 
     AND tp.basel2_approach = cnt.basel_approach_original
	 AND tp.IN_DEFAULT_IND_ORIGINAL = cnt.IN_DEFAULT_IND_ORIGINAL
			GROUP BY tp.CUSTOMER_ID,tp.facility_id,tp.system_id,basel2_approach,tp.IN_DEFAULT_IND_ORIGINAL
     ) src
     ON (t.CUSTOMER_ID = src.CUSTOMER_ID AND t.facility_id = src.facility_id AND t.system_id = src.system_id 
     AND t.basel_approach_original = src.basel2_approach
     AND t.IN_DEFAULT_IND_ORIGINAL = src.IN_DEFAULT_IND_ORIGINAL
	 )
    WHEN MATCHED THEN UPDATE SET t.ip_factor = ROUND(CASE WHEN src.ead_1 > 0 THEN round(( case when t.basel_approach_original in ('SA','SA_TR') THEN
                                               t.exposure_at_default+t.alloc_provision_amt ELSE t.exposure_at_default end) / nullif(src.ead_1,0),8)
														 WHEN src.ead_1 = 0 THEN 1/src.count_nr END ,8),
						t.IP_RECOVERY_ESTIMATE_AMT = round(CASE WHEN t.in_default_ind_original = 1 THEN src.IP_RECOVERY_ESTIMATE_AMT  *
														(ROUND(CASE WHEN src.ead_1 > 0 THEN round((case when t.basel_approach_original in ('SA','SA_TR') THEN
                                               t.exposure_at_default+t.alloc_provision_amt ELSE t.exposure_at_default end) / nullif(src.ead_1,0),8)
														 WHEN src.ead_1 = 0 THEN 1/src.count_nr END ,8)) END,2);
    COMMIT;

--Update ip_col010 and ip_col030 in datamart
    MERGE /*+ enable_parallel_dml */ INTO (SELECT CUSTOMER_ID,facility_id,system_id,basel_approach_original,secured_by_res_prop_ind,secured_by_com_prop_ind,ip_loss_col010,ip_loss_col030
                                         ,exposure_at_default,ip_factor
										   FROM tmp_corep_recap_measure_b4
										   WHERE observed_new_default_ip_ind = 1 AND (secured_by_res_prop_ind = 1 OR secured_by_com_prop_ind = 1))t USING  --AND   observed_new_default_ip_ind = 1
    (SELECT CUSTOMER_ID,facility_id,system_id,basel2_approach,read_1,ip_loss_col010,ip_loss_col030 FROM TT_PROV_COV_B4 WHERE in_default_ind_original = 1)src
	ON (t.CUSTOMER_ID = src.CUSTOMER_ID AND t.facility_id = src.facility_id AND t.system_id = src.system_id AND t.basel_approach_original = src.basel2_approach )
    WHEN MATCHED THEN UPDATE SET t.ip_loss_col010 = round(src.ip_loss_col010 * t.ip_factor,2),
								 t.ip_loss_col030 = round(src.ip_loss_col030 * t.ip_factor,2);
    COMMIT;

--Update ip_col050 in datamart
    MERGE /*+ enable_parallel_dml */ INTO (SELECT CUSTOMER_ID,facility_id,system_id,basel_approach_original,secured_by_res_prop_ind,secured_by_com_prop_ind,ip_loss_col050
                                        ,exposure_at_default,ip_factor,IN_DEFAULT_IND_ORIGINAL
										   FROM tmp_corep_recap_measure_b4
										   WHERE secured_by_res_prop_ind = 1 OR secured_by_com_prop_ind = 1)t USING
    (SELECT CUSTOMER_ID,facility_id,system_id,basel2_approach,MAX(read_1) read_1,MAX(ip_loss_col050) ip_loss_col050,IN_DEFAULT_IND_ORIGINAL FROM TT_PROV_COV_B4 
    GROUP BY CUSTOMER_ID,facility_id,system_id,basel2_approach,IN_DEFAULT_IND_ORIGINAL)src
	ON (t.CUSTOMER_ID = src.CUSTOMER_ID AND t.facility_id = src.facility_id AND t.system_id = src.system_id 
    AND t.basel_approach_original = src.basel2_approach
    AND t.IN_DEFAULT_IND_ORIGINAL = src.IN_DEFAULT_IND_ORIGINAL)
    WHEN MATCHED THEN UPDATE SET t.ip_loss_col050 = round(src.ip_loss_col050 * t.ip_factor,2);
    COMMIT;
	
--Update IP_REF_DEF_DATE date in datamart tmp table
    MERGE /*+ enable_parallel_dml */ INTO (SELECT system_id,customer_id ,IP_REF_DEF_DATE FROM tmp_corep_recap_measure_b4
                WHERE in_default_ind_original = 1
                ) t USING
    (SELECT CUSTOMER_ID,SYSTEM_ID,MIN(RECORD_VALID_FROM) IP_REF_DEF_DATE
	 FROM TT_OLD_DEFAULTS_B4 GROUP BY customer_id,system_id) src
     ON (t.CUSTOMER_ID = src.CUSTOMER_ID AND t.system_id = src.system_id )
    WHEN MATCHED THEN UPDATE SET t.IP_REF_DEF_DATE = src.IP_REF_DEF_DATE;
    COMMIT;	
	
--Update IP_REF_NON_DEF_DATE date in datamart tmp table
    MERGE /*+ enable_parallel_dml */ INTO (SELECT system_id,customer_id,IP_REF_NON_DEF_DATE FROM tmp_corep_recap_measure_b4
                WHERE in_default_ind_original = 1
                ) t USING
    (SELECT CUSTOMER_ID,SYSTEM_ID,MAX(RECORD_VALID_FROM) IP_REF_NON_DEF_DATE
	 FROM tt_last_non_default GROUP BY customer_id,system_id) src
     ON (t.CUSTOMER_ID = src.CUSTOMER_ID AND t.system_id = src.system_id )
    WHEN MATCHED THEN UPDATE SET t.IP_REF_NON_DEF_DATE = src.IP_REF_NON_DEF_DATE;
    COMMIT;
	
    UPDATE tmp_corep_recap_measure_b4
    SET IP_REF_DEF_DATE = v_reporting_date
    WHERE in_default_ind_original = 1
    AND IP_REF_DEF_DATE IS NULL;
    COMMIT;	
	
--Update EAD at default date and orig cover amount at not default date in datamart for current defaulted customers.
    MERGE /*+ enable_parallel_dml */ INTO (SELECT CUSTOMER_ID,facility_id,system_id,basel_approach_original,ip_ead_ref_def_date,IP_COVER_AMT_REF_NON_DEF_DATE
											, ip_factor,IP_REF_DEF_DATE
										   FROM tmp_corep_recap_measure_b4
										   WHERE (secured_by_res_prop_ind = 1 OR secured_by_com_prop_ind = 1)
										   AND in_default_ind_original = 1) t USING
    (SELECT CUSTOMER_ID,facility_id,system_id,basel2_approach,read_old,cover_amt,ead_1
     FROM TT_EXPOSURE_IP_B4 WHERE in_default_ind_original = 1) src
    ON (t.CUSTOMER_ID = src.CUSTOMER_ID AND t.facility_id = src.facility_id AND t.system_id = src.system_id AND t.basel_approach_original = src.basel2_approach )
    WHEN MATCHED THEN UPDATE SET t.ip_ead_ref_def_date =  case when t.IP_REF_DEF_DATE = v_reporting_date then round(t.ip_factor * src.ead_1,2)
															else round(t.ip_factor * src.read_old,2) end, --STRY0479738: changed to read_old
                                 t.IP_COVER_AMT_REF_NON_DEF_DATE =  round(t.ip_factor * src.cover_amt,2);

    v_debug_msg := $$plsql_line|| ' of plsql unit '|| $$plsql_unit|| ' '|| systimestamp|| ' Rows Affected:- '|| SQL%rowcount;
    utilities.show_debug(v_debug_msg);
    COMMIT;



    insert_dmb_log_corep(v_detail_level    => 103,
                                   v_log_descr       => 'process_pre_corep_recap_b4',
                                   v_activity_code   => 'LOSS',
                                   v_result_code     => 'FINOK',
                                   v_system_id       => v_system_id,v_reporting_date       => v_reporting_date
                                  );


    insert_dmb_log_corep(v_detail_level    => 103,
                                   v_log_descr       => 'process_pre_corep_recap_b4',
                                   v_activity_code   => 'CDS',
                                   v_result_code     => 'START',
                                   v_system_id       => v_system_id,v_reporting_date       => v_reporting_date
                                   );
    -- LR columns
    -- 1. update cva_amount and dva_amount from dwh_outstanding_time_band_fact
    utilities.truncate_table('TMP_COREP_CDS_B4');
    BEGIN -- retrieve Bought and Sold covers
        INSERT /*+ APPEND +*/ INTO TMP_COREP_CDS_B4 (system_id,record_valid_from,reporting_date,cover_key,facility_key,cds_ind,expiry_date,customer_id_cp,customer_id_ref,notional_amount,clearinghouse)
        (SELECT c.system_id,c.record_valid_from,v_reporting_date,c.cover_key,c.facility_key,
			   CASE WHEN ct.ct_lr_cds_class_id = 'CDS_BOUGHT' THEN 'B'
					WHEN ct.ct_lr_cds_class_id = 'CDS_SOLD' THEN 'S'
			   END,expiry_date,cover_provider,f.customer_id,
			   CASE WHEN cf.amt_type = 'CCRB' AND c.cover_key = cf.cover_key AND ct.ct_lr_cds_class_id = 'CDS_BOUGHT' THEN cf.cover_amt
					ELSE 0
			   END,'N' --clearinghouse
		FROM dwh_cover c,cover_type ct,dwh_facility f,dwh_cover_fact cf
		WHERE c.system_id = 'CRS' AND c.record_valid_from = v_reporting_date
		AND c.cover_type_key = ct.cover_type_key AND ct.ct_lr_cds_class_id in ('CDS_BOUGHT','CDS_SOLD')
		AND f.system_id(+) = 'CRS' AND f.record_valid_from(+) = v_reporting_date
		AND cf.system_id(+) = 'CRS' AND cf.record_valid_from(+) = v_reporting_date
		AND cf.amt_type(+) = 'CCRB'
		AND c.facility_key = f.facility_key(+)
		AND c.cover_key = cf.cover_key(+));
    EXCEPTION
        WHEN OTHERS THEN utils.handleerror(sqlcode,sqlerrm);
    END;
    COMMIT;

   -- update notional amount for Sold
   -- begin select outstanding groups with single CDS Sold covers
    utilities.truncate_table('tt_tmp_cds_covers');
--   UTILS.IDENTITY_RESET('tt_tmp_cds_covers');
    BEGIN
        INSERT /*+ APPEND +*/ INTO tt_tmp_cds_covers
        (SELECT DISTINCT t.cover_key cover_unique_key,rm.outstanding_group_key
         FROM TMP_COREP_CDS_B4 t,dwh_vre_cover_recapb4 rm
         WHERE t.cover_key = rm.cover_key
         AND t.cds_ind = 'S'
         AND --(rm.record_valid_from, rm.system_id) IN  ( SELECT /*+ PRECOMPUTE_SUBQUERY */ reporting_date, system_id FROM tmp_basel_combined_uploads)
		     rm.system_id = v_system_id --  modification corep_vpp
		 AND rm.record_valid_from = v_reporting_date --  modification corep_vpp
         AND rm.configuration_code = 'RECAP4AIRO'
        );
    EXCEPTION
        WHEN OTHERS THEN utils.handleerror(sqlcode,sqlerrm);
    END;
    COMMIT;

---------------------------------------modification corep_vpp
   DELETE FROM tt_tmp_outstanding_min_timeband;
   UTILS.IDENTITY_RESET('tt_tmp_outstanding_min_timeband');

   INSERT /*+ APPEND +*/ INTO tt_tmp_outstanding_min_timeband (
   	SELECT /*+ no_index(otbf) */ otbf.outstanding_key ,
           otbf.netting_type ,
           MIN(otbf.time_band_key)  min_tb_key
   	  FROM dwh_outstanding_time_band_fact otbf
   	 WHERE  otbf.netting_type = 'NET'
              AND otbf.system_id = v_system_id
              AND otbf.record_valid_from = v_reporting_date
   	  GROUP BY otbf.outstanding_key,otbf.netting_type );
      COMMIT;
   DELETE FROM tt_mintb;
   UTILS.IDENTITY_RESET('tt_mintb');
   COMMIT;
--\\
   INSERT /*+ APPEND +*/ INTO tt_mintb (
   	SELECT /*+ no_index(otba) */ min_tb.outstanding_key ,
           SUM(CASE
                    WHEN min_tb.netting_type = 'NET' THEN otba.os_amt
               ELSE NULL
                  END)  max_rb_tb_os_amt
   	  FROM tt_tmp_outstanding_min_timeband min_tb,
           dwh_outstanding_time_band_fact otba
   	 WHERE  otba.outstanding_key = min_tb.outstanding_key
              AND otba.time_band_key = min_tb.min_tb_key
              AND otba.netting_type = min_tb.netting_type
              AND otba.system_id = v_system_id
              AND otba.record_valid_from = v_reporting_date
   	  GROUP BY min_tb.outstanding_key );
      COMMIT;
--------------------------------------------------------------
   -- end select outstanding groups with single CDS Sold covers
   -- select OS amt for remaining outstanding groups
    utilities.truncate_table('tt_tmp_cds_os');
    BEGIN
        INSERT /*+ APPEND +*/ INTO tt_tmp_cds_os
        (SELECT rm.outstanding_group_key,SUM(mintb.max_rb_tb_os_amt) os_amt
         FROM dwh_outstanding rm,tt_mintb mintb                  --  modification corep_vpp
         WHERE rm.outstanding_key = mintb.outstanding_key(+)
         AND outstanding_group_key IN (SELECT /*+ PRECOMPUTE_SUBQUERY */ outstanding_group_key FROM tt_tmp_cds_covers GROUP BY outstanding_group_key)
         AND rm.system_id = v_system_id --  modification corep_vpp
		 AND rm.record_valid_from = v_reporting_date --  modification corep_vpp
         GROUP BY rm.outstanding_group_key
        );
    EXCEPTION
        WHEN OTHERS THEN utils.handleerror(sqlcode,sqlerrm);
    END;
    COMMIT;
   -- select nr covers for remaining outstanding groups
    utilities.truncate_table('tt_tmp_nr_os_cover');
--   UTILS.IDENTITY_RESET('tt_tmp_nr_os_cover');
    BEGIN
        INSERT /*+ APPEND +*/ INTO tt_tmp_nr_os_cover
        (SELECT COUNT(DISTINCT t.cover_key) nr_covers,rm.outstanding_group_key
         FROM TMP_COREP_CDS_B4 t,dwh_vre_cover_recapb4 rm
         WHERE t.cover_key = rm.cover_key
         AND t.cds_ind = 'S'
         AND rm.configuration_code = 'RECAP4AIRO'
         AND rm.outstanding_group_key IN (SELECT /*+ PRECOMPUTE_SUBQUERY */ outstanding_group_key FROM tt_tmp_cds_covers)
         AND rm.system_id = v_system_id --  modification corep_vpp
		 AND rm.record_valid_from = v_reporting_date --  modification corep_vpp
         GROUP BY rm.outstanding_group_key
        );
    EXCEPTION
        WHEN OTHERS THEN utils.handleerror(sqlcode,sqlerrm);
    END;

    COMMIT;
   -- calc notional amount for sold by dividing OS by Nr Sold Covers
    utilities.truncate_table('tt_tmp_s_notional_amount');
    BEGIN
        INSERT /*+ APPEND +*/ INTO tt_tmp_s_notional_amount
        (SELECT o.outstanding_group_key,c.cover_key,o.os_amt / n.nr_covers notional_amount
         FROM tt_tmp_cds_os o,tt_tmp_nr_os_cover n,dwh_vre_cover_recapb4 c
         WHERE c.configuration_code = 'RECAP4AIRO'
         AND c.system_id = v_system_id --  modification corep_vpp
		 AND c.record_valid_from = v_reporting_date --  modification corep_vpp
         AND c.outstanding_group_key = o.outstanding_group_key
         AND o.outstanding_group_key = n.outstanding_group_key
         AND c.cover_key IN (SELECT /*+ PRECOMPUTE_SUBQUERY */ cover_key FROM TMP_COREP_CDS_B4 WHERE cds_ind = 'S')
        );
    EXCEPTION
        WHEN OTHERS THEN utils.handleerror(sqlcode,sqlerrm);
    END;
    COMMIT;
    --JT Query tune for performance issue
    MERGE /*+ enable_parallel_dml */ INTO (SELECT cover_key,notional_amount FROM TMP_COREP_CDS_B4 WHERE cds_ind = 'S') t USING
    (SELECT MAX(notional_amount) notional_amount,cover_key
     FROM tt_tmp_s_notional_amount group by cover_key) src
    ON (  t.cover_key = src.cover_key )
    WHEN MATCHED THEN UPDATE SET t.notional_amount = src.notional_amount;
    COMMIT;

    UPDATE /*+ enable_parallel_dml */ TMP_COREP_CDS_B4
    SET clearinghouse = 'Y'
    WHERE CAST(customer_id_cp AS VARCHAR2(30)) IN (SELECT /*+ PRECOMPUTE_SUBQUERY */ code FROM clearinghouse WHERE basel2_recognised = 'Y');
    COMMIT;

    --JT Query tune for performance issue
    MERGE /*+ enable_parallel_dml */ INTO (SELECT facility_key,ing_legal_entity_key--,sync_key
	FROM TMP_COREP_CDS_B4) t USING
    (SELECT /*+ no_index(f) */ f.entity_key,f.facility_key
     FROM  dwh_facility f
     WHERE f.system_id = v_system_id --  modification corep_vpp
	 AND f.record_valid_from = v_reporting_date) src
    ON ( t.facility_key = src.facility_key )
    WHEN MATCHED THEN UPDATE SET t.ing_legal_entity_key = src.entity_key;
    COMMIT;

    UPDATE /*+ enable_parallel_dml */ tmp_corep_recap_measure_b4
    SET default_fund_ind = 1
    WHERE product_type_key IN (SELECT /*+ PRECOMPUTE_SUBQUERY */ facility_type_key FROM dm_facility_type WHERE basel_level2_code = 'WSD' AND hierarchy_level = 6);
    COMMIT;

    insert_dmb_log_corep(v_detail_level    => 103,
                                   v_log_descr       => 'process_pre_corep_recap_b4',
                                   v_activity_code   => 'CDS',
                                   v_result_code     => 'FINOK',
                                   v_system_id       => v_system_id,v_reporting_date       => v_reporting_date
                                  );

    insert_dmb_log_corep(v_detail_level    => 103,
                                   v_log_descr       => 'process_pre_corep_recap_b4',
                                   v_activity_code   => 'FINREP',
                                   v_result_code     => 'START',
                                   v_system_id       => v_system_id,v_reporting_date       => v_reporting_date
                                   );


    utilities.truncate_table('tt_tmp_cust_default');
    BEGIN
        INSERT /*+ APPEND +*/ INTO tt_tmp_cust_default
        (SELECT /*+ no_index(c) */ c.customer_id,MIN(c.record_valid_from) record_valid_from
         FROM tmp_corep_recap_measure_b4 rm,dwh_derived_customer c
         WHERE rm.in_default_ind = 1
         AND rm.customer_id = c.customer_id
         AND c.risk_rating_key IN (SELECT risk_rating_key FROM risk_rating WHERE in_default = 'Y')
         GROUP BY c.customer_id
         );
    EXCEPTION
        WHEN OTHERS THEN utils.handleerror(sqlcode,sqlerrm);
    END;
    COMMIT;


    UPDATE /*+ enable_parallel_dml */ tmp_corep_recap_measure_b4
    SET local_official_approach_indicator = 1
    WHERE basel_local_official_approach IS NOT NULL
    AND basel_local_official_approach <> ' '
    AND basel_local_official_approach = basel_approach_original;
    COMMIT;

    UPDATE /*+ enable_parallel_dml */ tmp_corep_recap_measure_b4
    SET local_official_approach_indicator = 1
    WHERE NVL(basel_local_official_approach,' ') = ' '
    AND basel_approach_original = basel2_official_approach;
    COMMIT;
    -- update cdspb_facility_ind   ---    exclude Credit Default Swap Protection Bought facilities

    UPDATE /*+ enable_parallel_dml */ tmp_corep_recap_measure_b4
    SET cdspb_facility_ind = 1
    WHERE facility_purpose_key IN (SELECT /*+ PRECOMPUTE_SUBQUERY */ facility_purpose_key FROM dm_facility_purpose WHERE hierarchy_level = 4 AND facility_purpose_descr = 'Credit Default Swap Protection Bought');
    COMMIT;


   ----------------------------------------------------------------------------------------------
   -- IFRS Accounting Classification
   ----------------------------------------------------------------------------------------------
   --JT Query tune for performance issue
   MERGE /*+ enable_parallel_dml */ INTO (SELECT outstanding_group_key,facility_key,customer_key,ifrs_accounting_classification
               FROM tmp_corep_recap_measure_b4) t USING
   (SELECT dog.outstanding_group_key,dog.facility_key,dog.customer_key,aci.acg_cl_ifrs_key,aci.code
    FROM  dwh_outstanding_group dog,acg_cl_ifrs aci
    WHERE dog.ifrs9_accounting_classification_key = aci.acg_cl_ifrs_key
    AND --(dog.record_valid_from, dog.system_id) IN  ( SELECT /*+ PRECOMPUTE_SUBQUERY */ reporting_date, system_id FROM tmp_basel_combined_uploads)
	     dog.system_id = v_system_id --  modification corep_vpp
	 AND dog.record_valid_from = v_reporting_date --  modification corep_vpp
   ) src
   ON (t.outstanding_group_key = src.outstanding_group_key AND t.facility_key = src.facility_key AND t.customer_key = src.customer_key )
   WHEN MATCHED THEN UPDATE SET t.ifrs_accounting_classification = src.code;
   COMMIT;
   ----------------------------------------------------------------------------------------------
   -- IFRS Measurement Category
   ----------------------------------------------------------------------------------------------
   --JT Query tune for performance issue
   MERGE /*+ enable_parallel_dml */ INTO (SELECT outstanding_group_key,facility_key,customer_key,ifrs_measurement_category
               FROM tmp_corep_recap_measure_b4) t using
   (SELECT dog.outstanding_group_key,dog.facility_key,dog.customer_key,msi.msr_cgy_ifrs_key,msi.code
    FROM dwh_outstanding_group dog,msr_cgy_ifrs msi
    WHERE dog.ifrs9_measurement_category_key = msi.msr_cgy_ifrs_key
    AND --(dog.record_valid_from, dog.system_id) IN  ( SELECT /*+ PRECOMPUTE_SUBQUERY */ reporting_date, system_id FROM tmp_basel_combined_uploads)
	     dog.system_id = v_system_id --  modification corep_vpp
	 AND dog.record_valid_from = v_reporting_date --  modification corep_vpp
   ) src
   ON (t.outstanding_group_key = src.outstanding_group_key AND t.facility_key = src.facility_key AND t.customer_key = src.customer_key)
   WHEN MATCHED THEN UPDATE SET t.ifrs_measurement_category = src.code;
   COMMIT;

    	----------------------------------------------------------------------------------------------
	-- ccr_wrong_way_risk_indicator
	----------------------------------------------------------------------------------------------
	UPDATE tmp_corep_recap_measure_b4 rm
   SET rm.ccr_wrong_way_risk_indicator = 1
 WHERE  EXISTS ( SELECT 1
                 FROM dwh_outstanding os,
                      wrong_way_risk_type w
                  WHERE  --(os.record_valid_from, os.system_id, os.load_key) IN  ( SELECT /*+ PRECOMPUTE_SUBQUERY */ reporting_date, system_id, load_key_n FROM tmp_basel_combined_uploads)
				  	           os.system_id = v_system_id --  modification corep_vpp
	                       AND os.record_valid_from = v_reporting_date --  modification corep_vpp
                           AND os.outstanding_key = rm.outstanding_key
                           AND os.wrong_way_risk_type_key = w.wrong_way_risk_type_key
                           AND w.code = 'SWWR' );


commit;


    --WHERE NULL
    MERGE /*+ enable_parallel_dml */ INTO (SELECT risk_weight_factor_bucket_key,risk_weight_factor_bucket_code,risk_weight_factor,record_valid_from
                FROM tmp_corep_recap_measure_b4 WHERE source_table IN ('SA', 'SEC') AND risk_weight_factor_bucket_key IS NULL) t USING
    (SELECT risk_factor,record_valid_from,record_valid_until,risk_weight_bucket_sa_key,code
     FROM risk_weight_bucket_sa
     WHERE risk_factor IS NULL) src
    ON (src.record_valid_from <= t.record_valid_from AND NVL(src.record_valid_until,utilities.record_default_date) > t.record_valid_from)
    WHEN MATCHED THEN UPDATE SET t.risk_weight_factor_bucket_key = src.risk_weight_bucket_sa_key,
                                 t.risk_weight_factor_bucket_code = src.code;
    COMMIT;


    --WHERE NULL
    MERGE /*+ enable_parallel_dml */ INTO (SELECT risk_weight_factor,record_valid_from,lr_risk_weight_bucket_code
                FROM tmp_corep_recap_measure_b4 WHERE lr_risk_weight_bucket_code IS NULL) t USING
    (SELECT code,rw_from,rw_until,record_valid_from,record_valid_until
     FROM lr_risk_weight_bucket
     WHERE rw_from IS NULL) src
    ON (src.record_valid_from <= t.record_valid_from AND NVL(src.record_valid_until,utilities.record_default_date)  > t.record_valid_from)
    WHEN MATCHED THEN UPDATE SET t.lr_risk_weight_bucket_code = src.code;
   COMMIT;


   insert_dmb_log_corep  (
        v_detail_level  =>  103,
        v_log_descr     => 'process_pre_corep_recap_b4',
        v_activity_code => 'pd range',
        v_result_code   => 'START',
        v_system_id     => v_system_id
    );
    --just for SEC
    BEGIN
    MERGE /*+ enable_parallel_dml */ INTO tmp_corep_recap_measure_b4 p USING
    (SELECT t.ROWID row_id, S.code
    FROM tmp_corep_recap_measure_b4 t,corep_pd_range S
    WHERE t.pd >= S.low_value
    AND t.pd < S.high_value
    AND t.record_valid_from >= S.record_valid_from
    AND ( t.record_valid_from < S.record_valid_until OR S.record_valid_until IS NULL )
    AND t.source_table = 'SEC'
    AND t.basel_approach IN ( 'AIRB','AIRB_OFFIC','FIRB' )
    AND t.corep_pd_range IS NULL --for safer side
    ) src ON ( p.ROWID = src.row_id )
    WHEN MATCHED THEN UPDATE SET p.corep_pd_range = src.code;
    EXCEPTION
      WHEN OTHERS THEN RAISE;
    END;

COMMIT;
    insert_dmb_log_corep  (
        v_detail_level  =>  103,
        v_log_descr     => 'process_pre_corep_recap_b4',
        v_activity_code => 'pd range',
        v_result_code   => 'FINOK',
        v_system_id     => v_system_id
    );



   --ORAMIGSECONDCATCHUP BEGIN
   ----------------------------------------------------------------------------------------------
   -- sts_indicator, sec_calculation_method,  sts_qualif_diff_treatment_ind
   ----------------------------------------------------------------------------------------------
   -- Default non-STS securitisations
   BEGIN
        UPDATE /*+ enable_parallel_dml */ tmp_corep_recap_measure_b4
        SET sts_indicator = 'N',sec_calculation_method = 'OTHER',sts_qualif_diff_treatment_ind = 'N'
        WHERE exposure_class IN ('SEC','SEC_SPON','SEC_ORIG')
        AND sec_calculation_method IS NULL;
   EXCEPTION
       WHEN OTHERS THEN utils.handleerror(sqlcode,sqlerrm);
   END;
   COMMIT;
   -- Set sts_qualif_diff_treatment_ind
   BEGIN
       UPDATE /*+ enable_parallel_dml */ tmp_corep_recap_measure_b4
       SET sts_qualif_diff_treatment_ind = CASE WHEN sts_indicator = 'N' THEN 'N' WHEN sts_indicator = 'Y' THEN 'Y' END
       WHERE source_table = 'SEC';
   EXCEPTION
        WHEN OTHERS THEN utils.handleerror(sqlcode,sqlerrm);
   END;
   COMMIT;

   -----------------------------------------------------------------
   -- Logic to populate column exclude_from_output floor
   -----------------------------------------------------------------
   --   MERGE /*+ enable_parallel_dml */ INTO tmp_corep_recap_measure_b4 tmp using
--    (select distinct outstanding_group_key,cover_key from tmp_corep_recap_measure_b4
--    where (outstanding_group_key,cover_key) in (select distinct outstanding_group_key,cover_key from tmp_corep_recap_measure_b4 where source_table = 'IRB' and official_approach_indicator = 1 and official_approach_applied = 'SA')
--    and source_table  = 'SA' and official_approach_indicator = 0) src
--    ON (src.outstanding_group_key = tmp.outstanding_group_key AND src.cover_key = tmp.cover_key)
--    WHEN MATCHED THEN UPDATE SET exclude_from_output_floor = 'Y';

    MERGE /*+ enable_parallel_dml */ INTO (SELECT exclude_from_output_floor,outstanding_group_key,cover_key from tmp_corep_recap_measure_b4 where source_table  = 'SA' and official_approach_indicator = 0) tmp using
    (select distinct outstanding_group_key,cover_key from tmp_corep_recap_measure_b4
     where (outstanding_group_key,cover_key) in (select distinct outstanding_group_key,cover_key
                                                 from tmp_corep_recap_measure_b4
                                                 where source_table = 'IRB'
                                                 and official_approach_indicator = 1
                                                 and official_approach_applied = 'SA')) src
    ON (src.outstanding_group_key = tmp.outstanding_group_key AND src.cover_key = tmp.cover_key)
    WHEN MATCHED THEN UPDATE SET exclude_from_output_floor = 'Y';

    COMMIT;

    UPDATE /*+ enable_parallel_dml */ tmp_corep_recap_measure_b4 SET exclude_from_output_floor = 'N' WHERE exclude_from_output_floor is NULL;
    COMMIT;

    --------------------------------------------------------------------------------------------

    -----------------------------------------------------------------
     -- 7530557 - Retrieve EL and UL from SEC aggregate DWH tables for reporting in columns 202 and 203 of C 14.00
     -----------------------------------------------------------------
     BEGIN
        MERGE /*+ enable_parallel_dml */ INTO TMP_COREP_RECAP_MEASURE_B4 t USING
        (SELECT sum(vre.expected_loss) / sum(vre.exposure_at_default) el_ratio, sum(vre.capital_requirement) / sum(vre.exposure_at_default) ul_ratio,securitisation_code
         FROM dwh_vre_secsts_aggr_bus vre 
         WHERE purpose = 'RECAPB4'
         AND vre.record_valid_from <= v_reporting_date
         AND (vre.record_valid_until > v_reporting_date OR vre.record_valid_until IS NULL)
         GROUP BY securitisation_code)src 
        ON ( src.securitisation_code = t.securitisation_code )
        WHEN MATCHED THEN UPDATE SET t.el_ratio = src.el_ratio,
                                     t.ul_ratio = src.ul_ratio;            
    EXCEPTION
       WHEN OTHERS THEN utils.handleerror(sqlcode,sqlerrm);
    END;

 --------------------------------------------------------------------
    -- Execute process_pre_corep_npl_b4 to fetch NPL data
    --------------------------------------------------------------------

     insert_dmb_log_corep(v_detail_level    => 103,
                                   v_log_descr       => 'process_pre_corep_recap_b4',
                                   v_activity_code   => 'pre_npl',
                                   v_result_code     => 'START',
                                   v_system_id       => v_system_id,v_reporting_date       => v_reporting_date
                                  );



begin
process_pre_corep_npl_b4(   v_reporting_date   => v_reporting_date,
                                   v_system_id        => v_system_id,
                                   v_batch_id         => v_batch_id,
                                   v_debug            => v_debug
                                  );
EXCEPTION
        WHEN OTHERS THEN utils.handleerror(sqlcode,sqlerrm);
    END;


     insert_dmb_log_corep(v_detail_level    => 103,
                                   v_log_descr       => 'process_pre_corep_recap_b4',
                                   v_activity_code   => 'pre_npl',
                                   v_result_code     => 'END',
                                   v_system_id       => v_system_id,v_reporting_date       => v_reporting_date
                                  );

   insert_dmb_log_corep(v_detail_level => 103,
                                  v_log_descr => 'process_pre_corep_recap_b4',
                                  v_activity_code => 'FINREP',
                                  v_result_code => 'FINOK',
                                  v_system_id       => v_system_id,v_reporting_date       => v_reporting_date);

   v_debug_msg := $$plsql_line|| ' of plsql unit '|| $$plsql_unit|| ' '|| systimestamp|| ' Rows Affected:- '|| SQL%rowcount;
   utilities.show_debug(v_debug_msg);
   COMMIT;

EXCEPTION
    WHEN OTHERS THEN utils.handleerror(sqlcode,sqlerrm);
end;
/
show errors;
GRANT EXECUTE ON process_pre_corep_recap_b4 TO VORTEX_BUSS_REPORT_GRP;