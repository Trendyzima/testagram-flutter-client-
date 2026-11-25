import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:testagram/features/auth/identity_verification_client.dart';

void main() {
  const application = IdentityApplication(
    applicationId: '11111111-1111-4111-8111-111111111111',
    applicationToken: 'application-token-abcdefghijklmnopqrstuvwxyz',
    sessionId: '22222222-2222-4222-8222-222222222222',
    sessionToken: 'session-token-abcdefghijklmnopqrstuvwxyz',
  );

  test('creates an application with normalized fields and idempotency key', () async {
    late http.Request seen;
    final client = IdentityVerificationClient(
      backendOrigin: Uri.parse('https://api.testagram.site'),
      client: MockClient((request) async {
        seen = request;
        return http.Response(jsonEncode({
          'application_id': application.applicationId,
          'application_token': application.applicationToken,
          'verification_session_id': application.sessionId,
          'verification_session_token': application.sessionToken,
        }), 202, headers: {'content-type': 'application/json'});
      }),
    );
    final result = await client.createApplication(
      email: ' USER@example.com ',
      username: '@Test_User',
      displayName: ' Test User ',
      adultConfirmed: true,
      termsAccepted: true,
      privacyAccepted: true,
      idempotencyKey: List<String>.filled(43, 'a').join(),
    );
    expect(result.application?.applicationId, application.applicationId);
    expect(result.hasApplication, isTrue);
    expect(seen.url.path, '/api/identity/applications');
    expect(seen.headers['Idempotency-Key'], List<String>.filled(43, 'a').join());
    final body = jsonDecode(seen.body) as Map<String, dynamic>;
    expect(body['email'], 'user@example.com');
    expect(body['username'], 'test_user');
    expect(body['display_name'], 'Test User');
    client.close();
  });

  test('handles privacy-preserving generic application acceptance', () async {
    final client = IdentityVerificationClient(
      backendOrigin: Uri.parse('https://api.testagram.site'),
      client: MockClient((request) async => http.Response(jsonEncode({
        'ok': true,
        'message': 'If the application is eligible, the next verification step will be sent.',
      }), 202, headers: {'content-type': 'application/json'})),
    );

    final result = await client.createApplication(
      email: 'user@example.com',
      username: 'test_user',
      displayName: 'Test User',
      adultConfirmed: true,
      termsAccepted: true,
      privacyAccepted: true,
      idempotencyKey: List<String>.filled(43, 'a').join(),
    );

    expect(result.hasApplication, isFalse);
    expect(result.application, isNull);
    expect(result.message, contains('If the application is eligible'));
    client.close();
  });

  test('reads the expiry of the active evidence session', () async {
    late http.Request seen;
    final client = IdentityVerificationClient(
      backendOrigin: Uri.parse('https://api.testagram.site'),
      client: MockClient((request) async {
        seen = request;
        return http.Response(jsonEncode({
          'session_id': application.sessionId,
          'application_id': application.applicationId,
          'purpose': 'age_assurance',
          'status': 'in_progress',
          'expires_at': '2026-11-16T12:00:00Z',
        }), 200, headers: {'content-type': 'application/json'});
      }),
    );

    final expiry = await client.getSessionExpiry(application);

    expect(seen.url.path, '/api/identity/sessions/${application.sessionId}');
    expect(seen.headers['X-Verification-Session-Token'], application.sessionToken);
    expect(expiry, DateTime.utc(2026, 11, 16, 12));
    client.close();
  });

  test('rejects an expired evidence session so the application can renew it', () async {
    final client = IdentityVerificationClient(
      backendOrigin: Uri.parse('https://api.testagram.site'),
      client: MockClient((request) async => http.Response(jsonEncode({
        'ok': false,
        'error': {'code': 'SESSION_NOT_FOUND', 'message': 'Verification session was not found'},
      }), 404, headers: {'content-type': 'application/json'})),
    );

    await expectLater(
      client.getSessionExpiry(application),
      throwsA(
        isA<IdentityVerificationException>().having((error) => error.statusCode, 'statusCode', 404),
      ),
    );
    client.close();
  });

  test('uploads evidence, then submits only its opaque evidence ID', () async {
    final seen = <http.BaseRequest>[];
    final client = IdentityVerificationClient(
      backendOrigin: Uri.parse('https://api.testagram.site'),
      client: MockClient((request) async {
        seen.add(request);
        if (request.url.path.endsWith('/evidence/upload-url')) {
          return http.Response(jsonEncode({
            'evidence_id': '33333333-3333-4333-8333-333333333333',
            'upload_url': '/api/identity/sessions/${application.sessionId}/evidence/33333333-3333-4333-8333-333333333333/upload',
            'method': 'PUT',
            'content_type': 'image/jpeg',
            'size_bytes': 11,
            'expires_in_seconds': 300,
          }), 201, headers: {'content-type': 'application/json'});
        }
        if (request.method == 'PUT') return http.Response('', 204);
        if (request.url.path.endsWith('/evidence/submit')) {
          return http.Response(jsonEncode({'ok': true, 'status': 'manual_review'}), 202,
              headers: {'content-type': 'application/json'});
        }
        return http.Response('unexpected route', 404);
      }),
    );
    await client.uploadAndSubmitEvidence(
      application: application,
      bytes: Uint8List.fromList([0xff, 0xd8, 0xff, 0xe0, 0x00, 0x10, 0x4a, 0x46, 0x49, 0x46, 0x00]),
      contentType: 'image/jpeg',
    );
    expect(seen, hasLength(3));
    expect(seen[0].headers['X-Verification-Session-Token'], application.sessionToken);
    expect(seen[1].url.scheme, 'https');
    expect(seen[1].url.host, 'api.testagram.site');
    expect(seen[1].url.path, '/api/identity/sessions/${application.sessionId}/evidence/33333333-3333-4333-8333-333333333333/upload');
    expect(seen[1].headers['Content-Type'], 'image/jpeg');
    expect(seen[1].headers['X-Verification-Session-Token'], application.sessionToken);
    expect(seen[2].headers['X-Verification-Session-Token'], application.sessionToken);
    expect(jsonDecode((seen[2] as http.Request).body)['evidence_id'],
        '33333333-3333-4333-8333-333333333333');
    client.close();
  });

  test('rejects a non-HTTPS evidence upload URL', () async {
    final client = IdentityVerificationClient(
      backendOrigin: Uri.parse('https://api.testagram.site'),
      client: MockClient((request) async => http.Response(jsonEncode({
        'evidence_id': '33333333-3333-4333-8333-333333333333',
        'upload_url': 'http://untrusted.example/upload',
        'method': 'PUT',
        'content_type': 'image/jpeg',
        'size_bytes': 1,
        'expires_in_seconds': 300,
      }), 201, headers: {'content-type': 'application/json'})),
    );
    await expectLater(
      client.uploadAndSubmitEvidence(
        application: application,
        bytes: Uint8List.fromList([1]),
        contentType: 'image/jpeg',
      ),
      throwsA(isA<FormatException>()),
    );
    client.close();
  });

  test('rejects a cross-origin HTTPS evidence upload URL', () async {
    final client = IdentityVerificationClient(
      backendOrigin: Uri.parse('https://api.testagram.site'),
      client: MockClient((request) async => http.Response(jsonEncode({
        'evidence_id': '33333333-3333-4333-8333-333333333333',
        'upload_url': 'https://attacker.example/upload',
        'method': 'PUT',
        'content_type': 'image/jpeg',
        'size_bytes': 1,
        'expires_in_seconds': 300,
      }), 201, headers: {'content-type': 'application/json'})),
    );
    await expectLater(
      client.uploadAndSubmitEvidence(
        application: application,
        bytes: Uint8List.fromList([1]),
        contentType: 'image/jpeg',
      ),
      throwsA(isA<FormatException>()),
    );
    client.close();
  });

  test('requests an applicant-scoped provisioning token and redeems with a native password', () async {
    final seen = <http.BaseRequest>[];
    final client = IdentityVerificationClient(
      backendOrigin: Uri.parse('https://api.testagram.site'),
      client: MockClient((request) async {
        seen.add(request);
        if (request.url.path.endsWith('/provisioning-token')) {
          return http.Response(jsonEncode({
            'approval_token': 'approval-token-abcdefghijklmnopqrstuvwxyz',
            'jti': 'jti-token-abcdefghijklmnopqrstuvwxyz',
            'expires_in_seconds': 900,
          }), 200, headers: {'content-type': 'application/json'});
        }
        return http.Response(jsonEncode({
          'status': 'provisioned',
          'canonical_user_id': '44444444-4444-4444-8444-444444444444',
          'email_verification_required': true,
        }), 200, headers: {'content-type': 'application/json'});
      }),
    );
    final authorization = await client.requestProvisioningAuthorization(application);
    expect(authorization.jti, 'jti-token-abcdefghijklmnopqrstuvwxyz');
    final result = await client.redeemProvisioningAuthorization(
      application: application,
      authorization: authorization,
      password: 'a-strong-native-password-123',
    );
    expect(result['status'], 'provisioned');
    expect(seen[0].url.path,
        '/api/identity/applications/${application.applicationId}/provisioning-token');
    expect(seen[0].headers['X-Application-Token'], application.applicationToken);
    expect(seen[1].url.path,
        '/api/identity/applications/${application.applicationId}/redeem');
    expect(seen[1].headers['X-Identity-Approval-Token'], authorization.token);
    expect(seen[1].headers['X-Identity-Approval-JTI'], authorization.jti);
    expect(seen[1].headers.containsKey('Authorization'), isFalse);
    expect(jsonDecode((seen[1] as http.Request).body), {
      'password': 'a-strong-native-password-123',
    });
    client.close();
  });

  test('verifies a native email capability without a foreign-provider bearer', () async {
    late http.Request seen;
    final client = IdentityVerificationClient(
      backendOrigin: Uri.parse('https://api.testagram.site'),
      client: MockClient((request) async {
        seen = request;
        return http.Response(jsonEncode({
          'status': 'active',
          'email_verified': true,
          'canonical_user_id': '44444444-4444-4444-8444-444444444444',
        }), 200, headers: {'content-type': 'application/json'});
      }),
    );

    await client.verifyEmail(
      applicationId: application.applicationId,
      token: 'one-time-native-email-token-abcdefghijklmnopqrstuvwxyz',
    );

    expect(seen.url.path,
        '/api/identity/applications/${application.applicationId}/verify-email');
    expect(seen.headers.containsKey('Authorization'), isFalse);
    expect(jsonDecode(seen.body), {
      'token': 'one-time-native-email-token-abcdefghijklmnopqrstuvwxyz',
    });
    client.close();
  });

  test('resends verification only with the saved application capability', () async {
    late http.Request seen;
    final client = IdentityVerificationClient(
      backendOrigin: Uri.parse('https://api.testagram.site'),
      client: MockClient((request) async {
        seen = request;
        return http.Response(jsonEncode({
          'ok': true,
          'email_queued': true,
          'message': 'If the application is awaiting email verification, a new link will be sent.',
        }), 202, headers: {'content-type': 'application/json'});
      }),
    );

    final result = await client.resendVerification(application);

    expect(result['email_queued'], isTrue);
    expect(seen.url.path,
        '/api/identity/applications/${application.applicationId}/resend-verification');
    expect(seen.headers['X-Application-Token'], application.applicationToken);
    expect(seen.headers.containsKey('Authorization'), isFalse);
    client.close();
  });

  test('maps application status without inventing an approved state', () async {
    final client = IdentityVerificationClient(
      backendOrigin: Uri.parse('https://api.testagram.site'),
      client: MockClient((request) async => http.Response(jsonEncode({
        'status': 'verification_pending',
        'adult_verification_status': 'verified',
        'verification_session_id': application.sessionId,
        'account_provisioning_status': 'verification_pending',
      }), 200, headers: {'content-type': 'application/json'})),
    );
    final status = await client.getStatus(application);
    expect(status.status, 'verification_pending');
    expect(status.verificationStatus, 'verified');
    expect(status.sessionId, application.sessionId);
    expect(status.provisioningStatus, 'verification_pending');
    client.close();
  });

  test('completes the applicant HTTP contract from intake through verified redemption', () async {
    final requests = <http.Request>[];
    const evidenceId = '33333333-3333-4333-8333-333333333333';
    final client = IdentityVerificationClient(
      backendOrigin: Uri.parse('https://api.testagram.site'),
      client: MockClient((request) async {
        requests.add(request);
        final path = request.url.path;
        if (request.method == 'POST' && path == '/api/identity/applications') {
          return http.Response(jsonEncode({
            'ok': true,
            'application_id': application.applicationId,
            'application_token': application.applicationToken,
            'verification_session_id': application.sessionId,
            'verification_session_token': application.sessionToken,
            'status': 'verification_pending',
          }), 202, headers: {'content-type': 'application/json'});
        }
        if (request.method == 'POST' && path.endsWith('/evidence/upload-url')) {
          return http.Response(jsonEncode({
            'evidence_id': evidenceId,
            'upload_url': '/api/identity/sessions/${application.sessionId}/evidence/$evidenceId/upload',
            'method': 'PUT',
            'content_type': 'image/jpeg',
            'size_bytes': 4,
            'expires_in_seconds': 120,
          }), 201, headers: {'content-type': 'application/json'});
        }
        if (request.method == 'PUT' && path.endsWith('/evidence/$evidenceId/upload')) {
          return http.Response('', 204);
        }
        if (request.method == 'POST' && path.endsWith('/evidence/submit')) {
          return http.Response(jsonEncode({'ok': true, 'status': 'manual_review'}), 202,
              headers: {'content-type': 'application/json'});
        }
        if (request.method == 'GET' && path.endsWith('/${application.applicationId}')) {
          return http.Response(jsonEncode({
            'status': 'under_review',
            'adult_verification_status': 'pending',
            'verification_session_id': application.sessionId,
            'account_provisioning_status': 'not_started',
          }), 200, headers: {'content-type': 'application/json'});
        }
        if (request.method == 'POST' && path.endsWith('/resend-verification')) {
          return http.Response(jsonEncode({'ok': true, 'email_queued': true, 'message': 'If eligible, a new link will be sent.'}), 202,
              headers: {'content-type': 'application/json'});
        }
        if (request.method == 'POST' && path.endsWith('/verify-email')) {
          return http.Response(jsonEncode({'status': 'active', 'email_verified': true}), 200,
              headers: {'content-type': 'application/json'});
        }
        if (request.method == 'POST' && path.endsWith('/provisioning-token')) {
          return http.Response(jsonEncode({
            'approval_token': 'approval-token-abcdefghijklmnopqrstuvwxyz',
            'jti': 'jti-token-abcdefghijklmnopqrstuvwxyz',
            'expires_in_seconds': 900,
          }), 200, headers: {'content-type': 'application/json'});
        }
        if (request.method == 'POST' && path.endsWith('/redeem')) {
          return http.Response(jsonEncode({
            'status': 'provisioned',
            'canonical_user_id': '44444444-4444-4444-8444-444444444444',
            'email_verification_required': true,
          }), 200, headers: {'content-type': 'application/json'});
        }
        return http.Response('unexpected route: ${request.method} $path', 404);
      }),
    );

    final created = await client.createApplication(
      email: ' Person@example.test ',
      username: '@person_123',
      displayName: 'Person Example',
      adultConfirmed: true,
      termsAccepted: true,
      privacyAccepted: true,
      idempotencyKey: List<String>.filled(43, 'z').join(),
    );
    expect(created.hasApplication, isTrue);
    final savedApplication = created.application!;
    expect(savedApplication.applicationId, application.applicationId);

    await client.uploadAndSubmitEvidence(
      application: savedApplication,
      bytes: Uint8List.fromList([0xff, 0xd8, 0xff, 0xe0]),
      contentType: 'image/jpeg',
    );
    final status = await client.getStatus(savedApplication);
    expect(status.status, 'under_review');
    await client.resendVerification(savedApplication);
    await client.verifyEmail(
      applicationId: savedApplication.applicationId,
      token: 'one-time-email-token-abcdefghijklmnopqrstuvwxyz',
    );
    final authorization =
        await client.requestProvisioningAuthorization(savedApplication);
    final redeemed = await client.redeemProvisioningAuthorization(
      application: savedApplication,
      authorization: authorization,
      password: 'test-only-strong-password-123',
    );

    expect(redeemed['status'], 'provisioned');
    expect(requests, hasLength(9));
    expect(requests.first.url.path, '/api/identity/applications');
    expect(requests.first.headers['Idempotency-Key'], List<String>.filled(43, 'z').join());
    expect(requests[1].headers['X-Verification-Session-Token'], application.sessionToken);
    expect(requests[2].headers['X-Verification-Session-Token'], application.sessionToken);
    expect(requests[3].headers['X-Verification-Session-Token'], application.sessionToken);
    expect(requests[4].headers['X-Application-Token'], application.applicationToken);
    expect(requests[5].headers['X-Application-Token'], application.applicationToken);
    expect(requests[7].headers['X-Application-Token'], application.applicationToken);
    expect(requests[8].headers['X-Identity-Approval-Token'], authorization.token);
    expect(requests[8].headers['X-Identity-Approval-JTI'], authorization.jti);
    expect(requests.every((request) => !request.headers.containsKey('Authorization')), isTrue);
    client.close();
  });

}
