import 'package:flutter/material.dart';

import '../models/user_profile.dart';
import '../services/api_client.dart';
import '../services/app_settings.dart';
import '../services/auth_controller.dart';
import '../theme/app_colors.dart';
import '../utils/format.dart';
import '../utils/password_rules.dart';
import '../widgets/auth_widgets.dart';
import '../widgets/labeled_field.dart';
import '../widgets/section_card.dart';
import 'pinepal_loader.dart';

const _echagueOnly = 'Echague only for now';

// What Edit profile can change, one at a time, same as the web (EDITABLE in
// src/pages/Profile.jsx). secure = a sign-in detail, which needs the current
// password first (the server checks it too). farmOnly = farmers with a farm.
class _Editable {
  final String key;
  final String label;
  final bool secure;
  final bool farmOnly;
  const _Editable(
    this.key,
    this.label, {
    this.secure = false,
    this.farmOnly = false,
  });
}

const _editable = [
  _Editable('full_name', 'Full name'),
  _Editable('username', 'Username', secure: true),
  _Editable('email', 'Email', secure: true),
  _Editable('new_password', 'Password', secure: true),
  _Editable('farm_name', 'Farm name', farmOnly: true),
  _Editable('farm_size_ha', 'Farm size', farmOnly: true),
];

// The signed-in user's own details, from the server, laid out like the web's
// My profile: a cover with the name, Overview and Farm for farmers, then
// Personal info. Edit profile lists what can be changed; each detail is
// changed on its own and only that detail is sent. It sits at the top of the
// Profile tab, as a column of cards.
class MyProfileView extends StatefulWidget {
  const MyProfileView({super.key, this.api, this.auth, this.settings});

  // Leave empty to use the shared ones
  final ApiClient? api;
  final AuthController? auth;
  final AppSettings? settings;

  @override
  State<MyProfileView> createState() => _MyProfileViewState();
}

class _MyProfileViewState extends State<MyProfileView> {
  late final _api = widget.api ?? ApiClient();
  late final _auth = widget.auth ?? AuthController.instance;
  late final _settings = widget.settings ?? AppSettings.instance;

  UserProfile? _profile;
  String? _loadError;

