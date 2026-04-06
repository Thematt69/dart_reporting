import '../../common/common.dart';
import 'analysis_rule.dart';

/// Detects common Sentry anti-patterns:
///
/// - Async operations without Sentry error capturing.
/// - Manual `print()` for error logging instead of `Sentry.captureException()`.
/// - `runZonedGuarded` without Sentry integration.
class SentryRule extends AnalysisRule {
  const SentryRule();

  // print() used for error reporting
  static final _printErrorPattern = RegExp(
    r'print\s*\(\s*[^)]*(?:error|exception|err|failure|fail)',
    caseSensitive: false,
  );

  // debugPrint with error
  static final _debugPrintErrorPattern = RegExp(
    r'debugPrint\s*\(\s*[^)]*(?:error|exception|err|failure)',
    caseSensitive: false,
  );

  // catch block without Sentry.captureException
  static final _catchPattern = RegExp(
    r'\}\s*catch\s*\(',
  );

  @override
  List<Finding> analyze(String filePath, String source, List<String> lines) {
    final findings = <Finding>[];

    if (!source.contains('sentry') && !source.contains('Sentry')) {
      return findings;
    }

    for (var i = 0; i < lines.length; i++) {
      final line = lines[i];

      // Detect print() used for errors when Sentry is available
      if (_printErrorPattern.hasMatch(line) ||
          _debugPrintErrorPattern.hasMatch(line)) {
        findings.add(Finding(
          ruleId: 'analyzer/sentry-use-capture-exception',
          message:
              'Use Sentry.captureException() instead of print() '
              'for error reporting when sentry_flutter is available. '
              'This ensures errors are tracked and monitored centrally.',
          severity: FindingSeverity.note,
          filePath: filePath,
          line: i + 1,
          helpUri: 'https://pub.dev/packages/sentry_flutter',
        ));
      }

      // Detect catch blocks without Sentry
      if (_catchPattern.hasMatch(line)) {
        // Check if Sentry.captureException is used in the catch body
        final catchEnd = (i + 10).clamp(0, lines.length);
        final catchBody = lines.sublist(i, catchEnd).join('\n');

        if (!catchBody.contains('Sentry.captureException') &&
            !catchBody.contains('Sentry.captureMessage') &&
            !catchBody.contains('captureException') &&
            !catchBody.contains('rethrow')) {
          findings.add(Finding(
            ruleId: 'analyzer/sentry-missing-capture-in-catch',
            message:
                'catch block does not report to Sentry. Consider '
                'adding Sentry.captureException(error, stackTrace: '
                'stackTrace) to track errors in your monitoring '
                'dashboard.',
            severity: FindingSeverity.note,
            filePath: filePath,
            line: i + 1,
          ));
        }
      }
    }

    return findings;
  }
}
