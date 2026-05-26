# antlr-grammars-plsql

PL/SQL grammar module extracted from `gradle-antlr-xml-plugin`.

This repository hosts PL/SQL ANTLR grammars and validates them against SQL sample corpora through dynamic parser loading tests and XML AST conversion tasks.

## What this repo contains

- grammar sources: `src/main/antlr/name/jurgenei/parsers`
  - `PlSqlLexer.g4`
  - `PlSqlParser.g4`
- SQL test samples:
  - `src/test/resources/plsql`
  - `src/test/resources/benchmark`
  - `src/test/resources/antlr-issue`
  - `src/test/resources/antlr-issue-unresolved` (known failing samples, tracked but excluded from CI checks)
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
- `xmlast` - lifecycle alias that runs all XML AST sample-set tasks
- `xml-ast-antlr-issue` - converts `src/test/resources/antlr-issue` SQL samples
- `xml-ast-benchmark` - converts `src/test/resources/benchmark` SQL samples
- `xml-ast-plsql` - converts `src/test/resources/plsql` SQL samples

## XML AST task

The XML AST tasks are configured with:

- `parserClassName = name.jurgenei.parsers.PlSqlParser`
- `lexerClassName = name.jurgenei.parsers.PlSqlLexer`
- `startRule = script`
- output directories under: `build/xmlast-samples`

Run manually:

```bash
./gradlew xmlast
```

## Notes

- `check` runs source verification, unit tests, and the `xmlast` alias task.
- `xmlast` is a lifecycle/wrapper task that depends on:
  - `xml-ast-antlr-issue`
  - `xml-ast-benchmark`
  - `xml-ast-plsql`
- `src/test/resources/antlr-issue-unresolved` contains known failing antlr issue samples and is intentionally not part of the default XML AST task inputs yet.

## Project status

This module is configured for dynamic parser loading and sample-driven grammar validation, aligned with the local `gradle-antlr-plugin` integration.
