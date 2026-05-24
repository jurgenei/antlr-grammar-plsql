-- Issue #4837: [plsql] Scientific notion in SEQUENCE
-- URL: https://github.com/antlr/grammars-v4/issues/4837

CREATE SEQUENCE s_example
    START WITH 1.9e+09;