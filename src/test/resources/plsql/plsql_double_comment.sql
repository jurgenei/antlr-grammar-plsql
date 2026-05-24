-- 1 comment
/* 2 simple plsql */
/* 3 insert/select case */
INSERT
/* 4 this too */
/* 5 and this too */
-- 6 comment
INTO   contacts (contact_id, last_name, first_name)
-- 7 comment
/* 8 and this too */
SELECT customer_id,
/* 9 and this too */
last_name, -- 10 comment
first_name
FROM   customers
WHERE  customer_id = '123';
/* comment at the end */
