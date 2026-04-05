import 'dart:convert';

import 'package:http/http.dart' as http;

import 'security_models.dart';

/// Client for querying the OSV (Open Source Vulnerability) database.
class OsvClient {
  static const String _osvApiUrl = 'https://api.osv.dev/v1/query';

  final http.Client _httpClient;

  OsvClient({http.Client? httpClient})
      : _httpClient = httpClient ?? http.Client();

  /// Queries the OSV database for vulnerabilities affecting the given package.
  Future<List<Vulnerability>> queryVulnerabilities(
    String packageName,
    String version,
  ) async {
    try {
      final response = await _httpClient.post(
        Uri.parse(_osvApiUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'package': {
            'name': packageName,
            'ecosystem': 'Pub',
          },
          'version': version,
        }),
      );

      if (response.statusCode != 200) return [];

      final json = jsonDecode(response.body);
      if (json is! Map<String, dynamic>) return [];

      final vulns = json['vulns'];
      if (vulns is! List) return [];

      return vulns.map<Vulnerability>((v) {
        final id = (v['id'] as String?) ?? 'UNKNOWN';
        final summary = (v['summary'] as String?) ?? 'No summary available';
        final details = v['details'] as String?;
        final aliases = (v['aliases'] as List?)
                ?.map((a) => a.toString())
                .toList() ??
            [];

        String? severity;
        final sevList = v['severity'] as List?;
        if (sevList != null && sevList.isNotEmpty) {
          severity = (sevList.first['score'] as String?) ??
              (sevList.first['type'] as String?);
        }

        return Vulnerability(
          id: id,
          summary: summary,
          details: details,
          aliases: aliases,
          severity: severity,
          packageName: packageName,
          packageVersion: version,
        );
      }).toList();
    } on Exception {
      return [];
    }
  }

  void close() => _httpClient.close();
}
