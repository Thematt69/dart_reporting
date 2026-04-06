import 'dart:io';

import 'package:args/args.dart';
import 'package:dart_reporting/dart_reporting.dart';

Future<void> main(List<String> arguments) async {
  final parser = ArgParser()
    ..addOption(
      'project',
      abbr: 'p',
      help: 'Path to the target project directory.',
      defaultsTo: '.',
    )
    ..addOption(
      'output',
      abbr: 'o',
      help: 'Path for the SARIF output file.',
      defaultsTo: 'dart_reporting.sarif',
    )
    ..addOption(
      'lcov',
      help: 'Path to the LCOV coverage file.',
      defaultsTo: 'coverage/lcov.info',
    )
    ..addOption(
      'min-coverage',
      help: 'Minimum test coverage percentage threshold.',
      defaultsTo: '80',
    )
    ..addFlag(
      'skip-security',
      help: 'Skip the security audit module (OSV + pub.dev checks).',
      defaultsTo: false,
    )
    ..addFlag(
      'help',
      abbr: 'h',
      help: 'Show this help message.',
      negatable: false,
    );

  final ArgResults args;
  try {
    args = parser.parse(arguments);
  } on FormatException catch (e) {
    stderr.writeln('Error: ${e.message}');
    stderr.writeln('Usage: dart run dart_reporting [options]');
    stderr.writeln(parser.usage);
    exit(2);
  }

  if (args.flag('help')) {
    stdout.writeln('dart_reporting - Static analysis and code audit CLI');
    stdout.writeln('');
    stdout.writeln('Usage: dart run dart_reporting [options]');
    stdout.writeln('');
    stdout.writeln(parser.usage);
    exit(0);
  }

  final projectPath = args.option('project')!;
  final outputPath = args.option('output')!;
  final lcovPath = args.option('lcov')!;
  final minCoverage = double.tryParse(args.option('min-coverage')!) ?? 80.0;
  final skipSecurity = args.flag('skip-security');

  stdout.writeln('╔══════════════════════════════════════════╗');
  stdout.writeln('║       dart_reporting - Code Audit        ║');
  stdout.writeln('╚══════════════════════════════════════════╝');
  stdout.writeln('');
  stdout.writeln('Project: $projectPath');
  stdout.writeln('');

  final allFindings = <Finding>[];
  final metadata = <String, Object>{};

  // Module 1: AST Analysis
  stdout.writeln('▸ Running AST analysis...');
  final analyzerResult = AnalyzerModule(projectPath: projectPath).run();
  _processResult('AST Analysis', analyzerResult, allFindings, metadata);

  // Module 2: Code Duplication
  stdout.writeln('▸ Running duplication detection...');
  final duplicationResult =
      DuplicationModule(projectPath: projectPath).run();
  _processResult(
      'Code Duplication', duplicationResult, allFindings, metadata);

  // Module 3: LCOV Coverage
  stdout.writeln('▸ Running coverage analysis...');
  final lcovResult = LcovModule(
    lcovPath: lcovPath,
    minimumCoverage: minCoverage,
  ).run();
  _processResult('LCOV Coverage', lcovResult, allFindings, metadata);

  // Module 4: Security Audit
  if (!skipSecurity) {
    stdout.writeln('▸ Running security audit...');
    final lockPath = '$projectPath/pubspec.lock';
    final securityResult =
        await SecurityModule(pubspecLockPath: lockPath).run();
    _processResult('Security Audit', securityResult, allFindings, metadata);
  } else {
    stdout.writeln('▸ Skipping security audit (--skip-security)');
  }

  // Module 5: Generate SARIF Report
  stdout.writeln('');
  stdout.writeln('▸ Generating SARIF report...');
  final exporter = SarifExporter();
  final sarif = exporter.generateSarif(
    findings: allFindings,
    toolName: 'dart_reporting',
    toolVersion: '1.0.0',
    informationUri: 'https://github.com/Thematt69/dart_reporting',
  );
  exporter.writeToFile(sarif, outputPath);
  stdout.writeln('  SARIF report written to: $outputPath');

  // Print summary
  stdout.writeln('');
  stdout.writeln('════════════════════════════════════════════');
  stdout.writeln('  Summary');
  stdout.writeln('════════════════════════════════════════════');

  final errors =
      allFindings.where((f) => f.severity == FindingSeverity.error).length;
  final warnings =
      allFindings.where((f) => f.severity == FindingSeverity.warning).length;
  final notes =
      allFindings.where((f) => f.severity == FindingSeverity.note).length;

  stdout.writeln('  Total findings: ${allFindings.length}');
  stdout.writeln('  Errors:   $errors');
  stdout.writeln('  Warnings: $warnings');
  stdout.writeln('  Notes:    $notes');

  if (metadata.containsKey('coverage_percent')) {
    stdout.writeln(
        '  Coverage: ${metadata['coverage_percent']}%');
  }
  if (metadata.containsKey('duplication_percent')) {
    stdout.writeln(
        '  Duplication: ${metadata['duplication_percent']}%');
  }

  stdout.writeln('════════════════════════════════════════════');

  // Exit with error if there are error-level findings
  if (errors > 0) {
    exit(1);
  }
}

void _processResult(
  String moduleName,
  ModuleResult result,
  List<Finding> allFindings,
  Map<String, Object> metadata,
) {
  switch (result) {
    case ModuleSuccess(:final findings, metadata: final meta):
      stdout.writeln('  ✓ $moduleName: ${findings.length} finding(s)');
      allFindings.addAll(findings);
      metadata.addAll(meta);
    case ModuleFailure(:final errorMessage):
      stdout.writeln('  ✗ $moduleName failed: $errorMessage');
  }
}
