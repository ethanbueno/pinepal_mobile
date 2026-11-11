import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import '../models/dashboard_stats.dart';
import '../models/scan_record.dart';
import '../models/user_profile.dart';
import 'app_settings.dart';
import 'auth_controller.dart';

// Something went wrong talking to the server. The message is written for the
// farmer, so it can be shown as it is.
class ApiException implements Exception {
  final String message;
  final int? statusCode;

  // True when the server could not be reached at all (no signal, wrong address,
  // too slow). Trying the next scan right away would fail the same way.
  final bool offline;

  const ApiException(this.message, {this.statusCode, this.offline = false});

  // The token is missing, wrong or has run out
  bool get unauthorized => statusCode == 401;

  @override
  String toString() => message;
}

// The calls the app makes to the PinePal Flask backend (backend/mobile_sync.py
// and backend/web_auth.py in the web project).
class ApiClient {
  ApiClient({http.Client? client, String Function()? baseUrl})
    : _client = client ?? http.Client(),
      _baseUrl = baseUrl ?? (() => AppSettings.instance.serverUrl);

  final http.Client _client;
  final String Function()
  _baseUrl; // read on every call, so Settings apply at once

  static const _timeout = Duration(seconds: 20);
  static const _uploadTimeout = Duration(seconds: 60);

  // Same login as the web, but the token lasts 30 days, so a farmer who scans
  // offline for days can still sync without signing in again. With the phone's
  // own farmer ID token, the server connects that farmer ID and its scans to
  // the account (or moves them into the farmer ID the account already has).
  Future<AuthSession> login(
    String username,
    String password, {
    String? deviceToken,
  }) async {
    final json = await _sendJson('POST', '/api/mobile/login', {
      'username': username,
      'password': password,
      'device_token': ?deviceToken,
    });
    return AuthSession(
      token: json['access_token'] as String,
      user: AuthUser.fromJson(json['user'] as Map<String, dynamic>),
    );
  }

  // Sign up only ever creates farmer accounts (the server enforces it). With
  // the phone's own farmer ID token, the new account keeps that farmer ID.
  Future<void> register({
    required String fullName,
    required String username,
    required String email,
    required String password,
    String? deviceToken,
  }) async {
    await _sendJson('POST', '/api/auth/register', {
      'full_name': fullName,
      'username': username,
      'email': email,
      'password': password,
      'role': 'farmer',
      'device_token': ?deviceToken,
    });
  }

  // Gives this phone its own farmer ID, for syncing before anyone signs in
  Future<PhoneFarmer> registerPhone() async {
    return PhoneFarmer.fromJson(await _sendJson('POST', '/api/mobile/device'));
  }

  // Sends one scan with its photo. The server uses scan_uuid to tell scans
  // apart, so sending the same scan again updates it instead of duplicating it.
  Future<void> uploadScan(
    ScanRecord scan, {
    required String token,
    String? farmName,
    String? municipality,
  }) async {
    final request = http.MultipartRequest('POST', _uri('/api/mobile/scans'));
    request.headers['Authorization'] = 'Bearer $token';

    void field(String name, Object? value) {
      final text = value?.toString() ?? '';
      if (text.isNotEmpty) request.fields[name] = text;
    }

    field('scan_uuid', scan.scanUuid);
    field('predicted_label', scan.predictedLabel);
    field('confidence', scan.confidence);
    field('second_label', scan.secondLabel);
    field('second_confidence', scan.secondConfidence);
    field('latitude', scan.latitude);
    field('longitude', scan.longitude);
    field('scanned_at', scan.scannedAt.toIso8601String());
    field('image_source', scan.imageSource);
    field('municipality', municipality);
    field('farm_name', farmName);
    field('notes', scan.notes);
    field('farmer_feedback', scan.feedback?.name);
    field('farmer_label', scan.verifiedLabel);

    // The photo may have been deleted from the phone; the scan is still sent
    if (await File(scan.imagePath).exists()) {
      request.files.add(
        await http.MultipartFile.fromPath('image', scan.imagePath),
      );
    }

    await _send(request, _uploadTimeout);
  }

  // The farmer's own scans on the server, for the Online view of the
  // dashboard. Works with an account token or this phone's own token.
  Future<List<DashboardScan>> getMyScans({required String token}) async {
    final request = http.Request('GET', _uri('/api/mobile/scans'));
    request.headers['Authorization'] = 'Bearer $token';
    final json = await _send(request, _timeout);
    final rows = json['scans'] as List<dynamic>? ?? [];
    return rows
        .map((row) => DashboardScan.fromJson(row as Map<String, dynamic>))
        .toList();
  }

  // The signed-in user's own details (needs an account token, not the phone's)
  Future<UserProfile> getProfile({required String token}) async {
    return UserProfile.fromJson(
      await _sendJson('GET', '/api/profile', null, token),
    );
  }

  // Only the name, farm name and farm size are saved; the server ignores the
  // rest, so the important details can't be changed from the app.
  Future<UserProfile> updateProfile({
    required String token,
    required String fullName,
    String? farmName,
    double? farmSizeHa,
  }) async {
    return UserProfile.fromJson(
      await _sendJson('PUT', '/api/profile', {
        'full_name': fullName,
        'farm_name': ?farmName,
        'farm_size_ha': ?farmSizeHa,
      }, token),
    );
  }

  Future<void> changePassword({
    required String token,
    required String currentPassword,
    required String newPassword,
  }) async {
    await _sendJson('POST', '/api/profile/password', {
      'current_password': currentPassword,
      'new_password': newPassword,
    }, token);
  }

  // Used by "Test connection" in Settings
  Future<String> ping() async {
    final json = await _sendJson('GET', '/');
    return json['message']?.toString() ?? 'Connected';
  }

  Uri _uri(String path) {
    try {
      final uri = Uri.parse('${_baseUrl()}$path');
      if (!uri.hasAuthority) throw const FormatException('no host');
      return uri;
    } on FormatException {
      throw const ApiException('The server address is not valid.');
    }
  }

  Future<Map<String, dynamic>> _sendJson(
    String method,
    String path, [
    Map<String, dynamic>? body,
    String? token,
  ]) async {
    final request = http.Request(method, _uri(path));
    if (token != null) request.headers['Authorization'] = 'Bearer $token';
    if (body != null) {
      request.headers['Content-Type'] = 'application/json';
      request.body = jsonEncode(body);
    }
    return _send(request, _timeout);
  }

  Future<Map<String, dynamic>> _send(
    http.BaseRequest request,
    Duration timeout,
  ) async {
    final http.Response response;
    try {
      final streamed = await _client.send(request).timeout(timeout);
      response = await http.Response.fromStream(streamed).timeout(timeout);
    } on TimeoutException {
      throw const ApiException(
        'The server took too long to answer.',
        offline: true,
      );
    } on SocketException {
      throw const ApiException(
        'Cannot reach the server. Check your internet connection and try again.',
        offline: true,
      );
    } on http.ClientException {
      throw const ApiException(
        'Cannot reach the server. Check your internet connection and try again.',
        offline: true,
      );
    }

    Map<String, dynamic> json = {};
    try {
      final decoded = response.body.isEmpty ? null : jsonDecode(response.body);
      if (decoded is Map<String, dynamic>) json = decoded;
    } on FormatException {
      // not JSON (for example an error page), handled below
    }

    if (response.statusCode >= 200 && response.statusCode < 300) return json;

    final message = json['error'] ?? json['message'];
    throw ApiException(
      message is String && message.isNotEmpty
          ? message
          : 'The server returned an error (${response.statusCode}).',
      statusCode: response.statusCode,
    );
  }
}
