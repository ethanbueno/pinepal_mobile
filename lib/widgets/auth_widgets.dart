import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../utils/password_rules.dart';

// Pieces shared by the sign in and create account screens: the logo with the
// app name, fields with hint text inside the box, round pill buttons and the
// error box.

// Logo with "PinePal" next to it
class AuthBrand extends StatelessWidget {
  const AuthBrand({super.key});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Image.asset('assets/icons/logo.png', width: 44),
        const SizedBox(width: AppSpacing.sm),
        const Text(
          'PinePal',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
        ),
      ],
    );
  }
}

// A text field with [label] shown as hint text inside the box. The hint
// disappears once the user starts typing.
class AuthField extends StatelessWidget {
  final String label;
  final TextEditingController controller;
  final bool obscure;
  final bool enabled;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final Widget? suffix;
  final ValueChanged<String>? onSubmitted;

  const AuthField({
    super.key,
    required this.label,
    required this.controller,
    this.obscure = false,
    this.enabled = true,
    this.keyboardType,
    this.textInputAction,
    this.suffix,
    this.onSubmitted,
  });

  @override
  Widget build(BuildContext context) {
    OutlineInputBorder border(Color color, double width) => OutlineInputBorder(
      borderRadius: BorderRadius.circular(AppRadius.card),
      borderSide: BorderSide(color: color, width: width),
    );

    return TextField(
      controller: controller,
      obscureText: obscure,
      enabled: enabled,
      keyboardType: keyboardType,
      textInputAction: textInputAction,
      autocorrect: false,
      enableSuggestions: !obscure,
      onSubmitted: onSubmitted,
      style: const TextStyle(fontSize: 16),
      decoration: InputDecoration(
        hintText: label,
        hintStyle: TextStyle(color: context.colors.textMuted),
        filled: true,
        fillColor: context.colors.surface,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: 18,
        ),
        border: border(context.colors.line, 1),
        enabledBorder: border(context.colors.line, 1),
        focusedBorder: border(context.colors.accent, 2),
        suffixIcon: suffix,
      ),
    );
  }
}

// Full width, fully rounded button. [outlined] is the second choice.
class PillButton extends StatelessWidget {
  final String text;
  final VoidCallback? onPressed;
  final bool outlined;
  final bool busy; // shows a spinner instead of the text

  const PillButton({
    super.key,
    required this.text,
    required this.onPressed,
    this.outlined = false,
    this.busy = false,
  });

  @override
  Widget build(BuildContext context) {
    const shape = StadiumBorder();
    const size = Size.fromHeight(52);
    const textStyle = TextStyle(fontSize: 16, fontWeight: FontWeight.w500);

    final child = busy
        ? SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: context.colors.onAccent,
            ),
          )
        : Text(text);

    if (outlined) {
      return OutlinedButton(
        style: OutlinedButton.styleFrom(
          shape: shape,
          minimumSize: size,
          textStyle: textStyle,
        ),
        onPressed: onPressed,
        child: child,
      );
    }
    return ElevatedButton(
      style: ElevatedButton.styleFrom(
        shape: shape,
        minimumSize: size,
        textStyle: textStyle,
      ),
      onPressed: onPressed,
      child: child,
    );
  }
}

// Error under the fields, in the same red box style as the web ErrorAlert
class AuthError extends StatelessWidget {
  final String message;

  const AuthError({super.key, required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: context.colors.danger.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(AppRadius.control),
        border: Border.all(color: context.colors.danger.withValues(alpha: 0.4)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.error_outline, size: 18, color: context.colors.danger),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              message,
              style: TextStyle(fontSize: 13, color: context.colors.danger),
            ),
          ),
        ],
      ),
    );
  }
}

// Shown under the button while the server wakes up from sleep (the free
// server sleeps when nobody uses it and takes about a minute to start)
class AuthWakingNote extends StatelessWidget {
  const AuthWakingNote({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.md),
      child: Text(
        'Waking up the server. This can take up to a minute the first time.',
        textAlign: TextAlign.center,
        style: TextStyle(fontSize: 13, color: context.colors.textMuted),
      ),
    );
  }
}

// The password rules under a new-password box, ticked off while typing.
// Hidden until something is typed. Pass [confirm] to add a "Passwords match"
// line once the confirm box has something in it.
class PasswordChecklist extends StatelessWidget {
  final TextEditingController password;
  final TextEditingController? confirm;

  const PasswordChecklist({super.key, required this.password, this.confirm});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([password, ?confirm]),
      builder: (context, _) {
        final pw = password.text;
        if (pw.isEmpty) return const SizedBox.shrink();
        final lines = [
          for (final rule in passwordRules) (rule.label, rule.test(pw)),
          if (confirm != null && confirm!.text.isNotEmpty)
            ('Passwords match', pw == confirm!.text),
        ];
        return Padding(
          padding: const EdgeInsets.only(
            top: AppSpacing.sm,
            left: AppSpacing.xs,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (final (label, met) in lines)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: Row(
                    children: [
                      Icon(
                        met ? Icons.check_rounded : Icons.circle_outlined,
                        size: 16,
                        color: met
                            ? context.colors.accentText
                            : context.colors.textMuted,
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: Text(
                          label,
                          style: TextStyle(
                            fontSize: 13,
                            color: met
                                ? context.colors.text
                                : context.colors.textMuted,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}
