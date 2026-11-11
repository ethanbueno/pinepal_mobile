import 'package:flutter/material.dart';

import '../models/user_profile.dart';
import '../services/api_client.dart';
import '../services/app_settings.dart';
import '../services/auth_controller.dart';
import '../theme/app_colors.dart';
import '../utils/format.dart';
import '../widgets/labeled_field.dart';
import '../widgets/section_card.dart';

const _minPassword = 6; // same as MIN_PASSWORD in the web backend

// The signed-in user's own details, from the server. Only the name, and for
// farmers the farm name and size, can be changed here, plus the password.
// The important details (username, email, role, farmer ID, municipality...)
// are shown with a lock: only an admin or officer can change them.
class MyProfileScreen extends StatefulWidget {
  const MyProfileScreen({super.key, this.api, this.auth, this.settings});

  // Leave empty to use the shared ones
  final ApiClient? api;
  final AuthController? auth;
  final AppSettings? settings;

  @override
  State<MyProfileScreen> createState() => _MyProfileScreenState();
}

class _MyProfileScreenState extends State<MyProfileScreen> {
  late final _api = widget.api ?? ApiClient();
  late final _auth = widget.auth ?? AuthController.instance;
  late final _settings = widget.settings ?? AppSettings.instance;

  UserProfile? _profile;
  String? _loadError;

  final _fullName = TextEditingController();
  final _farmName = TextEditingController();
  final _farmSize = TextEditingController();
  bool _saving = false;

