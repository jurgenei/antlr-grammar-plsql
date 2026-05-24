# antlr-grammars-plsql

PL/SQL grammar module extracted from `gradle-antlr-xml-plugin`.

This repository hosts PL/SQL ANTLR grammars and validates them against SQL sample corpora through dynamic parser loading tests.

## What this repo contains

- grammar sources: `src/main/antlr/name/jurgenei/parsers`
  - `PlSqlLexer.g4`
  - `PlSqlParser.g4`
- SQL test samples:
  - `src/test/resources/plsql`
  - `src/test/resources/benchmark`
- dynamic-loading parser test: `src/test/java/name/jurgenei/parsers/PlSqlLexerParserTest.java`

## Build model

This project uses:

- `antlr` plugin to generate lexer/parser Java sources
- local composite plugin include for `xmlast` via `../gradle-antlr-plugin`
- custom compile task for generated ANTLR sources (`compileAntlrSources`)

Tests load parser/lexer classes dynamically (reflection), avoiding direct compile-time coupling to generated classes.

## Requirements

- Java 21+
- Gradle 8+

## Quick start

```bash
./gradlew clean test
```

## Important tasks

- `generateLexerSources` - generates lexer Java from `PlSqlLexer.g4`
- `generateParserSources` - generates parser Java from `PlSqlParser.g4`
- `compileAntlrSources` - compiles generated parser/lexer classes
- `verifyGrammarSources` - checks required grammar files are present
- `test` - runs dynamic-loading parser tests over sample SQL files
- `xmlast` - optional conversion of benchmark SQL files to XML AST

## XML AST task

`xmlast` is configured for benchmark parsing with:

- `parserClassName = name.jurgenei.parsers.PlSqlParser`
- `lexerClassName = name.jurgenei.parsers.PlSqlLexer`
- `startRule = sqlScript`
- source directory: `src/test/resources/benchmark`
- output directory: `build/xmlast-samples`

Run manually:

```bash
./gradlew xmlast
```

## Notes

- `check` currently emphasizes source verification + test execution.
- `xmlast` can be run explicitly for additional AST regression checks.

## Project status

This module is configured for dynamic parser loading and sample-driven grammar validation, aligned with the local `gradle-antlr-plugin` integration.
