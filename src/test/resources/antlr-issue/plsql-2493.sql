-- Issue #2493: CHR-Function cannot used in TRIM-Function
-- URL: https://github.com/antlr/grammars-v4/issues/2493

SELECT      customer_id, cust_address_ntab
MULTISET UNION cust_address2_ntab multiset_union
FROM       customers_demo;