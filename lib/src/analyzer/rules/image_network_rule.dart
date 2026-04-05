import '../../common/common.dart';
import 'analysis_rule.dart';

/// Detects usage of Image.network() and recommends using
/// cached_network_image or similar caching strategy instead.
class ImageNetworkRule extends AnalysisRule {
  const ImageNetworkRule();

  static final _imageNetworkPattern = RegExp(
    r'Image\.network\s*\(',
  );

  @override
  List<Finding> analyze(String filePath, String source, List<String> lines) {
    final findings = <Finding>[];

    for (var i = 0; i < lines.length; i++) {
      final matches = _imageNetworkPattern.allMatches(lines[i]);
      for (final match in matches) {
        findings.add(Finding(
          ruleId: 'analyzer/prefer-cached-network-image',
          message:
              'Image.network() does not cache images on disk. Use '
              'CachedNetworkImage from cached_network_image package '
              'to reduce cellular data consumption.',
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
