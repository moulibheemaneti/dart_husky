/// Example usage of dart_husky.
///
/// dart_husky is primarily a CLI tool: you describe your hooks in a
/// `dart_husky.yaml` file at your project root, then install them once.
///
/// ```sh
/// dart run dart_husky install     # write the hooks into .git/hooks/
/// dart run dart_husky list        # show configured hooks and install status
/// dart run dart_husky run pre-commit  # trigger a hook manually
/// dart run dart_husky uninstall   # remove every installed hook
/// ```
///
/// See `example/dart_husky.yaml` in this directory for a fully annotated
/// configuration covering parallel execution, glob filtering, staged-only
/// mode, custom commit types and the melos preset.
///
/// The commit-message validator is also exposed as a library, which is what
/// this file demonstrates. Run it with:
///
/// ```sh
/// dart run example/example.dart
/// ```
library;

import 'package:dart_husky/dart_husky.dart';

void main() {
  // The built-in Conventional Commits types are accepted out of the box.
  _check('feat(auth): add login screen');

  // Subjects must be lowercase by default...
  _check('feat(auth): Add Login Screen');

  // ...and unknown types are rejected.
  _check('wip: half-finished work');

  // Unless you append your own types — this mirrors the YAML config:
  //
  //   commit-msg:
  //     commands:
  //       conventional:
  //         preset: conventional
  //         types:
  //           append: [wip, release]
  _check('wip: half-finished work', appendTypes: ['wip', 'release']);

  // `overrideTypes` replaces the built-in list entirely rather than adding
  // to it, so ordinary types stop being accepted.
  _check('feat: add login', overrideTypes: ['ticket']);

  // Lowercase enforcement can be turned off on its own.
  _check('feat(auth): Add Login Screen', onlySmallCase: false);
}

/// Validates [message] and prints whether it passed, plus the reason if not.
void _check(
  String message, {
  List<String> appendTypes = const [],
  List<String> overrideTypes = const [],
  bool onlySmallCase = true,
}) {
  final result = CommitMsgValidator.validate(
    message,
    appendTypes: appendTypes,
    overrideTypes: overrideTypes,
    onlySmallCase: onlySmallCase,
  );

  print('${result.passed ? '✅' : '❌'} $message');

  // `message` is null whenever validation passed.
  final failure = result.message;
  if (failure != null) {
    // Indent the validator's multi-line explanation under the heading above.
    print(failure.trimRight().split('\n').map((l) => '   $l').join('\n'));
  }
  print('');
}
