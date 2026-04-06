import '../../common/common.dart';

/// Base class for analysis rules.
abstract class AnalysisRule {
  const AnalysisRule();

  /// Analyzes the given source file and returns findings.
  List<Finding> analyze(String filePath, String source, List<String> lines);
}
