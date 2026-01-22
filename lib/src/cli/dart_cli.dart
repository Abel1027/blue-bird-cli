part of 'cli.dart';

/// Dart CLI
class Dart {
  /// Determine whether dart is installed.
  static Future<bool> installed({
    required Logger logger,
  }) async {
    try {
      await _Cmd.run('dart', ['--version'], logger: logger);
      return true;
    } on Exception catch (_) {
      return false;
    }
  }

  /// Generate files
  /// (`dart run build_runner build --delete-conflicting-outputs`).
  static Future<void> generate({
    required Logger logger,
    String cwd = '.',
    bool recursive = false,
  }) async {
    await _runCommandOnPubspecPackage(
      logger: logger,
      cmd: 'dart',
      args: ['run', 'build_runner', 'build', '--delete-conflicting-outputs'],
      cwd: cwd,
      recursive: recursive,
    );
  }

    /// Apply all fixes (`dart fix --apply`).
  static Future<void> applyFixes({
    required Logger logger,
    String cwd = '.',
    bool recursive = false,
  }) async {
    await _runCommandOnPubspecPackage(
      logger: logger,
      cmd: 'dart',
      args: ['fix', '--apply'],
      cwd: cwd,
      recursive: recursive,
    );
  }

    /// Format (`dart format .`).
  static Future<void> format({
    required Logger logger,
    String cwd = '.',
    bool recursive = false,
  }) async {
    await _runCommandOnPubspecPackage(
      logger: logger,
      cmd: 'dart',
      args: ['format', '.'],
      cwd: cwd,
      recursive: recursive,
    );
  }

  /// Run command on packages with a pubspec.yaml.
  static Future<void> _runCommandOnPubspecPackage({
    required Logger logger,
    required String cmd,
    required List<String> args,
    String cwd = '.',
    bool recursive = false,
  }) async {
    if (!recursive) {
      final pubspec = File(p.join(cwd, 'pubspec.yaml'));
      if (!pubspec.existsSync()) throw PubspecNotFound();

      await _Cmd.run(cmd, args, workingDirectory: cwd, logger: logger);
      return;
    }

    final processes = _Cmd.runWhere(
      run: (entity) => _Cmd.run(
        cmd,
        args,
        workingDirectory: entity.parent.path,
        logger: logger,
      ),
      where: _isPubspec,
      cwd: cwd,
    );

    if (processes.isEmpty) throw PubspecNotFound();

    await Future.wait<void>(processes);
  }

  /// Activate global package.
  static Future<bool> activate({
    required Logger logger,
    required String package,
  }) async {
    try {
      await _Cmd.run(
        'dart',
        ['pub global activate $package'],
        logger: logger,
      );
      return true;
    } on Exception catch (_) {
      return false;
    }
  }
}
