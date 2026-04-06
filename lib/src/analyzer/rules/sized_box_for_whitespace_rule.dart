import '../../common/common.dart';
import 'analysis_rule.dart';

/// Detects `Container` used only for adding whitespace (width/height)
/// which should use `SizedBox` instead.
///
/// `SizedBox` is a simpler, const-able widget that conveys intent better
/// when only dimensions are needed.
class SizedBoxForWhitespaceRule extends AnalysisRule {
  const SizedBoxForWhitespaceRule();

  static final _containerPattern = RegExp(
    r'(?<!\w)Container\s*\(',
  );

  @override
  List<Finding> analyze(String filePath, String source, List<String> lines) {
    final findings = <Finding>[];

    for (var i = 0; i < lines.length; i++) {
      final matches = _containerPattern.allMatches(lines[i]);

      for (final match in matches) {
        // Extract the Container's arguments
        final containerBody = _extractWidgetArgs(lines, i, match.start);
        if (containerBody == null) continue;

        // Check if Container only has width/height (and optionally child)
        final hasWidth = containerBody.contains('width:');
        final hasHeight = containerBody.contains('height:');

        if (!hasWidth && !hasHeight) continue;

        // Check for properties that justify using Container
        final hasDecoration = containerBody.contains('decoration:');
        final hasColor = containerBody.contains('color:');
        final hasTransform = containerBody.contains('transform:');
        final hasConstraints = containerBody.contains('constraints:');
        final hasPadding = containerBody.contains('padding:');
        final hasMargin = containerBody.contains('margin:');
        final hasAlignment = containerBody.contains('alignment:');
        final hasForegroundDecoration = containerBody.contains('foregroundDecoration:');
        final hasClipBehavior = containerBody.contains('clipBehavior:');

        if (!hasDecoration && !hasColor && !hasTransform && !hasConstraints &&
            !hasPadding && !hasMargin && !hasAlignment && !hasForegroundDecoration &&
            !hasClipBehavior) {
          findings.add(Finding(
            ruleId: 'analyzer/sized-box-for-whitespace',
            message:
                'Use SizedBox instead of Container when only '
                'width/height is needed. SizedBox is simpler '
                'and can be const.',
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

  String? _extractWidgetArgs(List<String> lines, int startLine, int startCol) {
    var depth = 0;
    var started = false;
    final buffer = StringBuffer();

    for (var i = startLine; i < lines.length && i < startLine + 30; i++) {
      final start = (i == startLine) ? startCol : 0;
      for (var c = start; c < lines[i].length; c++) {
        final ch = lines[i][c];
        if (ch == '(') {
          depth++;
          started = true;
        } else if (ch == ')') {
          depth--;
          if (started && depth == 0) {
            return buffer.toString();
          }
        }
        if (started && depth == 1) {
          buffer.write(ch);
        }
      }
      if (started) buffer.write('\n');
    }
    return null;
  }
}
