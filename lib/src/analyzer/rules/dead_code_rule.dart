import '../../common/common.dart';
import 'analysis_rule.dart';

/// Detects dead, unused, or obsolete code patterns:
///
/// - Unused imports (imports not referenced in the file)
/// - Commented-out code blocks
/// - TODO/FIXME/HACK comments (technical debt markers)
/// - Deprecated API usage (@deprecated annotation)
/// - Unused private declarations (private methods/fields never referenced)
class DeadCodeRule extends AnalysisRule {
  const DeadCodeRule();

  @override
  List<Finding> analyze(String filePath, String source, List<String> lines) {
    final findings = <Finding>[];

    _detectUnusedImports(filePath, source, lines, findings);
    _detectCommentedOutCode(filePath, lines, findings);
    _detectTechnicalDebtComments(filePath, lines, findings);
    _detectDeprecatedUsage(filePath, source, lines, findings);
    _detectUnusedPrivateMembers(filePath, source, lines, findings);

    return findings;
  }

  /// Detects imports that don't appear to be used in the file.
  void _detectUnusedImports(
    String filePath,
    String source,
    List<String> lines,
    List<Finding> findings,
  ) {
    final importPattern = RegExp(r"^import\s+'([^']+)'(?:\s+as\s+(\w+))?;");

    for (var i = 0; i < lines.length; i++) {
      final match = importPattern.firstMatch(lines[i].trim());
      if (match == null) continue;

      final importPath = match.group(1)!;
      final alias = match.group(2);

      // Skip dart: imports (core library) — they may provide types
      if (importPath.startsWith('dart:')) continue;

      // Skip the import line itself for the search
      final sourceWithoutImports = lines
          .sublist(i + 1)
          .join('\n');

      if (alias != null) {
        // If aliased, check if the alias is used
        final aliasPattern = RegExp('\\b$alias\\.');
        if (!aliasPattern.hasMatch(sourceWithoutImports)) {
          findings.add(Finding(
            ruleId: 'analyzer/unused-import',
            message:
                'Import "$importPath" (as $alias) appears unused. '
                'Remove unused imports to keep the codebase clean.',
            severity: FindingSeverity.note,
            filePath: filePath,
            line: i + 1,
          ));
        }
      } else {
        // For non-aliased imports, check if any exported symbol is used
        // Use the last segment of the path as a heuristic
        final segments = importPath.split('/');
        final fileName = segments.last.replaceAll('.dart', '');

        // Convert file_name to potential class names (PascalCase)
        final parts = fileName.split('_');
        final className = parts.map((p) =>
            p.isNotEmpty ? p[0].toUpperCase() + p.substring(1) : p).join();

        // Check if the class name or any common derivative is used
        if (!sourceWithoutImports.contains(className) &&
            !sourceWithoutImports.contains(fileName)) {
          // More aggressive check: look for show/hide clauses
          if (lines[i].contains('show ')) {
            final showPattern = RegExp(r'show\s+(.+);');
            final showMatch = showPattern.firstMatch(lines[i]);
            if (showMatch != null) {
              final shown = showMatch.group(1)!.split(',').map((s) => s.trim());
              final allUnused = shown.every((s) =>
                  !sourceWithoutImports.contains(s));
              if (allUnused) {
                findings.add(Finding(
                  ruleId: 'analyzer/unused-import',
                  message:
                      'Import "$importPath" appears unused. '
                      'Remove unused imports to keep the codebase clean.',
                  severity: FindingSeverity.note,
                  filePath: filePath,
                  line: i + 1,
                ));
              }
            }
          }
        }
      }
    }
  }

  /// Detects blocks of commented-out code (not documentation comments).
  void _detectCommentedOutCode(
    String filePath,
    List<String> lines,
    List<Finding> findings,
  ) {
    // Patterns that suggest code rather than comments
    final codePatterns = [
      RegExp(r'//\s*(final|var|const|int|double|String|bool|void|return|if|for|while|class|import)\b'),
      RegExp(r'//\s*\w+\s*[=\(;{]'),
      RegExp(r'//\s*\w+\.\w+\('),
    ];

    var consecutiveCodeComments = 0;
    var blockStartLine = 0;

    for (var i = 0; i < lines.length; i++) {
      final trimmed = lines[i].trimLeft();

      // Skip doc comments
      if (trimmed.startsWith('///')) continue;

      if (trimmed.startsWith('//')) {
        final isCodeComment = codePatterns.any((p) => p.hasMatch(trimmed));
        if (isCodeComment) {
          if (consecutiveCodeComments == 0) {
            blockStartLine = i;
          }
          consecutiveCodeComments++;
        } else {
          _emitCommentedCodeFinding(
            filePath, findings, consecutiveCodeComments, blockStartLine,
          );
          consecutiveCodeComments = 0;
        }
      } else {
        _emitCommentedCodeFinding(
          filePath, findings, consecutiveCodeComments, blockStartLine,
        );
        consecutiveCodeComments = 0;
      }
    }

    // Handle end-of-file
    _emitCommentedCodeFinding(
      filePath, findings, consecutiveCodeComments, blockStartLine,
    );
  }

