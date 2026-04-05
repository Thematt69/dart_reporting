import '../../common/common.dart';
import 'analysis_rule.dart';

/// Detects usage of the non-null assertion operator (`!`) which can cause
/// runtime exceptions. Recommends null-aware alternatives instead.
class AvoidNonNullAssertionRule extends AnalysisRule {
  const AvoidNonNullAssertionRule();

  // Match ! used as non-null assertion (after an identifier or closing paren/bracket)
  static final _nonNullAssertionPattern = RegExp(
    r'(\w|\)|\])\!\s*[\.;\),\]\s]',
  );

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

      // Skip lines that are string literals or imports
      if (trimmed.startsWith("'") || trimmed.startsWith('"') || trimmed.startsWith('import ')) {
        continue;
      }

      final matches = _nonNullAssertionPattern.allMatches(line);
      for (final match in matches) {
        // Find the position of ! in the match
        final bangPos = line.indexOf('!', match.start);
        if (bangPos == -1) continue;

        // Make sure it's not != operator
        if (bangPos + 1 < line.length && line[bangPos + 1] == '=') continue;

        // Make sure it's not inside a string
        if (_isInsideString(line, bangPos)) continue;

        findings.add(Finding(
          ruleId: 'analyzer/avoid-non-null-assertion',
          message:
              'Avoid using the non-null assertion operator (!). '
              'It can throw a runtime exception if the value is null. '
              'Use null-aware operators (?., ??, ??=) or null checks instead.',
          severity: FindingSeverity.warning,
          filePath: filePath,
          line: i + 1,
          column: bangPos + 1,
        ));
      }
    }

    return findings;
  }

  bool _isInsideString(String line, int pos) {
    var singleQuoteCount = 0;
    var doubleQuoteCount = 0;
    for (var i = 0; i < pos; i++) {
      if (line[i] == "'" && (i == 0 || line[i - 1] != r'\')) {
        singleQuoteCount++;
      } else if (line[i] == '"' && (i == 0 || line[i - 1] != r'\')) {
        doubleQuoteCount++;
      }
    }
    return singleQuoteCount.isOdd || doubleQuoteCount.isOdd;
  }
}
