import 'dart:convert';
import 'dart:io';

import '../common/common.dart';

/// Generates SARIF v2.1.0 reports from analysis findings.
///
/// SARIF (Static Analysis Results Interchange Format) is a standard
/// format for the output of static analysis tools, supported by
/// GitHub for code scanning alerts.
class SarifExporter {
  static const String _sarifVersion = '2.1.0';
  static const String _schemaUri =
      'https://docs.oasis-open.org/sarif/sarif/v2.1.0/cos02/schemas/sarif-schema-2.1.0.json';

  /// Generates a SARIF JSON document from the given findings.
  Map<String, Object> generateSarif({
    required List<Finding> findings,
    required String toolName,
    String toolVersion = '1.0.0',
    String? informationUri,
  }) {
    // Collect unique rules
    final ruleIds = findings.map((f) => f.ruleId).toSet().toList()..sort();
    final ruleIndex = <String, int>{};
    for (var i = 0; i < ruleIds.length; i++) {
      ruleIndex[ruleIds[i]] = i;
    }

    final rules = ruleIds.map((id) {
      final rule = <String, Object>{
        'id': id,
        'shortDescription': {
          'text': _ruleDescription(id),
        },
      };
      final helpUri = _ruleHelpUri(id);
      if (helpUri != null) {
        rule['helpUri'] = helpUri;
      }
      return rule;
    }).toList();

    final results = findings.map((f) {
      final result = <String, Object>{
        'ruleId': f.ruleId,
        'ruleIndex': ruleIndex[f.ruleId]!,
        'level': f.severity.sarifLevel,
        'message': {
          'text': f.message,
        },
      };

      if (f.filePath != null) {
        final location = <String, Object>{
          'physicalLocation': _buildPhysicalLocation(f),
        };
        result['locations'] = [location];
      }

      return result;
    }).toList();

    return <String, Object>{
      '\$schema': _schemaUri,
      'version': _sarifVersion,
      'runs': [
        {
          'tool': {
            'driver': {
              'name': toolName,
              'version': toolVersion,
              // ignore: use_null_aware_elements
              if (informationUri != null) 'informationUri': informationUri,
              'rules': rules,
            },
          },
          'results': results,
        },
      ],
    };
  }

  /// Writes the SARIF report to a file.
  void writeToFile(
    Map<String, Object> sarif,
    String outputPath,
  ) {
    final json = const JsonEncoder.withIndent('  ').convert(sarif);
    File(outputPath).writeAsStringSync(json);
  }

  Map<String, Object> _buildPhysicalLocation(Finding f) {
    final location = <String, Object>{
      'artifactLocation': {
        'uri': f.filePath!,
        'uriBaseId': '%SRCROOT%',
      },
    };

    if (f.line != null) {
      final region = <String, Object>{
        'startLine': f.line!,
      };
      if (f.column != null) {
        region['startColumn'] = f.column!;
      }
      if (f.endLine != null) {
        region['endLine'] = f.endLine!;
      }
      if (f.endColumn != null) {
        region['endColumn'] = f.endColumn!;
      }
      location['region'] = region;
    }

    return location;
  }

