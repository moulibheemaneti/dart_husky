import 'dart:io';

import 'package:args/args.dart';
import 'package:dart_husky/src/cli/commands/check_command.dart';
import 'package:dart_husky/src/cli/commands/install_command.dart';
import 'package:dart_husky/src/cli/commands/list_command.dart';
import 'package:dart_husky/src/cli/commands/run_command.dart';
import 'package:dart_husky/src/cli/commands/uninstall_command.dart';

const _description = {
  'install': 'Install git hooks from dart_husky.yaml',
  'uninstall': 'Remove all installed git hooks',
  'run': 'Run a specific hook manually',
  'list': 'List all configured hooks',
  'check': 'Check that installed hooks match dart_husky.yaml',
};

void main(List<String> arguments) async {
  final parser = ArgParser();
  for (final cmd in _description.keys) {
    parser.addCommand(cmd);
  }

  final results = parser.parse(arguments);
  final command = results.command;

  switch (command?.name) {
    case 'install':
      InstallCommand().run();
    case 'uninstall':
      UninstallCommand().run();
    case 'run':
      final hookName = command?.rest.firstOrNull;
      final arg = (command?.rest.length ?? 0) > 1 ? command?.rest[1] : null;
      if (hookName == null) {
        print('Usage: dart run dart_husky run <hook-name>');
        return;
      }
      await RunCommand().run(hookName, arg: arg);
    case 'list':
      ListCommand().run();
    case 'check':
      exitCode = CheckCommand().run();
    default:
      _printHelp();
  }
}

void _printHelp() {
  print('dart_husky — Git hook manager for Dart & Flutter');
  print('');
  print('Usage: dart run dart_husky <command>');
  print('');
  print('Commands:');
  for (final entry in _description.entries) {
    print('  ${entry.key.padRight(12)}${entry.value}');
  }
}
