import 'dart:convert';

import 'package:crypto/crypto.dart';

/// Extracts structural blocks from Dart source code and computes
/// structural hashes for duplication detection.
///
/// This uses a lightweight line-based approach to extract function/method
/// bodies and produce structural hashes that ignore variable names,
/// whitespace, and formatting.
class StructuralHasher {
  /// Minimum number of lines for a block to be considered for duplication.
  final int minimumBlockLines;

  const StructuralHasher({this.minimumBlockLines = 5});

  /// Extracts function/method blocks from Dart source content.
  ///
  /// Returns a list of (functionName, startLine, endLine, normalizedBody) tuples.
  List<ExtractedBlock> extractBlocks(String source) {
    final lines = source.split('\n');
    final blocks = <ExtractedBlock>[];

    // Simple brace-matching parser to find function/method bodies
    final functionPattern = RegExp(
      r'^\s*(?:(?:static|async|Future|void|int|double|String|bool|List|Map|Set|dynamic|var|final|const|late)\s+)*'
      r'(\w+)\s*\([^)]*\)\s*(?:async\s*)?\{',
    );

    // Control flow keywords that should not be treated as function names
    const controlKeywords = {
      'if', 'else', 'for', 'while', 'do', 'switch', 'catch', 'try',
      'finally',
    };

    for (var i = 0; i < lines.length; i++) {
      final match = functionPattern.firstMatch(lines[i]);
      if (match == null) continue;

      final funcName = match.group(1) ?? 'anonymous';
      if (controlKeywords.contains(funcName)) continue;
      final startLine = i + 1; // 1-based

      // Count braces to find the end of the function body
      var braceCount = 0;
      var foundOpen = false;
      var endLine = startLine;

      for (var j = i; j < lines.length; j++) {
        for (final ch in lines[j].split('')) {
          if (ch == '{') {
            braceCount++;
            foundOpen = true;
          } else if (ch == '}') {
            braceCount--;
          }
        }
        if (foundOpen && braceCount == 0) {
          endLine = j + 1; // 1-based
          break;
        }
      }

      final lineCount = endLine - startLine + 1;
      if (lineCount >= minimumBlockLines) {
        final bodyLines = lines.sublist(startLine - 1, endLine);
        final normalized = _normalize(bodyLines);
        final hash = _computeHash(normalized);

        blocks.add(ExtractedBlock(
          functionName: funcName,
          startLine: startLine,
          endLine: endLine,
          structuralHash: hash,
        ));
      }
    }

    return blocks;
  }

  /// Normalizes code by stripping identifiers, whitespace, and comments
  /// to produce a structural representation.
  String _normalize(List<String> lines) {
    final buffer = StringBuffer();

    for (final line in lines) {
      var normalized = line.trim();

      // Skip empty lines and single-line comments
      if (normalized.isEmpty || normalized.startsWith('//')) continue;

      // Replace all identifiers with a placeholder to achieve alpha-equivalence
      normalized = normalized.replaceAll(RegExp(r'[a-zA-Z_]\w*'), '_ID_');

      // Remove all whitespace
      normalized = normalized.replaceAll(RegExp(r'\s+'), '');

      // Remove string literals
      normalized = normalized.replaceAll(RegExp(r"'[^']*'"), '_STR_');
      normalized = normalized.replaceAll(RegExp(r'"[^"]*"'), '_STR_');

      buffer.writeln(normalized);
    }

    return buffer.toString();
  }

  /// Computes a SHA-256 hash of the normalized structural representation.
  String _computeHash(String normalized) {
    final bytes = utf8.encode(normalized);
    return sha256.convert(bytes).toString();
  }
}

/// An extracted code block with its structural hash.
final class ExtractedBlock {
  final String functionName;
  final int startLine;
  final int endLine;
  final String structuralHash;

  const ExtractedBlock({
    required this.functionName,
    required this.startLine,
    required this.endLine,
    required this.structuralHash,
  });

  int get lineCount => endLine - startLine + 1;
}
