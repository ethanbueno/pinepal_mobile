// The signed-in user's own details from the server (GET /api/profile in
// backend/my_profile.py). Only the name, and for farmers the farm name and
// size, can be changed from the app; the rest is shown locked.
class UserProfile {
  final String fullName;
  final String username;
  final String? email;
  final String role;
  final String
  municipality; // users.municipality; a farmer's matches the farm's
  final DateTime? createdAt;
  final ProfileFarm? farm; // farmers only, and only once a farm is linked
  // The photos on the Account tab (Cloudinary URLs), null until one is chosen
  final String? avatarUrl;
  final String? coverUrl;

  const UserProfile({
    required this.fullName,
    required this.username,
    required this.role,
    this.municipality = '',
    this.email,
    this.createdAt,
    this.farm,
    this.avatarUrl,
    this.coverUrl,
  });

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    final account = json['account'] as Map<String, dynamic>;
    final farm = json['farm'];
    return UserProfile(
      fullName: account['full_name'] as String? ?? '',
      username: account['username'] as String? ?? '',
      email: account['email'] as String?,
      role: account['role'] as String? ?? 'farmer',
      municipality: account['municipality'] as String? ?? '',
      createdAt: DateTime.tryParse(account['created_at'] as String? ?? ''),
      farm: farm is Map<String, dynamic> ? ProfileFarm.fromJson(farm) : null,
      avatarUrl: _url(account['avatar_url']),
      coverUrl: _url(account['cover_url']),
    );
  }
}

String? _url(Object? value) =>
    value is String && value.isNotEmpty ? value : null;

class ProfileFarm {
  final String farmerId;
  final String farmName;
  final String municipality;
  final double? sizeHa;
  final double? latitude;
  final double? longitude;
  final bool isActive;
  final DateTime? registeredAt;
  final int totalScans;

  const ProfileFarm({
    required this.farmerId,
    required this.farmName,
    required this.municipality,
    required this.isActive,
    required this.totalScans,
    this.sizeHa,
    this.latitude,
    this.longitude,
    this.registeredAt,
  });

  factory ProfileFarm.fromJson(Map<String, dynamic> json) {
    double? number(Object? value) => (value as num?)?.toDouble();
    return ProfileFarm(
      farmerId: json['farmer_id'] as String? ?? '',
      farmName: json['farm_name'] as String? ?? '',
      municipality: json['municipality'] as String? ?? '',
      sizeHa: number(json['farm_size_ha']),
      latitude: number(json['farm_latitude']),
      longitude: number(json['farm_longitude']),
      isActive: json['is_active'] as bool? ?? true,
      registeredAt: DateTime.tryParse(json['registered_at'] as String? ?? ''),
      totalScans: (json['total_scans'] as num?)?.toInt() ?? 0,
    );
  }
}
