import '../../common/common.dart';
import 'analysis_rule.dart';

/// Detects widget constructors that could use the `const` keyword.
///
/// When a widget constructor's arguments are all compile-time constants,
/// use `const` to enable Flutter's widget caching and avoid unnecessary
/// rebuilds.
class PreferConstConstructorsRule extends AnalysisRule {
  const PreferConstConstructorsRule();

  // Common widgets that typically have const constructors
  static const _constCapableWidgets = [
    'Text',
    'Icon',
    'SizedBox',
    'Spacer',
    'Divider',
    'Padding',
    'EdgeInsets',
    'Center',
    'Align',
    'Positioned',
    'Expanded',
    'Flexible',
    'CircularProgressIndicator',
    'LinearProgressIndicator',
  ];

  @override
  List<Finding> analyze(String filePath, String source, List<String> lines) {
    final findings = <Finding>[];

    for (var i = 0; i < lines.length; i++) {
      final line = lines[i];
      final trimmed = line.trimLeft();

      // Skip comments
      if (trimmed.startsWith('//') || trimmed.startsWith('*') || trimmed.startsWith('///')) {
        continue;
      }

      for (final widget in _constCapableWidgets) {
        // Match Widget( with literal-only arguments
        final pattern = RegExp('(?<!const\\s)(?<!\\w)$widget\\s*\\(');
        final matches = pattern.allMatches(line);

        for (final match in matches) {
          // Check if already preceded by const
          final before = line.substring(0, match.start).trimRight();
          if (before.endsWith('const')) continue;

          // Simple heuristic: check if arguments look like constants
          // (string literals, numbers, booleans, named const parameters)
          final afterMatch = source.substring(
            _offsetOf(lines, i, match.start),
          );

          if (_looksLikeConstArgs(afterMatch, widget)) {
            findings.add(Finding(
              ruleId: 'analyzer/prefer-const-constructors',
              message:
                  'Prefer "const $widget(...)" to enable compile-time '
                  'constant optimization and reduce widget rebuilds.',
              severity: FindingSeverity.note,
              filePath: filePath,
              line: i + 1,
              column: match.start + 1,
            ));
          }
        }
      }
    }

    return findings;
  }

  int _offsetOf(List<String> lines, int lineIndex, int column) {
    var offset = 0;
    for (var i = 0; i < lineIndex; i++) {
      offset += lines[i].length + 1; // +1 for newline
    }
    return offset + column;
  }

  bool _looksLikeConstArgs(String source, String widget) {
    // Find the matching closing parenthesis
    var depth = 0;
    var started = false;
    final buffer = StringBuffer();

    for (var i = 0; i < source.length && i < 500; i++) {
      if (source[i] == '(') {
        if (started) {
          depth++;
        } else {
          started = true;
        }
      } else if (source[i] == ')') {
        if (depth == 0 && started) {
          break;
        }
        depth--;
      } else if (started && depth == 0) {
        buffer.write(source[i]);
      }
    }

    final args = buffer.toString().trim();

    // Empty args — definitely const-able
    if (args.isEmpty) return true;

    // If args contain only simple literals and named parameters with literals
    // This is a conservative heuristic
    final hasVariableRef = RegExp(r'[a-z_]\w*(?!\s*:)(?!\()').hasMatch(args);
    final hasMethodCall = args.contains('(') && !args.contains('const ');
    final hasFunctionRef = RegExp(r'(?<!\w)(?:widget|context|this|ref)\b').hasMatch(args);

    return !hasVariableRef && !hasMethodCall && !hasFunctionRef;
  }
}
