import '../../common/common.dart';
import 'analysis_rule.dart';

/// Detects common Riverpod anti-patterns:
///
/// - **flutter_riverpod**: Detects usage of `StateNotifier` (prefer `Notifier`
///   from Riverpod 2.0+), detects `ref.watch` inside non-build methods.
/// - **riverpod_annotation**: Detects manual `Provider` declarations when
///   `@riverpod` annotation is available.
class RiverpodRule extends AnalysisRule {
  const RiverpodRule();

  // Deprecated StateNotifier usage
  static final _stateNotifierPattern = RegExp(
    r'class\s+\w+\s+extends\s+StateNotifier<',
  );

  // ChangeNotifier usage with Riverpod (should use Notifier instead)
  static final _changeNotifierProviderPattern = RegExp(
    r'ChangeNotifierProvider\s*[<(]',
  );

  // Manual provider declarations that could use @riverpod
  static final _manualProviderPattern = RegExp(
    r'final\s+\w+Provider\s*=\s*(StateNotifierProvider|NotifierProvider|AsyncNotifierProvider|Provider|FutureProvider|StreamProvider)\s*[<(]',
  );

  // ref.watch in non-build methods (e.g., initState, callbacks)
  static final _refWatchOutsideBuildPattern = RegExp(
    r'ref\.watch\s*\(',
  );

  @override
  List<Finding> analyze(String filePath, String source, List<String> lines) {
    final findings = <Finding>[];

    // Check if source uses riverpod
    if (!source.contains('riverpod')) return findings;

    for (var i = 0; i < lines.length; i++) {
      final line = lines[i];

      // Detect deprecated StateNotifier
      if (_stateNotifierPattern.hasMatch(line)) {
        findings.add(Finding(
          ruleId: 'analyzer/riverpod-prefer-notifier',
          message:
              'StateNotifier is deprecated in Riverpod 2.0+. '
              'Migrate to Notifier or AsyncNotifier for better '
              'lifecycle management and code generation support.',
          severity: FindingSeverity.warning,
          filePath: filePath,
          line: i + 1,
          helpUri: 'https://riverpod.dev/docs/migration/from_state_notifier',
        ));
      }

      // Detect ChangeNotifierProvider (legacy pattern)
      if (_changeNotifierProviderPattern.hasMatch(line)) {
        findings.add(Finding(
          ruleId: 'analyzer/riverpod-avoid-change-notifier',
          message:
              'ChangeNotifierProvider is discouraged in Riverpod. '
              'Use Notifier with @riverpod annotation instead for '
              'better performance and testability.',
          severity: FindingSeverity.warning,
          filePath: filePath,
          line: i + 1,
          helpUri: 'https://riverpod.dev/docs/concepts/providers',
        ));
      }

      // Detect manual provider declarations
      if (_manualProviderPattern.hasMatch(line) &&
          source.contains('riverpod_annotation')) {
        findings.add(Finding(
          ruleId: 'analyzer/riverpod-prefer-annotation',
          message:
              'Consider using the @riverpod annotation from '
              'riverpod_annotation package instead of manually '
              'declaring providers. This enables code generation '
              'and reduces boilerplate.',
          severity: FindingSeverity.note,
          filePath: filePath,
          line: i + 1,
          helpUri: 'https://riverpod.dev/docs/concepts/about_code_generation',
        ));
      }
    }

    // Detect ref.watch outside build context
    _checkRefWatchUsage(source, lines, filePath, findings);

    return findings;
  }

  void _checkRefWatchUsage(
    String source,
    List<String> lines,
    String filePath,
    List<Finding> findings,
  ) {
    // Track if we're inside a build method or not
    final initStatePattern = RegExp(r'void\s+initState\s*\(');
    final disposePattern = RegExp(r'void\s+dispose\s*\(');
    final callbackPatterns = [
      RegExp(r'onPressed\s*:'),
      RegExp(r'onTap\s*:'),
      RegExp(r'onChanged\s*:'),
      RegExp(r'onSubmitted\s*:'),
    ];

    for (var i = 0; i < lines.length; i++) {
      final line = lines[i];

      // Check for ref.watch inside initState or dispose
      if (_refWatchOutsideBuildPattern.hasMatch(line)) {
        // Look backwards to find if we're in initState or dispose
        for (var j = i; j >= (i - 10).clamp(0, lines.length); j--) {
          if (initStatePattern.hasMatch(lines[j]) ||
              disposePattern.hasMatch(lines[j])) {
            findings.add(Finding(
              ruleId: 'analyzer/riverpod-watch-outside-build',
              message:
                  'ref.watch() should not be used outside of build '
                  'methods. Use ref.read() in initState, dispose, '
                  'or callbacks instead.',
              severity: FindingSeverity.warning,
              filePath: filePath,
              line: i + 1,
            ));
            break;
          }

          // Check if in a callback
          for (final pattern in callbackPatterns) {
            if (pattern.hasMatch(lines[j])) {
              findings.add(Finding(
                ruleId: 'analyzer/riverpod-watch-in-callback',
                message:
                    'ref.watch() should not be used inside callbacks. '
                    'Use ref.read() in event handlers like onPressed, '
                    'onTap, etc.',
                severity: FindingSeverity.warning,
                filePath: filePath,
                line: i + 1,
              ));
              break;
            }
          }
        }
      }
    }
  }
}
