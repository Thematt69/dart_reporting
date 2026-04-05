import '../../common/common.dart';
import 'analysis_rule.dart';

/// Detects common Equatable anti-patterns:
///
/// - Classes extending `Equatable` with an empty `props` list.
/// - Classes extending `Equatable` that don't override `props`.
/// - Mutable fields in Equatable classes (should be immutable).
class EquatableRule extends AnalysisRule {
  const EquatableRule();

  // Class extending Equatable
  static final _equatableClassPattern = RegExp(
    r'class\s+(\w+)\s+(?:extends|with)\s+(?:\w+\s+(?:with|extends)\s+)*Equatable',
  );

  // Props override
  static final _propsPattern = RegExp(
    r'List<Object\??>\s+get\s+props\s*=>\s*\[([^\]]*)\]',
  );

  // Non-final fields
  static final _nonFinalFieldPattern = RegExp(
    r'^\s+(?!final\s|const\s|static\s)(?:late\s+)?(String|int|double|bool|List|Map|Set|\w+)\??\s+\w+\s*[;=]',
  );

  @override
  List<Finding> analyze(String filePath, String source, List<String> lines) {
    final findings = <Finding>[];

    if (!source.contains('Equatable')) return findings;

    for (final classMatch in _equatableClassPattern.allMatches(source)) {
      final className = classMatch.group(1)!;
      final classLine =
          source.substring(0, classMatch.start).split('\n').length;

      // Extract class body
      final classBody = _extractClassBody(source, classMatch.start);
      if (classBody == null) continue;

      // Check if props is overridden
      final propsMatch = _propsPattern.firstMatch(classBody);
      if (propsMatch == null) {
        findings.add(Finding(
          ruleId: 'analyzer/equatable-missing-props',
          message:
              'Class "$className" extends Equatable but does not '
              'override "props". Override the props getter to include '
              'all fields used for equality comparison.',
          severity: FindingSeverity.warning,
          filePath: filePath,
          line: classLine,
        ));
      } else {
        // Check for empty props
        final propsContent = propsMatch.group(1)?.trim() ?? '';
        if (propsContent.isEmpty) {
          final propsLine = source
              .substring(0, classMatch.start + propsMatch.start)
              .split('\n')
              .length;
          findings.add(Finding(
            ruleId: 'analyzer/equatable-empty-props',
            message:
                'Class "$className" extends Equatable with an empty '
                'props list. Add all fields used for equality comparison '
                'to the props list, or remove the Equatable extension '
                'if equality comparison is not needed.',
            severity: FindingSeverity.warning,
            filePath: filePath,
            line: propsLine,
          ));
        }
      }

      // Check for mutable (non-final) fields
      final classBodyLines = classBody.split('\n');
      for (var i = 0; i < classBodyLines.length; i++) {
        if (_nonFinalFieldPattern.hasMatch(classBodyLines[i])) {
          // Skip method parameter lines, return statements, etc.
          final trimmed = classBodyLines[i].trim();
          if (trimmed.startsWith('return') ||
              trimmed.startsWith('//') ||
              trimmed.contains('(') ||
              trimmed.contains(')')) {
            continue;
          }

          findings.add(Finding(
            ruleId: 'analyzer/equatable-mutable-field',
            message:
                'Class "$className" extends Equatable but has mutable '
                'fields. Equatable classes should use final fields to '
                'ensure immutability and correct equality semantics.',
            severity: FindingSeverity.note,
            filePath: filePath,
            line: classLine + i,
          ));
        }
      }
    }

    return findings;
  }

  String? _extractClassBody(String source, int classStart) {
    var braceCount = 0;
    var foundOpen = false;
    final start = source.indexOf('{', classStart);
    if (start == -1) return null;

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
