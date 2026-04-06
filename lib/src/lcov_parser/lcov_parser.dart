import 'lcov_models.dart';

/// Parses LCOV coverage files and computes coverage metrics.
///
/// Filters out auto-generated files (e.g., `*.g.dart`, `*.freezed.dart`)
/// to provide accurate human-authored code coverage.
class LcovParser {
  /// Patterns to exclude from coverage calculation (auto-generated files).
  static const List<String> _defaultExcludePatterns = [
    '.g.dart',
    '.freezed.dart',
    '.gr.dart',
    '.gen.dart',
    '.mocks.dart',
  ];

  final List<String> excludePatterns;

  const LcovParser({this.excludePatterns = _defaultExcludePatterns});

  /// Parses raw LCOV content into a [CoverageSummary].
  CoverageSummary parse(String lcovContent) {
    final files = <FileCoverage>[];
    String? currentFile;
    var lineCoverage = <int, int>{};

    for (final line in lcovContent.split('\n')) {
      final trimmed = line.trim();
      if (trimmed.isEmpty) continue;

      if (trimmed.startsWith('SF:')) {
        currentFile = trimmed.substring(3);
        lineCoverage = <int, int>{};
      } else if (trimmed.startsWith('DA:')) {
        final parts = trimmed.substring(3).split(',');
        if (parts.length >= 2) {
          final lineNum = int.tryParse(parts[0]);
          final hitCount = int.tryParse(parts[1]);
          if (lineNum != null && hitCount != null) {
            lineCoverage[lineNum] = hitCount;
          }
        }
      } else if (trimmed == 'end_of_record') {
        if (currentFile != null && !_isExcluded(currentFile)) {
          files.add(FileCoverage(
            sourceFile: currentFile,
            lineCoverage: Map.unmodifiable(lineCoverage),
          ));
        }
        currentFile = null;
        lineCoverage = <int, int>{};
      }
    }

    final totalFound = files.fold<int>(0, (s, f) => s + f.linesFound);
    final totalHit = files.fold<int>(0, (s, f) => s + f.linesHit);
    final percent = totalFound == 0 ? 100.0 : (totalHit / totalFound) * 100.0;

    return CoverageSummary(
      files: files,
      totalLinesFound: totalFound,
      totalLinesHit: totalHit,
      coveragePercent: percent,
    );
  }

  bool _isExcluded(String filePath) {
    return excludePatterns.any((p) => filePath.endsWith(p));
  }
}
