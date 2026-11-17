import 'dart:convert';

// Password rules for new passwords, the same as password_problem() in the web
// backend (backend/security.py) and src/utils/passwordRules.js on the web.
// They only apply when a password is set (sign up or change), so older
// passwords still sign in.

const minPassword = 8;
const _maxPasswordBytes = 72; // bcrypt can't hash more than 72 bytes

final _upper = RegExp(r'[A-Z]');
final _symbol = RegExp(r'[^A-Za-z0-9\s]');

// One line of the checklist under the password box
class PasswordRule {
  final String label;
  final bool Function(String password) test;

  const PasswordRule(this.label, this.test);
}

final passwordRules = <PasswordRule>[
  PasswordRule(
    '$minPassword or more characters',
    (pw) => pw.length >= minPassword,
  ),
  PasswordRule('1 uppercase letter', (pw) => _upper.hasMatch(pw)),
  PasswordRule(
    '1 special symbol, like ! @ # or \$',
    (pw) => _symbol.hasMatch(pw),
  ),
];

// The first rule a password breaks, as a message for the error box, or null
// if it's fine
String? passwordProblem(String pw) {
  if (pw.length < minPassword) {
    return 'Password must be at least $minPassword characters.';
  }
  if (utf8.encode(pw).length > _maxPasswordBytes) {
    return 'Password is too long (72 characters at most).';
  }
  if (!_upper.hasMatch(pw)) {
    return 'Password needs at least 1 uppercase letter.';
  }
  if (!_symbol.hasMatch(pw)) {
    return 'Password needs at least 1 special symbol, like ! @ # or \$.';
  }
  return null;
}
