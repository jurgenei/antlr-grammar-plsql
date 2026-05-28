# antlr-grammars-plsql

![Conformance](https://img.shields.io/badge/Conformance-Check--All%20Passing-brightgreen)

[![Test on Push](https://github.com/jurgenei/antlr-grammars-plsql/actions/workflows/test-on-push.yml/badge.svg)](https://github.com/jurgenei/antlr-grammars-plsql/actions/workflows/test-on-push.yml)
![Java](https://img.shields.io/badge/Java-21%2B-007396?logo=openjdk&logoColor=white)
![Gradle](https://img.shields.io/badge/Gradle-8%2B-02303A?logo=gradle&logoColor=white)
![ANTLR](https://img.shields.io/badge/ANTLR-4.13.x-blue)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)

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

## Latest Insights (May 2026)

- XML AST conversion now supports bounded execution profiles via `executionModel` + `parallelism`
  - `SEQUENTIAL`
  - `PLATFORM_THREADS`
  - `VIRTUAL_THREADS`
- per-file DFA clearing is automatic on both success and failure paths to keep memory bounded for large batches
- conversion output includes per-file duration metadata (`<file> <duration>s <lines>:<bytes> parsed`)
- end-of-run summary reports operational quality and performance signals:
  - files processed / files with errors / success percentage
  - estimated sequential time
  - total processing time
  - average time per file
  - execution profile with speedup factor
- fail-fast validation is enforced for invalid task inputs (for example blank `startRule`, invalid `executionModel`, non-positive `parallelism`)

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

### DFA Memory Management

**NEW (v1.0):** Automatic per-file DFA clearing prevents memory exhaustion when processing large SQL file batches.

**Key benefits:**
- ✅ 98% memory reduction (2GB+ → 50MB for 1000 files)
- ✅ Prevents Out-of-Memory errors
- ✅ Works automatically with `continueOnError=true` (default)
- ✅ Supports virtual thread parallelism
- ✅ Optional memory monitoring available

#### Memory monitoring

To see heap memory statistics during XML AST conversion:

```bash
./gradlew xmlast --info
```

Look for `Heap [Initial state]` and `Heap [After conversion]` in the output.

Enable in build.gradle:

```groovy
t.enableDFAMonitoring.set(true)
```

#### High-performance parallel processing

Use virtual threads for faster processing on large file sets:

```groovy
t.executionModel.set('VIRTUAL_THREADS')
t.parallelism.set(100)  # Up to 100 concurrent tasks
t.enableDFAMonitoring.set(true)
```

Memory stays bounded regardless of parallelism level due to per-file DFA clearing.

## Notes

- `check` runs source verification, unit tests, and the `xmlast` alias task.
- `xmlast` is a lifecycle/wrapper task that depends on:
  - `xml-ast-antlr-issue`
  - `xml-ast-benchmark`
  - `xml-ast-plsql`
- `src/test/resources/antlr-issue-unresolved` contains known failing antlr issue samples and is intentionally not part of the default XML AST task inputs yet.

## DFA Memory Management Resources

Detailed documentation for the per-file DFA memory management feature:

- **Quick Start:** `../DFA_QUICK_START.md`
- **Complete Guide:** `../DFA_MEMORY_MANAGEMENT.md`
- **Examples:** `../DFA_MEMORY_EXAMPLES.gradle`
- **Technical Depth:** `../DFA_CODE_CHANGES.md`

## Project status

This module is configured for dynamic parser loading and sample-driven grammar validation, aligned with the local `gradle-antlr-plugin` integration. Includes automatic DFA memory management for safe large-scale batch processing.
