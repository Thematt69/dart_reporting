/// Represents a dependency extracted from pubspec.lock.
final class LockDependency {
  final String name;
  final String version;
  final String source;
  final bool isDirect;

  const LockDependency({
    required this.name,
    required this.version,
    required this.source,
    required this.isDirect,
  });
}

/// Represents a known vulnerability from OSV.
final class Vulnerability {
  final String id;
  final String summary;
  final String? details;
  final List<String> aliases;
  final String? severity;
  final String packageName;
  final String packageVersion;
  final String? databaseSpecific;

  const Vulnerability({
    required this.id,
    required this.summary,
    this.details,
    this.aliases = const [],
    this.severity,
    required this.packageName,
    required this.packageVersion,
    this.databaseSpecific,
  });
}

/// Represents the status of a package on pub.dev.
final class PubDevStatus {
  final String packageName;
  final bool isDiscontinued;
  final String? latestVersion;
  final String currentVersion;

  const PubDevStatus({
    required this.packageName,
    required this.isDiscontinued,
    this.latestVersion,
    required this.currentVersion,
  });
}
