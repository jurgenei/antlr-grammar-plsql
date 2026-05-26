-- Issue #3626: [PL/SQL]   PlSqlParser $$  or  Predefined Inquiry Directives is not supported 
-- URL: https://github.com/antlr/grammars-v4/issues/3626

CREATE OR REPLACE PROCEDURE p
 AUTHID DEFINER IS
   i PLS_INTEGER;
 BEGIN
  DBMS_OUTPUT.PUT_LINE('Inside p');
    i := $$PLSQL_LINE;
    DBMS_OUTPUT.PUT_LINE('i = ' || i);
   DBMS_OUTPUT.PUT_LINE('$$PLSQL_LINE = ' || $$PLSQL_LINE);
   DBMS_OUTPUT.PUT_LINE('$$PLSQL_UNIT = ' || $$PLSQL_UNIT);
   DBMS_OUTPUT.PUT_LINE('$$PLSQL_UNIT_OWNER = ' || $$PLSQL_UNIT_OWNER);
    DBMS_OUTPUT.PUT_LINE('$$PLSQL_UNIT_TYPE = ' || $$PLSQL_UNIT_TYPE);
  END;