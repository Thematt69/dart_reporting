import '../../common/common.dart';
import 'analysis_rule.dart';

/// Detects empty catch blocks that silently swallow errors.
///
/// Empty catch blocks make debugging difficult and can hide bugs.
/// At minimum, log the error or add a comment explaining why
/// the exception is intentionally ignored.
class AvoidEmptyCatchRule extends AnalysisRule {
  const AvoidEmptyCatchRule();

  static final _catchPattern = RegExp(
    r'\}\s*catch\s*\([^)]*\)\s*\{',
  );

  @override
  List<Finding> analyze(String filePath, String source, List<String> lines) {
    final findings = <Finding>[];

    final matches = _catchPattern.allMatches(source);
    for (final match in matches) {
      // The { at the end of the match is the start of the catch body
      final catchBodyStart = match.end - 1;

      // Extract the catch body
      final catchBody = _extractBody(source, catchBodyStart);
      if (catchBody == null) continue;

      // Check if the body is empty (only whitespace/newlines)
      final bodyContent = catchBody
          .substring(1, catchBody.length - 1)
          .trim();

      if (bodyContent.isEmpty) {
        final lineNum = source.substring(0, match.start).split('\n').length;
        findings.add(Finding(
          ruleId: 'analyzer/avoid-empty-catch',
          message:
              'Empty catch block silently swallows the error. '
              'Log the error, rethrow it, or add a comment explaining '
              'why the exception is intentionally ignored.',
          severity: FindingSeverity.warning,
          filePath: filePath,
          line: lineNum,
        ));
      }
    }

    return findings;
  }

  String? _extractBody(String source, int start) {
    var braceCount = 0;
    var foundOpen = false;

    for (var i = start; i < source.length; i++) {
      if (source[i] == '{') {
        braceCount++;
        foundOpen = true;
      } else if (source[i] == '}') {
        braceCount--;
      }
      if (foundOpen && braceCount == 0) {
        return source.substring(start, i + 1);
      }
    }
    return null;
  }
}
