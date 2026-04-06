import '../../common/common.dart';
import 'analysis_rule.dart';

/// Detects local variables declared with `var` that are never reassigned
/// and could be declared with `final`.
///
/// Using `final` for variables that are never reassigned makes the code
/// more predictable and helps prevent accidental mutations.
class PreferFinalLocalsRule extends AnalysisRule {
  const PreferFinalLocalsRule();

  // Match var declarations inside method bodies
  static final _varDeclarationPattern = RegExp(
    r'^\s+var\s+(\w+)\s*=',
  );

  @override
  List<Finding> analyze(String filePath, String source, List<String> lines) {
    final findings = <Finding>[];

    for (var i = 0; i < lines.length; i++) {
      final match = _varDeclarationPattern.firstMatch(lines[i]);
      if (match == null) continue;

      final trimmed = lines[i].trimLeft();

      // Skip comments
      if (trimmed.startsWith('//') || trimmed.startsWith('*')) continue;

      // Only check inside method bodies (indentation > 2)
      final indent = lines[i].length - trimmed.length;
      if (indent < 4) continue;

      final varName = match.group(1)!;

      // Check if the variable is reassigned later in the same scope
      var isReassigned = false;
      var braceDepth = 0;

      for (var j = i + 1; j < lines.length; j++) {
        for (var c = 0; c < lines[j].length; c++) {
          if (lines[j][c] == '{') braceDepth++;
          if (lines[j][c] == '}') braceDepth--;
        }

        // Left the scope
        if (braceDepth < 0) break;

        // Check for reassignment patterns
        final reassignPattern = RegExp(
          '(?<![\\w.])${RegExp.escape(varName)}\\s*(?:=(?!=)|\\+\\+|--|\\+=|-=|\\*=|/=|\\|=|&=)',
        );
        if (reassignPattern.hasMatch(lines[j])) {
          isReassigned = true;
          break;
        }
      }

      if (!isReassigned) {
        findings.add(Finding(
          ruleId: 'analyzer/prefer-final-locals',
          message:
              'Local variable "$varName" is never reassigned. '
              'Use "final" instead of "var" to indicate immutability.',
          severity: FindingSeverity.note,
          filePath: filePath,
          line: i + 1,
        ));
      }
    }

    return findings;
  }
}
