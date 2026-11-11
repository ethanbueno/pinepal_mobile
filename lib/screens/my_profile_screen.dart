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

  // Saves the Edit profile sheet. Returns true when it worked, so the sheet closes.
  Future<bool> _save() async {
    final name = _fullName.text.trim();
    if (name.isEmpty) {
      _say('Enter your full name.');
      return false;
    }
    final isFarmer = _profile!.role == 'farmer';
    double? size;
    if (isFarmer && _farmSize.text.trim().isNotEmpty) {
      size = double.tryParse(_farmSize.text.trim());
      if (size == null || size < 0) {
        _say('Farm size must be a number.');
        return false;
      }
    }

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
      if (!mounted) return true;
      _fill(p);
      setState(() => _profile = p);
      _say('Profile saved.');
      return true;
    } catch (e) {
      if (mounted) _say('$e');
      return false;
    }
  }

  // The floating Edit profile button: a sheet with the few details that can
  // change. It starts on what is saved every time it opens.
  Future<void> _openEdit() {
    _fill(_profile!);
    final isFarmer = _profile!.role == 'farmer';
    var saving = false;
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) => StatefulBuilder(
        builder: (sheetContext, setSheet) => Padding(
          // moves up with the keyboard
          padding: EdgeInsets.fromLTRB(
            20,
            4,
            20,
            20 + MediaQuery.of(sheetContext).viewInsets.bottom,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Edit profile',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                ),
                const SizedBox(height: 4),
                Text(
                  isFarmer
                      ? 'You can change your name, farm name and farm size. '
                            'Ask your agricultural officer to change anything else.'
                      : 'You can change your name. Ask an admin to change '
                            'anything else.',
                  style: TextStyle(
                    color: sheetContext.colors.textMuted,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 16),
                LabeledField(
                  label: 'Full name',
                  controller: _fullName,
                  enabled: !saving,
                  textInputAction: isFarmer
                      ? TextInputAction.next
                      : TextInputAction.done,
                ),
                if (isFarmer) ...[
                  const SizedBox(height: 12),
                  LabeledField(
                    label: 'Farm name',
                    hint: 'For example: Bueno Farm',
                    controller: _farmName,
                    enabled: !saving,
                    textInputAction: TextInputAction.next,
                  ),
                  const SizedBox(height: 12),
                  LabeledField(
                    label: 'Farm size (hectares)',
                    controller: _farmSize,
                    enabled: !saving,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                  ),
                ],
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    onPressed: saving
                        ? null
                        : () async {
                            setSheet(() => saving = true);
                            final ok = await _save();
                            if (ok && sheetContext.mounted) {
                              Navigator.pop(sheetContext);
                            } else if (sheetContext.mounted) {
                              setSheet(() => saving = false);
                            }
                          },
                    child: Text(saving ? 'Saving...' : 'Save changes'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
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
      // floating at the bottom of the screen, once the profile has loaded
      floatingActionButton: _profile == null
          ? null
          : FloatingActionButton.extended(
              onPressed: _openEdit,
              icon: const Icon(Icons.edit_outlined),
              label: const Text('Edit profile'),
            ),
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
      // the bottom padding keeps the last card clear of the Edit profile button
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.page,
        AppSpacing.page,
        AppSpacing.page,
        96,
      ),
      children: [
        Text(
          'Details with a lock can only be changed by an admin or officer.',
          style: TextStyle(color: context.colors.textMuted, fontSize: 13),
        ),
        const SizedBox(height: 12),
        SectionCard(
          title: 'Personal details',
          children: [
            Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: context.colors.surface2,
                    borderRadius: BorderRadius.circular(AppRadius.control),
                  ),
                  child: Text(
                    _initials(p.fullName),
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        p.fullName,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        _roleLabel(p.role),
                        style: TextStyle(
                          color: context.colors.textMuted,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            _detail('Full name', p.fullName),
            _locked('Username', '@${p.username}'),
            _locked('Email', p.email),
            _locked('Role', _roleLabel(p.role)),
            _greyedMunicipality(p.municipality),
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
                    _detail('Farm name', farm.farmName),
                    _detail(
                      'Farm size',
                      farm.sizeHa == null ? null : '${farm.sizeHa} ha',
                    ),
                    _locked('Farmer ID', farm.farmerId),
                    _greyedMunicipality(farm.municipality),
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

  String _initials(String name) {
    final letters = name
        .trim()
        .split(RegExp(r'\s+'))
        .where((part) => part.isNotEmpty)
        .take(2)
        .map((part) => part[0])
        .join()
        .toUpperCase();
    return letters.isEmpty ? '?' : letters;
  }

  // A detail that can be seen but not changed here
  Widget _locked(String label, String? value) =>
      _detail(label, value, locked: true);

  // The municipality: greyed out like a disabled field, since PinePal only
  // covers Echague for now
  Widget _greyedMunicipality(String? value) => Opacity(
    opacity: 0.5,
    child: _detail(
      'Municipality',
      value,
      locked: true,
      note: 'Echague only for now',
      muted: true,
    ),
  );

  // One detail. A locked one gets a lock; the others change with Edit profile.
  // muted shows the value in grey instead of bold; note is a line under it.
  Widget _detail(
    String label,
    String? value, {
    bool locked = false,
    bool muted = false,
    String? note,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // same width with or without the lock, so the labels line up
          SizedBox(
            width: 16,
            child: locked
                ? Icon(
                    Icons.lock_outline,
                    size: 16,
                    color: context.colors.textMuted,
                  )
                : null,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              label,
              style: TextStyle(color: context.colors.textMuted, fontSize: 14),
            ),
          ),
          const SizedBox(width: 12),
          Flexible(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  (value == null || value.isEmpty) ? '–' : value,
                  textAlign: TextAlign.right,
                  style: muted
                      ? TextStyle(fontSize: 14, color: context.colors.textMuted)
                      : const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                ),
                if (note != null)
                  Text(
                    note,
                    textAlign: TextAlign.right,
                    style: TextStyle(
                      fontSize: 12,
                      color: context.colors.textMuted,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
