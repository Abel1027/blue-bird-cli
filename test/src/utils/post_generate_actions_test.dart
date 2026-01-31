import 'dart:io';

import 'package:blue_bird_cli/src/cli/cli.dart';
import 'package:blue_bird_cli/src/utils/post_generate_actions.dart';
import 'package:mason/mason.dart';
import 'package:mocktail/mocktail.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

class _MockLogger extends Mock implements Logger {}

class _MockProgress extends Mock implements Progress {}

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
  group('PostGenerateActions', () {
    late Logger logger;
    late Progress progress;
    late Directory tempDir;
    late _TestProcess process;

    setUp(() {
      logger = _MockLogger();
      progress = _MockProgress();
      when(() => logger.progress(any())).thenReturn(progress);
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

    group('addToParentWorkspace', () {
      test('adds package to parent workspace', () async {
        final parentDir = Directory(p.join(tempDir.path, 'parent'))
          ..createSync();
        final parentPubspec = File(p.join(parentDir.path, 'pubspec.yaml'))
          ..writeAsStringSync('''
name: parent_project
workspace:
  - core
''');

        final packageDir = Directory(p.join(parentDir.path, 'test_package'))
          ..createSync();

        await addToParentWorkspace(logger, packageDir);

        final content = parentPubspec.readAsStringSync();
        expect(content, contains('- test_package'));
        verify(() => progress.complete()).called(1);
      });

      test('does not duplicate existing entry', () async {
        final parentDir = Directory(p.join(tempDir.path, 'parent'))
          ..createSync();
        final parentPubspec = File(p.join(parentDir.path, 'pubspec.yaml'))
          ..writeAsStringSync('''
name: parent_project
workspace:
  - test_package
''');

        final packageDir = Directory(p.join(parentDir.path, 'test_package'))
          ..createSync();

        await addToParentWorkspace(logger, packageDir);

        final content = parentPubspec.readAsStringSync();
        expect('- test_package'.allMatches(content).length, 1);
      });

      test('throws NoParentWorkspaceException when no parent found', () async {
        final isolatedDir = Directory(p.join(tempDir.path, 'isolated'))
          ..createSync();

        await expectLater(
          addToParentWorkspace(logger, isolatedDir),
          throwsA(isA<NoParentWorkspaceException>()),
        );
      });

      test('throws when parent has no workspace section', () async {
        final parentDir = Directory(p.join(tempDir.path, 'parent'))
          ..createSync();
        File(p.join(parentDir.path, 'pubspec.yaml'))
            .writeAsStringSync('name: parent_project\n');

        final packageDir = Directory(p.join(parentDir.path, 'test_package'))
          ..createSync();

        await expectLater(
          addToParentWorkspace(logger, packageDir),
          throwsA(isA<NoParentWorkspaceException>()),
        );
        verify(() => progress.fail()).called(greaterThanOrEqualTo(1));
      });

      test(
        'throws when parent has dependencies but no workspace section',
        () async {
          final parentDir = Directory(p.join(tempDir.path, 'parent_no_ws'))
            ..createSync();
          File(p.join(parentDir.path, 'pubspec.yaml')).writeAsStringSync('''
name: parent_project
dependencies:
  flutter:
    sdk: flutter
''');

          final packageDir = Directory(p.join(parentDir.path, 'test_package'))
            ..createSync();

          await expectLater(
            addToParentWorkspace(logger, packageDir),
            throwsA(isA<NoParentWorkspaceException>()),
          );
          verify(() => progress.fail()).called(greaterThanOrEqualTo(1));
        },
      );

      test(
        'throws when workspace is detected but cannot be parsed '
        '(CR-only newlines)',
        () async {
          final parentDir = Directory(p.join(tempDir.path, 'parent_cr'))
            ..createSync();
          File(p.join(parentDir.path, 'pubspec.yaml')).writeAsStringSync(
            'name: parent_project\rworkspace:\r  - core\r',
          );

          final packageDir = Directory(p.join(parentDir.path, 'test_package'))
            ..createSync();

          await expectLater(
            addToParentWorkspace(logger, packageDir),
            throwsA(isA<NoParentWorkspaceException>()),
          );
          verify(() => progress.fail()).called(greaterThanOrEqualTo(1));
        },
      );
    });

    group('addToParentDependencies', () {
      test('adds package to parent dependencies', () async {
        final parentDir = Directory(p.join(tempDir.path, 'parent'))
          ..createSync();
        final parentPubspec = File(p.join(parentDir.path, 'pubspec.yaml'))
          ..writeAsStringSync('''
name: parent_project
workspace:
  - core
dependencies:
  flutter:
    sdk: flutter
''');

        final packageDir = Directory(p.join(parentDir.path, 'test_package'))
          ..createSync();

        await addToParentDependencies(logger, packageDir);

        final content = parentPubspec.readAsStringSync();
        expect(content, contains('test_package:'));
        expect(content, contains('path: test_package'));
        verify(() => progress.complete()).called(1);
      });

      test('does not duplicate existing dependency', () async {
        final parentDir = Directory(p.join(tempDir.path, 'parent'))
          ..createSync();
        final parentPubspec = File(p.join(parentDir.path, 'pubspec.yaml'))
          ..writeAsStringSync('''
name: parent_project
workspace:
  - test_package
dependencies:
  test_package:
    path: test_package
''');

        final packageDir = Directory(p.join(parentDir.path, 'test_package'))
          ..createSync();

        await addToParentDependencies(logger, packageDir);

        final content = parentPubspec.readAsStringSync();
        expect('test_package:'.allMatches(content).length, 1);
      });

      test('throws NoParentWorkspaceException when no parent found', () async {
        final isolatedDir = Directory(p.join(tempDir.path, 'isolated'))
          ..createSync();

        await expectLater(
          addToParentDependencies(logger, isolatedDir),
          throwsA(isA<NoParentWorkspaceException>()),
        );
      });

      test('throws when no dependencies section', () async {
        final parentDir = Directory(p.join(tempDir.path, 'parent'))
          ..createSync();
        File(p.join(parentDir.path, 'pubspec.yaml')).writeAsStringSync('''
name: parent_project
workspace:
  - test_package
''');

        final packageDir = Directory(p.join(parentDir.path, 'test_package'))
          ..createSync();

        await expectLater(
          addToParentDependencies(logger, packageDir),
          throwsException,
        );
        verify(() => progress.fail()).called(greaterThanOrEqualTo(1));
      });

      test('inserts after existing path dependencies', () async {
        final parentDir = Directory(p.join(tempDir.path, 'parent'))
          ..createSync();
        final parentPubspec = File(p.join(parentDir.path, 'pubspec.yaml'))
          ..writeAsStringSync('''
name: parent_project
workspace:
  - core
dependencies:
  existing_package:
    path: ../existing
  flutter:
    sdk: flutter
''');

        final packageDir = Directory(p.join(parentDir.path, 'test_package'))
          ..createSync();

        await addToParentDependencies(logger, packageDir);

        final content = parentPubspec.readAsStringSync();
        expect(content, contains('test_package:'));
        expect(content, contains('path: test_package'));
        // Should be inserted somewhere in dependencies section
        expect(content.indexOf('test_package:'), greaterThan(0));
      });

      test('inserts after multiple path dependencies', () async {
        final parentDir = Directory(p.join(tempDir.path, 'parent_multi'))
          ..createSync();
        final parentPubspec = File(p.join(parentDir.path, 'pubspec.yaml'))
          ..writeAsStringSync('''
name: parent_project
workspace:
  - core
  - features
dependencies:
  core_package:
    path: core/core_package
  feature_a:
    path: features/feature_a
  feature_b:
    path: features/feature_b
  flutter:
    sdk: flutter
''');

        final packageDir = Directory(p.join(parentDir.path, 'test_package'))
          ..createSync();

        await addToParentDependencies(logger, packageDir);

        final content = parentPubspec.readAsStringSync();
        expect(content, contains('test_package:'));
        expect(content, contains('path: test_package'));
        // Verify the package was added to dependencies
        final lines = content.split('\n');
        final testPackageLineIndex =
            lines.indexWhere((line) => line.trim().startsWith('test_package:'));
        expect(testPackageLineIndex, greaterThan(0));
        // Verify it's in the dependencies section
        final depsIndex =
            lines.indexWhere((line) => line.trim() == 'dependencies:');
        expect(testPackageLineIndex, greaterThan(depsIndex));
      });

      test(
        'detects path dependencies and inserts after them',
        () async {
          final parentDir = Directory(p.join(tempDir.path, 'parent_path_deps'))
            ..createSync();
          final parentPubspec = File(p.join(parentDir.path, 'pubspec.yaml'))
            ..writeAsStringSync('''
name: parent_project
workspace:
  - core
dependencies:
  existing_package: # keep this line from looking like a section header
    path: ../existing
  flutter:
    sdk: flutter
''');

          final packageDir = Directory(p.join(parentDir.path, 'test_package'))
            ..createSync();

          await addToParentDependencies(logger, packageDir);

          final content = parentPubspec.readAsStringSync();
          expect(content, contains('test_package:'));
          expect(content, contains('path: test_package'));

          final existingIndex = content.indexOf('existing_package:');
          final insertedIndex = content.indexOf('test_package:');
          final flutterIndex = content.indexOf('flutter:');

          expect(existingIndex, greaterThanOrEqualTo(0));
          expect(insertedIndex, greaterThan(existingIndex));
          expect(flutterIndex, greaterThan(insertedIndex));
        },
      );
    });

    group('addToParentDIConfiguration', () {
      test('adds DI configuration to parent injection file', () async {
        final parentDir = Directory(p.join(tempDir.path, 'parent'))
          ..createSync();
        final libDir =
            Directory(p.join(parentDir.path, 'lib', 'src', 'config', 'di'))
              ..createSync(recursive: true);
        final injectionFile = File(p.join(libDir.path, 'injection.dart'))
          ..writeAsStringSync('''
import 'package:get_it/get_it.dart';

final getIt = GetIt.instance;

void configureDependencies() {
  // configureYourPackageDependencies(getIt);
}
''');

        final packageDir = Directory(p.join(parentDir.path, 'test_package'))
          ..createSync();

        await addToParentDIConfiguration(logger, packageDir);

        final content = injectionFile.readAsStringSync();
        expect(
          content,
          contains("import 'package:test_package/test_package.dart'"),
        );
        expect(content, contains('configureTestPackageDependencies(getIt);'));
        verify(() => progress.complete()).called(1);
      });

      test('does not duplicate existing import', () async {
        final parentDir = Directory(p.join(tempDir.path, 'parent'))
          ..createSync();
        final libDir =
            Directory(p.join(parentDir.path, 'lib', 'src', 'config', 'di'))
              ..createSync(recursive: true);
        final injectionFile = File(p.join(libDir.path, 'injection.dart'))
          ..writeAsStringSync('''
import 'package:get_it/get_it.dart';
import 'package:test_package/test_package.dart';

final getIt = GetIt.instance;

void configureDependencies() {
  configureTestPackageDependencies(getIt);
}
''');

        final packageDir = Directory(p.join(parentDir.path, 'test_package'))
          ..createSync();

        await addToParentDIConfiguration(logger, packageDir);

        final content = injectionFile.readAsStringSync();
        expect(
          "import 'package:test_package/test_package.dart'"
              .allMatches(content)
              .length,
          1,
        );
        expect(
          'configureTestPackageDependencies'.allMatches(content).length,
          1,
        );
      });

      test('throws NoParentInjectionException when not found', () async {
        final parentDir = Directory(p.join(tempDir.path, 'parent'))
          ..createSync();
        final packageDir = Directory(p.join(parentDir.path, 'test_package'))
          ..createSync();

        await expectLater(
          addToParentDIConfiguration(logger, packageDir),
          throwsA(isA<NoParentInjectionException>()),
        );
      });

      test('converts snake_case to PascalCase', () async {
        final parentDir = Directory(p.join(tempDir.path, 'parent'))
          ..createSync();
        final libDir =
            Directory(p.join(parentDir.path, 'lib', 'src', 'config', 'di'))
              ..createSync(recursive: true);
        final injectionFile = File(p.join(libDir.path, 'injection.dart'))
          ..writeAsStringSync('''
import 'package:get_it/get_it.dart';

final getIt = GetIt.instance;

void configureDependencies() {
  // configureYourPackageDependencies(getIt);
}
''');

        final packageDir = Directory(p.join(parentDir.path, 'my_cool_package'))
          ..createSync();

        await addToParentDIConfiguration(logger, packageDir);

        final content = injectionFile.readAsStringSync();
        expect(content, contains('configureMyCoolPackageDependencies(getIt);'));
      });

      test('adds config when no example comment exists', () async {
        final parentDir = Directory(p.join(tempDir.path, 'parent'))
          ..createSync();
        final libDir =
            Directory(p.join(parentDir.path, 'lib', 'src', 'config', 'di'))
              ..createSync(recursive: true);
        final injectionFile = File(p.join(libDir.path, 'injection.dart'))
          ..writeAsStringSync('''
import 'package:get_it/get_it.dart';

final getIt = GetIt.instance;

void configureDependencies() {
}
''');

        final packageDir = Directory(p.join(parentDir.path, 'test_package'))
          ..createSync();

        await addToParentDIConfiguration(logger, packageDir);

        final content = injectionFile.readAsStringSync();
        expect(
          content,
          contains("import 'package:test_package/test_package.dart'"),
        );
        expect(content, contains('configureTestPackageDependencies'));
      });
    });

    group('helper functions', () {
      test('installFlutterPackages executes', () async {
        final packageDir = Directory(p.join(tempDir.path, 'test_package'))
          ..createSync();
        File(p.join(packageDir.path, 'pubspec.yaml'))
          ..createSync()
          ..writeAsStringSync('name: test\n');

        await ProcessOverrides.runZoned(
          () => installFlutterPackages(logger, packageDir),
          runProcess: process.run,
        );

        verify(() => logger.progress(any())).called(greaterThan(0));
      });

      test('applyDartFixes executes', () async {
        final packageDir = Directory(p.join(tempDir.path, 'test_package'))
          ..createSync();
        File(p.join(packageDir.path, 'pubspec.yaml'))
          ..createSync()
          ..writeAsStringSync('name: test\n');

        await ProcessOverrides.runZoned(
          () => applyDartFixes(logger, packageDir),
          runProcess: process.run,
        );

        verify(() => logger.progress(any())).called(greaterThan(0));
      });

      test('format executes', () async {
        final packageDir = Directory(p.join(tempDir.path, 'test_package'))
          ..createSync();
        File(p.join(packageDir.path, 'pubspec.yaml'))
          ..createSync()
          ..writeAsStringSync('name: test\n');

        await ProcessOverrides.runZoned(
          () => format(logger, packageDir),
          runProcess: process.run,
        );

        verify(() => logger.progress(any())).called(greaterThan(0));
      });

      test('generate executes', () async {
        final packageDir = Directory(p.join(tempDir.path, 'test_package'))
          ..createSync();
        File(p.join(packageDir.path, 'pubspec.yaml'))
          ..createSync()
          ..writeAsStringSync('name: test\n');

        await ProcessOverrides.runZoned(
          () => generate(logger, packageDir),
          runProcess: process.run,
        );

        verify(() => logger.progress(any())).called(greaterThan(0));
      });

      test('generateL10n executes', () async {
        final l10nDir = Directory(p.join(tempDir.path, 'l10n'))..createSync();
        File(p.join(l10nDir.path, 'pubspec.yaml'))
          ..createSync()
          ..writeAsStringSync('name: test\n');

        await ProcessOverrides.runZoned(
          () => generateL10n(logger, l10nDir),
          runProcess: process.run,
        );

        verify(() => logger.progress(any())).called(greaterThan(0));
      });

      test('create executes', () async {
        final packageDir = Directory(p.join(tempDir.path, 'test_package'))
          ..createSync();

        await ProcessOverrides.runZoned(
          () => create(
            logger,
            packageDir,
            organization: 'com.example',
            android: true,
            ios: true,
            web: false,
            linux: false,
            macos: false,
            windows: false,
          ),
          runProcess: process.run,
        );

        verify(() => logger.progress(any())).called(greaterThan(0));
      });
    });

    group('exceptions', () {
      test('NoParentWorkspaceException has correct message', () {
        const exception = NoParentWorkspaceException();
        expect(
          exception.toString(),
          'No parent pubspec.yaml with workspace configuration found.',
        );
      });

      test('NoParentInjectionException has correct message', () {
        const exception = NoParentInjectionException();
        expect(
          exception.toString(),
          'No parent lib/src/config/di/injection.dart file found.',
        );
      });
    });
  });
}
