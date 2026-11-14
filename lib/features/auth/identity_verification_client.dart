import 'dart:convert';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;

class IdentityApplication {
  const IdentityApplication({
    required this.applicationId,
    required this.applicationToken,
    required this.sessionId,
    required this.sessionToken,
  });

  final String applicationId;
  final String applicationToken;
  final String sessionId;
  final String sessionToken;

  factory IdentityApplication.fromJson(Map<String, dynamic> json) {
    return IdentityApplication(
      applicationId: json['application_id'] as String,
      applicationToken: json['application_token'] as String,
      sessionId: json['verification_session_id'] as String,
      sessionToken: json['verification_session_token'] as String,
    );
  }
}

class IdentityApplicationStatus {
  const IdentityApplicationStatus({
    required this.status,
    required this.verificationStatus,
    required this.sessionId,
  });

  final String status;
  final String verificationStatus;
  final String sessionId;

  factory IdentityApplicationStatus.fromJson(Map<String, dynamic> json) {
    return IdentityApplicationStatus(
      status: json['status'] as String? ?? 'unknown',
      verificationStatus:
          json['adult_verification_status'] as String? ?? 'unknown',
      sessionId: json['verification_session_id'] as String? ?? '',
    );
  }
}

class IdentityProvisioningAuthorization {
  const IdentityProvisioningAuthorization({
    required this.token,
    required this.jti,
  });

  final String token;
  final String jti;

  factory IdentityProvisioningAuthorization.fromJson(Map<String, dynamic> json) {
    return IdentityProvisioningAuthorization(
      token: json['approval_token'] as String,
      jti: json['jti'] as String,
    );
  }
}

class IdentityVerificationClient {
  IdentityVerificationClient({
    required Uri backendOrigin,
    http.Client? client,
  })  : _backendOrigin = backendOrigin,
        _client = client ?? http.Client();

  final Uri _backendOrigin;
  final http.Client _client;

  Uri _endpoint(String path) => _backendOrigin.resolve(path);

  Map<String, dynamic> _decode(http.Response response) {
    final decoded = jsonDecode(response.body);
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('Identity API returned an invalid response.');
    }
    if (response.statusCode < 200 || response.statusCode >= 300) {
      final error = decoded['error'];
      final message = error is Map<String, dynamic>
          ? error['message'] as String?
          : null;
      throw IdentityVerificationException(
        message ?? 'Identity verification request failed (${response.statusCode}).',
        response.statusCode,
      );
    }
    return decoded;
  }

  Future<IdentityApplication> createApplication({
    required String email,
    required String username,
    required String displayName,
    required bool adultConfirmed,
    required bool termsAccepted,
    required bool privacyAccepted,
    required String idempotencyKey,
  }) async {
    final response = await _client.post(
      _endpoint('/api/identity/applications'),
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
        'Idempotency-Key': idempotencyKey,
      },
      body: jsonEncode({
        'email': email.trim().toLowerCase(),
        'username': username.trim().replaceFirst(RegExp(r'^@'), '').toLowerCase(),
        'display_name': displayName.trim(),
        'adult_confirmed': adultConfirmed,
        'terms_accepted': termsAccepted,
        'privacy_accepted': privacyAccepted,
      }),
    );
    return IdentityApplication.fromJson(_decode(response));
  }

  Future<void> uploadAndSubmitEvidence({
    required IdentityApplication application,
    required Uint8List bytes,
    required String contentType,
  }) async {
    final digest = sha256.convert(bytes).toString();
    final reserve = await _client.post(
      _endpoint(
        '/api/identity/sessions/${application.sessionId}/evidence/upload-url',
      ),
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
        'X-Verification-Session-Token': application.sessionToken,
      },
      body: jsonEncode({
        'content_type': contentType,
        'size_bytes': bytes.length,
        'sha256': digest,
      }),
    );
    final reservation = _decode(reserve);
    // Evidence bytes must travel through the authenticated Backend proxy.
    // Never let the API redirect the client to an internal MinIO hostname or
    // expose a raw object-store presigned capability to the mobile app.
    final evidenceId = reservation['evidence_id'] as String;
    final uploadPath = reservation['upload_url'] as String;
    final uploadUrl = _backendOrigin.resolve(uploadPath);
    final expectedPath =
        '/api/identity/sessions/${application.sessionId}/evidence/$evidenceId/upload';
    final expiresIn = reservation['expires_in_seconds'];
    if (reservation['method'] != 'PUT' ||
        reservation['content_type'] != contentType ||
        reservation['size_bytes'] != bytes.length ||
        expiresIn is! int ||
        expiresIn < 1 ||
        expiresIn > 300 ||
        uploadUrl.scheme != 'https' ||
        uploadUrl.origin != _backendOrigin.origin ||
        uploadUrl.userInfo.isNotEmpty ||
        uploadUrl.hasFragment ||
        uploadUrl.hasQuery ||
        uploadUrl.path != expectedPath) {
      throw const FormatException('The evidence service returned an unsafe or mismatched upload reservation.');
    }
    final put = await _client.put(
      uploadUrl,
      headers: {
        'Content-Type': contentType,
        'X-Verification-Session-Token': application.sessionToken,
      },
      body: bytes,
    );
    if (put.statusCode < 200 || put.statusCode >= 300) {
      throw IdentityVerificationException(
        'Private evidence upload failed (${put.statusCode}).',
        put.statusCode,
      );
    }
    final submit = await _client.post(
      _endpoint(
        '/api/identity/sessions/${application.sessionId}/evidence/submit',
      ),
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
        'X-Verification-Session-Token': application.sessionToken,
      },
      body: jsonEncode({'evidence_id': reservation['evidence_id']}),
    );
    _decode(submit);
  }

  Future<IdentityApplicationStatus> getStatus(
    IdentityApplication application,
  ) async {
    final response = await _client.get(
      _endpoint('/api/identity/applications/${application.applicationId}'),
      headers: {'X-Application-Token': application.applicationToken},
    );
    return IdentityApplicationStatus.fromJson(_decode(response));
  }

  Future<IdentityProvisioningAuthorization> requestProvisioningAuthorization(
    IdentityApplication application,
  ) async {
    final response = await _client.post(
      _endpoint(
        '/api/identity/applications/${application.applicationId}/provisioning-token',
      ),
      headers: {
        'Accept': 'application/json',
        'X-Application-Token': application.applicationToken,
      },
    );
    return IdentityProvisioningAuthorization.fromJson(_decode(response));
  }

  Future<Map<String, dynamic>> redeemProvisioningAuthorization({
    required IdentityApplication application,
    required IdentityProvisioningAuthorization authorization,
    required String appwriteJwt,
  }) async {
    final response = await _client.post(
      _endpoint('/api/identity/applications/${application.applicationId}/redeem'),
      headers: {
        'Accept': 'application/json',
        'X-Application-Token': application.applicationToken,
        'X-Identity-Approval-Token': authorization.token,
        'X-Identity-Approval-JTI': authorization.jti,
        'Authorization': 'Bearer $appwriteJwt',
      },
    );
    return _decode(response);
  }

  void close() => _client.close();
}

class IdentityVerificationException implements Exception {
  const IdentityVerificationException(this.message, this.statusCode);

  final String message;
  final int statusCode;

  @override
  String toString() => message;
}
