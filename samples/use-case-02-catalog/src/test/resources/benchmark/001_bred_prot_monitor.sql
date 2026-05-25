create or replace PROCEDURE BRED_PROT_MONITOR_DWHDMBRECON_B4 ( 
    i_reporting_date   IN DATE, 
--    i_debug IN INTEGER DEFAULT 0,
    system_id  IN VARCHAR2 DEFAULT NULL,
    threshold  IN NUMBER DEFAULT 100,
    export_id  IN NUMBER DEFAULT 99999
) AS

    v_reporting_date       DATE := i_reporting_date;
    v_system_id            VARCHAR2(3):= system_id;
    v_threshold            NUMBER := threshold;
    v_debug_msg            pkg_subtype.debug_msg;
    cv_1                   SYS_REFCURSOR;
    v_tname 			         VARCHAR2(100);
    v_start                DATE;
    v_count                INTEGER;
    v_proc_name            VARCHAR2(128 CHAR) := 'BRED_PROT_MONITOR_DWHDMBRECON_B4';
    v_export_id            NUMBER := export_id;
    v_eurcurrencykey       NUMBER(12);
    v_eurcurrcode          VARCHAR2(10 CHAR);
    
BEGIN

    SELECT eurcurr.currency_key ,
           eurcurr.code
    INTO  v_eurcurrencykey,
          v_eurcurrcode
    FROM currency eurcurr
    WHERE  eurcurr.code = 'EUR'
    AND eurcurr.record_valid_from <= v_reporting_date
    AND ( eurcurr.record_valid_until > v_reporting_date
    OR eurcurr.record_valid_until IS NULL );
    
    BEGIN
        v_start := SYSDATE;
        utilities.truncate_table('TMP_VDD_DMB_PROT_RECON');
      
        INSERT  /*+ APPEND enable_parallel_dml */ INTO TMP_VDD_DMB_PROT_RECON
        (SELECT /*+ Parallel +*/ rm.reporting_date,
            rm.v_orig_src_system_id        system_id,
            COUNT(DISTINCT NVL(rm.cover_key, rm.asset_key)) prot_cnt,
            COUNT(1) counts,
            SUM(rm.n_mitigant_value) mitigants,
            SUM(rm.n_fx_rate) fx_rate,
            SUM(rm.n_tot_priority_claim_amt)  priority_amt,
            SUM(rm.n_fin_coll_adjusted_amount) adjusted_amt,
            SUM(rm.n_realizable_amount_la_r)   realizable_la_amount,
            SUM(rm.n_realizable_amount_cap_req)  realizable_cap_amount,
            SUM(rm.n_occupancy_rate) occupancy_rate,
            SUM(rm.n_total_rentable_surface) rentable_surface,
            --SUM(rm.n_exp_liquidation_costs_perc) liquidation_perc,
            SUM(rm.n_exp_liquidation_costs) liquidation_perc, -- STRY3721832 SS
            SUM(rm.n_liquidation_value) liquidation,
            SUM(rm.n_fair_value) fair,
            SUM(rm.n_mitigant_value_eur) mitigant_eur,
            SUM(rm.interest_coverage_ratio) coverage_ratio,
            SUM(rm.debt_service_coverage_ratio)  dept_coverage_ratio,
            SUM(rm.gross_annual_rental_income)   rental_income,
            SUM(rm.annual_rental_value) rental_value,
            SUM(rm.annual_rental_costs)  rental_costs, 
            SUM(rm.net_annual_rental_income) net_rental_income,
            SUM(rm.n_orig_mitigant_value) mitigant_value,
            SUM(rm.n_orig_fx_rate) orig_fx_rate,
            SUM(n_orig_mitigant_value_eur) orig_mitigant,
            v_level_ind v_level_ind
          FROM dmb_reg_protection_dmart rm
          WHERE rm.reporting_date = v_reporting_date
          GROUP BY reporting_date, v_orig_src_system_id,v_level_ind
          );

          v_count := SQL%ROWCOUNT;
          COMMIT;

          schema_maint.gather_idx_stats('TMP_VDD_DMB_PROT_RECON');
          vde_log(v_export_id, v_proc_name, v_reporting_date, v_start, 1, 'Inserted data to TMP_VDD_DMB_PROT_RECON. Row count:' || v_count);

          v_debug_msg := $$plsql_line|| ' OF PLSQL UNIT '|| $$plsql_unit||' rowcount >> '|| v_count;
          utilities.show_debug(v_debug_msg);

          EXCEPTION
          WHEN OTHERS THEN
          utils.handleerror(SQLCODE,SQLERRM);
      END;

  /*To find the scope for protection(to find the eligible records for protection)
    Select all outstanding_group keys  in scope for BRED into a temp table (we can use tt_bred_scope for this */

--    BEGIN
--        v_start := SYSDATE;
--        utilities.truncate_table('tt_bred_scope_recon');
--
--        INSERT INTO /*+ APPEND enable_parallel_dml +*/ tt_bred_scope_recon
--        ( outstanding_group_key, facility_key )
--          ( SELECT  /*+ Parallel +*/ dog.outstanding_group_key outstanding_group_key  ,
--          df.facility_key facility_key
--          FROM dwh_outstanding_group dog
--          JOIN dwh_facility df   ON  df.facility_key = dog.facility_key
--          WHERE  dog.record_valid_from = v_reporting_date
--          AND df.record_valid_from = v_reporting_date
--          AND dog.system_id = NVL(v_system_id, dog.system_id)
--          AND df.limit_type_indicator IN ( 'S','I' )
--          AND EXISTS ( SELECT 1
--                  FROM facility_type ft
--                  WHERE  dog.prod_type_key = ft.facility_type_key
--                            AND ft.highest_level_code IN ( 'WS','ST','NR','MM','IS','FM' )
--          ) );
--
--        v_count := SQL%ROWCOUNT;
--        COMMIT;
--
--        schema_maint.gather_idx_stats('tt_bred_scope_recon');
--        vde_log(v_export_id, v_proc_name, v_reporting_date, v_start, 1, 'Inserted data to tt_bred_scope_recon. Row count:' || v_count);
--
--        v_debug_msg := $$plsql_line|| ' OF PLSQL UNIT '|| $$plsql_unit||' rowcount >> '|| v_count;
--        utilities.show_debug(v_debug_msg);
--
--        EXCEPTION
--        WHEN OTHERS THEN
--        utils.handleerror(SQLCODE,SQLERRM);
--    END;

/* Now like dmb table, Collect respective values from protection dwh tables 
  First fill following temp tables used in joins */


-----Take distinct facility keys in scope

    BEGIN
        v_start := SYSDATE;
        utilities.truncate_table('tt_scope');

        INSERT /*+ APPEND enable_parallel_dml */ INTO tt_scope
          ( SELECT DISTINCT
              facility_key_link,
              MAX(f_cre_scope_ind) AS f_cre_scope_ind,
              MAX(f_ana_scope_ind) AS f_ana_scope_ind -- 8.8.601
            FROM dmb_reg_facility_hierarchy
            WHERE reporting_date = v_reporting_date
            GROUP BY facility_key_link); -- 8.8.601);

          v_count := SQL%ROWCOUNT;
          COMMIT;

          schema_maint.gather_idx_stats('tt_scope');
          vde_log(v_export_id, v_proc_name, v_reporting_date, v_start, 1, 'Inserted data to tt_scope. Row count:' || v_count);

          v_debug_msg := $$plsql_line|| ' OF PLSQL UNIT '|| $$plsql_unit||' rowcount >> '|| v_count;
          utilities.show_debug(v_debug_msg);

          EXCEPTION
          WHEN OTHERS THEN
          utils.handleerror(SQLCODE,SQLERRM);
      END;

-----Create temp table to capture cover scope records.
    BEGIN
        v_start := SYSDATE;
        utilities.truncate_table('tt_cover_scope_records');

        INSERT/*+ APPEND enable_parallel_dml */ INTO tt_cover_scope_records
            ( SELECT /*+ parallel +*/
                cov.cover_key,
                cov.cover_id,
                cov.system_id
              FROM
                dwh_cover cov
                JOIN tt_scope fac_heir
                ON cov.facility_key = fac_heir.facility_key_link
                AND cov.record_valid_from = v_reporting_date -- MK partitions
              GROUP BY
                cov.cover_key,
                cov.cover_id,
                cov.system_id
            );
        v_count := SQL%ROWCOUNT;
        COMMIT;

        schema_maint.gather_idx_stats('tt_cover_scope_records');
        vde_log(v_export_id, v_proc_name, v_reporting_date, v_start, 1, 'Inserted data to tt_cover_scope_records. Row count:' || v_count);

        v_debug_msg := $$plsql_line|| ' OF PLSQL UNIT '|| $$plsql_unit||' rowcount >> '|| v_count;
        utilities.show_debug(v_debug_msg);

        EXCEPTION
        WHEN OTHERS THEN
        utils.handleerror(SQLCODE,SQLERRM);
    END;


--Create temp table to calculate summed amounts on reporting_date
    BEGIN
      v_start := SYSDATE;
      utilities.truncate_table('tt_cover_amounts_hc');
      
      INSERT/*+ APPEND enable_parallel_dml */ INTO tt_cover_amounts_hc
      ( SELECT /*+ parallel +*/
          csr.cover_key,
          csr.cover_id,
          SUM(nvl(covvre.alloc_available_amount_before_hc,0) ) alloc_amt_before_hc,
          SUM(nvl(covvre.alloc_available_amount_after_hc,0) ) alloc_amt_after_hc_irb,
          nvl(SUM(covvre.alloc_available_amt_after_index),0) alloc_available_amt_after_index
        FROM
          tt_cover_scope_records csr
          LEFT JOIN dwh_vre_cover_recapb4 covvre 
          ON csr.cover_key = covvre.cover_key
              AND covvre.record_valid_from = v_reporting_date
              AND covvre.configuration_code = 'RECAP4AIRB'
      GROUP BY
          csr.cover_key,
          csr.cover_id
      );

      v_count := SQL%ROWCOUNT;
      COMMIT;

      schema_maint.gather_idx_stats('tt_cover_amounts_hc');
      vde_log(v_export_id, v_proc_name, v_reporting_date, v_start, 1, 'Inserted data to tt_cover_amounts_hc. Row count:' || v_count);

      v_debug_msg := $$plsql_line|| ' OF PLSQL UNIT '|| $$plsql_unit||' rowcount >> '|| v_count;
      utilities.show_debug(v_debug_msg);

      EXCEPTION
      WHEN OTHERS THEN
      utils.handleerror(SQLCODE,SQLERRM);
    END;


--Create temp table to get the non grid customers and their respective customer_type
    BEGIN
      v_start := SYSDATE;
      utilities.truncate_table('tt_anacredit_nongrid_customers');

      INSERT /*+ APPEND enable_parallel_dml */INTO tt_anacredit_nongrid_customers
          ( SELECT/*+ parallel +*/
              basiccust.customer_type customer_type,
              dercust.customer_key customer_key
            FROM dwh_basic_customer basiccust
            INNER JOIN dwh_derived_customer dercust ON basiccust.basic_customer_key = dercust.basic_customer_key
            WHERE dercust.grid_interface = 'N'
            AND dercust.record_valid_from <= v_reporting_date
            --AND  nvl(dercust.record_valid_until,utilities.record_default_date ) > v_reporting_date
            AND  nvl(dercust.record_valid_until,utilities.record_default_date ) > v_reporting_date
            --AND (dercust.record_valid_until > v_reporting_date OR dercust.record_valid_until IS NULL) --ORAMIGCONTINUOUSCATCHUP3
          );
      v_count := SQL%ROWCOUNT;
      COMMIT;

      schema_maint.gather_idx_stats('tt_anacredit_nongrid_customers');
      vde_log(v_export_id, v_proc_name, v_reporting_date, v_start, 1, 'Inserted data to tt_anacredit_nongrid_customers. Row count:' || v_count);

      v_debug_msg := $$plsql_line|| ' OF PLSQL UNIT '|| $$plsql_unit||' rowcount >> '|| v_count;
      utilities.show_debug(v_debug_msg);

      EXCEPTION
      WHEN OTHERS THEN
      utils.handleerror(SQLCODE,SQLERRM);
    END;

