package name.jurgenei.parsers;

import java.io.File;
import java.nio.file.*;
import java.util.*;
import java.util.stream.Collectors;
import java.util.stream.Stream;

/**
 * Utility class to dynamically provide test resource directories for PL/SQL grammar tests.
 *
 * Supports multiple directory selection via system property:
 * - Property: {@code testResourceDirs}
 * - Values:
 *   - Single: "antlr-issue", "benchmark", "plsql", or path
 *   - Multiple: comma-separated list, e.g., "antlr-issue,benchmark"
 *   - All: "*" or empty (uses all available)
 *
 * Also supports individual flags via properties:
 * - {@code test.use.antlr-issue=true/false}
 * - {@code test.use.benchmark=true/false}
 * - {@code test.use.plsql=true/false}
 */
public class TestResourceDirectoryProvider {

    private static final String BASE_TEST_RESOURCES = "src/test/resources";
    private static final String PROPERTY_DIRS = "testResourceDirs";
    private static final String PROPERTY_PREFIX = "test.use.";
    private static final List<String> DEFAULT_DIRS = List.of("antlr-issue", "benchmark", "plsql");

    /**
     * Get list of directories to test based on system properties.
     *
     * @return List of File objects pointing to test resource directories
     * @throws IllegalArgumentException if specified directories don't exist
     */
    public static List<File> getTestDirectories() {
        List<String> dirNames = resolveDirectoryNames();
        return dirNames.stream()
                .map(TestResourceDirectoryProvider::resolveDirectory)
                .filter(Objects::nonNull)
                .collect(Collectors.toList());
    }

    /**
     * Get all SQL files from the selected test directories.
     *
     * @return List of SQL files found
     */
    public static List<File> getAllTestSqlFiles() {
        return getTestDirectories().stream()
                .flatMap(dir -> {
                    try {
                        return Files.walk(dir.toPath())
                                .filter(p -> p.toString().endsWith(".sql"))
                                .map(Path::toFile)
                                .sorted(Comparator.comparing(File::getAbsolutePath));
                    } catch (Exception e) {
                        System.err.println("Error walking directory: " + dir);
                        return Stream.empty();
                    }
                })
                .collect(Collectors.toList());
    }

    /**
     * Get SQL files from a specific directory.
     *
     * @param directory the directory to search
     * @return List of SQL files
     */
    public static List<File> getSqlFilesInDirectory(File directory) {
        try {
            return Files.walk(directory.toPath())
                    .filter(p -> p.toString().endsWith(".sql"))
                    .map(Path::toFile)
                    .sorted(Comparator.comparing(File::getAbsolutePath))
                    .collect(Collectors.toList());
        } catch (Exception e) {
            System.err.println("Error reading directory: " + directory);
            return Collections.emptyList();
        }
    }

    /**
     * Resolve which directories should be used based on system properties.
     */
    private static List<String> resolveDirectoryNames() {
        // Check for explicit directory list property
        String dirsProp = System.getProperty(PROPERTY_DIRS, "").trim();

        if (!dirsProp.isEmpty()) {
            if (dirsProp.equals("*")) {
                return DEFAULT_DIRS;
            }
            return Arrays.stream(dirsProp.split(","))
                    .map(String::trim)
                    .filter(s -> !s.isEmpty())
                    .collect(Collectors.toList());
        }

        // Check for individual directory flags
        List<String> selected = new ArrayList<>();
        for (String dir : DEFAULT_DIRS) {
            if (Boolean.parseBoolean(System.getProperty(PROPERTY_PREFIX + dir, "true"))) {
                selected.add(dir);
            }
        }

        return selected.isEmpty() ? DEFAULT_DIRS : selected;
    }

    /**
     * Resolve a single directory name or path to a File object.
     */
    private static File resolveDirectory(String dirNameOrPath) {
        // Try as a relative path first (just the directory name)
        File relativeDir = new File(BASE_TEST_RESOURCES, dirNameOrPath);
        if (relativeDir.isDirectory()) {
            return relativeDir;
        }

        // Try as an absolute/relative path
        File pathDir = new File(dirNameOrPath);
        if (pathDir.isDirectory()) {
            return pathDir;
        }

        // Try from project root
        File rootRelative = new File(BASE_TEST_RESOURCES, dirNameOrPath);
        if (rootRelative.isDirectory()) {
            return rootRelative;
        }

        System.err.println("Warning: Directory not found: " + dirNameOrPath);
        return null;
    }

    /**
     * Print available test directories and currently selected ones.
     */
    public static void printStatus() {
        System.out.println("\n========== TEST RESOURCE DIRECTORIES ==========");
        System.out.println("Base path: " + BASE_TEST_RESOURCES);

        System.out.println("\nAvailable directories:");
        for (String dir : DEFAULT_DIRS) {
            File f = new File(BASE_TEST_RESOURCES, dir);
            if (f.isDirectory()) {
                long fileCount = getSqlFilesInDirectory(f).size();
                System.out.printf("  - %s (%d SQL files)%n", dir, fileCount);
            }
        }

        System.out.println("\nSelected directories:");
        List<File> selected = getTestDirectories();
        for (File dir : selected) {
            long fileCount = getSqlFilesInDirectory(dir).size();
            System.out.printf("  - %s (%d SQL files)%n", dir.getName(), fileCount);
        }

        System.out.println("\nConfiguration:");
        System.out.println("  Property 'testResourceDirs': " + System.getProperty(PROPERTY_DIRS, "[not set]"));
        for (String dir : DEFAULT_DIRS) {
            String val = System.getProperty(PROPERTY_PREFIX + dir, "[not set]");
            System.out.printf("  Property '%s%s': %s%n", PROPERTY_PREFIX, dir, val);
        }
        System.out.println("==============================================\n");
    }
}

