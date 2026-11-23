import 'dart:io';

import 'package:dart_husky/src/utils/git_utils.dart';
import 'package:path/path.dart' as path;
import 'package:test/test.dart';

import 'support/git.dart';

void main() {
  group('GitUtils.getStagedFiles', () {
    late Directory repository;

    setUp(() async {
      repository = await Directory.systemTemp.createTemp('dart_husky_git_');
      await initRepository(repository.path);
    });

    tearDown(() async {
      await repository.delete(recursive: true);
    });

    test('excludes staged files that were deleted', () async {
      final retainedFile = File('${repository.path}/retained.dart');
      final deletedFile = File('${repository.path}/deleted.dart');

      await retainedFile.writeAsString('void retained() {}\n');
      await deletedFile.writeAsString('void deleted() {}\n');
      await runGit(repository.path, ['add', '.']);
      await runGit(repository.path, ['commit', '-m', 'initial']);

      await retainedFile
          .writeAsString('void retained() => print("retained");\n');
      await deletedFile.delete();
      await runGit(repository.path, ['add', '--all']);

      expect(
        await GitUtils.getStagedFiles(workingDirectory: repository.path),
        ['retained.dart'],
      );
    });
  });

  group('GitUtils.findHooks', () {
    late Directory repository;

    String canonical(String directory) {
      return path.canonicalize(Directory(directory).resolveSymbolicLinksSync());
    }

    setUp(() async {
      repository = await Directory.systemTemp.createTemp('dart_husky_git_');
      await initRepository(repository.path);
    });

    tearDown(() async {
      await repository.delete(recursive: true);
    });

    test('finds .git/hooks by default', () {
      final hooks = GitUtils.findHooks(repository.path)!;

      expect(canonical(hooks.topLevel), canonical(repository.path));
      expect(
        hooks.hooksPath,
        path.normalize(path.join(repository.path, '.git', 'hooks')),
      );
    });

    test('finds the shared hooks folder from a linked worktree', () async {
      await runGit(repository.path, ['commit', '--allow-empty', '-m', 'init']);
      final worktree = path.join(repository.path, 'wt');
      await runGit(repository.path, ['worktree', 'add', worktree]);

      final hooks = GitUtils.findHooks(worktree)!;

      expect(canonical(hooks.topLevel), canonical(worktree));
      expect(
        canonical(hooks.hooksPath),
        canonical(path.join(repository.path, '.git', 'hooks')),
      );
    });

    test('follows a relative core.hooksPath', () async {
      await runGit(repository.path, ['config', 'core.hooksPath', '.githooks']);

      expect(
        GitUtils.findHooks(repository.path)!.hooksPath,
        path.normalize(path.join(repository.path, '.githooks')),
      );
    });

    test('follows an absolute core.hooksPath', () async {
      final hooks = path.join(repository.path, 'elsewhere');
      await runGit(repository.path, ['config', 'core.hooksPath', hooks]);

      expect(GitUtils.findHooks(repository.path)!.hooksPath, hooks);
    });

    test('reports the top level when run from a subdirectory', () {
      final subdirectory = Directory(path.join(repository.path, 'sub'))
        ..createSync();

      final hooks = GitUtils.findHooks(subdirectory.path)!;

      expect(canonical(hooks.topLevel), canonical(repository.path));
      expect(
        canonical(hooks.hooksPath),
        canonical(path.join(repository.path, '.git', 'hooks')),
      );
    });

    test('returns null outside a git repository', () async {
      final outside = await Directory.systemTemp.createTemp('dart_husky_');
      addTearDown(() => outside.delete(recursive: true));

      expect(GitUtils.findHooks(outside.path), isNull);
    });
  });
}
