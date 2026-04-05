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
