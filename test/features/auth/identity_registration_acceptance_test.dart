import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:testagram/features/auth/identity_application_store.dart';
import 'package:testagram/features/auth/identity_verification_client.dart';

class _MemoryIdentityStorage implements IdentityApplicationSecureStorage {
  final Map<String, String> values = {};

  @override
  Future<String?> read(String key) async => values[key];

  @override
  Future<void> write(String key, String value) async {
    values[key] = value;
  }

  @override
  Future<void> delete(String key) async {
    values.remove(key);
  }
}

void main() {
  const backendOrigin = 'https://api.testagram.site';
  const applicationId = '11111111-1111-4111-8111-111111111111';
  const sessionId = '22222222-2222-4222-8222-222222222222';
  const evidenceId = '33333333-3333-4333-8333-333333333333';
  const applicationToken = 'application-token-abcdefghijklmnopqrstuvwxyz';
  const sessionToken = 'session-token-abcdefghijklmnopqrstuvwxyz';
  const approvalToken = 'approval-token-abcdefghijklmnopqrstuvwxyz';
  const approvalJti = 'approval-jti-abcdefghijklmnopqrstuvwxyz';
  const verificationToken = 'native-email-token-abcdefghijklmnopqrstuvwxyz';
  const idempotencyKey = 'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';

  test('resumes and completes the Testagram registration API journey safely', () async {
    final storage = _MemoryIdentityStorage();
    final store = IdentityApplicationStore(storage: storage);
    final seen = <http.BaseRequest>[];
    var finalStatusRead = false;

    final client = IdentityVerificationClient(
      backendOrigin: Uri.parse(backendOrigin),
      client: MockClient((request) async {
        seen.add(request);
        final path = request.url.path;

        if (request.method == 'POST' && path == '/api/identity/applications') {
          return http.Response(jsonEncode({
            'application_id': applicationId,
            'application_token': applicationToken,
            'verification_session_id': sessionId,
            'verification_session_token': sessionToken,
            'status': 'verification_pending',
            'verification_method': 'manual_review',
          }), 202, headers: {'content-type': 'application/json'});
        }
        if (request.method == 'GET' &&
            path == '/api/identity/applications/$applicationId') {
          final status = finalStatusRead ? 'verified' : 'verification_pending';
          return http.Response(jsonEncode({
            'application_id': applicationId,
            'status': status,
            'adult_verification_status': 'verified',
            'verification_session_id': sessionId,
            'account_provisioning_status':
                finalStatusRead ? 'active' : 'verification_pending',
          }), 200, headers: {'content-type': 'application/json'});
        }
        if (request.method == 'POST' &&
            path.endsWith('/evidence/upload-url')) {
          return http.Response(jsonEncode({
            'evidence_id': evidenceId,
            'upload_url':
                '/api/identity/sessions/$sessionId/evidence/$evidenceId/upload',
            'method': 'PUT',
            'content_type': 'image/jpeg',
            'size_bytes': 11,
            'expires_in_seconds': 300,
          }), 201, headers: {'content-type': 'application/json'});
        }
        if (request.method == 'PUT' && path.endsWith('/evidence/$evidenceId/upload')) {
          return http.Response('', 204);
        }
        if (request.method == 'POST' && path.endsWith('/evidence/submit')) {
          return http.Response(jsonEncode({
            'ok': true,
            'status': 'manual_review',
          }), 202, headers: {'content-type': 'application/json'});
        }
        if (request.method == 'POST' && path.endsWith('/provisioning-token')) {
          return http.Response(jsonEncode({
            'approval_token': approvalToken,
            'jti': approvalJti,
            'expires_in_seconds': 900,
          }), 200, headers: {'content-type': 'application/json'});
        }
        if (request.method == 'POST' && path.endsWith('/redeem')) {
          return http.Response(jsonEncode({
            'status': 'provisioned',
            'canonical_user_id': '44444444-4444-4444-8444-444444444444',
            'email_verification_required': true,
            'email_delivery_pending': false,
          }), 202, headers: {'content-type': 'application/json'});
        }
        if (request.method == 'POST' && path.endsWith('/resend-verification')) {
          return http.Response(jsonEncode({
            'ok': true,
            'email_delivery_pending': false,
          }), 202, headers: {'content-type': 'application/json'});
        }
        if (request.method == 'POST' && path.endsWith('/verify-email')) {
          finalStatusRead = true;
          return http.Response(jsonEncode({
            'ok': true,
            'status': 'verified',
            'email_verified': true,
          }), 200, headers: {'content-type': 'application/json'});
        }
        return http.Response('unexpected route: ${request.method} $path', 404);
      }),
    );

    final draft = IdentityApplicationDraft(
      email: ' APPLICANT@example.test ',
      username: '@applicant_123',
      displayName: ' Test Applicant ',
      idempotencyKey: idempotencyKey,
      createdAt: DateTime.utc(2026, 11, 17),
    );
    await store.save(draft);

    // Initial submission and a retry use the same durable idempotency key.
    final restoredDraft = await store.load();
    expect(restoredDraft, isNotNull);
    final created = await client.createApplication(
      email: restoredDraft!.email,
      username: restoredDraft.username,
      displayName: restoredDraft.displayName,
      adultConfirmed: true,
      termsAccepted: true,
      privacyAccepted: true,
      idempotencyKey: restoredDraft.idempotencyKey,
    );
    expect(created.hasApplication, isTrue);
    final application = created.application!;
    await store.save(restoredDraft.copyWith(application: application));

    final retry = await client.createApplication(
      email: restoredDraft.email,
      username: restoredDraft.username,
      displayName: restoredDraft.displayName,
      adultConfirmed: true,
      termsAccepted: true,
      privacyAccepted: true,
      idempotencyKey: restoredDraft.idempotencyKey,
    );
    expect(retry.application?.applicationId, applicationId);

    // Simulate an app restart: only the secure draft store restores the
    // application/session capabilities needed to continue.
    final resumedDraft = await store.load();
    expect(resumedDraft?.application?.applicationToken, applicationToken);
    expect(resumedDraft?.application?.sessionToken, sessionToken);

    final pending = await client.getStatus(application);
    expect(pending.status, 'verification_pending');
    expect(pending.provisioningStatus, 'verification_pending');

    await client.uploadAndSubmitEvidence(
      application: application,
      bytes: Uint8List.fromList([
        0xff, 0xd8, 0xff, 0xe0, 0x00, 0x10, 0x4a, 0x46, 0x49, 0x46, 0x00,
      ]),
      contentType: 'image/jpeg',
    );

    final authorization =
        await client.requestProvisioningAuthorization(application);
    expect(authorization.token, approvalToken);
    expect(authorization.jti, approvalJti);

    final provisioned = await client.redeemProvisioningAuthorization(
      application: application,
      authorization: authorization,
      password: 'strong-test-password-123',
    );
    expect(provisioned['status'], 'provisioned');
    expect(provisioned['email_verification_required'], isTrue);

    await client.resendVerification(application);
    await client.verifyEmail(
      applicationId: applicationId,
      token: verificationToken,
    );
    final active = await client.getStatus(application);
    expect(active.status, 'verified');
    expect(active.provisioningStatus, 'active');

    final createRequests = seen.where(
      (request) => request.url.path == '/api/identity/applications',
    ).toList();
    expect(createRequests, hasLength(2));
    for (final request in createRequests) {
      expect(request.headers['Idempotency-Key'], idempotencyKey);
      expect(request.headers.containsKey('Authorization'), isFalse);
      final body = jsonDecode((request as http.Request).body);
      expect(body['email'], 'applicant@example.test');
      expect(body['username'], 'applicant_123');
    }

    final uploadRequests = seen.where(
      (request) => request.url.path.contains('/evidence/'),
    ).toList();
    expect(uploadRequests, hasLength(3));
    for (final request in uploadRequests) {
      expect(request.headers['X-Verification-Session-Token'], sessionToken);
      expect(request.headers.containsKey('Authorization'), isFalse);
    }

    final redeemRequest = seen.singleWhere(
      (request) => request.url.path.endsWith('/redeem'),
    ) as http.Request;
    expect(redeemRequest.headers['X-Application-Token'], applicationToken);
    expect(redeemRequest.headers['X-Identity-Approval-Token'], approvalToken);
    expect(redeemRequest.headers['X-Identity-Approval-JTI'], approvalJti);
    expect(jsonDecode(redeemRequest.body)['password'], 'strong-test-password-123');

    final resendRequest = seen.singleWhere(
      (request) => request.url.path.endsWith('/resend-verification'),
    );
    expect(resendRequest.headers['X-Application-Token'], applicationToken);

    final verifyRequest = seen.singleWhere(
      (request) => request.url.path.endsWith('/verify-email'),
    ) as http.Request;
    expect(verifyRequest.headers.containsKey('Authorization'), isFalse);
    expect(jsonDecode(verifyRequest.body)['token'], verificationToken);

    // The secure draft must never retain the account password or evidence bytes.
    final persisted = storage.values.values.single.toLowerCase();
    expect(persisted, isNot(contains('strong-test-password-123')));
    expect(persisted, isNot(contains('evidence_bytes')));
    await store.clear();
    expect(await store.load(), isNull);
    client.close();
  });
}