  // The Edit profile sheet: the one detail being changed, or null
  String? _field;
  final _value = TextEditingController();
  final _confirm = TextEditingController(); // the new password again
  final _current = TextEditingController(); // for sign-in details
  String? _formError;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _value.dispose();
    _confirm.dispose();
    _current.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loadError = null);
    try {
      final p = await _api.getProfile(token: _auth.token!);
      if (mounted) setState(() => _profile = p);
    } catch (e) {
      if (mounted) setState(() => _loadError = '$e');
    }
  }

  void _say(String text) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  // The saved value of a detail, as the form starts with it ('' for the password)
  String _savedValue(String key) {
    final p = _profile!;
    return switch (key) {
      'full_name' => p.fullName,
      'username' => p.username,
      'email' => p.email ?? '',
      'farm_name' => p.farm?.farmName ?? '',
      'farm_size_ha' => p.farm?.sizeHa?.toString() ?? '',
      _ => '',
    };
  }

  // The saved value as the Edit profile list shows it
  String _shownValue(String key) {
    final p = _profile!;
    return switch (key) {
      'new_password' => '••••••••',
      'username' => '@${p.username}',
      'farm_size_ha' => p.farm?.sizeHa == null ? '' : '${p.farm!.sizeHa} ha',
      _ => _savedValue(key),
    };
  }

  // Opens one detail for changing, starting on what is saved
  void _startChange(String key) {
    _field = key;
    _value.text = _savedValue(key);
    _confirm.clear();
    _current.clear();
    _formError = null;
  }

  // Checks and saves the open detail. Returns an error to show, or null when
  // it was saved.
  Future<String?> _saveField() async {
    final key = _field!;
    final item = _editable.firstWhere((f) => f.key == key);
    final label = item.label.toLowerCase();
    final text = key == 'new_password' ? _value.text : _value.text.trim();

    if (key != 'new_password' && text == _savedValue(key)) {
      return "That's the same as what is saved.";
    }
    if ((key == 'full_name' || key == 'username' || key == 'email') &&
        text.isEmpty) {
      return 'Enter your $label.';
    }
    double? size;
    if (key == 'farm_size_ha' && text.isNotEmpty) {
      size = double.tryParse(text);
      if (size == null || size < 0) return 'Farm size must be a number.';
    }
    if (key == 'new_password') {
      if (passwordProblem(text) case final rule?) return rule;
      if (text != _confirm.text) return 'The new passwords do not match.';
    }
    if (item.secure && _current.text.isEmpty) {
      return 'Enter your current password to change your $label.';
    }

    try {
      // only this one detail is sent; the server leaves the rest as they are
      final p = await _api.updateProfile(
        token: _auth.token!,
        fullName: key == 'full_name' ? text : null,
        username: key == 'username' ? text : null,
        email: key == 'email' ? text : null,
        newPassword: key == 'new_password' ? text : null,
        farmName: key == 'farm_name' ? text : null,
        farmSizeHa: size,
        clearFarmSize: key == 'farm_size_ha' && text.isEmpty,
        currentPassword: item.secure ? _current.text : null,
      );
      await _auth.updateAccount(fullName: p.fullName, username: p.username);
      // new scans carry the farm name too, so it stays the same as the server's
      if (p.role == 'farmer') {
        await _settings.setFarmName(p.farm?.farmName ?? '');
      }
      if (mounted) {
        setState(() => _profile = p);
        _say('${item.label} changed.');
      }
      return null;
    } catch (e) {
      return '$e';
    }
  }

  // Edit profile: a sheet listing what can be changed, one detail at a time
  Future<void> _openEdit() {
    _field = null;
    _formError = null;
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) => StatefulBuilder(
        builder: (sheetContext, setSheet) {
          final p = _profile!;
          final hasFarm = p.role == 'farmer' && p.farm != null;
          final items = _editable.where((f) => !f.farmOnly || hasFarm).toList();
          final colors = sheetContext.colors;
          return Padding(
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
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Choose what to change. Only that detail is saved; '
                    'everything else stays the same.',
                    style: TextStyle(color: colors.textMuted, fontSize: 13),
                  ),
                  const SizedBox(height: 14),
                  Container(
                    decoration: BoxDecoration(
                      border: Border.all(color: colors.line),
                      borderRadius: BorderRadius.circular(AppRadius.control),
                    ),
                    child: Column(
                      children: [
                        for (final (i, item) in items.indexed) ...[
                          if (i > 0) Divider(height: 1, color: colors.line),
                          _editRow(sheetContext, item, setSheet),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  Align(
                    alignment: Alignment.centerRight,
                    child: OutlinedButton(
                      onPressed: _saving
                          ? null
                          : () => Navigator.pop(sheetContext),
                      child: const Text('Done'),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    ).whenComplete(() => _field = null);
  }

  // One detail of the Edit profile list, with its form when it is open
  Widget _editRow(BuildContext context, _Editable item, StateSetter setSheet) {
    final colors = context.colors;
    final open = _field == item.key;
    final shown = _shownValue(item.key);
    final label = item.label.toLowerCase();

    Future<void> save() async {
      setSheet(() {
        _saving = true;
        _formError = null;
      });
      final error = await _saveField();
      if (!context.mounted) return;
      setSheet(() {
        _saving = false;
        _formError = error;
        if (error == null) _field = null;
      });
    }

    return Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.label,
                      style: TextStyle(fontSize: 12, color: colors.textMuted),
                    ),
                    Text(
                      shown.isEmpty ? '–' : shown,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w500),
                    ),
                  ],
                ),
              ),
              if (!open)
                OutlinedButton(
                  onPressed: _field != null
                      ? null
                      : () => setSheet(() => _startChange(item.key)),
                  child: const Text('Change'),
                ),
            ],
          ),
          if (open) ...[
            const SizedBox(height: 12),
            if (item.key == 'new_password') ...[
              _PasswordField(
                label: 'New password',
                controller: _value,
                enabled: !_saving,
                autofocus: true,
              ),
              const SizedBox(height: 12),
              _PasswordField(
                label: 'Confirm new password',
                controller: _confirm,
                enabled: !_saving,
              ),
              PasswordChecklist(password: _value, confirm: _confirm),
            ] else
              LabeledField(
                label: 'New $label',
                controller: _value,
                enabled: !_saving,
                autofocus: true,
                keyboardType: switch (item.key) {
                  'email' => TextInputType.emailAddress,
                  'farm_size_ha' => const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  _ => null,
                },
                hint: item.key == 'farm_size_ha'
                    ? 'Hectares, leave empty to clear'
                    : null,
              ),
            if (item.secure) ...[
              const SizedBox(height: 12),
              _PasswordField(
                label: 'Current password',
                hint: 'Needed to change your sign-in details',
                controller: _current,
                enabled: !_saving,
                onSubmitted: (_) => save(),
              ),
            ],
            if (_formError != null) ...[
              const SizedBox(height: 10),
              Text(
                _formError!,
                style: TextStyle(color: colors.danger, fontSize: 13),
              ),
            ],
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                OutlinedButton(
                  onPressed: _saving
                      ? null
                      : () => setSheet(() {
                          _field = null;
                          _formError = null;
                        }),
                  child: const Text('Cancel'),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: _saving ? null : save,
                  child: Text(_saving ? 'Saving...' : 'Save $label'),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final p = _profile;
    if (p == null && _loadError != null) return _buildOffline();
    if (p == null) {
      return Container(
        height: 160,
        alignment: Alignment.center,
        decoration: _cardDecoration(context),
        child: const PinePalLoader(size: 64),
      );
    }
    return _buildProfile(p);
  }

  BoxDecoration _cardDecoration(BuildContext context) => BoxDecoration(
    color: context.colors.surface,
    borderRadius: BorderRadius.circular(AppRadius.card),
    border: Border.all(color: context.colors.line),
  );

  // The server could not be reached (the app works offline): what the phone
  // knows about the account, and a way to try again
  Widget _buildOffline() {
    final colors = context.colors;
    final user = _auth.user;
    return SectionCard(
      title: 'Account',
      children: [
        if (user != null)
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: colors.accent,
                  shape: BoxShape.circle,
                ),
                child: Text(
                  user.initials,
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: colors.onAccent,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      user.fullName,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    Text(
                      '@${user.username} · ${user.roleLabel}',
                      style: TextStyle(color: colors.textMuted, fontSize: 13),
                    ),
                  ],
                ),
              ),
            ],
          ),
        const SizedBox(height: 12),
        Text(
          'Could not load your full profile. Check your connection.\n'
          '$_loadError',
          style: TextStyle(color: colors.textMuted, fontSize: 13),
        ),
        const SizedBox(height: 10),
        OutlinedButton(onPressed: _load, child: const Text('Try again')),
      ],
    );
  }

  Widget _buildProfile(UserProfile p) {
    final colors = context.colors;
    final isFarmer = p.role == 'farmer';
    final farm = p.farm;
    final role = _roleLabel(p.role);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildCoverCard(p),
        if (isFarmer && farm != null) ...[
          const SizedBox(height: 12),
          SectionCard(
            title: 'Overview',
            titleColor: colors.accentText,
            children: [
              Row(
                children: [
                  Expanded(
                    child: _StatTile(
                      value: '${farm.totalScans}',
                      label: 'Scans',
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _StatTile(
                      value: farm.sizeHa == null ? '–' : '${farm.sizeHa} ha',
                      label: 'Farm size',
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _StatTile(
                      value: farm.isActive ? 'Active' : 'Off',
                      label: 'Farm status',
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          SectionCard(
            title: 'Farm',
            titleColor: colors.accentText,
            children: _spaced([
              _InfoItem(
                icon: Icons.spa_outlined,
                value: farm.farmName.isEmpty
                    ? 'No farm name yet'
                    : farm.farmName,
                label: 'Farm name',
              ),
              _InfoItem(
                icon: Icons.tag,
                value: farm.farmerId,
                label: 'Farmer ID',
              ),
              _InfoItem(
                icon: Icons.place_outlined,
                value: farm.latitude == null
                    ? 'Not set yet'
                    : '${farm.latitude!.toStringAsFixed(5)}, '
                          '${farm.longitude!.toStringAsFixed(5)}',
                label: 'Farm location',
              ),
              _InfoItem(
                icon: Icons.calendar_today_outlined,
                value: farm.registeredAt == null
                    ? null
                    : formatDate(farm.registeredAt!),
                label: 'Registered',
              ),
            ]),
          ),
        ],
        if (isFarmer && farm == null) ...[
          const SizedBox(height: 12),
          SectionCard(
            title: 'Farm',
            titleColor: colors.accentText,
            children: [
              Text(
                'No farm is linked to your account yet.',
                style: TextStyle(color: colors.textMuted),
              ),
            ],
          ),
        ],
        const SizedBox(height: 12),
        SectionCard(
          title: 'Personal info',
          titleColor: colors.accentText,
          children: [
            ..._spaced([
              _InfoItem(
                icon: Icons.mail_outline,
                value: p.email,
                label: 'Email',
              ),
              _InfoItem(
                icon: Icons.person_outline,
                value: '@${p.username}',
                label: 'Username',
              ),
              _InfoItem(
                icon: Icons.shield_outlined,
                value: role,
                label: 'Role',
              ),
              _InfoItem(
                icon: Icons.place_outlined,
                value: p.municipality,
                label: 'Municipality',
                muted: true,
                note: _echagueOnly,
              ),
              _InfoItem(
                icon: Icons.calendar_today_outlined,
                value: p.createdAt == null ? null : formatDate(p.createdAt!),
                label: 'Joined',
              ),
            ]),
            const SizedBox(height: 14),
            Divider(height: 1, color: colors.line),
            const SizedBox(height: 12),
            Text(
              'Change your email, username or password with Edit profile. '
              'Your role, municipality and join date can only be changed by '
              'an admin.',
              style: TextStyle(color: colors.textMuted, fontSize: 12),
            ),
          ],
        ),
      ],
    );
  }

  // The profile card: cover, avatar, name, and Edit profile
  Widget _buildCoverCard(UserProfile p) {
    final colors = context.colors;
    final isFarmer = p.role == 'farmer';
    final farm = p.farm;
    final role = _roleLabel(p.role);
    final active = !isFarmer || farm == null || farm.isActive;
    const coverHeight = 120.0;
    const avatar = 96.0;

    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: _cardDecoration(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Stack(
            clipBehavior: Clip.none,
            children: [
              const SizedBox(
                height: coverHeight,
                width: double.infinity,
                child: _Cover(),
              ),
              Positioned(
                left: 16,
                top: coverHeight - avatar / 2,
                child: Container(
                  width: avatar,
                  height: avatar,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: colors.accent,
                    shape: BoxShape.circle,
                    border: Border.all(color: colors.surface, width: 4),
                  ),
                  child: Text(
                    _initials(p.fullName),
                    style: TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.w600,
                      color: colors.onAccent,
                    ),
                  ),
                ),
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, avatar / 2 + 10, 16, 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text(
                      p.fullName,
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: colors.accentSoft,
                        borderRadius: BorderRadius.circular(AppRadius.pill),
                      ),
                      child: Text(
                        role,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: colors.accentText,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 16,
                  runSpacing: 4,
                  children: [
                    _iconText(
                      isFarmer ? Icons.spa_outlined : Icons.shield_outlined,
                      isFarmer && (farm?.farmName.isNotEmpty ?? false)
                          ? farm!.farmName
                          : role,
                    ),
                    Opacity(
                      opacity: 0.6,
                      child: Tooltip(
                        message: _echagueOnly,
                        child: _iconText(
                          Icons.place_outlined,
                          '${p.municipality.isEmpty ? 'No municipality yet' : p.municipality}, Isabela',
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: [
                    _Chip('@${p.username}'),
                    if (farm != null) _Chip('Farmer ID ${farm.farmerId}'),
                  ],
                ),
              ],
            ),
          ),
          Divider(height: 1, color: colors.line),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 12, 10),
            child: Row(
              children: [
                Icon(
                  Icons.verified_outlined,
                  size: 16,
                  color: active ? colors.success : colors.danger,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    active ? 'Active account' : 'Deactivated account',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: active ? colors.success : colors.danger,
                    ),
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: _openEdit,
                  icon: const Icon(Icons.edit_outlined, size: 18),
                  label: const Text('Edit profile'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _iconText(IconData icon, String text) {
    final muted = context.colors.textMuted;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: muted),
        const SizedBox(width: 6),
        Flexible(
          child: Text(text, style: TextStyle(fontSize: 14, color: muted)),
        ),
      ],
    );
  }

  // Puts the same gap between a card's lines
  List<Widget> _spaced(List<Widget> items) => [
    for (final (i, item) in items.indexed) ...[
      if (i > 0) const SizedBox(height: 14),
      item,
    ],
  ];

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
}

// The cover: pineapple-leaf greens, drawn with gradients like the web's COVER,
// so there is no image to load. Same colors in light and dark.
class _Cover extends StatelessWidget {
  const _Cover();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF1F4D2B), Color(0xFF2F6B35), Color(0xFF173B22)],
          stops: [0, 0.45, 1],
        ),
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: RadialGradient(
                center: Alignment(-0.7, -1),
                radius: 1.1,
                colors: [Color(0xFF4D8A3A), Color(0x004D8A3A)],
                stops: [0, 0.55],
              ),
            ),
          ),
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: RadialGradient(
                center: Alignment(0.7, -0.8),
                radius: 0.9,
                colors: [Color(0xFF2F7D4F), Color(0x002F7D4F)],
                stops: [0, 0.6],
              ),
            ),
          ),
          CustomPaint(painter: _LeafStripes()),
        ],
      ),
    );
  }
}

