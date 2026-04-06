import '../../common/common.dart';
import 'analysis_rule.dart';

/// Detects `Container` widgets used without any decoration, transformation,
/// or constraint properties that could be replaced by simpler widgets.
///
/// An empty `Container()` or one with only `child:` should be removed or
/// replaced with `SizedBox`, `Padding`, etc.
class AvoidUnnecessaryContainerRule extends AnalysisRule {
  const AvoidUnnecessaryContainerRule();

  // Match Container( with only child: or no arguments
  static final _containerPattern = RegExp(
    r'(?<!\w)Container\s*\(',
  );

  // Properties that justify using Container
  static const _justifyingProperties = [
    'decoration:',
    'color:',
    'transform:',
    'constraints:',
    'foregroundDecoration:',
    'clipBehavior:',
  ];

  @override
  List<Finding> analyze(String filePath, String source, List<String> lines) {
    final findings = <Finding>[];

    for (var i = 0; i < lines.length; i++) {
      final line = lines[i].trimLeft();

      // Skip comments
      if (line.startsWith('//') || line.startsWith('*') || line.startsWith('///')) {
        continue;
      }

      final matches = _containerPattern.allMatches(lines[i]);
      for (final match in matches) {
        // Extract the Container arguments by looking ahead
        final containerBody = _extractWidgetBody(source, match.start + _offsetUpToLine(lines, i));
        if (containerBody == null) continue;

        // Check if any justifying property is present
        final hasJustifyingProperty = _justifyingProperties.any(
          (p) => containerBody.contains(p),
        );

        if (!hasJustifyingProperty) {
          // Check what properties are present
          final hasPadding = containerBody.contains('padding:');
          final hasMargin = containerBody.contains('margin:');
          final hasWidth = containerBody.contains('width:');
          final hasHeight = containerBody.contains('height:');
          final hasAlignment = containerBody.contains('alignment:');

          String suggestion;
          if (containerBody.trim() == '()' ||
              !containerBody.contains(':')) {
            suggestion = 'Remove the empty Container or use const SizedBox.shrink()';
          } else if (hasPadding && !hasMargin && !hasWidth && !hasHeight && !hasAlignment) {
            suggestion = 'Replace Container with Padding widget';
          } else if ((hasWidth || hasHeight) && !hasPadding && !hasMargin && !hasAlignment) {
            suggestion = 'Replace Container with SizedBox widget';
          } else if (hasAlignment && !hasPadding && !hasMargin && !hasWidth && !hasHeight) {
            suggestion = 'Replace Container with Align widget';
          } else {
            suggestion = 'Consider using a more specific widget (SizedBox, Padding, Align, etc.)';
          }

          findings.add(Finding(
            ruleId: 'analyzer/avoid-unnecessary-container',
            message:
                'Container without decoration, color, or transform '
                'properties adds unnecessary complexity. $suggestion.',
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

  int _offsetUpToLine(List<String> lines, int lineIndex) {
    var offset = 0;
    for (var i = 0; i < lineIndex; i++) {
      offset += lines[i].length + 1; // +1 for newline
    }
    return offset;
  }

  String? _extractWidgetBody(String source, int widgetStart) {
    final parenStart = source.indexOf('(', widgetStart);
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
