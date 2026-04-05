/// Represents the coverage data for a single source file.
final class FileCoverage {
  final String sourceFile;
  final Map<int, int> lineCoverage; // line number -> hit count

  const FileCoverage({
    required this.sourceFile,
    required this.lineCoverage,
  });

  int get linesFound => lineCoverage.length;
  int get linesHit => lineCoverage.values.where((h) => h > 0).length;

  double get coveragePercent =>
      linesFound == 0 ? 100.0 : (linesHit / linesFound) * 100.0;
}

/// Aggregate coverage summary across all files.
final class CoverageSummary {
  final List<FileCoverage> files;
  final int totalLinesFound;
  final int totalLinesHit;
  final double coveragePercent;

  const CoverageSummary({
    required this.files,
    required this.totalLinesFound,
    required this.totalLinesHit,
    required this.coveragePercent,
  });
}