// Thin diagonal lines over the cover, like leaf veins
class _LeafStripes extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    void lines(double step, double slope, Color color) {
      final paint = Paint()
        ..color = color
        ..strokeWidth = 2;
      final run = size.height * slope;
      for (var x = -run.abs(); x < size.width + run.abs(); x += step) {
        canvas.drawLine(Offset(x, size.height), Offset(x + run, 0), paint);
      }
    }

    lines(28, 0.47, const Color(0x12FFFFFF)); // white at 7%
    lines(36, -0.47, const Color(0x14000000)); // black at 8%
  }

  @override
  bool shouldRepaint(_LeafStripes oldDelegate) => false;
}

// A number tile of the Overview card
class _StatTile extends StatelessWidget {
  const _StatTile({required this.value, required this.label});

  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 14),
      decoration: BoxDecoration(
        color: colors.accent.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              value,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: colors.accentText,
            ),
          ),
        ],
      ),
    );
  }
}

// One line of Personal info or Farm: an icon in a soft square, the value, and
// what it is under it. muted = greyed out, with a note (the municipality,
// while PinePal only covers Echague).
class _InfoItem extends StatelessWidget {
  const _InfoItem({
    required this.icon,
    required this.value,
    required this.label,
    this.muted = false,
    this.note,
  });

