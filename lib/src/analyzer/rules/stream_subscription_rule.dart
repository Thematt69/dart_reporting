import '../../common/common.dart';
import 'analysis_rule.dart';

/// Detects StreamSubscription and Timer fields in StatefulWidget State classes
/// that are not properly cancelled/closed in the dispose() method.
class StreamSubscriptionRule extends AnalysisRule {
  const StreamSubscriptionRule();

  static final _stateClassPattern = RegExp(
    r'class\s+(\w+)\s+extends\s+State<\w+>',
  );

  static final _subscriptionPattern = RegExp(
    r'(StreamSubscription|Timer)\s*(<[^>]*>)?\s*\??\s+(\w+)',
  );

  static final _disposePattern = RegExp(
    r'void\s+dispose\s*\(\)',
  );

  @override
  List<Finding> analyze(String filePath, String source, List<String> lines) {
    final findings = <Finding>[];

    // Find State classes
    for (final match in _stateClassPattern.allMatches(source)) {
      final stateClassName = match.group(1)!;
      final classStart = source.substring(0, match.start).split('\n').length;

      // Find the class body boundaries
      final classBody = _extractClassBody(source, match.start);
      if (classBody == null) continue;

      // Find subscription/timer fields
      final fields = _subscriptionPattern
          .allMatches(classBody)
          .map((m) => (type: m.group(1)!, name: m.group(3)!))
          .toList();

      if (fields.isEmpty) continue;

      // Check dispose method
      final disposeMatch = _disposePattern.firstMatch(classBody);

      for (final field in fields) {
        final cancelMethod =
            field.type == 'Timer' ? 'cancel' : 'cancel';

        if (disposeMatch == null) {
          final lineNum = _findFieldLine(lines, field.name, classStart);
          findings.add(Finding(
            ruleId: 'analyzer/uncancelled-subscription',
            message:
                '${field.type} "${field.name}" in $stateClassName is never '
                'cancelled. Add ${field.name}.$cancelMethod() in dispose().',
            severity: FindingSeverity.warning,
            filePath: filePath,
            line: lineNum,
          ));
        } else {
          final disposeBody = _extractMethodBody(classBody, disposeMatch.start);
          if (disposeBody != null &&
              !disposeBody.contains('${field.name}.cancel()') &&
              !disposeBody.contains('${field.name}?.cancel()') &&
              !disposeBody.contains('${field.name}.close()') &&
              !disposeBody.contains('${field.name}?.close()')) {
            final lineNum = _findFieldLine(lines, field.name, classStart);
            findings.add(Finding(
              ruleId: 'analyzer/uncancelled-subscription',
              message:
                  '${field.type} "${field.name}" in $stateClassName is not '
                  'cancelled in dispose(). Add ${field.name}.$cancelMethod().',
              severity: FindingSeverity.warning,
              filePath: filePath,
              line: lineNum,
            ));
          }
        }
      }
    }

    return findings;
  }

  String? _extractClassBody(String source, int classStart) {
    var braceCount = 0;
    var foundOpen = false;
    final start = source.indexOf('{', classStart);
    if (start == -1) return null;

    for (var i = start; i < source.length; i++) {
      if (source[i] == '{') {
        braceCount++;
        foundOpen = true;
      } else if (source[i] == '}') {
        braceCount--;
      }
      if (foundOpen && braceCount == 0) {
        return source.substring(start, i + 1);
      }
    }
    return null;
  }

  String? _extractMethodBody(String source, int methodStart) {
    final start = source.indexOf('{', methodStart);
    if (start == -1) return null;

    var braceCount = 0;
    var foundOpen = false;

    for (var i = start; i < source.length; i++) {
      if (source[i] == '{') {
        braceCount++;
        foundOpen = true;
      } else if (source[i] == '}') {
        braceCount--;
      }
      if (foundOpen && braceCount == 0) {
        return source.substring(start, i + 1);
      }
    }
    return null;
  }

  int _findFieldLine(List<String> lines, String fieldName, int startLine) {
    for (var i = startLine - 1; i < lines.length; i++) {
      if (lines[i].contains(fieldName) &&
          (lines[i].contains('StreamSubscription') ||
              lines[i].contains('Timer'))) {
        return i + 1;
      }
    }
    return startLine;
  }
}
