import 'dart:io';

import '../common/common.dart';
import 'lcov_parser.dart';

/// Module that runs LCOV coverage analysis and generates findings.
class LcovModule {
  final String lcovPath;
  final double minimumCoverage;

  const LcovModule({
    required this.lcovPath,
    this.minimumCoverage = 80.0,
  });

  ModuleResult run() {
    try {
      final file = File(lcovPath);
      if (!file.existsSync()) {
        return ModuleSuccess(
          findings: [
            Finding(
              ruleId: 'coverage/missing-lcov',
              message: 'Coverage file not found at $lcovPath. '
                  'Run "flutter test --coverage" to generate it.',
              severity: FindingSeverity.warning,
            ),
          ],
          metadata: {'lcov_found': false},
        );
      }

      final content = file.readAsStringSync();
      final parser = LcovParser();
      final summary = parser.parse(content);

      final findings = <Finding>[];

      if (summary.coveragePercent < minimumCoverage) {
        findings.add(Finding(
          ruleId: 'coverage/below-threshold',
          message:
              'Global test coverage is ${summary.coveragePercent.toStringAsFixed(1)}%, '
              'below the required ${minimumCoverage.toStringAsFixed(1)}% threshold.',
          severity: FindingSeverity.warning,
        ));
      }

      for (final file in summary.files) {
        if (file.coveragePercent < minimumCoverage) {
          findings.add(Finding(
            ruleId: 'coverage/file-below-threshold',
            message:
                'Test coverage for ${file.sourceFile} is ${file.coveragePercent.toStringAsFixed(1)}%, '
                'below the required ${minimumCoverage.toStringAsFixed(1)}% threshold.',
            severity: FindingSeverity.note,
            filePath: file.sourceFile,
          ));
        }
      }

      return ModuleSuccess(
        findings: findings,
        metadata: {
          'lcov_found': true,
          'coverage_percent':
              double.parse(summary.coveragePercent.toStringAsFixed(2)),
          'total_lines_found': summary.totalLinesFound,
          'total_lines_hit': summary.totalLinesHit,
          'files_analyzed': summary.files.length,
        },
      );
    } on Exception catch (e) {
      return ModuleFailure(
        moduleName: 'LcovModule',
        errorMessage: 'Failed to parse LCOV file: $e',
      );
    }
  }
}
