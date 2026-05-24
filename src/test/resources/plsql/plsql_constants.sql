begin
    c1 := 'string';
    c2 := q'^perl string1^';
    c3 := q'[perl string 2]';
    c4 := nvl(a, 1e6);
    c5 := 12345;
    c6 := $$plsql_line || 'OF PLSQL UNIT' || $$plsql_unit || ' ' || '  Count of tt_pp_limit_amount_weight_First_Insertion  ' || SQL%
          rowcount;
end;