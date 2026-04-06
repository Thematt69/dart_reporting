import '../../common/common.dart';
import 'analysis_rule.dart';

/// Detects logic in `createState()` method of `StatefulWidget`.
///
/// The `createState()` method should only return a new instance of the State
/// class. Any logic, variable assignment, or side effects in createState()
/// is a mistake — it runs every time the widget is inserted into the tree.
class NoLogicInCreateStateRule extends AnalysisRule {
  const NoLogicInCreateStateRule();

  static final _createStatePattern = RegExp(
    r'State\s*<\w+>\s+createState\s*\(\)',
  );

  @override
  List<Finding> analyze(String filePath, String source, List<String> lines) {
    final findings = <Finding>[];

    if (!source.contains('StatefulWidget')) return findings;

    for (var i = 0; i < lines.length; i++) {
      if (!_createStatePattern.hasMatch(lines[i])) continue;

      // Check if it's a one-liner with => (arrow function) — that's fine
      if (lines[i].contains('=>')) continue;

      // Look ahead for the method body
      var braceCount = 0;
      var bodyStarted = false;
      var statementCount = 0;

      for (var j = i; j < lines.length && j < i + 20; j++) {
        for (var c = 0; c < lines[j].length; c++) {
          if (lines[j][c] == '{') {
            braceCount++;
            bodyStarted = true;
          } else if (lines[j][c] == '}') {
            braceCount--;
          }
        }

        if (bodyStarted && j > i) {
          final trimmed = lines[j].trim();
          // Count statements (lines that aren't just braces or empty)
          if (trimmed.isNotEmpty &&
              trimmed != '{' &&
              trimmed != '}' &&
              !trimmed.startsWith('//')) {
            statementCount++;
          }
        }

        if (bodyStarted && braceCount == 0) break;
      }

      // If more than 1 statement (the return), there's extra logic
      if (statementCount > 1) {
        findings.add(Finding(
          ruleId: 'analyzer/no-logic-in-create-state',
          message:
              'createState() should only return a new State instance. '
              'Move initialization logic to initState() instead.',
          severity: FindingSeverity.warning,
          filePath: filePath,
          line: i + 1,
        ));
      }
    }

    return findings;
  }
}
