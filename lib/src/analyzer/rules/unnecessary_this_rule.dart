import '../../common/common.dart';
import 'analysis_rule.dart';

/// Detects unnecessary usage of the `this` keyword.
///
/// In Dart, `this` is only necessary when there's a naming conflict
/// between a parameter and a field. Using `this` unnecessarily adds
/// noise to the code.
class UnnecessaryThisRule extends AnalysisRule {
  const UnnecessaryThisRule();

  // Match this.field access in method bodies
  static final _thisPattern = RegExp(
    r'(?<!\w)this\.(\w+)',
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

      // Skip constructor initializer lists and constructor parameters
      if (trimmed.startsWith('this.') && trimmed.contains(',') ||
          trimmed.contains('required this.') ||
          trimmed.contains(': this.') ||
          trimmed.contains('{this.')) {
        continue;
      }

      final matches = _thisPattern.allMatches(lines[i]);
      for (final match in matches) {
        final fieldName = match.group(1)!;

        // Check if this is a constructor parameter declaration (this.field)
        // Constructor params: ClassName(this.field) or ClassName({this.field})
        final beforeThis = lines[i].substring(0, match.start).trimRight();
        final isConstructorParam =
            (beforeThis.endsWith('{') || beforeThis.endsWith('required')) ||
            (beforeThis.endsWith('(') && _isConstructorDeclaration(beforeThis)) ||
            (beforeThis.endsWith(',') && _isInConstructorParams(lines, i));
        if (isConstructorParam) {
          continue;
        }

        // Check if there's a local variable/parameter with the same name
        // that would require disambiguation
        final hasConflict = _hasNamingConflict(lines, i, fieldName);

        if (!hasConflict) {
          findings.add(Finding(
            ruleId: 'analyzer/unnecessary-this',
            message:
                'Unnecessary "this." before "$fieldName". '
                'Remove "this." when there is no naming conflict.',
            severity: FindingSeverity.note,
            filePath: filePath,
            line: i + 1,
            column: match.start + 1,
          ));
        }
      }
    }

    return findings;
  }

  /// Checks if the text before `(this.` looks like a constructor declaration
  /// (e.g., `ClassName(` or `ClassName.named(`) vs a method call (e.g., `print(`).
  bool _isConstructorDeclaration(String beforeParen) {
    // Constructor: ClassName( — starts with uppercase
    final beforeParenTrimmed = beforeParen.trimRight();
    if (!beforeParenTrimmed.endsWith('(')) return false;
    final withoutParen = beforeParenTrimmed.substring(0, beforeParenTrimmed.length - 1).trimRight();
    if (withoutParen.isEmpty) return false;
    // Constructor names start with an uppercase letter
    final lastWord = RegExp(r'(\w+)$').firstMatch(withoutParen);
    if (lastWord == null) return false;
    final name = lastWord.group(1)!;
    return name[0] == name[0].toUpperCase() && name[0] != name[0].toLowerCase();
  }

  /// Checks if we're inside a constructor parameter list by looking backwards
  bool _isInConstructorParams(List<String> lines, int lineIndex) {
    for (var i = lineIndex; i >= (lineIndex - 10).clamp(0, lineIndex); i--) {
      if (lines[i].contains('this.') && _isConstructorDeclaration(
        lines[i].substring(0, lines[i].indexOf('this.')))) {
        return true;
      }
      // Look for a constructor declaration line
      final constructorPattern = RegExp(r'\b[A-Z]\w*\s*\.\s*\w+\s*\(|^\s*\b[A-Z]\w*\s*\(');
      if (constructorPattern.hasMatch(lines[i])) {
        return true;
      }
    }
    return false;
  }

  bool _hasNamingConflict(List<String> lines, int currentLine, String name) {
    // Look backwards for a parameter or local variable with the same name
    // Only look within the current method scope
    for (var i = currentLine; i >= (currentLine - 30).clamp(0, currentLine); i--) {
      final trimmed = lines[i].trimLeft();

      // Stop at class-level declarations (not inside a method)
      // A class field won't cause a naming conflict with this.field
      final indent = lines[i].length - trimmed.length;
      if (indent <= 2 && !trimmed.startsWith('}') && !trimmed.startsWith('{') &&
          !trimmed.startsWith('//') && trimmed.isNotEmpty &&
          !trimmed.startsWith('void ') && !trimmed.startsWith('Future ') &&
          !trimmed.startsWith('@')) {
        // We've reached a class-level declaration; stop searching
        break;
      }

      // Check for method/function declaration with a parameter of the same name
      if ((trimmed.contains('void ') || trimmed.contains('Future ') ||
           trimmed.contains('Widget ') || trimmed.contains('String ') && trimmed.contains('(')) &&
          (trimmed.contains('($name') ||
           trimmed.contains(', $name') ||
           trimmed.contains('{$name') ||
           trimmed.contains('$name,'))) {
        return true;
      }

      // Check for local variable declaration (must be inside method, indent >= 4)
      if (indent >= 4) {
        if (trimmed.startsWith('var $name ') ||
            trimmed.startsWith('final $name ') ||
            trimmed.startsWith('int $name') ||
            trimmed.startsWith('String $name') ||
            trimmed.startsWith('double $name') ||
            trimmed.startsWith('bool $name')) {
          return true;
        }
      }
    }

    return false;
  }
}
