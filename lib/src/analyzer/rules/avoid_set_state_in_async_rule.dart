import '../../common/common.dart';
import 'analysis_rule.dart';

/// Detects usage of `setState()` called after an asynchronous gap
/// which can cause "setState() called after dispose()" errors.
class AvoidSetStateInAsyncRule extends AnalysisRule {
  const AvoidSetStateInAsyncRule();

  // setState after await
  static final _setStatePattern = RegExp(
    r'(?<!\w)setState\s*\(',
  );

  static final _awaitPattern = RegExp(
    r'\bawait\b',
  );

  static final _mountedCheckPattern = RegExp(
    r'\bmounted\b',
  );

  @override
  List<Finding> analyze(String filePath, String source, List<String> lines) {
    final findings = <Finding>[];

    // Only relevant for StatefulWidget State classes
    if (!source.contains('extends State<')) return findings;

    for (var i = 0; i < lines.length; i++) {
      if (!_setStatePattern.hasMatch(lines[i])) continue;

      // Look backwards for an await without a mounted check between
      var foundAwait = false;
      var foundMountedCheck = false;

      for (var j = i - 1; j >= (i - 15).clamp(0, i); j--) {
        if (_awaitPattern.hasMatch(lines[j])) {
          foundAwait = true;
        }
        if (_mountedCheckPattern.hasMatch(lines[j])) {
          foundMountedCheck = true;
          break;
        }
        // Stop at method boundaries
        if (lines[j].trimLeft().startsWith('void ') ||
            lines[j].trimLeft().startsWith('Future ') ||
            lines[j].contains('=>') && lines[j].contains('async')) {
          break;
        }
      }

      if (foundAwait && !foundMountedCheck) {
        findings.add(Finding(
          ruleId: 'analyzer/avoid-set-state-in-async',
          message:
              'setState() is called after an await without checking '
              '"mounted". This can cause "setState() called after '
              'dispose()" errors. Add "if (!mounted) return;" before '
              'setState().',
          severity: FindingSeverity.warning,
          filePath: filePath,
          line: i + 1,
        ));
      }
    }

    return findings;
  }
}
