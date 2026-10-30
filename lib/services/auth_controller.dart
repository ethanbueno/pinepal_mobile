import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

// The signed-in account, as the web backend describes it.
class AuthUser {
  final int id;
  final String fullName;
  final String username;
  final String role; // admin, officer or farmer

  const AuthUser({
    required this.id,
    required this.fullName,
    required this.username,
    required this.role,
  });

  // Same labels as the web dashboard (src/utils/roles.js)
  String get roleLabel {
    switch (role) {
      case 'admin':
        return 'Admin';
      case 'officer':
        return 'Agricultural Officer';
      case 'farmer':
        return 'Farmer';
      default:
        return role;
    }
  }

  String get initials {
    final parts = fullName
        .trim()
        .split(RegExp(r'\s+'))
        .where((p) => p.isNotEmpty);
    final letters = parts.take(2).map((p) => p[0]).join().toUpperCase();
    return letters.isEmpty ? '?' : letters;
  }

  factory AuthUser.fromJson(Map<String, dynamic> json) {
    return AuthUser(
      id: (json['id'] as num).toInt(),
      fullName: json['full_name'] as String? ?? '',
      username: json['username'] as String? ?? '',
      role: json['role'] as String? ?? 'farmer',
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'full_name': fullName,
    'username': username,
    'role': role,
  };
}

// What a successful login gives back
class AuthSession {
  final String token;
  final AuthUser user;

  const AuthSession({required this.token, required this.user});
}

// Where the session is kept between launches
abstract class SessionStore {
  Future<String?> read();
  Future<void> write(String? value); // null removes it
}

// The token is a password for the account, so it goes in the phone's secure
// storage (Keystore on Android, Keychain on iOS), not in plain preferences.
class SecureSessionStore implements SessionStore {
  static const _key = 'session';
  final FlutterSecureStorage _storage = const FlutterSecureStorage();

  @override
  Future<String?> read() => _storage.read(key: _key);

  @override
  Future<void> write(String? value) async {
    if (value == null) {
      await _storage.delete(key: _key);
    } else {
      await _storage.write(key: _key, value: value);
    }
  }
}

// For tests
class MemorySessionStore implements SessionStore {
  String? value;

  @override
  Future<String?> read() async => value;

  @override
  Future<void> write(String? value) async => this.value = value;
}

// Who is signed in. Scanning works without an account; signing in is only
// needed to sync scans to the server.
class AuthController extends ChangeNotifier {
  AuthController({SessionStore? store})
    : _store = store ?? SecureSessionStore();

  static final instance = AuthController();

  final SessionStore _store;
  AuthSession? _session;

  AuthSession? get session => _session;
  AuthUser? get user => _session?.user;
  String? get token => _session?.token;
  bool get isSignedIn => _session != null;

  Future<void> load() async {
    try {
      final raw = await _store.read();
      if (raw == null) return;
      final json = jsonDecode(raw) as Map<String, dynamic>;
      _session = AuthSession(
        token: json['token'] as String,
        user: AuthUser.fromJson(json['user'] as Map<String, dynamic>),
      );
      notifyListeners();
    } catch (_) {
      // unreadable or missing: the farmer just signs in again
    }
  }

  Future<void> signIn(AuthSession session) async {
    _session = session;
    notifyListeners();
    try {
      await _store.write(
        jsonEncode({'token': session.token, 'user': session.user.toJson()}),
      );
    } catch (_) {
      // signed in for this launch even if it could not be remembered
    }
  }

  Future<void> signOut() async {
    _session = null;
    notifyListeners();
    try {
      await _store.write(null);
    } catch (_) {
      // nothing more to do
    }
  }
}
