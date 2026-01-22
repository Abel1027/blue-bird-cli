import 'dart:io';

import 'package:blue_bird_cli/src/cli/cli.dart';
import 'package:blue_bird_cli/src/commands/create/templates/blue_bird_flutter_lite/blue_bird_flutter_lite_template.dart';
import 'package:blue_bird_cli/src/utils/blue_bird_mason_generator.dart';
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

void main() {
  group('FlutterLiteTemplate', () {
    late Logger logger;
    late Progress progress;
    late BlueBirdMasonGenerator generator;
    late Directory tempDir;
    late _TestProcess process;

    setUp(() {
      logger = _MockLogger();
      progress = _MockProgress();
      generator = _MockBlueBirdMasonGenerator();

      when(() => logger.progress(any())).thenReturn(progress);
      when(() => logger.info(any())).thenReturn(null);
      when(() => progress.complete(any())).thenReturn(null);

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
      expect(FlutterLiteTemplate(), isNotNull);
    });

    test('has correct name', () {
      final template = FlutterLiteTemplate();
      expect(template.name, 'flutter_lite');
    });

    test('has correct help text', () {
      final template = FlutterLiteTemplate();
      expect(template.help, 'Generate a Blue Bird Flutter lite app.');
    });

    test('onGenerateComplete runs all steps', () async {
      final template = FlutterLiteTemplate();
      final outputDir = Directory(p.join(tempDir.path, 'test_app'))
        ..createSync();
      File(p.join(outputDir.path, 'pubspec.yaml'))
        ..createSync()
        ..writeAsStringSync('name: test_app\n');

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
        () => template.onGenerateComplete(logger, outputDir, generator, vars),
        runProcess: process.run,
      );

      verify(() => logger.progress(any())).called(greaterThan(0));
      verify(() => logger.info(any())).called(greaterThan(0));
    });

    test('onGenerateComplete works with null vars', () async {
      final template = FlutterLiteTemplate();
      final outputDir = Directory(p.join(tempDir.path, 'test_app'))
        ..createSync();
      File(p.join(outputDir.path, 'pubspec.yaml'))
        ..createSync()
        ..writeAsStringSync('name: test_app\n');

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
          generator,
          emptyVars,
        ),
        runProcess: process.run,
      );

      verify(() => logger.info(any())).called(greaterThan(0));
    });
  });
}
