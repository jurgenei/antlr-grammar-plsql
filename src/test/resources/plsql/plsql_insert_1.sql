/* simple plsql insert/select case */
INSERT
INTO   contacts (contact_id, last_name, first_name)
SELECT customer_id, last_name, first_name
FROM   customers
WHERE  customer_id = '123';
