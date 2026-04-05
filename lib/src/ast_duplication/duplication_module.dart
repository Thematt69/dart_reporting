import 'dart:io';

import '../common/common.dart';
import 'duplication_models.dart';
import 'structural_hasher.dart';

/// Module that detects structural code duplication across Dart source files.
class DuplicationModule {
  final String projectPath;
  final int minimumBlockLines;
  final List<String> excludePatterns;

  const DuplicationModule({
    required this.projectPath,
    this.minimumBlockLines = 5,
    this.excludePatterns = const [
      '.g.dart',
      '.freezed.dart',
      '.gr.dart',
      '.gen.dart',
      '.mocks.dart',
    ],
  });

  ModuleResult run() {
    try {
      final dir = Directory(projectPath);
      if (!dir.existsSync()) {
        return ModuleFailure(
          moduleName: 'DuplicationModule',
          errorMessage: 'Project directory not found: $projectPath',
        );
      }

      final hasher = StructuralHasher(minimumBlockLines: minimumBlockLines);
      final allBlocks = <String, List<_BlockInfo>>{}; // hash -> blocks
      var totalBlocks = 0;

      // Collect all Dart files in lib/
      final libDir = Directory('$projectPath/lib');
      if (!libDir.existsSync()) {
        return const ModuleSuccess(
          findings: [],
          metadata: {
            'total_blocks': 0,
            'duplicated_blocks': 0,
            'duplication_percent': 0.0,
            'clusters': 0,
          },
        );
      }

      final dartFiles = libDir
          .listSync(recursive: true)
          .whereType<File>()
          .where((f) => f.path.endsWith('.dart'))
          .where((f) => !_isExcluded(f.path));

      for (final file in dartFiles) {
        final source = file.readAsStringSync();
        final blocks = hasher.extractBlocks(source);
        totalBlocks += blocks.length;

        for (final block in blocks) {
          final key = block.structuralHash;
          allBlocks.putIfAbsent(key, () => []).add(_BlockInfo(
                filePath: file.path,
                functionName: block.functionName,
                startLine: block.startLine,
                endLine: block.endLine,
              ));
        }
      }

      // Find clusters (hashes with more than one block)
      final clusters = <DuplicationCluster>[];
      var duplicatedBlocks = 0;

      for (final entry in allBlocks.entries) {
        if (entry.value.length > 1) {
          duplicatedBlocks += entry.value.length;
          clusters.add(DuplicationCluster(
            structuralHash: entry.key,
            blocks: entry.value
                .map((b) => DuplicateBlock(
                      filePath: b.filePath,
                      functionName: b.functionName,
                      startLine: b.startLine,
                      endLine: b.endLine,
                    ))
                .toList(),
          ));
        }
      }

      final percent =
          totalBlocks == 0 ? 0.0 : (duplicatedBlocks / totalBlocks) * 100.0;

      final findings = <Finding>[];

      for (final cluster in clusters) {
        for (final block in cluster.blocks) {
          findings.add(Finding(
            ruleId: 'duplication/structural-duplicate',
            message:
                'Function "${block.functionName}" (lines ${block.startLine}-${block.endLine}) '
                'is structurally duplicated in ${cluster.duplicateCount} locations.',
            severity: FindingSeverity.warning,
            filePath: block.filePath,
            line: block.startLine,
            endLine: block.endLine,
          ));
        }
      }

      return ModuleSuccess(
        findings: findings,
        metadata: {
          'total_blocks': totalBlocks,
          'duplicated_blocks': duplicatedBlocks,
          'duplication_percent':
              double.parse(percent.toStringAsFixed(2)),
          'clusters': clusters.length,
        },
      );
    } on Exception catch (e) {
      return ModuleFailure(
        moduleName: 'DuplicationModule',
        errorMessage: 'Failed to analyze duplication: $e',
      );
    }
  }

  bool _isExcluded(String filePath) {
    return excludePatterns.any((p) => filePath.endsWith(p));
  }
}

class _BlockInfo {
  final String filePath;
  final String functionName;
  final int startLine;
  final int endLine;

  const _BlockInfo({
    required this.filePath,
    required this.functionName,
    required this.startLine,
    required this.endLine,
  });
}