  final _current = TextEditingController();
  final _next = TextEditingController();
  final _confirm = TextEditingController();
  bool _changing = false;
  String? _passwordError;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    for (final c in [
      _fullName,
      _farmName,
      _farmSize,
      _current,
      _next,
      _confirm,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  void _fill(UserProfile p) {
    _fullName.text = p.fullName;
    _farmName.text = p.farm?.farmName ?? '';
    final size = p.farm?.sizeHa;
    _farmSize.text = size == null ? '' : size.toString();
  }

  Future<void> _load() async {
    setState(() => _loadError = null);
    try {
      final p = await _api.getProfile(token: _auth.token!);
      if (!mounted) return;
      _fill(p);
      setState(() => _profile = p);
    } catch (e) {
      if (mounted) setState(() => _loadError = '$e');
    }
  }

  void _say(String text) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  Future<void> _save() async {
    final name = _fullName.text.trim();
    if (name.isEmpty) {
      _say('Enter your full name.');
      return;
    }
    final isFarmer = _profile!.role == 'farmer';
    double? size;
    if (isFarmer && _farmSize.text.trim().isNotEmpty) {
      size = double.tryParse(_farmSize.text.trim());
      if (size == null || size < 0) {
        _say('Farm size must be a number.');
        return;
      }
    }

    setState(() => _saving = true);
    try {
      final p = await _api.updateProfile(
        token: _auth.token!,
        fullName: name,
        farmName: isFarmer ? _farmName.text.trim() : null,
        farmSizeHa: size,
      );
      await _auth.updateFullName(p.fullName);
      // new scans carry the farm name too, so it stays the same as the server's
      if (isFarmer) await _settings.setFarmName(p.farm?.farmName ?? '');
      if (!mounted) return;
      _fill(p);
      setState(() => _profile = p);
      _say('Profile saved.');
    } catch (e) {
      if (mounted) _say('$e');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _changePassword() async {
    setState(() => _passwordError = null);
    if (_current.text.isEmpty) {
      setState(() => _passwordError = 'Enter your current password.');
      return;
    }
    if (_next.text.length < _minPassword) {
      setState(
        () => _passwordError =
            'The new password must be at least $_minPassword characters.',
      );
      return;
    }
    if (_next.text != _confirm.text) {
      setState(() => _passwordError = 'The new passwords do not match.');
      return;
    }

    setState(() => _changing = true);
    try {
      await _api.changePassword(
        token: _auth.token!,
        currentPassword: _current.text,
        newPassword: _next.text,
      );
      _current.clear();
      _next.clear();
      _confirm.clear();
      if (mounted) _say('Password changed.');
    } catch (e) {
      if (mounted) setState(() => _passwordError = '$e');
    } finally {
      if (mounted) setState(() => _changing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('My profile')),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_loadError != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.page),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Could not load your profile.\n$_loadError',
                textAlign: TextAlign.center,
                style: TextStyle(color: context.colors.textMuted),
              ),
              const SizedBox(height: 12),
              OutlinedButton(onPressed: _load, child: const Text('Try again')),
            ],
          ),
        ),
      );
    }
    final p = _profile;
    if (p == null) return const Center(child: CircularProgressIndicator());

    final isFarmer = p.role == 'farmer';
    final farm = p.farm;
    return ListView(
      padding: const EdgeInsets.all(AppSpacing.page),
      children: [
        Text(
          'Details with a lock can only be changed by an admin or officer.',
          style: TextStyle(color: context.colors.textMuted, fontSize: 13),
        ),
        const SizedBox(height: 12),
        SectionCard(
          title: 'Edit details',
          children: [
            LabeledField(
              label: 'Full name',
              controller: _fullName,
              enabled: !_saving,
              textInputAction: TextInputAction.next,
            ),
            if (isFarmer) ...[
              const SizedBox(height: 12),
              LabeledField(
                label: 'Farm name',
                hint: 'For example: Bueno Farm',
                controller: _farmName,
                enabled: !_saving,
                textInputAction: TextInputAction.next,
              ),
              const SizedBox(height: 12),
              LabeledField(
                label: 'Farm size (hectares)',
                controller: _farmSize,
                enabled: !_saving,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
              ),
            ],
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                onPressed: _saving ? null : _save,
                child: Text(_saving ? 'Saving...' : 'Save changes'),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        SectionCard(
          title: 'Account',
          children: [
            _locked('Username', '@${p.username}'),
            _locked('Email', p.email),
            _locked('Role', _roleLabel(p.role)),
            _locked(
              'Member since',
              p.createdAt == null ? null : formatDate(p.createdAt!),
            ),
          ],
        ),
        if (isFarmer) ...[
          const SizedBox(height: 12),
          SectionCard(
            title: 'Farm',
            children: farm == null
                ? [
                    Text(
                      'No farm is linked to your account yet.',
                      style: TextStyle(color: context.colors.textMuted),
                    ),
                  ]
                : [
                    _locked('Farmer ID', farm.farmerId),
                    _locked('Municipality', farm.municipality),
                    _locked(
                      'Farm location',
                      farm.latitude == null
                          ? 'Not set yet'
                          : '${farm.latitude!.toStringAsFixed(5)}, '
                                '${farm.longitude!.toStringAsFixed(5)}',
                    ),
                    _locked('Status', farm.isActive ? 'Active' : 'Deactivated'),
                    _locked(
                      'Registered',
                      farm.registeredAt == null
                          ? null
                          : formatDate(farm.registeredAt!),
                    ),
                    _locked('Scans on the server', '${farm.totalScans}'),
                  ],
          ),
        ],
        const SizedBox(height: 12),
        SectionCard(
          title: 'Change password',
          children: [
            LabeledField(
              label: 'Current password',
              controller: _current,
              obscure: true,
              enabled: !_changing,
              textInputAction: TextInputAction.next,
            ),
            const SizedBox(height: 12),
            LabeledField(
              label: 'New password',
              hint: 'At least $_minPassword characters',
              controller: _next,
              obscure: true,
              enabled: !_changing,
              textInputAction: TextInputAction.next,
            ),
            const SizedBox(height: 12),
            LabeledField(
              label: 'Confirm new password',
              controller: _confirm,
              obscure: true,
              enabled: !_changing,
              onSubmitted: (_) => _changePassword(),
            ),
            if (_passwordError != null) ...[
              const SizedBox(height: 10),
              Text(
                _passwordError!,
                style: TextStyle(color: context.colors.danger, fontSize: 13),
              ),
            ],
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                onPressed: _changing ? null : _changePassword,
                child: Text(_changing ? 'Changing...' : 'Change password'),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
      ],
    );
  }

  // Same labels as AuthUser.roleLabel and the web (src/utils/roles.js)
  String _roleLabel(String role) => switch (role) {
    'admin' => 'Admin',
    'officer' => 'Agricultural Officer',
    'farmer' => 'Farmer',
    _ => role,
  };

  // A detail that can be seen but not changed here
  Widget _locked(String label, String? value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.lock_outline, size: 16, color: context.colors.textMuted),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              label,
              style: TextStyle(color: context.colors.textMuted, fontSize: 14),
            ),
          ),
          const SizedBox(width: 12),
          Flexible(
            child: Text(
              (value == null || value.isEmpty) ? '–' : value,
              textAlign: TextAlign.right,
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }
}