--Create temp table to capture cover scope records.
    BEGIN
      v_start := SYSDATE;
      utilities.truncate_table('tt_anacredit_dwh_cover');

      INSERT /*+ full(cov) */ INTO tt_anacredit_dwh_cover
        ( SELECT /*+ parallel +*/ cov.cover_key cover_key  ,
        cov.asset_key asset_key  ,
        cov.record_valid_from record_valid_from  ,
        cov.cover_id cover_id  ,
        cov.system_id system_id  ,
        cov.cover_start_date cover_start_date  ,
        cov.facility_key facility_key  ,
        cov.facility_id facility_id  ,
        cov.batch_id batch_id
        FROM dwh_cover cov
            JOIN cover_type covtp   ON cov.cover_type_key = covtp.cover_type_key
                                    AND cov.record_valid_from = v_reporting_date -- MK partitions
                                    AND covtp.ira_purpose NOT IN ( 'ICG','LLG') -- exclude IRA trigger cover
            JOIN dmb_reg_facility_hierarchy hier   ON cov.facility_key = hier.facility_key--8.8.652
                                                  AND   hier.f_ana_scope_ind IS NOT NULL --8.8.652
                                                  AND   hier.level_number = 0-- exclude AnaCredit protection type NONANACREDIT
            LEFT JOIN reg_cover_type_class reg   ON covtp.reg_cover_type_class = reg.code
            AND reg.record_valid_from <= v_reporting_date
          AND  NVL(reg.record_valid_until,utilities.record_default_date) > v_reporting_date
        WHERE  reg.anacredit_protection_type <> 'NONANACREDIT'
          );

      v_count := SQL%ROWCOUNT;
      COMMIT;

      schema_maint.gather_idx_stats('tt_anacredit_dwh_cover');
      vde_log(v_export_id, v_proc_name, v_reporting_date, v_start, 1, 'Inserted data to tt_anacredit_dwh_cover. Row count:' || v_count);

      v_debug_msg := $$plsql_line|| ' OF PLSQL UNIT '|| $$plsql_unit||' rowcount >> '|| v_count;
      utilities.show_debug(v_debug_msg);

      EXCEPTION
      WHEN OTHERS THEN
      utils.handleerror(SQLCODE,SQLERRM);
    END;


 --Create temp table to determine first record on or after cover start date (csd) for table dwh_cover_amount_org and table dwh_vre_cover_recapb4                                                        --on reporting date
    BEGIN
      v_start := SYSDATE;
      utilities.truncate_table('tt_anacredit_cover_start_date_records');
      INSERT /*+ APPEND enable_parallel_dml */ INTO tt_anacredit_cover_start_date_records
      ( SELECT  /*+ parallel full(cov_csd)  */  --added hint to fix INC9592891
              cov.cover_key,    --on reporting date
              cov.cover_id,
              cov.system_id,
              cov.cover_start_date,
              MIN(amt_ccro.record_valid_from) ccro_csd,--first date available for amt_ccro record
              MIN(amt_ccso.record_valid_from) ccso_csd,--first date available for amt_ccso record
              MIN(vre.record_valid_from) vre_csd --first date on or after cover start date for vre record
          FROM
              tt_anacredit_dwh_cover cov --on reporting date
              JOIN dwh_cover cov_csd ON cov.cover_id = cov_csd.cover_id --on cover start date
                                      AND cov.system_id = cov_csd.system_id
                                      AND cov_csd.record_valid_from = v_reporting_date -- MK partitions
              LEFT JOIN dwh_cover_amount_org amt_ccro ON cov_csd.cover_key = amt_ccro.cover_key
              AND amt_ccro.amount_type = 'CCRO'
                AND amt_ccro.record_valid_from = last_day(amt_ccro.record_valid_from)
              AND amt_ccro.cover_value_date IS NOT NULL --STRY0728079
            AND amt_ccro.cover_amount IS NOT NULL --STRY0728079
              LEFT JOIN dwh_cover_amount_org amt_ccso ON cov_csd.cover_key = amt_ccso.cover_key
              AND amt_ccso.amount_type = 'CCSO'
            AND amt_ccso.record_valid_from = last_day(amt_ccso.record_valid_from)

          AND amt_ccso.cover_value_date IS NOT NULL --STRY0728079
              AND amt_ccso.cover_amount IS NOT NULL --STRY0728079
          LEFT JOIN dwh_vre_cover_recapb4 vre --replaced with basel4 source for story 4840242
        ON cov_csd.cover_key = vre.cover_key
              AND vre.configuration_code = 'RECAP4AIRB'
              AND vre.record_valid_from = last_day(vre.record_valid_from)
              AND vre.record_valid_from >= cov.cover_start_date
          GROUP BY
              cov.cover_key,
              cov.cover_id,
              cov.system_id,
              cov.cover_start_date);

      v_count := SQL%ROWCOUNT;
      COMMIT;

      schema_maint.gather_idx_stats('tt_anacredit_cover_start_date_records');
      vde_log(v_export_id, v_proc_name, v_reporting_date, v_start, 1, 'Inserted data to tt_anacredit_cover_start_date_records. Row count:' || v_count);

      v_debug_msg := $$plsql_line|| ' OF PLSQL UNIT '|| $$plsql_unit||' rowcount >> '|| v_count;
      utilities.show_debug(v_debug_msg);

      EXCEPTION
      WHEN OTHERS THEN
      utils.handleerror(SQLCODE,SQLERRM);
    END;


 --Create temp table to calculate summed amounts (allocated_available_amount_before_haircut) on reporting_date and cover_start_date

  utilities.show_debug('INFO: -- step 1e of 3: Create temp table 4 for AnaCredit Protection Export - VRE records on CSD');

    BEGIN
      v_start := SYSDATE;
      utilities.truncate_table('tt_anacredit_vre_amounts');
    
      INSERT /*+ APPEND enable_parallel_dml */ INTO tt_anacredit_vre_amounts
      (SELECT /*+ parallel full(cov) */  --added hints to fix INC9592891
            csd.cover_key ,                                                                               --on reporting date
            cov.cover_key as cover_key_vre_csd  ,                                                         --on cover start date for VRE
            csd.cover_id,
            SUM(NVL(covvre.alloc_available_amt_after_index, 0))      AS alloc_amt_after_index               --26. on reporting date
          ,SUM(NVL(covvre.alloc_available_amt_after_index, 0))      AS alloc_amt_after_index_csd           --42. on cover start date
      FROM tt_anacredit_cover_start_date_records                 csd
      LEFT JOIN dwh_cover cov ON csd.vre_csd = cov.record_valid_from --on cover start date
      AND csd.system_id = cov.system_id
      AND csd.cover_id = cov.cover_id
      LEFT JOIN dwh_vre_cover_recapb4 covvre  --replaced with basel4 source for story 4840242
      ON csd.cover_key = covvre.cover_key
      AND covvre.configuration_code = 'RECAP4AIRB'
      AND covvre.record_valid_from = v_reporting_date
      AND covvre.system_id = csd.system_id
      GROUP BY csd.cover_key, cov.cover_key, csd.cover_id);

      v_count := SQL%ROWCOUNT;
      COMMIT;

      schema_maint.gather_idx_stats('tt_anacredit_vre_amounts');
      vde_log(v_export_id, v_proc_name, v_reporting_date, v_start, 1, 'Inserted data to tt_anacredit_vre_amounts. Row count:' || v_count);

      v_debug_msg := $$plsql_line|| ' OF PLSQL UNIT '|| $$plsql_unit||' rowcount >> '|| v_count;
      utilities.show_debug(v_debug_msg);

      EXCEPTION
      WHEN OTHERS THEN
      utils.handleerror(SQLCODE,SQLERRM);
    END;

    /* Now Collect respective values from protection dwh tables for cover records */

    BEGIN
      v_start := SYSDATE;
      utilities.truncate_table('TMP_VDD_DWH_PROT_RECON_COVER');
    
      INSERT INTO /*+ APPEND enable_parallel_dml +*/  TMP_VDD_DWH_PROT_RECON_COVER
          (reporting_date,system_id,prot_cnt_cover,cover_counts,mitigants,fx_rate,priority_amt,adjusted_amount,realizable_la_amount,realizable_cap_amount,
            liquidation,mitigant_eur,coverage_ratio,dept_coverage_ratio,rental_income,rental_value,rental_costs,net_rental_income,mitigant_value,
            orig_fx_rate,orig_mitigant)
            with sum_fin_coll as
          (
              SELECT /*+ parallel full(cov2) */
                cov2.cover_key,
                nvl(SUM(nvl(bsl_sa.financial_collateral,0) ),0) n_fin_coll_adjusted_amount
              FROM
                dwh_cover cov2
                JOIN tt_cover_amounts_hc cov_scope
                  ON cov2.cover_key = cov_scope.cover_key
                  AND cov2.record_valid_from = v_reporting_date -- MK partitions
                LEFT
                JOIN dwh_recapb4_osg_cover_sa bsl_sa
                  ON cov2.record_valid_from = bsl_sa.record_valid_from
                AND cov2.system_id = bsl_sa.system_id
                AND cov2.cover_id = bsl_sa.cover_id
                AND bsl_sa.basel_approach = 'SA'
                AND bsl_sa.financial_collateral > 0
              WHERE
                cov2.record_valid_from = v_reporting_date
              GROUP BY
                cov2.cover_key
            ),
            sum_rel as
            (
              SELECT
                cov2.cover_key,
                nvl(SUM(nvl(amt_ifrs.alloc_available_amount_after_hc,0) ),0) n_realizable_amount_la_r
              FROM
                tt_cover_amounts_hc cov2
                LEFT
                JOIN dwh_vre_cover_ifrs amt_ifrs
                  ON cov2.cover_key = amt_ifrs.cover_key
                AND amt_ifrs.record_valid_from = v_reporting_date
                AND amt_ifrs.configuration_code = 'IFRSPIT'
                AND amt_ifrs.alloc_available_amount_after_hc > 0
              GROUP BY cov2.cover_key
              ) ,
          sum_cap_req as
          (
              SELECT
                cov2.cover_key,
                nvl(SUM(nvl(covvre.alloc_available_amount_after_hc,0) ),0) n_realizable_amount_cap_req
              FROM
                tt_cover_amounts_hc cov2
                LEFT
                JOIN dwh_vre_cover_recapb4 covvre
                  ON cov2.cover_key = covvre.cover_key
                  AND covvre.record_valid_from = v_reporting_date
                  AND covvre.configuration_code = 'RECAP4AIRB'
                  AND covvre.alloc_available_amount_after_hc > 0
              GROUP BY cov2.cover_key
            )   ,
        sum_liq_val as
          (
          SELECT
            cov2.cover_key,
            ROUND(nvl(SUM(nvl(vre.alloc_available_amount_after_hc,0) ),0)) n_liquidation_value
          FROM
            tt_cover_amounts_hc cov2
            LEFT
            JOIN dwh_vre_cover_incap vre
              ON cov2.cover_key = vre.cover_key
            AND vre.record_valid_from = v_reporting_date
            AND vre.configuration_code = 'INCAPTTC'
            AND vre.cover_allocation_type = 'INCC'
            AND vre.alloc_available_amount_after_hc > 0
          GROUP BY
            cov2.cover_key
            ),
        cte_cre_cov AS
        (
            select cover_key,
                   SUM(NVL(cre_cov.interest_coverage_ratio,0))  as interest_coverage_ratio ,                                    --coverage_ratio
                   SUM(NVL(cre_cov.debt_service_coverage_ratio,0)) as debt_service_coverage_ratio,                             --dept_coverage_ratio
                   SUM(NVL(cre_cov.gross_annual_rental_income,0))  as   gross_annual_rental_income,                                 --rental_income
                   SUM(NVL(cre_cov.annual_rental_value,0))    as      annual_rental_value,                                    --rental_value
                   SUM(NVL(cre_cov.annual_rental_costs,0))   as    annual_rental_costs,                                       --rental_costs
                   SUM(NVL(cre_cov.net_annual_rental_income,0))  as  net_annual_rental_income                                 --net_rental_income
            from dwh_cre_cover cre_cov
            where 1=1
            and record_valid_from = v_reporting_date
            group by cover_key
        )
        
            select 
              cov.record_valid_from as reporting_date ,                                                             --reporting_date
              cov.system_id  as  system_id,                                                                         --system_id
              COUNT(DISTINCT cov.cover_key) as prot_cnt_cover,                                                      --prot_cnt_cover
              COUNT(1) as  cover_counts,                                                                            --cover_counts                                                                      

              SUM(CASE WHEN amt_fact_ccrb.cover_perc IS NULL
											THEN CASE WHEN amt_orig_cmvo.cover_key IS NOT NULL -- CMVO
                                THEN NVL(amt_orig_cmvo.cover_amount, 0)
                                WHEN amt_orig_ccgo.cover_key IS NOT NULL -- CCGO
                                THEN NVL(amt_orig_ccgo.cover_amount, 0)
                                WHEN amt_orig_ccso.cover_key IS NOT NULL -- CCSO
                                THEN NVL(amt_orig_ccso.cover_amount, 0)
                                WHEN amt_orig_ccro.cover_key IS NOT NULL -- CCRO
                                THEN NVL(amt_orig_ccro.cover_amount, 0)
                                ELSE amt.alloc_available_amt_after_index -- VRE
                            END
                      ELSE amt.alloc_available_amt_after_index -- VRE
									END)  as n_mitigant_value ,                                                                        --mitigants

              SUM(exch_rt.exchange_rate ) as  fx_rate ,                                                             --fx_rate
              SUM(NVL(amt_orig_cplo.cover_amount, 0))  as priority_amt ,                                            --priority_amt
              SUM(sum_fin_coll.n_fin_coll_adjusted_amount ) as adjusted_amount ,                                    --adjusted_amount
              SUM(sum_rel.n_realizable_amount_la_r) as realizable_la_amount ,                                       --realizable_la_amount
              SUM(sum_cap_req.n_realizable_amount_cap_req)   as realizable_cap_amount ,                             --realizable_cap_amount
              SUM(NVL(sum_liq_val.n_liquidation_value,0))  as  liquidation ,                                        --liquidation | both cover and asset records
              
              SUM(CASE WHEN amt_fact_ccrb.cover_perc IS NULL AND NVL(exch_rt.exchange_rate,0) <> 0
                  THEN CASE WHEN amt_orig_cmvo.cover_key IS NOT NULL
                        THEN CASE WHEN NVL(amt_orig_cmvo.cover_amount,0) <> 0
                              THEN ROUND(amt_orig_cmvo.cover_amount/exch_rt.exchange_rate,2)
                              ELSE 0
                          END
                        WHEN amt_orig_ccgo.cover_key IS NOT NULL
                        THEN CASE WHEN NVL(amt_orig_ccgo.cover_amount,0) <> 0
                              THEN ROUND(amt_orig_ccgo.cover_amount/exch_rt.exchange_rate,2)
                              ELSE 0
                          END
                        WHEN amt_orig_ccso.cover_key IS NOT NULL
                        THEN CASE WHEN NVL(amt_orig_ccso.cover_amount,0) <> 0
                              THEN ROUND(amt_orig_ccso.cover_amount/exch_rt.exchange_rate,2)
                              ELSE 0
                              END
                        WHEN amt_orig_ccro.cover_key IS NOT NULL
                        THEN CASE WHEN NVL(amt_orig_ccro.cover_amount,0) <> 0
                              THEN ROUND(amt_orig_ccro.cover_amount/exch_rt.exchange_rate,2)
                              ELSE 0
                          END
                    END
                  WHEN amt_fact_ccrb.cover_perc IS NOT NULL AND NVL(exch_rt.exchange_rate,0) <> 0
                  THEN
                    CASE WHEN NVL(amt.alloc_available_amt_after_index,0) <> 0
                        THEN ROUND(amt.alloc_available_amt_after_index/exch_rt.exchange_rate,2)
                        ELSE 0
                    END
                  ELSE 0
                  END  ) as  mitigant_eur ,      

                   SUM(NVL(cre_cov.interest_coverage_ratio,0))  as interest_coverage_ratio ,                                    --coverage_ratio
                   SUM(NVL(cre_cov.debt_service_coverage_ratio,0)) as debt_service_coverage_ratio,                             --dept_coverage_ratio
                   SUM(NVL(cre_cov.gross_annual_rental_income,0))  as   gross_annual_rental_income,                                 --rental_income
                   SUM(NVL(cre_cov.annual_rental_value,0))    as      annual_rental_value,                                    --rental_value
                   SUM(NVL(cre_cov.annual_rental_costs,0))   as    annual_rental_costs,                                       --rental_costs
                   SUM(NVL(cre_cov.net_annual_rental_income,0))  as  net_annual_rental_income,                                 --net_rental_income

                SUM(
                    CASE WHEN amt_fact_ccrb.cover_perc IS NOT NULL
                    THEN amt_ana.alloc_amt_after_index_csd
                    WHEN amt_fact_ccrb.cover_perc IS NULL AND amt_orig_ccao.cover_key IS NOT NULL
                    THEN amt_orig_ccao.cover_amount
                    WHEN amt_fact_ccrb.cover_perc IS NULL AND amt_orig_cvpo.cover_key IS NOT NULL
                    THEN amt_orig_cvpo.cover_amount
                    WHEN amt_fact_ccrb.cover_perc IS NULL AND amt_incep_cmvo.cover_key IS NOT NULL  -- Inception
                    THEN amt_incep_cmvo.cover_amount
                    WHEN amt_fact_ccrb.cover_perc IS NULL AND amt_incep_ccgo.cover_key IS NOT NULL  -- Inception
                    THEN amt_incep_ccgo.cover_amount
                    WHEN amt_fact_ccrb.cover_perc IS NULL AND amt_incep_ccso.cover_key IS NOT NULL  -- Inception
                    THEN amt_incep_ccso.cover_amount
                    WHEN amt_fact_ccrb.cover_perc IS NULL AND amt_incep_ccro.cover_key IS NOT NULL  -- Inception
                    THEN amt_incep_ccro.cover_amount
                    ELSE amt_ana.alloc_amt_after_index_csd
                    END 
                  )  AS mitigant_value,                                                                           --mitigant_value (n_orig_mitigant_value)

                SUM(
                    CASE WHEN amt_fact_ccrb.cover_perc IS NOT NULL
                    THEN 1
                    ELSE incep_exch_rt.exchange_rate  -- Inception
                    END
                ) AS orig_fx_rate ,                                                                                --orig_fx_rate (orig_fx_rate)

                SUM(
                    CASE WHEN amt_fact_ccrb.cover_perc IS NOT NULL
                    THEN ROUND(amt_ana.alloc_amt_after_index_csd,2)
                    WHEN amt_fact_ccrb.cover_perc IS NULL AND amt_orig_ccao.cover_key IS NOT NULL AND exch_rt.exchange_rate IS NOT NULL AND exch_rt.exchange_rate <> 0
                    THEN ROUND((amt_orig_ccao.cover_amount / exch_rt.exchange_rate),2)
                    WHEN amt_fact_ccrb.cover_perc IS NULL AND amt_orig_cvpo.cover_key IS NOT NULL AND exch_rt.exchange_rate IS NOT NULL AND exch_rt.exchange_rate <> 0
                    THEN ROUND((amt_orig_cvpo.cover_amount / exch_rt.exchange_rate),2)
                    WHEN amt_fact_ccrb.cover_perc IS NULL AND amt_incep_cmvo.cover_key IS NOT NULL AND incep_exch_rt.exchange_rate IS NOT NULL AND incep_exch_rt.exchange_rate <> 0
                    THEN ROUND((amt_incep_cmvo.cover_amount / incep_exch_rt.exchange_rate),2)  -- Inception
                    WHEN amt_fact_ccrb.cover_perc IS NULL AND amt_incep_ccgo.cover_key IS NOT NULL AND incep_exch_rt.exchange_rate IS NOT NULL AND incep_exch_rt.exchange_rate <> 0
                    THEN ROUND((amt_incep_ccgo.cover_amount / incep_exch_rt.exchange_rate),2)  -- Inception
                    WHEN amt_fact_ccrb.cover_perc IS NULL AND amt_incep_ccso.cover_key IS NOT NULL AND incep_exch_rt.exchange_rate IS NOT NULL AND incep_exch_rt.exchange_rate <> 0
                    THEN ROUND((amt_incep_ccso.cover_amount / incep_exch_rt.exchange_rate),2)  -- Inception
                    WHEN amt_fact_ccrb.cover_perc IS NULL AND amt_incep_ccro.cover_key IS NOT NULL AND incep_exch_rt.exchange_rate IS NOT NULL AND incep_exch_rt.exchange_rate <> 0
                    THEN ROUND((amt_incep_ccro.cover_amount / incep_exch_rt.exchange_rate),2)  -- Inception
                    ELSE ROUND(amt_ana.alloc_amt_after_index_csd,2)
                    END
                 )  AS orig_mitigant                                                                               --orig_mitigant(n_orig_mitigant_value_eur)
          FROM dwh_cover cov 
          JOIN tt_cover_amounts_hc amt 
            ON cov.cover_key = amt.cover_key
            AND cov.record_valid_from = v_reporting_date 
          JOIN dwh_facility fac 
            ON cov.facility_key = fac.facility_key
            AND fac.record_valid_from = v_reporting_date
            AND fac.system_id = cov.system_id
          JOIN sum_fin_coll ON sum_fin_coll.cover_key = cov.cover_key
          JOIN sum_rel ON cov.cover_key = sum_rel.cover_key
          JOIN sum_cap_req ON cov.cover_key = sum_cap_req.cover_key
          JOIN sum_liq_val ON cov.cover_key = sum_liq_val.cover_key
          LEFT JOIN cover_type covtp
            ON cov.cover_type_key = covtp.cover_type_key
          LEFT JOIN reg_cover_type_class reg
            ON covtp.reg_cover_type_class = reg.code
            AND reg.record_valid_from <= v_reporting_date
            AND nvl(reg.record_valid_until,utilities.record_default_date) > v_reporting_date
          LEFT JOIN dwh_cover_fact amt_fact_ccrb
            ON cov.cover_key = amt_fact_ccrb.cover_key
            AND amt_fact_ccrb.record_valid_from = v_reporting_date
            AND amt_fact_ccrb.amt_type = 'CCRB'
          LEFT JOIN dwh_cover_amount_org amt_orig_ccro
            ON cov.cover_key = amt_orig_ccro.cover_key
            AND amt_orig_ccro.record_valid_from = v_reporting_date
            AND amt_orig_ccro.amount_type = 'CCRO'
            AND amt_orig_ccro.system_id = cov.system_id
          LEFT JOIN dwh_cover_amount_org amt_orig_cmvo
            ON cov.cover_key = amt_orig_cmvo.cover_key
            AND amt_orig_cmvo.record_valid_from = v_reporting_date
            AND amt_orig_cmvo.amount_type = 'CMVO'
            AND amt_orig_cmvo.system_id = cov.system_id 
          LEFT JOIN dwh_cover_amount_org amt_orig_ccao
            ON cov.cover_key = amt_orig_ccao.cover_key
            AND amt_orig_ccao.record_valid_from = v_reporting_date
            AND amt_orig_ccao.amount_type = 'CCAO'
            AND amt_orig_ccao.system_id = cov.system_id 
          LEFT JOIN dwh_cover_amount_org amt_orig_cvpo
            ON cov.cover_key = amt_orig_cvpo.cover_key
            AND amt_orig_cvpo.record_valid_from = v_reporting_date
            AND amt_orig_cvpo.amount_type = 'CVPO'
            AND amt_orig_cvpo.system_id = cov.system_id
          LEFT JOIN dwh_cover_amount_org amt_orig_ccso
            ON cov.cover_key = amt_orig_ccso.cover_key
            AND amt_orig_ccso.record_valid_from = v_reporting_date
            AND amt_orig_ccso.amount_type = 'CCSO'
            AND amt_orig_ccso.system_id = cov.system_id
          LEFT JOIN tt_anacredit_vre_amounts amt_ana
            ON cov.cover_key = amt_ana.cover_key
          LEFT JOIN dwh_cover_amount_org amt_orig_ccso
            ON cov.cover_key = amt_orig_ccso.cover_key
            AND amt_orig_ccso.record_valid_from = v_reporting_date
            AND amt_orig_ccso.amount_type = 'CCSO'
            AND amt_orig_ccso.system_id = cov.system_id
          LEFT JOIN country ctry
            ON cov.cover_ctry_key = ctry.country_key
          LEFT JOIN dwh_cover_amount_org amt_orig_ccgo
            ON cov.cover_key = amt_orig_ccgo.cover_key
            AND amt_orig_ccgo.record_valid_from = v_reporting_date
            AND amt_orig_ccgo.amount_type = 'CCGO'
            AND amt_orig_ccgo.system_id = cov.system_id
          LEFT JOIN dwh_cover_amount_org amt_orig_cplo
            ON cov.cover_key = amt_orig_cplo.cover_key
            AND amt_orig_cplo.record_valid_from <= v_reporting_date
            AND nvl(amt_orig_cplo.record_valid_until,utilities.record_default_date) > v_reporting_date
            AND amt_orig_cplo.amount_type = 'CPLO'
            AND amt_orig_cplo.system_id = cov.system_id
          LEFT JOIN dwh_exchange_rate exch_rt
            ON (  CASE
            WHEN amt_fact_ccrb.cover_perc IS NULL THEN CASE
              WHEN amt_orig_cmvo.currency_key IS NOT NULL THEN amt_orig_cmvo.currency_key
              WHEN amt_orig_ccgo.currency_key IS NOT NULL THEN amt_orig_ccgo.currency_key
              WHEN amt_orig_ccso.currency_key IS NOT NULL THEN amt_orig_ccso.currency_key --continuous catchup
              WHEN amt_orig_ccao.currency_key IS NOT NULL THEN amt_orig_ccao.currency_key -- 8.8.640
                              WHEN amt_orig_cvpo.currency_key IS NOT NULL THEN amt_orig_cvpo.currency_key -- 8.8.640
              ELSE amt_orig_ccro.currency_key
            END
            ELSE v_eurcurrencykey
            END ) = exch_rt.currency_key
            AND exch_rt.source = 'SIS'
            AND exch_rt.record_valid_from <= v_reporting_date
            AND nvl(exch_rt.record_valid_until,utilities.record_default_date) > v_reporting_date
            AND ( CASE
            WHEN amt_fact_ccrb.cover_perc IS NULL THEN CASE
              WHEN amt_orig_cmvo.currency_key IS NOT NULL THEN amt_orig_cmvo.batch_id
              WHEN amt_orig_ccgo.currency_key IS NOT NULL THEN amt_orig_ccgo.batch_id
              WHEN amt_orig_ccso.currency_key IS NOT NULL THEN amt_orig_ccso.batch_id --continuous catchup
              WHEN amt_orig_ccao.currency_key IS NOT NULL THEN amt_orig_ccao.batch_id -- 8.8.640
                              WHEN amt_orig_cvpo.currency_key IS NOT NULL THEN amt_orig_cvpo.batch_id -- 8.8.640
              ELSE amt_orig_ccro.batch_id
            END
            ELSE amt_fact_ccrb.batch_id
            END ) = exch_rt.batch_id
          LEFT JOIN dmb_reg_protection_incep incep
            ON cov.cover_id = incep.cover_id
            AND cov.system_id = incep.system_id
            AND cov.cover_start_date = incep.cover_start_date
            AND cov.cover_start_date = incep.limit_start_date
          LEFT JOIN dwh_cover_amount_org         amt_incep_ccro
            ON incep.cover_key_ccro_incep = amt_incep_ccro.cover_key
            AND amt_incep_ccro.amount_type = 'CCRO' -- 8.8.640
          LEFT JOIN dwh_cover_amount_org amt_incep_cmvo
            ON incep.cover_key_cmvo_incep = amt_incep_cmvo.cover_key
            AND amt_incep_cmvo.amount_type = 'CMVO' -- 8.8.640
          LEFT JOIN dwh_cover_amount_org amt_incep_ccgo
            ON incep.cover_key_ccgo_incep = amt_incep_ccgo.cover_key
            AND amt_incep_ccgo.amount_type = 'CCGO' -- 8.8.640
          LEFT JOIN dwh_cover_amount_org  amt_incep_ccso ON incep.cover_key_ccso_incep = amt_incep_ccso.cover_key
            AND amt_incep_ccso.amount_type = 'CCSO' -- 8.8.640
          LEFT JOIN dwh_exchange_rate incep_exch_rt  
            ON (CASE WHEN amt_fact_ccrb.cover_perc IS NULL
                    THEN
                      CASE
                        WHEN amt_incep_cmvo.currency_key IS NOT NULL THEN amt_incep_cmvo.currency_key
                        WHEN amt_incep_ccgo.currency_key IS NOT NULL THEN amt_incep_ccgo.currency_key
                        WHEN amt_incep_ccso.currency_key IS NOT NULL THEN amt_incep_ccso.currency_key
                        WHEN amt_orig_ccao.currency_key IS NOT NULL THEN amt_orig_ccao.currency_key -- 8.8.640
                        WHEN amt_orig_cvpo.currency_key IS NOT NULL THEN amt_orig_cvpo.currency_key -- 8.8.640
                        WHEN amt_incep_ccro.currency_key IS NOT NULL THEN amt_incep_ccro.currency_key -- 8.8.640
                        --ELSE amt_incep_ccro.currency_key
                        ELSE v_eurcurrencykey
                      END
                    --ELSE v_eurcurrencykey
                END) = incep_exch_rt.currency_key
            AND incep_exch_rt.source = 'SIS'
            AND (CASE WHEN amt_fact_ccrb.cover_perc iS NULL
                  THEN
                    CASE
                      WHEN amt_incep_cmvo.currency_key IS NOT NULL THEN amt_incep_cmvo.batch_id
                      WHEN amt_incep_ccgo.currency_key IS NOT NULL THEN amt_incep_ccgo.batch_id
                      WHEN amt_incep_ccso.currency_key IS NOT NULL THEN amt_incep_ccso.batch_id
                      WHEN amt_orig_ccao.currency_key IS NOT NULL THEN amt_orig_ccao.batch_id -- 8.8.640
                      WHEN amt_orig_cvpo.currency_key IS NOT NULL THEN amt_orig_cvpo.batch_id -- 8.8.640
                      when  amt_incep_ccro.currency_key IS NOT NULL THEN amt_incep_ccro.batch_id-- 8.8.640
                      --ELSE amt_incep_ccro.batch_id
                      ELSE amt_fact_ccrb.batch_id
                    END
                  --ELSE amt_fact_ccrb.batch_id
              END) = incep_exch_rt.batch_id
          LEFT JOIN cte_cre_cov 	cre_cov
            ON cre_cov.cover_key = cov.cover_key
          WHERE reg.anacredit_protection_type <> 'NONANACREDIT'
          AND covtp.ira_purpose NOT IN ( 'ICG','LLG')
          GROUP BY cov.record_valid_from, cov.system_id
          
        ------SRT | --8.8.750 start
          UNION  ---Securitization ADD protection
              select 
                cov.record_valid_from as reporting_date ,                                                             --reporting_date
                cov.system_id  as  system_id,                                                                         --system_id
                COUNT(DISTINCT cov.cover_key) as prot_cnt_cover,                                                      --prot_cnt_cover
                COUNT(1) as  cover_counts,                                                                            --cover_counts

                SUM(st.current_tranche_size)  as n_mitigant_value ,                                                                        --mitigants

                SUM(1) as  fx_rate ,                                                                                  --fx_rate
                SUM(NVL(amt_orig_cplo.cover_amount, 0))  as priority_amt ,                                            --priority_amt
                                                      
                SUM(sum_fin_coll.n_fin_coll_adjusted_amount ) as adjusted_amount ,                                    --adjusted_amount
                SUM(sum_fin_coll.n_fin_coll_adjusted_amount) as realizable_la_amount ,                                --realizable_la_amount
                SUM(sum_cap_req.n_realizable_amount_cap_req)   as realizable_cap_amount ,                             --n_realizable_amount_cap_req
                SUM(NVL(sum_liq_val.n_liquidation_value ,0))  as  liquidation ,                                        --liquidation | both cover and asset records
            
                SUM(
                      CASE WHEN amt_fact_ccrb.cover_perc IS NULL AND NVL(exch_rt.exchange_rate,0) <> 0
                      THEN CASE WHEN amt_orig_cmvo.cover_key IS NOT NULL
                                THEN CASE WHEN NVL(amt_orig_cmvo.cover_amount,0) <> 0
                                        THEN amt_orig_cmvo.cover_amount/exch_rt.exchange_rate
                                        ELSE 0
                                    END
                                WHEN amt_orig_ccgo.cover_key IS NOT NULL
                                THEN CASE WHEN NVL(amt_orig_ccgo.cover_amount,0) <> 0
                                        THEN amt_orig_ccgo.cover_amount/exch_rt.exchange_rate
                                        ELSE 0
                                    END
                                WHEN amt_orig_ccso.cover_key IS NOT NULL
                                THEN CASE WHEN NVL(amt_orig_ccso.cover_amount,0) <> 0
                                        THEN amt_orig_ccso.cover_amount/exch_rt.exchange_rate
                                        ELSE 0
                                        END
                                WHEN amt_orig_ccro.cover_key IS NOT NULL
                                THEN CASE WHEN NVL(amt_orig_ccro.cover_amount,0) <> 0
                                        THEN amt_orig_ccro.cover_amount/exch_rt.exchange_rate
                                        ELSE 0
                                    END
                        END
                      WHEN amt_fact_ccrb.cover_perc IS NOT NULL AND NVL(exch_rt.exchange_rate,0) <> 0
                      THEN
                        CASE WHEN NVL(amt.alloc_available_amt_after_index,0) <> 0
                                THEN amt.alloc_available_amt_after_index/exch_rt.exchange_rate
                                ELSE 0
                        END
                      ELSE 0
                      END 
                ) as  mitigant_eur ,                                                                         --n_mitigant_value_eur    

                  SUM(NVL(cre_cov.interest_coverage_ratio,0))  as coverage_ratio ,                                    --coverage_ratio
                  SUM(NVL(cre_cov.debt_service_coverage_ratio,0)) as dept_coverage_ratio,                             --dept_coverage_ratio
                  SUM(NVL(cre_cov.gross_annual_rental_income ,0))  as   rental_income,                                 --rental_income
                  SUM(NVL(cre_cov.annual_rental_value,0))    as      rental_value,                                    --rental_value
                  SUM(NVL(cre_cov.annual_rental_costs,0))   as    rental_costs,                                       --rental_costs
                  SUM(NVL(cre_cov.net_annual_rental_income,0))  as  net_rental_income,                                --net_rental_income

                  SUM(st.original_tranche_size)  AS mitigant_value,                                                                           --mitigant_value (n_orig_mitigant_value)

                  SUM(1) AS orig_fx_rate ,                                                                                --orig_fx_rate (orig_fx_rate)

                  SUM(
                      CASE WHEN amt_fact_ccrb.cover_perc IS NOT NULL
                      THEN amt_ana.alloc_amt_after_index_csd
                      WHEN amt_fact_ccrb.cover_perc IS NULL AND amt_orig_ccao.cover_key IS NOT NULL AND exch_rt.exchange_rate IS NOT NULL AND exch_rt.exchange_rate <> 0
                      THEN (amt_orig_ccao.cover_amount / exch_rt.exchange_rate)
                      WHEN amt_fact_ccrb.cover_perc IS NULL AND amt_orig_cvpo.cover_key IS NOT NULL AND exch_rt.exchange_rate IS NOT NULL AND exch_rt.exchange_rate <> 0
                      THEN (amt_orig_cvpo.cover_amount / exch_rt.exchange_rate)
                      WHEN amt_fact_ccrb.cover_perc IS NULL AND amt_incep_cmvo.cover_key IS NOT NULL AND incep_exch_rt.exchange_rate IS NOT NULL AND incep_exch_rt.exchange_rate <> 0
                      THEN (amt_incep_cmvo.cover_amount / incep_exch_rt.exchange_rate)  -- Inception
                      WHEN amt_fact_ccrb.cover_perc IS NULL AND amt_incep_ccgo.cover_key IS NOT NULL AND incep_exch_rt.exchange_rate IS NOT NULL AND incep_exch_rt.exchange_rate <> 0
                      THEN (amt_incep_ccgo.cover_amount / incep_exch_rt.exchange_rate)  -- Inception
                      WHEN amt_fact_ccrb.cover_perc IS NULL AND amt_incep_ccso.cover_key IS NOT NULL AND incep_exch_rt.exchange_rate IS NOT NULL AND incep_exch_rt.exchange_rate <> 0
                      THEN (amt_incep_ccso.cover_amount / incep_exch_rt.exchange_rate)  -- Inception
                      WHEN amt_fact_ccrb.cover_perc IS NULL AND amt_incep_ccro.cover_key IS NOT NULL AND incep_exch_rt.exchange_rate IS NOT NULL AND incep_exch_rt.exchange_rate <> 0
                      THEN (amt_incep_ccro.cover_amount / incep_exch_rt.exchange_rate)  -- Inception
                      ELSE amt_ana.alloc_amt_after_index_csd
                      END
                  )  AS orig_mitigant                                                                               --orig_mitigant(n_orig_mitigant_value_eur)
            ---!!! BASED ON THE CURRENT SECURITISATION DESIGN SPECIFIC FOR PROTECTION PROVIDER AND UNDERLYING LOGIC | 7442527 - Starts Here
        FROM ( SELECT *                                                                          --PROTECTION PROVIDER
                FROM DWH_COVER 
                WHERE COVER_PROVIDER IS NOT NULL
                    AND RECORD_VALID_FROM = V_REPORTING_DATE
                    )COV

        JOIN DWH_FACILITY FAC
            ON COV.FACILITY_KEY = FAC.FACILITY_KEY
            AND FAC.RECORD_VALID_FROM = V_REPORTING_DATE

        JOIN SECURITISATION_TRANCHE ST                                                           --UNDERLYING FACILITIES
            ON FAC.FACILITY_ID = ST.FACILITY_ID
            --AND FAC.SYSTEM_ID = ST.SYSTEM_ID
            AND ST.RECORD_VALID_FROM <= V_REPORTING_DATE
            AND NVL(ST.RECORD_VALID_UNTIL,UTILITIES.RECORD_DEFAULT_DATE) > V_REPORTING_DATE

        JOIN DWH_SECURITISED_FACILITY DSF                                                        --UNDERLYING FACILITIES
            ON DSF.SECURITISATION_CODE = ST.SECURITISATION_CODE
            AND DSF.RECORD_VALID_FROM <= V_REPORTING_DATE
            AND NVL(DSF.RECORD_VALID_UNTIL,UTILITIES.RECORD_DEFAULT_DATE) > V_REPORTING_DATE

        JOIN SECURITISATION_LEGAL_ENTITY SLE                                                     --SECURITISATION CODES (E.G Simba2,Simba3)
            ON ST.SECURITISATION_CODE = SLE.CODE        
            AND SLE.RECORD_VALID_FROM <= V_REPORTING_DATE
            AND NVL(SLE.RECORD_VALID_UNTIL,UTILITIES.RECORD_DEFAULT_DATE) > V_REPORTING_DATE
            AND SLE.ANACREDIT_ELIGIBLE = 'Y'

        ---!!! TO FILL VALUES FOR THE RESPECTIVE TARGET COLUMNS. AS PER BRED LOGIC OR ALREADY EXISTS IN ANACREDIT BASED ON PREVIOUS REQUIREMENTS
        ------ ADDITIONAL JOIN WITH FAC_HEIR & AMT FOR SECURITIZATION
        JOIN TT_SCOPE FAC_HEIR
            ON COV.FACILITY_KEY = FAC_HEIR.FACILITY_KEY_LINK
        JOIN TT_COVER_AMOUNTS_HC AMT
            ON COV.COVER_KEY = AMT.COVER_KEY

        ------ BELOW FOUR TABLES ARE BEING USED TO FILL VALUES FOR RESPECTIVE COLUMNS AS IT IS IN BRED
        JOIN SUM_FIN_COLL ON SUM_FIN_COLL.COVER_KEY = COV.COVER_KEY
        JOIN SUM_REL ON COV.COVER_KEY = SUM_REL.COVER_KEY
        JOIN SUM_CAP_REQ ON COV.COVER_KEY = SUM_CAP_REQ.COVER_KEY
        JOIN SUM_LIQ_VAL ON COV.COVER_KEY = SUM_LIQ_VAL.COVER_KEY
        ------
        JOIN COVER_TYPE COVTP 
            ON COV.COVER_TYPE_KEY = COVTP.COVER_TYPE_KEY
        JOIN COVER_TYPE COV_TYP
            ON COVTP.HIGHEST_LEVEL_KEY = COV_TYP.COVER_TYPE_KEY
          -- AND COV_TYP.CODE = 'GTY'
        ------
        JOIN DWH_COVER_FACT fact
            ON cov.cover_key = fact.cover_key
            AND fact.amt_type = 'CCRB'
            AND fact.record_valid_from = v_reporting_date
        ------ ADDITIONAL JOIN WITH AMT_ORIG_CPLO FOR SECURITIZATION    
        LEFT JOIN dwh_cover_amount_org amt_orig_cplo
            ON cov.cover_key = amt_orig_cplo.cover_key
            AND amt_orig_cplo.record_valid_from <= v_reporting_date                              
            --AND amt_orig_cplo.record_valid_from = v_reporting_date                            -- Changed for 2507876#
            AND nvl(amt_orig_cplo.record_valid_until,utilities.record_default_date) > v_reporting_date
            AND amt_orig_cplo.amount_type = 'CPLO'

      ------ ADDITIONAL JOIN WITH IRA_COV FOR SECURITIZATION
        LEFT JOIN DMB_REG_IRA_COVER IRA_COV
            ON COV.COVER_KEY = IRA_COV.POST_IRA_COVER_KEY
        LEFT JOIN COVER_ID_MAPPING MAPP
            ON COV.SYSTEM_ID = MAPP.SYSTEM_ID                                                   --LEFT JOIN NEEDED (ONLY GENERATED COVERS IN TABLE)
            AND COV.COVER_ID = MAPP.GENERATED_COVER_ID
            AND COV.FACILITY_ID = MAPP.FACILITY_ID
        ------
        LEFT JOIN REG_COVER_TYPE_CLASS REG
            ON COVTP.REG_COVER_TYPE_CLASS = REG.CODE
            AND REG.RECORD_VALID_FROM <= V_REPORTING_DATE
            AND NVL(REG.RECORD_VALID_UNTIL,UTILITIES.RECORD_DEFAULT_DATE) > V_REPORTING_DATE

        ------ ADDITIONAL JOIN WITH AMT_ORIG_CMVO,AMT_ORIG_CCAO,AMT_ORIG_CVPO,AMT_ANA,AMT_ORIG_CCGO,AMT_ORIG_CCSO,AMT_FACT_CCRB,AMT_ORIG_CCRO FOR SECURITIZATION
        LEFT JOIN dwh_cover_amount_org amt_orig_cmvo
            ON cov.cover_key = amt_orig_cmvo.cover_key
            AND amt_orig_cmvo.record_valid_from = v_reporting_date
            AND amt_orig_cmvo.amount_type = 'CMVO'
        LEFT JOIN dwh_cover_amount_org amt_orig_ccao
            ON cov.cover_key = amt_orig_ccao.cover_key
            AND amt_orig_ccao.record_valid_from = v_reporting_date
            AND amt_orig_ccao.amount_type = 'CCAO'                                              -- 8.8.640
        LEFT JOIN dwh_cover_amount_org amt_orig_cvpo
            ON cov.cover_key = amt_orig_cvpo.cover_key
            AND amt_orig_cvpo.record_valid_from = v_reporting_date
            AND amt_orig_cvpo.amount_type = 'CVPO'                                              -- 8.8.640
        LEFT JOIN tt_anacredit_vre_amounts amt_ana
            ON cov.cover_key = amt_ana.cover_key                                                -- 8.8.640
        LEFT JOIN dwh_cover_amount_org amt_orig_ccgo
            ON cov.cover_key = amt_orig_ccgo.cover_key
            AND amt_orig_ccgo.record_valid_from = v_reporting_date
            AND amt_orig_ccgo.amount_type = 'CCGO'
        LEFT JOIN dwh_cover_amount_org amt_orig_ccso
            ON cov.cover_key = amt_orig_ccso.cover_key                                          --continuous catchup
            AND amt_orig_ccso.record_valid_from = v_reporting_date
            AND amt_orig_ccso.amount_type = 'CCSO'
        LEFT JOIN dwh_cover_fact amt_fact_ccrb
            ON cov.cover_key = amt_fact_ccrb.cover_key
            AND amt_fact_ccrb.record_valid_from = v_reporting_date
            AND amt_fact_ccrb.amt_type = 'CCRB'
        LEFT JOIN dwh_cover_amount_org amt_orig_ccro
            ON cov.cover_key = amt_orig_ccro.cover_key
            AND amt_orig_ccro.record_valid_from = v_reporting_date
            AND amt_orig_ccro.amount_type = 'CCRO'
        ------ ADDITIONAL JOIN WITH  EXCH_RT FOR SECURITIZATION
        LEFT JOIN dwh_exchange_rate exch_rt
            ON (  CASE
            WHEN amt_fact_ccrb.cover_perc IS NULL THEN CASE
                WHEN amt_orig_cmvo.currency_key IS NOT NULL THEN amt_orig_cmvo.currency_key
                WHEN amt_orig_ccgo.currency_key IS NOT NULL THEN amt_orig_ccgo.currency_key
                WHEN amt_orig_ccso.currency_key IS NOT NULL THEN amt_orig_ccso.currency_key      --continuous catchup
                WHEN amt_orig_ccao.currency_key IS NOT NULL THEN amt_orig_ccao.currency_key      -- 8.8.640
                WHEN amt_orig_cvpo.currency_key IS NOT NULL THEN amt_orig_cvpo.currency_key      -- 8.8.640
                ELSE amt_orig_ccro.currency_key
            END
            ELSE v_eurcurrencykey
            END ) = exch_rt.currency_key
            AND exch_rt.source = 'SIS'
            AND exch_rt.record_valid_from <= v_reporting_date
            AND nvl(exch_rt.record_valid_until,utilities.record_default_date) > v_reporting_date
            --AND ( exch_rt.record_valid_until > v_reporting_date OR exch_rt.record_valid_until IS NULL )
            AND ( CASE
            WHEN amt_fact_ccrb.cover_perc IS NULL THEN CASE
                WHEN amt_orig_cmvo.currency_key IS NOT NULL THEN amt_orig_cmvo.batch_id
                WHEN amt_orig_ccgo.currency_key IS NOT NULL THEN amt_orig_ccgo.batch_id
                WHEN amt_orig_ccso.currency_key IS NOT NULL THEN amt_orig_ccso.batch_id         --continuous catchup
                WHEN amt_orig_ccao.currency_key IS NOT NULL THEN amt_orig_ccao.batch_id         -- 8.8.640
                WHEN amt_orig_cvpo.currency_key IS NOT NULL THEN amt_orig_cvpo.batch_id         -- 8.8.640
                ELSE amt_orig_ccro.batch_id
            END
            ELSE amt_fact_ccrb.batch_id
            END ) = exch_rt.batch_id
        ------ ADDITIONL JOIN WITH INCEP FOR SECURITIZATION
        LEFT JOIN dmb_reg_protection_incep incep
            ON cov.cover_id = incep.cover_id
            AND cov.system_id = incep.system_id
            AND cov.cover_start_date = incep.cover_start_date
            AND cov.cover_start_date = incep.limit_start_date

        ------ ADDITIONL JOIN WITH AMT_INCEP_CCRO,AMT_INCEP_CMVO,AMT_INCEP_CCGO & AMT_INCEP_CCSO FOR SECURITIZATION
        LEFT JOIN dwh_cover_amount_org amt_incep_ccro
            ON incep.cover_key_ccro_incep = amt_incep_ccro.cover_key
            --AND amt_incep_ccro.record_valid_from = v_reporting_date
            AND amt_incep_ccro.amount_type = 'CCRO'                                             -- 8.8.640
        LEFT JOIN dwh_cover_amount_org amt_incep_cmvo
            ON incep.cover_key_cmvo_incep = amt_incep_cmvo.cover_key
            -- AND amt_incep_cmvo.record_valid_from = v_reporting_date
            AND amt_incep_cmvo.amount_type = 'CMVO'                                             -- 8.8.640
        LEFT JOIN dwh_cover_amount_org amt_incep_ccgo
            ON incep.cover_key_ccgo_incep = amt_incep_ccgo.cover_key
            --AND amt_incep_ccgo.record_valid_from = v_reporting_date
            AND amt_incep_ccgo.amount_type = 'CCGO'                                             -- 8.8.640
        LEFT JOIN dwh_cover_amount_org amt_incep_ccso 
            ON incep.cover_key_ccso_incep = amt_incep_ccso.cover_key
            --AND amt_incep_ccso.record_valid_from = v_reporting_date
            AND amt_incep_ccso.amount_type = 'CCSO'      

        ------ ADDITIONL JOIN WITH INCEP_EXCH_RT FOR SECURITIZATION
        LEFT JOIN dwh_exchange_rate incep_exch_rt  
            ON (CASE WHEN amt_fact_ccrb.cover_perc IS NULL
                    THEN
                    CASE
                        WHEN amt_incep_cmvo.currency_key IS NOT NULL THEN amt_incep_cmvo.currency_key
                        WHEN amt_incep_ccgo.currency_key IS NOT NULL THEN amt_incep_ccgo.currency_key
                        WHEN amt_incep_ccso.currency_key IS NOT NULL THEN amt_incep_ccso.currency_key
                        WHEN amt_orig_ccao.currency_key IS NOT NULL THEN amt_orig_ccao.currency_key -- 8.8.640
                        WHEN amt_orig_cvpo.currency_key IS NOT NULL THEN amt_orig_cvpo.currency_key -- 8.8.640
                        WHEN amt_incep_ccro.currency_key IS NOT NULL THEN amt_incep_ccro.currency_key -- 8.8.640
                        --ELSE amt_incep_ccro.currency_key
                        ELSE v_eurcurrencykey
                    END
                    --ELSE v_eurcurrencykey
                END) = incep_exch_rt.currency_key
            AND incep_exch_rt.source = 'SIS'
            --AND incep_exch_rt.record_valid_from <= v_reporting_date
            --AND (incep_exch_rt.record_valid_until > v_reporting_date OR incep_exch_rt.record_valid_until IS NULL)
            AND (CASE WHEN amt_fact_ccrb.cover_perc iS NULL
                THEN
                CASE
                    WHEN amt_incep_cmvo.currency_key IS NOT NULL THEN amt_incep_cmvo.batch_id
                    WHEN amt_incep_ccgo.currency_key IS NOT NULL THEN amt_incep_ccgo.batch_id
                    WHEN amt_incep_ccso.currency_key IS NOT NULL THEN amt_incep_ccso.batch_id
                    WHEN amt_orig_ccao.currency_key IS NOT NULL THEN amt_orig_ccao.batch_id     -- 8.8.640
                    WHEN amt_orig_cvpo.currency_key IS NOT NULL THEN amt_orig_cvpo.batch_id     -- 8.8.640
                    when  amt_incep_ccro.currency_key IS NOT NULL THEN amt_incep_ccro.batch_id  -- 8.8.640
                    --ELSE amt_incep_ccro.batch_id
                    ELSE amt_fact_ccrb.batch_id
                END
                --ELSE amt_fact_ccrb.batch_id
            END) = incep_exch_rt.batch_id
        ------ ADDITIONAL JOIN WITH CRE_COV FOR SECURITIZATION
        LEFT JOIN dwh_cre_cover cre_cov
            ON cre_cov.cover_key = cov.cover_key
            AND cre_cov.record_valid_from = v_reporting_date -- MK partitions
                  -- BASED ON THE CURRENT SECURITISATION DESIGN | 7460162
        WHERE EXISTS(  SELECT 1                                                                 --ENABLING THE SECURITISATION RECORD
                        FROM control_parameter fpr
                        WHERE  fpr.code = 'ANACREDIT_SEC'
                        and fpr.record_valid_from <= V_REPORTING_DATE
                        AND ( nvl(fpr.record_valid_until,UTILITIES.RECORD_DEFAULT_DATE) > V_REPORTING_DATE )
                        AND fpr.indicator_value = 'Y'
                        )
            AND REG.ANACREDIT_PROTECTION_TYPE <> 'NONANACREDIT'
        GROUP BY cov.record_valid_from, cov.system_id;

      v_count := SQL%ROWCOUNT;
      COMMIT;

      schema_maint.gather_idx_stats('TMP_VDD_DWH_PROT_RECON_COVER');
      vde_log(v_export_id, v_proc_name, v_reporting_date, v_start, 1, 'Inserted data to TMP_VDD_DWH_PROT_RECON. Row count:' || v_count);

      v_debug_msg := $$plsql_line|| ' OF PLSQL UNIT '|| $$plsql_unit||' rowcount >> '|| v_count;
      utilities.show_debug(v_debug_msg);

      EXCEPTION
      WHEN OTHERS THEN
      utils.handleerror(SQLCODE,SQLERRM);
    END;

