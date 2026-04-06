import '../common/common.dart';
import 'osv_client.dart';
import 'pub_dev_client.dart';
import 'pubspec_lock_parser.dart';

/// Module that performs security auditing of dependencies.
///
/// Checks dependencies against the OSV vulnerability database
/// and the pub.dev API for discontinued packages.
class SecurityModule {
  final String pubspecLockPath;
  final bool checkPubDev;

  const SecurityModule({
    required this.pubspecLockPath,
    this.checkPubDev = true,
  });

  Future<ModuleResult> run() async {
    try {
      final parser = PubspecLockParser();
      final deps = parser.parseFile(pubspecLockPath);

      if (deps.isEmpty) {
        return const ModuleSuccess(
          findings: [
            Finding(
              ruleId: 'security/no-dependencies',
              message: 'No dependencies found in pubspec.lock.',
              severity: FindingSeverity.note,
            ),
          ],
        );
      }

      final findings = <Finding>[];
      final osvClient = OsvClient();
      final pubDevClient = PubDevClient();

      try {
        // Query OSV for vulnerabilities concurrently (bounded)
        const maxConcurrent = 5;
        for (var i = 0; i < deps.length; i += maxConcurrent) {
          final batchDeps = deps.skip(i).take(maxConcurrent).toList();
          final results = await Future.wait(
            batchDeps.map((dep) => osvClient.queryVulnerabilities(
              dep.name,
              dep.version,
            )),
          );

          for (var j = 0; j < results.length; j++) {
            final dep = batchDeps[j];
            for (final vuln in results[j]) {
              findings.add(Finding(
                ruleId: 'security/osv-vulnerability',
                message:
                    '${vuln.id}: ${vuln.summary} (package: ${dep.name}@${dep.version})',
                severity: FindingSeverity.error,
                helpUri: 'https://osv.dev/vulnerability/${vuln.id}',
              ));
            }
          }
        }

        // Check pub.dev for discontinued packages concurrently (bounded)
        if (checkPubDev) {
          final hostedDeps =
              deps.where((d) => d.source == 'hosted').toList();

          for (var i = 0; i < hostedDeps.length; i += maxConcurrent) {
            final batchDeps =
                hostedDeps.skip(i).take(maxConcurrent).toList();
            final results = await Future.wait(
              batchDeps.map((dep) => pubDevClient.checkPackageStatus(
                dep.name,
                dep.version,
              )),
            );

            for (var j = 0; j < results.length; j++) {
              final dep = batchDeps[j];
              if (results[j].isDiscontinued) {
                findings.add(Finding(
                  ruleId: 'security/discontinued-package',
                  message:
                      'Package "${dep.name}" is discontinued on pub.dev.',
                  severity: FindingSeverity.warning,
                  helpUri: 'https://pub.dev/packages/${dep.name}',
                ));
              }
            }
          }
        }
      } finally {
        osvClient.close();
        pubDevClient.close();
      }

      return ModuleSuccess(
        findings: findings,
        metadata: {
          'dependencies_checked': deps.length,
          'direct_dependencies': deps.where((d) => d.isDirect).length,
          'transitive_dependencies': deps.where((d) => !d.isDirect).length,
          'vulnerabilities_found':
              findings.where((f) => f.ruleId == 'security/osv-vulnerability').length,
          'discontinued_packages':
              findings.where((f) => f.ruleId == 'security/discontinued-package').length,
        },
      );
    } on Exception catch (e) {
      return ModuleFailure(
        moduleName: 'SecurityModule',
        errorMessage: 'Failed to run security audit: $e',
      );
    }
  }
}
