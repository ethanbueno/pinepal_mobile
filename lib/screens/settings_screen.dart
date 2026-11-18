import 'package:flutter/material.dart';

import '../services/api_client.dart';
import '../services/app_settings.dart';
import '../services/sync_controller.dart';
import '../theme/app_colors.dart';
import '../theme/theme_controller.dart';
import '../widgets/labeled_field.dart';
import '../widgets/section_card.dart';
import 'help_screen.dart';

const appVersion = '1.0.0';

// Preferences for the whole app. Opened from the gear on the Account tab.
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key, this.settings, this.sync});

  // Leave empty to use the shared ones
  final AppSettings? settings;
  final SyncController? sync;

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  static const _tapsForDeveloper = 7;

  late final _settings = widget.settings ?? AppSettings.instance;
  late final _sync = widget.sync ?? SyncController.instance;
  final _theme = ThemeController.instance;

  int _versionTaps = 0;

  // Tapping the version seven times turns on the developer options, the same
  // way as on Android. Farmers never see the server address.
  void _tapVersion() {
    if (_settings.developerOptions) return;
    _versionTaps++;
    if (_versionTaps < _tapsForDeveloper) return;
    _versionTaps = 0;
    _settings.setDeveloperOptions(true);
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Developer options are on.')));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListenableBuilder(
        listenable: Listenable.merge([_settings, _theme]),
        builder: (context, _) {
          return ListView(
            padding: const EdgeInsets.all(AppSpacing.page),
            children: [
              _buildSync(),
              const SizedBox(height: 12),
              _buildAppearance(),
              const SizedBox(height: 12),
              _buildHelp(),
              const SizedBox(height: 12),
              _buildAbout(),
              if (_settings.developerOptions) ...[
                const SizedBox(height: 12),
                _DeveloperCard(settings: _settings),
              ],
              const SizedBox(height: 8),
            ],
          );
        },
      ),
    );
  }

  Widget _buildSync() {
    final automatic = _settings.syncMode == SyncMode.automatic;
    return SectionCard(
      title: 'Sync',
      children: [
        SizedBox(
          width: double.infinity,
          child: SegmentedButton<SyncMode>(
            showSelectedIcon: false,
            segments: const [
              ButtonSegment(value: SyncMode.manual, label: Text('Manual')),
              ButtonSegment(
                value: SyncMode.automatic,
                label: Text('Automatic'),
              ),
            ],
            selected: {_settings.syncMode},
            onSelectionChanged: (selection) {
              _settings.setSyncMode(selection.first);
              // Switching to automatic sends whatever is already waiting
              _sync.maybeAutoSync();
            },
          ),
        ),
        const SizedBox(height: 8),
        Text(
          automatic
              ? 'Scans are sent by themselves when there is a connection.'
              : 'Scans are sent only when you tap Sync now on the Account tab.',
          style: TextStyle(color: context.colors.textMuted, fontSize: 13),
        ),
        if (automatic) ...[
          const SizedBox(height: 4),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Wi-Fi only'),
            subtitle: Text(
              'Do not use mobile data to upload photos',
              style: TextStyle(color: context.colors.textMuted, fontSize: 13),
            ),
            value: _settings.wifiOnly,
            onChanged: (value) {
              _settings.setWifiOnly(value);
              _sync.maybeAutoSync();
            },
          ),
        ],
      ],
    );
  }

  Widget _buildAppearance() {
    return SectionCard(
      title: 'Appearance',
      children: [
        SizedBox(
          width: double.infinity,
          child: SegmentedButton<ThemeMode>(
            showSelectedIcon: false,
            segments: const [
              ButtonSegment(value: ThemeMode.light, label: Text('Light')),
              ButtonSegment(value: ThemeMode.dark, label: Text('Dark')),
              ButtonSegment(value: ThemeMode.system, label: Text('Device')),
            ],
            selected: {_theme.value},
            onSelectionChanged: (selection) => _theme.setMode(selection.first),
          ),
        ),
        const SizedBox(height: 8),
        Text(switch (_theme.value) {
          ThemeMode.light => 'Always light.',
          ThemeMode.dark => 'Always dark.',
          ThemeMode.system =>
            'Follows your phone: light or dark, the same as its setting.',
        }, style: TextStyle(color: context.colors.textMuted, fontSize: 13)),
      ],
    );
  }

  Widget _buildHelp() {
    return SectionCard(
      title: 'Help',
      children: [
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: Icon(Icons.help_outline, color: context.colors.accentText),
          title: const Text('How PinePal works'),
          subtitle: const Text(
            'Photo tips, the confidence score, offline sync and officer '
            'checks.',
          ),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const HelpScreen()),
          ),
        ),
      ],
    );
  }

  Widget _buildAbout() {
    return SectionCard(
      title: 'About',
      children: [
        InkWell(
          onTap: _tapVersion,
          borderRadius: BorderRadius.circular(AppRadius.control),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              children: [
                const Expanded(
                  child: Text('PinePal Mobile', style: TextStyle(fontSize: 15)),
                ),
                Text(
                  'Version $appVersion',
                  style: TextStyle(
                    color: context.colors.textMuted,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Offline pineapple disease scanner, with sync to the PinePal '
          'dashboard.',
          style: TextStyle(color: context.colors.textMuted, fontSize: 13),
        ),
      ],
    );
  }
}

// For developers only: which server the app talks to. Normal builds already
// know it (PINEPAL_API_URL), so this stays hidden unless it is turned on.
class _DeveloperCard extends StatefulWidget {
  final AppSettings settings;

  const _DeveloperCard({required this.settings});

  @override
  State<_DeveloperCard> createState() => _DeveloperCardState();
}

class _DeveloperCardState extends State<_DeveloperCard> {
  late final _server = TextEditingController(text: widget.settings.serverUrl);
  final _focus = FocusNode();

  bool _testing = false;
  String? _testResult;
  bool _testOk = false;

  @override
  void initState() {
    super.initState();
    // The address is saved when the field loses focus
    _focus.addListener(() {
      if (!_focus.hasFocus) _save();
    });
  }

  @override
  void dispose() {
    _server.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _save() {
    widget.settings.setServerUrl(_server.text);
    _server.text = widget.settings.serverUrl;
  }

  Future<void> _useDefault() async {
    await widget.settings.resetServerUrl();
    setState(() {
      _server.text = widget.settings.serverUrl;
      _testResult = null;
    });
  }

  Future<void> _test() async {
    _save();
    setState(() {
      _testing = true;
      _testResult = null;
    });
    try {
      final message = await ApiClient().ping();
      if (!mounted) return;
      setState(() {
        _testOk = true;
        _testResult = 'Connected: $message';
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _testOk = false;
        _testResult = e.message;
      });
    } finally {
      if (mounted) setState(() => _testing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final settings = widget.settings;
    return SectionCard(
      title: 'Developer',
      children: [
        LabeledField(
          label: 'Server address',
          hint: AppSettings.defaultServerUrl,
          controller: _server,
          focusNode: _focus,
          keyboardType: TextInputType.url,
          textInputAction: TextInputAction.done,
          onSubmitted: (_) => _save(),
        ),
        const SizedBox(height: 6),
        Text(
          settings.usesCustomServer
              ? 'Using this address instead of the one the app was built with '
                    '(${AppSettings.defaultServerUrl}).'
              : 'The address the app was built with. On a real phone, use the '
                    'address of your computer, for example '
                    'http://192.168.1.5:5000.',
          style: TextStyle(color: context.colors.textMuted, fontSize: 13),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          children: [
            TextButton.icon(
              icon: _testing
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.wifi_tethering),
              label: const Text('Test connection'),
              onPressed: _testing ? null : _test,
            ),
            if (settings.usesCustomServer)
              TextButton(
                onPressed: _useDefault,
                child: const Text('Use built-in address'),
              ),
            TextButton(
              onPressed: () => settings.setDeveloperOptions(false),
              child: const Text('Hide developer options'),
            ),
          ],
        ),
        if (_testResult != null)
          Text(
            _testResult!,
            style: TextStyle(
              color: _testOk ? context.colors.success : context.colors.danger,
              fontSize: 13,
            ),
          ),
      ],
    );
  }
}
