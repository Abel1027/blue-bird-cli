import 'package:blue_bird_cli/src/utils/project_config.dart';
import 'package:test/test.dart';

void main() {
  group('PlatformConfig', () {
    test('creates with default values', () {
      const config = PlatformConfig();
      expect(config.android, isFalse);
      expect(config.ios, isFalse);
      expect(config.web, isFalse);
      expect(config.linux, isFalse);
      expect(config.macos, isFalse);
      expect(config.windows, isFalse);
    });

    test('creates with custom values', () {
      const config = PlatformConfig(
        android: true,
        ios: true,
        macos: true,
      );
      expect(config.android, isTrue);
      expect(config.ios, isTrue);
      expect(config.macos, isTrue);
      expect(config.web, isFalse);
      expect(config.linux, isFalse);
      expect(config.windows, isFalse);
    });

    test('fromMap creates config correctly', () {
      final config = PlatformConfig.fromMap({
        'android': true,
        'web': true,
      });
      expect(config.android, isTrue);
      expect(config.web, isTrue);
      expect(config.ios, isFalse);
    });

    test('fromMap handles missing values', () {
      final config = PlatformConfig.fromMap({});
      expect(config.android, isFalse);
      expect(config.ios, isFalse);
    });
  });

  group('ProjectConfig', () {
    test('creates with required values', () {
      const config = ProjectConfig(
        orgName: 'com.example',
        platforms: PlatformConfig(android: true),
      );
      expect(config.orgName, 'com.example');
      expect(config.platforms.android, isTrue);
    });

    test('fromMap creates config correctly', () {
      final config = ProjectConfig.fromMap({
        'org_name': 'com.test',
        'platforms': {
          'android': true,
          'ios': true,
        },
      });
      expect(config.orgName, 'com.test');
      expect(config.platforms.android, isTrue);
      expect(config.platforms.ios, isTrue);
    });

    test('fromMap handles empty org name', () {
      final config = ProjectConfig.fromMap({
        'org_name': '',
        'platforms': {
          'android': true,
        },
      });
      expect(config.orgName, isEmpty);
    });
  });
}
