import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:testagram/core/backend_api.dart';
import 'package:testagram/features/federation/federation_settings_screen.dart';

void main() {
  testWidgets('loads and updates federation preference through authenticated Backend API',
      (tester) async {
    var getSeen = false;
    var putSeen = false;
    final client = MockClient((request) async {
      expect(request.url.path, '/api/me/federation');
      expect(request.headers['Authorization'], 'Bearer appwrite-session-jwt');
      expect(request.headers['Accept'], 'application/json');
      if (request.method == 'GET') {
        getSeen = true;
        return http.Response(
          jsonEncode({
            'ok': true,
            'data': {'enabled': false},
            'error': null,
            'request_id': 'get-1',
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      }
      if (request.method == 'PUT') {
        putSeen = true;
        expect(jsonDecode(request.body), {'enabled': true});
        return http.Response(
          jsonEncode({
            'ok': true,
            'data': {'enabled': true},
            'error': null,
            'request_id': 'put-1',
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      }
      return http.Response('unexpected method', 405);
    });
    final api = BackendApi(
      baseUri: Uri.parse('https://api.testagram.site'),
      getJwt: () async => 'appwrite-session-jwt',
      client: client,
    );
    addTearDown(api.close);

    await tester.pumpWidget(
      MaterialApp(home: FederationSettingsScreen(api: api)),
    );
    await tester.pumpAndSettle();

    expect(getSeen, isTrue);
    expect(find.text('Allow Fediverse discovery'), findsOneWidget);
    expect(find.text('Your account is not opted in to federation.'), findsOneWidget);

    await tester.tap(find.byType(SwitchListTile));
    await tester.pumpAndSettle();

    expect(putSeen, isTrue);
    expect(find.text('Your account has opted in to federation.'), findsOneWidget);
  });

  testWidgets('keeps the preference disabled when Backend rejects opt-in',
      (tester) async {
    final client = MockClient((request) async {
      if (request.method == 'GET') {
        return http.Response(
          jsonEncode({
            'ok': true,
            'data': {'enabled': false},
            'error': null,
            'request_id': 'get-1',
          }),
          200,
        );
      }
      return http.Response(
        jsonEncode({
          'ok': false,
          'data': null,
          'error': {'code': 'FEDERATION_NOT_ELIGIBLE', 'message': 'Make your account public first.'},
          'request_id': 'put-1',
        }),
        409,
      );
    });
    final api = BackendApi(
      baseUri: Uri.parse('https://api.testagram.site'),
      getJwt: () async => 'appwrite-session-jwt',
      client: client,
    );
    addTearDown(api.close);

    await tester.pumpWidget(
      MaterialApp(home: FederationSettingsScreen(api: api)),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byType(SwitchListTile));
    await tester.pumpAndSettle();

    expect(find.text('Your account is not opted in to federation.'), findsOneWidget);
    expect(find.text('Make your account public first.'), findsOneWidget);
  });
}
