import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'dashboard_cache.dart';

// The signed-in account, as the web backend describes it.
class AuthUser {
  final int id;
  final String fullName;
  final String username;
  final String role; // admin, officer or farmer
  final String?
  farmerId; // the account's row in the farmers table (F069), farmers only

  const AuthUser({
    required this.id,
    required this.fullName,
    required this.username,
    required this.role,
    this.farmerId,
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
      farmerId: json['farmer_id'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'full_name': fullName,
    'username': username,
    'role': role,
    'farmer_id': farmerId,
  };
}

// A phone used without an account gets its own farmer ID on the server (F070),
// so its scans can sync before anyone signs in. Signing in or creating an
// account on this phone connects that farmer ID and its scans to the account.
class PhoneFarmer {
  final String farmerId;
  final String token; // only uploads scans for this farmer ID

  const PhoneFarmer({required this.farmerId, required this.token});

  factory PhoneFarmer.fromJson(Map<String, dynamic> json) => PhoneFarmer(
    farmerId: json['farmer_id'] as String,
    token: json['device_token'] as String,
  );

  Map<String, dynamic> toJson() => {
    'farmer_id': farmerId,
    'device_token': token,
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
  SecureSessionStore([this._key = 'session']);

  final String _key;
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

// Who is signed in, and this phone's own farmer ID for syncing without an
// account. Scanning works without an account.
class AuthController extends ChangeNotifier {
  AuthController({SessionStore? store, SessionStore? phoneStore})
    : _store = store ?? SecureSessionStore(),
      // tests that pass a store keep the phone's farmer ID in memory too
      _phoneStore =
          phoneStore ??
          (store == null
              ? SecureSessionStore('phone_farmer')
              : MemorySessionStore());

  static final instance = AuthController();

  final SessionStore _store;
  final SessionStore _phoneStore;
  AuthSession? _session;
  PhoneFarmer? _phone;

  AuthSession? get session => _session;
  AuthUser? get user => _session?.user;
  String? get token => _session?.token;
  bool get isSignedIn => _session != null;
  PhoneFarmer? get phoneFarmer => _phone;

  Future<void> load() async {
    try {
      final raw = await _store.read();
      if (raw != null) {
        final json = jsonDecode(raw) as Map<String, dynamic>;
        _session = AuthSession(
          token: json['token'] as String,
          user: AuthUser.fromJson(json['user'] as Map<String, dynamic>),
        );
      }
    } catch (_) {
      // unreadable or missing: the farmer just signs in again
    }
    try {
      final raw = await _phoneStore.read();
      if (raw != null) {
        _phone = PhoneFarmer.fromJson(jsonDecode(raw) as Map<String, dynamic>);
      }
    } catch (_) {
      // the phone gets a new farmer ID on its next sync
    }
    notifyListeners();
  }

  // Signing in connects this phone's farmer ID to the account (the server did
  // that during login), so the phone no longer needs its own.
  Future<void> signIn(AuthSession session) async {
    _session = session;
    await setPhoneFarmer(null);
    try {
      await _store.write(
        jsonEncode({'token': session.token, 'user': session.user.toJson()}),
      );
    } catch (_) {
      // signed in for this launch even if it could not be remembered
    }
  }

  // After My profile saves a new name or username, so the app shows it right
  // away and keeps it after a restart. The token stays the same.
  Future<void> updateAccount({String? fullName, String? username}) async {
    final session = _session;
    if (session == null) return;
    final old = session.user;
    await signIn(
      AuthSession(
        token: session.token,
        user: AuthUser(
          id: old.id,
          fullName: fullName ?? old.fullName,
          username: username ?? old.username,
          role: old.role,
          farmerId: old.farmerId,
        ),
      ),
    );
  }

  Future<void> setPhoneFarmer(PhoneFarmer? phone) async {
    _phone = phone;
    notifyListeners();
    try {
      await _phoneStore.write(
        phone == null ? null : jsonEncode(phone.toJson()),
      );
    } catch (_) {
      // kept for this launch only
    }
  }

  Future<void> signOut() async {
    _session = null;
    notifyListeners();
    await DashboardCache.clearAll(); // the next person must not see these numbers
    try {
      await _store.write(null);
    } catch (_) {
      // nothing more to do
    }
  }
}
