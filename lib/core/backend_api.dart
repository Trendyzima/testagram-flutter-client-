import 'dart:convert';

import 'package:http/http.dart' as http;

class BackendApi {
  BackendApi({required this.baseUri, required this.getJwt, http.Client? client})
      : _client = client ?? http.Client();

  final Uri baseUri;
  final Future<String> Function() getJwt;
  final http.Client _client;

  Future<Map<String, dynamic>> getHomeFeed({int limit = 20, String? cursor}) async {
    final uri = baseUri.resolve('/v1/feed/home').replace(queryParameters: {
      'limit': '$limit',
      if (cursor != null && cursor.isNotEmpty) 'before': cursor,
    });
    final response = await _client
        .get(uri, headers: await _headers())
        .timeout(const Duration(seconds: 20));
    return _decodeObject(response);
  }

  Future<Map<String, dynamic>> createPost({
    required String content,
    String visibility = 'public',
    required String idempotencyKey,
  }) async {
    final response = await _client
        .post(
          baseUri.resolve('/v1/posts'),
          headers: {
            ...await _headers(),
            'Content-Type': 'application/json',
            'Idempotency-Key': idempotencyKey,
          },
          body: jsonEncode({'content': content, 'visibility': visibility}),
        )
        .timeout(const Duration(seconds: 20));
    return _decodeObject(response);
  }

  Future<Map<String, String>> _headers() async => {
        'Accept': 'application/json',
        'Authorization': 'Bearer ${await getJwt()}',
      };

  Map<String, dynamic> _decodeObject(http.Response response) {
    dynamic decoded;
    try {
      decoded = jsonDecode(response.body);
    } on FormatException {
      throw BackendApiException('The server returned an invalid response.',
          statusCode: response.statusCode);
    }
    if (response.statusCode < 200 || response.statusCode >= 300) {
      final message = decoded is Map
          ? (decoded['message'] ?? decoded['error'])?.toString()
          : null;
      throw BackendApiException(
        message?.isNotEmpty == true ? message! : 'Request failed. Please try again.',
        statusCode: response.statusCode,
      );
    }
    if (decoded is Map<String, dynamic>) return decoded;
    throw const BackendApiException('The server returned an unexpected response.');
  }

  void close() => _client.close();
}

class BackendApiException implements Exception {
  const BackendApiException(this.message, {this.statusCode});
  final String message;
  final int? statusCode;

  @override
  String toString() => message;
}
