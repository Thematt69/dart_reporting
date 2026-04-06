import 'dart:convert';

import 'package:http/http.dart' as http;

import 'security_models.dart';

/// Client for querying the pub.dev API to check package status.
class PubDevClient {
  static const String _pubDevApiUrl = 'https://pub.dev/api/packages';

  final http.Client _httpClient;

  PubDevClient({http.Client? httpClient})
      : _httpClient = httpClient ?? http.Client();

  /// Checks the status of a package on pub.dev.
  Future<PubDevStatus> checkPackageStatus(
    String packageName,
    String currentVersion,
  ) async {
    try {
      final response = await _httpClient.get(
        Uri.parse('$_pubDevApiUrl/$packageName'),
      );

      if (response.statusCode != 200) {
        return PubDevStatus(
          packageName: packageName,
          isDiscontinued: false,
          currentVersion: currentVersion,
        );
      }

      final json = jsonDecode(response.body);
      if (json is! Map<String, dynamic>) {
        return PubDevStatus(
          packageName: packageName,
          isDiscontinued: false,
          currentVersion: currentVersion,
        );
      }

      final isDiscontinued = json['isDiscontinued'] as bool? ?? false;
      final latest = json['latest'] as Map<String, dynamic>?;
      final latestVersion = latest?['version'] as String?;

      return PubDevStatus(
        packageName: packageName,
        isDiscontinued: isDiscontinued,
        latestVersion: latestVersion,
        currentVersion: currentVersion,
      );
    } on Exception {
      return PubDevStatus(
        packageName: packageName,
        isDiscontinued: false,
        currentVersion: currentVersion,
      );
    }
  }

  void close() => _httpClient.close();
}
