select listagg(distinct rpad(rvj.parent_column_name,47-length(rvj.parent_abbreviation)-1) || ' = ' || rvj.child_abbreviation || '.' || rvj.child_column_name||chr(13)
		|| 	case when upper(rvj.parent_column_name)        = 'TIME_KEY'
						and upper(rvj.join_class)          IN ('SCOPING_FAC','SCOPING_OUT')
				 then ' AND '|| rvj.parent_abbreviation || '.' || rpad(rvj.parent_column_name,47-length(rvj.parent_abbreviation)-1) || ' = '||''''||v_time_key||''''
			end
		|| 	case when upper(rvj.parent_column_name)        = 'SYSTEM_ID'
						and upper(rvj.join_class)          IN ('SCOPING_FAC','SCOPING_OUT')
						and upper(sel.type)                = 'VORTEX'
						and substr(ora_database_name,1,6)  = 'VTXCON'
						and sel.system_id is not null
				 then ' AND '|| rvj.parent_abbreviation || '.' || rpad(rvj.parent_column_name,47-length(rvj.parent_abbreviation)-1) || ' = '||''''||sel.system_id||''''
			end
		   ,CHR(13) || ' AND ' || rvj.parent_abbreviation )
            within group (order by rvj.order_number)
            over (partition BY RVj.RAW_VIEW_NAME, rvj.parent_abbreviation)
from dual;           