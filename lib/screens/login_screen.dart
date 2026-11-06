import 'package:flutter/material.dart';

import '../services/api_client.dart';
import '../services/auth_controller.dart';
import '../services/sync_controller.dart';
import '../theme/app_colors.dart';
import '../widgets/auth_widgets.dart';
import 'register_screen.dart';

// Sign in with the same account as the web dashboard. Scanning never needs
// an account; this is only for syncing. Pops with true when signed in.
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _username = TextEditingController();
  final _password = TextEditingController();

  bool _busy = false;
  bool _showPassword = false;
  String? _error;

  @override
  void dispose() {
    _username.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _signIn() async {
    final username = _username.text.trim();
    if (username.isEmpty || _password.text.isEmpty) {
      setState(() => _error = 'Enter your username and password.');
      return;
    }

    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      // This phone's own farmer ID (if it synced before sign in) joins the
      // account: it becomes the account's farmer ID, or its scans move into
      // the one the account already has
      final session = await ApiClient().login(
        username,
        _password.text,
        deviceToken: AuthController.instance.phoneFarmer?.token,
      );
      await AuthController.instance.signIn(session);
      // Scans waiting from before sign-in go out now if automatic sync is on
      SyncController.instance.maybeAutoSync();
      if (!mounted) return;
      Navigator.pop(context, true);
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = e.message;
      });
    }
  }

  // Signing up also signs in, so this screen is done too
  Future<void> _openRegister() async {
    final signedIn = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (context) => const RegisterScreen()),
    );
    if (signedIn != true || !mounted) return;
    Navigator.pop(context, true);
  }

  // A calm, simple page: the logo, a short title, the fields and one button
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        // only the back arrow
        backgroundColor: context.colors.canvas,
        shape: const Border(),
      ),
      body: SafeArea(
        top: false,
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(AppSpacing.page + 4),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const AuthBrand(),
                  const SizedBox(height: AppSpacing.section),
                  const Text(
                    'Log into PinePal',
                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    'Sign in to sync your scans with your account.',
                    style: TextStyle(
                      fontSize: 14,
                      color: context.colors.textMuted,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.section),
                  AuthField(
                    label: 'Username or email',
                    controller: _username,
                    enabled: !_busy,
                    keyboardType: TextInputType.emailAddress,
                    textInputAction: TextInputAction.next,
                  ),
                  const SizedBox(height: AppSpacing.md),
                  AuthField(
                    label: 'Password',
                    controller: _password,
                    enabled: !_busy,
                    obscure: !_showPassword,
                    textInputAction: TextInputAction.done,
                    onSubmitted: (_) => _signIn(),
                    suffix: IconButton(
                      tooltip: _showPassword
                          ? 'Hide password'
                          : 'Show password',
                      icon: Icon(
                        _showPassword
                            ? Icons.visibility_off_outlined
                            : Icons.visibility_outlined,
                      ),
                      onPressed: () =>
                          setState(() => _showPassword = !_showPassword),
                    ),
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: AppSpacing.md),
                    AuthError(message: _error!),
                  ],
                  const SizedBox(height: AppSpacing.lg),
                  PillButton(
                    text: 'Log in',
                    busy: _busy,
                    onPressed: _busy ? null : _signIn,
                  ),
                  const SizedBox(height: AppSpacing.md),
                  TextButton(
                    onPressed: _busy ? null : _openRegister,
                    child: const Text('New to PinePal? Create an account'),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  Text(
                    'You can scan without an account. Sign in only to sync '
                    'your scans.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: context.colors.textMuted,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
