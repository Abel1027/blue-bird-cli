import 'package:blue_bird_cli/src/cli/cli.dart';
import 'package:mason/mason.dart';
import 'package:mocktail/mocktail.dart';
import 'package:test/test.dart';
import 'package:universal_io/io.dart';

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

void main() {
  group('Dart', () {
    late _TestProcess process;
    late Logger logger;
    late Progress progress;

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
      test('returns true when dart is installed', () {
        ProcessOverrides.runZoned(
          () => expectLater(Dart.installed(logger: logger), completion(isTrue)),
          runProcess: process.run,
        );
      });

      test('returns false when dart is not installed', () {
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
          () =>
              expectLater(Dart.installed(logger: logger), completion(isFalse)),
          runProcess: process.run,
        );
      });
    });

    group('.applyFixes', () {
      test('completes normally', () {
        ProcessOverrides.runZoned(
          () => expectLater(Dart.applyFixes(logger: logger), completes),
        );
      });

      test('completes normally using recursion', () {
        ProcessOverrides.runZoned(
          () => expectLater(
            Dart.applyFixes(logger: logger, recursive: true),
            completes,
          ),
          runProcess: process.run,
        );
      });
    });

    group('.generate', () {
      test('completes normally', () {
        ProcessOverrides.runZoned(
          () => expectLater(Dart.generate(logger: logger), completes),
          runProcess: process.run,
        );
      });

      test('completes normally using recursion', () {
        ProcessOverrides.runZoned(
          () => expectLater(
            Dart.generate(logger: logger, recursive: true),
            completes,
          ),
          runProcess: process.run,
        );
      });

      test('throws PubspecNotFound when no pubspec exists', () {
        final tempDir = Directory.systemTemp.createTempSync();
        ProcessOverrides.runZoned(
          () => expectLater(
            Dart.generate(logger: logger, cwd: tempDir.path),
            throwsA(isA<PubspecNotFound>()),
          ),
          runProcess: process.run,
        );
      });

      test('throws PubspecNotFound when recursive and no pubspec exists', () {
        final tempDir = Directory.systemTemp.createTempSync();
        ProcessOverrides.runZoned(
          () => expectLater(
            Dart.generate(logger: logger, cwd: tempDir.path, recursive: true),
            throwsA(isA<PubspecNotFound>()),
          ),
          runProcess: process.run,
        );
      });
    });

    group('.format', () {
      test('completes normally', () {
        ProcessOverrides.runZoned(
          () => expectLater(Dart.format(logger: logger), completes),
          runProcess: process.run,
        );
      });

      test('completes normally using recursion', () {
        ProcessOverrides.runZoned(
          () => expectLater(
            Dart.format(logger: logger, recursive: true),
            completes,
          ),
          runProcess: process.run,
        );
      });

      test('throws PubspecNotFound when no pubspec exists', () {
        final tempDir = Directory.systemTemp.createTempSync();
        ProcessOverrides.runZoned(
          () => expectLater(
            Dart.format(logger: logger, cwd: tempDir.path),
            throwsA(isA<PubspecNotFound>()),
          ),
          runProcess: process.run,
        );
      });

      test('throws PubspecNotFound when recursive and no pubspec exists', () {
        final tempDir = Directory.systemTemp.createTempSync();
        ProcessOverrides.runZoned(
          () => expectLater(
            Dart.format(logger: logger, cwd: tempDir.path, recursive: true),
            throwsA(isA<PubspecNotFound>()),
          ),
          runProcess: process.run,
        );
      });
    });

    group('.activate', () {
      test('returns true when activation succeeds', () {
        ProcessOverrides.runZoned(
          () => expectLater(
            Dart.activate(logger: logger, package: 'mason_cli'),
            completion(isTrue),
          ),
          runProcess: process.run,
        );
      });

      test('returns false when activation fails', () {
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
            Dart.activate(logger: logger, package: 'invalid_package'),
            completion(isFalse),
          ),
          runProcess: process.run,
        );
      });
    });
  });
}
