import '../../common/common.dart';
import 'analysis_rule.dart';

/// Detects Flutter color values that don't use the full 8-character hex format.
///
/// Use `Color(0xFFRRGGBB)` instead of `Color(0xRRGGBB)` to ensure the
/// alpha channel is explicitly specified.
class UseFullHexValuesRule extends AnalysisRule {
  const UseFullHexValuesRule();

  // Match Color(0x...) where the hex value is not 8 characters
  static final _shortHexPattern = RegExp(
    r'Color\(\s*0x([0-9a-fA-F]+)\s*\)',
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

      final matches = _shortHexPattern.allMatches(lines[i]);
      for (final match in matches) {
        final hexValue = match.group(1)!;
        if (hexValue.length != 8) {
          findings.add(Finding(
            ruleId: 'analyzer/use-full-hex-values',
            message:
                'Use full 8-character hex values for Flutter colors. '
                'Replace "0x$hexValue" with a full 8-character hex value '
                '(e.g., 0xFFRRGGBB) to explicitly specify the alpha channel.',
            severity: FindingSeverity.warning,
            filePath: filePath,
            line: i + 1,
            column: match.start + 1,
          ));
        }
      }
    }

    return findings;
  }
}
