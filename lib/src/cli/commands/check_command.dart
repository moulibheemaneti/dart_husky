import 'dart:io';

import 'package:yaml/yaml.dart';

import '../../config/config_model.dart';
import '../../config/config_parser.dart';
import '../../hooks/hook_installer.dart';
import '../../hooks/hook_status.dart';

/// Reports, through its exit code, whether the installed git hooks match
/// dart_husky.yaml.
class CheckCommand {
  /// Every configured hook is in sync and nothing is stale.
  static const exitInSync = 0;

  /// At least one hook is missing, foreign, outdated or stale.
  static const exitOutOfSync = 1;

  /// The check could not run: no dart_husky.yaml, an invalid one, or no git
  /// hooks folder.
  static const exitCannotCheck = 2;

  static const _installCommand = 'dart run dart_husky install';

  final StringSink _out;
  final StringSink _err;

  /// Creates a [CheckCommand] that writes its report to [out] (defaults to
  /// [stdout]) and errors to [err] (defaults to [stderr]).
  CheckCommand({StringSink? out, StringSink? err})
      : _out = out ?? stdout,
        _err = err ?? stderr;

  /// Checks the hooks of the project in [projectDirectory] (defaults to
  /// [Directory.current]) and returns the exit code.
  int run({Directory? projectDirectory}) {
    final directory = projectDirectory ?? Directory.current;

    try {
      final config = ConfigParser.parse(projectDirectory: directory);
      final hooksDirectory = HookInstaller.hooksDirectory(directory);
      return _check(config, hooksDirectory);
    } on FileSystemException catch (e) {
      return _cannotCheck(e.message);
    } on YamlException catch (e) {
      final line = e.span == null ? '' : ' (line ${e.span!.start.line + 1})';
      return _cannotCheck(
          'dart_husky.yaml is not valid YAML$line: ${e.message}');
    } on FormatException catch (e) {
      return _cannotCheck('invalid dart_husky.yaml: ${e.message}');
    }
  }

  int _check(GitHooksConfig config, Directory hooksDirectory) {
    var reported = false;
    var allInSync = true;

    for (final hookType in HookType.values) {
      final status = HookStatus.of(
        hookType,
        contents: HookInstaller.readHook(hooksDirectory, hookType),
        isConfigured: config.hooks.containsKey(hookType),
      );
      if (status == null) continue;

      reported = true;
      if (status != HookStatus.inSync) allInSync = false;
      _out.writeln(_describe(hookType, status));
    }

    if (!reported) _out.writeln('No hooks configured in dart_husky.yaml');

    return allInSync ? exitInSync : exitOutOfSync;
  }

  static String _describe(HookType hookType, HookStatus status) {
    final line = '${hookType.scriptName}: ${status.description}';

    return switch (status) {
      HookStatus.inSync => line,
      HookStatus.foreign => '$line - run "$_installCommand" to replace it',
      _ => '$line - run "$_installCommand" to fix',
    };
  }

  int _cannotCheck(String reason) {
    // Keep the reason to one line so scripts can show it as-is.
    _err.writeln(
      'dart_husky check: ${reason.replaceAll(RegExp(r'\s*\n\s*'), ' ')}',
    );
    return exitCannotCheck;
  }
}
