import '../../common/common.dart';
import 'analysis_rule.dart';

/// Detects `child` or `children` properties that are not the last
/// named parameter in a widget constructor call.
///
/// Placing `child`/`children` last improves readability by keeping
/// the widget's configuration together before its subtree.
class SortChildPropertiesLastRule extends AnalysisRule {
  const SortChildPropertiesLastRule();

  static final _childPropertyPattern = RegExp(
    r'^\s+(child|children)\s*:',
  );

  static final _namedParamPattern = RegExp(
    r'^\s+(\w+)\s*:',
  );

  @override
  List<Finding> analyze(String filePath, String source, List<String> lines) {
    final findings = <Finding>[];

    for (var i = 0; i < lines.length; i++) {
      final childMatch = _childPropertyPattern.firstMatch(lines[i]);
      if (childMatch == null) continue;

      final childName = childMatch.group(1)!;

      // Look ahead to find if there are more named parameters after this one
      // We need to track brace/paren depth to skip nested widgets
      var depth = 0;
      var foundParamAfterChild = false;

      for (var j = i + 1; j < lines.length; j++) {
        for (var c = 0; c < lines[j].length; c++) {
          final ch = lines[j][c];
          if (ch == '(' || ch == '[' || ch == '{') depth++;
          if (ch == ')' || ch == ']' || ch == '}') depth--;
        }

        // If we've gone back to the parent widget's level
        if (depth < 0) break;

        // At the same level, check for another named parameter
        if (depth == 0) {
          final paramMatch = _namedParamPattern.firstMatch(lines[j]);
          if (paramMatch != null) {
            final paramName = paramMatch.group(1)!;
            // Skip child/children themselves
            if (paramName != 'child' && paramName != 'children' && paramName != 'key') {
              foundParamAfterChild = true;
              break;
            }
          }
        }
      }

      if (foundParamAfterChild) {
        findings.add(Finding(
          ruleId: 'analyzer/sort-child-properties-last',
          message:
              'Place "$childName:" as the last property in the widget '
              'constructor. This improves readability by separating '
              'configuration from the widget subtree.',
          severity: FindingSeverity.note,
          filePath: filePath,
          line: i + 1,
        ));
      }
    }

    return findings;
  }
}
