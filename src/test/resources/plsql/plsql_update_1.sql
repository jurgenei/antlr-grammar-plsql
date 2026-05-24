/* simple plsql update/select case */
UPDATE customers
SET    c_details = (
   SELECT contract_date
   FROM   suppliers
   WHERE  suppliers.supplier_name = customers.customer_name
)
WHERE  customer_id < 1000
;
