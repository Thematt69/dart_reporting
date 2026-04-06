import '../../common/common.dart';
import 'analysis_rule.dart';

/// Detects `void` async functions that should return `Future<void>`.
///
/// Declaring an async function as `void` makes it fire-and-forget:
/// exceptions are silently swallowed and the caller cannot await it.
/// Use `Future<void>` instead to ensure proper error propagation.
class AvoidVoidAsyncRule extends AnalysisRule {
  const AvoidVoidAsyncRule();

  static final _voidAsyncPattern = RegExp(
    r'^\s*(?:@\w+\s+)*void\s+(\w+)\s*(?:<[^>]*>)?\s*\([^)]*\)\s*async\b',
  );

  @override
  List<Finding> analyze(String filePath, String source, List<String> lines) {
    final findings = <Finding>[];

    for (var i = 0; i < lines.length; i++) {
      final match = _voidAsyncPattern.firstMatch(lines[i]);
      if (match == null) continue;

      final methodName = match.group(1)!;

      // Skip common Flutter lifecycle methods that are meant to be void
      if (methodName == 'initState' ||
          methodName == 'dispose' ||
          methodName == 'didChangeDependencies' ||
          methodName == 'didUpdateWidget' ||
          methodName == 'main') {
        continue;
      }

      // Skip overrides — they must match the parent signature
      if (i > 0 && lines[i - 1].trim() == '@override') continue;

      findings.add(Finding(
        ruleId: 'analyzer/avoid-void-async',
        message:
            'Function "$methodName" is declared as "void async". '
            'Use "Future<void>" instead to enable proper error handling '
            'and allow callers to await the result.',
        severity: FindingSeverity.warning,
        filePath: filePath,
        line: i + 1,
      ));
    }

    return findings;
  }
}
