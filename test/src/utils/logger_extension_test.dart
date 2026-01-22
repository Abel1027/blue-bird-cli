import 'package:blue_bird_cli/src/utils/logger_extension.dart';
import 'package:mason/mason.dart';
import 'package:mocktail/mocktail.dart';
import 'package:test/test.dart';

class _MockLogger extends Mock implements Logger {}

void main() {
  group('LoggerX', () {
    late Logger logger;

    setUp(() {
      logger = _MockLogger();
      when(() => logger.info(any())).thenReturn(null);
    });

    test('created logs message with styling', () {
      logger.created('test message');
      verify(() => logger.info(any())).called(1);
    });
  });
}
