import '../../common/common.dart';
import 'analysis_rule.dart';

/// Detects usage of MediaQuery.of(context) and recommends
/// MediaQuery.sizeOf(context) or MediaQuery.paddingOf(context) instead
/// to avoid unnecessary widget rebuilds.
class MediaQueryRule extends AnalysisRule {
  const MediaQueryRule();

  static final _mediaQueryOfPattern = RegExp(
    r'MediaQuery\.of\((\w+)\)',
  );

  @override
  List<Finding> analyze(String filePath, String source, List<String> lines) {
    final findings = <Finding>[];

    for (var i = 0; i < lines.length; i++) {
      final matches = _mediaQueryOfPattern.allMatches(lines[i]);
      for (final match in matches) {
        // Check if it's followed by .size to suggest sizeOf
        final afterMatch = lines[i].substring(match.end);
        final suggestion = afterMatch.trimLeft().startsWith('.size')
            ? 'MediaQuery.sizeOf(${match.group(1)})'
            : 'a specific accessor like MediaQuery.sizeOf() or MediaQuery.paddingOf()';

        findings.add(Finding(
          ruleId: 'analyzer/prefer-specific-media-query',
          message:
              'Avoid MediaQuery.of(context) which causes rebuilds on any '
              'MediaQueryData change. Use $suggestion instead.',
          severity: FindingSeverity.warning,
          filePath: filePath,
          line: i + 1,
          column: match.start + 1,
        ));
      }
    }

    return findings;
  }
}
