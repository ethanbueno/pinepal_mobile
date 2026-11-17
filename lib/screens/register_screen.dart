import 'package:flutter/material.dart';

import '../services/api_client.dart';
import '../services/auth_controller.dart';
import '../services/sync_controller.dart';
import '../theme/app_colors.dart';
import '../utils/municipalities.dart';
import '../utils/password_rules.dart';
import '../widgets/auth_widgets.dart';

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
  // locked: every account is in Echague (the server saves it as the farm's municipality)
  final _municipality = TextEditingController(text: scanMunicipality);
  final _username = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _confirm = TextEditingController();

  bool _busy = false;
  bool _showPassword = false; // the eye button, for both password boxes
  String? _error;

  @override
  void dispose() {
    _fullName.dispose();
    _municipality.dispose();
    _username.dispose();
    _email.dispose();
    _password.dispose();
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _register() async {
    final fullName = _fullName.text.trim();
    final username = _username.text.trim();
    final email = _email.text.trim();

    String? problem;
    if (fullName.isEmpty ||
        username.isEmpty ||
        email.isEmpty ||
        _password.text.isEmpty) {
      problem = 'All fields are required.';
    } else if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(email)) {
      problem = 'Enter a valid email address.';
    } else if (passwordProblem(_password.text) case final rule?) {
      problem = rule;
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
        email: email,
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

  // A calm, simple page like the sign in screen: a short title, the fields in
  // two small groups and one button
  @override
  Widget build(BuildContext context) {
    final groupLabel = TextStyle(
      fontSize: 13,
      fontWeight: FontWeight.w600,
      color: context.colors.textMuted,
    );

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
                    'Create account',
                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    'A free farmer account for checking your pineapples.',
                    style: TextStyle(
                      fontSize: 14,
                      color: context.colors.textMuted,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.section),
                  Text('Your details', style: groupLabel),
                  const SizedBox(height: AppSpacing.sm),
                  AuthField(
                    label: 'Full name',
                    controller: _fullName,
                    enabled: !_busy,
                    textInputAction: TextInputAction.next,
                  ),
                  const SizedBox(height: AppSpacing.md),
                  AuthField(
                    label: 'Municipality',
                    controller: _municipality,
                    enabled: false,
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  Text('Account', style: groupLabel),
                  const SizedBox(height: AppSpacing.sm),
                  AuthField(
                    label: 'Username',
                    controller: _username,
                    enabled: !_busy,
                    textInputAction: TextInputAction.next,
                  ),
                  const SizedBox(height: AppSpacing.md),
                  AuthField(
                    label: 'Email',
                    controller: _email,
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
                    textInputAction: TextInputAction.next,
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
                  const SizedBox(height: AppSpacing.md),
                  AuthField(
                    label: 'Confirm password',
                    controller: _confirm,
                    enabled: !_busy,
                    obscure: !_showPassword,
                    textInputAction: TextInputAction.done,
                    onSubmitted: (_) => _register(),
                  ),
                  // the rules, ticked off while typing
                  PasswordChecklist(password: _password, confirm: _confirm),
                  if (_error != null) ...[
                    const SizedBox(height: AppSpacing.md),
                    AuthError(message: _error!),
                  ],
                  const SizedBox(height: AppSpacing.lg),
                  PillButton(
                    text: 'Create account',
                    busy: _busy,
                    onPressed: _busy ? null : _register,
                  ),
                  const SizedBox(height: AppSpacing.md),
                  // goes back to the sign in screen, which opened this one
                  TextButton(
                    onPressed: _busy ? null : () => Navigator.pop(context),
                    child: const Text('Already have an account? Log in'),
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
