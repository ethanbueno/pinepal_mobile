import 'package:flutter/material.dart';

import '../services/api_client.dart';
import '../services/auth_controller.dart';
import '../services/sync_controller.dart';
import '../theme/app_colors.dart';
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

  // A different look from the sign in screen, like the web Register page:
  // an amber "Join PinePal" header with how it works, then the form in groups
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Create account')),
      body: SafeArea(
        top: false,
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(AppSpacing.page),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const _JoinHeader(),
                  const SizedBox(height: AppSpacing.lg),
                  Container(
                    padding: const EdgeInsets.all(AppSpacing.page),
                    decoration: BoxDecoration(
                      color: context.colors.surface,
                      borderRadius: BorderRadius.circular(AppRadius.card),
                      border: Border.all(color: context.colors.line),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const _FormSectionTitle(
                          number: 1,
                          title: 'Your details',
                        ),
                        const SizedBox(height: AppSpacing.md),
                        AuthField(
                          label: 'Full name',
                          controller: _fullName,
                          enabled: !_busy,
                          textInputAction: TextInputAction.next,
                        ),
                        const SizedBox(height: AppSpacing.section),
                        const _FormSectionTitle(number: 2, title: 'Account'),
                        const SizedBox(height: AppSpacing.md),
                        AuthField(
                          label: 'Username',
                          controller: _username,
                          enabled: !_busy,
                          textInputAction: TextInputAction.next,
                        ),
                        const SizedBox(height: AppSpacing.md),
                        AuthField(
                          label: 'Password',
                          controller: _password,
                          enabled: !_busy,
                          obscure: true,
                          textInputAction: TextInputAction.next,
                        ),
                        const SizedBox(height: AppSpacing.md),
                        AuthField(
                          label: 'Confirm password',
                          controller: _confirm,
                          enabled: !_busy,
                          obscure: true,
                          textInputAction: TextInputAction.done,
                          onSubmitted: (_) => _register(),
                        ),
                        const SizedBox(height: AppSpacing.lg),
                        Container(
                          padding: const EdgeInsets.all(AppSpacing.md),
                          decoration: BoxDecoration(
                            color: context.colors.surface2,
                            borderRadius: BorderRadius.circular(
                              AppRadius.control,
                            ),
                          ),
                          child: Text(
                            'This creates a farmer account. Farmer accounts '
                            'work on the phone and on the web dashboard. '
                            'Agricultural officers and admins are added by an '
                            'admin.',
                            style: TextStyle(
                              fontSize: 12,
                              height: 1.4,
                              color: context.colors.textMuted,
                            ),
                          ),
                        ),
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
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  // goes back to the sign in screen, which opened this one
                  TextButton(
                    onPressed: _busy ? null : () => Navigator.pop(context),
                    child: const Text('Already have an account? Log in'),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  const AuthFooter(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// Amber header with the app name, "Join PinePal" and the 3 steps as chips
class _JoinHeader extends StatelessWidget {
  const _JoinHeader();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.page),
      decoration: BoxDecoration(
        color: context.colors.accentSoft,
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(color: context.colors.accent.withValues(alpha: 0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const AuthHeadline(text: 'Join ', highlight: 'PinePal'),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'A free farmer account for checking your pineapples and keeping '
            'your farm healthy.',
            style: TextStyle(
              fontSize: 14,
              height: 1.4,
              color: context.colors.textMuted,
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          const Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: [
              _StepChip(
                number: 1,
                icon: Icons.document_scanner_outlined,
                text: 'Scan',
              ),
              _StepChip(
                number: 2,
                icon: Icons.menu_book_outlined,
                text: 'Get the care guide',
              ),
              _StepChip(
                number: 3,
                icon: Icons.place_outlined,
                text: 'Track your farm',
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// "1 Scan" with an icon, one of the how it works steps
class _StepChip extends StatelessWidget {
  final int number;
  final IconData icon;
  final String text;

  const _StepChip({
    required this.number,
    required this.icon,
    required this.text,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(4, 4, 12, 4),
      decoration: BoxDecoration(
        color: context.colors.surface,
        borderRadius: BorderRadius.circular(AppRadius.pill),
        border: Border.all(color: context.colors.line),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 26,
            height: 26,
            decoration: BoxDecoration(
              color: context.colors.accent,
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 15, color: context.colors.onAccent),
          ),
          const SizedBox(width: 6),
          Text(
            '$number. $text',
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}

// A numbered heading over a group of fields
class _FormSectionTitle extends StatelessWidget {
  final int number;
  final String title;

  const _FormSectionTitle({required this.number, required this.title});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 24,
          height: 24,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: context.colors.accentSoft,
            shape: BoxShape.circle,
          ),
          child: Text(
            '$number',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: context.colors.accentText,
            ),
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        Text(
          title,
          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
        ),
      ],
    );
  }
}
