part of 'cli.dart';

/// Thrown when `flutter packages get` or `flutter pub get`
/// is executed without a `pubspec.yaml`.
class PubspecNotFound implements Exception {}

/// A method which returns a [Future<MasonGenerator>] given a [MasonBundle].
typedef GeneratorBuilder = Future<MasonGenerator> Function(MasonBundle);

/// Flutter CLI
class Flutter {
  /// Determine whether flutter is installed.
  static Future<bool> installed({
    required Logger logger,
  }) async {
    try {
      await _Cmd.run('flutter', ['--version'], logger: logger);
      return true;
    } on Exception catch (_) {
      return false;
    }
  }

  /// Install flutter dependencies (`flutter packages get`).
  static Future<void> packagesGet({
    required Logger logger,
    String cwd = '.',
    bool recursive = false,
  }) async {
    await _runCommand(
      cmd: (cwd) async {
        final installProgress = logger.progress(
          'Running "flutter packages get" in $cwd',
        );

        try {
          await _verifyGitDependencies(cwd, logger: logger);
        } catch (_) {
          installProgress.fail();
          rethrow;
        }

        try {
          await _Cmd.run(
            'flutter',
            ['packages', 'get'],
            workingDirectory: cwd,
            logger: logger,
          );
        } finally {
          installProgress.complete();
        }
      },
      cwd: cwd,
      recursive: recursive,
    );
  }

  /// Install dart dependencies (`flutter pub get`).
  static Future<void> pubGet({
    required Logger logger,
    String cwd = '.',
    bool recursive = false,
  }) async {
    await _runCommand(
      cmd: (cwd) => _Cmd.run(
        'flutter',
        ['pub', 'get'],
        workingDirectory: cwd,
        logger: logger,
      ),
      cwd: cwd,
      recursive: recursive,
    );
  }

  /// Generate l10n files (`flutter gen-l10n`).
  static Future<void> l10nGen({
    required Logger logger,
    String cwd = '.',
    bool recursive = false,
  }) async {
    await _runCommand(
      cmd: (cwd) => _Cmd.run(
        'flutter',
        ['gen-l10n'],
        workingDirectory: cwd,
        logger: logger,
      ),
      cwd: cwd,
      recursive: recursive,
    );
  }

  /// Set up organization and platforms for a Flutter project.
  /// (`flutter create . --org <organization> --platforms=<platforms>`).
  static Future<void> create({
    required Logger logger,
    required String organization,
    required bool android,
    required bool ios,
    required bool web,
    required bool linux,
    required bool macos,
    required bool windows,
    String cwd = '.',
  }) async {
    final platforms = [
      if (android) 'android',
      if (ios) 'ios',
      if (web) 'web',
      if (linux) 'linux',
      if (macos) 'macos',
      if (windows) 'windows',
    ];

    if (platforms.isEmpty) {
      return;
    }

    final platformsString = platforms.join(',');

    await _Cmd.run(
      'flutter',
      ['create', '.', '--org', organization, '--platforms=$platformsString'],
      workingDirectory: cwd,
      logger: logger,
    );
  }
}

/// Ensures all git dependencies are reachable for the pubspec
/// located in the [cwd].
///
/// If any git dependencies are unreachable,
/// an [UnreachableGitDependency] is thrown.
Future<void> _verifyGitDependencies(
  String cwd, {
  required Logger logger,
}) async {
  final pubspec = Pubspec.parse(
    await File(p.join(cwd, 'pubspec.yaml')).readAsString(),
  );

  final dependencies = pubspec.dependencies;
  final devDependencies = pubspec.devDependencies;
  final dependencyOverrides = pubspec.dependencyOverrides;
  final gitDependencies = [
    ...dependencies.entries,
    ...devDependencies.entries,
    ...dependencyOverrides.entries,
  ]
      .where((entry) => entry.value is GitDependency)
      .map((entry) => entry.value)
      .cast<GitDependency>()
      .toList();

  await Future.wait(
    gitDependencies.map(
      (dependency) => Git.reachable(
        dependency.url,
        logger: logger,
      ),
    ),
  );
}

/// Run a command on directories with a `pubspec.yaml`.
Future<List<T>> _runCommand<T>({
  required Future<T> Function(String cwd) cmd,
  required String cwd,
  required bool recursive,
}) async {
  if (!recursive) {
    final pubspec = File(p.join(cwd, 'pubspec.yaml'));
    if (!pubspec.existsSync()) throw PubspecNotFound();

    return [await cmd(cwd)];
  }

  final processes = _Cmd.runWhere<T>(
    run: (entity) => cmd(entity.parent.path),
    where: _isPubspec,
    cwd: cwd,
  );

  if (processes.isEmpty) throw PubspecNotFound();

  final results = <T>[];
  for (final process in processes) {
    results.add(await process);
  }
  return results;
}