  void _emitCommentedCodeFinding(
    String filePath,
    List<Finding> findings,
    int count,
    int startLine,
  ) {
    if (count >= 3) {
      findings.add(Finding(
        ruleId: 'analyzer/commented-out-code',
        message:
            'Block of $count lines of commented-out code detected. '
            'Remove dead code and use version control to track history.',
        severity: FindingSeverity.note,
        filePath: filePath,
        line: startLine + 1,
        endLine: startLine + count,
      ));
    }
  }

  /// Detects TODO, FIXME, HACK comments as technical debt markers.
  void _detectTechnicalDebtComments(
    String filePath,
    List<String> lines,
    List<Finding> findings,
  ) {
    final debtPattern = RegExp(
      r'//\s*(TODO|FIXME|HACK|XXX|UNDONE)\b[:\s]*(.*)',
      caseSensitive: false,
    );

    for (var i = 0; i < lines.length; i++) {
      final match = debtPattern.firstMatch(lines[i]);
      if (match != null) {
        final tag = match.group(1)!.toUpperCase();
        final description = match.group(2)?.trim() ?? '';

        findings.add(Finding(
          ruleId: 'analyzer/technical-debt-comment',
          message:
              '$tag comment found${description.isNotEmpty ? ': "$description"' : ''}. '
              'Track technical debt in issue tracker rather than '
              'code comments.',
          severity: FindingSeverity.note,
          filePath: filePath,
          line: i + 1,
        ));
      }
    }
  }

  /// Detects usage of @deprecated APIs.
  void _detectDeprecatedUsage(
    String filePath,
    String source,
    List<String> lines,
    List<Finding> findings,
  ) {
    // Detect @deprecated or @Deprecated annotations on declarations
    final deprecatedPattern = RegExp(
      r'@[Dd]eprecated',
    );

    for (var i = 0; i < lines.length; i++) {
      if (deprecatedPattern.hasMatch(lines[i])) {
        // Find the next non-empty, non-comment line
        for (var j = i + 1; j < lines.length && j < i + 5; j++) {
          final nextLine = lines[j].trim();
          if (nextLine.isEmpty || nextLine.startsWith('//') || nextLine.startsWith('///')) {
            continue;
          }

          // Extract the name of the deprecated member
          final memberPattern = RegExp(
            r'(?:class|void|int|double|bool|String|Future|dynamic|static\s+)?\s*(\w+)',
          );
          final memberMatch = memberPattern.firstMatch(nextLine);

          if (memberMatch != null) {
            findings.add(Finding(
              ruleId: 'analyzer/deprecated-member',
              message:
                  'Deprecated member "${memberMatch.group(1)}" found. '
                  'Plan to remove or replace deprecated code to '
                  'avoid future breakage.',
              severity: FindingSeverity.note,
              filePath: filePath,
              line: i + 1,
            ));
          }
          break;
        }
      }
    }
  }

  /// Detects unused private members (methods, fields, getters).
  void _detectUnusedPrivateMembers(
    String filePath,
    String source,
    List<String> lines,
    List<Finding> findings,
  ) {
    // Find private member declarations
    final privateFieldPattern = RegExp(
      r'(?:final|var|late|static)\s+(?:\w+(?:<[^>]*>)?\s+)?(_\w+)\s*[;=]',
    );
    final privateMethodPattern = RegExp(
      r'(?:void|int|double|bool|String|Future|Stream|dynamic|\w+(?:<[^>]*>)?)\s+(_\w+)\s*\(',
    );
    final privateGetterPattern = RegExp(
      r'(?:\w+)\s+get\s+(_\w+)',
    );

    final privateMembers = <({String name, int line})>[];

    for (var i = 0; i < lines.length; i++) {
      final trimmed = lines[i].trimLeft();

      // Skip comments
      if (trimmed.startsWith('//') || trimmed.startsWith('*') || trimmed.startsWith('///')) {
        continue;
      }

      for (final pattern in [privateFieldPattern, privateMethodPattern, privateGetterPattern]) {
        final match = pattern.firstMatch(lines[i]);
        if (match != null) {
          final name = match.group(1)!;
          // Skip common Flutter patterns
          if (name == '_key' || name == '_controller' || name == '_formKey' ||
              name == '_scaffoldKey' || name == '_navigatorKey') {
            continue;
          }
          privateMembers.add((name: name, line: i + 1));
        }
      }
    }

    // Check if each private member is referenced elsewhere in the file
    // Build a single regex for all members to avoid repeated compilation
    for (final member in privateMembers) {
      final pattern = RegExp('\\b${RegExp.escape(member.name)}\\b');
      final occurrences = pattern.allMatches(source).length;

      if (occurrences <= 1) {
        findings.add(Finding(
          ruleId: 'analyzer/unused-private-member',
          message:
              'Private member "${member.name}" appears to be unused. '
              'Remove unused code to reduce maintenance burden.',
          severity: FindingSeverity.warning,
          filePath: filePath,
          line: member.line,
        ));
      }
    }
  }
}
