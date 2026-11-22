import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:testagram/core/backend_api.dart';

void main() {
  test('communication capability wrappers use authenticated native Backend boundary', () async {
    final requests = <http.Request>[];
    final api = BackendApi(
      baseUri: Uri.parse('https://api.testagram.site'),
      getAccessToken: ({bool forceRefresh = false}) async => 'native-session-token',
      client: MockClient((request) async {
        requests.add(request);
        return http.Response(jsonEncode({'ok': true, 'data': {'items': []}}), 200);
      }),
    );

    await api.listConversations();
    await api.createConversation(['123e4567-e89b-42d3-a456-426614174000']);
    await api.listMessages('123e4567-e89b-42d3-a456-426614174000');
    await api.listConversationCalls('123e4567-e89b-42d3-a456-426614174000');
    await api.createCallSession('123e4567-e89b-42d3-a456-426614174000', kind: 'voice');

    expect(requests, hasLength(5));
    final capabilities = requests.map((request) =>
      (jsonDecode(request.body) as Map<String, dynamic>)['capability']
    ).toList();
    expect(capabilities, [
      'testagram.conversations.list',
      'testagram.conversations.create',
      'testagram.messages.list',
      'testagram.calls.list',
      'testagram.calls.create',
    ]);
    expect(requests.every((request) => request.url.path == '/api/capability'), isTrue);
    expect(requests.every((request) => request.headers['authorization'] == 'Bearer native-session-token'), isTrue);
    expect(jsonDecode(requests[1].body)['input']['member_ids'], [
      '123e4567-e89b-42d3-a456-426614174000',
    ]);
    expect(jsonDecode(requests[4].body)['input']['kind'], 'voice');
    api.close();
  });

  test('encrypted message API rejects plaintext-like incomplete envelopes locally', () {
    final api = BackendApi(
      baseUri: Uri.parse('https://api.testagram.site'),
      getAccessToken: ({bool forceRefresh = false}) async => 'native-session-token',
      client: MockClient((_) async => http.Response('{}', 200)),
    );
    expect(() => api.createConversation([
      '123e4567-e89b-42d3-a456-426614174000',
      '123e4567-e89b-42d3-a456-426614174001',
    ]), throwsArgumentError);
    expect(() => api.sendEncryptedMessage(
      conversationId: 'conversation',
      ciphertext: '',
      nonce: '',
      clientMessageId: '',
      epoch: 0,
    ), throwsArgumentError);
    api.close();
  });
}
