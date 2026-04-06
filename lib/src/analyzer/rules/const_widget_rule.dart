import '../../common/common.dart';
import 'analysis_rule.dart';

/// Detects widget constructors that could be declared as const
/// but are not using the const keyword.
class ConstWidgetRule extends AnalysisRule {
  const ConstWidgetRule();

  static final _widgetPattern = RegExp(
    r'(?<!const\s)(?<!const\s{2})(?<!\w)(SizedBox|Spacer|Divider)\s*\(\s*\)',
  );

  @override
  List<Finding> analyze(String filePath, String source, List<String> lines) {
    final findings = <Finding>[];

    for (var i = 0; i < lines.length; i++) {
      final line = lines[i];

      // Check for common zero-argument widget constructors that should be const
      final matches = _widgetPattern.allMatches(line);
      for (final match in matches) {
        // Verify it's not already preceded by const
        final precedingText =
            line.substring(0, match.start).trimRight();
        if (precedingText.endsWith('const')) continue;

        final widgetName = match.group(1);
        findings.add(Finding(
          ruleId: 'analyzer/prefer-const-widget',
          message:
              'Use "const $widgetName()" instead of "$widgetName()" '
              'to enable compile-time constant optimization and avoid '
              'unnecessary widget rebuilds.',
          severity: FindingSeverity.note,
          filePath: filePath,
          line: i + 1,
          column: match.start + 1,
        ));
      }
    }

    return findings;
  }
}
