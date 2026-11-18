import 'dart:async';

import 'package:flutter/material.dart';

import '../services/api_client.dart';
import '../theme/app_colors.dart';
import '../utils/password_rules.dart';
import '../widgets/auth_widgets.dart';

// Forgot password in two steps, like the web's (src/pages/ForgotPassword.jsx):
// the account's email, then a new password. Depending on how the server is
// set up, step 2 also asks for the 6-digit code it emailed. Pops with the
// server's message once the password is changed, for the Sign in screen.
class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key, this.api});

  // Leave empty to use a normal one (tests pass their own)
  final ApiClient? api;

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  // The server sends at most one code a minute
  static const _resendSeconds = 60;
  static final _emailPattern = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');

  late final _api = widget.api ?? ApiClient();
  final _email = TextEditingController();
  final _code = TextEditingController();
  final _password = TextEditingController();
  final _confirm = TextEditingController();

  PasswordResetStart? _start; // null on step 1
  bool _busy = false;
  bool _waking = false;
  bool _showPassword = false;
  String? _error;
  int _resendIn = 0;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    ApiClient.warmUp(api: _api);
  }

  @override
  void dispose() {
    _timer?.cancel();
    _email.dispose();
    _code.dispose();
    _password.dispose();
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _wakeServer() async {
    try {
      await _api.wakeUp(
        onSlow: () {
          if (mounted) setState(() => _waking = true);
        },
      );
    } finally {
      if (mounted) setState(() => _waking = false);
    }
  }

  void _countDown() {
    _timer?.cancel();
    setState(() => _resendIn = _resendSeconds);
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted || _resendIn <= 1) {
        timer.cancel();
        if (mounted) setState(() => _resendIn = 0);
        return;
      }
      setState(() => _resendIn--);
    });
  }

  Future<void> _sendEmail() async {
    final email = _email.text.trim();
    if (!_emailPattern.hasMatch(email)) {
      setState(() => _error = 'Enter the email address of your account.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await _wakeServer();
      final start = await _api.requestPasswordReset(email);
      if (!mounted) return;
      setState(() {
        _start = start;
        _busy = false;
      });
      if (start.emailedCode) _countDown();
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = e.message;
      });
    }
  }

  Future<void> _setPassword() async {
    final start = _start!;
    final code = _code.text.trim();
    final String? problem;
    if (start.emailedCode && !RegExp(r'^\d{6}$').hasMatch(code)) {
      problem = 'Enter the 6-digit code from the email.';
    } else if (passwordProblem(_password.text) case final rule?) {
      problem = rule;
    } else if (_password.text != _confirm.text) {
      problem = 'The passwords do not match.';
    } else {
      problem = null;
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
      await _wakeServer();
      final message = await _api.resetPassword(
        newPassword: _password.text,
        resetToken: start.emailedCode ? null : start.resetToken,
        email: start.emailedCode ? _email.text.trim() : null,
        code: start.emailedCode ? code : null,
      );
      if (!mounted) return;
      Navigator.pop(context, message);
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = e.message;
      });
    }
  }

  // Back to step 1, for another email
  void _changeEmail() {
    _timer?.cancel();
    setState(() {
      _start = null;
      _resendIn = 0;
      _error = null;
      _code.clear();
      _password.clear();
      _confirm.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    final start = _start;
    return Scaffold(
      appBar: AppBar(
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
                children: start == null ? _emailStep() : _passwordStep(start),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _title(String title, String text) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const AuthBrand(),
        const SizedBox(height: AppSpacing.section),
        Text(
          title,
          style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          text,
          style: TextStyle(fontSize: 14, color: context.colors.textMuted),
        ),
        const SizedBox(height: AppSpacing.section),
      ],
    );
  }

  List<Widget> _errorAndButton(String text, VoidCallback onPressed) {
    return [
      if (_error != null) ...[
        const SizedBox(height: AppSpacing.md),
        AuthError(message: _error!),
      ],
      const SizedBox(height: AppSpacing.lg),
      PillButton(text: text, busy: _busy, onPressed: _busy ? null : onPressed),
      if (_busy && _waking) const AuthWakingNote(),
    ];
  }

  List<Widget> _emailStep() {
    return [
      _title(
        'Forgot Your Password?',
        'Enter the email address of your PinePal account.',
      ),
      AuthField(
        label: 'Email',
        controller: _email,
        enabled: !_busy,
        keyboardType: TextInputType.emailAddress,
        textInputAction: TextInputAction.done,
        onSubmitted: (_) => _sendEmail(),
      ),
      ..._errorAndButton('Continue', _sendEmail),
      const SizedBox(height: AppSpacing.md),
      TextButton(
        onPressed: _busy ? null : () => Navigator.pop(context),
        child: const Text('Back to Log In'),
      ),
    ];
  }

  List<Widget> _passwordStep(PasswordResetStart start) {
    final email = _email.text.trim();
    final intro = start.emailedCode
        ? (start.message ?? 'If an account uses $email, we sent it a code.')
        : start.username == null
        ? 'Choose a new password for $email.'
        : 'Choose a new password for @${start.username}.';

    return [
      _title('New Password', intro),
      if (start.emailedCode) ...[
        AuthField(
          label: '6-digit code',
          controller: _code,
          enabled: !_busy,
          keyboardType: TextInputType.number,
          textInputAction: TextInputAction.next,
        ),
        const SizedBox(height: AppSpacing.md),
      ],
      AuthField(
        label: 'New Password',
        controller: _password,
        enabled: !_busy,
        obscure: !_showPassword,
        textInputAction: TextInputAction.next,
        suffix: IconButton(
          tooltip: _showPassword ? 'Hide password' : 'Show password',
          icon: Icon(
            _showPassword
                ? Icons.visibility_off_outlined
                : Icons.visibility_outlined,
          ),
          onPressed: () => setState(() => _showPassword = !_showPassword),
        ),
      ),
      const SizedBox(height: AppSpacing.md),
      AuthField(
        label: 'Confirm New Password',
        controller: _confirm,
        enabled: !_busy,
        obscure: !_showPassword,
        textInputAction: TextInputAction.done,
        onSubmitted: (_) => _setPassword(),
      ),
      PasswordChecklist(password: _password, confirm: _confirm),
      ..._errorAndButton('Change Password', _setPassword),
      const SizedBox(height: AppSpacing.md),
      if (start.emailedCode)
        TextButton(
          onPressed: _busy || _resendIn > 0 ? null : _sendEmail,
          child: Text(
            _resendIn > 0
                ? 'Send a new code in ${_resendIn}s'
                : 'Send a New Code',
          ),
        ),
      TextButton(
        onPressed: _busy ? null : _changeEmail,
        child: const Text('Use Another Email'),
      ),
    ];
  }
}
