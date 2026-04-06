import '../../common/common.dart';
import 'analysis_rule.dart';

/// Detects functions/methods with too many positional parameters.
///
/// Functions with many positional parameters are hard to read and maintain.
/// Use named parameters for better readability and self-documenting code.
class PreferNamedParametersRule extends AnalysisRule {
  const PreferNamedParametersRule();

  /// Threshold for number of positional parameters before suggesting named.
  static const _maxPositionalParams = 3;

  // Match function/method declarations
  static final _functionPattern = RegExp(
    r'(?:void|int|double|bool|String|List|Map|Set|Future|Stream|dynamic|\w+)\s+(\w+)\s*\(([^)]*)\)',
  );

  @override
  List<Finding> analyze(String filePath, String source, List<String> lines) {
    final findings = <Finding>[];

    for (var i = 0; i < lines.length; i++) {
      final line = lines[i].trimLeft();

      // Skip comments
      if (line.startsWith('//') || line.startsWith('*') || line.startsWith('///')) {
        continue;
      }

      // Skip overrides (they must match the signature)
      if (i > 0 && lines[i - 1].trim() == '@override') {
        continue;
      }

      final matches = _functionPattern.allMatches(lines[i]);
      for (final match in matches) {
        final funcName = match.group(1)!;
        final params = match.group(2)!;

        // Skip constructors and common framework methods
        if (funcName == 'build' || funcName == 'dispose' ||
            funcName == 'initState' || funcName == 'main') {
          continue;
        }

        // Count positional parameters (not named, not optional)
        final positionalCount = _countPositionalParams(params);

        if (positionalCount > _maxPositionalParams) {
          findings.add(Finding(
            ruleId: 'analyzer/prefer-named-parameters',
            message:
                'Function "$funcName" has $positionalCount positional '
                'parameters (threshold: $_maxPositionalParams). '
                'Consider using named parameters for better readability.',
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

  int _countPositionalParams(String params) {
    if (params.trim().isEmpty) return 0;

    // Remove named parameter blocks { }
    var remaining = params.replaceAll(RegExp(r'\{[^}]*\}'), '');
    // Remove optional parameter blocks [ ]
    remaining = remaining.replaceAll(RegExp(r'\[[^\]]*\]'), '');

    if (remaining.trim().isEmpty) return 0;

    // Count commas + 1 for the number of parameters
    return remaining.split(',').where((p) => p.trim().isNotEmpty).length;
  }
}