---------------------------- Ended here for cover...

/*Collect similar values from protection dwh tables for asset records */
/*Create following temp tables being used in joins*/
/*Create temp table with unique asset records by selecting the highest mitigant_value with lowest cover_key per asset_key*/


    BEGIN
      v_start := SYSDATE;
      utilities.truncate_table('tt_vdd_asset_records');
    
      INSERT/*+ APPEND enable_parallel_dml */ INTO tt_vdd_asset_records (
      SELECT DISTINCT leading_cover_key,asset_key,n_mitigant_value_eur
        FROM
        (
        SELECT /*+ parallel +*/ asset_key
              ,max_n_mitigant_value_eur AS n_mitigant_value_eur
              ,case when max_n_mitigant_value_eur = n_mitigant_value_eur then leading_cover_key
                    else null
                end AS leading_cover_key
        FROM
        (
            SELECT --MIN(pt.cover_key)  leading_cover_key ,
                  pt.asset_key asset_key ,
                  max(pt.n_mitigant_value_eur) over (partition by pt.asset_key) AS max_n_mitigant_value_eur
                  ,n_mitigant_value_eur
                  ,min(pt.cover_key)over (partition by pt.asset_key,n_mitigant_value_eur) leading_cover_key
                        FROM dmb_reg_protection_dmart pt
                      WHERE pt.asset_id IS NOT NULL
                    AND pt.record_create_step = 'initial_load'
                    AND pt.highest_level_indicator = 'N'
                    AND pt.reporting_date = v_reporting_date
          )
        )
      WHERE leading_cover_key IS NOT NULL);


      v_count := SQL%ROWCOUNT;
      COMMIT;

      schema_maint.gather_idx_stats('tt_vdd_asset_records');
      vde_log(v_export_id, v_proc_name, v_reporting_date, v_start, 1, 'Inserted data to tt_vdd_asset_records. Row count:' || v_count);

      v_debug_msg := $$plsql_line|| ' OF PLSQL UNIT '|| $$plsql_unit||' rowcount >> '|| v_count;
      utilities.show_debug(v_debug_msg);

      EXCEPTION
      WHEN OTHERS THEN
      utils.handleerror(SQLCODE,SQLERRM);
    END;



 --Create temp table on asset level by aggregate the underlying cover amounts
    BEGIN
      v_start := SYSDATE;
      utilities.truncate_table('tt_vdd_calc_amounts');

      INSERT/*+ APPEND enable_parallel_dml */ INTO tt_vdd_calc_amounts (
        SELECT/*+ parallel +*/ asset_key ,
                MAX(f_generated_flg)  max_generated_flg ,
                COUNT(DISTINCT v_mitigant_ccy_cd)  count_ccy_cd ,
                SUM(n_mitigant_value)  sum_mitigant_value ,
                SUM(n_mitigant_value_eur)  sum_mitigant_value_eur ,
                MIN(v_orig_mitigant_cd)  min_original_cover_id ,
                MIN(v_reason_for_gen)  min_reason_for_gen ,
                SUM(n_tot_priority_claim_amt)  sum_tot_priority_claim_amt ,
                SUM(n_fin_coll_adjusted_amount)  sum_fin_coll_adjusted_amount ,
                SUM(n_realizable_amount_la_r)  sum_realizable_amount_la_r ,
                SUM(n_realizable_amount_cap_req)  sum_realizable_amount_cap_req ,
                SUM(n_liquidation_value)  sum_liquidation_value ,
                SUM(n_fair_value)  sum_fair_value,
                MAX(f_cre_scope_ind) f_cre_scope_ind , -- 8.8.601
                MAX(f_ana_scope_ind) f_ana_scope_ind  -- 8.8.601
          FROM dmb_reg_protection_dmart
          WHERE  asset_id IS NOT NULL
                  AND record_create_step = 'initial_load'
                  AND highest_level_indicator = 'N'
                  AND reporting_date = v_reporting_date
          GROUP BY asset_key );
      v_count := SQL%ROWCOUNT;
      COMMIT;

      schema_maint.gather_idx_stats('tt_vdd_calc_amounts');
      vde_log(v_export_id, v_proc_name, v_reporting_date, v_start, 1, 'Inserted data to tt_vdd_calc_amounts. Row count:' || v_count);

      v_debug_msg := $$plsql_line|| ' OF PLSQL UNIT '|| $$plsql_unit||' rowcount >> '|| v_count;
      utilities.show_debug(v_debug_msg);

      EXCEPTION
      WHEN OTHERS THEN
      utils.handleerror(SQLCODE,SQLERRM);
    END;

    BEGIN
      v_start := SYSDATE;
      utilities.truncate_table('tt_anacredit_diff_currencies');
    

      INSERT /*+ APPEND */ INTO tt_anacredit_diff_currencies
        SELECT asset_key,
              COUNT(*) AS currencies
        --INTO #anacredit_diff_currencies
        FROM (
              SELECT DISTINCT asset_key,
                    v_orig_mitigant_value_ccy_cd
              FROM dmb_reg_protection_dmart
              where f_ana_scope_ind IS NOT NULL
                AND asset_key IS NOT NULL
        )t
        GROUP BY asset_key
        HAVING COUNT(*) > 1;
        v_count := SQL%ROWCOUNT;
        COMMIT;

      schema_maint.gather_idx_stats('tt_anacredit_diff_currencies');
      vde_log(v_export_id, v_proc_name, v_reporting_date, v_start, 1, 'Inserted data to tt_anacredit_diff_currencies. Row count:' || v_count);

      v_debug_msg := $$plsql_line|| ' OF PLSQL UNIT '|| $$plsql_unit||' rowcount >> '|| v_count;
      utilities.show_debug(v_debug_msg);

      EXCEPTION
      WHEN OTHERS THEN
      utils.handleerror(SQLCODE,SQLERRM);
    END;
        
    BEGIN
      v_start := SYSDATE;
      utilities.truncate_table('tt_anacredit_asset_sum');
    
    
      INSERT /*+ APPEND */ INTO tt_anacredit_asset_sum
        SELECT asset_key,
              SUM(n_orig_mitigant_value)     AS sum_orig,
              SUM(n_orig_mitigant_value_eur) AS sum_eur
        --INTO   #anacredit_asset_sum
        FROM dmb_reg_protection_dmart
        WHERE f_ana_scope_ind IS NOT NULL AND asset_key IS NOT NULL
        AND v_level_ind = 'A'
        GROUP BY asset_key;

      v_count := SQL%ROWCOUNT;
      COMMIT;

      schema_maint.gather_idx_stats('tt_anacredit_asset_sum');
      vde_log(v_export_id, v_proc_name, v_reporting_date, v_start, 1, 'Inserted data to tt_anacredit_asset_sum. Row count:' || v_count);

      v_debug_msg := $$plsql_line|| ' OF PLSQL UNIT '|| $$plsql_unit||' rowcount >> '|| v_count;
      utilities.show_debug(v_debug_msg);

      EXCEPTION
      WHEN OTHERS THEN
      utils.handleerror(SQLCODE,SQLERRM);
    END;


