import '../../common/common.dart';
import 'analysis_rule.dart';

/// Detects `Future`-returning expressions that are not awaited.
///
/// Unawaited futures can silently swallow errors and lead to
/// unpredictable execution order. Either `await` them or explicitly
/// use `unawaited()` to indicate fire-and-forget intent.
class UnawaitedFuturesRule extends AnalysisRule {
  const UnawaitedFuturesRule();

  // Common async methods that return Future
  static const _asyncMethods = [
    'Future.delayed',
    'Future.wait',
    'http.get',
    'http.post',
    'http.put',
    'http.delete',
    'showDialog',
    'showModalBottomSheet',
    'Navigator.push',
    'Navigator.pushNamed',
  ];

  // Pattern: method call on a line by itself (statement) that looks async
  static final _futureCallPattern = RegExp(
    r'^\s+(?!return\b)(?!await\b)(?!final\b)(?!var\b)(?!const\b)(\w+(?:\.\w+)*)\s*(?:<[^>]*>)?\s*\(',
  );

  @override
  List<Finding> analyze(String filePath, String source, List<String> lines) {
    final findings = <Finding>[];

    // Only check in async functions
    if (!source.contains('async')) return findings;

    var inAsyncFunction = false;
    var braceDepth = 0;
    var asyncFunctionBraceDepth = 0;

    for (var i = 0; i < lines.length; i++) {
      final line = lines[i];

      // Track brace depth for function boundary detection
      for (var c = 0; c < line.length; c++) {
        if (line[c] == '{') {
          braceDepth++;
        } else if (line[c] == '}') {
          braceDepth--;
          // If we've returned to the depth before the async function started,
          // we've exited the async function
          if (inAsyncFunction && braceDepth < asyncFunctionBraceDepth) {
            inAsyncFunction = false;
          }
        }
      }

      // Track async function boundaries
      if (line.contains('async') &&
          (line.contains('Future') || line.contains('void'))) {
        inAsyncFunction = true;
        asyncFunctionBraceDepth = braceDepth;
      }

      if (!inAsyncFunction) continue;

      // Check for function/method calls that look like they return futures
      final match = _futureCallPattern.firstMatch(line);
      if (match == null) continue;

      final methodCall = match.group(1)!;

      // Check if this is a known async method
      final isKnownAsync = _asyncMethods.any((m) => methodCall.endsWith(m));

      // Or if the method name suggests async behavior
      final suggestsAsync = methodCall.contains('fetch') ||
          methodCall.contains('load') ||
          methodCall.contains('save') ||
          methodCall.contains('delete') ||
          methodCall.contains('update') ||
          methodCall.contains('send') ||
          methodCall.contains('submit');

      if (isKnownAsync || suggestsAsync) {
        findings.add(Finding(
          ruleId: 'analyzer/unawaited-futures',
          message:
              'Future from "$methodCall()" is not awaited. '
              'Either await it, assign it to a variable, or use '
              'unawaited() to indicate intentional fire-and-forget.',
          severity: FindingSeverity.warning,
          filePath: filePath,
          line: i + 1,
        ));
      }
    }

    return findings;
  }
}
