import '../../common/common.dart';
import 'analysis_rule.dart';

/// Detects top-level or static variables that are assigned a constant value
/// and could be declared as `const` instead of `final`.
///
/// `const` declarations are evaluated at compile time, providing better
/// performance and smaller code size.
class PreferConstDeclarationsRule extends AnalysisRule {
  const PreferConstDeclarationsRule();

  // Match final top-level/static declarations with literal values
  static final _finalWithLiteralPattern = RegExp(
    r'^\s*(?:static\s+)?final\s+(\w+(?:<[^>]*>)?)\s+(\w+)\s*=\s*(.+);',
  );

  // Patterns for constant expressions
  static final _constLiteralPatterns = [
    RegExp(r"^'[^']*'$"), // String literal (single quotes)
    RegExp(r'^"[^"]*"$'), // String literal (double quotes)
    RegExp(r'^\d+(?:\.\d+)?$'), // Number literal
    RegExp(r'^(?:true|false)$'), // Boolean literal
    RegExp(r'^null$'), // Null literal
  ];

  @override
  List<Finding> analyze(String filePath, String source, List<String> lines) {
    final findings = <Finding>[];

    for (var i = 0; i < lines.length; i++) {
      final match = _finalWithLiteralPattern.firstMatch(lines[i]);
      if (match == null) continue;

      final trimmed = lines[i].trimLeft();

      // Skip if already const
      if (trimmed.startsWith('const ')) continue;

      // Skip if inside a method/function body (only suggest for top-level/class-level)
      // Simple heuristic: check indentation level (0 or 2 spaces for top-level/class-level)
      final indent = lines[i].length - trimmed.length;
      if (indent > 4) continue;

      final value = match.group(3)!.trim();

      // Check if value is a constant expression
      if (_isConstantExpression(value)) {
        final name = match.group(2)!;
        findings.add(Finding(
          ruleId: 'analyzer/prefer-const-declarations',
          message:
              'Variable "$name" is assigned a constant value. '
              'Use "const" instead of "final" for compile-time '
              'constant optimization.',
          severity: FindingSeverity.note,
          filePath: filePath,
          line: i + 1,
        ));
      }
    }

    return findings;
  }

  bool _isConstantExpression(String value) {
    return _constLiteralPatterns.any((p) => p.hasMatch(value));
  }
}
