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
    expect(result.applicationId, application.applicationId);
    expect(seen.url.path, '/api/identity/applications');
    expect(seen.headers['Idempotency-Key'], List<String>.filled(43, 'a').join());
    final body = jsonDecode(seen.body) as Map<String, dynamic>;
    expect(body['email'], 'user@example.com');
    expect(body['username'], 'test_user');
    expect(body['display_name'], 'Test User');
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

  test('requests an applicant-scoped provisioning token and redeems it with Appwrite JWT', () async {
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
      appwriteJwt: 'appwrite-session-jwt',
    );
    expect(result['status'], 'provisioned');
    expect(seen[0].url.path,
        '/api/identity/applications/${application.applicationId}/provisioning-token');
    expect(seen[0].headers['X-Application-Token'], application.applicationToken);
    expect(seen[1].url.path,
        '/api/identity/applications/${application.applicationId}/redeem');
    expect(seen[1].headers['X-Identity-Approval-Token'], authorization.token);
    expect(seen[1].headers['X-Identity-Approval-JTI'], authorization.jti);
    expect(seen[1].headers['Authorization'], 'Bearer appwrite-session-jwt');
    client.close();
  });

  test('maps application status without inventing an approved state', () async {
    final client = IdentityVerificationClient(
      backendOrigin: Uri.parse('https://api.testagram.site'),
      client: MockClient((request) async => http.Response(jsonEncode({
        'status': 'verification_pending',
        'adult_verification_status': 'verified',
        'verification_session_id': application.sessionId,
      }), 200, headers: {'content-type': 'application/json'})),
    );
    final status = await client.getStatus(application);
    expect(status.status, 'verification_pending');
    expect(status.verificationStatus, 'verified');
    expect(status.sessionId, application.sessionId);
    client.close();
  });
}
