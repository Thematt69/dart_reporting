import '../../common/common.dart';
import 'analysis_rule.dart';

/// Detects common Firebase anti-patterns:
///
/// - **cloud_firestore**: Firestore snapshot listeners (`.snapshots()`) assigned
///   to StreamSubscription but not cancelled in `dispose()`.
/// - **firebase_auth**: `authStateChanges()` / `idTokenChanges()` /
///   `userChanges()` listeners not cancelled in `dispose()`.
/// - **firebase_messaging**: `onMessage` / `onMessageOpenedApp` listeners
///   not cancelled in `dispose()`.
/// - **firebase_storage**: Upload/download tasks without error handling
///   (missing `.catchError` or try/catch).
/// - **firebase_ai**: Direct model calls without error handling.
class FirebaseRule extends AnalysisRule {
  const FirebaseRule();

  // Firestore snapshots() usage without proper subscription management
  static final _snapshotsPattern = RegExp(
    r'\.snapshots\s*\(',
  );

  // Firebase Auth state listeners
  static final _authListenerPattern = RegExp(
    r'FirebaseAuth\.instance\.(authStateChanges|idTokenChanges|userChanges)\s*\(\)',
  );

  // Firebase Messaging listeners
  static final _messagingListenerPattern = RegExp(
    r'FirebaseMessaging\.(onMessage|onMessageOpenedApp)',
  );

  // Firebase Storage upload/download without error handling
  static final _storageTaskPattern = RegExp(
    r'\.(putFile|putData|putString|putBlob|writeToFile|getData)\s*\(',
  );

  // Firebase AI generate content call
  static final _firebaseAiPattern = RegExp(
    r'\.generateContent\s*\(',
  );

  @override
  List<Finding> analyze(String filePath, String source, List<String> lines) {
    final findings = <Finding>[];

    for (var i = 0; i < lines.length; i++) {
      final line = lines[i];

      // Detect Firestore snapshots() without listen variable
      if (_snapshotsPattern.hasMatch(line)) {
        // Check if the result is being stored in a variable for later cancellation
        final trimmed = line.trim();
        if (!trimmed.contains('StreamSubscription') &&
            !trimmed.startsWith('_') &&
            !trimmed.contains('= ') &&
            !trimmed.contains('cancel')) {
          findings.add(Finding(
            ruleId: 'analyzer/firestore-snapshots-not-tracked',
            message:
                'Firestore snapshots() listener should be stored in a '
                'StreamSubscription and cancelled in dispose() to prevent '
                'memory leaks.',
            severity: FindingSeverity.warning,
            filePath: filePath,
            line: i + 1,
          ));
        }
      }

      // Detect Firebase Auth listeners not stored
      final authMatch = _authListenerPattern.firstMatch(line);
      if (authMatch != null) {
        final trimmed = line.trim();
        if (!trimmed.contains('StreamSubscription') &&
            !trimmed.contains('= ')) {
          findings.add(Finding(
            ruleId: 'analyzer/firebase-auth-listener-not-tracked',
            message:
                'FirebaseAuth.${authMatch.group(1)}() listener should be '
                'stored in a StreamSubscription and cancelled in dispose() '
                'to prevent memory leaks.',
            severity: FindingSeverity.warning,
            filePath: filePath,
            line: i + 1,
          ));
        }
      }

      // Detect Firebase Messaging listeners not stored
      final msgMatch = _messagingListenerPattern.firstMatch(line);
      if (msgMatch != null) {
        final trimmed = line.trim();
        if (!trimmed.contains('StreamSubscription') &&
            !trimmed.contains('= ')) {
          findings.add(Finding(
            ruleId: 'analyzer/firebase-messaging-listener-not-tracked',
            message:
                'FirebaseMessaging.${msgMatch.group(1)} listener should be '
                'stored in a StreamSubscription and cancelled in dispose().',
            severity: FindingSeverity.warning,
            filePath: filePath,
            line: i + 1,
          ));
        }
      }

      // Detect Firebase Storage tasks without error handling
      if (_storageTaskPattern.hasMatch(line)) {
        // Check surrounding lines for error handling
        final surroundingStart = (i - 2).clamp(0, lines.length - 1);
        final surroundingEnd = (i + 3).clamp(0, lines.length);
        final surroundingLines =
            lines.sublist(surroundingStart, surroundingEnd).join('\n');

        if (!surroundingLines.contains('catchError') &&
            !surroundingLines.contains('onError') &&
            !surroundingLines.contains('try') &&
            !surroundingLines.contains('catch')) {
          findings.add(Finding(
            ruleId: 'analyzer/firebase-storage-no-error-handling',
            message:
                'Firebase Storage task should include error handling '
                '(try/catch or .catchError()) to handle upload/download '
                'failures gracefully.',
            severity: FindingSeverity.warning,
            filePath: filePath,
            line: i + 1,
          ));
        }
      }

      // Detect Firebase AI calls without error handling
      if (_firebaseAiPattern.hasMatch(line) &&
          line.contains('firebase_ai')) {
        final surroundingStart = (i - 2).clamp(0, lines.length - 1);
        final surroundingEnd = (i + 3).clamp(0, lines.length);
        final surroundingLines =
            lines.sublist(surroundingStart, surroundingEnd).join('\n');

        if (!surroundingLines.contains('try') &&
            !surroundingLines.contains('catch')) {
          findings.add(Finding(
            ruleId: 'analyzer/firebase-ai-no-error-handling',
            message:
                'Firebase AI generateContent() should be wrapped in '
                'try/catch to handle API errors and rate limiting.',
            severity: FindingSeverity.warning,
            filePath: filePath,
            line: i + 1,
          ));
        }
      }
    }

    return findings;
  }
}
