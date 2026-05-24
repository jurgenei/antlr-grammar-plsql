create or replace PROCEDURE portfolio_reports_customer_data
 (
    iv_hierarchy_level                             IN pkg_subtype.hierarchy_level DEFAULT NULL,
    iv_higher_level_key                            IN NUMBER DEFAULT NULL,
    iv_higher_level_code                           IN VARCHAR2 DEFAULT NULL,
    iv_reporting_date                              IN pkg_subtype.general_date DEFAULT NULL,
    v_login                                        IN VARCHAR2 DEFAULT NULL,
    v_initiating_office_code                       IN pkg_subtype.general_code DEFAULT NULL,
    v_booking_office_code                          IN pkg_subtype.general_code DEFAULT NULL,
    v_reporting_date_start                         IN pkg_subtype.general_date DEFAULT NULL,
    iv_report_type                                 IN VARCHAR2 DEFAULT NULL,
    v_ult_parent_based                             IN VARCHAR2 DEFAULT 'false',
    v_customer_ult_parent                          IN VARCHAR2 DEFAULT 'false',
    iv_top_n_categories                            IN VARCHAR2 DEFAULT NULL,
    iv_ct_hierarchy_type                           IN pkg_subtype.indicator DEFAULT 'L',
    v_intercompany_code                            IN pkg_subtype.general_code DEFAULT '000',
    v_customer_id                                  IN pkg_subtype.customer_id DEFAULT NULL,
    iv_hierarchy_type                              IN pkg_subtype.indicator DEFAULT NULL,
    v_source_system_id                             IN pkg_subtype.system_id DEFAULT NULL,
    iv_elec_approach                               IN pkg_subtype.general_code DEFAULT NULL,
    v_ing_legal_entity_code                        IN pkg_subtype.general_code DEFAULT NULL,
    v_report_rr_hierarchy_type                     IN pkg_subtype.general_code DEFAULT 'RRPD',
    v_report_it_hierarchy_type                     IN pkg_subtype.general_code DEFAULT 'NAICS',
    v_report_customer_type_hierarchy_type          IN pkg_subtype.general_code DEFAULT 'CT',--[C]ustomer[T]ype, [C]ustomer[F]orm.
    v_report_segmentation_type_hierarchy_type      IN pkg_subtype.general_code DEFAULT NULL,-- for normal (CUSTSEG) & Polish (POLSEG) type
    v_report_model_exposure_class_hierarchy_type   IN VARCHAR2 DEFAULT NULL,--[EA]d-model, [LG]d-model, [E]xposure[C]lass.
    v_principal_borrower                           IN VARCHAR2 DEFAULT 'false',--Indication if a principal_borrower overview is asked for.
    iv_result_column_list                          IN CLOB DEFAULT NULL,
    v_trend_interval                               IN VARCHAR2 DEFAULT NULL,--[2D]ates, [MO]nthly,[QU]arterly, [S]emi-[A]nnual, [AN]nual.
    v_nr_of_comparison_dates                       IN NUMBER DEFAULT NULL,--2,3,4,5
    iv_compare_date                                IN pkg_subtype.general_date DEFAULT NULL,
    v_nr_toppers                                   IN NUMBER DEFAULT NULL,
    v_based_on                                     IN VARCHAR2 DEFAULT NULL,
    v_grouping_level                               IN pkg_subtype.indicator DEFAULT 'L',
    v_recap_approach                               IN pkg_subtype.general_code DEFAULT NULL,
    v_aggregated                                   IN VARCHAR2 DEFAULT NULL,
    v_regulator_country_code                       IN pkg_subtype.general_code DEFAULT NULL,
    v_regulator_legal_entity_code                  IN pkg_subtype.general_code DEFAULT NULL,
    iv_debug                                       IN NUMBER DEFAULT 0,
    v_report_rd_hierarchy_type                     IN VARCHAR2 DEFAULT 'CR',--[C]redit[R]eview, [CDD], [MIFID], [B]ank[R]ating
    v_report_review_owner_hierarchy_type           IN pkg_subtype.general_code DEFAULT NULL,
    v_customer_hierarchy_variables                 IN CLOB DEFAULT ' ',
    v_facility_hierarchy_variables                 IN CLOB DEFAULT ' ',
    v_recap_hierarchy_variables                    IN VARCHAR2 DEFAULT ' ',
    v_raroc_indicator                              IN pkg_subtype.indicator DEFAULT 'N',
    v_failedsettlement_code                        IN pkg_subtype.general_code
	
) AS

    v_cursor                             SYS_REFCURSOR;
    v_reporting_date                     pkg_subtype.general_date := iv_reporting_date;
    v_hierarchy_type                     pkg_subtype.indicator := iv_hierarchy_type;
    v_elec_approach                      pkg_subtype.general_code := iv_elec_approach;
    v_elec_approach_orig                 pkg_subtype.general_code := iv_elec_approach;
    v_result_column_list                 CLOB := iv_result_column_list;
    v_ct_hierarchy_type                  pkg_subtype.indicator := iv_ct_hierarchy_type;
    v_hierarchy_level                    pkg_subtype.hierarchy_level := iv_hierarchy_level;
    v_report_type                        VARCHAR2(50) := iv_report_type;
    v_higher_level_key                   NUMBER(12) := iv_higher_level_key;
    v_top_n_categories                   VARCHAR2(1000) := iv_top_n_categories;
    v_compare_date                       pkg_subtype.general_date := iv_compare_date;
    v_debug                              NUMBER(12) := iv_debug;
	v_fst_value                          VARCHAR2(2);


    v_select_statement                   CLOB;
    v_statement                          CLOB;--Used as a temp variable to populate with sql and execute it directly. --ORAIQ_P9 varchar(20000) changed with varchar(16384)
    v_from_statement_cb                  CLOB;
    v_from_statement_fb                  CLOB;
    v_from_statement_basic               CLOB;
    v_where_clause_cb                    CLOB;
    v_where_clause_fb                    CLOB;
    v_where_clause_all                   CLOB;
    v_group_statement                    VARCHAR2(5000 CHAR);
    v_report_type_table                  VARCHAR2(50 CHAR);
    v_report_type_im_table               VARCHAR2(50 CHAR);
    v_report_key                         VARCHAR2(50 CHAR);
    v_report_code                        VARCHAR2(50 CHAR);
    v_report_field                       VARCHAR2(50 CHAR);
    v_report_descr                       VARCHAR2(50 CHAR);
    v_crm_field                          VARCHAR2(250 CHAR);
    v_crm_rd_field                       VARCHAR2(50 CHAR);--added to change crm_field selection where @report_type='ReviewDate'
    v_cust_sel_table                     VARCHAR2(5 CHAR);
    v_cust_table_name                    VARCHAR2(50 CHAR);
    v_authorisation_enabled              VARCHAR2(1 CHAR);
    v_table_name                         VARCHAR2(50 CHAR);
    v_hierarchy_parent                   VARCHAR2(30 CHAR);--Customer column on which the data has to be filtered.
    v_hierarchy_parent_display           VARCHAR2(30 CHAR);--Customer column on which the data has te be aggregated.
    v_nr_facilities                      NUMBER(12);
    v_elec_suffix                        pkg_subtype.general_code;
    v_expected_loss_active               pkg_subtype.indicator;
    v_economic_capital_active            pkg_subtype.indicator;
    v_raroc_active                       pkg_subtype.indicator;
    v_elec_available                     pkg_subtype.indicator;
    v_elec_available_basel               pkg_subtype.indicator;
    v_higher_level_key_orig              NUMBER(12);--Indicates the original higher level key.
    v_period                             pkg_subtype.indicator;
    v_time                               DATE;
    v_based_on_total                     VARCHAR2(50 CHAR);
    v_authorisation_components           VARCHAR2(10 CHAR);
    v_select_cat_description             VARCHAR2(1 CHAR);
    v_facility_based                     VARCHAR2(1 CHAR);
    v_update_statement                   CLOB;
    v_column_name_ead_model_key          pkg_subtype.description30;
    v_fullstatement                      CLOB;
    v_recent_reporting_date              pkg_subtype.general_date;
    v_first_reporting_date               pkg_subtype.general_date;
    v_recent_reporting_date_code         NUMBER(5);
    v_first_reporting_date_code          NUMBER(5);
    v_procedure_name                     VARCHAR2(128 CHAR);
    v_update_statement_basel             CLOB;
    v_from_statement_top                 CLOB;
    v_where_clause_top                   CLOB;
    v_report_key_top                     VARCHAR2(50 CHAR);
    v_report_type_table_top              VARCHAR2(50 CHAR);
    v_max_topn_date                      DATE;
    v_ing_ult_level_code                 VARCHAR2(20 CHAR);
    v_ing_ult_level_key                  pkg_subtype.general_int;
    v_insert_columns_crm                 CLOB;
    v_aggregation_columns_crm            CLOB;
    v_select_columns_crm                 CLOB;
    v_select_columns_crm_row             CLOB;
    v_insert_columns_recap               CLOB;
    v_select_columns_recap               CLOB;
    v_basel_indicator                    pkg_subtype.indicator;
    v_review_date_midfix                 VARCHAR2(6 CHAR);
    v_select_columns_review_date_total   VARCHAR2(2000 CHAR);
    v_select_columns_review_date         VARCHAR2(2000 CHAR);
    v_insert_columns_review_date         VARCHAR2(2000 CHAR);
    v_group_columns_review_date          VARCHAR2(2000 CHAR);
    v_source_table                       VARCHAR2(5 CHAR);
    v_ret                                NUMBER(12);
    v_column_name_ead_model_code         pkg_subtype.description30;
    v_none_code                          VARCHAR2(100 CHAR);
    v_none_descr                         VARCHAR2(2000 CHAR);
    v_other_code                         VARCHAR2(100 CHAR);
    v_other_descr                        VARCHAR2(2000 CHAR);
    v_temp                               NUMBER(1,0) := 0;
    v_hierarchy_parent2                  VARCHAR2(3000 CHAR);
    v_default_code                       pkg_subtype.general_code;
    v_default_descr                      pkg_subtype.description100;
    v_column_heading                     pkg_subtype.general_code;
    v_higher_level_code                  VARCHAR2(50 CHAR) := iv_higher_level_code;
    l_v_report_code                      VARCHAR2(50 CHAR) := v_report_code;
    v_debug_msg                          CLOB;
    v_elec_switch_recap_approach         VARCHAR2(100);
BEGIN

    v_debug_msg := $$plsql_line || ' OF PLSQL UNIT ' || $$plsql_unit || '<<start>>';
    utilities.show_debug(v_debug_msg);
    v_procedure_name := 'portfolio_reports_customer_data';
    v_column_name_ead_model_key := 'ead_model_key';
   ------------------------------------------------------------------------------
   -- check if authorisation is enabled for the current user
   -- Must be first of the procedure and committed asap.
   ------------------------------------------------------------------------------
    v_authorisation_enabled := 'Y';
    authorisation_enabled(
        login                             => v_login,
        authorisation_enabled_output      => v_authorisation_enabled,
        authorisation_components_output   => v_authorisation_components
    );
   ------------------------------------------------------------------------------
   -- Default parameters
   ------------------------------------------------------------------------------
	v_fst_value:= v_failedsettlement_code;

    IF ( v_reporting_date IS NULL ) THEN
        v_reporting_date := SYSDATE;
    END IF;
    IF ( ( v_customer_id IS NOT NULL ) AND ( v_hierarchy_type IS NULL ) ) THEN
        v_hierarchy_type := 'L';
    END IF;

    IF ( v_elec_approach IS NULL ) THEN
        v_elec_approach := 'Finance';
    END IF;
    IF ( v_elec_approach = 'Basel4' ) THEN
        v_elec_approach := 'Basel';
    END IF;

    IF (utilities.get_control_param_value('RECAPB4_ACTIVE_FOR_DEPENDENCY', v_reporting_date) = 'Y' OR v_elec_approach_orig = 'Basel4') AND v_elec_approach_orig != 'Basel' THEN
        v_elec_switch_recap_approach := 'recap4';
    ELSE
        v_elec_switch_recap_approach := 'recap';
    END IF;

    IF ( v_result_column_list IS NULL OR trim(v_result_column_list) = ' ' ) THEN
        BEGIN
            v_result_column_list := 'product_type_key,product_type_descr,max_limit,max_os,principal_outstanding_amount,external_risk_rating_original,external_risk_rating_agency,ext_rating_agency_key,accrued_interest_amt,gross_carrying_amount,accounting_value,commit_undrawn_amount,uncommit_advised_undrawn_amount,exposure,expected_loss' --ORAMIGTHIRDCATCHUP
            || ',economic_capital,expected_transfer_loss,transfer_event_probability,exposure_at_transfer_event,loss_given_transfer_event'
            || ',economic_capital_transfer,unexpected_transfer_loss,correlation_transfer_factor,capital_transfer_multiple,expected_credit_loss'
            || ',probability_of_default,exposure_at_default,loss_given_default,economic_capital_credit,unexpected_credit_loss'
            || ',correlation_credit_factor,capital_credit_multiple,regulatory_capital,regulatory_probability_of_default,regulatory_exposure_at_default'
            || ',regulatory_loss_given_default,regulatory_maturity,regulatory_risk_weight,regulatory_risk_weighted_assets,regulatory_asset_class_code'
            || ',regulatory_asset_class_descr,nr_of_fac,r_squared_credit_factor'
            || ',exposure_at_default_model,loss_given_default_model'
            || ',residual_value_amount,residual_value_risk_weight,residual_value_risk_weight_asset'
            || ',effective_maturity,residual_value_capital,asset_default_correlation,compliance_department'
            || ',cva_risk_weight,cva_effective_maturity,cva_diversification_ratio,diversified_cva_capital'
            || ',regulatory_outstanding_amount,after_coll_regulatory_os_amt,gross_regulatory_os_amt,total_cva_exposure,cva_exposure'
            || ',provision_amount,collective_provision_stage_1,collective_provision_stage_2,collective_provision_stage_3,collective_poci,collective_off_balance,individual_poci,individual_off_balance,individual_provision_stage_3,off_balance_provision,other_provision';
                            --   Cva capital columns.

            IF v_raroc_indicator = 'Y' THEN
                v_result_column_list := v_result_column_list || ',interest_income,fees,employee_benefits,other_income,revenues,risk_adjusted_revenue,net_cost_economic_capital'
