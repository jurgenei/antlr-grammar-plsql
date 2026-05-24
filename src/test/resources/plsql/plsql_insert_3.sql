/*  plsql insert/select nested case */
 INSERT/*+ APPEND +*/INTO tt_max_ing_rr
( SELECT
    src.system_id,
    src.ing_risk_rating,
    src.risk_rating_type,
    src.customer_id
  FROM
    (
        SELECT
            system_id,
            ing_risk_rating,
            risk_rating_type,
            grid_id customer_id,
            id,
            MIN(id) OVER(
                PARTITION BY grid_id,
                risk_rating_type
            ) AS minid
        FROM
            tt_max_ing_rr_1
    ) src
    where id = minid
);