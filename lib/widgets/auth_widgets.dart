import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

// Pieces shared by the sign in and create account screens. They copy the web
// Login and Register pages (src/pages/Login.jsx): the logo with the app name,
// a big headline, fields with the label inside the box, round pill buttons
// and a line with text in the middle.

// Logo with "PINEPAL" next to it
class AuthBrand extends StatelessWidget {
  const AuthBrand({super.key});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Image.asset('assets/icons/logo.png', width: 44),
        const SizedBox(width: AppSpacing.sm),
        const Text(
          'PINEPAL',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w600,
            letterSpacing: 1.2,
          ),
        ),
      ],
    );
  }
}

// The big headline. [highlight] is drawn in amber, like on the web.
class AuthHeadline extends StatelessWidget {
  final String text;
  final String highlight;

  const AuthHeadline({super.key, required this.text, this.highlight = ''});

  @override
  Widget build(BuildContext context) {
    return Text.rich(
      TextSpan(
        text: text,
        children: [
          TextSpan(
            text: highlight,
            style: TextStyle(color: context.colors.accentText),
          ),
        ],
      ),
      style: const TextStyle(
        fontSize: 34,
        fontWeight: FontWeight.w600,
        height: 1.1,
        letterSpacing: -0.5,
      ),
    );
  }
}

// A text field with its label inside the box. The label moves up once the
// field has focus or text, like FloatingInput on the web.
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
        labelText: label,
        labelStyle: TextStyle(color: context.colors.textMuted),
        floatingLabelStyle: TextStyle(color: context.colors.textMuted),
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

// ——— New to PinePal? ———
class TextDivider extends StatelessWidget {
  final String text;

  const TextDivider({super.key, required this.text});

  @override
  Widget build(BuildContext context) {
    final line = Expanded(
      child: Container(height: 1, color: context.colors.line),
    );
    return Row(
      children: [
        line,
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
          child: Text(
            text,
            style: TextStyle(fontSize: 12, color: context.colors.textMuted),
          ),
        ),
        line,
      ],
    );
  }
}

// Small logo and line at the bottom of the form, like the web
class AuthFooter extends StatelessWidget {
  const AuthFooter({super.key});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Image.asset('assets/icons/logo.png', width: 16),
        const SizedBox(width: 6),
        // Flexible so the line can wrap on very narrow screens
        Flexible(
          child: Text(
            'Pineapple disease monitoring for Isabela',
            style: TextStyle(fontSize: 12, color: context.colors.textMuted),
          ),
        ),
      ],
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
