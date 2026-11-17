import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:testagram/features/auth/identity_verification_client.dart';

void main() {
  test('registration client completes the backend HTTP contract over real HTTP', () async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final requests = <({String method, String path, String? idempotencyKey,
      String? applicationToken, String body})>[];
    final applicationId = '11111111-1111-4111-8111-111111111111';
    final applicationToken = 'application-token-abcdefghijklmnopqrstuvwxyz';
    final sessionId = '22222222-2222-4222-8222-222222222222';
    final sessionToken = 'session-token-abcdefghijklmnopqrstuvwxyz';

    final serverTask = () async {
      await for (final request in server) {
        final body = await utf8.decoder.bind(request).join();
        requests.add((
          method: request.method,
          path: request.uri.path,
          idempotencyKey: request.headers.value('Idempotency-Key'),
          applicationToken: request.headers.value('X-Application-Token'),
          body: body,
        ));
        request.response.headers.contentType = ContentType.json;
        if (request.method == 'POST' && request.uri.path == '/api/identity/applications') {
          request.response.statusCode = HttpStatus.accepted;
          request.response.write(jsonEncode({
            'ok': true,
            'application_id': applicationId,
            'application_token': applicationToken,
            'verification_session_id': sessionId,
            'verification_session_token': sessionToken,
            'status': 'verification_pending',
          }));
        } else if (request.method == 'GET' &&
            request.uri.path == '/api/identity/applications/$applicationId') {
          request.response.statusCode = HttpStatus.ok;
          request.response.write(jsonEncode({
            'status': 'verification_pending',
            'adult_verification_status': 'pending',
            'verification_session_id': sessionId,
            'account_provisioning_status': '',
          }));
        } else if (request.method == 'POST' &&
            request.uri.path == '/api/identity/applications/$applicationId/resend-verification') {
          request.response.statusCode = HttpStatus.accepted;
          request.response.write(jsonEncode({
            'ok': true,
            'message': 'If the application is awaiting email verification, a new link will be sent.',
          }));
        } else {
          request.response.statusCode = HttpStatus.notFound;
          request.response.write(jsonEncode({
            'ok': false,
            'error': {'code': 'NOT_FOUND', 'message': 'Route not found'},
          }));
        }
        await request.response.close();
      }
    }();

    final client = IdentityVerificationClient(
      backendOrigin: Uri.parse('http://127.0.0.1:${server.port}'),
    );
    try {
      final created = await client.createApplication(
        email: ' PERSON@example.test ',
        username: '@Test_User',
        displayName: ' Test Person ',
        adultConfirmed: true,
        termsAccepted: true,
        privacyAccepted: true,
        idempotencyKey: List<String>.filled(43, 'k').join(),
      );
      expect(created.hasApplication, isTrue);
      final application = created.application!;

      final status = await client.getStatus(application);
      expect(status.status, 'verification_pending');
      expect(status.verificationStatus, 'pending');
      expect(status.provisioningStatus, isEmpty);

      await client.resendVerification(application);

      expect(requests, hasLength(3));
      expect(requests[0].method, 'POST');
      expect(requests[0].path, '/api/identity/applications');
      expect(requests[0].idempotencyKey, List<String>.filled(43, 'k').join());
      expect(jsonDecode(requests[0].body), {
        'email': 'person@example.test',
        'username': 'test_user',
        'display_name': 'Test Person',
        'adult_confirmed': true,
        'terms_accepted': true,
        'privacy_accepted': true,
      });
      expect(requests[1].method, 'GET');
      expect(requests[1].path, '/api/identity/applications/$applicationId');
      expect(requests[1].applicationToken, applicationToken);
      expect(requests[2].method, 'POST');
      expect(requests[2].path, '/api/identity/applications/$applicationId/resend-verification');
      expect(requests[2].applicationToken, applicationToken);
    } finally {
      client.close();
      await server.close(force: true);
      await serverTask;
    }
  });

  test('registration client preserves the disabled-intake response from backend', () async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final serverTask = () async {
      await for (final request in server) {
        await utf8.decoder.bind(request).join();
        request.response.statusCode = HttpStatus.serviceUnavailable;
        request.response.headers.contentType = ContentType.json;
        request.response.write(jsonEncode({
          'ok': false,
          'error': {
            'code': 'REGISTRATION_DISABLED',
            'message': 'Identity registration is not enabled',
          },
        }));
        await request.response.close();
      }
    }();

    final client = IdentityVerificationClient(
      backendOrigin: Uri.parse('http://127.0.0.1:${server.port}'),
    );
    try {
      await expectLater(
        client.createApplication(
          email: 'person@example.test',
          username: 'person_123',
          displayName: 'Test Person',
          adultConfirmed: true,
          termsAccepted: true,
          privacyAccepted: true,
          idempotencyKey: List<String>.filled(43, 'z').join(),
        ),
        throwsA(isA<IdentityVerificationException>()
            .having((error) => error.statusCode, 'statusCode', 503)
            .having((error) => error.message, 'message', 'Identity registration is not enabled')),
      );
    } finally {
      client.close();
      await server.close(force: true);
      await serverTask;
    }
  });
}
