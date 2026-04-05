import 'dart:io';

import '../common/common.dart';
import 'rules/const_widget_rule.dart';
import 'rules/image_network_rule.dart';
import 'rules/media_query_rule.dart';
import 'rules/stream_subscription_rule.dart';

/// Module that performs AST-based static analysis on Dart source files.
///
/// Implements rules for:
/// - Memory leaks (uncancelled StreamSubscription/Timer in StatefulWidget)
/// - Performance (const widgets, MediaQuery.sizeOf)
/// - Data consumption (Image.network without caching)
class AnalyzerModule {
  final String projectPath;
  final List<String> excludePatterns;

  const AnalyzerModule({
    required this.projectPath,
    this.excludePatterns = const [
      '.g.dart',
      '.freezed.dart',
      '.gr.dart',
      '.gen.dart',
      '.mocks.dart',
    ],
  });

  ModuleResult run() {
    try {
      final libDir = Directory('$projectPath/lib');
      if (!libDir.existsSync()) {
        return const ModuleSuccess(findings: []);
      }

      final dartFiles = libDir
          .listSync(recursive: true)
          .whereType<File>()
          .where((f) => f.path.endsWith('.dart'))
          .where((f) => !_isExcluded(f.path));

      final findings = <Finding>[];
      final rules = [
        const StreamSubscriptionRule(),
        const MediaQueryRule(),
        const ImageNetworkRule(),
        const ConstWidgetRule(),
      ];

      for (final file in dartFiles) {
        final source = file.readAsStringSync();
        final lines = source.split('\n');

        for (final rule in rules) {
          findings.addAll(rule.analyze(file.path, source, lines));
        }
      }

      return ModuleSuccess(
        findings: findings,
        metadata: {
          'rules_applied': rules.length,
          'findings_count': findings.length,
        },
      );
    } on Exception catch (e) {
      return ModuleFailure(
        moduleName: 'AnalyzerModule',
        errorMessage: 'Failed to run AST analysis: $e',
      );
    }
  }

  bool _isExcluded(String filePath) {
    return excludePatterns.any((p) => filePath.endsWith(p));
  }
}
