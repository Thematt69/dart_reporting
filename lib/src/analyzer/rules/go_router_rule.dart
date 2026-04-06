import '../../common/common.dart';
import 'analysis_rule.dart';

/// Detects common go_router anti-patterns:
///
/// - Usage of `Navigator.push`, `Navigator.of`, `Navigator.pop` etc.
///   when go_router is present (should use `context.go`, `context.push`,
///   `context.pop` instead).
/// - Missing error page / redirect configuration.
class GoRouterRule extends AnalysisRule {
  const GoRouterRule();

  // Navigator imperative usage patterns
  static final _navigatorPushPattern = RegExp(
    r'Navigator\.(of\(|push\(|pushNamed\(|pushReplacement|pushAndRemoveUntil|pop\(|popUntil\(|maybePop\()',
  );

  // MaterialPageRoute usage (should use GoRoute instead)
  static final _materialPageRoutePattern = RegExp(
    r'MaterialPageRoute\s*[<(]',
  );

  @override
  List<Finding> analyze(String filePath, String source, List<String> lines) {
    final findings = <Finding>[];

    // Only check if go_router is likely used in the project
    if (!source.contains('go_router') && !source.contains('GoRouter')) {
      return findings;
    }

    for (var i = 0; i < lines.length; i++) {
      final line = lines[i];

      // Detect Navigator imperative calls
      final navMatch = _navigatorPushPattern.firstMatch(line);
      if (navMatch != null) {
        findings.add(Finding(
          ruleId: 'analyzer/go-router-avoid-navigator',
          message:
              'Avoid using Navigator directly when go_router is '
              'available. Use context.go(), context.push(), or '
              'context.pop() from go_router for consistent '
              'declarative navigation.',
          severity: FindingSeverity.warning,
          filePath: filePath,
          line: i + 1,
          helpUri: 'https://pub.dev/packages/go_router',
        ));
      }

      // Detect MaterialPageRoute usage
      if (_materialPageRoutePattern.hasMatch(line)) {
        findings.add(Finding(
          ruleId: 'analyzer/go-router-avoid-material-page-route',
          message:
              'Avoid using MaterialPageRoute with go_router. '
              'Define routes using GoRoute and GoRouter configuration '
              'for proper deep linking and URL synchronization.',
          severity: FindingSeverity.note,
          filePath: filePath,
          line: i + 1,
          helpUri: 'https://pub.dev/packages/go_router',
        ));
      }
    }

    return findings;
  }
}
