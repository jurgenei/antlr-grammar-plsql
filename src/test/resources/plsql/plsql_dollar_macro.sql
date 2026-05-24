begin
    select event_type
      , export_channel
      $IF pkg_env.c_is_sdp $THEN
      , batch_id
      $END
    from table;
    select event_type
      , export_channel
      $IF pkg_env.c_is_sdp $THEN
      , batch_id
      $ELSE
      , batch_id
      $END
    from table;
    select event_type
      , export_channel
      $IF pkg_env.c_is_sdp $THEN
      , batch_id
      $END
    from table;
end;