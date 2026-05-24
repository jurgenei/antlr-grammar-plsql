/* simple column alias 2 - concat
   from: https://www.oracletutorial.com/oracle-basics/oracle-alias/ */
SELECT
  first_name  || ' '  || last_name AS "Full Name"
FROM
  employees;