|| ',gross_eva,required_return,operating_expenses,net_eva,economic_capital_adjusted,gross_raroc,net_raroc';
            END IF;

        END;
    END IF;
   --Enclose complete string with comma so we can check ",<column>,"

    v_result_column_list := ',' || v_result_column_list || ',';
   ------------------------------------------------------------------------------
   -- Add dependencies between result columns.(eg when columns are weigted).
   ------------------------------------------------------------------------------
    v_result_column_list := v_result_column_list || f_dynamic_result(
        v_result_column_list,
        'weighted_loss_given_transfer_event',
        'loss_given_transfer_event,'
    );
    v_result_column_list := v_result_column_list  || f_dynamic_result(
        v_result_column_list,
        'total_cva_exposure',
        'total_cva_exposure,'
    )|| f_dynamic_result(
        v_result_column_list,
        'cva_risk_weight',
        'cva_exposure,'
    ) || f_dynamic_result(
        v_result_column_list,
        'cva_effective_maturity',
        'cva_exposure,'
    ) || f_dynamic_result(
        v_result_column_list,
        'cva_diversification_ratio',
        'cva_exposure,'
    ) || f_dynamic_result(
        v_result_column_list,
        'loss_given_default',
        'exposure_at_default_abs,'
    ) || f_dynamic_result(
        v_result_column_list,
        'loss_given_default',
        'weighted_loss_given_default,'
    ) || f_dynamic_result(
        v_result_column_list,
        'probability_of_default',
        'exposure_at_default_abs,'
    ) || f_dynamic_result(
        v_result_column_list,
        'loss_given_transfer_event',
        'exposure_at_transfer_event_abs,'
    ) || f_dynamic_result(
        v_result_column_list,
        'transfer_event_probability',
        'exposure_at_transfer_event_abs,'
    ) || f_dynamic_result(
        v_result_column_list,
        'correlation_transfer_factor',
        'unexpected_transfer_loss_abs,'
    ) || f_dynamic_result(
        v_result_column_list,
        'capital_transfer_multiple',
        'exposure_at_transfer_event_abs,'
    ) || f_dynamic_result(
        v_result_column_list,
        'probability_of_default',
        'exposure_at_default_abs,'
    ) || f_dynamic_result(
        v_result_column_list,
        'loss_given_default',
        'exposure_at_default_abs,'
    ) || f_dynamic_result(
        v_result_column_list,
        'asset_default_correlation',
        'correlation_credit_factor,'
    ) || f_dynamic_result(
        v_result_column_list,
        'correlation_credit_factor',
        'unexpected_credit_loss_abs,'
    ) || f_dynamic_result(
        v_result_column_list,
        'correlation_credit_factor',
        'exposure_at_default_abs,'
    ) || f_dynamic_result(
        v_result_column_list,
        'capital_credit_multiple',
        'exposure_at_default_abs,'
    ) || f_dynamic_result(
        v_result_column_list,
        'r_squared_credit_factor ',
        'exposure_at_default_abs,'
    ) || f_dynamic_result(
        v_result_column_list,
        'regulatory_probability_of_default',
        'regulatory_exposure_at_default_abs,'
    ) || f_dynamic_result(
        v_result_column_list,
        'regulatory_loss_given_default',
        'regulatory_exposure_at_default_abs, '
    ) || f_dynamic_result(
        v_result_column_list,
        'regulatory_maturity',
        'regulatory_exposure_at_default_abs,'
    ) || f_dynamic_result(
        v_result_column_list,
        'regulatory_risk_weight',
        'regulatory_exposure_at_default_abs,'
    ) || f_dynamic_result(
        v_result_column_list,
        'cure_rate',
        'exposure_at_default_abs,'
    ) || f_dynamic_result(
        v_result_column_list,
        'e_lim_factor',
        'exposure_at_default_abs,'
    ) || f_dynamic_result(
        v_result_column_list,
        'e_os_factor',
        'exposure_at_default_abs,'
    ) || f_dynamic_result(
        v_result_column_list,
        'g_factor',
        'exposure_at_default_abs,'
    ) || f_dynamic_result(
        v_result_column_list,
        'h_factor',
        'somecover_abs,'
    ) || f_dynamic_result(
        v_result_column_list,
        'k_factor',
        'exposure_at_default_abs,'
    ) || f_dynamic_result(
        v_result_column_list,
        'secured_discount_factor',
        'somecover_abs,'
    ) || f_dynamic_result(
        v_result_column_list,
        'unsecured_discount_factor',
        'exposure_at_default_abs,'
    ) || f_dynamic_result(
        v_result_column_list,
        'residual_value_risk_weight',
        'residual_value_amount_abs,'
    ) || f_dynamic_result(
        v_result_column_list,
        'effective_maturity',
        'exposure_at_default_abs,'
    ); --Cva

    IF ( v_elec_approach = 'Basel' ) THEN
        v_result_column_list := v_result_column_list || f_dynamic_result(
            v_result_column_list,
            'expected_credit_loss',
            'expected_loss,'
        ) || f_dynamic_result(
            v_result_column_list,
            'exposure_at_default_abs',
            'regulatory_exposure_at_default_abs,'
        );
    END IF;
   ------------------------------------------------------------------------------
   -- Set Column Heading
   ------------------------------------------------------------------------------

    IF ( v_grouping_level = 'O' ) THEN
        v_column_heading := 'fac_';
    ELSE
        v_column_heading := ' ';
    END IF;
   ------------------------------------------------------------------------------
   -- Init @ct_hierarchy_type
   ------------------------------------------------------------------------------

    IF ( v_ct_hierarchy_type = 'L' ) THEN
        v_hierarchy_parent := 'legal_ult_parent_id';
    ELSIF ( v_ct_hierarchy_type = 'E' ) THEN
        v_hierarchy_parent := 'econ_ult_parent_id';
    ELSE --if upper(@ct_hierarchy_type) = 'N'
        v_ct_hierarchy_type := NULL;
        v_hierarchy_parent := 'customer_id';
    END IF;
   --If we want a principal_borrower overview, we have to use the right column.
   --Business decided that we should not use ultimate parents for principal borrower.
   --As they may change their minds (due to the fact that it gives more flexibility in
   --presenting data) the if-else structure is kept in tact.

    IF ( v_principal_borrower = 'true' ) THEN
        BEGIN
            v_hierarchy_parent_display := 'principal_borrower_id';
        END;
    ELSE
        BEGIN
            IF ( v_customer_ult_parent = 'true' ) THEN
                BEGIN
                    IF ( v_ct_hierarchy_type = 'E' ) THEN
                        v_hierarchy_parent_display := 'econ_ult_parent_id';
                    ELSE
                        v_hierarchy_parent_display := 'legal_ult_parent_id';
                    END IF;

                END;

            ELSE
                BEGIN
                    v_hierarchy_parent_display := 'customer_id';
              --@customer_ult_parent = 'false'
                END;
            END IF;

        END;
    END IF;

    utilities.truncate_table('time_period_tmp');
   ------------------------------------------------------------------------------
   -- determine dates to include in the report.
   ------------------------------------------------------------------------------
    IF ( v_trend_interval IS NOT NULL ) THEN
        BEGIN
         -- v_fill_table_with_tre_param := v_reporting_date ;--reporting_date.
          --Fill the table time_period_tmp with the right dates for the trend-report.
            v_ret := fill_table_with_trendreporting_dates(
                v_reporting_date           => v_reporting_date,
                v_nr_of_comparison_dates   => v_nr_of_comparison_dates, --nr of values for trendreporting.
                v_compare_date             => v_compare_date, --compare date in case of [2D] trend_interval.
                v_trend_interval           => v_trend_interval, --trendinterval that has to be shown.
                v_period                   => v_period, --Indication if recent, endmonth or history must be used.
                v_debug                    => v_debug
            );

        EXCEPTION
            WHEN OTHERS THEN
                utils.handleerror(
                    sqlcode,
                    sqlerrm
                );
        END;
    ELSE
        BEGIN
          --No trend report, just the reporting_date is needed.
            INSERT INTO time_period_tmp (
                period_date,
                reporting_date,
                reporting_date_code,
                flag
            )
                ( SELECT
                    v_reporting_date,
                    v_reporting_date,
                    1,
                    'O'
                  FROM
                    dual
                );

            v_period := NULL;
        EXCEPTION
            WHEN OTHERS THEN
                utils.handleerror(
                    sqlcode,
                    sqlerrm
                );
        END;
    END IF;

    utilities.truncate_table('tmp_sync_key');
    v_debug_msg := $$plsql_line || ' OF PLSQL UNIT ' || $$plsql_unit || '<<v_source_system_id>>' || v_source_system_id;
    utilities.show_debug(v_debug_msg);
    BEGIN
        INSERT INTO tmp_sync_key (
            reporting_date,
            reporting_date_code,
            sync_key,
            sync_key_recap
            ,system_id --rajiv
        )
            ( SELECT
                vdrp.record_valid_from,
                rd.reporting_date_code,
                vdrp.sync_key,
                vdbrp.sync_key
                ,vdrp.system_id--rajiv
              FROM
                time_period_tmp rd,v_dmi_reporting_period vdrp
                LEFT JOIN v_dmi_basel_reporting_period vdbrp
                ON vdrp.sync_key   = vdbrp.sync_key_n
              WHERE        vdrp.record_valid_from <= rd.reporting_date AND   (
                    vdrp.record_valid_until > rd.reporting_date OR    vdrp.record_valid_until IS NULL
                ) AND   (
                    vdrp.system_id = v_source_system_id OR    v_source_system_id IS NULL
                )
                AND vdrp.record_valid_from > ADD_MONTHS(rd.reporting_date, -12) -- don't select old closed sync keys
            );

    EXCEPTION
        WHEN OTHERS THEN
            utils.handleerror(
                sqlcode,
                sqlerrm
            );
    END;

    BEGIN
        SELECT
            MAX(reporting_date),
            MIN(reporting_date_code),
            MIN(reporting_date),
            MAX(reporting_date_code)
        INTO
            v_recent_reporting_date,v_recent_reporting_date_code,v_first_reporting_date,v_first_reporting_date_code
        FROM
            time_period_tmp;

    EXCEPTION
        WHEN no_data_found THEN
            NULL;
        WHEN OTHERS THEN
            utils.handleerror(
                sqlcode,
                sqlerrm
            );
    END;
   ------------------------------------------------------------------------------
   -- ELEC data
   ------------------------------------------------------------------------------

    BEGIN
        determine_elec_available(
            v_trend_interval               => v_trend_interval,
            v_reporting_date               => v_reporting_date,
            v_elec_approach                => v_elec_approach_orig,
            v_expected_loss_active         => v_expected_loss_active,
            v_economic_capital_active      => v_economic_capital_active,
            v_raroc_active                 => v_raroc_active,
            v_elec_suffix                  => v_elec_suffix,
            v_elec_available               => v_elec_available,
            v_elec_available_basel         => v_elec_available_basel,
            v_column_name_ead_model_key    => v_column_name_ead_model_key,
            v_debug                        => v_debug,
            v_column_name_ead_model_code   => v_column_name_ead_model_code
        );
    EXCEPTION
        WHEN OTHERS THEN
            utils.handleerror(
                sqlcode,
                sqlerrm
            );
    END;
   ------------------------------------------------------------------------------
   -- Selection Recent/end month/history
   ------------------------------------------------------------------------------

    IF ( v_period IS NULL ) THEN
        table_period_selection(
            v_reporting_date   => v_reporting_date,
            v_period           => v_period
        );
    END IF;
   ------------------------------------------------------------------------------
   -- Table selection
   ------------------------------------------------------------------------------

    BEGIN
        report_table_select(
            iv_report          => 'credit', -- credit, country, recap, raroc, provision
            v_period           => v_period, -- M = Month R=Recent H=Historical data
            v_table_name       => v_table_name,
            v_column_heading   => v_column_heading
        );-- 'fac_', ''
    EXCEPTION
        WHEN OTHERS THEN
            utils.handleerror(
                sqlcode,
                sqlerrm
            );
    END;
   -- Initialise @hierarchy_level

    IF ( ( v_hierarchy_level IS NULL OR v_hierarchy_level = 0 ) AND v_report_type NOT IN (
            'LegalEntity',
            'CorepSecDetail'
        ) ) THEN
        v_hierarchy_level := 1;
    ELSIF ( v_report_type IN (
        'LegalEntity',
        'CorepSecDetail'
    ) ) THEN
        v_hierarchy_level := NULL;
    END IF;
   -- Initialise @report_type

    IF v_report_type IS NULL THEN
        v_report_type := 'IndustryType';
    END IF;
   ------------------------------------------------------------------------------
   -- Initiate dynamic sql variables depending on @report_type
   ------------------------------------------------------------------------------
    BEGIN
        portfolio_report_type(
            v_report_type                                  => v_report_type,
            v_report_rr_hierarchy_type                     => v_report_rr_hierarchy_type,
            v_report_it_hierarchy_type                     => v_report_it_hierarchy_type,
            v_report_customer_type_hierarchy_type          => v_report_customer_type_hierarchy_type,
            v_report_segmentation_type_hierarchy_type      => v_report_segmentation_type_hierarchy_type,
            v_report_model_exposure_class_hierarchy_type   => v_report_model_exposure_class_hierarchy_type,
            v_ult_parent_based                             => v_ult_parent_based,
            v_ct_hierarchy_type                            => v_ct_hierarchy_type,
            v_report_review_owner_hierarchy_type           => v_report_review_owner_hierarchy_type,
            iv_table_name                                  => v_table_name,
            v_report_level                                 =>
                CASE
                    WHEN v_grouping_level = 'O' THEN
                        'os'
                    ELSE 'fac'
                END,
            v_report_type_table                            => v_report_type_table,
            v_report_type_im_table                         => v_report_type_im_table,
            v_report_key                                   => v_report_key,
            v_report_code                                  => v_report_code,
            v_report_field                                 => v_report_field,
            v_report_descr                                 => v_report_descr,
            v_measure_field                                => v_crm_field,
            v_facility_based                               => v_facility_based,
            v_cust_table_name                              => v_cust_table_name,
            v_report_rd_hierarchy_type                     => v_report_rd_hierarchy_type,
            v_recap_approach                               => v_recap_approach,
            v_none_code                                    => v_none_code,
            v_none_descr                                   => v_none_descr,
            v_other_code                                   => v_other_code,
            v_other_descr                                  => v_other_descr
        );
    EXCEPTION
        WHEN OTHERS THEN
            utils.handleerror(
                sqlcode,
                sqlerrm
            );
    END;
   -- Init customer selection table (depends on @ult_parent_based)

    IF ( v_cust_table_name <> ' ' ) THEN
        v_cust_sel_table := 'c';-- dmi_customer
    ELSE
        v_cust_sel_table := 'crm';
    END IF;

    IF ( v_report_type IN (
            'ReviewDate',
            'RiskRating',
            'ReviewOwner'
        ) ) THEN
        v_source_table := ' crm';
    ELSE
        v_source_table := v_cust_sel_table;
    END IF;

   --Set measure field to owner key in case of review_date_report

    IF ( v_report_type = 'ReviewDate' ) THEN
        BEGIN
            IF ( v_report_rd_hierarchy_type = 'CDD' ) THEN
                BEGIN
                    v_review_date_midfix := 'cdd_';
                END;
            ELSIF ( v_report_rd_hierarchy_type = 'MIFID' ) THEN
                BEGIN
                    v_review_date_midfix := 'mifid_';
                END;
            ELSIF ( v_report_rd_hierarchy_type = 'BR' ) THEN
                BEGIN
                    v_review_date_midfix := 'br_';
                END;
            ELSE
                BEGIN
                    v_review_date_midfix := ' ';
                END;
            END IF;

            IF ( v_ult_parent_based = 'false' ) THEN
                v_crm_rd_field := 'review_date_' || v_review_date_midfix || 'owner_key';
            ELSE
                BEGIN
                    IF ( v_ct_hierarchy_type = 'L' ) THEN
                        v_crm_rd_field := 'lup_review_date_' || v_review_date_midfix || 'owner_key';
                    ELSE
                        v_crm_rd_field := 'eup_review_date_' || v_review_date_midfix || 'owner_key';
                    END IF;

                END;
            END IF;

        END;
    END IF;

   -- select category description (or not)

    v_select_cat_description := 'N';
    IF ( v_facility_based = 'N' AND ( v_principal_borrower IS NULL OR v_principal_borrower = 'false' ) ) THEN
        IF ( ( v_ult_parent_based = 'true' AND v_customer_ult_parent = 'true' ) OR ( v_ult_parent_based = 'false' AND v_customer_ult_parent = 'false' ) ) THEN
            v_select_cat_description := 'Y';
        END IF;
    END IF;

    BEGIN
        report_selection_fill_tmp(
            v_booking_office_code        => v_booking_office_code,
            v_initiating_office_code     => v_initiating_office_code,
            v_authorisation_enabled      => v_authorisation_enabled,
            v_authorisation_components   => v_authorisation_components,
            v_login                      => v_login,
            v_debug                      => v_debug
        );
    EXCEPTION
        WHEN OTHERS THEN
            utils.handleerror(
                sqlcode,
                sqlerrm
            );
    END;
   ------------------------------------------------------------------------------
   -- Selection criteria: customer based
   ------------------------------------------------------------------------------

    IF ( v_customer_id IS NOT NULL ) THEN
        BEGIN
            customer_selection(
                v_mapping_date                   => v_reporting_date,
                v_customer_id                    => v_customer_id,
                v_hierarchy_type                 => v_hierarchy_type,
                v_debug                          => v_debug,
                v_use_review_owner_indicator     => 'N',
                v_customer_hierarchy_variables   => v_customer_hierarchy_variables
            );

        EXCEPTION
            WHEN OTHERS THEN
                utils.handleerror(
                    sqlcode,
                    sqlerrm
                );
        END;
    ELSE -- (@customer_id is null)
        BEGIN
            report_selection_customer(
                v_alias                          => v_cust_sel_table,
                v_where_clause                   => v_where_clause_cb,
                v_from_statement                 => v_from_statement_cb,
                v_ult_parent_based               => v_ult_parent_based,
                v_ct_hierarchy_type              => v_ct_hierarchy_type,
                v_debug                          => v_debug,
                v_use_review_owner_indicator     => 'N',
                v_customer_hierarchy_variables   => v_customer_hierarchy_variables
            );

        EXCEPTION
            WHEN OTHERS THEN
                utils.handleerror(
                    sqlcode,
                    sqlerrm
                );
        END;
    END IF;
   ------------------------------------------------------------------------------
   -- Selection criteria: facility based
   ------------------------------------------------------------------------------`

    BEGIN
        report_selection_facility(
            v_reporting_date                 => v_reporting_date,
            v_report_type                    => v_report_type,
            v_ult_parent_based               => v_ult_parent_based,
            v_ct_hierarchy_type              => v_ct_hierarchy_type,
            v_source_system_id               => v_source_system_id,
            v_reporting_date_start           => v_reporting_date_start,
            v_login                          => v_login,
            v_authorisation_enabled          => v_authorisation_enabled,
            v_authorisation_components       => v_authorisation_components,
            v_alias                          => 'crm',
            iv_table_name                    => v_table_name,
            v_report_level                   => 'fac',
            v_where_clause                   => v_where_clause_fb,
            v_from_statement                 => v_from_statement_fb,
            v_debug                          => v_debug,
            v_report_rd_hierarchy_type       => v_report_rd_hierarchy_type,
            v_elec_approach                  => v_elec_switch_recap_approach,
            v_facility_hierarchy_variables   => v_facility_hierarchy_variables
        );
    EXCEPTION
        WHEN OTHERS THEN
            utils.handleerror(
                sqlcode,
                sqlerrm
            );
    END;

   ---------------------------------------------------------------------------
   -- Result column definition
   ---------------------------------------------------------------------------
   --CVA

    v_insert_columns_crm := v_insert_columns_crm || f_dynamic_result(
        v_result_column_list,
        'after_coll_regulatory_os_amt',
        ', after_coll_regulatory_os_amt '
    ) || f_dynamic_result(
        v_result_column_list,
        'cva_risk_weight ',
        ', cva_risk_weight  '
    ) || f_dynamic_result(
        v_result_column_list,
        'cva_effective_maturity',
        ', cva_effective_maturity '
    ) || f_dynamic_result(
        v_result_column_list,
        'cva_diversification_ratio',
        ', cva_diversification_ratio '
    ) || f_dynamic_result(
        v_result_column_list,
        'diversified_cva_capital',
        ', diversified_cva_capital '
    ) || f_dynamic_result(
        v_result_column_list,
        'regulatory_outstanding_amount',
        ', regulatory_os_amt '
    ) || f_dynamic_result(
        v_result_column_list,
        'total_cva_exposure',
        ', total_cva_exposure '
    ) || f_dynamic_result(
        v_result_column_list,
        'cva_exposure',
        ', cva_exposure '
    ) || f_dynamic_result(
        v_result_column_list,
        'gross_regulatory_os_amt',
        ', gross_regulatory_os_amt '
    ) || f_dynamic_result(
        v_result_column_list,
        'exposure',
        ', exposure '
    ) || f_dynamic_result(
        v_result_column_list,
        'max_limit',
        ', max_limit '
    ) || f_dynamic_result(
        v_result_column_list,
        'max_os',
        ', max_os '
    )
    || f_dynamic_result(
        v_result_column_list,
        'principal_outstanding_amount',
        ', principal_outstanding_amount'
    )
    || f_dynamic_result(
        v_result_column_list,
        'accrued_interest_amt',
        ', accrued_interest_amt '
    )--ORAMIGTHIRDCATCHUP START
    || f_dynamic_result(
        v_result_column_list,
        'gross_carrying_amount',
        ', gross_carrying_amount '
    )
    || f_dynamic_result(
        v_result_column_list,
        'accounting_value',
        ', accounting_value '
    )
    || f_dynamic_result(
        v_result_column_list,
        'commit_undrawn_amount',
        ', commit_undrawn_amount '
    )     || f_dynamic_result(
        v_result_column_list,
        'uncommit_advised_undrawn_amount',
        ', uncommit_advised_undrawn_amount '
    )   --ORAMIGTHIRDCATCHUP END
    || f_dynamic_result(
        v_result_column_list,
        'provision_amount',
        ', provision_amount '
    )         --oramigfisrtcatchup--being
     || f_dynamic_result(
        v_result_column_list,
        'collective_provision_stage_1',
        ', collective_provision_stage_1 '
    ) || f_dynamic_result(
        v_result_column_list,
        'collective_provision_stage_2',
        ', collective_provision_stage_2 '
    ) || f_dynamic_result(
        v_result_column_list,
        'collective_provision_stage_3',
        ', collective_provision_stage_3 '


   --ORAMIGCATCHUP4 start
    ) || f_dynamic_result(
        v_result_column_list,
        'collective_poci',
        ', collective_poci '

    ) || f_dynamic_result(
        v_result_column_list,
        'collective_off_balance',
        ', collective_off_balance '

     ) || f_dynamic_result(
        v_result_column_list,
        'individual_poci',
        ', individual_poci '

      ) || f_dynamic_result(
        v_result_column_list,
        'individual_off_balance',
        ', individual_off_balance '
    --ORAMIGCATCHUP4 end

    ) || f_dynamic_result(
        v_result_column_list,
        'individual_provision_stage_3',
        ', individual_provision_stage_3 '
    ) || f_dynamic_result(
        v_result_column_list,
        'off_balance_provision',
        ', off_balance_provision '
    ) || f_dynamic_result(
        v_result_column_list,
        'other_provision',
        ', other_provision '
    );  ---oramigfirstcatchup--end

    IF ( v_raroc_indicator = 'Y' AND v_raroc_active = 'Y' ) THEN
        BEGIN
            v_insert_columns_crm := v_insert_columns_crm || f_dynamic_result(
                v_result_column_list,
                'interest_income',
                ',     interest_income'
            ) || f_dynamic_result(
                v_result_column_list,
                'fees',
                ',     fees'
            ) || f_dynamic_result(
                v_result_column_list,
                'employee_benefits',
                ',     employee_benefits'
            ) || f_dynamic_result(
                v_result_column_list,
                'other_income',
                ',     other_income'
            ) || f_dynamic_result(
                v_result_column_list,
                'revenues',
                ',     revenues'
            ) || f_dynamic_result(
                v_result_column_list,
                'risk_adjusted_revenue',
                ',     risk_adjusted_revenue'
            ) || f_dynamic_result(
                v_result_column_list,
                'net_cost_economic_capital',
                ',     net_cost_economic_capital'
            ) || f_dynamic_result(
                v_result_column_list,
                'gross_eva',
                ',     gross_eva'
            ) || f_dynamic_result(
                v_result_column_list,
                'required_return',
                ',     required_return'
            ) || f_dynamic_result(
                v_result_column_list,
                'operating_expenses',
                ',     operating_expenses'
            ) || f_dynamic_result(
                v_result_column_list,
                'net_eva',
                ',     net_eva'
            ) || f_dynamic_result(
                v_result_column_list,
                'economic_capital_adjusted',
                ',     economic_capital_adjusted'
            );

        END;
    END IF;

    IF ( v_elec_approach <> 'Basel' AND v_elec_available = 'Y' AND v_expected_loss_active = 'Y' ) THEN
        BEGIN
            v_insert_columns_crm := v_insert_columns_crm || f_dynamic_result(
                v_result_column_list,
                'expected_loss',
                ',   expected_loss '
            ) || f_dynamic_result(
                v_result_column_list,
                'expected_transfer_loss',
                ',   expected_transfer_loss '
            ) || f_dynamic_result(
                v_result_column_list,
                'transfer_event_probability',
                ',   pd_tr_amount  '
            ) || f_dynamic_result(
                v_result_column_list,
                'exposure_at_transfer_event',
                ',   ead_tr '
            ) || f_dynamic_result(
                v_result_column_list,
                'exposure_at_transfer_event_abs',
                ',   ead_tr_abs '
            ) || f_dynamic_result(
                v_result_column_list,
                'loss_given_transfer_event',
                ',   lgd_tr_amount '
            ) || f_dynamic_result(
                v_result_column_list,
                'expected_credit_loss',
                ',   expected_credit_loss '
            ) || f_dynamic_result(
                v_result_column_list,
                'probability_of_default',
                ',   pd_cr_amount  '
            ) || f_dynamic_result(
                v_result_column_list,
                'exposure_at_default',
                ',   ead_cr '
            ) || f_dynamic_result(
                v_result_column_list,
                'exposure_at_default_abs',
                ',   ead_cr_abs '
            ) || f_dynamic_result(
                v_result_column_list,
                'weighted_loss_given_default',
                ',   lgd_cr_amount '
            ) || f_dynamic_result(
                v_result_column_list,
                'exposure_at_default_model',
                ',   ead_model_key_cr '
            ) || f_dynamic_result(
                v_result_column_list,
                'loss_given_default_model',
                ',   lgd_model_key_cr '
            );

        END;
    END IF;

    IF ( v_elec_approach <> 'Basel' AND v_elec_available = 'Y' AND v_economic_capital_active = 'Y' ) THEN
        BEGIN
            v_insert_columns_crm := v_insert_columns_crm || f_dynamic_result(
                v_result_column_list,
                'economic_capital',
                ',   economic_capital '
            ) || f_dynamic_result(
                v_result_column_list,
                'economic_capital_transfer',
                ',   economic_capital_transfer '
            ) || f_dynamic_result(
                v_result_column_list,
                'unexpected_transfer_loss',
                ',   unexpected_loss_tr '
            ) || f_dynamic_result(
                v_result_column_list,
                'unexpected_transfer_loss_abs',
                ',   unexpected_loss_tr_abs '
            ) || f_dynamic_result(
                v_result_column_list,
                'correlation_transfer_factor',
                ',   correlation_factor_tr_amount '
            ) || f_dynamic_result(
                v_result_column_list,
                'capital_transfer_multiple',
                ',   capital_multiple_tr_amount '
            ) || f_dynamic_result(
                v_result_column_list,
                'economic_capital_credit',
                ',   economic_capital_credit '
            ) || f_dynamic_result(
                v_result_column_list,
                'unexpected_credit_loss',
                ',   unexpected_loss_cr '
            ) || f_dynamic_result(
                v_result_column_list,
                'unexpected_credit_loss_abs',
                ',   unexpected_loss_cr_abs '
            ) || f_dynamic_result(
                v_result_column_list,
                'correlation_credit_factor',
                ',   correlation_factor_cr_amount '
            ) || f_dynamic_result(
                v_result_column_list,
                'capital_credit_multiple',
                ',   capital_multiple_cr_amount '
            ) || f_dynamic_result(
                v_result_column_list,
                'r_squared_credit_factor',
                ',   r_squared_cr_amount '
            );

        END;
    END IF;

    IF ( v_elec_approach IN (
            'Cred. Risk',
            'IAS',
            'INCAP',
            'INCAPNEW'
        ) ) THEN
        BEGIN
            v_insert_columns_crm := v_insert_columns_crm || f_dynamic_result(
                v_result_column_list,
                'cure_rate',
                ',    cure_rate_amount '
            ) || f_dynamic_result(
                v_result_column_list,
                'direct_cost',
                ',    direct_cost'
            ) || f_dynamic_result(
                v_result_column_list,
                'indirect_cost',
                ',    indirect_cost'
            ) || f_dynamic_result(
                v_result_column_list,
                'e_lim_factor',
                ',    e_lim_factor_amount'
            ) || f_dynamic_result(
                v_result_column_list,
                'e_os_factor',
                ',    e_os_factor_amount'
            ) || f_dynamic_result(
                v_result_column_list,
                'g_factor',
                ',    g_factor_amount'
            ) || f_dynamic_result(
                v_result_column_list,
                'h_factor',
                ',    h_factor_amount'
            ) || f_dynamic_result(
                v_result_column_list,
                'k_factor',
                ',    k_factor_amount'
            ) || f_dynamic_result(
                v_result_column_list,
                'secured_discount_factor',
                ',    secured_discount_factor_amount'
            ) || f_dynamic_result(
                v_result_column_list,
                'unsecured_discount_factor',
                ',    unsecured_discount_factor_amount'
            ) || f_dynamic_result(
                v_result_column_list,
                'secured_recovery_amounts',
                ',    secured_recovery_amounts'
            ) || f_dynamic_result(
                v_result_column_list,
                'unsecured_recovery_amounts',
                ',    unsecured_recovery_amounts'
            ) || f_dynamic_result(
                v_result_column_list,
                'secured_recovery_amounts_discounted',
                ',    secured_recovery_amounts_discounted'
            ) || f_dynamic_result(
                v_result_column_list,
                'unsecured_recovery_amounts_discounted',
                ',    unsecured_recovery_amounts_discounted'
            ) || f_dynamic_result(
                v_result_column_list,
                'original_cover_amount',
                ',    original_cover_amount '
            ) || f_dynamic_result(
                v_result_column_list,
                'somecover_abs',
                ',    original_cover_amount_abs '
            );

        END;
    END IF;

    IF ( v_elec_approach IN (
            'INCAP',
            'INCAPNEW'
        ) ) THEN
        v_insert_columns_crm := v_insert_columns_crm || f_dynamic_result(
            v_result_column_list,
            'residual_value_amount',
            ', residual_value_amount '
        ) || f_dynamic_result(
            v_result_column_list,
            'residual_value_amount_abs',
            ', residual_value_amount_abs '
        ) || f_dynamic_result(
            v_result_column_list,
            'residual_value_risk_weight',
            ', residual_value_risk_weight '
        ) || f_dynamic_result(
            v_result_column_list,
            'residual_value_risk_weight_asset',
            ', residual_value_risk_weight_asset '
        ) || f_dynamic_result(
            v_result_column_list,
            'effective_maturity',
            ', effective_maturity '
        ) || f_dynamic_result(
            v_result_column_list,
            'residual_value_capital',
            ', residual_value_capital '
        );
    END IF;

    v_insert_columns_crm := v_insert_columns_crm || CASE
        WHEN  ( v_report_type != 'ReviewOwner' AND v_report_review_owner_hierarchy_type != 'ROCOD' ) THEN
            f_dynamic_result(
                v_result_column_list,
                'compliance_department',
                ', compliance_department_key '
            )
    END;


    IF v_report_type = 'ReviewOwner' OR ( v_report_type = 'ReviewDate' AND v_report_rd_hierarchy_type IN (
            'CDD',
            'MIFID',
            'BR'
        ) ) THEN
        BEGIN


            v_insert_columns_crm := v_insert_columns_crm || CASE
                WHEN v_report_type = 'ReviewOwner' AND v_report_review_owner_hierarchy_type = 'ROCOD' THEN
                    ',   compliance_department_key '
                ELSE ',   next_review_date ,   review_date_owner_key '
            END;



        END;
    END IF;
  --  dbms_output.put_line('v_insert_columns_c0rm'||v_insert_columns_crm);

    IF ( v_elec_approach <> 'Basel' ) THEN
        BEGIN
            v_aggregation_columns_crm := v_aggregation_columns_crm || f_dynamic_result(
                v_result_column_list,
                'after_coll_regulatory_os_amt',
                ', sum(crm.after_coll_regulatory_os_amt) AS after_coll_regulatory_os_amt'
            ) || f_dynamic_result(
                v_result_column_list,
                'cva_risk_weight',
                ', sum(crm.cva_risk_weight_' || v_elec_suffix || ' * ABS(crm.cva_exposure_' || v_elec_suffix || ') )  AS cva_risk_weight'
            ) || f_dynamic_result(
                v_result_column_list,
                'cva_effective_maturity',
                ', sum(crm.cva_effective_maturity_' || v_elec_suffix || ' * ABS(crm.cva_exposure_' || v_elec_suffix || ' ))  AS cva_effective_maturity'
            ) || f_dynamic_result(
                v_result_column_list,
                'cva_diversification_ratio',
                ', sum(crm.cva_diversification_ratio_' || v_elec_suffix || '* ABS(crm.cva_exposure_' || v_elec_suffix || ') ) AS cva_diversification_ratio'
            ) || f_dynamic_result(
                v_result_column_list,
                'diversified_cva_capital',
                ', sum(crm.diversified_cva_capital_' || v_elec_suffix || ' ) AS diversified_cva_capital'
            ) || f_dynamic_result(
                v_result_column_list,
                'regulatory_outstanding_amount',
                ', sum(crm.regulatory_os_amt) as regulatory_os_amt'
            ) || f_dynamic_result(
                v_result_column_list,
                'total_cva_exposure',
                ', sum(ABS(crm.total_cva_exposure )) as total_cva_exposure'
            ) || f_dynamic_result(
                v_result_column_list,
                'cva_exposure',
                ', sum(ABS(crm.cva_exposure_' || v_elec_suffix || ' )) as cva_exposure'
            ) || f_dynamic_result(
                v_result_column_list,
                'gross_regulatory_os_amt',
                ', sum(crm.gross_regulatory_os_amt)  as gross_regulatory_os_amt'
            );

        END;
    ELSE
        BEGIN
            v_aggregation_columns_crm := v_aggregation_columns_crm || f_dynamic_result(
                v_result_column_list,
                'after_coll_regulatory_os_amt',
                ', NULL AS after_coll_regulatory_os_amt'
            ) || f_dynamic_result(
                v_result_column_list,
                'cva_risk_weight',
                ', NULL AS cva_risk_weight'
            ) || f_dynamic_result(
                v_result_column_list,
                'cva_effective_maturity',
                ', NULL AS cva_effective_maturity'
            ) || f_dynamic_result(
                v_result_column_list,
                'cva_diversification_ratio',
                ', NULL AS cva_diversification_ratio'
            ) || f_dynamic_result(
                v_result_column_list,
                'diversified_cva_capital',
                ', NULL AS diversified_cva_capital'
            ) || f_dynamic_result(
                v_result_column_list,
                'regulatory_outstanding_amount',
                ', NULL as regulatory_os_amt'
            ) || f_dynamic_result(
                v_result_column_list,
                'total_cva_exposure',
                ', NULL as total_cva_exposure'
            ) || f_dynamic_result(
                v_result_column_list,
                'cva_exposure',
                ', NULL as cva_exposure'
            ) || f_dynamic_result(
                v_result_column_list,
                'gross_regulatory_os_amt',
                ', NULL  as gross_regulatory_os_amt'
            );

        END;
    END IF;

    v_aggregation_columns_crm := v_aggregation_columns_crm || f_dynamic_result(
        v_result_column_list,
        'exposure',
        ',     sum(crm.exposure) '
    ) || f_dynamic_result(
        v_result_column_list,
        'max_limit',
        ',     sum(crm.allocated_limit_amt) '
    ) || f_dynamic_result(
        v_result_column_list,
        'max_os',
        ',     sum(crm.maximum_outstanding_amount) '
    ) || f_dynamic_result(
         v_result_column_list,
         'principal_outstanding_amount',
         ',     sum(coalesce(crm.principal_outstanding_amount,crm.maximum_outstanding_amount)) '
    ) || f_dynamic_result(
        v_result_column_list,
        'accrued_interest_amt',
        ',   sum(crm.accrued_interest_amt) '
    )
    ||--ORAMIGTHIRDCATCHUP START
    f_dynamic_result(
        v_result_column_list,
        'gross_carrying_amount',
        ',   sum(crm.gross_carrying_amount) '
    )
       || CASE WHEN v_elec_approach in ('INCAP','INCAPNEW') THEN f_dynamic_result(v_result_column_list, 'accounting_value'  , ',     sum(crm.accounting_value_incap) '     )
               WHEN v_elec_approach_orig in ('Basel')   THEN f_dynamic_result(v_result_column_list, 'accounting_value'  , ',     sum(crm.accounting_value_recap) '     )
               WHEN v_elec_approach_orig in ('Basel4')   THEN f_dynamic_result(v_result_column_list, 'accounting_value'  , ',     sum(crm.accounting_value_recap_b4) '     )
                                                            ELSE f_dynamic_result(v_result_column_list, 'accounting_value'  , ',     sum(crm.accounting_value_ifrs) '     )
          END

    || f_dynamic_result(
        v_result_column_list,
        'commit_undrawn_amount',
        ', sum(crm.commit_undrawn_amount) '
    )     || f_dynamic_result(
        v_result_column_list,
        'uncommit_advised_undrawn_amount',
        ', sum(crm.uncommit_advised_undrawn_amount) '
    )  --ORAMIGTHIRDCATCHUP END
    || f_dynamic_result(
        v_result_column_list,
        'provision_amount',
        ',     sum(crm.provision_amount) '
    )   ---oarmigfirstcatchup--begin
     || f_dynamic_result(
        v_result_column_list,
        'collective_provision_stage_1',
        ',     sum(crm.collective_provision_stage_1) '
    ) || f_dynamic_result(
        v_result_column_list,
        'collective_provision_stage_2',
        ',     sum(crm.collective_provision_stage_2) '
    ) || f_dynamic_result(
        v_result_column_list,
        'collective_provision_stage_3',
        ',     sum(crm.collective_provision_stage_3) '


  --ORAMIGCATCHUP4 start
   ) || f_dynamic_result(
        v_result_column_list,
        'collective_poci',
        ',     sum(crm.collective_poci) '

   ) || f_dynamic_result(
        v_result_column_list,
        'collective_off_balance',
        ',     sum(crm.collective_off_balance) '

   ) || f_dynamic_result(
        v_result_column_list,
        'individual_poci',
        ',     sum(crm.individual_poci) '

   ) || f_dynamic_result(
        v_result_column_list,
        'individual_off_balance',
        ',     sum(crm.individual_off_balance) '

--ORAMIGCATCHUP4 end



    ) || f_dynamic_result(
        v_result_column_list,
        'individual_provision_stage_3',
        ',     sum(crm.individual_provision_stage_3) '
    ) || f_dynamic_result(
        v_result_column_list,
        'off_balance_provision',
        ',     sum(crm.off_balance_provision) '
    ) || f_dynamic_result(
        v_result_column_list,
        'other_provision',
        ',     sum(crm.other_provision) '
    ); ---oramigfirstcatchup--end

    IF ( v_raroc_indicator = 'Y' AND v_raroc_active = 'Y' ) THEN
        BEGIN
            v_aggregation_columns_crm := v_aggregation_columns_crm || f_dynamic_result(
                v_result_column_list,
                'interest_income',
                ',     sum(crm.interest_income_' || v_elec_suffix || ') as interest_income'
            ) || f_dynamic_result(
                v_result_column_list,
                'fees',
                ',     sum(crm.fees_' || v_elec_suffix || ') as fees'
            ) || f_dynamic_result(
                v_result_column_list,
                'employee_benefits',
                ',     sum(crm.employee_benefits_' || v_elec_suffix || ') as employee_benefits'
            ) || f_dynamic_result(
                v_result_column_list,
                'other_income',
                ',     sum(crm.other_income_' || v_elec_suffix || ') as other_income'
            ) || f_dynamic_result(
                v_result_column_list,
                'revenues',
                ',     sum(crm.revenues_' || v_elec_suffix || ') as revenues'
            ) || f_dynamic_result(
                v_result_column_list,
                'risk_adjusted_revenue',
                ',     sum(crm.risk_adjusted_revenue_' || v_elec_suffix || ') as risk_adjusted_revenue'
            ) || f_dynamic_result(
                v_result_column_list,
                'net_cost_economic_capital',
                ',     sum(crm.net_cost_economic_capital_' || v_elec_suffix || ') as net_cost_economic_capital'
            ) || f_dynamic_result(
                v_result_column_list,
                'gross_eva',
                ',     sum(crm.gross_eva_' || v_elec_suffix || ') as gross_eva'
            ) || f_dynamic_result(
                v_result_column_list,
                'required_return',
                ',     sum(crm.required_return_' || v_elec_suffix || ') as required_return'
            ) || f_dynamic_result(
                v_result_column_list,
                'operating_expenses',
                ',     sum(crm.operating_expenses_' || v_elec_suffix || ') as operating_expenses'
            ) || f_dynamic_result(
                v_result_column_list,
                'net_eva',
                ',     sum(crm.net_eva_' || v_elec_suffix || ') as net_eva'
            ) || f_dynamic_result(
                v_result_column_list,
                'economic_capital_adjusted',
                ',     sum(crm.economic_capital_adjusted_' || v_elec_suffix || ') as economic_capital_adjusted'
            );

        END;
    END IF;
--dbms_output.put_line('v_result_column_list'||v_result_column_list);
    IF ( v_elec_approach <> 'Basel' AND v_elec_available = 'Y' AND v_expected_loss_active = 'Y' ) THEN
        BEGIN
            v_aggregation_columns_crm := v_aggregation_columns_crm || f_dynamic_result(
                v_result_column_list,
                'expected_loss',
                ',       sum(crm.expected_loss_' || v_elec_suffix || ') expected_loss '
            ) || f_dynamic_result(
                v_result_column_list,
                'expected_transfer_loss',
                ',       sum(crm.expected_loss_tr_' || v_elec_suffix || ') '
            ) || f_dynamic_result(
                v_result_column_list,
                'transfer_event_probability',
                ',       sum(crm.pd_tr_' || v_elec_suffix || ' * abs(crm.ead_tr_' || v_elec_suffix || ')) '
            ) || f_dynamic_result(
                v_result_column_list,
                'exposure_at_transfer_event',
                ',       sum(crm.ead_tr_' || v_elec_suffix || ') '
            ) || f_dynamic_result(
                v_result_column_list,
                'exposure_at_transfer_event_abs',
                ',   sum(abs(crm.ead_tr_' || v_elec_suffix || ')) '
            ) || f_dynamic_result(
                v_result_column_list,
                'loss_given_transfer_event',
                ',       sum(crm.lgd_tr_' || v_elec_suffix || ' * abs(crm.ead_tr_' || v_elec_suffix || ')) '
            ) || f_dynamic_result(
                v_result_column_list,
                'expected_credit_loss',
                ',       sum(crm.expected_loss_cr_' || v_elec_suffix || ') '
            ) || f_dynamic_result(
                v_result_column_list,
                'probability_of_default',
                ',       sum(crm.pd_cr_' || v_elec_suffix || ' * abs(crm.ead_cr_' || v_elec_suffix || ')) '
            ) || f_dynamic_result(
                v_result_column_list,
                'exposure_at_default',
                ',       sum(crm.ead_cr_' || v_elec_suffix || ') '
            ) || f_dynamic_result(
                v_result_column_list,
                'exposure_at_default_abs',
                ',       sum(abs(crm.ead_cr_' || v_elec_suffix || ')) '
            ) || f_dynamic_result(
                v_result_column_list,
                'weighted_loss_given_default',
                ',       sum(crm.lgd_cr_' || v_elec_suffix || ' * abs(crm.ead_cr_' || v_elec_suffix || ')) '
            ) || f_dynamic_result(
                v_result_column_list,
                'exposure_at_default_model',
                ',       case when min(crm.' || v_column_name_ead_model_key || ') <> max(crm.' || v_column_name_ead_model_key || ')  then 1  else min(crm.'
|| v_column_name_ead_model_key || ') end '
            ) || f_dynamic_result(
                v_result_column_list,
                'loss_given_default_model',
                ',       case when min(crm.lgd_model_key_' || v_elec_suffix || ') <> max(crm.lgd_model_key_' || v_elec_suffix || ')  then 1  else min(crm.lgd_model_key_'
|| v_elec_suffix || ') end '
            );

        END;
    END IF;

    IF ( v_elec_approach  <> 'Basel' AND v_elec_available = 'Y' AND v_economic_capital_active = 'Y' ) THEN
        BEGIN
            v_aggregation_columns_crm := v_aggregation_columns_crm || f_dynamic_result(
                v_result_column_list,
                'economic_capital',
                ',       sum(crm.economic_capital_' || v_elec_suffix || ') economic_capital '
            ) || f_dynamic_result(
                v_result_column_list,
                'economic_capital_transfer',
                ',       sum(crm.economic_capital_tr_' || v_elec_suffix || ') '
            ) || f_dynamic_result(
                v_result_column_list,
                'unexpected_transfer_loss',
                ',       sum(crm.unexpected_loss_tr_' || v_elec_suffix || ') '
            ) || f_dynamic_result(
                v_result_column_list,
                'unexpected_transfer_loss_abs',
                ',       sum(abs(crm.unexpected_loss_tr_' || v_elec_suffix || ')) '
            ) || f_dynamic_result(
                v_result_column_list,
                'correlation_transfer_factor',
                ',       sum(crm.correlation_factor_tr_' || v_elec_suffix || ' * abs(crm.unexpected_loss_tr_' || v_elec_suffix || ')) '
            ) || f_dynamic_result(
                v_result_column_list,
                'capital_transfer_multiple',
                ',       sum(crm.capital_multiple_tr_' || v_elec_suffix || ' * abs(crm.ead_tr_' || v_elec_suffix || ')) '
            ) || f_dynamic_result(
                v_result_column_list,
                'economic_capital_credit',
                ',       sum(crm.economic_capital_cr_' || v_elec_suffix || ') '
            ) || f_dynamic_result(
                v_result_column_list,
                'unexpected_credit_loss',
                ',       sum(crm.unexpected_loss_cr_' || v_elec_suffix || ') '
            ) || f_dynamic_result(
                v_result_column_list,
                'unexpected_credit_loss_abs',
                ',       sum(abs(crm.unexpected_loss_cr_' || v_elec_suffix || ') ) '
            ) ||
                CASE
                    WHEN v_elec_approach NOT IN (
                        'INCAP',
                        'INCAPNEW'
                    ) THEN
                        f_dynamic_result(
                            v_result_column_list,
                            'correlation_credit_factor',
                            ',       sum(crm.correlation_factor_cr_' || v_elec_suffix || ' * abs(crm.unexpected_loss_cr_' || v_elec_suffix || ')) '
                        )
                    ELSE f_dynamic_result(
                        v_result_column_list,
                        'correlation_credit_factor',
                        ',       sum(crm.correlation_factor_cr_' || v_elec_suffix || ' * abs(crm.ead_cr_' || v_elec_suffix || ')) '
                    )
                END
            || f_dynamic_result(
                v_result_column_list,
                'capital_credit_multiple',
                ',       sum(crm.capital_multiple_cr_' || v_elec_suffix || ' * abs(crm.ead_cr_' || v_elec_suffix || ')) '
            ) || f_dynamic_result(
                v_result_column_list,
                'r_squared_credit_factor',
                ',       sum(crm.r_squared_cr_' || v_elec_suffix || ' * abs(ead_cr_' || v_elec_suffix || ') ) '
            );

        END;
    END IF;

    IF ( v_elec_approach IN (
            'Cred. Risk',
            'IAS',
            'INCAP',
            'INCAPNEW'
        ) ) THEN
        BEGIN
            v_aggregation_columns_crm := v_aggregation_columns_crm || f_dynamic_result(
                v_result_column_list,
                'cure_rate',
                ',    sum(crm.cure_rate_' || v_elec_suffix || ' * abs(crm.ead_cr_' || v_elec_suffix || ') ) '
            ) || f_dynamic_result(
                v_result_column_list,
                'direct_cost',
                ',    sum(crm.direct_cost_' || v_elec_suffix || ') '
            ) || f_dynamic_result(
                v_result_column_list,
                'indirect_cost',
                ',    sum(crm.indirect_cost_' || v_elec_suffix || ') '
            ) || f_dynamic_result(
                v_result_column_list,
                'e_lim_factor',
                ',    sum(crm.e_factor_limit_' || v_elec_suffix || ' * abs(crm.ead_cr_' || v_elec_suffix || ') ) '
            ) || f_dynamic_result(
                v_result_column_list,
                'e_os_factor',
                ',    sum(crm.e_factor_os_' || v_elec_suffix || ' * abs(crm.ead_cr_' || v_elec_suffix || ') ) '
            ) || f_dynamic_result(
                v_result_column_list,
                'g_factor',
                ',    sum(crm.g_factor_' || v_elec_suffix || ' * abs(crm.ead_cr_' || v_elec_suffix || ')) '
            ) || f_dynamic_result(
                v_result_column_list,
                'h_factor',
                ',    sum(crm.h_factor_' || v_elec_suffix || ' * abs(crm.original_allocated_cover_amount)) '
            ) || f_dynamic_result(
                v_result_column_list,
                'k_factor',
                ',    sum(crm.k_factor_' || v_elec_suffix || ' * abs(crm.ead_cr_' || v_elec_suffix || ')) '
            ) || f_dynamic_result(
                v_result_column_list,
                'secured_discount_factor',
                ',    sum(crm.secured_discount_factor_' || v_elec_suffix || ' * abs(crm.original_allocated_cover_amount)) '
            ) || f_dynamic_result(
                v_result_column_list,
                'unsecured_discount_factor',
                ',    sum(crm.unsecured_discount_factor_' || v_elec_suffix || ' * abs(crm.ead_cr_' || v_elec_suffix || ')) '
            ) || f_dynamic_result(
                v_result_column_list,
                'secured_recovery_amounts',
                ',    sum(crm.secured_recovery_amount_' || v_elec_suffix || ')'
            ) || f_dynamic_result(
                v_result_column_list,
                'unsecured_recovery_amounts',
                ',    sum(crm.unsecured_recovery_amount_' || v_elec_suffix || ')'
            ) || f_dynamic_result(
                v_result_column_list,
                'secured_recovery_amounts_discounted',
                ',    sum(crm.secured_recovery_amount_discounted_' || v_elec_suffix || ')'
            ) || f_dynamic_result(
                v_result_column_list,
                'unsecured_recovery_amounts_discounted',
                ',    sum(crm.unsecured_recovery_amount_discounted_' || v_elec_suffix || ')'
            ) || f_dynamic_result(
                v_result_column_list,
                'original_cover_amount',
                ',    sum(crm.original_allocated_cover_amount) '
            ) || f_dynamic_result(
                v_result_column_list,
                'somecover_abs',
                ',    sum(abs(crm.original_allocated_cover_amount)) '
            );

        END;
    END IF;

    IF ( v_elec_approach IN (
            'INCAP',
            'INCAPNEW'
        ) ) THEN
        v_aggregation_columns_crm := v_aggregation_columns_crm || f_dynamic_result(
            v_result_column_list,
            'residual_value_amount',
            ', sum(crm.residual_value_amount_cr_' || v_elec_suffix || ' )             as residual_value_amount'
        ) || f_dynamic_result(
            v_result_column_list,
            'residual_value_amount_abs',
            ', sum(abs(crm.residual_value_amount_cr_' || v_elec_suffix || ') )            as residual_value_amount_abs'
        ) || f_dynamic_result(
            v_result_column_list,
            'residual_value_risk_weight',
            ', sum(crm.residual_value_risk_weight_cr_' || v_elec_suffix || ' * abs(crm.residual_value_amount_cr_' || v_elec_suffix || '))    as residual_value_risk_weight'
        ) || f_dynamic_result(
            v_result_column_list,
            'residual_value_risk_weight_asset',
            ', sum(crm.residual_value_risk_weight_cr_' || v_elec_suffix || ' * crm.residual_value_amount_cr_' || v_elec_suffix || ')       as residual_value_risk_weight_asset'
        ) || f_dynamic_result(
            v_result_column_list,
            'effective_maturity',
            ', sum(crm.effective_maturity_cr_' || v_elec_suffix || ' * abs(crm.ead_cr_' || v_elec_suffix || '))                      as effective_maturity'
        ) || f_dynamic_result(
            v_result_column_list,
            'residual_value_capital',
            ', sum(crm.residual_value_capital_cr_' || v_elec_suffix || ')              as residual_value_capital '
        );
    END IF;



    v_aggregation_columns_crm := v_aggregation_columns_crm || CASE
        WHEN  ( v_report_type != 'ReviewOwner' AND v_report_review_owner_hierarchy_type != 'ROCOD' ) AND v_ult_parent_based = 'true' THEN
            f_dynamic_result(
                v_result_column_list,
                'compliance_department',
                ', min(crm.compliance_department_key) '
            )
        WHEN  ( v_report_type != 'ReviewOwner' AND v_report_review_owner_hierarchy_type != 'ROCOD' ) THEN
            f_dynamic_result(
                v_result_column_list,
                'compliance_department',
                ', min(crm.compliance_department_key) '
            )
    END;

    IF v_report_type = 'ReviewOwner' OR ( v_report_type = 'ReviewDate' AND v_report_rd_hierarchy_type IN (
            'CDD',
            'MIFID',
            'BR'
        ) ) THEN
        BEGIN
            v_aggregation_columns_crm := v_aggregation_columns_crm ||
                CASE
                    WHEN ( v_report_type = 'ReviewOwner' AND v_report_review_owner_hierarchy_type = 'ROCD' ) OR ( v_report_type = 'ReviewDate' AND v_report_rd_hierarchy_type
= 'CDD' ) THEN
                        chr(10) || ',max(' || v_cust_sel_table || '.next_review_date_cdd) '
                    WHEN ( v_report_type = 'ReviewOwner' AND v_report_review_owner_hierarchy_type = 'ROMF' ) OR ( v_report_type = 'ReviewDate' AND v_report_rd_hierarchy_type
= 'MIFID' ) THEN
                        chr(10) || ',max(' || v_cust_sel_table || '.next_review_date_mifid) '
                    WHEN ( v_report_type = 'ReviewOwner' AND v_report_review_owner_hierarchy_type = 'ROBR' ) OR ( v_report_type = 'ReviewDate' AND v_report_rd_hierarchy_type
= 'BR' ) THEN
                        chr(10) || ',max(' || v_cust_sel_table || '.next_review_date_br) '
                END
            || CASE
                WHEN v_report_type = 'ReviewOwner' THEN
                    ',   max(' || v_source_table || '.' || v_crm_field || ') '
                ELSE ',   max(' || v_source_table || '.' || v_crm_rd_field || ') '
            END;

        END;
    END IF;

    v_select_columns_crm := v_select_columns_crm || f_dynamic_result(
        v_result_column_list,
        'after_coll_regulatory_os_amt',
        ', sum(after_coll_regulatory_os_amt) AS after_coll_regulatory_os_amt'
    ) || f_dynamic_result(
        v_result_column_list,
        'cva_risk_weight',
        ', sum(cva_risk_weight)  AS cva_risk_weight'
    ) || f_dynamic_result(
        v_result_column_list,
        'cva_effective_maturity',
        ', sum(cva_effective_maturity )  AS cva_effective_maturity'
    ) || f_dynamic_result(
        v_result_column_list,
        'cva_diversification_ratio',
        ', sum(cva_diversification_ratio) AS cva_diversification_ratio'
    ) || f_dynamic_result(
        v_result_column_list,
        'diversified_cva_capital',
        ', sum(diversified_cva_capital) AS diversified_cva_capital'
    ) || f_dynamic_result(
        v_result_column_list,
        'regulatory_outstanding_amount',
        ', sum(regulatory_os_amt) as regulatory_os_amt'
    ) || f_dynamic_result(
        v_result_column_list,
        'total_cva_exposure',
        ', sum(total_cva_exposure) as total_cva_exposure'
    ) || f_dynamic_result(
        v_result_column_list,
        'cva_exposure',
        ', sum(cva_exposure) as cva_exposure'
    ) || f_dynamic_result(
        v_result_column_list,
        'gross_regulatory_os_amt',
        ', sum(gross_regulatory_os_amt)  as gross_regulatory_os_amt'
    ) || f_dynamic_result(
        v_result_column_list,
        'exposure',
        ',     sum(exposure) '
    ) || f_dynamic_result(
        v_result_column_list,
        'expected_outstanding_amount',
        ',     sum(expected_outstanding_amount) '
    ) || f_dynamic_result(
        v_result_column_list,
        'max_limit',
        ',     sum(max_limit) '
    ) || f_dynamic_result(
        v_result_column_list,
        'max_os',
        ',     sum(max_os) '
     ) || f_dynamic_result(
        v_result_column_list,
        'principal_outstanding_amount',
        ',     sum(coalesce(principal_outstanding_amount,max_os)) '

    ) || f_dynamic_result(
        v_result_column_list,
        'accrued_interest_amt',
        ',     sum(accrued_interest_amt) '
        )--ORAMIGTHIRDCATCHUP START
    || f_dynamic_result(
        v_result_column_list,
        'gross_carrying_amount',
        ', sum(gross_carrying_amount) '
    )     || f_dynamic_result(
        v_result_column_list,
        'accounting_value',
        ', sum(accounting_value) '
    )    || f_dynamic_result(
        v_result_column_list,
        'commit_undrawn_amount',
        ', sum(commit_undrawn_amount) '
    )     || f_dynamic_result(
        v_result_column_list,
        'uncommit_advised_undrawn_amount',
        ', sum(uncommit_advised_undrawn_amount) '
    )   --ORAMIGTHIRDCATCHUP END
    ---oramigfirstcatchup--begin
     || f_dynamic_result(
        v_result_column_list,
        'provision_amount',
        ', sum(provision_amount)'
    ) || f_dynamic_result(
        v_result_column_list,
        'collective_provision_stage_1',
        ', sum(collective_provision_stage_1)'
    ) || f_dynamic_result(
        v_result_column_list,
        'collective_provision_stage_2',
        ', sum(collective_provision_stage_2) '
    ) || f_dynamic_result(
        v_result_column_list,
        'collective_provision_stage_3',
        ',     sum(collective_provision_stage_3) '

    --ORAMIGCATCHUP4 start
     ) || f_dynamic_result(
        v_result_column_list,
        'collective_poci',
        ',     sum(collective_poci) '

      ) || f_dynamic_result(
        v_result_column_list,
        'collective_off_balance',
        ',     sum(collective_off_balance) '

     ) || f_dynamic_result(
        v_result_column_list,
        'individual_poci',
        ',     sum(individual_poci) '

     ) || f_dynamic_result(
        v_result_column_list,
        'individual_off_balance',
        ',     sum(individual_off_balance) '


    --ORAMIGCATCHUP4 end


    ) || f_dynamic_result(
        v_result_column_list,
        'individual_provision_stage_3',
        ',     sum(individual_provision_stage_3) '
    ) || f_dynamic_result(
        v_result_column_list,
        'off_balance_provision',
        ',     sum(off_balance_provision) '
    ) || f_dynamic_result(
        v_result_column_list,
        'other_provision',
        ',     sum(other_provision) '
    ); ---oramigfirstcatchup--end

    IF ( v_raroc_indicator = 'Y' AND v_raroc_active = 'Y' ) THEN
        BEGIN
            v_select_columns_crm := v_select_columns_crm || f_dynamic_result(
                v_result_column_list,
                'interest_income',
                ',     sum(interest_income)'
            ) || f_dynamic_result(
                v_result_column_list,
                'fees',
                ',     sum(fees)'
            ) || f_dynamic_result(
                v_result_column_list,
                'employee_benefits',
                ',     sum(employee_benefits)'
            ) || f_dynamic_result(
                v_result_column_list,
                'other_income',
                ',     sum(other_income)'
            ) || f_dynamic_result(
                v_result_column_list,
                'revenues',
                ',     sum(revenues)'
            ) || f_dynamic_result(
                v_result_column_list,
                'risk_adjusted_revenue',
                ',     sum(risk_adjusted_revenue)'
            ) || f_dynamic_result(
                v_result_column_list,
                'net_cost_economic_capital',
                ',     sum(net_cost_economic_capital)'
            ) || f_dynamic_result(
                v_result_column_list,
                'gross_eva',
                ',     sum(gross_eva)'
            ) || f_dynamic_result(
                v_result_column_list,
                'required_return',
                ',     sum(required_return)'
            ) || f_dynamic_result(
                v_result_column_list,
                'operating_expenses',
                ',     sum(operating_expenses)'
            ) || f_dynamic_result(
                v_result_column_list,
                'net_eva',
                ',     sum(net_eva)'
            ) || f_dynamic_result(
                v_result_column_list,
                'economic_capital_adjusted',
                ',     sum(economic_capital_adjusted)'
            );

        END;
    END IF;

    IF ( v_elec_approach  <> 'Basel' AND v_elec_available = 'Y' AND v_expected_loss_active = 'Y' ) THEN
        BEGIN
            v_select_columns_crm := v_select_columns_crm || f_dynamic_result(
                v_result_column_list,
                'expected_loss',
                ',   sum(expected_loss) '
            ) || f_dynamic_result(
                v_result_column_list,
                'expected_transfer_loss',
                ',   sum(expected_transfer_loss) '
            ) || f_dynamic_result(
                v_result_column_list,
                'transfer_event_probability',
                ',   sum(pd_tr_amount)  '
            ) || f_dynamic_result(
                v_result_column_list,
                'exposure_at_transfer_event',
                ',   sum(ead_tr) '
            ) || f_dynamic_result(
                v_result_column_list,
                'exposure_at_transfer_event_abs',
                ',   sum(ead_tr_abs) '
            ) || f_dynamic_result(
                v_result_column_list,
                'loss_given_transfer_event',
                ',   sum(lgd_tr_amount) '
            ) || f_dynamic_result(
                v_result_column_list,
                'expected_credit_loss',
                ',   sum(expected_credit_loss) '
            ) || f_dynamic_result(
                v_result_column_list,
                'probability_of_default',
                ',   sum(pd_cr_amount)  '
            ) || f_dynamic_result(
                v_result_column_list,
                'exposure_at_default',
                ',   sum(ead_cr) '
            ) || f_dynamic_result(
                v_result_column_list,
                'exposure_at_default_abs',
                ',   sum(ead_cr_abs) '
            ) || f_dynamic_result(
                v_result_column_list,
                'weighted_loss_given_default',
                ',   sum(lgd_cr_amount) '
            ) || f_dynamic_result(
                v_result_column_list,
                'exposure_at_default_model',
                ',   case when min(ead_model_key_cr) <> max(ead_model_key_cr) then 1  else min(ead_model_key_cr) end '
            ) || f_dynamic_result(
                v_result_column_list,
                'loss_given_default_model',
                ',   case when min(lgd_model_key_cr) <> max(lgd_model_key_cr) then 1  else min(lgd_model_key_cr) end '
            );

        END;
    END IF;

    IF ( v_elec_approach  <> 'Basel' AND v_elec_available = 'Y' AND v_economic_capital_active = 'Y' ) THEN
        BEGIN
            v_select_columns_crm := v_select_columns_crm || f_dynamic_result(
                v_result_column_list,
                'economic_capital',
                ',   sum(economic_capital) '
            ) || f_dynamic_result(
                v_result_column_list,
                'economic_capital_transfer',
                ',   sum(economic_capital_transfer) '
            ) || f_dynamic_result(
                v_result_column_list,
                'unexpected_transfer_loss',
                ',   sum(unexpected_loss_tr) '
            ) || f_dynamic_result(
                v_result_column_list,
                'unexpected_transfer_loss_abs',
                ',   sum(unexpected_loss_tr_abs) '
            ) || f_dynamic_result(
                v_result_column_list,
                'correlation_transfer_factor',
                ',   sum(correlation_factor_tr_amount) '
            ) || f_dynamic_result(
                v_result_column_list,
                'capital_transfer_multiple',
                ',   sum(capital_multiple_tr_amount) '
            ) || f_dynamic_result(
                v_result_column_list,
                'economic_capital_credit',
                ',   sum(economic_capital_credit) '
            ) || f_dynamic_result(
                v_result_column_list,
                'unexpected_credit_loss',
                ',   sum(unexpected_loss_cr) '
            ) || f_dynamic_result(
                v_result_column_list,
                'unexpected_credit_loss_abs',
                ',   sum(unexpected_loss_cr_abs) '
            ) || f_dynamic_result(
                v_result_column_list,
                'correlation_credit_factor',
                ',   sum(correlation_factor_cr_amount) '
            ) || f_dynamic_result(
                v_result_column_list,
                'capital_credit_multiple',
                ',   sum(capital_multiple_cr_amount) '
            ) || f_dynamic_result(
                v_result_column_list,
                'r_squared_credit_factor',
                ',   sum(r_squared_cr_amount) '
            );

        END;
    END IF;

    IF ( v_elec_approach IN (
            'Cred. Risk',
            'IAS',
            'INCAP',
            'INCAPNEW'
        ) ) THEN
        BEGIN
            v_select_columns_crm := v_select_columns_crm || f_dynamic_result(
                v_result_column_list,
                'cure_rate',
                ',    sum(cure_rate_amount) '
            ) || f_dynamic_result(
                v_result_column_list,
                'direct_cost',
                ',    sum(direct_cost) '
            ) || f_dynamic_result(
                v_result_column_list,
                'indirect_cost',
                ',    sum(indirect_cost) '
            ) || f_dynamic_result(
                v_result_column_list,
                'e_lim_factor',
                ',    sum(e_lim_factor_amount) '
            ) || f_dynamic_result(
                v_result_column_list,
                'e_os_factor',
                ',    sum(e_os_factor_amount) '
            ) || f_dynamic_result(
                v_result_column_list,
                'g_factor',
                ',    sum(g_factor_amount) '
            ) || f_dynamic_result(
                v_result_column_list,
                'h_factor',
                ',    sum(h_factor_amount) '
            ) || f_dynamic_result(
                v_result_column_list,
                'k_factor',
                ',    sum(k_factor_amount) '
            ) || f_dynamic_result(
                v_result_column_list,
                'secured_discount_factor',
                ',    sum(secured_discount_factor_amount) '
            ) || f_dynamic_result(
                v_result_column_list,
                'unsecured_discount_factor',
                ',    sum(unsecured_discount_factor_amount) '
            ) || f_dynamic_result(
                v_result_column_list,
                'secured_recovery_amounts',
                ',    sum(secured_recovery_amounts) '
            ) || f_dynamic_result(
                v_result_column_list,
                'unsecured_recovery_amounts',
                ',    sum(unsecured_recovery_amounts) '
            ) || f_dynamic_result(
                v_result_column_list,
                'secured_recovery_amounts_discounted',
                ',    sum(secured_recovery_amounts_discounted) '
            ) || f_dynamic_result(
                v_result_column_list,
                'unsecured_recovery_amounts_discounted',
                ',    sum(unsecured_recovery_amounts_discounted) '
            ) || f_dynamic_result(
                v_result_column_list,
                'original_cover_amount',
                ',    sum(original_cover_amount) '
            ) || f_dynamic_result(
                v_result_column_list,
                'somecover_abs',
                ',    sum(original_cover_amount_abs) '
            );

        END;
    END IF;

    IF ( v_elec_approach IN (
            'INCAP',
            'INCAPNEW'
        ) ) THEN
        v_select_columns_crm := v_select_columns_crm || f_dynamic_result(
            v_result_column_list,
            'residual_value_amount',
            ', sum(residual_value_amount) '
        )
       --                         + f_dynamic_result(@result_column_list, "residual_value_amount_abs"    , ", sum(abs(residual_value_amount)) ")
         || f_dynamic_result(
            v_result_column_list,
            'residual_value_amount_abs',
            ', sum(residual_value_amount_abs) '
        ) || f_dynamic_result(
            v_result_column_list,
            'residual_value_risk_weight',
            ', sum(residual_value_risk_weight) '
        ) || f_dynamic_result(
            v_result_column_list,
            'residual_value_risk_weight_asset',
            ', sum(residual_value_risk_weight_asset) '
        ) || f_dynamic_result(
            v_result_column_list,
            'effective_maturity',
            ', sum(effective_maturity) '
        ) || f_dynamic_result(
            v_result_column_list,
            'residual_value_capital',
            ', sum(residual_value_capital) '
        );
    END IF;

    IF ( v_report_type != 'ReviewOwner' AND v_report_review_owner_hierarchy_type != 'ROCOD' ) THEN
        BEGIN
            v_select_columns_crm_row := v_select_columns_crm || f_dynamic_result(
                v_result_column_list,
                'compliance_department',
                ', max(compliance_department_key) as compliance_department_key '
            );
            v_select_columns_crm := v_select_columns_crm || f_dynamic_result(
                v_result_column_list,
                'compliance_department',
                ', null as compliance_department_key '
            );
        END;
    ELSE
        BEGIN
            v_select_columns_crm_row := v_select_columns_crm;
        END;
    END IF;

    IF v_report_type = 'ReviewOwner' AND v_report_review_owner_hierarchy_type = 'ROCOD' THEN
        BEGIN
            v_select_columns_review_date := ', compliance_department_key ';
            v_select_columns_review_date := ', compliance_department_key ';
            v_select_columns_review_date_total := ', null as  compliance_department_key ';
            v_group_columns_review_date := ', compliance_department_key ';
        END;
    ELSIF v_report_type = 'ReviewOwner' OR ( v_report_type = 'ReviewDate' AND v_report_rd_hierarchy_type IN (
        'CDD',
        'MIFID',
        'BR'
    ) ) THEN
        BEGIN
            v_select_columns_review_date := ', next_review_date,   review_date_owner_key ';
            v_select_columns_review_date := ', next_review_date,   review_date_owner_key ';
            v_select_columns_review_date_total := ', null as next_review_date, null as  review_date_owner_key ';
            v_group_columns_review_date := ', next_review_date, review_date_owner_key ';
        END;
    ELSE
        BEGIN
            v_select_columns_review_date := ' ';
            v_select_columns_review_date := ' ';
            v_select_columns_review_date_total := ' ';
            v_group_columns_review_date := ' ';
        END;
    END IF;

    IF ( v_elec_available_basel = 'Y' ) THEN
        BEGIN
            v_insert_columns_recap := ' ' || f_dynamic_result(
                v_result_column_list,
                'regulatory_capital',
                ', regulatory_capital '
            ) || f_dynamic_result(
                v_result_column_list,
                'regulatory_probability_of_default',
                ', pd_cr_basel_amount '
            ) || f_dynamic_result(
                v_result_column_list,
                'regulatory_exposure_at_default',
                ', ead_cr_basel '
            ) || f_dynamic_result(
                v_result_column_list,
                'regulatory_exposure_at_default_abs',
                ', ead_cr_basel_abs '
            ) || f_dynamic_result(
                v_result_column_list,
                'regulatory_loss_given_default',
                ', lgd_cr_basel_amount '
            ) || f_dynamic_result(
                v_result_column_list,
                'regulatory_maturity',
                ', maturity_date_cr_basel_amount   '
            ) || f_dynamic_result(
                v_result_column_list,
                'regulatory_risk_weight',
                ', risk_weight_cr_basel_amount  '
            ) || f_dynamic_result(
                v_result_column_list,
                'regulatory_risk_weighted_assets',
                ', risk_weighted_assets_basel '
            ) || f_dynamic_result(
                v_result_column_list,
                'regulatory_asset_class_code',
                ', asset_class_code_basel '
            );

            v_select_columns_recap := ' ' || f_dynamic_result(
                v_result_column_list,
                'regulatory_capital',
                ', sum(regulatory_capital) '
            ) || f_dynamic_result(
                v_result_column_list,
                'regulatory_probability_of_default',
                ', sum(pd_cr_basel_amount) '
            ) || f_dynamic_result(
                v_result_column_list,
                'regulatory_exposure_at_default',
                ', sum(ead_cr_basel) '
            ) || f_dynamic_result(
                v_result_column_list,
                'regulatory_exposure_at_default_abs',
                ', sum(ead_cr_basel_abs) '
            ) || f_dynamic_result(
                v_result_column_list,
                'regulatory_loss_given_default',
                ', sum(lgd_cr_basel_amount) '
            ) || f_dynamic_result(
                v_result_column_list,
                'regulatory_maturity',
                ', sum(maturity_date_cr_basel_amount )  '
            ) || f_dynamic_result(
                v_result_column_list,
                'regulatory_risk_weight',
                ', sum(risk_weight_cr_basel_amount ) '
            ) || f_dynamic_result(
                v_result_column_list,
                'regulatory_risk_weighted_assets',
                ', sum(risk_weighted_assets_basel) '
            ) || f_dynamic_result(
                v_result_column_list,
                'regulatory_asset_class_code',
                ', case when min(asset_class_code_basel) <> max(asset_class_code_basel) then ''MULTI''  else min(asset_class_code_basel) end '
            );

            IF ( v_elec_approach IN (
                    'Basel'
                ) ) THEN
                BEGIN
                    v_insert_columns_recap := v_insert_columns_recap || f_dynamic_result(
                        v_result_column_list,
                        'probability_of_default',
                        ',   pd_cr_amount  '
                    ) || f_dynamic_result(
                        v_result_column_list,
                        'exposure_at_default',
                        ',   ead_cr '
                    ) || f_dynamic_result(
                        v_result_column_list,
                        'exposure_at_default_abs',
                        ',   ead_cr_abs '
                    ) || f_dynamic_result(
                        v_result_column_list,
                        'weighted_loss_given_default',
                        ',   lgd_cr_amount '
                    ) || f_dynamic_result(
                        v_result_column_list,
                        'exposure_at_default_model',
                        ',   ead_model_key_cr '
                    ) || f_dynamic_result(
                        v_result_column_list,
                        'loss_given_default_model',
                        ',   lgd_model_key_cr '
                    ) || f_dynamic_result(
                        v_result_column_list,
                        'economic_capital',
                        ',   economic_capital '
                    ) || f_dynamic_result(
                        v_result_column_list,
                        'economic_capital_credit',
                        ',   economic_capital_credit '
                    ) || f_dynamic_result(
                        v_result_column_list,
                        'cure_rate',
                        ',   cure_rate_amount '
                    ) || f_dynamic_result(
                        v_result_column_list,
                        'direct_cost',
                        ',   direct_cost'
                    ) || f_dynamic_result(
                        v_result_column_list,
                        'indirect_cost',
                        ',   indirect_cost'
                    ) || f_dynamic_result(
                        v_result_column_list,
                        'e_lim_factor',
                        ',   e_lim_factor_amount'
                    ) || f_dynamic_result(
                        v_result_column_list,
                        'e_os_factor',
                        ',   e_os_factor_amount'
                    ) || f_dynamic_result(
                        v_result_column_list,
                        'g_factor',
                        ',   g_factor_amount'
                    ) || f_dynamic_result(
                        v_result_column_list,
                        'h_factor',
                        ',   h_factor_amount'
                    ) || f_dynamic_result(
                        v_result_column_list,
                        'k_factor',
                        ',   k_factor_amount'
                    ) || f_dynamic_result(
                        v_result_column_list,
                        'secured_discount_factor',
                        ',   secured_discount_factor_amount'
                    ) || f_dynamic_result(
                        v_result_column_list,
                        'unsecured_discount_factor',
                        ',   unsecured_discount_factor_amount'
                    ) || f_dynamic_result(
                        v_result_column_list,
                        'secured_recovery_amounts',
                        ',   secured_recovery_amounts'
                    ) || f_dynamic_result(
                        v_result_column_list,
                        'unsecured_recovery_amounts',
                        ',   unsecured_recovery_amounts'
                    ) || f_dynamic_result(
                        v_result_column_list,
                        'secured_recovery_amounts_discounted',
                        ',   secured_recovery_amounts_discounted'
                    ) || f_dynamic_result(
                        v_result_column_list,
                        'unsecured_recovery_amounts_discounted',
                        ',   unsecured_recovery_amounts_discounted'
                    ) || f_dynamic_result(
                        v_result_column_list,
                        'original_cover_amount',
                        ',   original_cover_amount '
                    ) || f_dynamic_result(
                        v_result_column_list,
                        'somecover_abs',
                        ',   original_cover_amount_abs '
                    ) || f_dynamic_result(
                        v_result_column_list,
                        'expected_loss',
                        ',   expected_loss '
                    ) || f_dynamic_result(
                        v_result_column_list,
                        'residual_value_amount',
                        ',   residual_value_amount       '
                    ) || f_dynamic_result(
                        v_result_column_list,
                        'residual_value_amount_abs',
                        ',   residual_value_amount_abs   '
                    ) || f_dynamic_result(
                        v_result_column_list,
                        'residual_value_risk_weight',
                        ',   residual_value_risk_weight  '
                    ) || f_dynamic_result(
                        v_result_column_list,
                        'residual_value_risk_weight_asset',
                        ',   residual_value_risk_weight_asset '
                    ) || f_dynamic_result(
                        v_result_column_list,
                        'effective_maturity',
                        ',   effective_maturity          '
                    ) || f_dynamic_result(
                        v_result_column_list,
                        'residual_value_capital',
                        ',   residual_value_capital  '
                    );

                    v_select_columns_recap := v_select_columns_recap || f_dynamic_result(
                        v_result_column_list,
                        'probability_of_default',
                        ',   sum(pd_cr_amount)  '
                    ) || f_dynamic_result(
                        v_result_column_list,
                        'exposure_at_default',
                        ',   sum(ead_cr) '
                    ) || f_dynamic_result(
                        v_result_column_list,
                        'exposure_at_default_abs',
                        ',   sum(ead_cr_abs) '
                    ) || f_dynamic_result(
                        v_result_column_list,
                        'weighted_loss_given_default',
                        ',   sum(lgd_cr_amount) '
                    ) || f_dynamic_result(
                        v_result_column_list,
                        'exposure_at_default_model',
                        ',   case when min(ead_model_key_cr) <> max(ead_model_key_cr) then 1  else min(ead_model_key_cr) end '
                    ) || f_dynamic_result(
                        v_result_column_list,
                        'loss_given_default_model',
                        ',   case when min(lgd_model_key_cr) <> max(lgd_model_key_cr) then 1  else min(lgd_model_key_cr) end '
                    ) || f_dynamic_result(
                        v_result_column_list,
                        'economic_capital',
                        ',   sum(economic_capital) '
                    ) || f_dynamic_result(
                        v_result_column_list,
                        'economic_capital_credit',
                        ',   sum(economic_capital_credit) '
                    ) || f_dynamic_result(
                        v_result_column_list,
                        'cure_rate',
                        ',   sum(cure_rate_amount) '
                    ) || f_dynamic_result(
                        v_result_column_list,
                        'direct_cost',
                        ',   sum(direct_cost) '
                    ) || f_dynamic_result(
                        v_result_column_list,
                        'indirect_cost',
                        ',   sum(indirect_cost) '
                    ) || f_dynamic_result(
                        v_result_column_list,
                        'e_lim_factor',
                        ',   sum(e_lim_factor_amount) '
                    ) || f_dynamic_result(
                        v_result_column_list,
                        'e_os_factor',
                        ',   sum(e_os_factor_amount) '
                    ) || f_dynamic_result(
                        v_result_column_list,
                        'g_factor',
                        ',   sum(g_factor_amount) '
                    ) || f_dynamic_result(
                        v_result_column_list,
                        'h_factor',
                        ',   sum(h_factor_amount) '
                    ) || f_dynamic_result(
                        v_result_column_list,
                        'k_factor',
                        ',   sum(k_factor_amount) '
                    ) || f_dynamic_result(
                        v_result_column_list,
                        'secured_discount_factor',
                        ',   sum(secured_discount_factor_amount) '
                    ) || f_dynamic_result(
                        v_result_column_list,
                        'unsecured_discount_factor',
                        ',   sum(unsecured_discount_factor_amount) '
                    ) || f_dynamic_result(
                        v_result_column_list,
                        'secured_recovery_amounts',
                        ',   sum(secured_recovery_amounts) '
                    ) || f_dynamic_result(
                        v_result_column_list,
                        'unsecured_recovery_amounts',
                        ',   sum(unsecured_recovery_amounts) '
                    ) || f_dynamic_result(
                        v_result_column_list,
                        'secured_recovery_amounts_discounted',
                        ',   sum(secured_recovery_amounts_discounted) '
                    ) || f_dynamic_result(
                        v_result_column_list,
                        'unsecured_recovery_amounts_discounted',
                        ',   sum(unsecured_recovery_amounts_discounted) '
                    ) || f_dynamic_result(
                        v_result_column_list,
                        'original_cover_amount',
                        ',   sum(original_cover_amount) '
                    ) || f_dynamic_result(
                        v_result_column_list,
                        'somecover_abs',
                        ',   sum(original_cover_amount_abs) '
                    ) || f_dynamic_result(
                        v_result_column_list,
                        'expected_loss',
                        ',   sum(expected_loss) '
                    ) || f_dynamic_result(
                        v_result_column_list,
                        'residual_value_amount',
                        ',   sum(residual_value_amount       ) '
                    ) || f_dynamic_result(
                        v_result_column_list,
                        'residual_value_amount_abs',
                        ',   sum(residual_value_amount_abs   ) '
                    ) || f_dynamic_result(
                        v_result_column_list,
                        'residual_value_risk_weight',
                        ',   sum(residual_value_risk_weight  ) '
                    ) || f_dynamic_result(
                        v_result_column_list,
                        'residual_value_risk_weight_asset',
                        ',   sum(residual_value_risk_weight_asset) '
                    ) || f_dynamic_result(
                        v_result_column_list,
                        'effective_maturity',
                        ',   sum(effective_maturity          ) '
                    ) || f_dynamic_result(
                        v_result_column_list,
                        'residual_value_capital',
                        ',   sum(residual_value_capital  ) '
                    );

                END;
            END IF;

        END;
    END IF;

    utilities.truncate_table('tmp_portfolio_cust');
    utilities.truncate_table('tmp_level_keys');
    utilities.truncate_table('tmp_top_n_codes');
    utilities.truncate_table('tmp_top_n_keys');
   ------------------------------------------------------------------------------
   -- Empty temporary tables
   ------------------------------------------------------------------------------
    utilities.truncate_table('tmp_basel_figures');
    IF ( v_debug = 1 ) THEN
        utilities.performance_log(
            '1.' || v_procedure_name,
            v_time   => v_time
        );
    END IF;

    IF ( v_nr_toppers IS NOT NULL ) THEN
    --Top-n total row has been clicked.
        BEGIN
      ------------------------------------------------------------------------------
      -- When the higher_level_key equals the highest entity of the ING GROEP hierarchy,
      -- all data must be selected by resetting the higher_level_key to NULL
      ------------------------------------------------------------------------------
            BEGIN
                SELECT
                    value
                INTO
                    v_ing_ult_level_code
                FROM
                    dmi_system_configuration
                WHERE
                    name = 'HIGHEST_LEGAL_ENTITY';

            EXCEPTION
                WHEN no_data_found THEN
                    NULL;
                WHEN OTHERS THEN
                    utils.handleerror(
                        sqlcode,
                        sqlerrm
                    );
            END;

            BEGIN
                SELECT
                    ing_legal_entity_key
                INTO
                    v_ing_ult_level_key
                FROM
                    dmi_ing_legal_entity
                WHERE
                    ing_legal_entity_code = v_ing_ult_level_code AND   record_valid_from < v_reporting_date AND   (
                        record_valid_until >= v_reporting_date OR    record_valid_until IS NULL
                    );

            EXCEPTION
                WHEN no_data_found THEN
                    NULL;
                WHEN OTHERS THEN
                    utils.handleerror(
                        sqlcode,
                        sqlerrm
                    );
            END;

            IF ( v_ing_ult_level_key = v_higher_level_key ) THEN
                v_higher_level_key := NULL;
            END IF;
            v_top_n_categories := 'trend_report_top_n';
      -- Maximum used reporting date is the top-N date.
            BEGIN
                SELECT
                    MAX(reporting_date)
                INTO
                    v_max_topn_date
                FROM
                    time_period_tmp;

            EXCEPTION
                WHEN no_data_found THEN
                    NULL;
                WHEN OTHERS THEN
                    utils.handleerror(
                        sqlcode,
                        sqlerrm
                    );
            END;

            IF ( v_based_on IN (
                    'regulatory_risk_weighted_assets',
                    'regulatory_capital',
                    'regulatory_exposure_at_default',
                    'regulatory_risk_weight',
                    'regulatory_maturity'
                ) OR ( v_elec_approach IN ('Basel') AND v_based_on IN (
                    'economic_capital_credit',
                    'loss_given_default',
                    'weighted_loss_given_default',
                    'exposure_at_default',
                    'economic_capital',
                    'expected_loss',
                    'expected_credit_loss',
                    'probability_of_default',
                    'unsecured_recovery_amounts',
                    'secured_recovery_amounts',
                    'indirect_cost',
                    'direct_cost',
                    'cure_rate',
                    'secured_discount_factor',
                    'unsecured_discount_factor',
                    'original_cover_amount',
                    'secured_recovery_amounts_discounted',
                    'unsecured_recovery_amounts_discounted',
                    'residual_value_amount',
                    'residual_value_capital',
                    'residual_value_risk_weight',
                    'residual_value_risk_weight_asset',
                    'effective_maturity'
                ) ) ) THEN
                v_basel_indicator := 'Y';
            ELSE
                v_basel_indicator := 'N';
            END IF;

            BEGIN
                portfolio_report_query(
                    v_hierarchy_level                              => v_hierarchy_level,
                    v_higher_level_key                             => v_higher_level_key,
                    v_reporting_date                               => v_max_topn_date,
                    v_login                                        => v_login,
                    v_authorisation_enabled                        => v_authorisation_enabled,
                    v_authorisation_components                     => v_authorisation_components,
                    v_reporting_date_start                         => v_reporting_date_start,
                    v_report_type                                  => v_report_type,
                    v_ult_parent_based                             => v_ult_parent_based,
                    iv_ct_hierarchy_type                           => v_ct_hierarchy_type,
                    v_customer_id                                  => v_customer_id,
                    v_source_system_id                             => v_source_system_id,
                             -- ,                           @elec_suffix                                = @elec_suffix                         -->> not being used in SP call???
                    v_report_rr_hierarchy_type                     => v_report_rr_hierarchy_type,
                    v_report_it_hierarchy_type                     => v_report_it_hierarchy_type,
                    v_report_customer_type_hierarchy_type          => v_report_customer_type_hierarchy_type,
                    v_report_segmentation_type_hierarchy_type      => v_report_segmentation_type_hierarchy_type,
                    v_report_review_owner_hierarchy_type           => v_report_review_owner_hierarchy_type,
                    v_report_model_exposure_class_hierarchy_type   => v_report_model_exposure_class_hierarchy_type,
                    v_result_column_list                           => v_result_column_list,
                    v_ing_ult_level_key                            => v_ing_ult_level_key,
                    v_tmp_sync_key_indicator                       => 'N',
                    v_topn_indicator                               => 'N',
                    v_report_type_table_join                       => 'I',
                    v_period                                       => v_period,
                    v_debug                                        => v_debug,
                    v_from_statement                               => v_from_statement_top,
                    v_where_clause                                 => v_where_clause_top,
                    v_report_key                                   => v_report_key_top,
                    v_report_type_table                            => v_report_type_table_top,
                    v_basel_indicator                              => v_basel_indicator,
                    v_intercompany_code                            => v_intercompany_code,
                    v_recap_approach                               => v_recap_approach,
                    v_aggregated                                   => v_aggregated,
                    v_regulator_country_code                       => v_regulator_country_code,
                    v_regulator_legal_entity_code                  => v_regulator_legal_entity_code,
                    v_ansi_joins                                   => 1,
                             --v_report_review_owner_hierarchy_type => v_report_review_owner_hierarchy_type, DUPLICATE
                    v_customer_hierarchy_variables                 => v_customer_hierarchy_variables,
                    v_facility_hierarchy_variables                 => v_facility_hierarchy_variables,
                    v_report_code                                  => l_v_report_code,
                    v_report_descr                                 => v_report_descr,
                    v_hierarchy_parent2                            => v_hierarchy_parent2,
                    v_default_code                                 => v_default_code,
                    v_default_descr                                => v_default_descr,
                    v_column_heading                               => v_column_heading
                );
      -- ,                           @recap_hierarchy_variables                  = @recap_hierarchy_variables
            EXCEPTION
                WHEN OTHERS THEN
                    utils.handleerror(
                        sqlcode,
                        sqlerrm
                    );
            END;

      -- EXEC NEW PROC

            BEGIN
                portfolio_reports_topn(
                    v_report_name         => 'portfolio_reports_customer_data',
                    v_reporting_date      => v_max_topn_date,
                    v_based_on            => v_based_on,
                    v_nr_toppers          => v_nr_toppers,
                    v_elec_approach       => v_elec_approach_orig,
                    v_elec_suffix         => v_elec_suffix,
                    v_ult_parent_based    => v_ult_parent_based,
                    v_ct_hierarchy_type   => v_ct_hierarchy_type,
                    v_from_statement      => v_from_statement_top,
                    iv_where_clause       => v_where_clause_top,
                    v_report_code         => v_report_code,
                    v_report_key          => v_report_key_top,
                    v_report_type_table   => v_report_type_table_top,
                    v_debug               => v_debug,
                    v_period              => v_period,
                    v_based_on_total      => v_based_on_total
                );
            EXCEPTION
                WHEN OTHERS THEN
                    utils.handleerror(
                        sqlcode,
                        sqlerrm
                    );
            END;

        END;
    END IF;

    IF ( v_debug = 1 ) THEN
        utilities.performance_log(
            '2.' || v_procedure_name,
            v_time   => v_time
        );
    END IF;
   -- JBK20050720 The higher_level_key is set to NULL if it is zero. From now on we wont know if it was
   -- originally NULL or zero, so we safe the original state for future reference.

    v_higher_level_key_orig := v_higher_level_key;
   -- FL20090903: Workaround to make sure that a join (and not outer join) is performed when
   -- @higher_level_code is populated and @higher_level_key is not
    IF ( v_higher_level_key IS NULL AND v_higher_level_code IS NOT NULL ) THEN
        v_higher_level_key_orig :=-1;
    END IF;

    IF ( v_higher_level_key = 0 ) THEN
        v_higher_level_key := NULL;
    END IF;
    IF ( v_higher_level_key IS NOT NULL OR v_higher_level_code IS NOT NULL ) THEN
        BEGIN
            IF ( v_higher_level_code IS NULL ) THEN
                BEGIN
             -- Initialise @higher_level_code
                    v_statement := 'select ' || v_report_code || '  from ' || v_report_type_table || ' where ' || v_report_key || ' = ' || utils.convert_to_varchar2(
                        v_higher_level_key,
                        10
                    );
                    BEGIN
                    EXECUTE IMMEDIATE v_statement INTO
                        v_higher_level_code;
                    EXCEPTION
                    WHEN no_data_found THEN
                    v_higher_level_code := ' '; --empty code in case key doesn't return a code
                    END;
                    IF ( v_debug = 1 ) THEN
                        utilities.performance_log(
                            '3a.' || v_procedure_name,
                            v_time    => v_time,
                            v_query   => v_statement
                        );
                    END IF;

                    IF ( v_debug = 1 ) THEN
                        utilities.performance_log(
                            '3b.' || v_procedure_name,
                            v_time   => v_time
                        );
                    END IF;

                END;
            END IF;
      -- get keys via code

            IF ( v_higher_level_code = 'ALL' AND v_report_type = 'CorepSecDetail' ) THEN
                BEGIN
                 -- Not aggregated at the moment.
                    v_statement := 'insert into tmp_level_keys(report_key) ' || ' select distinct intermediate_parent_key ' || ' from ' || v_report_type_im_table
|| ' it' || ' where ' || v_report_code || ' = ''ALL'' ';

                    IF ( v_debug = 1 ) THEN
                        utilities.performance_log(
                            '3c.' || v_procedure_name,
                            v_time    => v_time,
                            v_query   => v_statement
                        );

                    END IF;

                    BEGIN
                        EXECUTE IMMEDIATE v_statement;
                        commit;--rajiv
                    EXCEPTION
                        WHEN OTHERS THEN
                            utils.handleerror(
                                sqlcode,
                                sqlerrm
                            );
                    END;

                    IF ( v_debug = 1 ) THEN
                        utilities.performance_log(
                            '3d.' || v_procedure_name,
                            v_time   => v_time
                        );
                    END IF;

                END;

            ELSIF ( v_hierarchy_level IS NULL ) THEN
                BEGIN
            -- Not aggregated at the moment.
                    v_statement := 'insert /*+ APPEND */ into tmp_level_keys(report_key) ' || ' select distinct intermediate_parent_key ' || ' from ' || v_report_type_im_table
|| ' it' || ' where it.intermediate_parent_code = ''' || rtrim(v_higher_level_code) || '''';

                    IF ( v_debug = 1 ) THEN
                        utilities.performance_log(
                            '4a.' || v_procedure_name,
                            v_time    => v_time,
                            v_query   => v_statement
                        );

                    END IF;

                    BEGIN
                        EXECUTE IMMEDIATE v_statement;
                        commit;--rajiv
                    EXCEPTION
                        WHEN OTHERS THEN
                            utils.handleerror(
                                sqlcode,
                                sqlerrm
                            );
                    END;

                    IF ( v_debug = 1 ) THEN
                        utilities.performance_log(
                            '4b.' || v_procedure_name,
                            v_time   => v_time
                        );
                    END IF;

                END;
            ELSIF ( v_report_type IN (
                'ReviewOwner'
            ) ) THEN
                BEGIN
                    v_statement := 'insert /*+ APPEND */ into tmp_level_keys(report_key) ' || ' select distinct intermediate_parent_key ' || ' from   ' || v_report_type_im_table
|| ' it' || ' where  it.hierarchy_level          = ' || utils.convert_to_varchar2(
                        v_hierarchy_level,
                        2
                    ) || ' and    it.intermediate_parent_code = ''' || rtrim(v_higher_level_code) || '''';

                    IF ( v_debug = 1 ) THEN
                        utilities.performance_log(
                            '5A.' || v_procedure_name,
                            v_time    => v_time,
                            v_query   => v_statement
                        );

                    END IF;

                    BEGIN
                        EXECUTE IMMEDIATE v_statement;
                        commit;--rajiv
                    EXCEPTION
                        WHEN OTHERS THEN
                            utils.handleerror(
                                sqlcode,
                                sqlerrm
                            );
                    END;

                    IF ( v_debug = 1 ) THEN
                        utilities.performance_log(
                            '5B.' || v_procedure_name,
                            v_time   => v_time
                        );
                    END IF;

                END;
            ELSE
                BEGIN
                    v_statement := 'insert /*+ APPEND */ into tmp_level_keys(report_key) ' || ' select ' || v_report_key || ' from   ' || v_report_type_im_table || ' it' || ' where  it.hierarchy_level          = '
|| utils.convert_to_varchar2(
                        v_hierarchy_level,
                        2
                    ) || ' and    it.intermediate_parent_code = ''' || rtrim(v_higher_level_code) || '''';

                    IF ( v_debug = 1 ) THEN
                        utilities.performance_log(
                            '5a.' || v_procedure_name,
                            v_time    => v_time,
                            v_query   => v_statement
                        );

                    END IF;

                    BEGIN
                        EXECUTE IMMEDIATE v_statement;
                        commit;--rajiv
                    EXCEPTION
                        WHEN OTHERS THEN
                            utils.handleerror(
                                sqlcode,
                                sqlerrm
                            );
                    END;

                    IF ( v_debug = 1 ) THEN
                        utilities.performance_log(
                            '5b.' || v_procedure_name,
                            v_time   => v_time
                        );
                    END IF;

                END;
            END IF;

        END;
    END IF;

    IF ( v_debug = 1 ) THEN
        utilities.performance_log(
            '6.' || v_procedure_name,
            v_time   => v_time
        );
    END IF;

    IF ( v_elec_available_basel = 'Y' ) THEN
        BEGIN
          --Get the basel data from the dmi_recap_measure table.
            BEGIN
                portfolio_reports_overview_data_basel(
                    iv_hierarchy_level                             => v_hierarchy_level,
                    iv_higher_level_key                            => v_higher_level_key,
                    v_higher_level_code                            => v_higher_level_code,
                    iv_reporting_date                              => v_reporting_date,
                    v_login                                        => v_login,
                    v_reporting_date_start                         => v_reporting_date_start,
                    iv_report_type                                 => v_report_type,
                    v_ult_parent_based                             => v_ult_parent_based,
                    iv_ct_hierarchy_type                           => v_ct_hierarchy_type,
                    v_customer_ult_parent                          => v_customer_ult_parent,
                    v_top_n_categories                             => v_top_n_categories,
                                            --iv_ct_hierarchy_type => v_ct_hierarchy_type, duplicate
                    v_customer_id                                  => v_customer_id,
                    iv_hierarchy_type                              => v_hierarchy_type,
                    v_source_system_id                             => v_source_system_id,
                    iv_elec_approach                               => v_elec_approach_orig,
                    v_report_rr_hierarchy_type                     => v_report_rr_hierarchy_type,
                    v_report_it_hierarchy_type                     => v_report_it_hierarchy_type,
                    v_report_customer_type_hierarchy_type          => v_report_customer_type_hierarchy_type,
                    v_report_segmentation_type_hierarchy_type      => v_report_segmentation_type_hierarchy_type,
                    v_report_review_owner_hierarchy_type           => v_report_review_owner_hierarchy_type,
                    v_report_model_exposure_class_hierarchy_type   => v_report_model_exposure_class_hierarchy_type,
                    v_principal_borrower                           => v_principal_borrower,
                    iv_result_column_list                          => v_result_column_list,
                    v_trend_interval                               => v_trend_interval,

                                            --     ,                                             @nr_of_comparison_dates                     = @nr_of_comparison_dates     -->> not being used ????

                                            --     ,                                             @compare_date                               = @compare_date               -->> not being used !!!
                    v_nr_toppers                                   => v_nr_toppers,

                                            --     ,                                             @based_on                                   = @based_on                   -->> not being used !!!
                    v_grouping_level                               => v_grouping_level,
                    v_debug                                        => v_debug,
                    v_overview_type                                => 'customer',
                    v_use_factor_amounts                           => 'Y',
                    v_period                                       => v_period,
                                           -- v_report_review_owner_hierarchy_type => v_report_review_owner_hierarchy_type, duplicate
                    v_report_rd_hierarchy_type                     => v_report_rd_hierarchy_type,
                    v_intercompany_code                            => v_intercompany_code,
                    v_aggregated                                   => v_aggregated,
                    v_ing_legal_entity_code                        => v_ing_legal_entity_code,
                    v_regulator_legal_entity_code                  => v_regulator_legal_entity_code,
                    v_customer_hierarchy_variables                 => v_customer_hierarchy_variables,
                    v_facility_hierarchy_variables                 => v_facility_hierarchy_variables,
                    v_recap_hierarchy_variables                    => v_recap_hierarchy_variables,
					v_failedsettlement_code                        => v_fst_value
                );
            EXCEPTION
                WHEN OTHERS THEN
                    utils.handleerror(
                        sqlcode,
                        sqlerrm
                    );
            END;

            v_update_statement_basel := 'MERGE INTO tmp_portfolio_cust USING' || '(SELECT tmp.rowid row_id,bf.*
                                      FROM tmp_portfolio_cust tmp,tmp_basel_figures bf
                                      where  tmp.customer_id = bf.customer_id '
||
                CASE
                    WHEN ( v_trend_interval IS NULL ) THEN
                        ' and tmp.risk_category_key     = bf.product_type_key '
                    ELSE ' and tmp.reporting_date_code   = bf.reporting_date_code '
                END
            || ') bf ON(tmp_portfolio_cust.rowid = bf.row_id)' || 'WHEN MATCHED THEN UPDATE ';

            v_update_statement_basel := v_update_statement_basel || ' set    regulatory_capital         = bf.regulatory_capital ' -- How to solve the problem with the set statement ?

             || f_dynamic_result(
                v_result_column_list,
                'regulatory_probability_of_default',
                ',       pd_cr_basel_amount            = bf.regulatory_probability_of_default_amount '
            ) || f_dynamic_result(
                v_result_column_list,
                'regulatory_exposure_at_default',
                ',       ead_cr_basel                  = bf.regulatory_exposure_at_default '
            ) || f_dynamic_result(
                v_result_column_list,
                'regulatory_exposure_at_default_abs',
                ',       ead_cr_basel_abs              = bf.regulatory_exposure_at_default_abs '
            ) || f_dynamic_result(
                v_result_column_list,
                'regulatory_loss_given_default',
                ',       lgd_cr_basel_amount           = bf.regulatory_loss_given_default_amount '
            ) || f_dynamic_result(
                v_result_column_list,
                'regulatory_maturity',
                ',       maturity_date_cr_basel_amount = bf.regulatory_maturity_amount '
            ) || f_dynamic_result(
                v_result_column_list,
                'regulatory_risk_weight',
                ',       risk_weight_cr_basel_amount   = bf.regulatory_risk_weight_amount '
            ) || f_dynamic_result(
                v_result_column_list,
                'regulatory_risk_weighted_assets',
                ',       risk_weighted_assets_basel    = bf.regulatory_risk_weighted_assets '
            ) || f_dynamic_result(
                v_result_column_list,
                'regulatory_asset_class_code',
                ',       asset_class_code_basel        = bf.regulatory_asset_class_code '
            );

            IF ( v_elec_approach IN (
                    'Basel'
                ) ) THEN
                BEGIN
                    v_update_statement_basel := v_update_statement_basel
                 --CVA
                     || f_dynamic_result(
                        v_result_column_list,
                        'cva_risk_weight ',
                        ', cva_risk_weight = bf.cva_risk_weight * abs(bf.cva_exposure)  '
                    ) || f_dynamic_result(
                        v_result_column_list,
                        'cva_effective_maturity',
                        ', cva_effective_maturity = bf.cva_effective_maturity * abs(bf.cva_exposure) '
                    ) || f_dynamic_result(
                        v_result_column_list,
                        'cva_diversification_ratio',
                        ', cva_diversification_ratio = bf.cva_diversification_ratio * abs(bf.cva_exposure) '
                    ) || f_dynamic_result(
                        v_result_column_list,
                        'diversified_cva_capital',
                        ', diversified_cva_capital = bf.diversified_cva_capital '
                    ) || f_dynamic_result(
                        v_result_column_list,
                        'total_cva_exposure',
                        ', total_cva_exposure = bf.total_cva_exposure '
                    ) || f_dynamic_result(
                        v_result_column_list,
                        'cva_exposure',
                        ', cva_exposure = bf.cva_exposure '
                    ) || f_dynamic_result(
                        v_result_column_list,
                        'regulatory_outstanding_amount',
                        ', regulatory_os_amt = bf.regulatory_os_amt '
                    ) || f_dynamic_result(
                        v_result_column_list,
                        'gross_regulatory_os_amt',
                        ', gross_regulatory_os_amt = bf.gross_regulatory_os_amt '
                    ) || f_dynamic_result(
                        v_result_column_list,
                        'after_coll_regulatory_os_amt',
                        ', after_coll_regulatory_os_amt = bf.after_coll_regulatory_os_amt '
                    ) || f_dynamic_result(
                        v_result_column_list,
                        'probability_of_default',
                        ',  pd_cr_amount                  = bf.regulatory_probability_of_default_amount '
                    ) || f_dynamic_result(
                        v_result_column_list,
                        'exposure_at_default',
                        ',  ead_cr                        = bf.regulatory_exposure_at_default '
                    ) || f_dynamic_result(
                        v_result_column_list,
                        'exposure_at_default_abs',
                        ',  ead_cr_abs                    = bf.regulatory_exposure_at_default_abs '
                    ) || f_dynamic_result(
                        v_result_column_list,
                        'weighted_loss_given_default',
                        ',  lgd_cr_amount                 = bf.regulatory_loss_given_default_amount '
                    ) || f_dynamic_result(
                        v_result_column_list,
                        'exposure_at_default_model',
                        ',  ead_model_key_cr              = bf.ead_model_key '
                    ) || f_dynamic_result(
                        v_result_column_list,
                        'loss_given_default_model',
                        ',  lgd_model_key_cr              = bf.lgd_model_key '
                    ) || f_dynamic_result(
                        v_result_column_list,
                        'economic_capital',
                        ',  economic_capital              = bf.regulatory_capital '
                    )
                 --            + f_dynamic_result(@result_column_list, "economic_capital_credit"             , ",  economic_capital_credit       = bf.regulatory_capital " )
                     || f_dynamic_result(
                        v_result_column_list,
                        'economic_capital_credit',
                        ',  economic_capital_credit       = bf.capital_requirement '
                    ) || f_dynamic_result(
                        v_result_column_list,
                        'cure_rate',
                        ' , cure_rate_amount                      = bf.cure_rate_amount '
                    ) || f_dynamic_result(
                        v_result_column_list,
                        'direct_cost',
                        ' , direct_cost                           = bf.direct_cost'
                    ) || f_dynamic_result(
                        v_result_column_list,
                        'indirect_cost',
                        ' , indirect_cost                         = bf.indirect_cost'
                    ) || f_dynamic_result(
                        v_result_column_list,
                        'e_lim_factor',
                        ' , e_lim_factor_amount                   = bf.e_lim_factor_amount'
                    ) || f_dynamic_result(
                        v_result_column_list,
                        'e_os_factor',
                        ' , e_os_factor_amount                    = bf.e_os_factor_amount'
                    ) || f_dynamic_result(
                        v_result_column_list,
                        'g_factor',
                        ' , g_factor_amount                       = bf.g_factor_amount'
                    ) || f_dynamic_result(
                        v_result_column_list,
                        'h_factor',
                        ' , h_factor_amount                       = bf.h_factor_amount'
                    ) || f_dynamic_result(
                        v_result_column_list,
                        'k_factor',
                        ' , k_factor_amount                       = bf.k_factor_amount'
                    ) || f_dynamic_result(
                        v_result_column_list,
                        'secured_discount_factor',
                        ' , secured_discount_factor_amount        = bf.secured_discount_factor_amount'
                    ) || f_dynamic_result(
                        v_result_column_list,
                        'unsecured_discount_factor',
                        ' , unsecured_discount_factor_amount      = bf.unsecured_discount_factor_amount'
                    ) || f_dynamic_result(
                        v_result_column_list,
                        'secured_recovery_amounts',
                        ' , secured_recovery_amounts              = bf.secured_recovery_amounts'
                    ) || f_dynamic_result(
                        v_result_column_list,
                        'unsecured_recovery_amounts',
                        ' , unsecured_recovery_amounts            = bf.unsecured_recovery_amounts'
                    ) || f_dynamic_result(
                        v_result_column_list,
                        'secured_recovery_amounts_discounted',
                        ' , secured_recovery_amounts_discounted   = bf.secured_recovery_amounts_discounted'
                    ) || f_dynamic_result(
                        v_result_column_list,
                        'unsecured_recovery_amounts_discounted',
                        ' , unsecured_recovery_amounts_discounted = bf.unsecured_recovery_amounts_discounted'
                    ) || f_dynamic_result(
                        v_result_column_list,
                        'original_cover_amount',
                        ' , original_cover_amount                 = bf.original_cover_value_amount '
                    ) || f_dynamic_result(
                        v_result_column_list,
                        'somecover_abs',
                        ' , original_cover_amount_abs             = bf.original_cover_value_abs '
                    ) || f_dynamic_result(
                        v_result_column_list,
                        'expected_loss',
                        ',  expected_loss                         = bf.expected_loss '
                    ) || f_dynamic_result(
                        v_result_column_list,
                        'residual_value_amount',
                        ',  residual_value_amount                 = bf.residual_value_amount        '
                    ) || f_dynamic_result(
                        v_result_column_list,
                        'residual_value_amount_abs',
                        ',  residual_value_amount_abs             = bf.residual_value_amount_abs    '
                    ) || f_dynamic_result(
                        v_result_column_list,
                        'residual_value_risk_weight',
                        ',  residual_value_risk_weight            = bf.residual_value_risk_weight   '
                    ) || f_dynamic_result(
                        v_result_column_list,
                        'residual_value_risk_weight_asset',
                        ',  residual_value_risk_weight_asset      = bf.residual_value_risk_weight_asset   '
                    ) || f_dynamic_result(
                        v_result_column_list,
                        'effective_maturity',
                        ',  effective_maturity                    = bf.effective_maturity           '
                    ) || f_dynamic_result(
                        v_result_column_list,
                        'residual_value_capital',
                        ',  residual_value_capital                = bf.residual_value_capital   '
                    );

                END;
            END IF;

        /*  v_update_statement_basel := v_update_statement_basel || ' from   tmp_basel_figures bf ' || ' where  pc.customer_id             = bf.customer_id '
                                   || CASE WHEN ( v_trend_interval IS NULL )
                                           THEN ' and pc.risk_category_key     = bf.product_type_key '
                                      ELSE ' and pc.reporting_date_code   = bf.reporting_date_code '
                                      END ;  */

        END;
    END IF;

    IF ( v_cust_table_name = ' ' ) THEN
        BEGIN
            v_where_clause_all := ' where  1 = 1 ';
            v_from_statement_basic := ' from ' || v_table_name || ' crm, ' || v_report_type_im_table || ' pk ';
          --JBK20050720, If the higher_level_key was originally zero, we have to use a different clause.
          --    Report : Organisation Portfolio -> Rating Owner -> No owner gives a zero as the higher_level_key.
            IF ( ( v_higher_level_key_orig = 0 OR v_higher_level_key_orig IS NULL ) AND v_top_n_categories IS NULL ) THEN
                BEGIN
                    v_where_clause_all := v_where_clause_all || ' and crm.' || v_crm_field || ' =pk.' || v_report_field || ' (+) ';

                    IF ( v_higher_level_key_orig = 0 ) THEN
                        BEGIN
                            v_where_clause_all := v_where_clause_all || ' and  ( crm.' || v_crm_field || ' IS NULL OR crm.' || v_crm_field || ' NOT IN ( select ' || v_report_field
|| ' from ' || v_report_type_im_table;

                            IF ( v_hierarchy_level IS NOT NULL ) THEN
                                BEGIN
                                    v_where_clause_all := v_where_clause_all || ' where parent_hierarchy_level = ' || utils.convert_to_varchar2(
                                        v_hierarchy_level,
                                        2
                                    );
                                END;

                            END IF;

                            v_where_clause_all := v_where_clause_all || ' )) ';
                        END;

                    END IF;

                END;
            ELSE
                BEGIN
                    v_where_clause_all := v_where_clause_all || ' and crm.' || v_crm_field || ' = pk.' || v_report_field || ' ';

                END;
            END IF;

        END;
        --@cust_table_name = ''
    ELSE
        BEGIN
            v_from_statement_basic := ' from ' || v_table_name || ' crm, ' || v_report_type_im_table || ' pk, ' || v_cust_table_name || ' c ';
          --JBK20050825 Changed construction of this part of the where clause.

            IF ( v_higher_level_key IS NULL AND v_top_n_categories IS NULL ) THEN
             --v_join := v_report_field ||'(+) ' ;
              --v_join := ' *= ';
                v_where_clause_all := ' where ' || v_source_table || '.' || v_crm_field || ' = ' || ' pk.' || v_report_field || '(+)';

            ELSE
             --v_join := ' = ';
                v_where_clause_all := ' where ' || v_source_table || '.' || v_crm_field || ' = ' || ' pk.' || v_report_field;
            END IF;

            IF ( v_higher_level_key_orig = 0 ) THEN
                BEGIN
                    v_where_clause_all := v_where_clause_all || ' and ( ' || v_source_table || '.' || v_crm_field || ' is NULL ';

                    IF ( v_hierarchy_level IS NULL ) THEN
                        BEGIN
                            v_where_clause_all := v_where_clause_all || ' or ' || v_source_table || '.' || v_crm_field || ' not in (select ' || v_report_field || ' from ' || v_report_type_im_table
|| ')) ';

                        END;

                    ELSE
                        BEGIN
                            v_where_clause_all := v_where_clause_all || ' or ' || v_source_table || '.' || v_crm_field || ' not in (select ' || v_report_field || ' from ' || v_report_type_im_table
|| ' where parent_hierarchy_level = ' || utils.convert_to_varchar2(
                                v_hierarchy_level,
                                2
                            ) || ' )) ';

                        END;
                    END IF;

                END;
            END IF;

            v_where_clause_all := v_where_clause_all || ' and crm.' || v_hierarchy_parent || '  = c.customer_id ';
            IF ( v_cust_table_name <> 'dmi_search_customer' ) THEN
                BEGIN
                    v_where_clause_all := v_where_clause_all || ' and c.record_valid_from <= ''' || utils.convert_to_varchar2(
                        v_reporting_date,
                        25
                    ) || '''' || ' and (c.record_valid_until > ''' || utils.convert_to_varchar2(
                        v_reporting_date,
                        25
                    ) || '''' || ' OR c.record_valid_until IS NULL) ';

                END;
            END IF;
       --@cust_table_name <> ''

        END;
    END IF;
   --@cust_table_name <> ''


    IF ( v_top_n_categories IS NOT NULL ) THEN
        v_where_clause_all := v_where_clause_all || ' and pk.intermediate_parent_key in (select top_n_key from tmp_top_n_keys) ';
    ELSIF ( v_higher_level_key IS NOT NULL OR v_higher_level_code IS NOT NULL ) THEN
        BEGIN
            v_where_clause_all := v_where_clause_all || ' and pk.intermediate_parent_key IN (SELECT report_key FROM tmp_level_keys) ';
            IF ( v_hierarchy_level IS NOT NULL AND v_report_type IN (
                    'ReviewOwner'
                ) ) THEN
                BEGIN
                    --Add the hierarchy_level filter as all codes appear multiple times for all levels.
                    v_where_clause_all := v_where_clause_all || ' and pk.parent_hierarchy_level (+) = ' || utils.convert_to_varchar2(
                        v_hierarchy_level,
                        2
                    ) || ' ';

                END;
            END IF;
             -- standalone option !!

            IF ( v_hierarchy_level IS NULL AND v_higher_level_code <> 'EXTENTITY' ) AND NOT ( v_higher_level_code = 'ALL' AND v_report_type = 'CorepSecDetail' ) THEN
                v_where_clause_all := v_where_clause_all || ' and pk.intermediate_parent_key = pk.' || v_report_key || ' ';
            END IF;

        END;
    ELSE
        BEGIN
            IF ( v_hierarchy_level IS NULL ) THEN
                BEGIN
                    v_where_clause_all := v_where_clause_all || ' and pk.parent_hierarchy_level = pk.hierarchy_level ';
                    -- standalone option !!
                    IF ( v_higher_level_code <> 'EXTENTITY' ) THEN
                        v_where_clause_all := v_where_clause_all || ' and pk.intermediate_parent_key = pk.' || v_report_key || ' ';
                    END IF;

                END;

            ELSE
                BEGIN
                    v_where_clause_all := v_where_clause_all || ' and pk.parent_hierarchy_level (+) = ' || utils.convert_to_varchar2(
                        v_hierarchy_level,
                        2
                    );
                END;
            END IF;

        END;
    END IF;
   -- D25046: In case of report_type = "EadLgdEC" and @report_model_exposure_class_hierarchy_type = "EC"
   --         add check on record_valid_from, record_valid_until
      IF ( v_report_type = 'EadLgdEC' AND v_report_model_exposure_class_hierarchy_type IN ('EC', 'EM') ) THEN
       IF (v_report_model_exposure_class_hierarchy_type = 'EM') THEN
             v_where_clause_all := REGEXP_REPLACE(v_where_clause_all, 'xxx\.', 'crm.');
             v_where_clause_all := REGEXP_REPLACE(v_where_clause_all, 'crm\.DECODE', 'DECODE');
             v_where_clause_all := REGEXP_REPLACE(v_where_clause_all, 'crm\.TRIM', 'TRIM');
        END IF;
        v_where_clause_all := v_where_clause_all || ' AND (pk.record_valid_from <= '''|| utils.convert_to_varchar2(
--            v_reporting_date,
--           25
--        )||''')  <= ''' || utils.convert_to_varchar2(
            v_reporting_date,
            25
        ) || '''' || '  OR (crm.exposure_class_sa_original_b4 IS NULL AND pk.record_valid_from IS NULL ))  AND (pk.record_valid_until > ''' || utils.convert_to_varchar2(
            v_reporting_date,
            25
        ) || '''' || ' OR pk.record_valid_until IS NULL) ';
        v_where_clause_all := v_where_clause_all
               || ' AND crm.limit_type_indicator in (''S'',''I'')';
    END IF;

   --Add the selection of sync_keys.
   --rajiv
   v_where_clause_all            := v_where_clause_all
                          ||
                 ' and crm.sync_key    = sync_keys.sync_key ';--rajiv

   v_from_statement_basic   := v_from_statement_basic || ',  tmp_sync_key sync_keys ';
    --rajiv
 /* --commented by rajiv
    v_where_clause_all := v_where_clause_all ||
        CASE
            WHEN v_trend_interval IS NOT NULL THEN
                ' and crm.sync_key    = sync_keys.sync_key '
            ELSE ' '
        END
    || ' and (crm.record_valid_from, crm.sync_key)    in (select reporting_date, sync_key from tmp_sync_key) ';

    IF v_trend_interval IS NOT NULL THEN
        BEGIN
            v_from_statement_basic := v_from_statement_basic || ',  tmp_sync_key sync_keys';
        END;
    END IF;
*/
    IF ( v_customer_id IS NOT NULL ) THEN
        BEGIN
            v_from_statement_basic := v_from_statement_basic || ',  aggregated_cust_tmp agct ';
            v_where_clause_all := v_where_clause_all || ' and crm.customer_id = agct.customer_id ';
        END;
    END IF;
   -- ******************** Do we want to see the ultimate parents or borrowers *****************
 
    v_select_statement := 'insert into tmp_portfolio_cust ' || '(     reporting_date_code ' || ',     customer_id ' || ',     record_type ' || ', external_risk_rating_original '|| ', ext_rating_agency_key '||
        CASE
            WHEN v_trend_interval IS NULL THEN
                f_dynamic_result(
                    v_result_column_list,
                    'product_type_key',
                    ', risk_category_key '
                )
        END
    || v_insert_columns_crm || ') ' ||
        CASE
            WHEN v_trend_interval IS NOT NULL THEN
                ' select /*+ NO_INDEX(pk) */ sync_keys.reporting_date_code '
            ELSE ' select /*+ NO_INDEX(pk) ' || CASE WHEN  v_customer_id IS NULL AND length(v_from_statement_cb)>1  THEN ' NO_INDEX(crm)  */ 1 ' ELSE ' */ 1 ' END
        END
    || ',       crm.' || v_hierarchy_parent_display || ',       1 ' ||
     ',       MIN(crm.external_risk_rating_original) , MIN(crm.ext_rating_agency_key)' ||
        CASE
            WHEN v_trend_interval IS NULL THEN
                f_dynamic_result(
                    v_result_column_list,
                    'product_type_key',
                    ', crm.' || v_column_heading || 'risk_category_level1_key '
                )
        END
    || v_aggregation_columns_crm;

    IF ( v_trend_interval IS NOT NULL ) THEN
        BEGIN
            v_group_statement := ' GROUP BY  sync_keys.reporting_date_code, crm.' || v_hierarchy_parent_display || CASE
                WHEN v_trend_interval IS NULL THEN
                    f_dynamic_result(
                        v_result_column_list,
                        'product_type_key',
                        ', crm.' || v_column_heading || 'risk_category_level1_key'
                    )
            END;

        END;
    ELSE
        BEGIN
            v_group_statement := ' GROUP BY  crm.' || v_hierarchy_parent_display || CASE
                WHEN v_trend_interval IS NULL THEN
                    f_dynamic_result(
                        v_result_column_list,
                        'product_type_key',
                        ', crm.' || v_column_heading || 'risk_category_level1_key'
                    )
            END;

        END;
    END IF;

   -- select ult. parents
     IF  ( v_cust_table_name = 'dmi_search_customer' )   THEN
         BEGIN
              v_where_clause_cb := REGEXP_REPLACE(v_where_clause_cb, 'scsel', 'c') || ' AND crm.record_valid_from in ( select /*+ PRECOMPUTE_SUBQUERY */  reporting_date from tmp_sync_key) AND crm.sync_key  in ( select sync_key from tmp_sync_key) ';

              v_fullstatement := v_select_statement || v_from_statement_basic || v_from_statement_fb || v_where_clause_all || v_where_clause_cb|| v_where_clause_fb || v_group_statement;

         END;
     ELSE
      BEGIN
            v_where_clause_cb := v_where_clause_cb || ' AND crm.record_valid_from in ( select /*+ PRECOMPUTE_SUBQUERY */  reporting_date from tmp_sync_key) AND crm.sync_key  in ( select sync_key from tmp_sync_key) ';

            v_fullstatement := v_select_statement || v_from_statement_basic || v_from_statement_cb || v_from_statement_fb || v_where_clause_all || v_where_clause_cb|| v_where_clause_fb || v_group_statement;
      END;
     END IF;


    utilities.show_debug('v_fullstatement from ' || $$plsql_unit || ' ::' || v_fullstatement);
    IF ( v_debug = 1 ) THEN
        utilities.performance_log(
            '7a.' || v_procedure_name,
            v_time    => v_time,
            v_query   => v_fullstatement
        );
    END IF;

    COMMIT;
    DBMS_STATS.gather_table_stats(ownname=>'VORTEX_BUSS_OWNER', tabname=>'tmp_level_keys', force=>true);
    DBMS_STATS.gather_table_stats(ownname=>'VORTEX_BUSS_OWNER', tabname=>'tmp_sync_key', force=>true);
    DBMS_STATS.gather_table_stats(ownname=>'VORTEX_BUSS_OWNER', tabname=>'tmp_user_office_code', force=>true);

    BEGIN
        EXECUTE IMMEDIATE v_fullstatement;
        commit;
        schema_maint.gather_idx_stats('tmp_portfolio_cust');
    EXCEPTION
        WHEN OTHERS THEN
            utils.handleerror(
                sqlcode,
                sqlerrm
            );
    END;

    IF ( v_debug = 1 ) THEN
        utilities.performance_log(
            '7b.' || v_procedure_name,
            v_time   => v_time
        );
    END IF;
   -- calculate nr of facilities in selection

 --only get fac count when requested
 IF (f_dynamic_result(
        v_result_column_list,
        'nr_of_fac',
        '1'
    ) = '1') THEN
    BEGIN

     IF  ( v_cust_table_name = 'dmi_search_customer' )   THEN
      BEGIN
         EXECUTE IMMEDIATE 'select count(crm.facility_key) ' || v_from_statement_basic || v_from_statement_fb || v_where_clause_all|| REGEXP_REPLACE(v_where_clause_cb, 'scsel', 'c') || v_where_clause_fb INTO
            v_nr_facilities;
      END;
     ELSE
      BEGIN
         EXECUTE IMMEDIATE 'select count(crm.facility_key) ' || v_from_statement_basic || v_from_statement_cb || v_from_statement_fb || v_where_clause_all|| v_where_clause_cb || v_where_clause_fb INTO
            v_nr_facilities;
      END;
     END IF;

  -- NULL;
    EXCEPTION
        WHEN OTHERS THEN
            utils.handleerror(
                sqlcode,
                sqlerrm
            );
    END;
   END IF;
commit;
dbms_output.put_line('Line no ' || $$PLSQL_UNIT || ' v_nr_facilities :: '||v_nr_facilities);
    IF ( v_debug = 1 ) THEN
        utilities.performance_log(
            '8.' || v_procedure_name,
            v_time   => v_time
        );
    END IF;
   --Update the basel-data when the basel_switch is on.

    IF ( v_debug = 1 ) THEN
        utilities.performance_log(
            '9a.' || v_procedure_name,
            v_time    => v_time,
            v_query   => v_update_statement_basel
        );
    END IF;

    BEGIN
        EXECUTE IMMEDIATE v_update_statement_basel;
    EXCEPTION
        WHEN OTHERS THEN
            utils.handleerror(
                sqlcode,
                sqlerrm
            );
    END;

    IF ( v_debug = 1 ) THEN
        utilities.performance_log(
            '9b.' || v_procedure_name,
            v_time   => v_time
        );
    END IF;
   ---------------------------------------------------------------------------
   -- Add a total-row for each date that has no rows yet in case of a trend-report.
   ---------------------------------------------------------------------------

    IF ( v_trend_interval IS NOT NULL ) THEN
        BEGIN
            BEGIN
                INSERT INTO tmp_portfolio_cust (
                    reporting_date_code,
                    record_type,
                    customer_id
                )
                    ( SELECT
                        reporting_date_code,
                        -1,
                        -1
                      FROM
                        time_period_tmp
                      WHERE
                        reporting_date_code NOT IN (
                            SELECT DISTINCT
                                reporting_date_code
                            FROM
                                tmp_portfolio_cust
                        )
                    );

            EXCEPTION
                WHEN OTHERS THEN
                    utils.handleerror(
                        sqlcode,
                        sqlerrm
                    );
            END;

        END;
    END IF;
   ------------------------------------------------------------------------------
   -- Clean all data that is not needed due to non-complete EL/EC/Basel data.
   ------------------------------------------------------------------------------

    IF ( v_trend_interval IS NOT NULL ) THEN
        BEGIN
      --Clean data for the dates that do not have complete data.
            IF ( v_elec_approach <> 'Basel' AND v_elec_available = 'Y' ) THEN
         --v_temp NUMBER(1, 0) := 0;
                BEGIN
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
                                    1
                                FROM
                                    time_period_tmp
                                WHERE
                                    elec_available = 'N'
                            );

                    EXCEPTION
                        WHEN no_data_found THEN
                            NULL;
                        WHEN OTHERS THEN
                            utils.handleerror(
                                sqlcode,
                                sqlerrm
                            );
                    END;

                    IF v_temp = 1 THEN
                        BEGIN
                            v_statement := 'update   tmp_portfolio_cust pc ' || 'set  expected_loss             = NULL ' -- How to solve the set statement problem ?
                             || f_dynamic_result(
                                v_result_column_list,
                                'economic_capital',
                                ',    economic_capital             = NULL '
                            ) || f_dynamic_result(
                                v_result_column_list,
                                'expected_transfer_loss',
                                ',    expected_transfer_loss       = NULL '
                            ) || f_dynamic_result(
                                v_result_column_list,
                                'transfer_event_probability',
                                ',    pd_tr_amount                 = NULL '
                            ) || f_dynamic_result(
                                v_result_column_list,
                                'exposure_at_transfer_event',
                                ',    ead_tr                       = NULL '
                            ) || f_dynamic_result(
                                v_result_column_list,
                                'loss_given_transfer_event',
                                ',    lgd_tr_amount                = NULL '
                            ) || f_dynamic_result(
                                v_result_column_list,
                                'economic_capital_transfer',
                                ',    economic_capital_transfer    = NULL '
                            ) || f_dynamic_result(
                                v_result_column_list,
                                'unexpected_transfer_loss',
                                ',    unexpected_loss_tr           = NULL '
                            ) || f_dynamic_result(
                                v_result_column_list,
                                'correlation_transfer_factor',
                                ',    correlation_factor_tr_amount = NULL '
                            ) || f_dynamic_result(
                                v_result_column_list,
                                'capital_transfer_multiple',
                                ',    capital_multiple_tr_amount   = NULL '
                            ) || f_dynamic_result(
                                v_result_column_list,
                                'expected_credit_loss',
                                ',    expected_credit_loss         = NULL '
                            ) || f_dynamic_result(
                                v_result_column_list,
                                'probability_of_default',
                                ',    pd_cr_amount                 = NULL '
                            ) || f_dynamic_result(
                                v_result_column_list,
                                'economic_capital_credit',
                                ',    economic_capital_credit      = NULL '
                            ) || f_dynamic_result(
                                v_result_column_list,
                                'unexpected_credit_loss',
                                ',    unexpected_loss_cr           = NULL '
                            ) || f_dynamic_result(
                                v_result_column_list,
                                'correlation_credit_factor',
                                ',    correlation_factor_cr_amount = NULL '
                            ) || f_dynamic_result(
                                v_result_column_list,
                                'capital_credit_multiple',
                                ',    capital_multiple_cr_amount   = NULL '
                            ) || f_dynamic_result(
                                v_result_column_list,
                                'exposure_at_default',
                                ',    ead_cr                       = NULL '
                            ) || f_dynamic_result(
                                v_result_column_list,
                                'weighted_loss_given_default',
                                ',    lgd_cr_amount                = NULL '
                            ) || f_dynamic_result(
                                v_result_column_list,
                                'r_squared_credit_factor',
                                ',    r_squared_cr_amount          = NULL '
                            ) || 'where reporting_date_code IN (SELECT reporting_date_code FROM time_period_tmp WHERE elec_available = ''N'') ';

                            IF ( v_debug = 1 ) THEN
                                utilities.performance_log(
                                    '10a.' || v_procedure_name,
                                    v_time    => v_time,
                                    v_query   => v_statement
                                );

                            END IF;

                            BEGIN
                                EXECUTE IMMEDIATE v_statement;
                                commit;--rajiv
                            EXCEPTION
                                WHEN OTHERS THEN
                                    utils.handleerror(
                                        sqlcode,
                                        sqlerrm
                                    );
                            END;

                        END;

                    END IF;

                END;
            END IF;

            IF ( v_debug = 1 ) THEN
                utilities.performance_log(
                    '10b.' || v_procedure_name,
                    v_time   => v_time
                );
            END IF;

            IF ( v_elec_available_basel = 'Y' ) THEN
        -- v_temp NUMBER(1, 0) := 0;
                BEGIN
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
                                    1
                                FROM
                                    time_period_tmp
                                WHERE
                                    elec_available_basel = 'N'
                            );

                    EXCEPTION
                        WHEN no_data_found THEN
                            NULL;
                        WHEN OTHERS THEN
                            utils.handleerror(
                                sqlcode,
                                sqlerrm
                            );
                    END;

                    IF v_temp = 1 THEN
                        BEGIN
                            v_statement := 'update   tmp_portfolio_cust ' || 'set regulatory_capital                 = NULL ' -- How to solve the problem with the set statement ?
                             || f_dynamic_result(
                                v_result_column_list,
                                'regulatory_probability_of_default',
                                ',   pd_cr_basel_amount                 = NULL '
                            ) || f_dynamic_result(
                                v_result_column_list,
                                'regulatory_exposure_at_default',
                                ',   ead_cr_basel                       = NULL '
                            ) || f_dynamic_result(
                                v_result_column_list,
                                'regulatory_loss_given_default',
                                ',   lgd_cr_basel_amount                = NULL '
                            ) || f_dynamic_result(
                                v_result_column_list,
                                'regulatory_maturity',
                                ',   maturity_date_cr_basel_amount      = NULL '
                            ) || f_dynamic_result(
                                v_result_column_list,
                                'regulatory_risk_weight',
                                ',   risk_weight_cr_basel_amount        = NULL '
                            ) || f_dynamic_result(
                                v_result_column_list,
                                'regulatory_risk_weighted_assets',
                                ',   risk_weighted_assets_basel         = NULL '
                            ) || f_dynamic_result(
                                v_result_column_list,
                                'regulatory_asset_class_code',
                                ',   asset_class_code_basel             = NULL '
                            );

                            IF ( v_elec_approach IN ('Basel') ) THEN
                                BEGIN
                                    v_statement := v_statement || f_dynamic_result(
                                        v_result_column_list,
                                        'probability_of_default',
                                        ',    pd_cr_amount                 = NULL '
                                    ) || f_dynamic_result(
                                        v_result_column_list,
                                        'exposure_at_default',
                                        ',    ead_cr                       = NULL '
                                    ) || f_dynamic_result(
                                        v_result_column_list,
                                        'weighted_loss_given_default',
                                        ',    lgd_cr_amount                = NULL '
                                    ) || f_dynamic_result(
                                        v_result_column_list,
                                        'exposure_at_default_model',
                                        ',    ead_model_key_cr            = NULL '
                                    ) || f_dynamic_result(
                                        v_result_column_list,
                                        'loss_given_default_model',
                                        ',    lgd_model_key_cr            = NULL '
                                    ) || f_dynamic_result(
                                        v_result_column_list,
                                        'economic_capital',
                                        ',    economic_capital             = NULL '
                                    ) || f_dynamic_result(
                                        v_result_column_list,
                                        'economic_capital_credit',
                                        ',    economic_capital_credit      = NULL '
                                    ) || f_dynamic_result(
                                        v_result_column_list,
                                        'cure_rate',
                                        ',    cure_rate_amount                         = null '
                                    ) || f_dynamic_result(
                                        v_result_column_list,
                                        'direct_cost',
                                        ',    direct_cost                                  = null '
                                    ) || f_dynamic_result(
                                        v_result_column_list,
                                        'indirect_cost',
                                        ',    indirect_cost                            = null '
                                    ) || f_dynamic_result(
                                        v_result_column_list,
                                        'e_lim_factor',
                                        ',    e_lim_factor_amount                  = null '
                                    ) || f_dynamic_result(
                                        v_result_column_list,
                                        'e_os_factor',
                                        ',    e_os_factor_amount                   = null '
                                    ) || f_dynamic_result(
                                        v_result_column_list,
                                        'g_factor',
                                        ',    g_factor_amount                          = null '
                                    ) || f_dynamic_result(
                                        v_result_column_list,
                                        'h_factor',
                                        ',    h_factor_amount                          = null'
                                    ) || f_dynamic_result(
                                        v_result_column_list,
                                        'k_factor',
                                        ',    k_factor_amount                          =  null'
                                    ) || f_dynamic_result(
                                        v_result_column_list,
                                        'secured_discount_factor',
                                        ',    secured_discount_factor_amount              =  null'
                                    ) || f_dynamic_result(
                                        v_result_column_list,
                                        'unsecured_discount_factor',
                                        ',    unsecured_discount_factor_amount            = null'
                                    ) || f_dynamic_result(
                                        v_result_column_list,
                                        'secured_recovery_amounts',
                                        ',    secured_recovery_amounts     = null'
                                    ) || f_dynamic_result(
                                        v_result_column_list,
                                        'unsecured_recovery_amounts',
                                        ',    unsecured_recovery_amounts   = null'
                                    ) || f_dynamic_result(
                                        v_result_column_list,
                                        'secured_recovery_amounts_discounted',
                                        ',    secured_recovery_amounts_discounted     = null'
                                    ) || f_dynamic_result(
                                        v_result_column_list,
                                        'unsecured_recovery_amounts_discounted',
                                        ',    unsecured_recovery_amounts_discounted = null'
                                    ) || f_dynamic_result(
                                        v_result_column_list,
                                        'original_cover_amount',
                                        ',    original_cover_amount              = null '
                                    ) || f_dynamic_result(
                                        v_result_column_list,
                                        'expected_loss',
                                        ',    expected_loss       = NULL '
                                    );

                                END;

                            END IF;

                            v_statement := v_statement || 'where reporting_date_code IN (SELECT reporting_date_code FROM time_period_tmp WHERE elec_available_basel = ''N'') '
;
                            IF ( v_debug = 1 ) THEN
                                utilities.performance_log(
                                    '11a.' || v_procedure_name,
                                    v_time    => v_time,
                                    v_query   => v_statement
                                );
                            END IF;

                            BEGIN
                                EXECUTE IMMEDIATE v_statement;
                                commit;--rajiv
                            EXCEPTION
                                WHEN OTHERS THEN
                                    utils.handleerror(
                                        sqlcode,
                                        sqlerrm
                                    );
                            END;

                        END;

                    END IF;

                END;
            END IF;

        END;
    END IF;

    IF ( v_debug = 1 ) THEN
        utilities.performance_log(
            '11b.' || v_procedure_name,
            v_time   => v_time
        );
    END IF;
   ------------------------------------------------------------------------------
   -- Add total rows
   ------------------------------------------------------------------------------

   v_statement := ' insert into tmp_portfolio_cust '
                                            || ' ( record_type '
                                            || ', reporting_date_code '
                                            || ', risk_category_key '
                                            || ', external_risk_rating_original '
                                            || ', ext_rating_agency_key '
                                            || ', customer_id '
                                            || v_insert_columns_crm
                                            || v_insert_columns_review_date
                                            || v_insert_columns_recap
                                            || ', based_on_total '
                                            || ' ) '
                                            || ' select ' --Add overall total.
                                            || ' -1 '
                                            || ', reporting_date_code '
                                            || ', -1 '
                                            || ', MIN(external_risk_rating_original) '
                                            || ', MIN(ext_rating_agency_key) '
                                            || ', -1 '
                                            || v_select_columns_crm
                                            || v_select_columns_review_date_total
                                            || v_select_columns_recap
                                            || ', sum(based_on_total) '
                                            || ' from tmp_portfolio_cust '
                                            || ' where record_type = 1 '
                                            || ' group by reporting_date_code '
                                            || v_group_columns_review_date;




if(v_trend_interval IS NULL) THEN
        BEGIN
    v_statement := v_statement --Add risk_category column totals.
                                        || ' union all '
                                        || ' select '
                                        || ' ( risk_category_key + 10 ) * -1 '
                                        || ', reporting_date_code '
                                        || ', risk_category_key '
                                        || ', MIN(external_risk_rating_original) '
                                        || ', MIN(ext_rating_agency_key) '
                                        || ', -1 '
                                        || v_select_columns_crm
                                        || v_select_columns_review_date_total
                                        || v_select_columns_recap
                                        || ', sum(based_on_total) '
                                        || ' from tmp_portfolio_cust '
                                        || ' group by risk_category_key '
                                        || ', reporting_date_code '
                                        || v_group_columns_review_date;

    v_statement := v_statement
                                        || ' union all '
                                        || ' select ' --Add row totals.
                                        || ' 1 '
                                        || ', reporting_date_code '
                                        || ', -1 '
                                        || ', MIN(external_risk_rating_original) '
                                        || ', MIN(ext_rating_agency_key) '
                                        || ', customer_id '
                                        || v_select_columns_crm_row
                                        || v_select_columns_review_date
                                        || v_select_columns_recap
                                        || ', sum(based_on_total) '
                                        || ' from tmp_portfolio_cust '
                                        || ' group by reporting_date_code '
                                        || ' , customer_id '
                                        || v_group_columns_review_date;

        END;
    END IF;

    IF ( v_debug = 1 ) THEN
        utilities.performance_log(
            '12a.' || v_procedure_name,
            v_time    => v_time,
            v_query   => v_statement
        );
    END IF;
commit;
    BEGIN
        EXECUTE IMMEDIATE v_statement;
        commit;--rajiv
    EXCEPTION
        WHEN OTHERS THEN
            utils.handleerror(
                sqlcode,
                sqlerrm
            );
    END;

    IF ( v_debug = 1 ) THEN
        utilities.performance_log(
            '12b.' || v_procedure_name,
            v_time   => v_time
        );
    END IF;
   ------------------------------------------------------------------------------
   -- Update report type description (= category description)
   ------------------------------------------------------------------------------

    IF ( v_select_cat_description = 'Y' ) THEN
        BEGIN
            IF ( v_cust_table_name = 'dmi_search_customer' ) THEN
                BEGIN
v_update_statement := 'MERGE INTO tmp_portfolio_cust
                                    USING (SELECT /*+ NO_INDEX(c IDX_DMI_SEARCH_CUSTOMER_CUSTID_LRM_PRM) */ pc.ROWID row_id,im.'
                                    || v_report_descr
                                    || '
                                    FROM
                                    tmp_portfolio_cust pc
                                    JOIN dmi_search_customer c   ON pc.customer_id = c.customer_id
                                    left join (select im.'
                                    || v_report_field
                                    || ',im.parent_hierarchy_level,'
                                    || v_report_descr
                                    || ' from '
                                    || v_report_type_im_table
                                    || ' im join  '
                                    || v_report_type_table
                                    || ' cat on cat.'
                                    || v_report_key
                                    || '  = im.intermediate_parent_key) im
                                    on (c.'
                                    || v_crm_field
                                    || ' = im.'
                                    || v_report_field
                                    || ')
                                    WHERE im.parent_hierarchy_level = '
                                    || utils.convert_to_varchar2(v_hierarchy_level,2)
                                    || ' ) src
                                    ON ( tmp_portfolio_cust.ROWID = src.row_id )
                                    WHEN MATCHED THEN UPDATE SET tmp_portfolio_cust.report_type_descr = src.'
                                    || v_report_descr;

                END;
            ELSE
       --if (@cust_table_name = 'dmi_customer')
                v_debug_msg := $$plsql_line || ' OF PLSQL UNIT ' || $$plsql_unit || '<<v_report_type_im_table>>' || v_report_type_im_table;
                utilities.show_debug(v_debug_msg);
    --industry_type_descr
                BEGIN
v_update_statement := 'MERGE INTO tmp_portfolio_cust
                                            USING (SELECT pc.ROWID row_id,im.'
                                            || v_report_descr
                                            || ' FROM tmp_portfolio_cust pc JOIN dmi_customer c   ON pc.customer_id = c.customer_id left join (select im.'
                                            || v_report_key
                                            || ',im.parent_hierarchy_level,'
                                            || v_report_descr
                                            || ' from '
                                            || v_report_type_im_table
                                            || ' im join  '
                                            || v_report_type_table
                                            || ' cat on cat.'
                                            || v_report_key
                                            || '  = im.intermediate_parent_key) im on (c.'
                                            || v_crm_field
                                            || ' = im.'
                                            || v_report_key
                                            || ') WHERE im.parent_hierarchy_level = '
                                            || utils.convert_to_varchar2(v_hierarchy_level,2)
                                            || ' AND c.record_valid_from <= '''
                                            || utils.convert_to_varchar2(v_reporting_date,25)
                                            || ''''
                                            || 'AND ( c.record_valid_until > '''
                                            || utils.convert_to_varchar2(v_reporting_date,25)
                                            || ''''
                                            || ' OR c.record_valid_until IS NULL )) src ON ( tmp_portfolio_cust.ROWID = src.row_id )
                                            WHEN MATCHED THEN UPDATE SET tmp_portfolio_cust.report_type_descr = src.'
                                            || v_report_descr;
                END;

            END IF;

            v_debug_msg := $$plsql_line || ' OF PLSQL UNIT ' || $$plsql_unit || '<<v_update_statement>>' || v_update_statement;
            utilities.show_debug(v_debug_msg);
            IF ( v_debug = 1 ) THEN
                utilities.performance_log(
                    '13a.' || v_procedure_name,
                    v_time    => v_time,
                    v_query   => v_update_statement
                );
            END IF;

            BEGIN
                EXECUTE IMMEDIATE v_update_statement;
            EXCEPTION
                WHEN OTHERS THEN
                    utils.handleerror(
                        sqlcode,
                        sqlerrm
                    );
            END;

        END;
    END IF;
commit;--rajiv
    IF ( v_debug = 1 ) THEN
        utilities.performance_log(
            '13b.' || v_procedure_name,
            v_time   => v_time
        );
    END IF;

    IF v_report_type = 'ReviewOwner' OR ( v_report_type = 'ReviewDate' AND v_report_rd_hierarchy_type IN (
            'CDD',
            'MIFID',
            'BR'
        ) ) THEN
        BEGIN
            IF v_report_type = 'ReviewOwner' AND v_report_review_owner_hierarchy_type = 'ROCOD' THEN
                BEGIN
                    UPDATE tmp_portfolio_cust
                    SET
                        review_date_owner_key = compliance_department_key;
                     commit;--rajiv
                EXCEPTION
                    WHEN OTHERS THEN
                        utils.handleerror(
                            sqlcode,
                            sqlerrm
                        );
                END;
            END IF;

            BEGIN
                MERGE INTO tmp_portfolio_cust USING ( SELECT
                    tmp.rowid row_id,
                    scs.scs_dept_description scs_dept_description_1,
                    scs2.scs_dept_description scs_dept_description_2
                                                      FROM
                    tmp_portfolio_cust tmp,
                    dmi_scs_department scs,
                    dmi_scs_department scs2
                                                      WHERE
                    tmp.review_date_owner_key = scs.scs_dept_key AND   scs.higher_level_key = scs2.scs_dept_key
                )
                src ON ( tmp_portfolio_cust.rowid = src.row_id )
                WHEN MATCHED THEN UPDATE SET tmp_portfolio_cust.review_owner_dept_descr = src.scs_dept_description_1,
                tmp_portfolio_cust.review_owner_entity_descr = src.scs_dept_description_2;
                commit;--rajiv
            EXCEPTION
                WHEN OTHERS THEN
                    utils.handleerror(
                        sqlcode,
                        sqlerrm
                    );
            END;

        END;
    END IF;

    BEGIN
        MERGE INTO tmp_portfolio_cust USING ( SELECT
            tmp.rowid row_id,
            scs.scs_dept_description
                                              FROM
            tmp_portfolio_cust tmp,
            dmi_scs_department scs
                                              WHERE
            tmp.compliance_department_key = scs.scs_dept_key
        )
        src ON ( tmp_portfolio_cust.rowid = src.row_id )
        WHEN MATCHED THEN UPDATE SET tmp_portfolio_cust.compliance_department = src.scs_dept_description;

    EXCEPTION
        WHEN OTHERS THEN
            utils.handleerror(
                sqlcode,
                sqlerrm
            );
    END;

commit; --rajiv
   --Add the report_date to the table tmp_portfolio_cust.

    BEGIN
        MERGE INTO tmp_portfolio_cust USING ( SELECT
            tmp.rowid row_id,
            tpt.reporting_date
                                              FROM
            tmp_portfolio_cust tmp,
            time_period_tmp tpt
                                              WHERE
            tmp.reporting_date_code = tpt.reporting_date_code
        )
        src ON ( tmp_portfolio_cust.rowid = src.row_id )
        WHEN MATCHED THEN UPDATE SET report_date = src.reporting_date;

    EXCEPTION
        WHEN OTHERS THEN
            utils.handleerror(
                sqlcode,
                sqlerrm
            );
    END;

    commit; --rajiv
   ---------------------------------------------------------------------------
   -- Construct the final result statement.
   ---------------------------------------------------------------------------

    utilities.show_debug('v_trend_interval  ' || $$plsql_unit || ' ::' || v_trend_interval);
    v_select_statement := 'select pc.report_date ' ||
        CASE
           WHEN v_trend_interval IS NOT NULL AND v_trend_interval <> 'B4' THEN ' , cast(to_date(pc.report_date,''dd/mm/yyyy HH:MIAM'') - to_date(''01/01/1970 01:00AM'', ''dd/mm/yyyy HH:MIAM'') as number) * 86400000  as split_column '
           WHEN v_trend_interval IS NOT NULL AND v_trend_interval = 'B4' THEN ' , DECODE(pc.reporting_date_code,1,2,2,1,1) as split_column '
        END
    || ',     pc.record_type ' || ',     pc.customer_id                       as customer_id ' || ',     cast(pc.customer_id as varchar2(30))      as report_code '
|| ',     scp.combined_status                  as customer_combined_status ' || ',     c.customer_name                       as customer_name    '
|| ',     c.country_name                     as customer_country ' || ',     c.city                                as customer_city    '
|| ',     pc.report_type_descr                   as report_descr ' || ',     pc.external_risk_rating_original           as external_risk_rating_original ' || ',     era.description                   as external_risk_rating_agency '|| f_dynamic_result(
        v_result_column_list,
        'product_type_key',
        ',     pc.risk_category_key                 AS product_type_key '
    ) ||
        CASE
            WHEN v_trend_interval IS NULL THEN
                f_dynamic_result(
                    v_result_column_list,
                    'product_type_key',
                    ',     pc.risk_category_key                  AS column_type '
                )
            ELSE ', -1 as column_type '
        END
    || f_dynamic_result(
        v_result_column_list,
        'product_type_descr',
        ',     ft.facility_type_descr               AS product_type_descr '
    ) || ',     c.ing_risk_rating                    AS risk_rating_code ' || ',     c.risk_rating_source                 AS risk_rating_source '
|| ',     c.ins_risk_rating                    AS ins_risk_rating_code ' || ',     c.ins_risk_rating_source             AS ins_risk_rating_source '
|| ',     c.industry_type_descr               AS industry_type ' || ',     c.industry_type_code                AS industry_type_code '
|| ',     scp.parent_account_manager ' || ',     scp.local_account_manager ' || ',     scp.parent_risk_manager ' || ',     scp.local_risk_manager '
   --+ f_dynamic_result(@result_column_list, "regulatory_outstanding_amount"     , ",     pc.regulatory_outstanding_amount     as regulatory_outstanding_amount "     )
     || f_dynamic_result(
        v_result_column_list,
        'expected_outstanding_amount',
        ',     pc.expected_outstanding_amount       as expected_outstanding_amount '
    ) || f_dynamic_result(
        v_result_column_list,
        'max_limit',
        ',     pc.max_limit                         AS max_limit '
    ) || f_dynamic_result(
        v_result_column_list,
        'max_os',
        ',     pc.max_os                            AS max_os '
    ) || f_dynamic_result(
        v_result_column_list,
        'principal_outstanding_amount',
        ',     coalesce(pc.principal_outstanding_amount,pc.max_os)                            AS principal_outstanding_amount '
    )
    || f_dynamic_result(
        v_result_column_list,
        'accrued_interest_amt',
        ',     pc.accrued_interest_amt                            AS accrued_interest_amt '
    )
    || f_dynamic_result(
        v_result_column_list,
        'gross_carrying_amount',
        ',     pc.gross_carrying_amount                            AS gross_carrying_amount '
    )

    || f_dynamic_result(
        v_result_column_list,
        'accounting_value',
        ',     pc.accounting_value                            AS accounting_value '
    )
    || f_dynamic_result(
        v_result_column_list,
        'commit_undrawn_amount',
        ',     pc.commit_undrawn_amount                            AS commit_undrawn_amount '
    )
    || f_dynamic_result(
        v_result_column_list,
        'uncommit_advised_undrawn_amount',
        ',     pc.uncommit_advised_undrawn_amount                            AS uncommit_advised_undrawn_amount '
    )--ORAMIGTHIRDCATCHUP END
    || f_dynamic_result(
        v_result_column_list,
        'exposure',
        ',     pc.exposure                          AS exposure '
    ) || f_dynamic_result(
        v_result_column_list,
        'provision_amount',
        ',     pc.provision_amount                         AS provision_amount '
    )--oramigfirstcatchup--begin
     || f_dynamic_result(
        v_result_column_list,
        'collective_provision_stage_1',
        ',     pc.collective_provision_stage_1                            AS collective_provision_stage_1 '
    ) || f_dynamic_result(
        v_result_column_list,
        'collective_provision_stage_2',
        ',     pc.collective_provision_stage_2                          AS collective_provision_stage_2 '
    ) || f_dynamic_result(
        v_result_column_list,
        'collective_provision_stage_3',
        ',     pc.collective_provision_stage_3                         AS collective_provision_stage_3 '

        --ORAMIGCATCHUP4 start

        ) || f_dynamic_result(
        v_result_column_list,
        'collective_poci',
        ',     pc.collective_poci                         AS collective_poci '

         ) || f_dynamic_result(
        v_result_column_list,
        'collective_off_balance',
        ',     pc.collective_off_balance                         AS collective_off_balance '

         ) || f_dynamic_result(
        v_result_column_list,
        'individual_poci',
        ',     pc.individual_poci                         AS individual_poci '

         ) || f_dynamic_result(
        v_result_column_list,
        'individual_off_balance',
        ',     pc.individual_off_balance                         AS individual_off_balance '


        --ORAMIGCATCHUP4 end
    ) || f_dynamic_result(
        v_result_column_list,
        'individual_provision_stage_3',
        ',     pc.individual_provision_stage_3                            AS individual_provision_stage_3 '
    ) || f_dynamic_result(
        v_result_column_list,
        'off_balance_provision',
        ',     pc.off_balance_provision                          AS off_balance_provision '
    ) || f_dynamic_result(
        v_result_column_list,
        'other_provision',
        ',     pc.other_provision                          AS other_provision '
    );--oramigfirstcatchup--begin

    IF ( ( v_elec_available = 'Y' AND v_elec_approach <> 'Basel' ) OR ( v_elec_available_basel = 'Y' AND v_elec_approach IN ('Basel') ) ) THEN
        BEGIN
            IF ( v_elec_approach IN ('Basel') ) THEN
                BEGIN
                    v_select_statement := v_select_statement || f_dynamic_result(
                        v_result_column_list,
                        'expected_loss',
                        ',     pc.expected_loss AS expected_loss '
                    ) || f_dynamic_result(
                        v_result_column_list,
                        'economic_capital',
                        ',     pc.economic_capital AS economic_capital '
                    ) || f_dynamic_result(
                        v_result_column_list,
                        'expected_transfer_loss',
                        ',     pc.expected_transfer_loss AS expected_transfer_loss '
                    ) || f_dynamic_result(
                        v_result_column_list,
                        'transfer_event_probability',
                        ',     case when pc.ead_tr_abs <> 0 then cast(pc.pd_tr_amount / pc.ead_tr_abs * 100 as number(22,2)) else null end                  AS transfer_event_probability '
                    ) || f_dynamic_result(
                        v_result_column_list,
                        'exposure_at_transfer_event',
                        ',     pc.ead_tr AS exposure_at_transfer_event '
                    ) || f_dynamic_result(
                        v_result_column_list,
                        'loss_given_transfer_event',
                        ',     case when pc.ead_tr_abs <> 0 then cast(pc.lgd_tr_amount / pc.ead_tr_abs * 100 as number(22,2)) else null end                 AS loss_given_transfer_event '
                    ) || f_dynamic_result(
                        v_result_column_list,
                        'weighted_loss_given_transfer_event',
                        ',     pc.lgd_tr_amount           AS  weighted_loss_given_transfer_event '
                    ) || f_dynamic_result(
                        v_result_column_list,
                        'economic_capital_transfer',
                        ',     pc.economic_capital_transfer  AS economic_capital_transfer '
                    ) || f_dynamic_result(
                        v_result_column_list,
                        'unexpected_transfer_loss',
                        ',     pc.unexpected_loss_tr                                                                                                       AS unexpected_transfer_loss '
                    ) || f_dynamic_result(
                        v_result_column_list,
                        'correlation_transfer_factor',
                        ',     case when unexpected_loss_tr_abs <> 0 then cast(pc.correlation_factor_tr_amount / pc.unexpected_loss_tr_abs * 100 as number(22,2)) else null end  AS correlation_transfer_factor '
                    ) || f_dynamic_result(
                        v_result_column_list,
                        'capital_transfer_multiple',
                        ',     case when ead_tr_abs <> 0 then cast(pc.capital_multiple_tr_amount / ead_tr_abs as number(22,2)) else null end                AS capital_transfer_multiple '
                    ) || f_dynamic_result(
                        v_result_column_list,
                        'expected_credit_loss',
                        ',     pc.expected_loss  AS expected_credit_loss '
                    ) || f_dynamic_result(
                        v_result_column_list,
                        'probability_of_default',
                        ',     case when pc.ead_cr_abs <> 0 then cast(pc.pd_cr_amount / pc.ead_cr_abs * 100 as number(11,8)) else null end                  AS probability_of_default '
                    ) || f_dynamic_result(
                        v_result_column_list,
                        'exposure_at_default',
                        ',     pc.ead_cr   AS exposure_at_default '
                    ) || f_dynamic_result(
                        v_result_column_list,
                        'loss_given_default',
                        ',     case when pc.ead_cr_abs <> 0 then cast(pc.lgd_cr_amount / pc.ead_cr_abs * 100 as number(22,2)) else null end                 AS loss_given_default '
                    ) || f_dynamic_result(
                        v_result_column_list,
                        'economic_capital_credit',
                        ',     pc.economic_capital_credit   AS economic_capital_credit '
                    ) || f_dynamic_result(
                        v_result_column_list,
                        'unexpected_credit_loss',
                        ',     pc.unexpected_loss_cr  AS unexpected_credit_loss '
                    ) || f_dynamic_result(
                        v_result_column_list,
                        'correlation_credit_factor',
                        ',     case when unexpected_loss_cr_abs <> 0 then cast(pc.correlation_factor_cr_amount / unexpected_loss_cr_abs * 100 as number(22,2)) else null end     AS correlation_credit_factor '
                    ) || f_dynamic_result(
                        v_result_column_list,
                        'asset_default_correlation',
                        ',     case when ead_cr_abs <> 0 then cast(pc.correlation_factor_cr_amount / ead_cr_abs * 100 as number(22,2)) else null end     AS asset_default_correlation '
                    ) || f_dynamic_result(
                        v_result_column_list,
                        'capital_credit_multiple',
                        ',     case when ead_cr_abs <> 0 then cast(pc.capital_multiple_cr_amount / pc.ead_cr_abs as number(22,2)) else null end             AS capital_credit_multiple '
                    ) || f_dynamic_result(
                        v_result_column_list,
                        'exposure_at_default_model',
                        ',     m1.description  AS exposure_at_default_model '
                    ) || f_dynamic_result(
                        v_result_column_list,
                        'loss_given_default_model',
                        ',     m2.description                                                                                                              AS loss_given_default_model  '
                    ) || f_dynamic_result(
                        v_result_column_list,
                        'r_squared_credit_factor ',
                        ',     case when ead_cr_abs <> 0 then cast(pc.r_squared_cr_amount / pc.ead_cr_abs * 100 as number(22,2)) else null end              AS r_squared_credit_factor'
                    ) || f_dynamic_result(
                        v_result_column_list,
                        'weighted_loss_given_default',
                        ',     pc.lgd_cr_amount                 AS weighted_loss_given_default '
                    );

                END;

            ELSE
                BEGIN
                    v_select_statement := v_select_statement || f_dynamic_result(
                        v_result_column_list,
                        'expected_loss',
                        ',     pc.expected_loss                                                                                                            AS expected_loss '
                    ) || f_dynamic_result(
                        v_result_column_list,
                        'economic_capital',
                        ',     pc.economic_capital                                                                                                         AS economic_capital '
                    ) || f_dynamic_result(
                        v_result_column_list,
                        'expected_transfer_loss',
                        ',     pc.expected_transfer_loss                                                                                                   AS expected_transfer_loss '
                    ) || f_dynamic_result(
                        v_result_column_list,
                        'transfer_event_probability',
                        ',     case when pc.ead_tr_abs <> 0 then cast(pc.pd_tr_amount / pc.ead_tr_abs * 100 as number(22,2)) else null end                      AS transfer_event_probability '
                    ) || f_dynamic_result(
                        v_result_column_list,
                        'exposure_at_transfer_event',
                        ',     pc.ead_tr                                                                                                                   AS exposure_at_transfer_event '
                    ) || f_dynamic_result(
                        v_result_column_list,
                        'loss_given_transfer_event',
                        ',     case when pc.ead_tr_abs <> 0 then cast(pc.lgd_tr_amount / pc.ead_tr_abs * 100 as number(22,2)) else null end                 AS loss_given_transfer_event '
                    ) || f_dynamic_result(
                        v_result_column_list,
                        'weighted_loss_given_transfer_event',
                        ',     pc.lgd_tr_amount                AS  weighted_loss_given_transfer_event '
                    ) || f_dynamic_result(
                        v_result_column_list,
                        'economic_capital_transfer',
                        ',     pc.economic_capital_transfer                                                                                                AS economic_capital_transfer '
                    ) || f_dynamic_result(
                        v_result_column_list,
                        'unexpected_transfer_loss',
                        ',     pc.unexpected_loss_tr                                                                                                       AS unexpected_transfer_loss '
                    ) || f_dynamic_result(
                        v_result_column_list,
                        'correlation_transfer_factor',
                        ',     case when unexpected_loss_tr_abs <> 0 then cast(pc.correlation_factor_tr_amount / pc.unexpected_loss_tr_abs * 100 as number(22,2)) else null end  AS correlation_transfer_factor '
                    ) || f_dynamic_result(
                        v_result_column_list,
                        'capital_transfer_multiple',
                        ',     case when ead_tr_abs <> 0 then cast(pc.capital_multiple_tr_amount / ead_tr_abs as number(22,2)) else null end                AS capital_transfer_multiple '
                    ) || f_dynamic_result(
                        v_result_column_list,
                        'expected_credit_loss',
                        ',     pc.expected_credit_loss                                                                                                     AS expected_credit_loss '
                    ) || f_dynamic_result(
                        v_result_column_list,
                        'probability_of_default',
                        ',     case when pc.ead_cr_abs <> 0 then cast(pc.pd_cr_amount / pc.ead_cr_abs * 100 as number(11,8)) else null end                  AS probability_of_default '
                    ) || f_dynamic_result(
                        v_result_column_list,
                        'exposure_at_default',
                        ',     pc.ead_cr                                                                                                                   AS exposure_at_default '
                    ) || f_dynamic_result(
                        v_result_column_list,
                        'loss_given_default',
                        ',     case when pc.ead_cr_abs <> 0 then cast(pc.lgd_cr_amount / pc.ead_cr_abs * 100 as number(22,2)) else null end                 AS loss_given_default '
                    ) || f_dynamic_result(
                        v_result_column_list,
                        'economic_capital_credit',
                        ',     pc.economic_capital_credit                                                                                                  AS economic_capital_credit '
                    ) || f_dynamic_result(
                        v_result_column_list,
                        'unexpected_credit_loss',
                        ',     pc.unexpected_loss_cr                                                                                                       AS unexpected_credit_loss '
                    ) ||
                        CASE
                            WHEN v_elec_approach NOT IN (
                                'INCAP',
                                'INCAPNEW'
                            ) THEN
                                f_dynamic_result(
                                    v_result_column_list,
                                    'correlation_credit_factor',
                                    ',     case when unexpected_loss_cr_abs <> 0 then cast(pc.correlation_factor_cr_amount / unexpected_loss_cr_abs * 100 as number(22,2)) else null end     AS correlation_credit_factor '
                                ) || f_dynamic_result(
                                    v_result_column_list,
                                    'asset_default_correlation',
                                    ',     null      AS asset_default_correlation'
                                )
                            ELSE f_dynamic_result(
                                v_result_column_list,
                                'asset_default_correlation',
                                ',     case when ead_cr_abs <> 0 then cast(pc.correlation_factor_cr_amount / ead_cr_abs * 100 as number(22,2)) else null end     AS asset_default_correlation '
                            ) || f_dynamic_result(
                                v_result_column_list,
                                'correlation_credit_factor',
                                ',    null      AS correlation_credit_factor'
                            )
                        END
                    || f_dynamic_result(
                        v_result_column_list,
                        'capital_credit_multiple',
                        ',     case when ead_cr_abs <> 0 then cast(pc.capital_multiple_cr_amount / pc.ead_cr_abs as number(22,2)) else null end             AS capital_credit_multiple '
                    ) || f_dynamic_result(
                        v_result_column_list,
                        'exposure_at_default_model',
                        ',     m1.description                                                                                                              AS exposure_at_default_model '
                    ) || f_dynamic_result(
                        v_result_column_list,
                        'loss_given_default_model',
                        ',     m2.description                                                                                                              AS loss_given_default_model  '
                    ) || f_dynamic_result(
                        v_result_column_list,
                        'r_squared_credit_factor ',
                        ',     case when ead_cr_abs <> 0 then cast(pc.r_squared_cr_amount / pc.ead_cr_abs * 100 as number(22,2)) else null end              AS r_squared_credit_factor'
                    ) || f_dynamic_result(
                        v_result_column_list,
                        'weighted_loss_given_default',
                        ',     pc.lgd_cr_amount                 AS weighted_loss_given_default '
                    );
          --@elec_approach <> Basel.

                END;
            END IF;

        END;
    ELSE
        BEGIN
            v_select_statement := v_select_statement || f_dynamic_result(
                v_result_column_list,
                'expected_loss',
                ',     null    AS expected_loss '
            ) || f_dynamic_result(
                v_result_column_list,
                'economic_capital',
                ',     null    AS economic_capital '
            ) || f_dynamic_result(
                v_result_column_list,
                'expected_transfer_loss',
                ',     null    AS expected_transfer_loss '
            ) || f_dynamic_result(
                v_result_column_list,
                'transfer_event_probability',
                ',     null    AS transfer_event_probability '
            ) || f_dynamic_result(
                v_result_column_list,
                'exposure_at_transfer_event',
                ',     null    AS exposure_at_transfer_event '
            ) || f_dynamic_result(
                v_result_column_list,
                'loss_given_transfer_event',
                ',     null    AS loss_given_transfer_event '
            ) || f_dynamic_result(
                v_result_column_list,
                'weighted_loss_given_transfer_event',
                ',     null  AS  weighted_loss_given_transfer_event '
            ) || f_dynamic_result(
                v_result_column_list,
                'economic_capital_transfer',
                ',     null    AS economic_capital_transfer '
            ) || f_dynamic_result(
                v_result_column_list,
                'unexpected_transfer_loss',
                ',     null    AS unexpected_transfer_loss '
            ) || f_dynamic_result(
                v_result_column_list,
                'correlation_transfer_factor',
                ',     null    AS correlation_transfer_factor '
            ) || f_dynamic_result(
                v_result_column_list,
                'capital_transfer_multiple',
                ',     null    AS capital_transfer_multiple '
            ) || f_dynamic_result(
                v_result_column_list,
                'expected_credit_loss',
                ',     null    AS expected_credit_loss '
            ) || f_dynamic_result(
                v_result_column_list,
                'probability_of_default',
                ',     null    AS probability_of_default '
            ) || f_dynamic_result(
                v_result_column_list,
                'exposure_at_default',
                ',     null    AS exposure_at_default '
            ) || f_dynamic_result(
                v_result_column_list,
                'loss_given_default',
                ',     null    AS loss_given_default '
            ) || f_dynamic_result(
                v_result_column_list,
                'economic_capital_credit',
                ',     null    AS economic_capital_credit '
            ) || f_dynamic_result(
                v_result_column_list,
                'unexpected_credit_loss',
                ',     null    AS unexpected_credit_loss '
            ) || f_dynamic_result(
                v_result_column_list,
                'correlation_credit_factor',
                ',     null    AS correlation_credit_factor '
            ) || f_dynamic_result(
                v_result_column_list,
                'asset_default_correlation',
                ',     null    AS asset_default_correlation '
            ) || f_dynamic_result(
                v_result_column_list,
                'capital_credit_multiple',
                ',     null    AS capital_credit_multiple '
            ) || f_dynamic_result(
                v_result_column_list,
                'exposure_at_default',
                ',     null    AS exposure_at_default_model '
            ) || f_dynamic_result(
                v_result_column_list,
                'loss_given_default',
                ',     null    AS loss_given_default_model  '
            ) || f_dynamic_result(
                v_result_column_list,
                'r_squared_credit_factor',
                ',     null    AS r_squared_credit_factor '
            ) || f_dynamic_result(
                v_result_column_list,
                'weighted_loss_given_default',
                ',     null    AS weighted_loss_given_default '
            );

        END;
    END IF;

    IF ( v_elec_available_basel = 'Y' ) THEN
        BEGIN
            v_select_statement := v_select_statement || f_dynamic_result(
                v_result_column_list,
                'regulatory_capital',
                ',     pc.regulatory_capital                AS regulatory_capital '
            ) || f_dynamic_result(
                v_result_column_list,
                'regulatory_probability_of_default',
                ',     case when pc.ead_cr_basel_abs <> 0 then cast(pc.pd_cr_basel_amount / pc.ead_cr_basel_abs * 100 as number(11,8)) else null end             AS regulatory_probability_of_default '
            ) || f_dynamic_result(
                v_result_column_list,
                'regulatory_exposure_at_default',
                ',     pc.ead_cr_basel                      AS regulatory_exposure_at_default '
            ) || f_dynamic_result(
                v_result_column_list,
                'regulatory_loss_given_default',
                ',     case when pc.ead_cr_basel_abs <> 0 then cast(pc.lgd_cr_basel_amount / pc.ead_cr_basel_abs * 100 as number(22,2)) else null end      AS regulatory_loss_given_default '
            ) || f_dynamic_result(
                v_result_column_list,
                'regulatory_maturity',
                ',     case when pc.ead_cr_basel_abs <> 0 then cast(pc.maturity_date_cr_basel_amount / pc.ead_cr_basel_abs as number(22,2)) else null end  AS regulatory_maturity '
            ) || f_dynamic_result(
                v_result_column_list,
                'regulatory_risk_weight',
                ',     case when pc.ead_cr_basel_abs <> 0 then cast(pc.risk_weight_cr_basel_amount / pc.ead_cr_basel_abs as number(22,2)) else null end    AS regulatory_risk_weight '
            ) || f_dynamic_result(
                v_result_column_list,
                'regulatory_risk_weighted_assets',
                ',     pc.risk_weighted_assets_basel        AS regulatory_risk_weighted_assets '
            ) || f_dynamic_result(
                v_result_column_list,
                'regulatory_asset_class_code',
                ',     pc.asset_class_code_basel            AS regulatory_asset_class_code'
            ) ||
                CASE

            WHEN v_recap_approach  IN ('FIRB','AIRB','Official') AND v_elec_approach_orig = 'Basel4' THEN
            f_dynamic_result(
                v_result_column_list,
                'regulatory_asset_class_descr',
                ',     ac.basel4_exposure_class_irb_descr                 AS regulatory_asset_class_descr'
            )
            WHEN v_recap_approach = 'SA' AND v_elec_approach_orig = 'Basel' THEN
            f_dynamic_result(
                v_result_column_list,
                'regulatory_asset_class_descr',
                ',     ac.exposure_class_sa_descr                 AS regulatory_asset_class_descr'
            )
            WHEN v_recap_approach = 'SA' AND v_elec_approach_orig = 'Basel4' THEN
            f_dynamic_result(
                v_result_column_list,
                'regulatory_asset_class_descr',
                ',     ac.basel4_exposure_class_sa_descr                 AS regulatory_asset_class_descr'
            )
            ELSE
                    f_dynamic_result(
                v_result_column_list,
                'regulatory_asset_class_descr',
                ',     ac.exposure_class_irb_descr                 AS regulatory_asset_class_descr'
            )
            END;

        END;
    ELSE
        BEGIN
            v_select_statement := v_select_statement || f_dynamic_result(
                v_result_column_list,
                'regulatory_capital',
                ',   null  AS regulatory_capital '
            ) || f_dynamic_result(
                v_result_column_list,
                'regulatory_probability_of_default',
                ',   null  AS regulatory_probability_of_default '
            ) || f_dynamic_result(
                v_result_column_list,
                'regulatory_exposure_at_default',
                ',   null  AS regulatory_exposure_at_default '
            ) || f_dynamic_result(
                v_result_column_list,
                'regulatory_loss_given_default',
                ',   null  AS regulatory_loss_given_default '
            ) || f_dynamic_result(
                v_result_column_list,
                'regulatory_maturity',
                ',   null  AS regulatory_maturity '
            ) || f_dynamic_result(
                v_result_column_list,
                'regulatory_risk_weight',
                ',   null  AS regulatory_risk_weight '
            ) || f_dynamic_result(
                v_result_column_list,
                'regulatory_risk_weighted_assets',
                ',   null  AS regulatory_risk_weighted_assets '
            ) || f_dynamic_result(
                v_result_column_list,
                'regulatory_asset_class_code',
                ',   null  AS regulatory_asset_class_code'
            ) || f_dynamic_result(
                v_result_column_list,
                'regulatory_asset_class_descr',
                ',   null  AS regulatory_asset_class_descr'
            );

        END;
    END IF;

    IF ( v_elec_approach = 'INCAP' OR v_elec_approach = 'INCAPNEW' OR ( v_elec_approach IN ('Basel') AND v_elec_available_basel = 'Y' ) ) THEN
        BEGIN
            v_select_statement := v_select_statement || f_dynamic_result(
                v_result_column_list,
                'residual_value_amount',
                ',  pc.residual_value_amount                 AS residual_value_amount        '
            ) || f_dynamic_result(
                v_result_column_list,
                'residual_value_risk_weight',
                ',  case when residual_value_amount_abs <> 0 then cast(pc.residual_value_risk_weight / pc.residual_value_amount_abs  as number(13,8))*100 else null end AS residual_value_risk_weight   '
            ) || f_dynamic_result(
                v_result_column_list,
                'residual_value_risk_weight_asset',
                ',  pc.residual_value_risk_weight_asset      AS residual_value_risk_weight_asset '
            ) || f_dynamic_result(
                v_result_column_list,
                'effective_maturity',
                ',  case when ead_cr_abs <> 0 then cast(pc.effective_maturity / pc.ead_cr_abs as number(20,8)) else null end                        AS effective_maturity           '
            ) || f_dynamic_result(
                v_result_column_list,
                'residual_value_capital',
                ',  pc.residual_value_capital                AS residual_value_capital   '
            );

        END;
    ELSE
        BEGIN
            v_select_statement := v_select_statement || f_dynamic_result(
                v_result_column_list,
                'residual_value_amount',
                ',  null   AS  residual_value_amount        '
            ) || f_dynamic_result(
                v_result_column_list,
                'residual_value_risk_weight',
                ',  null   AS  residual_value_risk_weight   '
            ) || f_dynamic_result(
                v_result_column_list,
                'residual_value_risk_weight_asset',
                ',  null   AS  residual_value_risk_weight_asset '
            ) || f_dynamic_result(
                v_result_column_list,
                'effective_maturity',
                ',  null   AS  effective_maturity           '
            ) || f_dynamic_result(
                v_result_column_list,
                'residual_value_capital',
                ',  null   AS  residual_value_capital   '
            );

        END;
    END IF;

    v_select_statement := v_select_statement || f_dynamic_result(
        v_result_column_list,
        'nr_of_fac',
        ',  ' || utils.convert_to_varchar2(
            v_nr_facilities,
            30
        ) || ' AS nr_of_fac '
    );

    IF ( v_raroc_indicator = 'Y' AND v_raroc_active = 'Y' ) THEN
        BEGIN
            v_select_statement := v_select_statement || f_dynamic_result(
                v_result_column_list,
                'interest_income',
                ',     pc.interest_income as interest_income '
            ) || f_dynamic_result(
                v_result_column_list,
                'fees',
                ',     pc.fees as fees '
            ) || f_dynamic_result(
                v_result_column_list,
                'employee_benefits',
                ',     pc.employee_benefits as employee_benefits '
            ) || f_dynamic_result(
                v_result_column_list,
                'other_income',
                ',     pc.other_income as other_income '
            ) || f_dynamic_result(
                v_result_column_list,
                'revenues',
                ',     pc.revenues as revenues '
            ) || f_dynamic_result(
                v_result_column_list,
                'risk_adjusted_revenue',
                ',     pc.risk_adjusted_revenue as risk_adjusted_revenue '
            ) || f_dynamic_result(
                v_result_column_list,
                'net_cost_economic_capital',
                ',     pc.net_cost_economic_capital as net_cost_of_ec'
            ) || f_dynamic_result(
                v_result_column_list,
                'gross_eva',
                ',     pc.gross_eva as gross_eva '
            ) || f_dynamic_result(
                v_result_column_list,
                'gross_raroc',
                ',     case when pc.economic_capital_adjusted = 0 then null else (pc.gross_eva + pc.required_return) / pc.economic_capital_adjusted * 100 end as gross_raroc '
            ) || f_dynamic_result(
                v_result_column_list,
                'operating_expenses',
                ',     pc.operating_expenses as operating_expenses '
            ) || f_dynamic_result(
                v_result_column_list,
                'net_eva',
                ',     pc.net_eva as net_eva '
            ) || f_dynamic_result(
                v_result_column_list,
                'net_raroc',
                ',       case when pc.economic_capital_adjusted = 0 then null else (pc.net_eva + pc.required_return) / pc.economic_capital_adjusted * 100 end as net_raroc '
            );

        END;
    ELSIF ( v_raroc_indicator = 'Y' ) THEN
        BEGIN
            v_select_statement := v_select_statement || f_dynamic_result(
                v_result_column_list,
                'interest_income',
                ',         null as interest_income'
            ) || f_dynamic_result(
                v_result_column_list,
                'fees',
                ',         null as fees'
            ) || f_dynamic_result(
                v_result_column_list,
                'employee_benefits',
                ',         null as employee_benefits'
            ) || f_dynamic_result(
                v_result_column_list,
                'other_income',
                ',         null as other_income'
            ) || f_dynamic_result(
                v_result_column_list,
                'revenues',
                ',         null as revenues'
            ) || f_dynamic_result(
                v_result_column_list,
                'risk_adjusted_revenue',
                ',         null as risk_adjusted_revenue'
            ) || f_dynamic_result(
                v_result_column_list,
                'net_cost_economic_capital',
                ',         null as net_cost_of_ec'
            ) || f_dynamic_result(
                v_result_column_list,
                'gross_eva',
                ',         null as gross_eva'
            ) || f_dynamic_result(
                v_result_column_list,
                'gross_raroc',
                ',         null as gross_raroc'
            ) || f_dynamic_result(
                v_result_column_list,
                'operating_expenses',
                ',         null as operating_expenses'
            ) || f_dynamic_result(
                v_result_column_list,
                'net_eva',
                ',         null as net_eva'
            ) || f_dynamic_result(
                v_result_column_list,
                'net_raroc',
                ',         null as net_raroc'
            );

        END;
    END IF;

    IF ( ( v_elec_available = 'Y' AND v_elec_approach IN (
            'IAS',
            'Cred. Risk',
            'INCAP',
            'INCAPNEW'
        ) ) OR ( v_elec_available_basel = 'Y' AND v_elec_approach IN ('Basel')
        ) ) THEN
        BEGIN
            v_select_statement := v_select_statement || f_dynamic_result(
                v_result_column_list,
                'cure_rate',
                ',    case when pc.ead_cr_abs <> 0 then cast(pc.cure_rate_amount / pc.ead_cr_abs as number(22,2)) else null end      AS cure_rate '
            ) || f_dynamic_result(
                v_result_column_list,
                'direct_cost',
                ',    pc.direct_cost '
            ) || f_dynamic_result(
                v_result_column_list,
                'indirect_cost',
                ',    pc.indirect_cost '
            ) || f_dynamic_result(
                v_result_column_list,
                'e_lim_factor',
                ',    case when pc.ead_cr_abs <> 0 then cast(pc.e_lim_factor_amount / pc.ead_cr_abs as number(22,2)) else null end  AS e_lim_factor '
            ) || f_dynamic_result(
                v_result_column_list,
                'e_os_factor',
                ',    case when pc.ead_cr_abs <> 0 then cast(pc.e_os_factor_amount / pc.ead_cr_abs as number(22,2)) else null end     AS e_os_factor '
            ) || f_dynamic_result(
                v_result_column_list,
                'g_factor',
                ',    case when pc.ead_cr_abs <> 0 then cast(pc.g_factor_amount / pc.ead_cr_abs as number(22,2)) else null end        AS g_factor '
            ) || f_dynamic_result(
                v_result_column_list,
                'h_factor',
                ',    case when pc.original_cover_amount_abs <> 0 then cast(pc.h_factor_amount / pc.original_cover_amount_abs as number(22,2)) else null end                                                              AS h_factor '
            ) || f_dynamic_result(
                v_result_column_list,
                'k_factor',
                ',    case when pc.ead_cr_abs <> 0 then cast(pc.k_factor_amount / pc.ead_cr_abs as number(22,2)) else null end        AS k_factor '
            ) || f_dynamic_result(
                v_result_column_list,
                'secured_discount_factor',
                ',    case when pc.original_cover_amount_abs <> 0 then cast(pc.secured_discount_factor_amount / pc.original_cover_amount_abs as number(22,2)) else null end  AS secured_discount_factor '
            ) || f_dynamic_result(
                v_result_column_list,
                'unsecured_discount_factor',
                ',    case when pc.ead_cr_abs <> 0 then cast(pc.unsecured_discount_factor_amount / pc.ead_cr_abs as number(22,2)) else null end                                                      AS unsecured_discount_factor '
            ) || f_dynamic_result(
                v_result_column_list,
                'secured_recovery_amounts',
                ',    pc.secured_recovery_amounts '
            ) || f_dynamic_result(
                v_result_column_list,
                'unsecured_recovery_amounts',
                ',    pc.unsecured_recovery_amounts '
            ) || f_dynamic_result(
                v_result_column_list,
                'secured_recovery_amounts_discounted',
                ',    pc.secured_recovery_amounts_discounted '
            ) || f_dynamic_result(
                v_result_column_list,
                'unsecured_recovery_amounts_discounted',
                ',    pc.unsecured_recovery_amounts_discounted '
            ) || f_dynamic_result(
                v_result_column_list,
                'original_cover_amount',
                ',    pc.original_cover_amount '
            );

        END;
    ELSE
        BEGIN
            v_select_statement := v_select_statement || f_dynamic_result(
                v_result_column_list,
                'cure_rate',
                ',    null as cure_rate '
            ) || f_dynamic_result(
                v_result_column_list,
                'direct_cost',
                ',    null as direct_cost '
            ) || f_dynamic_result(
                v_result_column_list,
                'indirect_cost',
                ',    null as indirect_cost '
            ) || f_dynamic_result(
                v_result_column_list,
                'e_lim_factor',
                ',    null as e_lim_factor '
            ) || f_dynamic_result(
                v_result_column_list,
                'e_os_factor',
                ',    null as e_os_factor '
            ) || f_dynamic_result(
                v_result_column_list,
                'g_factor',
                ',    null as g_factor '
            ) || f_dynamic_result(
                v_result_column_list,
                'h_factor',
                ',    null as h_factor '
            ) || f_dynamic_result(
                v_result_column_list,
                'k_factor',
                ',    null as k_factor '
            ) || f_dynamic_result(
                v_result_column_list,
                'secured_discount_factor',
                ',    null as secured_discount_factor '
            ) || f_dynamic_result(
                v_result_column_list,
                'unsecured_discount_factor',
                ',    null as unsecured_discount_factor '
            ) || f_dynamic_result(
                v_result_column_list,
                'secured_recovery_amounts',
                ',    null as secured_recovery_amounts '
            ) || f_dynamic_result(
                v_result_column_list,
                'unsecured_recovery_amounts',
                ',    null as unsecured_recovery_amounts '
            ) || f_dynamic_result(
                v_result_column_list,
                'secured_recovery_amounts_discounted',
                ',    null as secured_recovery_amounts_discounted '
            ) || f_dynamic_result(
                v_result_column_list,
                'unsecured_recovery_amounts_discounted',
                ',    null as unsecured_recovery_amounts_discounted '
            ) || f_dynamic_result(
                v_result_column_list,
                'original_cover_amount',
                ',    null as original_cover_amount '
            );

        END;
    END IF;

    v_select_statement := v_select_statement || ',      pc.compliance_department                      AS compliance_department ';

    IF v_report_type = 'ReviewOwner' OR ( v_report_type = 'ReviewDate' AND v_report_rd_hierarchy_type IN (
            'CDD',
            'MIFID',
            'BR'
        ) ) THEN

        v_select_statement := v_select_statement ||
            CASE
                WHEN not ( v_report_type = 'ReviewOwner' AND v_report_review_owner_hierarchy_type = 'ROCOD' ) THEN
                    ',      pc.next_review_date                           AS next_review_date '
            END
        || ',      pc.review_owner_entity_descr                  AS review_owner_entity_descr ' || ',      pc.review_owner_dept_descr                    AS review_owner_dept_descr '
;
    END IF;

   --CVA
   commit;
    utilities.truncate_table('TT_SCP');
    utilities.truncate_table('TT_C');

    INSERT /*+ APPEND */ INTO TT_SCP
        select pam.name parent_account_manager,lam.name local_account_manager,prm.name parent_risk_manager,lrm.name local_risk_manager,scp.customer_id,scp.combined_status
        from dmi_search_customer scp
        left outer join dmi_scs_user prm on scp.parent_risk_manager_id = prm.user_id
        left outer join dmi_scs_user lam on scp.local_account_manager_id = lam.user_id
        left outer join dmi_scs_user pam on scp.parent_account_manager_id = pam.user_id
        left outer join dmi_scs_user lrm on scp.local_risk_manager_id = lrm.user_id
        WHERE scp.customer_id IN (SELECT customer_id FROM tmp_portfolio_cust);
    SCHEMA_MAINT.GATHER_IDX_STATS('TT_SCP');

    schema_maint.gather_idx_stats('tmp_portfolio_cust');


    INSERT/*+ APPEND */ INTO TT_C
        select c.ins_risk_rating,it.industry_type_descr,it.industry_type_code,c.ins_risk_rating_source,c.customer_id,c.record_valid_until,c.record_valid_from,c.customer_name,ctry.country_name,c.city,c.ing_risk_rating,c.risk_rating_source
        from dmi_customer c
        left outer join dmi_country ctry on c.ctry_of_residence_key = ctry.country_key
        left outer join dmi_industry_type it on c.industry_type_key = it.industry_type_key
        WHERE C.RECORD_VALID_FROM <= v_reporting_date
          AND ( nvl(c.record_valid_until,TO_DATE('9999-12-31','yyyy-mm-dd') ) > v_reporting_date  )
          AND c.customer_id IN (SELECT customer_id FROM tmp_portfolio_cust);
    SCHEMA_MAINT.GATHER_IDX_STATS('TT_C');
    COMMIT;


   commit;

    v_select_statement := v_select_statement
                         || f_dynamic_result(v_result_column_list,'after_coll_regulatory_os_amt',', after_coll_regulatory_os_amt')
                         || f_dynamic_result(v_result_column_list,'cva_risk_weight',', CAST( 100 * ROUND(cva_risk_weight  / NULLIF(ABS(cva_exposure),0),8) AS number(11,8)) AS cva_risk_weight')
                         || f_dynamic_result(v_result_column_list,'cva_effective_maturity',', CAST( ROUND(cva_effective_maturity / NULLIF(ABS(cva_exposure),0),8) AS number(11,8)) AS cva_effective_maturity')
                         || f_dynamic_result(v_result_column_list,'cva_diversification_ratio',', CAST( ROUND(cva_diversification_ratio / NULLIF(ABS(cva_exposure),0),8) AS number(11,8)) AS cva_diversification_ratio')
                         || f_dynamic_result(v_result_column_list,'diversified_cva_capital',', diversified_cva_capital')
                         || f_dynamic_result(v_result_column_list,'regulatory_outstanding_amount',', regulatory_os_amt AS regulatory_outstanding_amount')
                         || f_dynamic_result(v_result_column_list,'total_cva_exposure',', total_cva_exposure')
                         || f_dynamic_result(v_result_column_list,'cva_exposure',', cva_exposure')
                         || f_dynamic_result(v_result_column_list,'gross_regulatory_os_amt',', gross_regulatory_os_amt')
                         || ' from  tmp_portfolio_cust pc '

                        || f_dynamic_result(v_result_column_list,'product_type_descr',' left outer join dmi_facility_type ft ' || ' on     pc.risk_category_key = ft.facility_type_key ')
                        || f_dynamic_result(v_result_column_list,'exposure_at_default_model',' left outer join dmi_ead_model m1 ' || ' on     pc.ead_model_key_cr = m1.model_key ')
                        || f_dynamic_result(v_result_column_list,'loss_given_default_model',' left outer join dmi_lgd_model m2 ' || ' on    pc.lgd_model_key_cr = m2.model_key ')
                        ||
                        CASE

                        WHEN v_recap_approach  IN ('FIRB','AIRB','Official') AND v_elec_approach_orig = 'Basel4' THEN
                            f_dynamic_result(v_result_column_list,'regulatory_asset_class_descr',' left outer join dmi_basel4_exposure_class_irb ac ' || ' on     pc.asset_class_code_basel = ac.basel4_exposure_class_irb_code '
                           || ' and   (ac.record_valid_from <= pc.report_date) '
                           || ' and   (nvl(ac.record_valid_until,to_date(''9999-12-31'',''yyyy-mm-dd'')) > pc.report_date ) ')
                        WHEN v_recap_approach  = 'SA' AND v_elec_approach_orig = 'Basel' THEN
                            f_dynamic_result(v_result_column_list,'regulatory_asset_class_descr',' left outer join dmi_exposure_class_sa ac ' || ' on     pc.asset_class_code_basel = ac.exposure_class_sa_code '
                           || ' and   (ac.record_valid_from <= pc.report_date) '
                           || ' and   (nvl(ac.record_valid_until,to_date(''9999-12-31'',''yyyy-mm-dd'')) > pc.report_date ) ')
                        WHEN v_recap_approach  = 'SA' AND v_elec_approach_orig = 'Basel4' THEN
                        f_dynamic_result(v_result_column_list,'regulatory_asset_class_descr',' left outer join dmi_basel4_exposure_class_sa ac ' || ' on     pc.asset_class_code_basel = ac.basel4_exposure_class_sa_code '
                           || ' and   (ac.record_valid_from <= pc.report_date) '
                           || ' and   (nvl(ac.record_valid_until,to_date(''9999-12-31'',''yyyy-mm-dd'')) > pc.report_date ) ')
                        ELSE
                            f_dynamic_result(v_result_column_list,'regulatory_asset_class_descr',' left outer join dmi_exposure_class_irb ac ' || ' on     pc.asset_class_code_basel = ac.exposure_class_irb_code '
                           || ' and   (ac.record_valid_from <= pc.report_date) '
                           || ' and   (nvl(ac.record_valid_until,to_date(''9999-12-31'',''yyyy-mm-dd'')) > pc.report_date ) ')
                        END
                        || ' left outer join TT_SCP scp on pc.customer_id = scp.customer_id '
                        || ' left outer join TT_C c on pc.customer_id = c.customer_id '
                        || ' left outer join rating_agency era on pc.ext_rating_agency_key = era.rating_agency_key ';


    IF ( v_debug = 1 ) THEN
        utilities.performance_log(
            '14a.' || v_procedure_name,
            v_time   => v_time
        );
    END IF;

    OPEN v_cursor FOR 'select count(*) as rowcount from tmp_portfolio_cust';
    dbms_sql.return_result(v_cursor);

    IF ( v_debug = 1 ) THEN
        utilities.performance_log(
            '14b.' || v_procedure_name,
            v_time   => v_time
        );
    END IF;

    IF ( v_debug = 1 ) THEN
        utilities.performance_log(
            '15a.' || v_procedure_name,
            v_time    => v_time,
            v_query   => v_select_statement
        );
    END IF;

    utilities.show_debug('v_select_statement from ' || $$plsql_unit || ' ::' || v_select_statement);
    BEGIN

        OPEN v_cursor FOR v_select_statement;
        dbms_sql.return_result(v_cursor);

    EXCEPTION
        WHEN OTHERS THEN
            utils.handleerror(
                sqlcode,
                sqlerrm
            );
    END;
commit;
    IF ( v_debug = 1 ) THEN
        utilities.performance_log(
            '15b.' || v_procedure_name,
            v_time   => v_time
        );
    END IF;

EXCEPTION
    WHEN OTHERS THEN
        utils.handleerror(
            sqlcode,
            sqlerrm
        );
END;
/
show error;
GRANT EXECUTE ON PORTFOLIO_REPORTS_CUSTOMER_DATA TO VORTEX_BUSS_REPORT_GRP;