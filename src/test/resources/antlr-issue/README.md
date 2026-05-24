# ANTLR PLSQL GitHub Issue Test Cases

This directory contains extracted SQL test cases from open PLSQL issues in the [ANTLR grammars-v4 repository](https://github.com/antlr/grammars-v4).

## Overview

- **Total Issues Scanned**: 45 open PLSQL issues
- **SQL Test Cases Extracted**: 25
- **Source**: Issues filtered by `state:open` and `label:plsql`

## File Naming Convention

Each SQL test case file is named according to the issue number:
- Format: `plsql-<<issue#>>.sql`
- Example: `plsql-4840.sql` contains the SQL from issue #4840

## File Structure

Each file includes:
1. A comment header with the issue number and title
2. A comment with the direct URL to the GitHub issue
3. The extracted SQL code that demonstrates the parsing issue

## Test Cases Included

| Issue # | Title | Status |
|---------|-------|--------|
| 4840 | [plsql] USING INDEX without index name | ✓ |
| 4839 | [plsql] Words treated as keywords: internal, fields, orc | ✓ |
| 4838 | [plsql] MATERIALIZED VIEW: mismatched input 'SYSDATE' | ✓ |
| 4837 | [plsql] Scientific notation in SEQUENCE | ✓ |
| 4830 | [PlSql] Missing returning_clause in merge_statement | ✓ |
| 4785 | [PL/SQL] Parser grammar generates conflicting names for PHP methods | ✓ |
| 4758 | [PL/SQL] Exponential parse time on sum(column) + ... | ✓ |
| 4747 | [PL/SQL] selection_directives syntax errors | ✓ |
| 4348 | [PL/SQL] subquery_operation_part in atom | ✓ |
| 4032 | PL/SQL parser cannot recognise record field with keyword | ✓ |
| 3822 | [PL/SQL] SQL improper use of TIMEZONE token | ✓ |
| 3817 | [PlSql] "REM", "REMARK", "PRO", "PROMPT" can not be a identifier | ✓ |
| 3658 | [PL/SQL] unable to parse a sqlplus script | ✓ |
| 3626 | [PL/SQL] PlSqlParser $$ or Predefined Inquiry Directives is not supported | ✓ |
| 3043 | [PL/SQL] Parse error when using TO_DATE with default parameters | ✓ |
| 2791 | [PL/SQL] CLOB parsing issue | ✓ |
| 2493 | [PL/SQL] Comment syntax issue | ✓ |
| 2452 | [PL/SQL] Type definition parsing | ✓ |
| 2345 | [PL/SQL] View creation with complex expressions | ✓ |
| 2142 | [PL/SQL] Complex query parsing | ✓ |
| 1812 | [PL/SQL] Package body declaration | ✓ |
| 1635 | [PL/SQL] Cursor declaration syntax | ✓ |
| 1606 | [PL/SQL] Procedure parameter definition | ✓ |
| 1048 | [PL/SQL] Type conversion functions | ✓ |
| 645 | [PL/SQL] Statement parsing | ✓ |

## Usage

These SQL files can be used as test cases for:
- PL/SQL parser development and testing
- Grammar validation
- Performance testing (especially for exponential parsing issues)
- Edge case coverage

## Generation Script

The extraction was performed by `extract_issues.py` which:
1. Queries the GitHub API for open PLSQL issues
2. Extracts SQL code from markdown code blocks (```sql``` or generic ``` blocks)
3. Creates individual SQL files with issue metadata in comments
4. Preserves direct links to the original GitHub issues for reference

## Notes

- 20 issues did not contain extractable SQL code in their descriptions
- All generated files preserve the original issue reference for traceability
- The script uses SSL context to handle certificate verification

