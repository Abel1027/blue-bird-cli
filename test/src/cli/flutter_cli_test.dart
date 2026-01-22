import 'dart:async';

import 'package:blue_bird_cli/src/cli/cli.dart';
import 'package:mason/mason.dart';
import 'package:mocktail/mocktail.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import 'package:universal_io/io.dart';

const _pubspec = '''
name: example
environment:
  sdk: ">=2.13.0 <3.0.0"

dev_dependencies:
  test: any''';

const _unreachableGitUrlPubspec = '''
name: example
environment:
  sdk: ">=2.13.0 <3.0.0"

dev_dependencies:
  very_good_analysis:
    git:
      url: https://github.com/verygoodopensource/_very_good_analysis''';

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

class _MockLogger extends Mock implements Logger {}

class _MockProgress extends Mock implements Progress {}

class _FakeGeneratorTarget extends Fake implements GeneratorTarget {}

void main() {
  group('Flutter', () {
    late _TestProcess process;
    late Logger logger;
    late Progress progress;

    setUpAll(() {
      registerFallbackValue(_FakeGeneratorTarget());
      registerFallbackValue(FileConflictResolution.prompt);
    });

    setUp(() {
      logger = _MockLogger();
      progress = _MockProgress();
      when(() => logger.progress(any())).thenReturn(progress);

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

    group('.installed', () {
      test('returns true when flutter is installed', () async {
        when(
          () => process.run(
            'flutter',
            ['--version'],
            runInShell: any(named: 'runInShell'),
            workingDirectory: any(named: 'workingDirectory'),
          ),
        ).thenAnswer(
          (_) async => ProcessResult(0, ExitCode.success.code, '', ''),
        );

        final result = await ProcessOverrides.runZoned(
          () => Flutter.installed(logger: logger),
          runProcess: process.run,
        );

        expect(result, isTrue);
      });

      test('returns false when flutter is not installed', () async {
        when(
          () => process.run(
            'flutter',
            ['--version'],
            runInShell: any(named: 'runInShell'),
            workingDirectory: any(named: 'workingDirectory'),
          ),
        ).thenThrow(Exception('flutter not found'));

        final result = await ProcessOverrides.runZoned(
          () => Flutter.installed(logger: logger),
          runProcess: process.run,
        );

        expect(result, isFalse);
      });
    });

    group('.packagesGet', () {
      test('throws when there is no pubspec.yaml', () {
        ProcessOverrides.runZoned(
          () => expectLater(
            Flutter.packagesGet(cwd: Directory.systemTemp.path, logger: logger),
            throwsA(isA<PubspecNotFound>()),
          ),
          runProcess: process.run,
        );
      });

      test('throws when process fails', () {
        when(
          () => process.run(
            'flutter',
            any(),
            runInShell: any(named: 'runInShell'),
            workingDirectory: any(named: 'workingDirectory'),
          ),
        ).thenAnswer(
          (_) async => ProcessResult(0, ExitCode.software.code, '', ''),
        );

        ProcessOverrides.runZoned(
          () => expectLater(
            Flutter.packagesGet(cwd: Directory.systemTemp.path, logger: logger),
            throwsException,
          ),
          runProcess: process.run,
        );
      });

      test('throws when there is an unreachable git url', () {
        final directory = Directory.systemTemp.createTempSync();
        File(p.join(directory.path, 'pubspec.yaml'))
            .writeAsStringSync(_unreachableGitUrlPubspec);

        when(
          () => process.run(
            'git',
            any(that: contains('ls-remote')),
            runInShell: any(named: 'runInShell'),
            workingDirectory: any(named: 'workingDirectory'),
          ),
        ).thenAnswer(
          (_) async => ProcessResult(0, ExitCode.software.code, '', ''),
        );

        ProcessOverrides.runZoned(
          () => expectLater(
            () => Flutter.packagesGet(cwd: directory.path, logger: logger),
            throwsA(isA<UnreachableGitDependency>()),
          ),
          runProcess: process.run,
        );
      });

      test('completes when the process succeeds', () {
        ProcessOverrides.runZoned(
          () => expectLater(Flutter.packagesGet(logger: logger), completes),
          runProcess: process.run,
        );
      });

      test('throws when there is no pubspec.yaml (recursive)', () {
        ProcessOverrides.runZoned(
          () => expectLater(
            Flutter.packagesGet(
              cwd: Directory.systemTemp.createTempSync().path,
              recursive: true,
              logger: logger,
            ),
            throwsA(isA<PubspecNotFound>()),
          ),
          runProcess: process.run,
        );
      });

      test('completes when there is a pubspec.yaml (recursive)', () {
        final directory = Directory.systemTemp.createTempSync();
        final nestedDirectory = Directory(p.join(directory.path, 'test'))
          ..createSync();
        File(p.join(nestedDirectory.path, 'pubspec.yaml'))
            .writeAsStringSync(_pubspec);

        ProcessOverrides.runZoned(
          () => expectLater(
            Flutter.packagesGet(
              cwd: directory.path,
              recursive: true,
              logger: logger,
            ),
            completes,
          ),
          runProcess: process.run,
        );
      });
    });

    group('.pubGet', () {
      test('throws when there is no pubspec.yaml', () {
        ProcessOverrides.runZoned(
          () => expectLater(
            Flutter.pubGet(cwd: Directory.systemTemp.path, logger: logger),
            throwsA(isA<PubspecNotFound>()),
          ),
          runProcess: process.run,
        );
      });

      test('throws when process fails', () {
        when(
          () => process.run(
            'flutter',
            any(),
            runInShell: any(named: 'runInShell'),
            workingDirectory: any(named: 'workingDirectory'),
          ),
        ).thenAnswer(
          (_) async => ProcessResult(0, ExitCode.software.code, '', ''),
        );
        ProcessOverrides.runZoned(
          () => expectLater(
            Flutter.pubGet(cwd: Directory.systemTemp.path, logger: logger),
            throwsException,
          ),
          runProcess: process.run,
        );
      });

      test('completes when the process succeeds', () {
        ProcessOverrides.runZoned(
          () => expectLater(Flutter.pubGet(logger: logger), completes),
          runProcess: process.run,
        );
      });

      test('completes when the process succeeds (recursive)', () {
        ProcessOverrides.runZoned(
          () => expectLater(
            Flutter.pubGet(recursive: true, logger: logger),
            completes,
          ),
          runProcess: process.run,
        );
      });

      test('throws when process fails', () {
        when(
          () => process.run(
            any(),
            any(),
            runInShell: any(named: 'runInShell'),
            workingDirectory: any(named: 'workingDirectory'),
          ),
        ).thenAnswer(
          (_) async => ProcessResult(0, ExitCode.software.code, '', ''),
        );
        ProcessOverrides.runZoned(
          () => expectLater(Flutter.pubGet(logger: logger), throwsException),
          runProcess: process.run,
        );
      });

      test('throws when process fails (recursive)', () {
        when(
          () => process.run(
            any(),
            any(),
            runInShell: any(named: 'runInShell'),
            workingDirectory: any(named: 'workingDirectory'),
          ),
        ).thenAnswer(
          (_) async => ProcessResult(0, ExitCode.software.code, '', ''),
        );
        ProcessOverrides.runZoned(
          () => expectLater(
            Flutter.pubGet(recursive: true, logger: logger),
            throwsException,
          ),
          runProcess: process.run,
        );
      });
    });

    group('.l10nGen', () {
      test('throws when there is no pubspec.yaml', () {
        ProcessOverrides.runZoned(
          () => expectLater(
            Flutter.l10nGen(cwd: Directory.systemTemp.path, logger: logger),
            throwsA(isA<PubspecNotFound>()),
          ),
          runProcess: process.run,
        );
      });

      test('throws when process fails', () {
        when(
          () => process.run(
            'flutter',
            any(),
            runInShell: any(named: 'runInShell'),
            workingDirectory: any(named: 'workingDirectory'),
          ),
        ).thenAnswer(
          (_) async => ProcessResult(0, ExitCode.software.code, '', ''),
        );

        ProcessOverrides.runZoned(
          () => expectLater(
            Flutter.l10nGen(cwd: Directory.systemTemp.path, logger: logger),
            throwsException,
          ),
          runProcess: process.run,
        );
      });

      test('completes when the process succeeds', () {
        ProcessOverrides.runZoned(
          () => expectLater(Flutter.l10nGen(logger: logger), completes),
          runProcess: process.run,
        );
      });
    });

    group('.create', () {
      test('runs flutter create with org and platforms', () async {
        when(
          () => process.run(
            'flutter',
            any(),
            runInShell: any(named: 'runInShell'),
            workingDirectory: any(named: 'workingDirectory'),
          ),
        ).thenAnswer(
          (_) async => ProcessResult(0, ExitCode.success.code, '', ''),
        );

        await ProcessOverrides.runZoned(
          () => Flutter.create(
            organization: 'com.example',
            android: true,
            ios: true,
            web: false,
            linux: false,
            macos: false,
            windows: false,
            logger: logger,
          ),
          runProcess: process.run,
        );

        verify(
          () => process.run(
            'flutter',
            [
              'create',
              '.',
              '--org',
              'com.example',
              '--platforms=android,ios',
            ],
            runInShell: any(named: 'runInShell'),
            workingDirectory: any(named: 'workingDirectory'),
          ),
        ).called(1);
      });

      test('creates with all platforms enabled', () async {
        when(
          () => process.run(
            'flutter',
            any(),
            runInShell: any(named: 'runInShell'),
            workingDirectory: any(named: 'workingDirectory'),
          ),
        ).thenAnswer(
          (_) async => ProcessResult(0, ExitCode.success.code, '', ''),
        );

        await ProcessOverrides.runZoned(
          () => Flutter.create(
            organization: 'com.example',
            android: true,
            ios: true,
            web: true,
            linux: true,
            macos: true,
            windows: true,
            logger: logger,
          ),
          runProcess: process.run,
        );

        verify(
          () => process.run(
            'flutter',
            [
              'create',
              '.',
              '--org',
              'com.example',
              '--platforms=android,ios,web,linux,macos,windows',
            ],
            runInShell: any(named: 'runInShell'),
            workingDirectory: any(named: 'workingDirectory'),
          ),
        ).called(1);
      });

      test('creates with only web platform', () async {
        when(
          () => process.run(
            'flutter',
            any(),
            runInShell: any(named: 'runInShell'),
            workingDirectory: any(named: 'workingDirectory'),
          ),
        ).thenAnswer(
          (_) async => ProcessResult(0, ExitCode.success.code, '', ''),
        );

        await ProcessOverrides.runZoned(
          () => Flutter.create(
            organization: 'com.example',
            android: false,
            ios: false,
            web: true,
            linux: false,
            macos: false,
            windows: false,
            logger: logger,
          ),
          runProcess: process.run,
        );

        verify(
          () => process.run(
            'flutter',
            [
              'create',
              '.',
              '--org',
              'com.example',
              '--platforms=web',
            ],
            runInShell: any(named: 'runInShell'),
            workingDirectory: any(named: 'workingDirectory'),
          ),
        ).called(1);
      });

      test('creates with custom working directory', () async {
        when(
          () => process.run(
            'flutter',
            any(),
            runInShell: any(named: 'runInShell'),
            workingDirectory: any(named: 'workingDirectory'),
          ),
        ).thenAnswer(
          (_) async => ProcessResult(0, ExitCode.success.code, '', ''),
        );

        await ProcessOverrides.runZoned(
          () => Flutter.create(
            organization: 'com.example',
            android: true,
            ios: false,
            web: false,
            linux: false,
            macos: false,
            windows: false,
            cwd: '/custom/path',
            logger: logger,
          ),
          runProcess: process.run,
        );

        verify(
          () => process.run(
            'flutter',
            any(),
            runInShell: any(named: 'runInShell'),
            workingDirectory: '/custom/path',
          ),
        ).called(1);
      });

      test('throws when process fails', () {
        when(
          () => process.run(
            'flutter',
            any(),
            runInShell: any(named: 'runInShell'),
            workingDirectory: any(named: 'workingDirectory'),
          ),
        ).thenAnswer(
          (_) async => ProcessResult(0, ExitCode.software.code, '', 'Error'),
        );

        ProcessOverrides.runZoned(
          () => expectLater(
            Flutter.create(
              organization: 'com.example',
              android: true,
              ios: false,
              web: false,
              linux: false,
              macos: false,
              windows: false,
              logger: logger,
            ),
            throwsException,
          ),
          runProcess: process.run,
        );
      });
    });
  });
}
