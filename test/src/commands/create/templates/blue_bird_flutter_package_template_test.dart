import 'dart:io';

import 'package:blue_bird_cli/src/cli/cli.dart';
import 'package:blue_bird_cli/src/commands/create/templates/blue_bird_flutter_package/blue_bird_flutter_package_template.dart';
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
  group('FlutterPackageTemplate', () {
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
      when(() => logger.err(any())).thenReturn(null);
      when(() => logger.warn(any())).thenReturn(null);
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
      expect(FlutterPackageTemplate(), isNotNull);
    });

    test('has correct name', () {
      final template = FlutterPackageTemplate();
      expect(template.name, 'flutter_package');
    });

    test('has correct help text', () {
      final template = FlutterPackageTemplate();
      expect(template.help, 'Generate a Blue Bird Flutter package.');
    });

    test('onGenerateComplete runs all steps with parent workspace', () async {
      final template = FlutterPackageTemplate();

      // Create parent workspace structure
      final parentDir = tempDir;
      File(p.join(parentDir.path, 'pubspec.yaml'))
        ..createSync()
        ..writeAsStringSync('''
name: parent_workspace
workspace:
  - core
dependencies:
  flutter:
    sdk: flutter
''');

      // Create DI injection file
      File(
        p.join(
          parentDir.path,
          'lib',
          'src',
          'config',
          'di',
          'injection.dart',
        ),
      )
        ..createSync(recursive: true)
        ..writeAsStringSync('''
import 'package:get_it/get_it.dart';

final getIt = GetIt.instance;

void configureDependencies() {
  // configureYourPackageDependencies(getIt);
}
''');

      final outputDir = Directory(p.join(parentDir.path, 'test_package'))
        ..createSync();
      File(p.join(outputDir.path, 'pubspec.yaml'))
        ..createSync()
        ..writeAsStringSync('name: test_package\n');

      await ProcessOverrides.runZoned(
        () => template.onGenerateComplete(logger, outputDir, generator, null),
        runProcess: process.run,
      );

      verify(() => logger.info(any())).called(greaterThan(0));
    });

    test('onGenerateComplete handles NoParentWorkspaceException', () async {
      final template = FlutterPackageTemplate();
      final outputDir = Directory(p.join(tempDir.path, 'test_package'))
        ..createSync();
      File(p.join(outputDir.path, 'pubspec.yaml'))
        ..createSync()
        ..writeAsStringSync('name: test_package\n');

      await ProcessOverrides.runZoned(
        () => template.onGenerateComplete(logger, outputDir, generator, null),
        runProcess: process.run,
      );

      verify(() => logger.err(any())).called(1);
      verifyNever(() => logger.info(any()));
    });

    test('onGenerateComplete handles NoParentInjectionException', () async {
      final template = FlutterPackageTemplate();

      // Create parent workspace structure without DI file
      final parentDir = tempDir;
      File(p.join(parentDir.path, 'pubspec.yaml'))
        ..createSync()
        ..writeAsStringSync('''
name: parent_workspace
workspace:
  - core
dependencies:
  flutter:
    sdk: flutter
''');

      final outputDir = Directory(p.join(parentDir.path, 'test_package'))
        ..createSync();
      File(p.join(outputDir.path, 'pubspec.yaml'))
        ..createSync()
        ..writeAsStringSync('name: test_package\n');

      await ProcessOverrides.runZoned(
        () => template.onGenerateComplete(logger, outputDir, generator, null),
        runProcess: process.run,
      );

      verify(() => logger.warn(any())).called(1);
      verify(() => logger.info(any())).called(greaterThan(0));
    });
  });
}
