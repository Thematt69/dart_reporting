import '../../common/common.dart';
import 'analysis_rule.dart';

/// Detects common widget lifecycle issues with:
///
/// - **flutter_map**: `MapController` not disposed.
/// - **wakelock_plus**: `WakelockPlus.enable()` without corresponding
///   `WakelockPlus.disable()` in `dispose()`.
/// - **webview_flutter**: `WebViewController` not properly managed.
/// - **lottie**: Lottie animations with `AnimationController` not disposed.
class WidgetLifecycleRule extends AnalysisRule {
  const WidgetLifecycleRule();

  // MapController usage
  static final _mapControllerPattern = RegExp(
    r'MapController\s*\(\)',
  );

  // WakelockPlus.enable()
  static final _wakelockEnablePattern = RegExp(
    r'WakelockPlus\.enable\s*\(',
  );

  // WakelockPlus.disable()
  static final _wakelockDisablePattern = RegExp(
    r'WakelockPlus\.disable\s*\(',
  );

  // WebViewController creation
  static final _webViewControllerPattern = RegExp(
    r'WebViewController\s*\(',
  );

  // Lottie AnimationController pattern
  static final _lottiePattern = RegExp(
    r'Lottie\.(asset|network|file|memory)\s*\(',
  );

  // AnimationController field
  static final _animControllerFieldPattern = RegExp(
    r'AnimationController\s*\??\s+(\w+)',
  );

  // dispose() method
  static final _disposePattern = RegExp(
    r'void\s+dispose\s*\(\)',
  );

  @override
  List<Finding> analyze(String filePath, String source, List<String> lines) {
    final findings = <Finding>[];

    // Check flutter_map MapController
    _checkMapController(filePath, source, lines, findings);

    // Check wakelock_plus
    _checkWakelock(filePath, source, lines, findings);

    // Check webview_flutter
    _checkWebViewController(filePath, source, lines, findings);

    // Check lottie AnimationController
    _checkLottieController(filePath, source, lines, findings);

    return findings;
  }

  // MapController field declaration pattern (captures variable name)
  static final _mapControllerFieldPattern = RegExp(
    r'MapController\s*\??\s+(\w+)',
  );

  void _checkMapController(
    String filePath,
    String source,
    List<String> lines,
    List<Finding> findings,
  ) {
    if (!source.contains('flutter_map') && !source.contains('MapController')) {
      return;
    }

    for (var i = 0; i < lines.length; i++) {
      if (_mapControllerPattern.hasMatch(lines[i])) {
        // Extract the variable name from the field declaration
        final fieldMatch = _mapControllerFieldPattern.firstMatch(source);
        final controllerName = fieldMatch?.group(1);

        // Check if the specific MapController is disposed
        final hasDispose = _disposePattern.hasMatch(source);
        final isDisposed = controllerName != null &&
            hasDispose &&
            _isVariableDisposedInDispose(source, controllerName);

        if (!isDisposed) {
          findings.add(Finding(
            ruleId: 'analyzer/flutter-map-controller-not-disposed',
            message:
                'MapController${controllerName != null ? ' "$controllerName"' : ''} '
                'should be disposed in the dispose() method to prevent '
                'memory leaks. Call '
                '${controllerName ?? 'mapController'}.dispose() in dispose().',
            severity: FindingSeverity.warning,
            filePath: filePath,
            line: i + 1,
            helpUri: 'https://pub.dev/packages/flutter_map',
          ));
        }
      }
    }
  }

  /// Checks if a variable is disposed inside the dispose() method body.
  bool _isVariableDisposedInDispose(String source, String variableName) {
    final disposeMatch = _disposePattern.firstMatch(source);
    if (disposeMatch == null) return false;

    final disposeBody = _extractMethodBody(source, disposeMatch.start);
    if (disposeBody == null) return false;

    return disposeBody.contains('$variableName.dispose()') ||
        disposeBody.contains('$variableName?.dispose()');
  }

