import '../../common/common.dart';
import 'analysis_rule.dart';

/// Detects `BuildContext` being stored in a field or passed to async methods,
/// which can lead to using a context after the widget is unmounted.
class AvoidBuildContextInAsyncRule extends AnalysisRule {
  const AvoidBuildContextInAsyncRule();

  // BuildContext stored as a field
  static final _contextFieldPattern = RegExp(
    r'(?:final\s+)?BuildContext\s+\w+\s*[;=]',
  );

  // async function with BuildContext parameter
  static final _asyncWithContextPattern = RegExp(
    r'(?:Future(?:<[^>]*>)?|void)\s+\w+\s*\([^)]*BuildContext\s+\w+[^)]*\)\s*async\b',
  );

  @override
  List<Finding> analyze(String filePath, String source, List<String> lines) {
    final findings = <Finding>[];

    for (var i = 0; i < lines.length; i++) {
      final line = lines[i].trimLeft();

      // Skip comments
      if (line.startsWith('//') || line.startsWith('*') || line.startsWith('///')) {
        continue;
      }

      // Detect BuildContext stored as class field
      if (_contextFieldPattern.hasMatch(line) &&
          !line.contains('parameter') &&
          !line.contains('(') &&
          !line.contains('build')) {
        // Check if it's at class-member indentation level (not inside a method)
        // by verifying this line doesn't appear deeply nested
        final leadingSpaces = lines[i].length - lines[i].trimLeft().length;
        if (leadingSpaces > 0 && leadingSpaces <= 4) {
          findings.add(Finding(
            ruleId: 'analyzer/avoid-build-context-in-async',
            message:
                'Avoid storing BuildContext as a field. The context '
                'may become invalid if the widget is unmounted. '
                'Access context directly in build methods instead.',
            severity: FindingSeverity.warning,
            filePath: filePath,
            line: i + 1,
          ));
        }
      }

      // Detect async functions receiving BuildContext
      if (_asyncWithContextPattern.hasMatch(lines[i])) {
        findings.add(Finding(
          ruleId: 'analyzer/avoid-build-context-in-async',
          message:
              'Avoid passing BuildContext to async functions. '
              'The context may be invalid after an await. '
              'Check mounted before using context after await, '
              'or restructure to avoid passing context to async code.',
          severity: FindingSeverity.warning,
          filePath: filePath,
          line: i + 1,
        ));
      }
    }

    return findings;
  }
}
