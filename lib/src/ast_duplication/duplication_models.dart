/// Represents a detected code duplication cluster.
final class DuplicationCluster {
  /// The structural hash shared by the duplicated blocks.
  final String structuralHash;

  /// The list of locations where duplicated blocks appear.
  final List<DuplicateBlock> blocks;

  const DuplicationCluster({
    required this.structuralHash,
    required this.blocks,
  });

  int get duplicateCount => blocks.length;
}

/// Represents a single block of code that is part of a duplication cluster.
final class DuplicateBlock {
  final String filePath;
  final String functionName;
  final int startLine;
  final int endLine;

  const DuplicateBlock({
    required this.filePath,
    required this.functionName,
    required this.startLine,
    required this.endLine,
  });

  int get lineCount => endLine - startLine + 1;
}

/// Aggregate result of duplication analysis.
final class DuplicationSummary {
  final List<DuplicationCluster> clusters;
  final int totalBlocks;
  final int duplicatedBlocks;
  final double duplicationPercent;

  const DuplicationSummary({
    required this.clusters,
    required this.totalBlocks,
    required this.duplicatedBlocks,
    required this.duplicationPercent,
  });
}
