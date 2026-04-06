import 'dart:io';

import 'package:yaml/yaml.dart';

import 'security_models.dart';

/// Parses a pubspec.lock file to extract dependency information.
class PubspecLockParser {
  /// Parses the given pubspec.lock file content and returns a list of dependencies.
  List<LockDependency> parse(String lockContent) {
    final yaml = loadYaml(lockContent);
    if (yaml is! YamlMap) return [];

    final packages = yaml['packages'];
    if (packages is! YamlMap) return [];

    final dependencies = <LockDependency>[];

    for (final entry in packages.entries) {
      final name = entry.key as String;
      final info = entry.value;
      if (info is! YamlMap) continue;

      final version = (info['version'] as String?) ?? 'unknown';
      final source = (info['source'] as String?) ?? 'unknown';
      final depType = (info['dependency'] as String?) ?? '';
      final isDirect = depType.contains('direct');

      dependencies.add(LockDependency(
        name: name,
        version: version,
        source: source,
        isDirect: isDirect,
      ));
    }

    return dependencies;
  }

  /// Parses pubspec.lock from a file path.
  List<LockDependency> parseFile(String filePath) {
    final file = File(filePath);
    if (!file.existsSync()) return [];
    return parse(file.readAsStringSync());
  }
}
