import '../../common/common.dart';
import 'analysis_rule.dart';

/// Detects usage of `print()` in production code.
///
/// `print()` should be avoided in production code. Use `debugPrint()`,
/// a `Logger`, or `log()` from `dart:developer` instead.
class AvoidPrintRule extends AnalysisRule {
  const AvoidPrintRule();

  static final _printPattern = RegExp(
    r'(?<!\w)print\s*\(',
  );

  static final _debugPrintPattern = RegExp(
    r'(?<!\w)debugPrint\s*\(',
  );

  @override
  List<Finding> analyze(String filePath, String source, List<String> lines) {
    final findings = <Finding>[];

    // Skip test files
    if (filePath.contains('_test.dart') || filePath.contains('/test/')) {
      return findings;
    }

    for (var i = 0; i < lines.length; i++) {
      final line = lines[i].trimLeft();

      // Skip comments
      if (line.startsWith('//') || line.startsWith('*') || line.startsWith('///')) {
        continue;
      }

      final matches = _printPattern.allMatches(lines[i]);
      for (final match in matches) {
        // Check it's not debugPrint
        if (_debugPrintPattern.hasMatch(
            lines[i].substring((match.start - 5).clamp(0, lines[i].length)))) {
          continue;
        }

        findings.add(Finding(
          ruleId: 'analyzer/avoid-print',
          message:
              'Avoid using print() in production code. '
              'Use debugPrint(), log() from dart:developer, '
              'or a proper logging package instead.',
          severity: FindingSeverity.warning,
          filePath: filePath,
          line: i + 1,
          column: match.start + 1,
        ));
      }
    }

    return findings;
  }
}
