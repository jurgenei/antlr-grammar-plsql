/* simple table alias - self join
   from: https://www.oracletutorial.com/oracle-basics/oracle-alias/ */
SELECT e.first_name employee, m.first_name managerdir
FROM   employees e
INNER
JOIN   employees m
ON     m.employee_id = e.employee_id;