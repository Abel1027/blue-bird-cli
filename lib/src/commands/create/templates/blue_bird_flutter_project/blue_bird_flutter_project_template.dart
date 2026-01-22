import 'package:blue_bird_cli/src/commands/create/templates/templates.dart';
import 'package:blue_bird_cli/src/utils/constant.dart';
import 'package:blue_bird_cli/src/utils/project_config.dart';
import 'package:blue_bird_cli/src/utils/utils.dart';
import 'package:mason/mason.dart';
import 'package:path/path.dart' as path;
import 'package:universal_io/io.dart';

/// {@template flutter_project_template}
/// A Flutter project template.
/// {@endtemplate}
class FlutterProjectTemplate extends Template {
  /// {@macro flutter_project_template}
  FlutterProjectTemplate()
      : super(
          name: 'flutter_project',
          bundle: blueBirdFlutterProjectBundle,
          help: 'Generate a Blue Bird Flutter project.',
        );

  @override
  Future<void> onGenerateComplete(
    Logger logger,
    Directory outputDir,
    BlueBirdMasonGenerator blueBirdMasonGenerator,
    Map<String, dynamic>? vars,
  ) async {
    await installFlutterPackages(logger, outputDir, recursive: true);
    await _createExamplePackage(logger, blueBirdMasonGenerator, outputDir);
    await generate(logger, outputDir);
    await applyDartFixes(logger, outputDir);
    await format(logger, outputDir, recursive: true);
    final projectConfig = ProjectConfig.fromMap(vars ?? {});
    await create(
      logger,
      outputDir,
      organization: projectConfig.orgName,
      android: projectConfig.platforms.android,
      ios: projectConfig.platforms.ios,
      web: projectConfig.platforms.web,
      linux: projectConfig.platforms.linux,
      macos: projectConfig.platforms.macos,
      windows: projectConfig.platforms.windows,
    );
    _logSummary(logger);
  }

  void _logSummary(Logger logger) {
    logger
      ..info('\n')
      ..created(
        'You have set up a Blue Bird Flutter project... 🐣',
      )
      ..info('\n');
  }

  Future<void> _createExamplePackage(
    Logger logger,
    BlueBirdMasonGenerator blueBirdMasonGenerator,
    Directory projectDir,
  ) async {
    final template = FlutterPackageTemplate();
    const projectName = 'bb_package_example';
    final vars = {
      'project_name': projectName,
      'project_description': Constant.projectDescription,
    };
    final directory = Directory(path.join(projectDir.path, 'packages'));
    final target = DirectoryGeneratorTarget(directory);

    await blueBirdMasonGenerator.generate(
      template: template,
      vars: vars,
      target: target,
    );

    await template.onGenerateComplete(
      logger,
      Directory(path.join(target.dir.path, projectName)),
      blueBirdMasonGenerator,
      null,
    );
  }
}
