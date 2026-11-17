import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:testagram/features/auth/identity_verification_client.dart';

void main() {
  test('registration client completes the backend HTTP contract without provisioning', () async {
    const appId = '11111111-1111-4111-8111-111111111111';
    const appToken = 'application-token-abcdefghijklmnopqrstuvwxyz';
    const sessionId = '22222222-2222-4222-8222-222222222222';
    const sessionToken = 'session-token-abcdefghijklmnopqrstuvwxyz';
    const evidenceId = '33333333-3333-4333-8333-333333333333';
    const key = 'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';
    final requests = <http.BaseRequest>[];
    final client = IdentityVerificationClient(
      backendOrigin: Uri.parse('https://api.testagram.site'),
      client: MockClient((request) async {
        requests.add(request);
        final path = request.url.path;
        if (request.method == 'POST' && path == '/api/identity/applications') {
          return http.Response(jsonEncode({
            'ok': true, 'application_id': appId, 'application_token': appToken,
            'verification_session_id': sessionId, 'verification_session_token': sessionToken,
            'status': 'verification_pending',
          }), 202, headers: {'content-type': 'application/json'});
        }
        if (request.method == 'POST' && path.endsWith('/evidence/upload-url')) {
          return http.Response(jsonEncode({
            'evidence_id': evidenceId,
            'upload_url': '/api/identity/sessions/$sessionId/evidence/$evidenceId/upload',
            'method': 'PUT', 'content_type': 'image/jpeg',
            'size_bytes': 11, 'expires_in_seconds': 300,
          }), 201, headers: {'content-type': 'application/json'});
        }
        if (request.method == 'PUT' && path.endsWith('/evidence/$evidenceId/upload')) {
          return http.Response('', 204);
        }
        if (request.method == 'POST' && path.endsWith('/evidence/submit')) {
          return http.Response(jsonEncode({'ok': true, 'status': 'manual_review'}), 202,
              headers: {'content-type': 'application/json'});
        }
        if (request.method == 'GET' && path == '/api/identity/applications/$appId') {
          return http.Response(jsonEncode({
            'status': 'under_review', 'adult_verification_status': 'pending',
            'verification_session_id': sessionId, 'account_provisioning_status': 'not_started',
          }), 200, headers: {'content-type': 'application/json'});
        }
        if (request.method == 'POST' && path.endsWith('/resend-verification')) {
          return http.Response(jsonEncode({'ok': true, 'message': 'If eligible, a new link will be sent.'}),
              202, headers: {'content-type': 'application/json'});
        }
        if (request.method == 'POST' && path.endsWith('/verify-email')) {
          return http.Response(jsonEncode({'status': 'active', 'email_verified': true}),
              200, headers: {'content-type': 'application/json'});
        }
        return http.Response('unexpected route', 404);
      }),
    );

    final result = await client.createApplication(
      email: ' APPLICANT@example.test ', username: '@applicant_123',
      displayName: ' Applicant ', adultConfirmed: true,
      termsAccepted: true, privacyAccepted: true, idempotencyKey: key,
    );
    expect(result.hasApplication, isTrue);
    final app = result.application!;
    await client.uploadAndSubmitEvidence(
      application: app,
      bytes: Uint8List.fromList([0xff, 0xd8, 0xff, 0xe0, 0x00, 0x10, 0x4a, 0x46, 0x49, 0x46, 0x00]),
      contentType: 'image/jpeg',
    );
    final status = await client.getStatus(app);
    expect(status.status, 'under_review');
    expect(status.provisioningStatus, 'not_started');
    await client.resendVerification(app);
    await client.verifyEmail(applicationId: app.applicationId, token: 'one-time-email-capability');

    expect(requests, hasLength(7));
    expect(requests.map((r) => '${r.method} ${r.url.path}'), [
      'POST /api/identity/applications',
      'POST /api/identity/sessions/$sessionId/evidence/upload-url',
      'PUT /api/identity/sessions/$sessionId/evidence/$evidenceId/upload',
      'POST /api/identity/sessions/$sessionId/evidence/submit',
      'GET /api/identity/applications/$appId',
      'POST /api/identity/applications/$appId/resend-verification',
      'POST /api/identity/applications/$appId/verify-email',
    ]);
    final create = requests.first as http.Request;
    expect(create.headers['Idempotency-Key'], key);
    expect(jsonDecode(create.body), {
      'email': 'applicant@example.test', 'username': 'applicant_123',
      'display_name': 'Applicant', 'adult_confirmed': true,
      'terms_accepted': true, 'privacy_accepted': true,
    });
    expect(requests[1].headers['X-Verification-Session-Token'], sessionToken);
    expect(requests[2].headers['X-Verification-Session-Token'], sessionToken);
    expect(requests[3].headers['X-Verification-Session-Token'], sessionToken);
    expect(requests[4].headers['X-Application-Token'], appToken);
    expect(requests[5].headers['X-Application-Token'], appToken);
    expect(jsonDecode((requests[3] as http.Request).body), {'evidence_id': evidenceId});
    expect(jsonDecode((requests[6] as http.Request).body), {'token': 'one-time-email-capability'});
    for (final request in requests) {
      expect(request.headers.containsKey('Authorization'), isFalse);
    }
    expect(requests.any((r) => r.url.path.endsWith('/redeem') ||
        r.url.path.endsWith('/provisioning-token')), isFalse);
    client.close();
  });
}
