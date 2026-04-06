/// Represents a single finding/issue discovered by an analysis module.
final class Finding {
  final String ruleId;
  final String message;
  final FindingSeverity severity;
  final String? filePath;
  final int? line;
  final int? column;
  final int? endLine;
  final int? endColumn;
  final String? helpUri;

  const Finding({
    required this.ruleId,
    required this.message,
    required this.severity,
    this.filePath,
    this.line,
    this.column,
    this.endLine,
    this.endColumn,
    this.helpUri,
  });
}

/// Severity levels for analysis findings.
enum FindingSeverity {
  error,
  warning,
  note;

  String get sarifLevel => switch (this) {
        FindingSeverity.error => 'error',
        FindingSeverity.warning => 'warning',
        FindingSeverity.note => 'note',
      };
}