------ Asset Level Starts Here:
    BEGIN
      v_start := SYSDATE;
      utilities.truncate_table('TMP_VDD_DWH_PROT_RECON_ASSETS');
      INSERT INTO /*+ APPEND enable_parallel_dml */ TMP_VDD_DWH_PROT_RECON_ASSETS
            (reporting_date,system_id,prot_cnt_assets,assets_counts,mitigants,fx_rate,priority_amt,adjusted_amount,realizable_la_amount,realizable_cap_amount,occupancy_rate,rentable_surface,
            liquidation_perc,liquidation,fair,mitigant_eur,coverage_ratio,dept_coverage_ratio,rental_income,rental_value,rental_costs,net_rental_income,mitigant_value,
                orig_fx_rate,orig_mitigant)

              with temp_cover as ( SELECT cov.asset_key ,--8.8.652
                                    MIN(cov.batch_id)  asset_batch_id
                                FROM dwh_cover cov
                              WHERE cov.asset_id IS NOT NULL
                                AND cov.record_valid_from <= v_reporting_date
                    AND nvl(cov.record_valid_until,utilities.record_default_date) > v_reporting_date
                              GROUP BY cov.asset_key
                  ),
                temp_prot as ( SELECT asset_key ,--8.8.652
                                    MIN(d_maturity_date)  min_maturity_date
                                FROM dmb_reg_protection_dmart
                              WHERE asset_id IS NOT NULL
                                AND d_maturity_date > reporting_date
                                AND record_create_step = 'initial_load'
                                AND highest_level_indicator = 'N'
                              GROUP BY asset_key )
                select
                    v_reporting_date reporting_date ,                                             --reporting_date()
                    dmt.v_orig_src_system_id    AS system_id,                                     --system_id(v_orig_src_system_id)
                    COUNT(DISTINCT dmt.asset_id) as prot_cnt_assets,                              --prot_cnt_assets
                    COUNT(1) assets_counts,                                                       --assets_counts
                    SUM(
                        CASE WHEN amt_orig_cmvo.asset_key IS NOT NULL
                          THEN NVL(amt_orig_cmvo.asset_amount,0)
                          WHEN amt_orig_ccgo.asset_key IS NOT NULL
                          THEN NVL(amt_orig_ccgo.asset_amount,0)
                          WHEN amt_orig_ccso.asset_key IS NOT NULL
                          THEN NVL(amt_orig_ccso.asset_amount,0)
                          ELSE
                          CASE calc_amt.count_ccy_cd
                                WHEN 1
                                THEN NVL(calc_amt.sum_mitigant_value,0)
                                ELSE NVL(calc_amt.sum_mitigant_value_eur,0)
                          END
                      END
                      )  AS mitigant,                                                                             --mitigant(n_mitigant_value)
                    SUM( COALESCE(cmvo_exr.exchange_rate, ccgo_exr.exchange_rate, ccso_exr.exchange_rate,CASE calc_amt.count_ccy_cd WHEN 1 THEN dmt.n_fx_rate
                         ELSE euroexr.exchange_rate
                           END)) as fx_rate ,                                                                      --fx_rate(n_fx_rate)

                    SUM(NVL(cploamtorg.asset_amount, calc_amt.sum_tot_priority_claim_amt)) as priority_amt ,      --priority_amt(n_tot_priority_claim_amt)
                    SUM(NVL(calc_amt.sum_fin_coll_adjusted_amount,0)) as adjusted_amount ,                        --(n_fin_coll_adjusted_amount)
                    SUM(NVL(calc_amt.sum_realizable_amount_la_r,0))  as  realizable_la_amount ,                   --(n_realizable_amount_la_r)
                    SUM(NVL(calc_amt.sum_realizable_amount_cap_req,0)) as realizable_cap_amount ,                 --(n_realizable_amount_cap_req)
                    SUM(NVL(asset.occupancy_rate,0))  as  occupancy_rate ,                                        --(n_occupancy_rate)
                    SUM(NVL(round(asset.total_rentable_sfc, 0), 0)) as rentable_surface ,                         --(total_rentable_sfc)
                    SUM(NVL(dmt.n_exp_liquidation_costs,0)) as liquidation_perc ,                                 --(n_exp_liquidation_costs)
                    SUM(NVL(round(calc_amt.sum_liquidation_value, 0), 0)) as liquidation ,                        --(n_liquidation_value)
                    SUM(NVL(calc_amt.sum_fair_value,0)) as fair ,                                                 --(n_fair_value)

                    SUM(
                          CASE WHEN amt_orig_cmvo.asset_key IS NOT NULL--continuous catchup
                          THEN CASE WHEN NVL(amt_orig_cmvo.asset_amount,0) <> 0 AND NVL(cmvo_exr.exchange_rate,0) <> 0
                                    THEN ROUND(amt_orig_cmvo.asset_amount/cmvo_exr.exchange_rate,2)
                                    ELSE 0
                              END
                          WHEN amt_orig_ccgo.asset_key IS NOT NULL
                          THEN CASE WHEN NVL(amt_orig_ccgo.asset_amount,0) <> 0 AND NVL(ccgo_exr.exchange_rate,0) <> 0
                                    THEN ROUND(amt_orig_ccgo.asset_amount/ccgo_exr.exchange_rate,2)
                                    ELSE 0
                              END
                          WHEN amt_orig_ccso.asset_key IS NOT NULL
                          THEN CASE WHEN NVL(amt_orig_ccso.asset_amount,0) <> 0 AND NVL(ccso_exr.exchange_rate,0) <> 0
                                    THEN ROUND(amt_orig_ccso.asset_amount/ccso_exr.exchange_rate,2)
                                    ELSE 0
                              END
                          ELSE CASE calc_amt.count_ccy_cd
                                    WHEN 1
                                    THEN CASE WHEN NVL(calc_amt.sum_mitigant_value,0) <> 0 AND NVL(dmt.n_fx_rate,0) <> 0
                                              THEN ROUND(calc_amt.sum_mitigant_value/dmt.n_fx_rate,2)
                                              ELSE 0
                                        END
                                    ELSE CASE WHEN NVL(calc_amt.sum_mitigant_value_eur,0) <> 0
                                              THEN ROUND(calc_amt.sum_mitigant_value_eur,2)
                                        ELSE 0
                                        END
                              END
                      END
                        ) as  mitigant_eur ,                                                                   --(n_mitigant_value_eur)

                  SUM(NVL(NULL,0))                                                      AS coverage_ratio,
                  SUM(NVL(NULL,0))                                                      AS dept_coverage_ratio,
                  SUM(NVL(NULL,0))                                                      AS rental_income,
                  SUM(NVL(NULL,0))                                                      AS rental_value,
                  SUM(NVL(NULL,0))                                                      AS rental_costs,
                  SUM(NVL(NULL,0))                                                      AS net_rental_income,

                SUM(
                    CASE WHEN asset_amt_ccao.asset_key IS NOT NULL
                    THEN asset_amt_ccao.asset_amount
                    WHEN asset_amt_cvpo.asset_key IS NOT NULL
                    THEN asset_amt_cvpo.asset_amount
                    WHEN asset_incep_cmvo.asset_key IS NOT NULL  -- Inception
                    THEN asset_incep_cmvo.asset_amount
                    WHEN asset_incep_ccgo.asset_key IS NOT NULL  -- Inception
                    THEN asset_incep_ccgo.asset_amount
                    WHEN asset_incep_ccso.asset_key IS NOT NULL  -- Inception
                    THEN asset_incep_ccso.asset_amount
                    WHEN diff_curr.asset_key IS NOT NULL  -- v_orig_mitigant_ccy_cd not the same for all covers under this asset
                    THEN ana_sum.sum_eur
                    ELSE ana_sum.sum_orig                 -- v_orig_mitigant_ccy_cd the same for all covers under this asset
                    END       
                  )  AS mitigant_value ,                                                                      --(n_orig_mitigant_value)

                SUM(
                      CASE   WHEN asset_amt_fact_ccrb.cover_perc IS NULL AND asset_amt_ccao.asset_key IS NOT NULL
                      THEN ccaoexr.exchange_rate
                      WHEN asset_amt_fact_ccrb.cover_perc IS NULL AND asset_amt_cvpo.asset_key IS NOT NULL
                      THEN cvpoexr.exchange_rate
                      WHEN asset_amt_fact_ccrb.cover_perc IS NULL AND asset_incep_cmvo.asset_key IS NOT NULL  -- Inception
                      THEN cmvoexr.exchange_rate
                      WHEN asset_amt_fact_ccrb.cover_perc IS NULL AND asset_incep_ccgo.asset_key IS NOT NULL  -- Inception
                      THEN ccgoexr.exchange_rate
                      WHEN asset_amt_fact_ccrb.cover_perc IS NULL AND asset_incep_ccso.asset_key IS NOT NULL  -- Inception
                      THEN ccsoexr.exchange_rate
                      WHEN diff_curr.asset_key IS NOT NULL  -- v_orig_mitigant_ccy_cd not the same for all covers under this asset
                      THEN 1
                      ELSE dmt.n_orig_fx_rate END
                ) AS orig_fx_rate ,                                                                       --(n_orig_fx_rate))

                SUM(
                    CASE WHEN asset_amt_fact_ccrb.cover_perc IS NULL AND asset_amt_ccao.asset_key IS NOT NULL AND ccaoexr.exchange_rate IS NOT NULL AND ccaoexr.exchange_rate <> 0
                    THEN ROUND((asset_amt_ccao.asset_amount / ccaoexr.exchange_rate),2)
                    WHEN asset_amt_fact_ccrb.cover_perc IS NULL AND asset_amt_cvpo.asset_key IS NOT NULL AND cvpoexr.exchange_rate IS NOT NULL AND cvpoexr.exchange_rate <> 0
                    THEN ROUND((asset_amt_cvpo.asset_amount / cvpoexr.exchange_rate),2)
                    WHEN asset_amt_fact_ccrb.cover_perc IS NULL AND asset_incep_cmvo.asset_key IS NOT NULL AND cmvoexr.exchange_rate IS NOT NULL AND cmvoexr.exchange_rate <> 0
                    THEN ROUND((asset_incep_cmvo.asset_amount / cmvoexr.exchange_rate),2)  -- Inception
                    WHEN asset_amt_fact_ccrb.cover_perc IS NULL AND asset_incep_ccgo.asset_key IS NOT NULL AND ccgoexr.exchange_rate IS NOT NULL AND ccgoexr.exchange_rate <> 0
                    THEN ROUND((asset_incep_ccgo.asset_amount / ccgoexr.exchange_rate),2)  -- Inception
                    WHEN asset_amt_fact_ccrb.cover_perc IS NULL AND asset_incep_ccso.asset_key IS NOT NULL AND ccsoexr.exchange_rate IS NOT NULL AND ccsoexr.exchange_rate <> 0
                    THEN ROUND((asset_incep_ccso.asset_amount / ccsoexr.exchange_rate),2)  -- Inception
                    WHEN diff_curr.asset_key IS NOT NULL  -- v_orig_mitigant_ccy_cd not the same for all covers under this asset
                    THEN ROUND(ana_sum.sum_eur,2)
                    ELSE ROUND(dmt.n_orig_mitigant_value_eur,2) END
                ) AS orig_mitigant                                                                        --(n_orig_mitigant_value_eur)
        FROM dmb_reg_protection_dmart dmt
        JOIN tt_vdd_asset_records asr
          ON dmt.cover_key = asr.leading_cover_key
          AND dmt.reporting_date = v_reporting_date -- MK partitions
        JOIN tt_vdd_calc_amounts calc_amt
          ON asr.asset_key = calc_amt.asset_key
        LEFT JOIN dwh_asset asset
          ON dmt.asset_key = asset.asset_key --continuous catchup
          AND asset.record_valid_from = v_reporting_date -- MK partitions
        LEFT JOIN temp_prot mmd   ON asr.asset_key = mmd.asset_key
        LEFT JOIN temp_cover mbi
          ON asr.asset_key = mbi.asset_key
        LEFT JOIN dwh_asset_amount_org amt_orig_cmvo
          ON asr.asset_key = amt_orig_cmvo.asset_key
                AND amt_orig_cmvo.record_valid_from = v_reporting_date
                AND amt_orig_cmvo.amount_type = 'CMVO'
                AND amt_orig_cmvo.system_id = asset.system_id -- MK partitions
        LEFT JOIN currency cmvo_cur
          ON amt_orig_cmvo.currency_key = cmvo_cur.currency_key
        LEFT JOIN dwh_exchange_rate cmvo_exr
          ON cmvo_cur.currency_key = cmvo_exr.currency_key
          AND amt_orig_cmvo.batch_id = cmvo_exr.batch_id
          AND cmvo_exr.source = 'SIS'
          AND cmvo_exr.record_valid_from <= v_reporting_date
          AND nvl(cmvo_exr.record_valid_until,utilities.record_default_date) > v_reporting_date
        LEFT JOIN dwh_asset_amount_org amt_orig_ccgo
          ON asr.asset_key = amt_orig_ccgo.asset_key
          AND amt_orig_ccgo.record_valid_from = v_reporting_date
          AND amt_orig_ccgo.amount_type = 'CCGO'
          AND amt_orig_ccgo.system_id = asset.system_id -- MK partitions
        LEFT JOIN currency ccgo_cur
          ON amt_orig_ccgo.currency_key = ccgo_cur.currency_key
        LEFT JOIN dwh_exchange_rate ccgo_exr
          ON ccgo_cur.currency_key = ccgo_exr.currency_key
          AND amt_orig_ccgo.batch_id = ccgo_exr.batch_id
          AND ccgo_exr.source = 'SIS'
          AND ccgo_exr.record_valid_from <= v_reporting_date
          AND nvl(ccgo_exr.record_valid_until,utilities.record_default_date) > v_reporting_date
        LEFT JOIN dwh_exchange_rate euroexr
          ON euroexr.currency_key = v_eurcurrencykey
          AND mbi.asset_batch_id = euroexr.batch_id
          AND euroexr.source = 'SIS'
          AND euroexr.record_valid_from <= v_reporting_date
          AND nvl(euroexr.record_valid_until,utilities.record_default_date) > v_reporting_date
        LEFT JOIN dwh_asset_amount_org cploamtorg
          ON asr.asset_key = cploamtorg.asset_key
          AND cploamtorg.amount_type = 'CPLO'
          AND cploamtorg.system_id = asset.system_id
          AND cploamtorg.record_valid_from <= v_reporting_date
          AND nvl(cploamtorg.record_valid_until,utilities.record_default_date) > v_reporting_date
        LEFT JOIN general_indicator gind
          ON asset.parking_space_attached_key = gind.general_indicator_key
          AND gind.record_valid_from <= v_reporting_date
          AND nvl(gind.record_valid_until,utilities.record_default_date) > v_reporting_date
        LEFT JOIN dwh_asset_amount_org amt_orig_ccso
          ON asr.asset_key = amt_orig_ccso.asset_key
          AND amt_orig_ccso.record_valid_from = v_reporting_date
          AND amt_orig_ccso.amount_type = 'CCSO'
          AND amt_orig_ccso.system_id = asset.system_id
        LEFT JOIN currency ccso_cur
          ON amt_orig_ccso.currency_key = ccso_cur.currency_key
        LEFT JOIN dwh_exchange_rate ccso_exr
          ON amt_orig_ccso.currency_key = ccso_exr.currency_key
          AND amt_orig_ccso.batch_id = ccso_exr.batch_id
          AND ccso_exr.source = 'SIS'
          AND ccso_exr.record_valid_from <= v_reporting_date
          AND nvl(ccso_exr.record_valid_until,utilities.record_default_date) > v_reporting_date
        LEFT JOIN dwh_cover     lead_cov
          ON asr.leading_cover_key = lead_cov.cover_key -- 8.8.652
          AND lead_cov.record_valid_from = v_reporting_date -- MK partitions
          AND lead_cov.system_id = asset.system_id -- MK partitions
        LEFT JOIN dmb_reg_protection_incep asset_incep
          ON lead_cov.cover_id = asset_incep.cover_id
          AND lead_cov.system_id = asset_incep.system_id
          AND lead_cov.cover_start_date = asset_incep.cover_start_date
          AND lead_cov.cover_start_date = asset_incep.limit_start_date -- 8.8.652
        LEFT JOIN dwh_cover   cov_cmvo
          ON asset_incep.cover_key_cmvo_incep = cov_cmvo.cover_key  -- 8.8.652
        LEFT JOIN dwh_asset_amount_org  asset_incep_cmvo
          ON cov_cmvo.asset_key = asset_incep_cmvo.asset_key
          AND asset_incep_cmvo.amount_type = 'CMVO' -- 8.8.652
          AND asset_incep_cmvo.system_id = cov_cmvo.system_id
        LEFT JOIN dwh_cover cov_ccgo
          ON asset_incep.cover_key_ccgo_incep = cov_ccgo.cover_key  -- 8.8.652
        LEFT JOIN dwh_asset_amount_org  asset_incep_ccgo
          ON cov_ccgo.asset_key = asset_incep_ccgo.asset_key
          AND asset_incep_ccgo.amount_type = 'CCGO' -- 8.8.652
          AND asset_incep_ccgo.system_id = cov_ccgo.system_id -- MK partitions
        LEFT JOIN dwh_cover   cov_ccso
          ON asset_incep.cover_key_ccso_incep = cov_ccso.cover_key  -- 8.8.652
        LEFT JOIN dwh_asset_amount_org  asset_incep_ccso
          ON cov_ccso.asset_key = asset_incep_ccso.asset_key
          AND asset_incep_ccso.amount_type = 'CCSO' -- 8.8.652
          AND asset_incep_ccso.system_id = cov_ccso.system_id -- MK partitions
        LEFT JOIN dwh_asset_amount_org asset_amt_ccao
          ON dmt.asset_key = asset_amt_ccao.asset_key
          AND asset_amt_ccao.amount_type = 'CCAO' -- 8.8.652
          AND asset_amt_ccao.record_valid_from = v_reporting_date -- MK partitions
          AND asset_amt_ccao.system_id = asset.system_id -- MK partitions
        LEFT JOIN dwh_asset_amount_org  asset_amt_cvpo
          ON dmt.asset_key = asset_amt_cvpo.asset_key
          AND asset_amt_cvpo.amount_type = 'CVPO' -- 8.8.652
          AND asset_amt_cvpo.record_valid_from = v_reporting_date -- MK partitions
          AND asset_amt_cvpo.system_id = asset.system_id -- MK partitions
        LEFT JOIN tt_anacredit_diff_currencies  diff_curr
          ON dmt.asset_key = diff_curr.asset_key  -- 8.8.652
        LEFT JOIN tt_anacredit_asset_sum  ana_sum
          ON dmt.asset_key = ana_sum.asset_key  -- 8.8.652
        LEFT JOIN currency  asset_amt_ccao_cur
          ON asset_amt_ccao.currency_key = asset_amt_ccao_cur.currency_key  -- 8.8.652
        LEFT JOIN currency  asset_amt_cvpo_cur
          ON asset_amt_cvpo.currency_key = asset_amt_cvpo_cur.currency_key  -- 8.8.652
        LEFT JOIN currency asset_amt_cmvo_cur
          ON asset_incep_cmvo.currency_key = asset_amt_cmvo_cur.currency_key  -- 8.8.652
        LEFT JOIN currency  asset_amt_ccgo_cur
          ON asset_incep_ccgo.currency_key = asset_amt_ccgo_cur.currency_key  -- 8.8.652
        LEFT JOIN currency asset_amt_ccso_cur
          ON asset_incep_ccso.currency_key = asset_amt_ccso_cur.currency_key  -- 8.8.652
        LEFT JOIN dwh_exchange_rate ccaoexr
          ON asset_amt_ccao_cur.currency_key = ccaoexr.currency_key
          AND lead_cov.batch_id = ccaoexr.batch_id
          AND ccaoexr.source = 'SIS'  -- 8.8.652
          AND ccaoexr.record_valid_from <= v_reporting_date -- MK partitions
        LEFT JOIN dwh_exchange_rate cvpoexr
          ON asset_amt_cvpo_cur.currency_key = cvpoexr.currency_key
          AND lead_cov.batch_id = cvpoexr.batch_id
          AND cvpoexr.source = 'SIS'  -- 8.8.652
          AND cvpoexr.record_valid_from <= v_reporting_date -- MK partitions
        LEFT JOIN dwh_exchange_rate  cmvoexr
          ON asset_amt_cmvo_cur.currency_key = cmvoexr.currency_key
          AND lead_cov.batch_id = cmvoexr.batch_id
          AND cmvoexr.source = 'SIS'  -- 8.8.652
          AND cmvoexr.record_valid_from <= v_reporting_date -- MK partitions
        LEFT JOIN dwh_exchange_rate  ccgoexr
          ON asset_amt_ccgo_cur.currency_key = ccgoexr.currency_key
          AND lead_cov.batch_id = ccgoexr.batch_id
          AND ccgoexr.source = 'SIS'  -- 8.8.652
          AND ccgoexr.record_valid_from <= v_reporting_date -- MK partitions
        LEFT JOIN dwh_exchange_rate  ccsoexr
          ON asset_amt_ccso_cur.currency_key = ccsoexr.currency_key
          AND lead_cov.batch_id = ccsoexr.batch_id
          AND ccsoexr.source = 'SIS'  -- 8.8.652
          AND ccsoexr.record_valid_from <= v_reporting_date -- MK partitions
        LEFT JOIN dwh_cover_fact  asset_amt_fact_ccrb
          ON lead_cov.cover_key = asset_amt_fact_ccrb.cover_key
          AND asset_amt_fact_ccrb.record_valid_from = v_reporting_date
          AND asset_amt_fact_ccrb.amt_type = 'CCRB'
        GROUP BY  v_reporting_date,dmt.v_orig_src_system_id;

      v_count := SQL%ROWCOUNT;
      COMMIT;

      schema_maint.gather_idx_stats('TMP_VDD_DWH_PROT_RECON_ASSETS');
      vde_log(v_export_id, v_proc_name, v_reporting_date, v_start, 1, 'Inserted data to TMP_VDD_DWH_PROT_RECON_ASSETS. Row count:' || v_count);

      v_debug_msg := $$plsql_line|| ' OF PLSQL UNIT '|| $$plsql_unit||' rowcount >> '|| v_count;
      utilities.show_debug(v_debug_msg);

      EXCEPTION
      WHEN OTHERS THEN
      utils.handleerror(SQLCODE,SQLERRM);
    END;
   