  final IconData icon;
  final String? value;
  final String label;
  final bool muted;
  final String? note;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final text = (value == null || value!.isEmpty) ? '–' : value!;
    return Opacity(
      opacity: muted ? 0.5 : 1,
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: colors.surface2,
              borderRadius: BorderRadius.circular(AppRadius.control),
            ),
            child: Icon(icon, size: 18, color: colors.textMuted),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  text,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontWeight: FontWeight.w500,
                    color: muted ? colors.textMuted : null,
                  ),
                ),
                Text(
                  note == null ? label : '$label · $note',
                  style: TextStyle(fontSize: 12, color: colors.textMuted),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: colors.surface2,
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w500,
          color: colors.textMuted,
        ),
      ),
    );
  }
}

// A password field with an eye button to show or hide what was typed
class _PasswordField extends StatefulWidget {
  const _PasswordField({
    required this.label,
    required this.controller,
    this.hint,
    this.enabled = true,
    this.autofocus = false,
    this.onSubmitted,
  });

  final String label;
  final TextEditingController controller;
  final String? hint;
  final bool enabled;
  final bool autofocus;
  final ValueChanged<String>? onSubmitted;

  @override
  State<_PasswordField> createState() => _PasswordFieldState();
}

class _PasswordFieldState extends State<_PasswordField> {
  bool _shown = false;

  @override
  Widget build(BuildContext context) {
    return LabeledField(
      label: widget.label,
      hint: widget.hint,
      controller: widget.controller,
      obscure: !_shown,
      enabled: widget.enabled,
      autofocus: widget.autofocus,
      onSubmitted: widget.onSubmitted,
      suffix: IconButton(
        tooltip: _shown ? 'Hide password' : 'Show password',
        icon: Icon(
          _shown ? Icons.visibility_off_outlined : Icons.visibility_outlined,
        ),
        onPressed: () => setState(() => _shown = !_shown),
      ),
    );
  }
}
