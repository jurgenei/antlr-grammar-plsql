/* simple plsql insert/select case */
INSERT /*+ APPEND +*/
INTO tt_bnk_dependent_defaulting
(
SELECT dependent_on_value
,      vortex_reference
FROM   current_dependent_defaulting dd
,      current_field_related_activity fa
WHERE  fa.reference_system_id = dd.system_id
AND    dd.defaulting_type = fa.activity_type
AND    fa.activity_code = 'DEFAULTING'
AND    fa.table_name = 'valid_customer'
AND    fa.field_name = 'risk_rating'
AND    fa.system_id = v_system_id
)
