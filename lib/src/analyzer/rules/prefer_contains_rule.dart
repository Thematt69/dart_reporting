import '../../common/common.dart';
import 'analysis_rule.dart';

/// Detects usage of `indexOf()` to check for containment, which should
/// use `contains()` instead.
///
/// `list.contains(x)` is more readable and expressive than
/// `list.indexOf(x) != -1` or `list.indexOf(x) >= 0`.
class PreferContainsRule extends AnalysisRule {
  const PreferContainsRule();

  // indexOf() compared to -1 or >= 0
  static final _indexOfComparisonPatterns = [
    RegExp(r'\.indexOf\s*\([^)]+\)\s*!=\s*-1'),
    RegExp(r'\.indexOf\s*\([^)]+\)\s*>=\s*0'),
    RegExp(r'\.indexOf\s*\([^)]+\)\s*>\s*-1'),
    RegExp(r'\.indexOf\s*\([^)]+\)\s*==\s*-1'),
    RegExp(r'-1\s*!=\s*\w+\.indexOf\s*\('),
    RegExp(r'-1\s*==\s*\w+\.indexOf\s*\('),
  ];

  @override
  List<Finding> analyze(String filePath, String source, List<String> lines) {
    final findings = <Finding>[];

    for (var i = 0; i < lines.length; i++) {
      final trimmed = lines[i].trimLeft();

      // Skip comments
      if (trimmed.startsWith('//') || trimmed.startsWith('*') || trimmed.startsWith('///')) {
        continue;
      }

      for (final pattern in _indexOfComparisonPatterns) {
        if (pattern.hasMatch(lines[i])) {
          final isNegativeCheck = lines[i].contains('== -1');

          findings.add(Finding(
            ruleId: 'analyzer/prefer-contains',
            message: isNegativeCheck
                ? 'Use "!collection.contains(element)" instead of '
                  '"collection.indexOf(element) == -1" for clarity.'
                : 'Use "collection.contains(element)" instead of '
                  '"collection.indexOf(element) != -1" for clarity.',
            severity: FindingSeverity.note,
            filePath: filePath,
            line: i + 1,
          ));
          break; // One finding per line
        }
      }
    }

    return findings;
  }
}
