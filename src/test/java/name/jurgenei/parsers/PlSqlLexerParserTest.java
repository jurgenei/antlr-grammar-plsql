package name.jurgenei.parsers;

import org.antlr.v4.runtime.*;
import org.junit.Assert;
import org.junit.Before;
import org.junit.Test;

import java.io.File;
import java.io.InputStream;
import java.lang.reflect.Constructor;
import java.lang.reflect.Method;
import java.nio.charset.StandardCharsets;
import java.nio.file.*;
import java.util.List;

/**
 * Unit tests for PlSql lexer and parser using dynamic class loading.
 *
 * Tests that the lexer and parser can successfully parse various PL/SQL constructs
 * from the test resource files. Classes are loaded dynamically via reflection to avoid
 * compile-time dependencies on generated ANTLR sources.
 */
public class PlSqlLexerParserTest {

    private List<File> testSqlFiles;
    private Class<?> lexerClass;
    private Class<?> parserClass;
    private Constructor<?> lexerConstructor;
    private Constructor<?> parserConstructor;
    private Method scriptMethod;

    @Before
    public void setupTestFiles() throws Exception {
        testSqlFiles = TestResourceDirectoryProvider.getSqlFilesInDirectory(
            new File("src/test/resources/plsql")
        );
        Assert.assertTrue("No SQL test files found in src/test/resources/plsql", !testSqlFiles.isEmpty());

        // Dynamically load PlSqlLexer and PlSqlParser classes
        loadParserClasses();
    }

    private void loadParserClasses() throws Exception {
        try {
            lexerClass = Class.forName("name.jurgenei.parsers.PlSqlLexer");
            parserClass = Class.forName("name.jurgenei.parsers.PlSqlParser");

            lexerConstructor = lexerClass.getConstructor(CharStream.class);
            parserConstructor = parserClass.getConstructor(TokenStream.class);
            scriptMethod = parserClass.getMethod("script");
        } catch (ClassNotFoundException ex) {
            throw new RuntimeException("Could not load ANTLR-generated parser classes. " +
                    "Ensure 'generateParserSources' and 'compileAntlrSources' tasks have completed.", ex);
        }
    }

    @Test
    public void canParsePlSqlTestFiles() throws Exception {
        for (File sqlFile : testSqlFiles) {
            try (InputStream is = Files.newInputStream(sqlFile.toPath())) {
                CharStream charStream = CharStreams.fromStream(is, StandardCharsets.UTF_8);
                Lexer lexer = (Lexer) lexerConstructor.newInstance(charStream);
                CommonTokenStream tokenStream = new CommonTokenStream(lexer);
                Parser parser = (Parser) parserConstructor.newInstance(tokenStream);

                // Suppress error messages for cleaner output
                parser.removeErrorListeners();
                parser.addErrorListener(new BaseErrorListener() {
                    @Override
                    public void syntaxError(Recognizer<?, ?> recognizer, Object offendingSymbol,
                                            int line, int charPositionInLine, String msg, RecognitionException e) {
                        Assert.fail("Parse error in " + sqlFile.getName() +
                                    " at line " + line + ": " + msg);
                    }
                });

                // Parse the script using reflection
                Object tree = scriptMethod.invoke(parser);
                Assert.assertNotNull("Parse tree should not be null for " + sqlFile.getName(), tree);

                System.out.println("✓ Parsed: " + sqlFile.getName());
            }
        }
    }

    @Test
    public void lexerTokenizesInput() throws Exception {
        if (testSqlFiles.isEmpty()) {
            return;
        }

        File testFile = testSqlFiles.get(0);
        try (InputStream is = Files.newInputStream(testFile.toPath())) {
            CharStream charStream = CharStreams.fromStream(is, StandardCharsets.UTF_8);
            Lexer lexer = (Lexer) lexerConstructor.newInstance(charStream);
            CommonTokenStream tokenStream = new CommonTokenStream(lexer);
            tokenStream.fill();

            Assert.assertTrue("Lexer should produce at least one token",
                            tokenStream.getNumberOfOnChannelTokens() > 0);
            System.out.println("✓ Lexer tokenized " + tokenStream.size() + " tokens");
        }
    }
}

