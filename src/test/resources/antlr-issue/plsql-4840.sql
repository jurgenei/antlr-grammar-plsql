-- Issue #4840: [plsql] USING INDEX without index name
-- URL: https://github.com/antlr/grammars-v4/issues/4840

CREATE TABLE test
(
  uk_col NUMBER(9),
  CONSTRAINT uk_test UNIQUE (uk_col)
    USING INDEX
);