--Assets ended here

   /*get the difference between dwh and dmb table (for cover) */

    BEGIN
      v_start := SYSDATE;
      utilities.truncate_table('TMP_VDD_RESULT_RECON_PROT_BRED_COVER');
    
      INSERT INTO TMP_VDD_RESULT_RECON_PROT_BRED_COVER(
        record_valid_from,
        system_id,
        dwh_cnt,
        dmb_cnt,
        cnt_diff,
        mitigants_diff,
        fx_rate_diff,
        priority_amt_diff,
        realizable_la_amount_diff,
        realizable_cap_amount_diff,
        liquidation_diff,
        mitigant_eur_diff,
        coverage_ratio_diff,
        dept_coverage_ratio_diff,
        rental_income_diff,
        rental_value_diff,
        rental_costs_diff,
        net_rental_income_diff,
        mitigant_value_diff,
        orig_fx_rate_diff,
        orig_mitigant_diff
      )
          ( SELECT
              dwh.reporting_date record_valid_from,
              dwh.system_id  system_id,
              SUM(dwh.prot_cnt_cover) dwh_cnt,
              SUM(dmb.prot_cnt) dmb_cnt,
              abs(SUM(nvl(dwh.prot_cnt_cover, 0)) - SUM(nvl(dmb.prot_cnt, 0))) cnt_diff,
              NVL(SUM(abs(dwh.mitigants - dmb.mitigants)) ,0) mitigants_diff,
              NVL(SUM(abs(dwh.fx_rate - dmb.fx_rate)) ,0 ) fx_rate_diff,
              NVL(SUM(abs(dwh.priority_amt - dmb.priority_amt)) ,0) priority_amt_diff,
              NVL(SUM(abs(dwh.realizable_la_amount - dmb.realizable_la_amount)),0) realizable_la_amount_diff,
              NVL(SUM(abs(dwh.realizable_cap_amount - dmb.realizable_cap_amount)),0) realizable_cap_amount_diff,
              NVL(SUM(abs(dwh.liquidation - dmb.liquidation)) ,0)  liquidation_diff,
              NVL(SUM(abs(dwh.mitigant_eur - dmb.mitigant_eur)),0) mitigant_eur_diff,
              NVL(SUM(abs(dwh.coverage_ratio - dmb.coverage_ratio)),0) coverage_ratio_diff,
              NVL(SUM(abs(dwh.dept_coverage_ratio - dmb.dept_coverage_ratio)),0) dept_coverage_ratio_diff,
              NVL(SUM(abs(dwh.rental_income - dmb.rental_income)),0) rental_income_diff,
              NVL(SUM(abs(dwh.rental_value - dmb.rental_value)) ,0) rental_value_diff,
              NVL(SUM(abs(dwh.rental_costs - dmb.rental_costs)),0) rental_costs_diff,
              NVL(SUM(abs(dwh.net_rental_income - dmb.net_rental_income)) ,0) net_rental_income_diff,
              NVL(SUM(abs(dwh.mitigant_value - dmb.mitigant_value)),0) mitigant_value_diff,
              NVL(SUM(abs(dwh.orig_fx_rate - dmb.orig_fx_rate)) ,0) orig_fx_rate_diff,
              NVL(SUM(abs(dwh.orig_mitigant - dmb.orig_mitigant)) ,0) dept_coverage_ratio_diff
          FROM TMP_VDD_DWH_PROT_RECON_COVER  dwh
          LEFT JOIN TMP_VDD_DMB_PROT_RECON  dmb ON dwh.reporting_date = dmb.record_valid_from
            AND dwh.system_id = dmb.system_id
          WHERE  dmb.v_level_ind='C'
          GROUP BY
              dwh.reporting_date,
              dwh.system_id
          );

      v_count := SQL%ROWCOUNT;
      COMMIT;

      schema_maint.gather_idx_stats('TMP_VDD_RESULT_RECON_PROT_BRED_COVER');
      vde_log(v_export_id, v_proc_name, v_reporting_date, v_start, 1, 'Inserted data to TMP_VDD_RESULT_RECON_PROT_BRED_COVER. Row count:' || v_count);

      v_debug_msg := $$plsql_line|| ' OF PLSQL UNIT '|| $$plsql_unit||' rowcount >> '|| v_count;
      utilities.show_debug(v_debug_msg);

      EXCEPTION
      WHEN OTHERS THEN
      utils.handleerror(SQLCODE,SQLERRM);
    END;

