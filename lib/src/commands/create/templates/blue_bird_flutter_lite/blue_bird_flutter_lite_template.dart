import 'package:blue_bird_cli/src/commands/create/templates/templates.dart';
import 'package:blue_bird_cli/src/utils/project_config.dart';
import 'package:blue_bird_cli/src/utils/utils.dart';
import 'package:mason/mason.dart';
import 'package:universal_io/io.dart';

/// {@template flutter_lite_template}
/// A Flutter lite app template.
/// {@endtemplate}
class FlutterLiteTemplate extends Template {
  /// {@macro flutter_lite_template}
  FlutterLiteTemplate()
      : super(
          name: 'flutter_lite',
          bundle: blueBirdFlutterLiteBundle,
          help: 'Generate a Blue Bird Flutter lite app.',
        );

  @override
  Future<void> onGenerateComplete(
    Logger logger,
    Directory outputDir,
    BlueBirdMasonGenerator blueBirdMasonGenerator,
    Map<String, dynamic>? vars,
  ) async {
    await installFlutterPackages(logger, outputDir);
    await generate(logger, outputDir);
    await applyDartFixes(logger, outputDir);
    await format(logger, outputDir);
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
        'You have set up a Blue Bird Flutter Lite App... 🐣',
      )
      ..info('\n');
  }
}
