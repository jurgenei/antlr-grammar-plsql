/* simple column alias 2 - expression
   from: https://www.oracletutorial.com/oracle-basics/oracle-alias/ */
SELECT
  product_name,
  list_price - standard_cost AS gross_profit
FROM
  products
ORDER BY
  gross_profit DESC;