  String _ruleDescription(String ruleId) {
    return switch (ruleId) {
      'analyzer/uncancelled-subscription' =>
        'StreamSubscription or Timer not cancelled in dispose()',
      'analyzer/prefer-specific-media-query' =>
        'Prefer MediaQuery.sizeOf() over MediaQuery.of()',
      'analyzer/prefer-cached-network-image' =>
        'Prefer cached_network_image over Image.network()',
      'analyzer/prefer-const-widget' =>
        'Prefer const constructor for widgets',
      // Code quality rules
      'analyzer/avoid-print' =>
        'Avoid print() in production code',
      'analyzer/avoid-unnecessary-container' =>
        'Avoid Container without decoration properties',
      'analyzer/avoid-non-null-assertion' =>
        'Avoid non-null assertion operator (!)',
      'analyzer/avoid-empty-catch' =>
        'Avoid empty catch blocks',
      'analyzer/prefer-is-empty' =>
        'Prefer .isEmpty/.isNotEmpty over .length comparison',
      'analyzer/avoid-hardcoded-colors' =>
        'Avoid hardcoded color values in widget code',
      'analyzer/prefer-named-parameters' =>
        'Prefer named parameters for functions with many arguments',
      'analyzer/avoid-build-context-in-async' =>
        'Avoid passing BuildContext to async functions',
      'analyzer/avoid-set-state-in-async' =>
        'Avoid setState() after await without mounted check',
      'analyzer/use-key-in-widget-constructor' =>
        'Widget constructor missing Key parameter',
      // Additional Dart/Flutter best practices
      'analyzer/no-logic-in-create-state' =>
        'No logic in createState() method',
      'analyzer/prefer-const-constructors' =>
        'Prefer const constructors for compile-time optimization',
      'analyzer/prefer-const-declarations' =>
        'Prefer const over final for constant values',
      'analyzer/sort-child-properties-last' =>
        'Place child/children property last in widget constructors',
      'analyzer/prefer-final-locals' =>
        'Prefer final for local variables that are never reassigned',
      'analyzer/sized-box-for-whitespace' =>
        'Use SizedBox instead of Container for whitespace',
      'analyzer/avoid-void-async' =>
        'Avoid void async functions (use Future<void>)',
      'analyzer/close-sinks' =>
        'StreamController/Sink not closed in dispose()',
      'analyzer/unawaited-futures' =>
        'Future-returning expression not awaited',
      'analyzer/only-throw-errors' =>
        'Only throw Error or Exception objects',
      'analyzer/avoid-catching-errors' =>
        'Avoid catching Error (catch Exception instead)',
      'analyzer/use-full-hex-values' =>
        'Use full 8-character hex values for Flutter colors',
      'analyzer/hash-and-equals' =>
        'Override both operator == and hashCode',
      'analyzer/unnecessary-this' =>
        'Unnecessary this keyword',
      'analyzer/prefer-contains' =>
        'Use contains() instead of indexOf() comparison',
      // Dead code rules
      'analyzer/unused-import' =>
        'Unused import detected',
      'analyzer/commented-out-code' =>
        'Block of commented-out code detected',
      'analyzer/technical-debt-comment' =>
        'Technical debt comment (TODO/FIXME/HACK)',
      'analyzer/deprecated-member' =>
        'Deprecated member should be removed or replaced',
      'analyzer/unused-private-member' =>
        'Unused private member detected',
      // Firebase rules
      'analyzer/firestore-snapshots-not-tracked' =>
        'Firestore snapshots() listener not stored in StreamSubscription',
      'analyzer/firebase-auth-listener-not-tracked' =>
        'Firebase Auth state listener not stored in StreamSubscription',
      'analyzer/firebase-messaging-listener-not-tracked' =>
        'Firebase Messaging listener not stored in StreamSubscription',
      'analyzer/firebase-storage-no-error-handling' =>
        'Firebase Storage task missing error handling',
      'analyzer/firebase-ai-no-error-handling' =>
        'Firebase AI call missing error handling',
      // Riverpod rules
      'analyzer/riverpod-prefer-notifier' =>
        'Prefer Notifier over deprecated StateNotifier',
      'analyzer/riverpod-avoid-change-notifier' =>
        'Avoid ChangeNotifierProvider in Riverpod',
      'analyzer/riverpod-prefer-annotation' =>
        'Prefer @riverpod annotation over manual provider declarations',
      'analyzer/riverpod-watch-outside-build' =>
        'ref.watch() used outside build method',
      'analyzer/riverpod-watch-in-callback' =>
        'ref.watch() used inside callback',
      // go_router rules
      'analyzer/go-router-avoid-navigator' =>
        'Avoid Navigator when go_router is available',
      'analyzer/go-router-avoid-material-page-route' =>
        'Avoid MaterialPageRoute with go_router',
      // Equatable rules
      'analyzer/equatable-missing-props' =>
        'Equatable class missing props override',
      'analyzer/equatable-empty-props' =>
        'Equatable class with empty props list',
      'analyzer/equatable-mutable-field' =>
        'Equatable class with mutable field',
      // Widget lifecycle rules
      'analyzer/flutter-map-controller-not-disposed' =>
        'MapController not disposed',
      'analyzer/wakelock-not-disabled' =>
        'WakelockPlus.enable() without corresponding disable()',
      'analyzer/wakelock-not-disabled-in-dispose' =>
        'WakelockPlus.disable() not called in dispose()',
      'analyzer/webview-controller-lifecycle' =>
        'WebViewController lifecycle not properly managed',
      'analyzer/lottie-controller-not-disposed' =>
        'AnimationController for Lottie not disposed',
      // image_picker rules
      'analyzer/image-picker-deprecated-method' =>
        'Deprecated ImagePicker.pickImage() static method',
      'analyzer/image-picker-no-null-check' =>
        'Image picker result not checked for null',
      // Sentry rules
      'analyzer/sentry-use-capture-exception' =>
        'Use Sentry.captureException() instead of print() for errors',
      'analyzer/sentry-missing-capture-in-catch' =>
        'catch block does not report to Sentry',
      // Other rules
      'duplication/structural-duplicate' =>
        'Structurally duplicated code block',
      'coverage/below-threshold' =>
        'Test coverage below minimum threshold',
      'coverage/file-below-threshold' =>
        'File test coverage below minimum threshold',
      'coverage/missing-lcov' =>
        'LCOV coverage file not found',
      'security/osv-vulnerability' =>
        'Known vulnerability in dependency (OSV)',
      'security/discontinued-package' =>
        'Package is discontinued on pub.dev',
      'security/no-dependencies' =>
        'No dependencies found to audit',
      _ => ruleId,
    };
  }

