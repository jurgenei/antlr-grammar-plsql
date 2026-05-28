# Samples (antlr-grammars-plsql)

![Conformance](https://img.shields.io/badge/Conformance-Check--All%20Passing-brightgreen)

This directory contains Gradle build use-case examples for validating PL/SQL sample SQL with the `xmlast` plugin.

## Files

- `use-case-01-direct/build.gradle` - direct parser/lexer/startRule configuration.
- `use-case-02-catalog/build.gradle` - catalog-driven configuration.
- `use-case-02-catalog/catalog.xml` - catalog file used by the catalog sample.
- `use-case-03-check-hook/build.gradle` - wiring `xmlast` into `check`.

These files are designed as copy/paste templates for a grammar module where:

- parser class: `name.jurgenei.parsers.PlSqlParser`
- lexer class: `name.jurgenei.parsers.PlSqlLexer`
- parser entry rule: `script`
- sample directory: `src/test/resources/benchmark`

