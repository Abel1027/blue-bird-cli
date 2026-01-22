import 'dart:async';

import 'package:blue_bird_cli/src/command_runner.dart';
import 'package:mason/mason.dart';
import 'package:mocktail/mocktail.dart';
import 'package:pub_updater/pub_updater.dart';

class MockLogger extends Mock implements Logger {}

class MockProgress extends Mock implements Progress {}

class MockPubUpdater extends Mock implements PubUpdater {}

void Function() _overridePrint(void Function(List<String>) fn) {
  return () {
    final printLogs = <String>[];
    final spec = ZoneSpecification(
      print: (_, __, ___, String msg) {
        printLogs.add(msg);
      },
    );

    return Zone.current
        .fork(specification: spec)
        .run<void>(() => fn(printLogs));
  };
}

void Function() withRunner(
  FutureOr<void> Function(
    BlueBirdCliCommandRunner commandRunner,
    Logger logger,
    PubUpdater pubUpdater,
    List<String> printLogs,
  ) runnerFn,
) {
  return _overridePrint((printLogs) async {
    final logger = MockLogger();
    final progress = MockProgress();
    final pubUpdater = MockPubUpdater();
    final progressLogs = <String>[];
    final commandRunner = BlueBirdCliCommandRunner(
      logger: logger,
      pubUpdater: pubUpdater,
    );

    when(() => progress.complete(any())).thenAnswer((answer) {
      final message = answer.positionalArguments.elementAt(0) as String?;
      if (message != null) progressLogs.add(message);
    });
    when(() => logger.progress(any())).thenReturn(progress);
    when(
      () => pubUpdater.isUpToDate(
        packageName: any(named: 'packageName'),
        currentVersion: any(named: 'currentVersion'),
      ),
    ).thenAnswer((_) => Future.value(true));
    when(
      () => pubUpdater.getLatestVersion(any()),
    ).thenAnswer((_) => Future.value('1.0.0'));

    await runnerFn(commandRunner, logger, pubUpdater, printLogs);
  });
}
