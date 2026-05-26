-- Issue #1812: bug of PlSqlParser.g4: statement split error
-- URL: https://github.com/antlr/grammars-v4/issues/1812

CREATE VIEW TEST (A, B, C)
      AS 
      WITH TESTCTE AS (
        SELECT 1 ONE FROM DUAL
      )
      SELECT 'A', 'B', 'C'
      FROM DUAL
      JOIN TESTCTE;

CREATE TABLE TEST
      AS 
      WITH TESTCTE AS (
        SELECT 1 ONE FROM DUAL
      )
      SELECT 'A', 'B', 'C'
      FROM DUAL