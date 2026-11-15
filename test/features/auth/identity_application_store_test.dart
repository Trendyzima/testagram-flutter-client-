import 'package:flutter_test/flutter_test.dart';
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
  const application = IdentityApplication(
    applicationId: '11111111-1111-4111-8111-111111111111',
    applicationToken: 'application-token-abcdefghijklmnopqrstuvwxyz',
    sessionId: '22222222-2222-4222-8222-222222222222',
    sessionToken: 'session-token-abcdefghijklmnopqrstuvwxyz',
  );

  test('securely round-trips the idempotency capability and application tokens', () async {
    final storage = _MemoryIdentityStorage();
    final store = IdentityApplicationStore(storage: storage);
    final draft = IdentityApplicationDraft(
      email: 'person@example.test',
      username: 'person_123',
      displayName: 'Test Person',
      idempotencyKey: List<String>.filled(43, 'a').join(),
      createdAt: DateTime.utc(2026, 11, 15),
      application: application,
    );

    await store.save(draft);
    final restored = await store.load();

    expect(restored, isNotNull);
    expect(restored!.email, draft.email);
    expect(restored.username, draft.username);
    expect(restored.displayName, draft.displayName);
    expect(restored.idempotencyKey, draft.idempotencyKey);
    expect(restored.application?.applicationId, application.applicationId);
    expect(restored.application?.applicationToken, application.applicationToken);
    expect(restored.application?.sessionToken, application.sessionToken);

    final serialized = storage.values.values.single.toLowerCase();
    expect(serialized, isNot(contains('password')));
    expect(serialized, isNot(contains('jwt')));
    expect(serialized, isNot(contains('evidence_bytes')));
  });

  test('clears malformed or unsupported stored state fail-closed', () async {
    final storage = _MemoryIdentityStorage()
      ..values['testagram.identity_application.v1'] = '{"schema_version":99}';
    final store = IdentityApplicationStore(storage: storage);

    expect(await store.load(), isNull);
    expect(storage.values, isEmpty);
  });

  test('clear removes the saved application capability', () async {
    final storage = _MemoryIdentityStorage();
    final store = IdentityApplicationStore(storage: storage);
    await store.save(IdentityApplicationDraft(
      email: 'person@example.test',
      username: 'person_123',
      displayName: 'Test Person',
      idempotencyKey: List<String>.filled(43, 'b').join(),
      createdAt: DateTime.utc(2026, 11, 15),
    ));

    await store.clear();

    expect(await store.load(), isNull);
  });

  test('resumed approved applications may omit an evidence session', () {
    final resumed = IdentityApplication.fromJson({
      'application_id': application.applicationId,
      'application_token': application.applicationToken,
      'status': 'approved',
    });

    expect(resumed.sessionId, isEmpty);
    expect(resumed.sessionToken, isEmpty);
  });
}
