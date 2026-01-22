/// {@template platform_config}
/// Platform configuration for a project.
/// {@endtemplate}
class PlatformConfig {
  /// {@macro platform_config}
  const PlatformConfig({
    this.android = false,
    this.ios = false,
    this.web = false,
    this.linux = false,
    this.macos = false,
    this.windows = false,
  });

  /// Creates a [PlatformConfig] from a map.
  factory PlatformConfig.fromMap(Map<String, dynamic> map) {
    return PlatformConfig(
      android: map['android'] as bool? ?? false,
      ios: map['ios'] as bool? ?? false,
      web: map['web'] as bool? ?? false,
      linux: map['linux'] as bool? ?? false,
      macos: map['macos'] as bool? ?? false,
      windows: map['windows'] as bool? ?? false,
    );
  }

  /// Whether Android platform is supported.
  final bool android;

  /// Whether iOS platform is supported.
  final bool ios;

  /// Whether Web platform is supported.
  final bool web;

  /// Whether Linux platform is supported.
  final bool linux;

  /// Whether macOS platform is supported.
  final bool macos;

  /// Whether Windows platform is supported.
  final bool windows;
}

/// {@template project_config}
/// Configuration data for project generation.
/// {@endtemplate}
class ProjectConfig {
  /// {@macro project_config}
  const ProjectConfig({
    required this.orgName,
    required this.platforms,
  });

  /// Creates a [ProjectConfig] from a map.
  factory ProjectConfig.fromMap(Map<String, dynamic> map) {
    return ProjectConfig(
      orgName: map['org_name'] as String,
      platforms: PlatformConfig.fromMap(
        map['platforms'] as Map<String, dynamic>,
      ),
    );
  }

  /// The organization name for the project.
  final String orgName;

  /// The platform configuration for the project.
  final PlatformConfig platforms;
}