/*get the difference between dwh and dmb table for assets record */
    BEGIN
      v_start := SYSDATE;
      utilities.truncate_table('TMP_VDD_RESULT_RECON_PROT_BRED_ASSETS');
    
      INSERT INTO TMP_VDD_RESULT_RECON_PROT_BRED_ASSETS(record_valid_from,
          system_id,
          dwh_cnt,
          dmb_cnt,
          cnt_diff,
          mitigants_diff,
          fx_rate_diff,
          priority_amt_diff,
          adjusted_amount_diff,
          realizable_la_amount_diff,
          realizable_cap_amount_diff,
          occupancy_rate_diff,
          rentable_surface_diff,
          liquidation_perc_diff,
          liquidation_diff,
          fair_diff,
          mitigant_eur_diff,
          coverage_ratio_diff,
          dept_coverage_ratio_diff,
          rental_income_diff,
          rental_value_diff,
          rental_costs_diff,
          net_rental_income_diff,
          mitigant_value_diff,
          orig_fx_rate_diff,
          orig_mitigant_diff
      )
      ( SELECT
          dwh.reporting_date AS record_valid_from,
          dwh.system_id  AS system_id,
          SUM(dwh.prot_cnt_assets) AS dwh_cnt,
          SUM(dmb.prot_cnt) AS dmb_cnt,
          abs(SUM(nvl(dwh.prot_cnt_assets, 0)) - SUM(nvl(dmb.prot_cnt, 0))) cnt_diff,
          NVL(SUM(abs(dwh.mitigants - dmb.mitigants)),0) mitigants_diff,
          NVL(SUM(abs(dwh.fx_rate - dmb.fx_rate)) ,0) fx_rate_diff,
          NVL(SUM(abs(dwh.priority_amt - dmb.priority_amt)) ,0) priority_amt_diff,
          NVL(SUM(abs(dwh.adjusted_amount - dmb.adjusted_amt)),0) adjusted_amount_diff,
          NVL(SUM(abs(dwh.realizable_la_amount - dmb.realizable_la_amount)),0) realizable_la_amount_diff,
          NVL(SUM(abs(dwh.realizable_cap_amount - dmb.realizable_cap_amount)),0) realizable_cap_amount_diff,
          NVL(SUM(abs(dwh.occupancy_rate - dmb.occupancy_rate)),0) occupancy_rate_diff,
          NVL(SUM(abs(dwh.rentable_surface - dmb.rentable_surface)) ,0) rental_surface_diff,
          NVL(SUM(abs(dwh.liquidation_perc - dmb.liquidation_perc)),0) liquidation_perc_diff,
          NVL(SUM(abs(dwh.liquidation - dmb.liquidation)) ,0) liquidation_diff,
          NVL(SUM(abs(dwh.fair - dmb.fair)),0) fair_diff,
          NVL(SUM(abs(dwh.mitigant_eur - dmb.mitigant_eur)) ,0) mitigant_eur_diff,
          NVL(SUM(abs(dwh.coverage_ratio - dmb.coverage_ratio)) ,0) coverage_ratio_diff,
          NVL(SUM(abs(dwh.dept_coverage_ratio - dmb.dept_coverage_ratio)),0) dept_coverage_ratio_diff,
          NVL(SUM(abs(dwh.rental_income - dmb.rental_income)) ,0) rental_income_diff,
          NVL(SUM(abs(dwh.rental_value - dmb.rental_value)) ,0) rental_value_diff,
          NVL(SUM(abs(dwh.rental_costs - dmb.rental_costs)) ,0) rental_costs_diff,
          NVL(SUM(abs(dwh.net_rental_income - dmb.net_rental_income)),0) net_rental_income_diff,
          NVL(SUM(abs(dwh.mitigant_value - dmb.mitigant_value)) ,0) mitigant_value_diff,
          NVL(SUM(abs(dwh.orig_fx_rate - dmb.orig_fx_rate)) ,0) orig_fx_rate_diff,
          NVL(SUM(abs(dwh.orig_mitigant - dmb.orig_mitigant)),0) orig_mitigant
      FROM
          TMP_VDD_DWH_PROT_RECON_ASSETS  dwh
          LEFT JOIN TMP_VDD_DMB_PROT_RECON    dmb ON dwh.reporting_date = dmb.record_valid_from
                                            AND dwh.system_id = dmb.system_id
          WHERE  dmb.v_level_ind='A'
      GROUP BY
          dwh.reporting_date,
          dwh.system_id
          );

      v_count := SQL%ROWCOUNT;
      COMMIT;

      schema_maint.gather_idx_stats('TMP_VDD_RESULT_RECON_PROT_BRED_ASSETS');
      vde_log(v_export_id, v_proc_name, v_reporting_date, v_start, 1, 'Inserted data to TMP_VDD_RESULT_RECON_PROT_BRED_ASSETS. Row count:' || v_count);

      v_debug_msg := $$plsql_line|| ' OF PLSQL UNIT '|| $$plsql_unit||' rowcount >> '|| v_count;
      utilities.show_debug(v_debug_msg);

      EXCEPTION
      WHEN OTHERS THEN
      utils.handleerror(SQLCODE,SQLERRM);
    END;

  /*Check the error_flag for cover */

    BEGIN
        v_start := SYSDATE;

        UPDATE TMP_VDD_RESULT_RECON_PROT_BRED_COVER
        SET
            error_flag = 'Y'
        WHERE cnt_diff > 0
          OR mitigants_diff  > v_threshold
          OR fx_rate_diff  > v_threshold
          OR priority_amt_diff  > v_threshold
          OR realizable_la_amount_diff  > v_threshold
          OR realizable_cap_amount_diff  > v_threshold
          OR liquidation_diff  > v_threshold
          OR mitigant_eur_diff  > v_threshold
          OR coverage_ratio_diff  > v_threshold
          OR dept_coverage_ratio_diff  > v_threshold
          OR rental_income_diff  > v_threshold
          OR rental_value_diff  > v_threshold
          OR rental_costs_diff  > v_threshold
          OR net_rental_income_diff  > v_threshold
          OR mitigant_value_diff  > v_threshold
          OR orig_fx_rate_diff  > v_threshold
          OR orig_mitigant_diff  > v_threshold;

        v_count := SQL%ROWCOUNT;
        COMMIT;

        schema_maint.gather_idx_stats('TMP_VDD_RESULT_RECON_PROT_BRED_COVER');
        vde_log(v_export_id, v_proc_name, v_reporting_date, v_start, 5, 'Updated error flag in TMP_VDD_RESULT_RECON_PROT_BRED_COVER. Row count:' || v_count);
        v_debug_msg := $$plsql_line|| ' OF PLSQL UNIT '|| $$plsql_unit|| ' rowcount >> '|| v_count;
        utilities.show_debug(v_debug_msg);
            
        EXCEPTION
        WHEN OTHERS THEN
        utils.handleerror(SQLCODE, SQLERRM);
    END;


    /*Check the error_flag for assets   */

    BEGIN
        v_start := SYSDATE;

        UPDATE TMP_VDD_RESULT_RECON_PROT_BRED_ASSETS
        SET
        error_flag = 'Y'
        WHERE cnt_diff> 0
          OR mitigants_diff > v_threshold
          OR fx_rate_diff > v_threshold
          OR priority_amt_diff > v_threshold
          OR adjusted_amount_diff > v_threshold
          OR realizable_la_amount_diff > v_threshold
          OR realizable_cap_amount_diff > v_threshold
          OR occupancy_rate_diff > v_threshold
          OR rentable_surface_diff > v_threshold
          OR liquidation_perc_diff > v_threshold
          OR liquidation_diff > v_threshold
          OR fair_diff > v_threshold
          OR mitigant_eur_diff > v_threshold
          OR coverage_ratio_diff > v_threshold
          OR dept_coverage_ratio_diff > v_threshold
          OR rental_income_diff > v_threshold
          OR rental_value_diff > v_threshold
          OR rental_costs_diff > v_threshold
          OR net_rental_income_diff > v_threshold
          OR mitigant_value_diff > v_threshold
          OR orig_fx_rate_diff > v_threshold
          OR orig_mitigant_diff > v_threshold;

        v_count := SQL%ROWCOUNT;
        COMMIT;

        schema_maint.gather_idx_stats('TMP_VDD_RESULT_RECON_PROT_BRED_ASSETS');
        vde_log(v_export_id, v_proc_name, v_reporting_date, v_start, 5, 'Updated error flag in TMP_VDD_RESULT_RECON_PROT_BRED_ASSETS. Row count:' || v_count);
        v_debug_msg := $$plsql_line|| ' OF PLSQL UNIT '|| $$plsql_unit|| ' rowcount >> '|| v_count;
        utilities.show_debug(v_debug_msg);
            
        EXCEPTION
        WHEN OTHERS THEN
        utils.handleerror(SQLCODE, SQLERRM);
    END;

