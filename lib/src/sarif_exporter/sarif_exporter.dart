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
      _ => null,
    };
  }
}
