-- Issue #4838: [plsql] MATERIALIZED VIEW: mismatched input 'SYSDATE'
-- URL: https://github.com/antlr/grammars-v4/issues/4838

CREATE MATERIALIZED VIEW mv_test
  REFRESH NEXT SYSDATE + INTERVAL '60' SECOND
AS
SELECT * FROM dual;