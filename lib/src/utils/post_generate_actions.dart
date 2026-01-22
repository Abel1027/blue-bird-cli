import 'package:blue_bird_cli/src/cli/cli.dart';
import 'package:mason/mason.dart';
import 'package:path/path.dart' as p;
import 'package:universal_io/io.dart';

/// Runs `flutter packages get` in the [outputDir].
Future<void> installFlutterPackages(
  Logger logger,
  Directory outputDir, {
  bool recursive = false,
}) async {
  final isFlutterInstalled = await Flutter.installed(logger: logger);
  if (isFlutterInstalled) {
    await Flutter.packagesGet(
      cwd: outputDir.path,
      recursive: recursive,
      logger: logger,
    );
  }
}

/// Runs `dart fix --apply` in the [outputDir].
Future<void> applyDartFixes(
  Logger logger,
  Directory outputDir, {
  bool recursive = false,
}) async {
  final isDartInstalled = await Dart.installed(logger: logger);
  if (isDartInstalled) {
    final applyFixesProgress = logger.progress(
      'Running "dart fix --apply" in ${outputDir.path}',
    );
    await Dart.applyFixes(
      cwd: outputDir.path,
      recursive: recursive,
      logger: logger,
    );
    applyFixesProgress.complete();
  }
}

/// Runs `dart format .` in the [outputDir].
Future<void> format(
  Logger logger,
  Directory outputDir, {
  bool recursive = false,
}) async {
  final isDartInstalled = await Dart.installed(logger: logger);
  if (isDartInstalled) {
    final formatProgress = logger.progress(
      'Running "dart format ." in ${outputDir.path}',
    );
    await Dart.format(
      cwd: outputDir.path,
      recursive: recursive,
      logger: logger,
    );
    formatProgress.complete();
  }
}

/// Runs `dart run build_runner build --delete-conflicting-outputs`
/// in the [outputDir].
Future<void> generate(
  Logger logger,
  Directory outputDir,
) async {
  final isFlutterInstalled = await Flutter.installed(logger: logger);
  if (isFlutterInstalled) {
    final generateProgress = logger.progress(
      'Running "dart run build_runner build --delete-conflicting-outputs" '
      'in ${outputDir.path}',
    );
    await Dart.generate(cwd: outputDir.path, logger: logger);
    generateProgress.complete();
  }
}

/// Runs `flutter gen-l10n` in the [l10nDir].
Future<void> generateL10n(
  Logger logger,
  Directory l10nDir,
) async {
  final isFlutterInstalled = await Flutter.installed(logger: logger);
  if (isFlutterInstalled) {
    final generateL10nProgress = logger.progress(
      'Running "flutter gen-l10n" in ${l10nDir.path}',
    );
    await Flutter.l10nGen(cwd: l10nDir.path, logger: logger);
    generateL10nProgress.complete();
  }
}

/// Runs `flutter create .` in the [outputDir].
Future<void> create(
  Logger logger,
  Directory outputDir, {
  required String organization,
  required bool android,
  required bool ios,
  required bool web,
  required bool linux,
  required bool macos,
  required bool windows,
}) async {
  final isFlutterInstalled = await Flutter.installed(logger: logger);
  if (isFlutterInstalled) {
    final createProgress = logger.progress(
      'Running "flutter create" in ${outputDir.path}',
    );
    await Flutter.create(
      logger: logger,
      organization: organization,
      android: android,
      ios: ios,
      web: web,
      linux: linux,
      macos: macos,
      windows: windows,
      cwd: outputDir.path,
    );
    createProgress.complete();
  }
}

