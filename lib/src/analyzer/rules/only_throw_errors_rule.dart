import '../../common/common.dart';
import 'analysis_rule.dart';

/// Detects `throw` expressions with non-Error/non-Exception objects.
///
/// Only `Error` and `Exception` objects (and their subclasses) should be
/// thrown. Throwing strings, numbers, or other objects makes error handling
/// unreliable.
class OnlyThrowErrorsRule extends AnalysisRule {
  const OnlyThrowErrorsRule();

  // throw followed by a string literal or number
  static final _throwLiteralPattern = RegExp(
    r"\bthrow\s+(?:'[^']*'|" r'"[^"]*"' r'|\d+)',
  );

  @override
  List<Finding> analyze(String filePath, String source, List<String> lines) {
    final findings = <Finding>[];

    for (var i = 0; i < lines.length; i++) {
      final trimmed = lines[i].trimLeft();

      // Skip comments
      if (trimmed.startsWith('//') || trimmed.startsWith('*') || trimmed.startsWith('///')) {
        continue;
      }

      if (_throwLiteralPattern.hasMatch(lines[i])) {
        findings.add(Finding(
          ruleId: 'analyzer/only-throw-errors',
          message:
              'Only throw Error or Exception objects. '
              'Throwing strings or other literals makes error '
              'handling unreliable and loses stack trace information.',
          severity: FindingSeverity.warning,
          filePath: filePath,
          line: i + 1,
        ));
      }
    }

    return findings;
  }
}