  void _checkWakelock(
    String filePath,
    String source,
    List<String> lines,
    List<Finding> findings,
  ) {
    if (!source.contains('WakelockPlus')) return;

    final hasEnable = _wakelockEnablePattern.hasMatch(source);
    final hasDisable = _wakelockDisablePattern.hasMatch(source);
    final hasDispose = _disposePattern.hasMatch(source);

    if (hasEnable && !hasDisable) {
      for (var i = 0; i < lines.length; i++) {
        if (_wakelockEnablePattern.hasMatch(lines[i])) {
          findings.add(Finding(
            ruleId: 'analyzer/wakelock-not-disabled',
            message:
                'WakelockPlus.enable() is called without a corresponding '
                'WakelockPlus.disable(). Ensure the wakelock is disabled '
                'in dispose() to prevent battery drain.',
            severity: FindingSeverity.warning,
            filePath: filePath,
            line: i + 1,
            helpUri: 'https://pub.dev/packages/wakelock_plus',
          ));
        }
      }
    } else if (hasEnable && hasDisable && hasDispose) {
      // Check that disable is called inside dispose
      final disposeMatch = _disposePattern.firstMatch(source);
      if (disposeMatch != null) {
        final disposeBody = _extractMethodBody(source, disposeMatch.start);
        if (disposeBody != null &&
            !_wakelockDisablePattern.hasMatch(disposeBody)) {
          for (var i = 0; i < lines.length; i++) {
            if (_wakelockEnablePattern.hasMatch(lines[i])) {
              findings.add(Finding(
                ruleId: 'analyzer/wakelock-not-disabled-in-dispose',
                message:
                    'WakelockPlus.disable() should be called in '
                    'dispose() to ensure the wakelock is released '
                    'when the widget is removed.',
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

  void _checkWebViewController(
    String filePath,
    String source,
    List<String> lines,
    List<Finding> findings,
  ) {
    if (!source.contains('webview_flutter') &&
        !source.contains('WebViewController')) {
      return;
    }

    for (var i = 0; i < lines.length; i++) {
      if (_webViewControllerPattern.hasMatch(lines[i])) {
        if (!_disposePattern.hasMatch(source)) {
          findings.add(Finding(
            ruleId: 'analyzer/webview-controller-lifecycle',
            message:
                'WebViewController should be properly managed. '
                'Ensure the widget using WebViewController has a '
                'dispose() method for cleanup.',
            severity: FindingSeverity.note,
            filePath: filePath,
            line: i + 1,
            helpUri: 'https://pub.dev/packages/webview_flutter',
          ));
        }
      }
    }
  }

  void _checkLottieController(
    String filePath,
    String source,
    List<String> lines,
    List<Finding> findings,
  ) {
    if (!source.contains('Lottie') && !source.contains('lottie')) return;

    // Check if Lottie is used with a controller
    final hasLottie = _lottiePattern.hasMatch(source);
    final hasAnimController = _animControllerFieldPattern.hasMatch(source);

    if (hasLottie && hasAnimController) {
      // Check if the AnimationController is disposed
      final controllerMatch =
          _animControllerFieldPattern.firstMatch(source);
      if (controllerMatch != null) {
        final controllerName = controllerMatch.group(1)!;
        final hasDispose = _disposePattern.hasMatch(source);

        if (hasDispose) {
          final disposeMatch = _disposePattern.firstMatch(source)!;
          final disposeBody =
              _extractMethodBody(source, disposeMatch.start);
          if (disposeBody != null &&
              !disposeBody.contains('$controllerName.dispose()') &&
              !disposeBody.contains('$controllerName?.dispose()')) {
            final lineNum = source
                .substring(0, controllerMatch.start)
                .split('\n')
                .length;
            findings.add(Finding(
              ruleId: 'analyzer/lottie-controller-not-disposed',
              message:
                  'AnimationController "$controllerName" used with Lottie '
                  'is not disposed in dispose(). Call '
                  '$controllerName.dispose() to prevent memory leaks.',
              severity: FindingSeverity.warning,
              filePath: filePath,
              line: lineNum,
            ));
          }
        }
      }
    }
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
}
