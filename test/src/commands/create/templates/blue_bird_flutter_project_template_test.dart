import 'dart:io';

import 'package:blue_bird_cli/src/cli/cli.dart';
import 'package:blue_bird_cli/src/commands/create/templates/blue_bird_flutter_project/blue_bird_flutter_project_template.dart';
import 'package:blue_bird_cli/src/utils/blue_bird_mason_generator.dart';
import 'package:blue_bird_cli/src/utils/template.dart';
import 'package:mason/mason.dart';
import 'package:mocktail/mocktail.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

class _MockLogger extends Mock implements Logger {}

class _MockProgress extends Mock implements Progress {}

class _MockBlueBirdMasonGenerator extends Mock
    implements BlueBirdMasonGenerator {}

class _TestProcess {
  Future<ProcessResult> run(
    String command,
    List<String> args, {
    bool runInShell = false,
    String? workingDirectory,
  }) {
    throw UnimplementedError();
  }
}

class _MockProcess extends Mock implements _TestProcess {}

class FakeDirectoryGeneratorTarget extends Fake
    implements DirectoryGeneratorTarget {}

class FakeTemplate extends Fake implements Template {}

void main() {
  group('FlutterProjectTemplate', () {
    late Logger logger;
    late Progress progress;
    late BlueBirdMasonGenerator blueBirdGenerator;
    late Directory tempDir;
    late _TestProcess process;

    setUpAll(() {
      registerFallbackValue(FakeDirectoryGeneratorTarget());
      registerFallbackValue(FakeTemplate());
    });

    setUp(() {
      logger = _MockLogger();
      progress = _MockProgress();
      blueBirdGenerator = _MockBlueBirdMasonGenerator();

      when(() => logger.progress(any())).thenReturn(progress);
      when(() => logger.info(any())).thenReturn(null);
      when(() => logger.err(any())).thenReturn(null);
      when(() => logger.warn(any())).thenReturn(null);
      when(() => progress.complete(any())).thenReturn(null);
      when(() => progress.fail()).thenReturn(null);

      tempDir = Directory.systemTemp.createTempSync();

      process = _MockProcess();
      when(
        () => process.run(
          any(),
          any(),
          runInShell: any(named: 'runInShell'),
          workingDirectory: any(named: 'workingDirectory'),
        ),
      ).thenAnswer(
        (_) async => ProcessResult(0, ExitCode.success.code, '', ''),
      );
    });

    tearDown(() {
      tempDir.deleteSync(recursive: true);
    });

    test('can be instantiated', () {
      expect(FlutterProjectTemplate(), isNotNull);
    });

    test('has correct name', () {
      final template = FlutterProjectTemplate();
      expect(template.name, 'flutter_project');
    });

    test('has correct help text', () {
      final template = FlutterProjectTemplate();
      expect(template.help, 'Generate a Blue Bird Flutter project.');
    });

    test('onGenerateComplete runs all steps', () async {
      final template = FlutterProjectTemplate();
      final outputDir = Directory(p.join(tempDir.path, 'test_project'))
        ..createSync();

      // Create main project pubspec
      File(p.join(outputDir.path, 'pubspec.yaml'))
        ..createSync()
        ..writeAsStringSync('''
name: test_project
workspace:
  - packages
dependencies:
  flutter:
    sdk: flutter
''');

      // Setup mock for example package generation
      when(
        () => blueBirdGenerator.generate(
          template: any(named: 'template'),
          vars: any(named: 'vars'),
          target: any(named: 'target'),
        ),
      ).thenAnswer((_) async {
        // Create the example package structure
        final packagesDir = Directory(p.join(outputDir.path, 'packages'))
          ..createSync();
        final exampleDir =
            Directory(p.join(packagesDir.path, 'bb_package_example'))
              ..createSync();

        File(p.join(exampleDir.path, 'pubspec.yaml'))
          ..createSync()
          ..writeAsStringSync('name: bb_package_example\n');
      });

      final vars = {
        'org_name': 'com.example.test',
        'platforms': {
          'android': true,
          'ios': true,
          'web': false,
          'linux': false,
          'macos': false,
          'windows': false,
        },
      };

      await ProcessOverrides.runZoned(
        () => template.onGenerateComplete(
          logger,
          outputDir,
          blueBirdGenerator,
          vars,
        ),
        runProcess: process.run,
      );

      verify(() => logger.info(any())).called(greaterThan(0));
      verify(
        () => blueBirdGenerator.generate(
          template: any(named: 'template'),
          vars: any(named: 'vars'),
          target: any(named: 'target'),
        ),
      ).called(1);
    });

    test('onGenerateComplete works with null vars', () async {
      final template = FlutterProjectTemplate();
      final outputDir = Directory(p.join(tempDir.path, 'test_project'))
        ..createSync();

      File(p.join(outputDir.path, 'pubspec.yaml'))
        ..createSync()
        ..writeAsStringSync('''
name: test_project
workspace:
  - packages
dependencies:
  flutter:
    sdk: flutter
''');

      when(
        () => blueBirdGenerator.generate(
          template: any(named: 'template'),
          vars: any(named: 'vars'),
          target: any(named: 'target'),
        ),
      ).thenAnswer((_) async {
        final packagesDir = Directory(p.join(outputDir.path, 'packages'))
          ..createSync();
        final exampleDir =
            Directory(p.join(packagesDir.path, 'bb_package_example'))
              ..createSync();

        File(p.join(exampleDir.path, 'pubspec.yaml'))
          ..createSync()
          ..writeAsStringSync('name: bb_package_example\n');
      });

      final emptyVars = {
        'org_name': 'com.example.test',
        'platforms': {
          'android': false,
          'ios': false,
          'web': false,
          'linux': false,
          'macos': false,
          'windows': false,
        },
      };

      await ProcessOverrides.runZoned(
        () => template.onGenerateComplete(
          logger,
          outputDir,
          blueBirdGenerator,
          emptyVars,
        ),
        runProcess: process.run,
      );

      verify(() => logger.info(any())).called(greaterThan(0));
    });
  });
}
