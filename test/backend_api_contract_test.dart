import 'package:flutter_test/flutter_test.dart';
import 'package:testagram/core/backend_api.dart';

void main() {
  group('BackendApiException', () {
    test('retains server status for callers', () {
      const error = BackendApiException('Unauthorized', statusCode: 401);
      expect(error.message, 'Unauthorized');
      expect(error.statusCode, 401);
      expect(error.toString(), 'Unauthorized');
    });
  });
}
