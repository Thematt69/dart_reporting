import 'package:dart_reporting/dart_reporting.dart';
import 'package:test/test.dart';

void main() {
  group('LcovParser', () {
    const parser = LcovParser();

    test('parses valid LCOV content', () {
      const lcov = '''
SF:lib/src/main.dart
DA:1,1
DA:2,0
DA:3,1
end_of_record
SF:lib/src/utils.dart
DA:1,1
DA:2,1
end_of_record
''';
      final result = parser.parse(lcov);
      expect(result.files, hasLength(2));
      expect(result.totalLinesFound, 5);
      expect(result.totalLinesHit, 4);
      expect(result.coveragePercent, closeTo(80.0, 0.01));
    });

    test('excludes generated files', () {
      const lcov = '''
SF:lib/src/main.dart
DA:1,1
end_of_record
SF:lib/src/model.g.dart
DA:1,0
DA:2,0
end_of_record
SF:lib/src/state.freezed.dart
DA:1,0
end_of_record
''';
      final result = parser.parse(lcov);
      expect(result.files, hasLength(1));
      expect(result.files.first.sourceFile, 'lib/src/main.dart');
    });

    test('handles empty content', () {
      final result = parser.parse('');
      expect(result.files, isEmpty);
      expect(result.coveragePercent, 100.0);
    });
  });

  group('StructuralHasher', () {
    const hasher = StructuralHasher(minimumBlockLines: 3);

    test('extracts blocks from source', () {
      const source = '''
void myFunction() {
  final x = 1;
  final y = 2;
  print(x + y);
}
''';
      final blocks = hasher.extractBlocks(source);
      expect(blocks, hasLength(1));
      expect(blocks.first.functionName, 'myFunction');
    });

    test('produces same hash for structurally identical functions', () {
      const source1 = '''
void foo() {
  final x = 1;
  final y = 2;
  print(x + y);
}
''';
      const source2 = '''
void bar() {
  final a = 1;
  final b = 2;
  print(a + b);
}
''';
      final blocks1 = hasher.extractBlocks(source1);
      final blocks2 = hasher.extractBlocks(source2);
      expect(blocks1, hasLength(1));
      expect(blocks2, hasLength(1));
      expect(blocks1.first.structuralHash, blocks2.first.structuralHash);
    });

    test('produces different hashes for different structures', () {
      const source1 = '''
void foo() {
  final x = 1;
  print(x);
  return;
}
''';
      const source2 = '''
void bar() {
  for (var i = 0; i < 10; i++) {
    print(i);
    continue;
  }
}
''';
      final blocks1 = hasher.extractBlocks(source1);
      final blocks2 = hasher.extractBlocks(source2);
      expect(blocks1, hasLength(1));
      expect(blocks2, hasLength(1));
      expect(
        blocks1.first.structuralHash,
        isNot(blocks2.first.structuralHash),
      );
    });
  });

  group('PubspecLockParser', () {
    final parser = PubspecLockParser();

    test('parses pubspec.lock content', () {
      const lockContent = '''
packages:
  args:
    dependency: "direct main"
    source: hosted
    version: "2.4.2"
  collection:
    dependency: transitive
    source: hosted
    version: "1.18.0"
''';
      final deps = parser.parse(lockContent);
      expect(deps, hasLength(2));

      final args = deps.firstWhere((d) => d.name == 'args');
      expect(args.version, '2.4.2');
      expect(args.isDirect, isTrue);

      final collection = deps.firstWhere((d) => d.name == 'collection');
      expect(collection.version, '1.18.0');
      expect(collection.isDirect, isFalse);
    });

    test('handles empty content', () {
      final deps = parser.parse('');
      expect(deps, isEmpty);
    });
  });

  group('SarifExporter', () {
    final exporter = SarifExporter();

    test('generates valid SARIF structure', () {
      final sarif = exporter.generateSarif(
        findings: [
          const Finding(
            ruleId: 'test/rule-1',
            message: 'Test finding',
            severity: FindingSeverity.warning,
            filePath: 'lib/main.dart',
            line: 10,
          ),
        ],
        toolName: 'test-tool',
      );

      expect(sarif['version'], '2.1.0');
      expect(sarif['\$schema'], isNotNull);

      final runs = sarif['runs'] as List;
      expect(runs, hasLength(1));

      final run = runs.first as Map<String, Object>;
      final tool = run['tool'] as Map<String, Object>;
      final driver = tool['driver'] as Map<String, Object>;
      expect(driver['name'], 'test-tool');

      final results = run['results'] as List;
      expect(results, hasLength(1));
    });

    test('generates SARIF with no findings', () {
      final sarif = exporter.generateSarif(
        findings: [],
        toolName: 'test-tool',
      );

      final runs = sarif['runs'] as List;
      final run = runs.first as Map<String, Object>;
      final results = run['results'] as List;
      expect(results, isEmpty);
    });

    test('maps severity levels correctly', () {
      final sarif = exporter.generateSarif(
        findings: [
          const Finding(
            ruleId: 'r1',
            message: 'Error',
            severity: FindingSeverity.error,
          ),
          const Finding(
            ruleId: 'r2',
            message: 'Warning',
            severity: FindingSeverity.warning,
          ),
          const Finding(
            ruleId: 'r3',
            message: 'Note',
            severity: FindingSeverity.note,
          ),
        ],
        toolName: 'test',
      );

      final runs = sarif['runs'] as List;
      final run = runs.first as Map<String, Object>;
      final results = run['results'] as List;

      expect((results[0] as Map)['level'], 'error');
      expect((results[1] as Map)['level'], 'warning');
      expect((results[2] as Map)['level'], 'note');
    });
  });

  group('Finding', () {
    test('FindingSeverity sarifLevel mapping', () {
      expect(FindingSeverity.error.sarifLevel, 'error');
      expect(FindingSeverity.warning.sarifLevel, 'warning');
      expect(FindingSeverity.note.sarifLevel, 'note');
    });
  });

  group('ModuleResult', () {
    test('ModuleSuccess stores findings and metadata', () {
      const result = ModuleSuccess(
        findings: [
          Finding(
            ruleId: 'test',
            message: 'msg',
            severity: FindingSeverity.note,
          ),
        ],
        metadata: {'key': 'value'},
      );
      expect(result.findings, hasLength(1));
      expect(result.metadata['key'], 'value');
    });

    test('ModuleFailure stores error info', () {
      const result = ModuleFailure(
        moduleName: 'TestModule',
        errorMessage: 'Something went wrong',
      );
      expect(result.moduleName, 'TestModule');
      expect(result.errorMessage, 'Something went wrong');
    });
  });

  group('AnalysisRules', () {
    test('MediaQueryRule detects MediaQuery.of', () {
      const rule = MediaQueryRule();
      const source = '''
Widget build(BuildContext context) {
  final size = MediaQuery.of(context).size;
  return Container();
}
''';
      final findings = rule.analyze('test.dart', source, source.split('\n'));
      expect(findings, hasLength(1));
      expect(findings.first.ruleId, 'analyzer/prefer-specific-media-query');
    });

    test('ImageNetworkRule detects Image.network', () {
      const rule = ImageNetworkRule();
      const source = '''
Widget build(BuildContext context) {
  return Image.network('https://example.com/photo.jpg');
}
''';
      final findings = rule.analyze('test.dart', source, source.split('\n'));
      expect(findings, hasLength(1));
      expect(findings.first.ruleId, 'analyzer/prefer-cached-network-image');
    });

    test('ConstWidgetRule detects non-const SizedBox()', () {
      const rule = ConstWidgetRule();
      const source = '''
Widget build(BuildContext context) {
  return SizedBox();
}
''';
      final findings = rule.analyze('test.dart', source, source.split('\n'));
      expect(findings, hasLength(1));
      expect(findings.first.ruleId, 'analyzer/prefer-const-widget');
    });

    test('ConstWidgetRule ignores const SizedBox()', () {
      const rule = ConstWidgetRule();
      const source = '''
Widget build(BuildContext context) {
  return const SizedBox();
}
''';
      final findings = rule.analyze('test.dart', source, source.split('\n'));
      expect(findings, isEmpty);
    });

    test('StreamSubscriptionRule detects uncancelled subscriptions', () {
      const rule = StreamSubscriptionRule();
      const source = '''
class _MyWidgetState extends State<MyWidget> {
  StreamSubscription? _subscription;

  @override
  void dispose() {
    super.dispose();
  }
}
''';
      final findings = rule.analyze('test.dart', source, source.split('\n'));
      expect(findings, hasLength(1));
      expect(findings.first.ruleId, 'analyzer/uncancelled-subscription');
    });

    test('StreamSubscriptionRule passes when cancel is called', () {
      const rule = StreamSubscriptionRule();
      const source = '''
class _MyWidgetState extends State<MyWidget> {
  StreamSubscription? _subscription;

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }
}
''';
      final findings = rule.analyze('test.dart', source, source.split('\n'));
      expect(findings, isEmpty);
    });
  });

  group('FirebaseRule', () {
    const rule = FirebaseRule();

    test('detects untracked Firestore snapshots listener', () {
      const source = '''
Widget build(BuildContext context) {
  FirebaseFirestore.instance.collection('users').snapshots().listen((s) {
    print(s);
  });
}
''';
      final findings = rule.analyze('test.dart', source, source.split('\n'));
      expect(findings, hasLength(1));
      expect(
          findings.first.ruleId, 'analyzer/firestore-snapshots-not-tracked');
    });

    test('passes when snapshots assigned to variable', () {
      const source = '''
void init() {
  _subscription = FirebaseFirestore.instance.collection('users').snapshots().listen((s) {});
}
''';
      final findings = rule.analyze('test.dart', source, source.split('\n'));
      expect(findings, isEmpty);
    });

    test('detects untracked Firebase Auth listener', () {
      const source = '''
void init() {
  FirebaseAuth.instance.authStateChanges().listen((user) {});
}
''';
      final findings = rule.analyze('test.dart', source, source.split('\n'));
      expect(findings, hasLength(1));
      expect(findings.first.ruleId,
          'analyzer/firebase-auth-listener-not-tracked');
    });

    test('detects untracked Firebase Messaging listener', () {
      const source = '''
void init() {
  FirebaseMessaging.onMessage.listen((msg) {});
}
''';
      final findings = rule.analyze('test.dart', source, source.split('\n'));
      expect(findings, hasLength(1));
      expect(findings.first.ruleId,
          'analyzer/firebase-messaging-listener-not-tracked');
    });

    test('detects Firebase Storage task without error handling', () {
      const source = '''
void upload() {
  ref.putFile(file);
}
''';
      final findings = rule.analyze('test.dart', source, source.split('\n'));
      expect(findings, hasLength(1));
      expect(findings.first.ruleId,
          'analyzer/firebase-storage-no-error-handling');
    });

    test('passes when Storage task has try/catch', () {
      const source = '''
void upload() {
  try {
    ref.putFile(file);
  } catch (e) {
    print(e);
  }
}
''';
      final findings = rule.analyze('test.dart', source, source.split('\n'));
      expect(findings, isEmpty);
    });
  });

  group('RiverpodRule', () {
    const rule = RiverpodRule();

    test('detects deprecated StateNotifier', () {
      const source = '''
import 'package:flutter_riverpod/flutter_riverpod.dart';

class CounterNotifier extends StateNotifier<int> {
  CounterNotifier() : super(0);
}
''';
      final findings = rule.analyze('test.dart', source, source.split('\n'));
      expect(findings, hasLength(1));
      expect(findings.first.ruleId, 'analyzer/riverpod-prefer-notifier');
    });

    test('detects ChangeNotifierProvider', () {
      const source = '''
import 'package:flutter_riverpod/flutter_riverpod.dart';

final provider = ChangeNotifierProvider((ref) => MyNotifier());
''';
      final findings = rule.analyze('test.dart', source, source.split('\n'));
      expect(findings, hasLength(1));
      expect(
          findings.first.ruleId, 'analyzer/riverpod-avoid-change-notifier');
    });

    test('ignores non-riverpod files', () {
      const source = '''
class MyClass {
  void doSomething() {}
}
''';
      final findings = rule.analyze('test.dart', source, source.split('\n'));
      expect(findings, isEmpty);
    });
  });

  group('GoRouterRule', () {
    const rule = GoRouterRule();

    test('detects Navigator.push with go_router', () {
      const source = '''
import 'package:go_router/go_router.dart';

void navigate(BuildContext context) {
  Navigator.push(context, route);
}
''';
      final findings = rule.analyze('test.dart', source, source.split('\n'));
      expect(findings, hasLength(1));
      expect(findings.first.ruleId, 'analyzer/go-router-avoid-navigator');
    });

    test('detects Navigator.of with go_router', () {
      const source = '''
import 'package:go_router/go_router.dart';

void navigate(BuildContext context) {
  Navigator.of(context).push(route);
}
''';
      final findings = rule.analyze('test.dart', source, source.split('\n'));
      expect(findings, hasLength(1));
      expect(findings.first.ruleId, 'analyzer/go-router-avoid-navigator');
    });

    test('detects MaterialPageRoute with go_router', () {
      const source = '''
import 'package:go_router/go_router.dart';

final route = MaterialPageRoute(builder: (_) => Page());
''';
      final findings = rule.analyze('test.dart', source, source.split('\n'));
      expect(findings, hasLength(1));
      expect(findings.first.ruleId,
          'analyzer/go-router-avoid-material-page-route');
    });

    test('ignores files without go_router', () {
      const source = '''
void navigate(BuildContext context) {
  Navigator.push(context, route);
}
''';
      final findings = rule.analyze('test.dart', source, source.split('\n'));
      expect(findings, isEmpty);
    });
  });

  group('EquatableRule', () {
    const rule = EquatableRule();

    test('detects Equatable with empty props', () {
      const source = '''
class User extends Equatable {
  final String name;

  const User(this.name);

  @override
  List<Object?> get props => [];
}
''';
      final findings = rule.analyze('test.dart', source, source.split('\n'));
      expect(
        findings.where((f) => f.ruleId == 'analyzer/equatable-empty-props'),
        hasLength(1),
      );
    });

    test('detects Equatable without props override', () {
      const source = '''
class User extends Equatable {
  final String name;
  const User(this.name);
}
''';
      final findings = rule.analyze('test.dart', source, source.split('\n'));
      expect(
        findings
            .where((f) => f.ruleId == 'analyzer/equatable-missing-props'),
        hasLength(1),
      );
    });

    test('passes for correct Equatable usage', () {
      const source = '''
class User extends Equatable {
  final String name;
  const User(this.name);

  @override
  List<Object?> get props => [name];
}
''';
      final findings = rule.analyze('test.dart', source, source.split('\n'));
      expect(
        findings.where((f) => f.ruleId == 'analyzer/equatable-empty-props'),
        isEmpty,
      );
      expect(
        findings
            .where((f) => f.ruleId == 'analyzer/equatable-missing-props'),
        isEmpty,
      );
    });

    test('ignores files without Equatable', () {
      const source = '''
class User {
  final String name;
  const User(this.name);
}
''';
      final findings = rule.analyze('test.dart', source, source.split('\n'));
      expect(findings, isEmpty);
    });
  });

  group('WidgetLifecycleRule', () {
    const rule = WidgetLifecycleRule();

    test('detects WakelockPlus.enable without disable', () {
      const source = '''
import 'package:wakelock_plus/wakelock_plus.dart';

class _MyState extends State<MyWidget> {
  void initState() {
    WakelockPlus.enable();
  }
}
''';
      final findings = rule.analyze('test.dart', source, source.split('\n'));
      expect(
        findings.where((f) => f.ruleId == 'analyzer/wakelock-not-disabled'),
        hasLength(1),
      );
    });

    test('passes when WakelockPlus has matching disable', () {
      const source = '''
import 'package:wakelock_plus/wakelock_plus.dart';

class _MyState extends State<MyWidget> {
  void initState() {
    WakelockPlus.enable();
  }
  void dispose() {
    WakelockPlus.disable();
    super.dispose();
  }
}
''';
      final findings = rule.analyze('test.dart', source, source.split('\n'));
      expect(
        findings.where((f) => f.ruleId == 'analyzer/wakelock-not-disabled'),
        isEmpty,
      );
    });
  });

  group('ImagePickerRule', () {
    const rule = ImagePickerRule();

    test('detects deprecated ImagePicker.pickImage', () {
      const source = '''
import 'package:image_picker/image_picker.dart';

void pick() {
  ImagePicker.pickImage(source: ImageSource.camera);
}
''';
      final findings = rule.analyze('test.dart', source, source.split('\n'));
      expect(
        findings.where(
            (f) => f.ruleId == 'analyzer/image-picker-deprecated-method'),
        hasLength(1),
      );
    });

    test('ignores files without image_picker', () {
      const source = '''
void doSomething() {
  print("hello");
}
''';
      final findings = rule.analyze('test.dart', source, source.split('\n'));
      expect(findings, isEmpty);
    });
  });

  group('SentryRule', () {
    const rule = SentryRule();

    test('detects print for error logging when Sentry is available', () {
      const source = '''
import 'package:sentry_flutter/sentry_flutter.dart';

void handleError(Object error) {
  print("Error: \$error");
}
''';
      final findings = rule.analyze('test.dart', source, source.split('\n'));
      expect(
        findings.where(
            (f) => f.ruleId == 'analyzer/sentry-use-capture-exception'),
        hasLength(1),
      );
    });

    test('detects catch without Sentry capture', () {
      const source = '''
import 'package:sentry_flutter/sentry_flutter.dart';

void doWork() {
  } catch (e) {
    print(e);
  }
}
''';
      final findings = rule.analyze('test.dart', source, source.split('\n'));
      expect(
        findings.where(
            (f) => f.ruleId == 'analyzer/sentry-missing-capture-in-catch'),
        hasLength(1),
      );
    });

    test('passes when catch has Sentry.captureException', () {
      const source = '''
import 'package:sentry_flutter/sentry_flutter.dart';

void doWork() {
  } catch (e, stackTrace) {
    Sentry.captureException(e, stackTrace: stackTrace);
  }
}
''';
      final findings = rule.analyze('test.dart', source, source.split('\n'));
      expect(
        findings.where(
            (f) => f.ruleId == 'analyzer/sentry-missing-capture-in-catch'),
        isEmpty,
      );
    });

    test('ignores files without Sentry', () {
      const source = '''
void doWork() {
  try {
    something();
  } catch (e) {
    print(e);
  }
}
''';
      final findings = rule.analyze('test.dart', source, source.split('\n'));
      expect(findings, isEmpty);
    });
  });

  // ==================== Core Dart/Flutter Rules ====================

  group('AvoidPrintRule', () {
    const rule = AvoidPrintRule();

    test('detects print() in production code', () {
      const source = '''
void doSomething() {
  print('debug info');
}
''';
      final findings = rule.analyze('lib/main.dart', source, source.split('\n'));
      expect(findings, hasLength(1));
      expect(findings.first.ruleId, 'analyzer/avoid-print');
    });

    test('ignores print() in test files', () {
      const source = '''
void main() {
  print('test output');
}
''';
      final findings = rule.analyze('test/widget_test.dart', source, source.split('\n'));
      expect(findings, isEmpty);
    });

    test('ignores debugPrint()', () {
      const source = '''
void doSomething() {
  debugPrint('debug info');
}
''';
      final findings = rule.analyze('lib/main.dart', source, source.split('\n'));
      expect(findings, isEmpty);
    });

    test('ignores print in comments', () {
      const source = '''
// print('should not trigger');
/// print('doc comment');
''';
      final findings = rule.analyze('lib/main.dart', source, source.split('\n'));
      expect(findings, isEmpty);
    });
  });

  group('AvoidUnnecessaryContainerRule', () {
    const rule = AvoidUnnecessaryContainerRule();

    test('detects empty Container()', () {
      const source = '''
Widget build(BuildContext context) {
  return Container();
}
''';
      final findings = rule.analyze('test.dart', source, source.split('\n'));
      expect(findings, hasLength(1));
      expect(findings.first.ruleId, 'analyzer/avoid-unnecessary-container');
    });

    test('passes for Container with decoration', () {
      const source = '''
Widget build(BuildContext context) {
  return Container(
    decoration: BoxDecoration(color: Colors.red),
    child: Text('hello'),
  );
}
''';
      final findings = rule.analyze('test.dart', source, source.split('\n'));
      expect(findings, isEmpty);
    });

    test('passes for Container with color', () {
      const source = '''
Widget build(BuildContext context) {
  return Container(
    color: Colors.blue,
    child: Text('hello'),
  );
}
''';
      final findings = rule.analyze('test.dart', source, source.split('\n'));
      expect(findings, isEmpty);
    });
  });

  group('AvoidNonNullAssertionRule', () {
    const rule = AvoidNonNullAssertionRule();

    test('detects non-null assertion operator', () {
      const source = '''
void foo(String? value) {
  final x = value!;
}
''';
      final findings = rule.analyze('test.dart', source, source.split('\n'));
      expect(findings, hasLength(1));
      expect(findings.first.ruleId, 'analyzer/avoid-non-null-assertion');
    });

    test('ignores != operator', () {
      const source = '''
void foo(String? value) {
  if (value != null) {}
}
''';
      final findings = rule.analyze('test.dart', source, source.split('\n'));
      expect(findings, isEmpty);
    });
  });

  group('AvoidEmptyCatchRule', () {
    const rule = AvoidEmptyCatchRule();

    test('detects empty catch block', () {
      const source = '''
void foo() {
  try {
    doSomething();
  } catch (e) {
  }
}
''';
      final findings = rule.analyze('test.dart', source, source.split('\n'));
      expect(findings, hasLength(1));
      expect(findings.first.ruleId, 'analyzer/avoid-empty-catch');
    });

    test('passes for catch with body', () {
      const source = '''
void foo() {
  try {
    doSomething();
  } catch (e) {
    print(e);
  }
}
''';
      final findings = rule.analyze('test.dart', source, source.split('\n'));
      expect(findings, isEmpty);
    });
  });

  group('PreferIsEmptyRule', () {
    const rule = PreferIsEmptyRule();

    test('detects .length == 0', () {
      const source = '''
void foo(List<int> list) {
  if (list.length == 0) {}
}
''';
      final findings = rule.analyze('test.dart', source, source.split('\n'));
      expect(findings, hasLength(1));
      expect(findings.first.ruleId, 'analyzer/prefer-is-empty');
    });

    test('detects .length > 0', () {
      const source = '''
void foo(List<int> list) {
  if (list.length > 0) {}
}
''';
      final findings = rule.analyze('test.dart', source, source.split('\n'));
      expect(findings, hasLength(1));
      expect(findings.first.ruleId, 'analyzer/prefer-is-empty');
    });
  });

  group('AvoidHardcodedColorsRule', () {
    const rule = AvoidHardcodedColorsRule();

    test('detects Color(0x...) in widget code', () {
      const source = '''
Widget build(BuildContext context) {
  return Container(color: Color(0xFF00FF00));
}
''';
      final findings = rule.analyze('lib/my_widget.dart', source, source.split('\n'));
      expect(
        findings.where((f) => f.ruleId == 'analyzer/avoid-hardcoded-colors'),
        isNotEmpty,
      );
    });

    test('ignores theme/color files', () {
      const source = '''
Widget build(BuildContext context) {
  return Container(color: Color(0xFF00FF00));
}
''';
      final findings = rule.analyze('lib/theme.dart', source, source.split('\n'));
      expect(findings, isEmpty);
    });
  });

  group('PreferNamedParametersRule', () {
    const rule = PreferNamedParametersRule();

    test('detects function with too many positional parameters', () {
      const source = '''
void doSomething(String a, int b, double c, bool d) {
  // body
}
''';
      final findings = rule.analyze('test.dart', source, source.split('\n'));
      expect(findings, hasLength(1));
      expect(findings.first.ruleId, 'analyzer/prefer-named-parameters');
    });

    test('passes for function with 3 or fewer positional parameters', () {
      const source = '''
void doSomething(String a, int b, double c) {
  // body
}
''';
      final findings = rule.analyze('test.dart', source, source.split('\n'));
      expect(findings, isEmpty);
    });

    test('passes for function with named parameters', () {
      const source = '''
void doSomething({required String a, required int b, required double c, required bool d}) {
  // body
}
''';
      final findings = rule.analyze('test.dart', source, source.split('\n'));
      expect(findings, isEmpty);
    });
  });

  group('AvoidBuildContextInAsyncRule', () {
    const rule = AvoidBuildContextInAsyncRule();

    test('detects async function with BuildContext parameter', () {
      const source = '''
Future<void> doSomething(BuildContext context) async {
  await Future.delayed(Duration(seconds: 1));
  Navigator.of(context).pop();
}
''';
      final findings = rule.analyze('test.dart', source, source.split('\n'));
      expect(findings, hasLength(1));
      expect(findings.first.ruleId, 'analyzer/avoid-build-context-in-async');
    });

    test('passes for sync function with BuildContext', () {
      const source = '''
void doSomething(BuildContext context) {
  Navigator.of(context).pop();
}
''';
      final findings = rule.analyze('test.dart', source, source.split('\n'));
      expect(findings, isEmpty);
    });
  });

  group('AvoidSetStateInAsyncRule', () {
    const rule = AvoidSetStateInAsyncRule();

    test('detects setState after await without mounted check', () {
      const source = '''
class _MyState extends State<MyWidget> {
  void _loadData() async {
    final data = await fetchData();
    setState(() {
      _data = data;
    });
  }
}
''';
      final findings = rule.analyze('test.dart', source, source.split('\n'));
      expect(findings, hasLength(1));
      expect(findings.first.ruleId, 'analyzer/avoid-set-state-in-async');
    });

    test('passes when mounted is checked', () {
      const source = '''
class _MyState extends State<MyWidget> {
  void _loadData() async {
    final data = await fetchData();
    if (!mounted) return;
    setState(() {
      _data = data;
    });
  }
}
''';
      final findings = rule.analyze('test.dart', source, source.split('\n'));
      expect(findings, isEmpty);
    });

    test('ignores files without State class', () {
      const source = '''
void doSomething() async {
  await Future.delayed(Duration(seconds: 1));
}
''';
      final findings = rule.analyze('test.dart', source, source.split('\n'));
      expect(findings, isEmpty);
    });
  });

  group('UseKeyInWidgetConstructorRule', () {
    const rule = UseKeyInWidgetConstructorRule();

    test('detects widget without key parameter', () {
      const source = '''
class MyWidget extends StatelessWidget {
  final String title;
  const MyWidget(this.title);

  @override
  Widget build(BuildContext context) => Text(title);
}
''';
      final findings = rule.analyze('test.dart', source, source.split('\n'));
      expect(findings, hasLength(1));
      expect(findings.first.ruleId, 'analyzer/use-key-in-widget-constructor');
    });

    test('passes when key is present', () {
      const source = '''
class MyWidget extends StatelessWidget {
  final String title;
  const MyWidget({super.key, required this.title});

  @override
  Widget build(BuildContext context) => Text(title);
}
''';
      final findings = rule.analyze('test.dart', source, source.split('\n'));
      expect(findings, isEmpty);
    });
  });

  // ==================== Dead Code Detection ====================

  group('DeadCodeRule', () {
    const rule = DeadCodeRule();

    test('detects commented-out code blocks', () {
      const source = '''
void main() {
  // final x = 1;
  // final y = 2;
  // print(x + y);
}
''';
      final findings = rule.analyze('test.dart', source, source.split('\n'));
      expect(
        findings.where((f) => f.ruleId == 'analyzer/commented-out-code'),
        hasLength(1),
      );
    });

    test('ignores regular comments', () {
      const source = '''
// This is a regular comment explaining the code
// It describes what the function does
// And provides context for the reader
void main() {}
''';
      final findings = rule.analyze('test.dart', source, source.split('\n'));
      expect(
        findings.where((f) => f.ruleId == 'analyzer/commented-out-code'),
        isEmpty,
      );
    });

    test('detects TODO/FIXME comments', () {
      const source = '''
void main() {
  // TODO: implement this feature
  // FIXME: broken edge case
}
''';
      final findings = rule.analyze('test.dart', source, source.split('\n'));
      expect(
        findings.where((f) => f.ruleId == 'analyzer/technical-debt-comment'),
        hasLength(2),
      );
    });

    test('detects deprecated members', () {
      const source = '''
@deprecated
void oldMethod() {}
''';
      final findings = rule.analyze('test.dart', source, source.split('\n'));
      expect(
        findings.where((f) => f.ruleId == 'analyzer/deprecated-member'),
        hasLength(1),
      );
    });

    test('detects unused private members', () {
      const source = '''
class MyClass {
  final String _unusedField = 'hello';

  void doSomething() {
    print('doing something');
  }
}
''';
      final findings = rule.analyze('test.dart', source, source.split('\n'));
      expect(
        findings.where((f) => f.ruleId == 'analyzer/unused-private-member'),
        hasLength(1),
      );
    });

    test('passes for used private members', () {
      const source = '''
class MyClass {
  final String _usedField = 'hello';

  void doSomething() {
    print(_usedField);
  }
}
''';
      final findings = rule.analyze('test.dart', source, source.split('\n'));
      expect(
        findings.where((f) => f.ruleId == 'analyzer/unused-private-member'),
        isEmpty,
      );
    });
  });
}
