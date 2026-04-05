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
}
