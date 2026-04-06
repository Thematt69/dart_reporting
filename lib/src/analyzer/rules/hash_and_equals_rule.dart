import '../../common/common.dart';
import 'analysis_rule.dart';

/// Detects classes that override `operator ==` without overriding `hashCode`,
/// or vice versa.
///
/// If two objects are equal (==), they must have the same hashCode.
/// Overriding only one breaks the contract and causes bugs with
/// hash-based collections (HashMap, HashSet).
class HashAndEqualsRule extends AnalysisRule {
  const HashAndEqualsRule();

  static final _classPattern = RegExp(
    r'class\s+(\w+)',
  );

  static final _operatorEqualsPattern = RegExp(
    r'bool\s+operator\s*==\s*\(',
  );

  static final _hashCodePattern = RegExp(
    r'int\s+get\s+hashCode\b',
  );

  @override
  List<Finding> analyze(String filePath, String source, List<String> lines) {
    final findings = <Finding>[];

    for (final classMatch in _classPattern.allMatches(source)) {
      final className = classMatch.group(1)!;

      // Skip classes that extend Equatable (they handle this automatically)
      final classDecl = source.substring(classMatch.start);
      if (classDecl.contains('extends Equatable') ||
          classDecl.contains('with EquatableMixin')) {
        continue;
      }

      final classBody = _extractClassBody(source, classMatch.start);
      if (classBody == null) continue;

      final hasOperatorEquals = _operatorEqualsPattern.hasMatch(classBody);
      final hasHashCode = _hashCodePattern.hasMatch(classBody);

      if (hasOperatorEquals && !hasHashCode) {
        final lineNum = source.substring(0, classMatch.start).split('\n').length;
        findings.add(Finding(
          ruleId: 'analyzer/hash-and-equals',
          message:
              'Class "$className" overrides operator == but not hashCode. '
              'Override both to maintain the hashCode contract: '
              'equal objects must have equal hashCodes.',
          severity: FindingSeverity.warning,
          filePath: filePath,
          line: lineNum,
        ));
      } else if (!hasOperatorEquals && hasHashCode) {
        final lineNum = source.substring(0, classMatch.start).split('\n').length;
        findings.add(Finding(
          ruleId: 'analyzer/hash-and-equals',
          message:
              'Class "$className" overrides hashCode but not operator ==. '
              'Override both to maintain the hashCode contract.',
          severity: FindingSeverity.warning,
          filePath: filePath,
          line: lineNum,
        ));
      }
    }

    return findings;
  }

  String? _extractClassBody(String source, int start) {
    final bodyStart = source.indexOf('{', start);
    if (bodyStart == -1) return null;

    var braceCount = 0;
    for (var i = bodyStart; i < source.length; i++) {
      if (source[i] == '{') braceCount++;
      if (source[i] == '}') braceCount--;
      if (braceCount == 0) {
        return source.substring(bodyStart, i + 1);
      }
    }
    return null;
  }
}
