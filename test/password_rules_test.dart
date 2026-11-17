import 'package:flutter_test/flutter_test.dart';
import 'package:pinepal_mobile/utils/password_rules.dart';

void main() {
  test('too short', () {
    expect(passwordProblem('Ab!'), 'Password must be at least 8 characters.');
  });

  test('no uppercase letter', () {
    expect(
      passwordProblem('abcdefg!'),
      'Password needs at least 1 uppercase letter.',
    );
  });

  test('no special symbol (a space does not count)', () {
    expect(passwordProblem('Abc defgh'), contains('special symbol'));
  });

  test('longer than 72 bytes', () {
    expect(passwordProblem('A!${'x' * 71}'), contains('too long'));
  });

  test('a good password', () {
    expect(passwordProblem('Pineapple#1'), isNull);
  });

  test('checklist lines tick off one by one', () {
    bool met(String pw, int i) => passwordRules[i].test(pw);
    expect(
      [met('abc', 0), met('abc', 1), met('abc', 2)],
      [false, false, false],
    );
    expect(
      [met('Pineapple!', 0), met('Pineapple!', 1), met('Pineapple!', 2)],
      [true, true, true],
    );
  });
}
