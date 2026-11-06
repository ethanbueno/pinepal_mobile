import 'package:flutter/material.dart';

import '../services/app_settings.dart';
import '../services/auth_controller.dart';
import '../services/sync_controller.dart';
import '../theme/app_colors.dart';
import '../utils/format.dart';
import '../widgets/farm_details_sheet.dart';
import '../widgets/section_card.dart';
import 'login_screen.dart';
import 'settings_screen.dart';

// The Profile tab is about the farmer: who is signed in, the farm, and what is
// waiting to sync. Preferences (sync mode, dark mode...) are in Settings, the
// gear in the top bar.
class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key, this.auth, this.settings, this.sync});

  // Leave empty to use the shared ones
  final AuthController? auth;
  final AppSettings? settings;
  final SyncController? sync;

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  late final _auth = widget.auth ?? AuthController.instance;
  late final _settings = widget.settings ?? AppSettings.instance;
  late final _sync = widget.sync ?? SyncController.instance;

  @override
  void initState() {
    super.initState();
    _sync.refreshPending();
  }

  Future<void> _openLogin() {
    return Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (context) => const LoginScreen()),
    );
  }

  Future<void> _openSettings() {
    return Navigator.push<void>(
      context,
      MaterialPageRoute(
        builder: (context) => SettingsScreen(settings: _settings, sync: _sync),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Profile'),
        actions: [
          IconButton(
            tooltip: 'Settings',
            icon: const Icon(Icons.settings_outlined),
            onPressed: _openSettings,
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: ListenableBuilder(
        listenable: Listenable.merge([_auth, _settings, _sync]),
        builder: (context, _) {
          return ListView(
            padding: const EdgeInsets.all(AppSpacing.page),
            children: [
              _buildAccount(),
              const SizedBox(height: 12),
              _buildFarm(),
              const SizedBox(height: 12),
              _buildSync(),
              const SizedBox(height: 8),
            ],
          );
        },
      ),
    );
  }

  // Square avatar with rounded corners, like the user menu of the web sidebar
  Widget _avatar({required Widget child}) {
    return Container(
      width: 44,
      height: 44,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: context.colors.surface2,
        borderRadius: BorderRadius.circular(AppRadius.control),
      ),
      child: child,
    );
  }

  Widget _buildAccount() {
    final user = _auth.user;
    if (user == null) {
      return SectionCard(
        title: 'Account',
        children: [
          Row(
            children: [
              _avatar(
                child: Icon(
                  Icons.person_outline,
                  color: context.colors.textMuted,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Not signed in',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _auth.phoneFarmer == null
                          ? 'Scans stay on this phone. Sign in to sync them '
                                'to the PinePal dashboard.'
                          : 'This phone syncs as farmer ID '
                                '${_auth.phoneFarmer!.farmerId}. Sign in or '
                                'create an account to connect it and its scans '
                                'to you.',
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
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              onPressed: _openLogin,
              child: const Text('Sign in'),
            ),
          ),
        ],
      );
    }

    return SectionCard(
      title: 'Account',
      children: [
        Row(
          children: [
            _avatar(
              child: Text(
                user.initials,
                style: const TextStyle(fontWeight: FontWeight.w500),
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
                  const SizedBox(height: 2),
                  Text(
                    '@${user.username}',
                    style: TextStyle(
                      color: context.colors.textMuted,
                      fontSize: 13,
                    ),
                  ),
                  if (user.farmerId != null)
                    Text(
                      'Farmer ID ${user.farmerId}',
                      style: TextStyle(
                        color: context.colors.textMuted,
                        fontSize: 13,
                      ),
                    ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
              decoration: BoxDecoration(
                color: context.colors.accentSoft,
                borderRadius: BorderRadius.circular(AppRadius.pill),
              ),
              child: Text(
                user.roleLabel,
                style: TextStyle(
                  color: context.colors.accentText,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
            icon: const Icon(Icons.logout),
            label: const Text('Log out'),
            onPressed: _auth.signOut,
          ),
        ),
      ],
    );
  }

  Widget _infoRow(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          Icon(icon, size: 18, color: context.colors.textMuted),
          const SizedBox(width: 10),
          Expanded(child: Text(text, style: const TextStyle(fontSize: 15))),
        ],
      ),
    );
  }

  Widget _buildFarm() {
    final hasFarm = _settings.farmName.isNotEmpty;
    return SectionCard(
      title: 'My farm',
      action: TextButton(
        // compact, so the card title is as tall as in the other cards
        style: TextButton.styleFrom(
          visualDensity: VisualDensity.compact,
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          padding: const EdgeInsets.symmetric(horizontal: 8),
        ),
        onPressed: () => showFarmDetailsSheet(context, _settings),
        child: Text(hasFarm ? 'Edit' : 'Add'),
      ),
      children: [
        if (hasFarm)
          _infoRow(Icons.home_work_outlined, _settings.farmName)
        else
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(
              'Add your farm name so the web dashboard can place your scans.',
              style: TextStyle(color: context.colors.textMuted, fontSize: 13),
            ),
          ),
        _infoRow(
          Icons.map_outlined,
          _settings.municipality.isEmpty
              ? 'No municipality yet'
              : _settings.municipality,
        ),
      ],
    );
  }

  String _syncStatus() {
    final n = _sync.pending;
    final waiting = '$n ${n == 1 ? 'scan is' : 'scans are'} waiting';
    if (!_auth.isSignedIn) {
      final phone = _auth.phoneFarmer;
      if (phone != null && _settings.syncMode == SyncMode.automatic) {
        return n == 0
            ? 'All scans are synced as farmer ID ${phone.farmerId}.'
            : '$waiting to sync as farmer ID ${phone.farmerId}.';
      }
      return n == 0
          ? 'Tap Sync now to sign in or create an account.'
          : '$waiting. Tap Sync now to sign in or create an account.';
    }
    return n == 0 ? 'All scans are synced.' : '$waiting to sync.';
  }

  Widget _buildSync() {
    // Signed out, Sync now opens sign in (with create account), which connects
    // this phone's farmer ID and its scans to the account
    final signedIn = _auth.isSignedIn;
    final canSync = !_sync.syncing && (!signedIn || _sync.pending > 0);
    final last = _sync.lastSyncedAt;
    final automatic = _settings.syncMode == SyncMode.automatic;

    return SectionCard(
      title: 'Sync',
      children: [
        Text(_syncStatus(), style: const TextStyle(fontSize: 15)),
        const SizedBox(height: 2),
        Text(
          [
            automatic
                ? (_settings.wifiOnly
                      ? 'Automatic, on Wi-Fi only'
                      : 'Automatic')
                : 'Manual',
            if (last != null) 'last synced ${formatDateTime(last)}',
          ].join(' · '),
          style: TextStyle(color: context.colors.textMuted, fontSize: 13),
        ),
        const SizedBox(height: 14),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
            icon: _sync.syncing
                ? SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: context.colors.onAccent,
                    ),
                  )
                : const Icon(Icons.sync),
            label: Text(_sync.syncing ? 'Syncing...' : 'Sync now'),
            onPressed: !canSync
                ? null
                : signedIn
                ? _sync.syncNow
                : _openLogin,
          ),
        ),
        if (_sync.message != null) ...[
          const SizedBox(height: 10),
          Text(
            _sync.message!,
            style: TextStyle(
              color: _sync.messageIsError
                  ? context.colors.danger
                  : context.colors.success,
              fontSize: 13,
            ),
          ),
        ],
      ],
    );
  }
}
