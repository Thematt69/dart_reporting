import '../../common/common.dart';
import 'analysis_rule.dart';

/// Detects `StreamController` or `Sink` fields that are not closed
/// in the `dispose()` or `close()` method.
///
/// Unclosed sinks can cause memory leaks and prevent garbage collection.
class CloseSinksRule extends AnalysisRule {
  const CloseSinksRule();

  static final _stateClassPattern = RegExp(
    r'class\s+(\w+)\s+extends\s+State<\w+>',
  );

  static final _sinkFieldPattern = RegExp(
    r'(?:final\s+)?(?:StreamController|StreamSink|Sink)\s*(?:<[^>]*>)?\s*\??\s+(\w+)',
  );

  static final _disposePattern = RegExp(
    r'void\s+dispose\s*\(\)',
  );

  @override
  List<Finding> analyze(String filePath, String source, List<String> lines) {
    final findings = <Finding>[];

    for (final classMatch in _stateClassPattern.allMatches(source)) {
      final className = classMatch.group(1)!;
      final classBody = _extractClassBody(source, classMatch.start);
      if (classBody == null) continue;

      // Find sink fields
      final fields = _sinkFieldPattern
          .allMatches(classBody)
          .map((m) => m.group(1)!)
          .toList();

      if (fields.isEmpty) continue;

      // Check dispose method
      final disposeMatch = _disposePattern.firstMatch(classBody);

      for (final field in fields) {
        if (disposeMatch == null) {
          final lineNum = _findFieldLine(source, lines, field, classMatch.start);
          findings.add(Finding(
            ruleId: 'analyzer/close-sinks',
            message:
                'StreamController/Sink "$field" in $className is never '
                'closed. Add $field.close() in dispose() to prevent '
                'memory leaks.',
            severity: FindingSeverity.warning,
            filePath: filePath,
            line: lineNum,
          ));
        } else {
          final disposeBody = _extractMethodBody(classBody, disposeMatch.start);
          if (disposeBody != null &&
              !disposeBody.contains('$field.close()') &&
              !disposeBody.contains('$field?.close()')) {
            final lineNum = _findFieldLine(source, lines, field, classMatch.start);
            findings.add(Finding(
              ruleId: 'analyzer/close-sinks',
              message:
                  'StreamController/Sink "$field" in $className is not '
                  'closed in dispose(). Add $field.close() to prevent '
                  'memory leaks.',
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

  String? _extractClassBody(String source, int start) {
    var braceCount = 0;
    var foundOpen = false;
    final bodyStart = source.indexOf('{', start);
    if (bodyStart == -1) return null;

    for (var i = bodyStart; i < source.length; i++) {
      if (source[i] == '{') {
        braceCount++;
        foundOpen = true;
      } else if (source[i] == '}') {
        braceCount--;
      }
      if (foundOpen && braceCount == 0) {
        return source.substring(bodyStart, i + 1);
      }
    }
    return null;
  }

  String? _extractMethodBody(String source, int start) {
    final bodyStart = source.indexOf('{', start);
    if (bodyStart == -1) return null;

    var braceCount = 0;
    var foundOpen = false;

    for (var i = bodyStart; i < source.length; i++) {
      if (source[i] == '{') {
        braceCount++;
        foundOpen = true;
      } else if (source[i] == '}') {
        braceCount--;
      }
      if (foundOpen && braceCount == 0) {
        return source.substring(bodyStart, i + 1);
      }
    }
    return null;
  }

  int _findFieldLine(String source, List<String> lines, String fieldName, int classStart) {
    final startLine = source.substring(0, classStart).split('\n').length - 1;
    for (var i = startLine; i < lines.length; i++) {
      if (lines[i].contains(fieldName) &&
          (lines[i].contains('StreamController') ||
              lines[i].contains('StreamSink') ||
              lines[i].contains('Sink'))) {
        return i + 1;
      }
    }
    return startLine + 1;
  }
}
