import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:testagram/core/backend_api.dart';

void main() {
  test('Knowledge API uses native auth, stable routes and idempotency headers', () async {
    final requests = <http.Request>[];
    final api = BackendApi(
      baseUri: Uri.parse('https://api.testagram.site'),
      getAccessToken: ({bool forceRefresh = false}) async => 'native-session-token',
      client: MockClient((request) async {
        requests.add(request);
        return http.Response(jsonEncode({'ok': true, 'data': {'items': []}}), 200);
      }),
    );

    await api.getKnowledgeQuestions(status: 'open', mine: true, limit: 15);
    await api.createKnowledgeQuestion(
      title: 'How can I improve PostgreSQL performance?',
      body: 'I am profiling a slow query.',
      visibility: 'followers',
      idempotencyKey: 'question-create-123456',
    );
    await api.getKnowledgeQuestion('123e4567-e89b-42d3-a456-426614174000');
    await api.createKnowledgeAnswer(
      questionId: '123e4567-e89b-42d3-a456-426614174000',
      body: 'Start with EXPLAIN ANALYZE.',
      idempotencyKey: 'answer-create-123456',
    );
    await api.acceptKnowledgeAnswer(
      questionId: '123e4567-e89b-42d3-a456-426614174000',
      answerId: '223e4567-e89b-42d3-a456-426614174000',
    );

    expect(requests, hasLength(5));
    expect(requests[0].url.path, '/api/knowledge/questions');
    expect(requests[0].url.queryParameters, {
      'limit': '15',
      'status': 'open',
      'mine': 'true',
    });
    expect(requests[1].headers['idempotency-key'], 'question-create-123456');
    expect(jsonDecode(requests[1].body), {
      'title': 'How can I improve PostgreSQL performance?',
      'body': 'I am profiling a slow query.',
      'visibility': 'followers',
      'language': '',
    });
    expect(requests[2].url.path, '/api/knowledge/questions/123e4567-e89b-42d3-a456-426614174000');
    expect(requests[3].url.path, '/api/knowledge/questions/123e4567-e89b-42d3-a456-426614174000/answers');
    expect(requests[3].headers['idempotency-key'], 'answer-create-123456');
    expect(requests[4].url.path, '/api/knowledge/questions/123e4567-e89b-42d3-a456-426614174000/answers/223e4567-e89b-42d3-a456-426614174000/accept');
    expect(requests.every((r) => r.headers['authorization'] == 'Bearer native-session-token'), isTrue);
    api.close();
  });
}
