import 'finding.dart';

/// Sealed class representing the result of an analysis module execution.
sealed class ModuleResult {
  const ModuleResult();
}

/// A module executed successfully, possibly with findings.
final class ModuleSuccess extends ModuleResult {
  final List<Finding> findings;
  final Map<String, Object> metadata;

  const ModuleSuccess({
    required this.findings,
    this.metadata = const {},
  });
}

/// A module execution failed with an error.
final class ModuleFailure extends ModuleResult {
  final String moduleName;
  final String errorMessage;

  const ModuleFailure({
    required this.moduleName,
    required this.errorMessage,
  });
}
