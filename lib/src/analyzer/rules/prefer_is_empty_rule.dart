import '../../common/common.dart';
import 'analysis_rule.dart';

/// Detects usage of `.length == 0`, `.length != 0`, `.length > 0`
/// and recommends `.isEmpty` / `.isNotEmpty` instead for readability
/// and performance.
class PreferIsEmptyRule extends AnalysisRule {
  const PreferIsEmptyRule();

  static final _lengthZeroPatterns = [
    RegExp(r'\.length\s*==\s*0(?!\d)'),
    RegExp(r'\.length\s*!=\s*0(?!\d)'),
    RegExp(r'\.length\s*>\s*0(?!\d)'),
    RegExp(r'\.length\s*<\s*1(?!\d)'),
    RegExp(r'0\s*==\s*\w+\.length'),
    RegExp(r'0\s*<\s*\w+\.length'),
  ];

  @override
  List<Finding> analyze(String filePath, String source, List<String> lines) {
    final findings = <Finding>[];

    for (var i = 0; i < lines.length; i++) {
      final line = lines[i];
      final trimmed = line.trimLeft();

      // Skip comments
      if (trimmed.startsWith('//') || trimmed.startsWith('*') || trimmed.startsWith('///')) {
        continue;
      }

      for (final pattern in _lengthZeroPatterns) {
        final matches = pattern.allMatches(line);
        for (final match in matches) {
          final matchStr = match.group(0)!;
          final String suggestion;

          if (matchStr.contains('== 0') || matchStr.contains('< 1')) {
            suggestion = '.isEmpty';
          } else {
            suggestion = '.isNotEmpty';
          }

          findings.add(Finding(
            ruleId: 'analyzer/prefer-is-empty',
            message:
                'Use "$suggestion" instead of "${match.group(0)}" '
                'for clearer intent and better performance on '
                'Iterable types.',
            severity: FindingSeverity.note,
            filePath: filePath,
            line: i + 1,
            column: match.start + 1,
          ));
        }
      }
    }

    return findings;
  }
}
