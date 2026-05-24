/* IF ELSE case going wrong with original grammar */
BEGIN
   IF ( v_trend_interval IS NOT NULL ) THEN
   /* DECLARE */
   BEGIN
     v_err := foo(v_reporting_date => v_reporting_date);
   END;
   ELSE
   BEGIN
      v_err := bar(v_reporting_date => v_reporting_date);
   END;
   END IF;
END;
