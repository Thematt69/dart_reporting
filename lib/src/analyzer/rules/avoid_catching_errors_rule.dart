import '../../common/common.dart';
import 'analysis_rule.dart';

/// Detects `catch (Error)` blocks that catch `Error` instead of `Exception`.
///
/// `Error` and its subclasses represent programming bugs (like
/// `StackOverflowError`, `OutOfMemoryError`) that should not be caught.
/// Only catch `Exception` and its subclasses for recoverable errors.
class AvoidCatchingErrorsRule extends AnalysisRule {
  const AvoidCatchingErrorsRule();

  static final _catchErrorPattern = RegExp(
    r'}\s*on\s+(Error|StateError|UnsupportedError|RangeError|TypeError|StackOverflowError|OutOfMemoryError|ConcurrentModificationError|CyclicInitializationError|AssertionError)\b',
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

      final match = _catchErrorPattern.firstMatch(lines[i]);
      if (match != null) {
        final errorType = match.group(1)!;
        findings.add(Finding(
          ruleId: 'analyzer/avoid-catching-errors',
          message:
              'Avoid catching "$errorType". Errors represent programming '
              'bugs and should not be caught. Catch "Exception" instead '
              'for recoverable errors.',
          severity: FindingSeverity.warning,
          filePath: filePath,
          line: i + 1,
        ));
      }
    }

    return findings;
  }
}