/// Adds the [outputDir] package to the parent workspace pubspec.yaml.
///
/// Throws [NoParentWorkspaceException] if no parent pubspec with workspace
/// configuration is found.
Future<void> addToParentWorkspace(
  Logger logger,
  Directory outputDir,
) async {
  final addToWorkspaceProgress = logger.progress(
    'Adding package to parent workspace',
  );

  try {
    // Find parent directory with pubspec.yaml containing workspace config
    Directory? searchDir = outputDir.parent;
    File? parentPubspec;

    while (searchDir != null && searchDir.path != searchDir.parent.path) {
      final pubspecFile = File(p.join(searchDir.path, 'pubspec.yaml'));
      if (pubspecFile.existsSync()) {
        final content = await pubspecFile.readAsString();
        if (content.contains(RegExp('^workspace:', multiLine: true))) {
          parentPubspec = pubspecFile;
          break;
        }
      }
      searchDir = searchDir.parent;
    }

    if (parentPubspec == null) {
      addToWorkspaceProgress.fail();
      throw const NoParentWorkspaceException();
    }

    // Read and parse parent pubspec
    final pubspecContent = await parentPubspec.readAsString();
    final lines = pubspecContent.split('\n');

    // Find workspace section
    var workspaceIndex = -1;
    for (var i = 0; i < lines.length; i++) {
      if (lines[i].trim().startsWith('workspace:')) {
        workspaceIndex = i;
        break;
      }
    }

    if (workspaceIndex == -1) {
      addToWorkspaceProgress.fail();
      throw const NoParentWorkspaceException();
    }

    // Get the package relative path from parent
    final parentDir = parentPubspec.parent;
    final relativePath = p.relative(outputDir.path, from: parentDir.path);

    // Check if package already exists in workspace
    for (var i = workspaceIndex + 1; i < lines.length; i++) {
      final line = lines[i].trim();
      if (line.isEmpty || !line.startsWith('-')) break;
      final existingPath = line.replaceFirst('-', '').trim();
      if (existingPath == relativePath ||
          existingPath == p.basename(outputDir.path)) {
        addToWorkspaceProgress.complete('Package already in workspace');
        return;
      }
    }

    // Add package to workspace list
    // Find the last item in the workspace list
    var insertIndex = workspaceIndex + 1;
    for (var i = workspaceIndex + 1; i < lines.length; i++) {
      final line = lines[i].trim();
      if (line.isEmpty || !line.startsWith('-')) break;
      insertIndex = i + 1;
    }

    lines.insert(insertIndex, '  - $relativePath');

    // Write back to file
    await parentPubspec.writeAsString(lines.join('\n'));
    addToWorkspaceProgress.complete();
  } catch (e) {
    addToWorkspaceProgress.fail();
    rethrow;
  }
}

/// Adds the package to the parent project's dependencies section.
///
/// Throws [NoParentWorkspaceException] if no parent pubspec with workspace
/// configuration is found.
Future<void> addToParentDependencies(
  Logger logger,
  Directory outputDir,
) async {
  final addToDepsProgress = logger.progress(
    'Adding package to parent dependencies',
  );

  try {
    // Find parent directory with pubspec.yaml containing workspace config
    Directory? searchDir = outputDir.parent;
    File? parentPubspec;

    while (searchDir != null && searchDir.path != searchDir.parent.path) {
      final pubspecFile = File(p.join(searchDir.path, 'pubspec.yaml'));
      if (pubspecFile.existsSync()) {
        final content = await pubspecFile.readAsString();
        if (content.contains(RegExp('^workspace:', multiLine: true))) {
          parentPubspec = pubspecFile;
          break;
        }
      }
      searchDir = searchDir.parent;
    }

    if (parentPubspec == null) {
      addToDepsProgress.fail();
      throw const NoParentWorkspaceException();
    }

    // Get the package name and relative path
    final packageName = p.basename(outputDir.path);
    final parentDir = parentPubspec.parent;
    final relativePath = p.relative(outputDir.path, from: parentDir.path);

    // Read and parse parent pubspec
    final pubspecContent = await parentPubspec.readAsString();
    final lines = pubspecContent.split('\n');

    // Check if package already exists in dependencies
    if (pubspecContent.contains(RegExp('^  $packageName:', multiLine: true))) {
      addToDepsProgress.complete('Package already in dependencies');
      return;
    }

    // Find dependencies section
    var dependenciesIndex = -1;
    for (var i = 0; i < lines.length; i++) {
      if (lines[i].trim().startsWith('dependencies:')) {
        dependenciesIndex = i;
        break;
      }
    }

    if (dependenciesIndex == -1) {
      addToDepsProgress.fail();
      throw Exception('No dependencies section found in parent pubspec.yaml');
    }

    // Find where to insert the new dependency (after other path dependencies)
    var insertIndex = dependenciesIndex + 1;
    var foundPathDeps = false;

    for (var i = dependenciesIndex + 1; i < lines.length; i++) {
      final line = lines[i];
      final trimmed = line.trim();

      // Stop if we hit another section
      if (trimmed.isNotEmpty &&
          !trimmed.startsWith('#') &&
          trimmed.endsWith(':') &&
          !trimmed.contains('  ')) {
        break;
      }

      // Check if this is a path dependency
      if (i + 1 < lines.length && lines[i + 1].trim().startsWith('path:')) {
        foundPathDeps = true;
        insertIndex = i + 2;
      }
    }

    // If no path dependencies found, insert after dependencies:
    if (!foundPathDeps) {
      insertIndex = dependenciesIndex + 1;
    }

    // Insert the new dependency
    lines
      ..insert(insertIndex, '  $packageName:')
      ..insert(insertIndex + 1, '    path: $relativePath');

    // Write back to file
    await parentPubspec.writeAsString(lines.join('\n'));
    addToDepsProgress.complete();
  } catch (e) {
    addToDepsProgress.fail();
    rethrow;
  }
}

