import '../../common/common.dart';
import 'analysis_rule.dart';

/// Detects hardcoded color values in widget build methods.
///
/// Hardcoded colors (e.g. `Color(0xFF...)`, `Colors.red`) in build methods
/// make theming difficult. Extract colors to a theme or a constants file.
class AvoidHardcodedColorsRule extends AnalysisRule {
  const AvoidHardcodedColorsRule();

  // Color(0x...) pattern
  static final _colorConstructorPattern = RegExp(
    r'(?<!\w)Color\s*\(\s*0x[0-9a-fA-F]+\s*\)',
  );

  // Color.fromARGB / Color.fromRGBO
  static final _colorFromPattern = RegExp(
    r'(?<!\w)Color\.from(ARGB|RGBO)\s*\(',
  );

  // Colors.xxx direct usage
  static final _colorsPattern = RegExp(
    r'(?<!\w)Colors\.\w+',
  );

  @override
  List<Finding> analyze(String filePath, String source, List<String> lines) {
    final findings = <Finding>[];

    // Only check files that appear to contain build methods (widget files)
    if (!source.contains('build(') && !source.contains('Widget')) {
      return findings;
    }

    // Skip theme/color constant files
    final lowerPath = filePath.toLowerCase();
    if (lowerPath.contains('theme') ||
        lowerPath.contains('color') ||
        lowerPath.contains('style') ||
        lowerPath.contains('constant')) {
      return findings;
    }

    for (var i = 0; i < lines.length; i++) {
      final line = lines[i];
      final trimmed = line.trimLeft();

      // Skip comments and imports
      if (trimmed.startsWith('//') ||
          trimmed.startsWith('*') ||
          trimmed.startsWith('///') ||
          trimmed.startsWith('import ')) {
        continue;
      }

      // Check Color(0x...) constructors
      for (final match in _colorConstructorPattern.allMatches(line)) {
        findings.add(Finding(
          ruleId: 'analyzer/avoid-hardcoded-colors',
          message:
              'Avoid hardcoded Color values. Extract colors to a '
              'theme (ThemeData) or constants file for consistent '
              'theming and easier maintenance.',
          severity: FindingSeverity.note,
          filePath: filePath,
          line: i + 1,
          column: match.start + 1,
        ));
      }

      // Check Color.fromARGB/fromRGBO
      for (final match in _colorFromPattern.allMatches(line)) {
        findings.add(Finding(
          ruleId: 'analyzer/avoid-hardcoded-colors',
          message:
              'Avoid hardcoded Color.from*() values. Extract colors '
              'to a theme (ThemeData) or constants file for consistent '
              'theming and easier maintenance.',
          severity: FindingSeverity.note,
          filePath: filePath,
          line: i + 1,
          column: match.start + 1,
        ));
      }

      // Check Colors.xxx usage inside build-like contexts
      for (final match in _colorsPattern.allMatches(line)) {
        final colorName = match.group(0)!;
        // Skip common universal colors
        if (colorName == 'Colors.transparent' ||
            colorName == 'Colors.white' ||
            colorName == 'Colors.black') {
          continue;
        }
        findings.add(Finding(
          ruleId: 'analyzer/avoid-hardcoded-colors',
          message:
              'Avoid using Colors.* directly in widget code. '
              'Use Theme.of(context).colorScheme or extract '
              'colors to a constants file instead.',
          severity: FindingSeverity.note,
          filePath: filePath,
          line: i + 1,
          column: match.start + 1,
        ));
      }
    }

    return findings;
  }
}
