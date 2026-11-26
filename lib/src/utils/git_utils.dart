import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as path;

/// Utilities for interacting with the git repository
class GitUtils {
  /// Variables that point git at a specific repository. Git exports them to
  /// the hooks it runs, so they can leak into dart_husky from a hook.
  static const _repositoryVariables = {
    'GIT_DIR',
    'GIT_WORK_TREE',
    'GIT_COMMON_DIR',
  };

  /// Finds the git repository that contains [workingDirectory].
  ///
  /// Returns the top-level directory of its work tree, and the folder git
  /// reads hooks from: `.git/hooks` by default, `core.hooksPath` if set, and
  /// the main repository's hooks folder in a linked worktree. The hooks
  /// folder may not exist yet.
  ///
  /// The repository is found from [workingDirectory] alone, ignoring
  /// `GIT_DIR` and similar variables. Returns null if [workingDirectory] is
  /// not inside a git work tree. Throws a [ProcessException] if git can't be
  /// run.
  static ({String topLevel, String hooksPath})? findHooks(
    String workingDirectory,
  ) {
    final environment = Map.of(Platform.environment)
      ..removeWhere(
        (key, _) => _repositoryVariables.contains(key.toUpperCase()),
      );

    final result = Process.runSync(
      'git',
      ['rev-parse', '--show-toplevel', '--git-path', 'hooks'],
      workingDirectory: workingDirectory,
      environment: environment,
      includeParentEnvironment: false,
    );

    if (result.exitCode != 0) return null;

    final lines = const LineSplitter().convert(result.stdout.toString().trim());
    if (lines.length != 2) return null;

    return (
      topLevel: path.normalize(lines[0]),
      // --git-path is relative to the directory git ran in, unless absolute
      hooksPath: path.normalize(path.join(workingDirectory, lines[1])),
    );
  }

  /// Returns a list of currently staged, non-deleted file paths
  /// Returns empty list if no files are staged
  ///
  /// By default git inherits this process's environment, including the
  /// `GIT_DIR` and `GIT_INDEX_FILE` that git exports to hooks. A hook needs
  /// them: during `git commit -a` the staged files are in a temporary index
  /// that only `GIT_INDEX_FILE` points to. Pass [environment] to run git
  /// with exactly that environment instead.
  static Future<List<String>> getStagedFiles({
    String? workingDirectory,
    Map<String, String>? environment,
  }) async {
    final result = await Process.run(
      'git',
      [
        'diff',
        '--cached',
        '--name-only',
        '--diff-filter=ACMR',
      ],
      runInShell: true,
      workingDirectory: workingDirectory,
      environment: environment,
      includeParentEnvironment: environment == null,
    );

    if (result.exitCode != 0) return [];

    return result.stdout
        .toString()
        .trim()
        .split('\n')
        .where((f) => f.isNotEmpty)
        .toList();
  }
}
