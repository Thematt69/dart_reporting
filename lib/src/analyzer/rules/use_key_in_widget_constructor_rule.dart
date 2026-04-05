import '../../common/common.dart';
import 'analysis_rule.dart';

/// Detects missing `Key` parameter in widget constructors.
///
/// All widgets should accept a `Key?` parameter in their constructor
/// for proper widget identity and testing support.
class UseKeyInWidgetConstructorRule extends AnalysisRule {
  const UseKeyInWidgetConstructorRule();

  // Match class declarations extending Widget types
  static final _widgetClassPattern = RegExp(
    r'class\s+(\w+)\s+extends\s+(StatelessWidget|StatefulWidget|HookWidget|HookConsumerWidget|ConsumerWidget|ConsumerStatefulWidget)',
  );

  @override
  List<Finding> analyze(String filePath, String source, List<String> lines) {
    final findings = <Finding>[];

    for (final classMatch in _widgetClassPattern.allMatches(source)) {
      final className = classMatch.group(1)!;
      final lineNum = source.substring(0, classMatch.start).split('\n').length;

      // Extract class body
      final classBody = _extractClassBody(source, classMatch.start);
      if (classBody == null) continue;

      // Look for constructor
      final constructorPattern = RegExp(
        'const\\s+$className\\s*\\(|$className\\s*\\(',
      );
      final constructorMatch = constructorPattern.firstMatch(classBody);

      if (constructorMatch != null) {
        // Check if Key is in the constructor parameters
        final constructorParams = _extractParenBody(
            classBody, constructorMatch.start);
        if (constructorParams != null &&
            !constructorParams.contains('Key') &&
            !constructorParams.contains('key')) {
          final constructorLine = classBody
              .substring(0, constructorMatch.start)
              .split('\n')
              .length;
          findings.add(Finding(
            ruleId: 'analyzer/use-key-in-widget-constructor',
            message:
                'Widget "$className" constructor is missing a Key '
                'parameter. Add "super.key" or "{Key? key}" for '
                'proper widget identity management.',
            severity: FindingSeverity.note,
            filePath: filePath,
            line: lineNum + constructorLine - 1,
          ));
        }
      }
    }

    return findings;
  }

  String? _extractClassBody(String source, int classStart) {
    final start = source.indexOf('{', classStart);
    if (start == -1) return null;

    var braceCount = 0;
    for (var i = start; i < source.length; i++) {
      if (source[i] == '{') braceCount++;
      if (source[i] == '}') braceCount--;
      if (braceCount == 0) {
        return source.substring(start, i + 1);
      }
    }
    return null;
  }

  String? _extractParenBody(String source, int start) {
    final parenStart = source.indexOf('(', start);
    if (parenStart == -1) return null;

    var parenCount = 0;
    for (var i = parenStart; i < source.length; i++) {
      if (source[i] == '(') parenCount++;
      if (source[i] == ')') parenCount--;
      if (parenCount == 0) {
        return source.substring(parenStart, i + 1);
      }
    }
    return null;
  }
}
