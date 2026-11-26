import 'package:dart_husky/src/config/config_model.dart';
import 'package:dart_husky/src/hooks/hook_installer.dart';
import 'package:dart_husky/src/hooks/hook_status.dart';
import 'package:test/test.dart';

void main() {
  group('HookStatus.of', () {
    const foreignScript = '#!/bin/sh\nnpx lint-staged\n';

    test('inSync when the file is exactly what install writes', () {
      for (final hookType in HookType.values) {
        final status = HookStatus.of(
          hookType,
          contents: HookInstaller.generateScript(hookType),
          isConfigured: true,
        );
        expect(status, HookStatus.inSync, reason: hookType.scriptName);
      }
    });

    test('missing when configured but there is no file', () {
      final status = HookStatus.of(
        HookType.preCommit,
        contents: null,
        isConfigured: true,
      );
      expect(status, HookStatus.missing);
    });

    test('foreign when the file has no dart_husky marker', () {
      final status = HookStatus.of(
        HookType.preCommit,
        contents: foreignScript,
        isConfigured: true,
      );
      expect(status, HookStatus.foreign);
    });

    test('outdated when the file has the marker but other content', () {
      final edited = HookInstaller.generateScript(HookType.preCommit)
          .replaceFirst('dart run', 'flutter pub run');
      final status = HookStatus.of(
        HookType.preCommit,
        contents: edited,
        isConfigured: true,
      );
      expect(status, HookStatus.outdated);
    });

    test('outdated when the file is the script for another hook', () {
      final status = HookStatus.of(
        HookType.commitMsg,
        contents: HookInstaller.generateScript(HookType.preCommit),
        isConfigured: true,
      );
      expect(status, HookStatus.outdated);
    });

    test('stale when a generated file exists for an unconfigured hook', () {
      final status = HookStatus.of(
        HookType.prePush,
        contents: HookInstaller.generateScript(HookType.prePush),
        isConfigured: false,
      );
      expect(status, HookStatus.stale);
    });

    test('notExecutable when the file is in sync but not executable', () {
      final status = HookStatus.of(
        HookType.commitMsg,
        contents: HookInstaller.generateScript(HookType.commitMsg),
        isConfigured: true,
        isExecutable: false,
      );
      expect(status, HookStatus.notExecutable);
    });

    test('content problems win over a missing executable bit', () {
      const isExecutable = false;
      expect(
        HookStatus.of(
          HookType.preCommit,
          contents: '#!/bin/sh\n${HookInstaller.generatedMarker}\n',
          isConfigured: true,
          isExecutable: isExecutable,
        ),
        HookStatus.outdated,
      );
      expect(
        HookStatus.of(
          HookType.preCommit,
          contents: foreignScript,
          isConfigured: true,
          isExecutable: isExecutable,
        ),
        HookStatus.foreign,
      );
      expect(
        HookStatus.of(
          HookType.prePush,
          contents: HookInstaller.generateScript(HookType.prePush),
          isConfigured: false,
          isExecutable: isExecutable,
        ),
        HookStatus.stale,
      );
    });

    test('stale even if the unconfigured generated file is outdated', () {
      final status = HookStatus.of(
        HookType.prePush,
        contents: '#!/bin/sh\n${HookInstaller.generatedMarker}\n',
        isConfigured: false,
      );
      expect(status, HookStatus.stale);
    });

    test('null when the hook is not configured and there is no file', () {
      final status = HookStatus.of(
        HookType.prePush,
        contents: null,
        isConfigured: false,
      );
      expect(status, isNull);
    });

    test('null for a hand-written file of an unconfigured hook', () {
      final status = HookStatus.of(
        HookType.prePush,
        contents: foreignScript,
        isConfigured: false,
      );
      expect(status, isNull);
    });
  });

  group('HookInstaller.generateScript', () {
    test('contains the generated marker', () {
      for (final hookType in HookType.values) {
        expect(
          HookInstaller.generateScript(hookType),
          contains(HookInstaller.generatedMarker),
        );
      }
    });

    test('passes the message file to commit-msg only', () {
      expect(
        HookInstaller.generateScript(HookType.commitMsg),
        contains('dart run dart_husky run commit-msg "\$1"'),
      );
      expect(
        HookInstaller.generateScript(HookType.preCommit),
        isNot(contains('"\$1"')),
      );
    });
  });
}
