import 'package:flutter/material.dart';

import '../services/api_client.dart';
import '../services/auth_controller.dart';
import '../services/sync_controller.dart';
import '../theme/app_colors.dart';
import '../widgets/labeled_field.dart';

// Create a farmer account (the server only allows farmers to sign up; officers
// and admins are created by an admin on the web), then sign in with it. If
// this phone already has its own farmer ID, the new account keeps it and its
// scans. Pops with true when signed in.
class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _fullName = TextEditingController();
  final _username = TextEditingController();
  final _password = TextEditingController();
  final _confirm = TextEditingController();

  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _fullName.dispose();
    _username.dispose();
    _password.dispose();
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _register() async {
    final fullName = _fullName.text.trim();
    final username = _username.text.trim();

    String? problem;
    if (fullName.isEmpty || username.isEmpty || _password.text.isEmpty) {
      problem = 'All fields are required.';
    } else if (_password.text != _confirm.text) {
      problem = 'The passwords do not match.';
    }
    if (problem != null) {
      setState(() => _error = problem);
      return;
    }

    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final api = ApiClient();
      final deviceToken = AuthController.instance.phoneFarmer?.token;
      await api.register(
        fullName: fullName,
        username: username,
        password: _password.text,
        deviceToken: deviceToken,
      );
      final session = await api.login(
        username,
        _password.text,
        deviceToken: deviceToken,
      );
      await AuthController.instance.signIn(session);
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Create account')),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(AppSpacing.page),
                decoration: BoxDecoration(
                  color: context.colors.surface,
                  borderRadius: BorderRadius.circular(AppRadius.card),
                  border: Border.all(color: context.colors.line),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Create your account',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Farmer accounts work on the phone and on the web '
                      'dashboard.',
                      style: TextStyle(
                        color: context.colors.textMuted,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 20),
                    LabeledField(
                      label: 'Full name',
                      hint: 'Enter your full name',
                      controller: _fullName,
                      enabled: !_busy,
                      textInputAction: TextInputAction.next,
                    ),
                    const SizedBox(height: 16),
                    LabeledField(
                      label: 'Username',
                      hint: 'Choose a username',
                      controller: _username,
                      enabled: !_busy,
                      textInputAction: TextInputAction.next,
                    ),
                    const SizedBox(height: 16),
                    LabeledField(
                      label: 'Password',
                      hint: 'Choose a password',
                      controller: _password,
                      enabled: !_busy,
                      obscure: true,
                      textInputAction: TextInputAction.next,
                    ),
                    const SizedBox(height: 16),
                    LabeledField(
                      label: 'Confirm password',
                      hint: 'Enter the password again',
                      controller: _confirm,
                      enabled: !_busy,
                      obscure: true,
                      textInputAction: TextInputAction.done,
                      onSubmitted: (_) => _register(),
                    ),
                    if (_error != null) ...[
                      const SizedBox(height: 12),
                      Text(
                        _error!,
                        style: TextStyle(
                          color: context.colors.danger,
                          fontSize: 13,
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
                        onPressed: _busy ? null : _register,
                        child: _busy
                            ? SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: context.colors.onAccent,
                                ),
                              )
                            : const Text('Create account'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