-----------------------------------------------------------------------------------------------------------------------------------------       

--  IF i_debug = 1 THEN
--    BEGIN
--        SELECT table_name 
--        INTO v_tname
--        FROM user_tables 
--        WHERE table_name = 'TMP_VDD_DMB_PROT_RECON';
--
--        OPEN cv_1 FOR 'SELECT * FROM ' 
--        || DBMS_ASSERT.SQL_OBJECT_NAME(v_tname) || ' ORDER BY 4,2,3,5,7';
--        dbms_sql.return_result(cv_1);
--
--        SELECT table_name 
--        INTO v_tname
--        FROM user_tables 
--        WHERE table_name = 'TMP_VDD_DWH_PROT_RECON_COVER';
--
--        SELECT table_name 
--        INTO v_tname
--        FROM user_tables 
--        WHERE table_name = 'TMP_VDD_DWH_PROT_RECON_ASSETS';
--            
--        OPEN cv_1 FOR 'SELECT * FROM ' 
--        || DBMS_ASSERT.SQL_OBJECT_NAME(v_tname) || ' ORDER BY 4,2,3,5,7';
--        dbms_sql.return_result(cv_1);                 
--		END;
--    END IF;  

    DBMS_OUTPUT.PUT_LINE(v_proc_name || ' PROCEDURE Ended: ' || TO_CHAR(SYSDATE, 'DD-MON-YYYY HH24:MI:SS'));

EXCEPTION
    WHEN OTHERS THEN
        utils.handleerror(sqlcode,sqlerrm);
END;
/
show error;