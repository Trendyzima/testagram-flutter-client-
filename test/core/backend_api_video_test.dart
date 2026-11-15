import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:testagram/core/backend_api.dart';

void main() {
  test('uploadPublicVideo uses the authenticated verified media lifecycle', () async {
    final requests = <http.Request>[];
    final api = BackendApi(
      baseUri: Uri.parse('https://api.testagram.site'),
      getJwt: () async => 'session-jwt',
      client: MockClient((request) async {
        requests.add(request);
        if (request.url.path == '/api/media/upload-intent') {
          return http.Response(jsonEncode({
            'ok': true,
            'data': {
              'key': 'users/test-user/0123456789abcdef0123456789abcdef',
              'url': '/api/media/upload?key=users%2Ftest-user%2F0123456789abcdef0123456789abcdef',
            },
          }), 201);
        }
        if (request.url.path == '/api/media/upload') {
          return http.Response('', 204);
        }
        if (request.url.path == '/api/media/complete') {
          return http.Response(jsonEncode({
            'ok': true,
            'data': {
              'key': 'users/test-user/0123456789abcdef0123456789abcdef',
              'status': 'ready',
              'media_type': 'video',
              'content_type': 'video/mp4',
            },
          }), 200);
        }
        return http.Response(jsonEncode({'ok': false}), 404);
      }),
    );

    final asset = await api.uploadPublicVideo(
      name: 'short.mp4',
      contentType: 'video/mp4',
      bytes: List<int>.filled(1024, 7),
    );

    expect(asset['status'], 'ready');
    expect(asset['media_type'], 'video');
    final intent = requests.firstWhere((request) => request.url.path == '/api/media/upload-intent');
    expect(intent.method, 'POST');
    expect(intent.headers['authorization'], 'Bearer session-jwt');
    expect(jsonDecode(intent.body), {
      'name': 'short.mp4',
      'content_type': 'video/mp4',
      'visibility': 'public',
      'size_bytes': 1024,
    });
    final upload = requests.firstWhere((request) => request.url.path == '/api/media/upload');
    expect(upload.method, 'PUT');
    expect(upload.headers['content-type'], 'video/mp4');
    final complete = requests.firstWhere((request) => request.url.path == '/api/media/complete');
    expect(jsonDecode(complete.body)['content_type'], 'video/mp4');
    expect(jsonDecode(complete.body)['checksum_sha256'], isNotEmpty);
    api.close();
  });

  test('uploadPublicVideo rejects unsupported media before making a request', () async {
    var requestCount = 0;
    final api = BackendApi(
      baseUri: Uri.parse('https://api.testagram.site'),
      getJwt: () async => 'session-jwt',
      client: MockClient((request) async {
        requestCount++;
        return http.Response('{}', 500);
      }),
    );

    await expectLater(
      api.uploadPublicVideo(
        name: 'clip.mov',
        contentType: 'video/quicktime',
        bytes: [1, 2, 3],
      ),
      throwsA(isA<BackendApiException>()),
    );
    expect(requestCount, 0);
    api.close();
  });
}