/// Adds the package DI configuration to the parent project's injection file.
///
/// Throws [NoParentInjectionException] if no parent injection file is found.
Future<void> addToParentDIConfiguration(
  Logger logger,
  Directory outputDir,
) async {
  final addToDIProgress = logger.progress(
    'Adding package to parent DI configuration',
  );

  try {
    // Find parent project directory with lib/src/config/di/injection.dart
    Directory? searchDir = outputDir.parent;
    File? parentInjectionFile;

    while (searchDir != null && searchDir.path != searchDir.parent.path) {
      final injectionFile = File(
        p.join(searchDir.path, 'lib', 'src', 'config', 'di', 'injection.dart'),
      );
      if (injectionFile.existsSync()) {
        parentInjectionFile = injectionFile;
        break;
      }
      searchDir = searchDir.parent;
    }

    if (parentInjectionFile == null) {
      addToDIProgress.fail();
      throw const NoParentInjectionException();
    }

    // Get the package name and create the function name
    final packageName = p.basename(outputDir.path);
    final pascalCaseName = _toPascalCase(packageName);
    final configFunctionName = 'configure${pascalCaseName}Dependencies';

    // Read the injection file
    final injectionContent = await parentInjectionFile.readAsString();
    final lines = injectionContent.split('\n');

    // Check if already configured
    if (injectionContent.contains(configFunctionName)) {
      addToDIProgress.complete('Package DI already configured');
      return;
    }

    // Find the import section and add the new import
    var lastImportIndex = -1;
    for (var i = 0; i < lines.length; i++) {
      if (lines[i].trim().startsWith('import ')) {
        lastImportIndex = i;
      }
    }

    if (lastImportIndex != -1) {
      lines.insert(
        lastImportIndex + 1,
        "import 'package:$packageName/$packageName.dart';",
      );
    }

    // Find the commented example line and add the call after it
    var exampleCommentIndex = -1;
    for (var i = 0; i < lines.length; i++) {
      if (lines[i].contains('configureYourPackageDependencies')) {
        exampleCommentIndex = i;
        break;
      }
    }

    if (exampleCommentIndex != -1) {
      lines.insert(exampleCommentIndex + 1, '  $configFunctionName(getIt);');
    } else {
      // If no example comment found, find the closing brace of the function
      for (var i = lines.length - 1; i >= 0; i--) {
        if (lines[i].trim() == '}' &&
            i > 0 &&
            !lines[i - 1].trim().startsWith('//')) {
          lines.insert(i, '  $configFunctionName(getIt);');
          break;
        }
      }
    }

    // Write back to file
    await parentInjectionFile.writeAsString(lines.join('\n'));
    addToDIProgress.complete();
  } catch (e) {
    addToDIProgress.fail();
    rethrow;
  }
}

/// Converts a snake_case string to PascalCase.
String _toPascalCase(String snakeCase) {
  return snakeCase
      .split('_')
      .map((word) => word[0].toUpperCase() + word.substring(1))
      .join();
}

/// Exception thrown when no parent workspace is found.
class NoParentWorkspaceException implements Exception {
  /// Creates a [NoParentWorkspaceException].
  const NoParentWorkspaceException();

  @override
  String toString() =>
      'No parent pubspec.yaml with workspace configuration found.';
}

/// Exception thrown when no parent injection file is found.
class NoParentInjectionException implements Exception {
  /// Creates a [NoParentInjectionException].
  const NoParentInjectionException();

  @override
  String toString() => 'No parent lib/src/config/di/injection.dart file found.';
}
