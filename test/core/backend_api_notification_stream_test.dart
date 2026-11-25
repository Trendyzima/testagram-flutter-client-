import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:testagram/core/backend_api.dart';

void main() {
  test('notification SSE uses Backend auth and resumes from Last-Event-ID', () async {
    http.Request? captured;
    final api = BackendApi(
      baseUri: Uri.parse('https://api.testagram.site'),
      getAccessToken: ({bool forceRefresh = false}) async => 'native-session-token',
      client: MockClient((request) async {
        captured = request as http.Request;
        return http.Response(
          ': keep-alive\n'
          'event: notification\n'
          'id: cursor-1\n'
          'data: {"id":"notification-1","kind":"mention","payload":{"post_id":"post-1"}}\n\n',
          200,
          headers: {'content-type': 'text/event-stream; charset=utf-8'},
        );
      }),
    );

    final events = await api.streamNotifications(lastEventId: 'cursor-0').toList();

    expect(captured?.url.path, '/api/social/notifications/stream');
    expect(captured?.headers['authorization'], 'Bearer native-session-token');
    expect(captured?.headers['accept'], 'text/event-stream');
    expect(captured?.headers['last-event-id'], 'cursor-0');
    expect(events, [
      {
        'id': 'notification-1',
        'kind': 'mention',
        'payload': {'post_id': 'post-1'},
        'stream_cursor': 'cursor-1',
      },
    ]);
    api.close();
  });

  test('notification SSE parses multiple data lines as one JSON event', () async {
    final api = BackendApi(
      baseUri: Uri.parse('https://api.testagram.site'),
      getAccessToken: ({bool forceRefresh = false}) async => 'native-session-token',
      client: MockClient((_) async => http.Response(
        'event: notification\n'
        'id: cursor-2\n'
        'data: {"id":"notification-2",\n'
        'data: "kind":"reply"}\n\n',
        200,
        headers: {'content-type': 'text/event-stream'},
      )),
    );

    final events = await api.streamNotifications().toList();
    expect(events.single['id'], 'notification-2');
    expect(events.single['kind'], 'reply');
    expect(events.single['stream_cursor'], 'cursor-2');
    api.close();
  });
}
