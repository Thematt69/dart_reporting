import 'dart:io';

import '../common/common.dart';
import 'rules/avoid_build_context_in_async_rule.dart';
import 'rules/avoid_empty_catch_rule.dart';
import 'rules/avoid_hardcoded_colors_rule.dart';
import 'rules/avoid_non_null_assertion_rule.dart';
import 'rules/avoid_print_rule.dart';
import 'rules/avoid_set_state_in_async_rule.dart';
import 'rules/avoid_unnecessary_container_rule.dart';
import 'rules/const_widget_rule.dart';
import 'rules/dead_code_rule.dart';
import 'rules/equatable_rule.dart';
import 'rules/firebase_rule.dart';
import 'rules/go_router_rule.dart';
import 'rules/image_network_rule.dart';
import 'rules/image_picker_rule.dart';
import 'rules/media_query_rule.dart';
import 'rules/prefer_is_empty_rule.dart';
import 'rules/prefer_named_parameters_rule.dart';
import 'rules/riverpod_rule.dart';
import 'rules/sentry_rule.dart';
import 'rules/stream_subscription_rule.dart';
import 'rules/use_key_in_widget_constructor_rule.dart';
import 'rules/widget_lifecycle_rule.dart';

/// Module that performs AST-based static analysis on Dart source files.
///
/// Implements rules for:
/// - Memory leaks (uncancelled StreamSubscription/Timer in StatefulWidget)
/// - Performance (const widgets, MediaQuery.sizeOf)
/// - Data consumption (Image.network without caching)
/// - Code quality (print, empty catch, non-null assertion, etc.)
/// - Dead code detection (unused imports, commented code, deprecated APIs)
/// - Flutter best practices (BuildContext in async, setState after await)
/// - Firebase best practices (Firestore, Auth, Messaging, Storage, AI)
/// - Riverpod patterns (StateNotifier migration, ref.watch usage)
/// - go_router navigation (Navigator vs go_router usage)
/// - Equatable correctness (props, immutability)
/// - Widget lifecycle (flutter_map, wakelock_plus, webview_flutter, lottie)
/// - image_picker usage (deprecated methods, null checks)
/// - Sentry error tracking (capture exceptions, catch blocks)
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
        // Core rules
        const StreamSubscriptionRule(),
        const MediaQueryRule(),
        const ImageNetworkRule(),
        const ConstWidgetRule(),
        // Code quality rules
        const AvoidPrintRule(),
        const AvoidUnnecessaryContainerRule(),
        const AvoidNonNullAssertionRule(),
        const AvoidEmptyCatchRule(),
        const PreferIsEmptyRule(),
        const AvoidHardcodedColorsRule(),
        const PreferNamedParametersRule(),
        const AvoidBuildContextInAsyncRule(),
        const AvoidSetStateInAsyncRule(),
        const UseKeyInWidgetConstructorRule(),
        // Dead code detection
        const DeadCodeRule(),
        // Dependency-specific rules
        const FirebaseRule(),
        const RiverpodRule(),
        const GoRouterRule(),
        const EquatableRule(),
        const WidgetLifecycleRule(),
        const ImagePickerRule(),
        const SentryRule(),
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