  String? _ruleHelpUri(String ruleId) {
    return switch (ruleId) {
      'security/osv-vulnerability' => 'https://osv.dev/',
      'security/discontinued-package' => 'https://pub.dev/',
      'analyzer/avoid-print' =>
        'https://dart.dev/tools/linter-rules/avoid_print',
      'analyzer/avoid-unnecessary-container' =>
        'https://dart.dev/tools/linter-rules/avoid_unnecessary_containers',
      'analyzer/avoid-non-null-assertion' =>
        'https://dart.dev/effective-dart/usage#avoid-using-cast-and-non-null-assertion',
      'analyzer/avoid-empty-catch' =>
        'https://dart.dev/tools/linter-rules/empty_catches',
      'analyzer/prefer-is-empty' =>
        'https://dart.dev/tools/linter-rules/prefer_is_empty',
      'analyzer/use-key-in-widget-constructor' =>
        'https://dart.dev/tools/linter-rules/use_key_in_widget_constructors',
      'analyzer/avoid-build-context-in-async' ||
      'analyzer/avoid-set-state-in-async' =>
        'https://dart.dev/tools/linter-rules/use_build_context_synchronously',
      'analyzer/no-logic-in-create-state' =>
        'https://dart.dev/tools/linter-rules/no_logic_in_create_state',
      'analyzer/prefer-const-constructors' =>
        'https://dart.dev/tools/linter-rules/prefer_const_constructors',
      'analyzer/prefer-const-declarations' =>
        'https://dart.dev/tools/linter-rules/prefer_const_declarations',
      'analyzer/sort-child-properties-last' =>
        'https://dart.dev/tools/linter-rules/sort_child_properties_last',
      'analyzer/prefer-final-locals' =>
        'https://dart.dev/tools/linter-rules/prefer_final_locals',
      'analyzer/sized-box-for-whitespace' =>
        'https://dart.dev/tools/linter-rules/sized_box_for_whitespace',
      'analyzer/avoid-void-async' =>
        'https://dart.dev/tools/linter-rules/avoid_void_async',
      'analyzer/close-sinks' =>
        'https://dart.dev/tools/linter-rules/close_sinks',
      'analyzer/unawaited-futures' =>
        'https://dart.dev/tools/linter-rules/unawaited_futures',
      'analyzer/only-throw-errors' =>
        'https://dart.dev/tools/linter-rules/only_throw_errors',
      'analyzer/avoid-catching-errors' =>
        'https://dart.dev/tools/linter-rules/avoid_catching_errors',
      'analyzer/use-full-hex-values' =>
        'https://dart.dev/tools/linter-rules/use_full_hex_values_for_flutter_colors',
      'analyzer/hash-and-equals' =>
        'https://dart.dev/tools/linter-rules/hash_and_equals',
      'analyzer/unnecessary-this' =>
        'https://dart.dev/tools/linter-rules/unnecessary_this',
      'analyzer/prefer-contains' =>
        'https://dart.dev/tools/linter-rules/prefer_contains',
      'analyzer/riverpod-prefer-notifier' =>
        'https://riverpod.dev/docs/migration/from_state_notifier',
      'analyzer/riverpod-avoid-change-notifier' =>
        'https://riverpod.dev/docs/concepts/providers',
      'analyzer/riverpod-prefer-annotation' =>
        'https://riverpod.dev/docs/concepts/about_code_generation',
      'analyzer/go-router-avoid-navigator' ||
      'analyzer/go-router-avoid-material-page-route' =>
        'https://pub.dev/packages/go_router',
      'analyzer/flutter-map-controller-not-disposed' =>
        'https://pub.dev/packages/flutter_map',
      'analyzer/wakelock-not-disabled' ||
      'analyzer/wakelock-not-disabled-in-dispose' =>
        'https://pub.dev/packages/wakelock_plus',
      'analyzer/webview-controller-lifecycle' =>
        'https://pub.dev/packages/webview_flutter',
      'analyzer/image-picker-deprecated-method' ||
      'analyzer/image-picker-no-null-check' =>
        'https://pub.dev/packages/image_picker',
      'analyzer/sentry-use-capture-exception' ||
      'analyzer/sentry-missing-capture-in-catch' =>
        'https://pub.dev/packages/sentry_flutter',
      _ => null,
    };
  }
}
