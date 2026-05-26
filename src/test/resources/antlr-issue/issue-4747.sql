-- Issue #4747: [PL/SQL] selection_directives syntax errors
-- URL: https://github.com/antlr/grammars-v4/issues/4747

Select a.ref,
       a.indent,
$if global_def $then
       count(a.ref),
$else 
       sum(a.price),
$end
       a.info
from all_data a
where a.a = 1
$if another_def $then
  and a.b = 3
$else 
  and a.c = 0
$end;
