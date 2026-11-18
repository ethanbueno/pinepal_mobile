import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import '../models/scan_record.dart';
import '../models/server_scan.dart';
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

  // The server runs on a free Render plan: it sleeps after 15 minutes without
  // calls and then needs about a minute to wake up, longer than _timeout. So
  // login and sign up wake it first (wakeUp), and the app pings it on launch.
  // When it last answered, for each server address (any ApiClient counts).
  static final Map<String, DateTime> _lastAnswered = {};
  static final Map<String, Future<void>> _waking = {};
  static const _stillAwake = Duration(minutes: 10);
  static const _wakeLimit = Duration(seconds: 100);
  static const _wakeAttempt = Duration(seconds: 30);

  // Starts waking the server without waiting, for example when the app opens,
  // so it is up by the time the farmer signs in. Failures are ignored.
  static void warmUp({ApiClient? api}) {
    unawaited((api ?? ApiClient()).wakeUp().then((_) {}, onError: (_) {}));
  }

  // Waits until the server answers, for up to about 100 seconds. Returns at
  // once if it answered in the last few minutes. onSlow is called once if the
  // server has not answered after 3 seconds, so the screen can say it is
  // waking up. Throws ApiException when there is no connection or the server
  // never answers.
  Future<void> wakeUp({void Function()? onSlow}) async {
    final base = _baseUrl();
    final last = _lastAnswered[base];
    if (last != null && DateTime.now().difference(last) < _stillAwake) return;

    final slow = onSlow == null
        ? null
        : Timer(const Duration(seconds: 3), onSlow);
    try {
      await (_waking[base] ??= _wake(base).whenComplete(() {
        _waking.remove(base); // not returned: whenComplete would wait on it
      }));
    } finally {
      slow?.cancel();
    }
  }

  Future<void> _wake(String base) async {
    final uri = _uri('/');
    final clock = Stopwatch()..start();
    while (true) {
      final left = _wakeLimit - clock.elapsed;
      try {
        final response = await _client
            .get(uri)
            .timeout(left < _wakeAttempt ? left : _wakeAttempt);
        // 502, 503 and 504 come from Render while the server is starting
        if (response.statusCode < 500) {
          _lastAnswered[base] = DateTime.now();
          return;
        }
      } on TimeoutException {
        // still waking up, ask again
      } on SocketException {
        throw _noConnection;
      } on http.ClientException {
        throw _noConnection;
      }
      if (clock.elapsed + const Duration(seconds: 3) >= _wakeLimit) {
        throw const ApiException(
          'The server is still waking up. Wait a minute and try again.',
          offline: true,
        );
      }
      await Future<void>.delayed(const Duration(seconds: 3));
    }
  }

  static const _noConnection = ApiException(
    'Cannot reach the server. Check your internet connection and try again.',
    offline: true,
  );

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
  // dashboard and History. Works with an account token or this phone's own
  // token.
  Future<List<ServerScan>> getMyScans({required String token}) async {
    final request = http.Request('GET', _uri('/api/mobile/scans'));
    request.headers['Authorization'] = 'Bearer $token';
    final json = await _send(request, _timeout);
    final rows = json['scans'] as List<dynamic>? ?? [];
    return rows
        .map((row) => ServerScan.fromJson(row as Map<String, dynamic>))
        .toList();
  }

  // The signed-in user's own details (needs an account token, not the phone's)
  Future<UserProfile> getProfile({required String token}) async {
    return UserProfile.fromJson(
      await _sendJson('GET', '/api/profile', null, token),
    );
  }

  // Edit profile: only the details passed are sent, and the server leaves the
  // rest as they are. A new username, email or password needs the current
  // password too (the server checks it). clearFarmSize empties the farm size.
  // Role, farmer ID, municipality and farm location are ignored by the server.
  Future<UserProfile> updateProfile({
    required String token,
    String? fullName,
    String? username,
    String? email,
    String? newPassword,
    String? farmName,
    double? farmSizeHa,
    bool clearFarmSize = false,
    String? currentPassword,
  }) async {
    return UserProfile.fromJson(
      await _sendJson('PUT', '/api/profile', {
        'full_name': ?fullName,
        'username': ?username,
        'email': ?email,
        'new_password': ?newPassword,
        'farm_name': ?farmName,
        if (clearFarmSize)
          'farm_size_ha': null
        else
          'farm_size_ha': ?farmSizeHa,
        'current_password': ?currentPassword,
      }, token),
    );
  }

  // A new profile photo (kind 'avatar') or cover photo (kind 'cover'), a JPG
  // or PNG on the phone. The server keeps it on Cloudinary and returns the
  // updated profile.
  Future<UserProfile> uploadProfilePhoto({
    required String token,
    required String kind,
    required String path,
  }) async {
    final request = http.MultipartRequest(
      'POST',
      _uri('/api/profile/photo/$kind'),
    );
    request.headers['Authorization'] = 'Bearer $token';
    request.files.add(await http.MultipartFile.fromPath('photo', path));
    return UserProfile.fromJson(await _send(request, _uploadTimeout));
  }

  // Removes the profile or cover photo; the Account tab goes back to the
  // initials and the plain cover
  Future<UserProfile> removeProfilePhoto({
    required String token,
    required String kind,
  }) async {
    return UserProfile.fromJson(
      await _sendJson('DELETE', '/api/profile/photo/$kind', null, token),
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
        'The server took too long to answer. Try again in a moment.',
        offline: true,
      );
    } on SocketException {
      throw _noConnection;
    } on http.ClientException {
      throw _noConnection;
    }

    if (response.statusCode < 500) {
      _lastAnswered[_baseUrl()] = DateTime.now();
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
    // Render's own page while the server starts up or restarts
    if (const [502, 503, 504].contains(response.statusCode) &&
        message is! String) {
      throw ApiException(
        'The server is starting up. Wait a minute and try again.',
        statusCode: response.statusCode,
        offline: true,
      );
    }
    throw ApiException(
      message is String && message.isNotEmpty
          ? message
          : 'The server returned an error (${response.statusCode}).',
      statusCode: response.statusCode,
    );
  }
}
