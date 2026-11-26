import 'dart:io';

/// Variables git exports to the hooks it runs. When the tests run inside
/// this repo's own pre-commit hook they would point the git commands below
/// at this repo instead of the temporary one, so they are removed.
const _repositoryVariables = {
  'GIT_DIR',
  'GIT_WORK_TREE',
  'GIT_COMMON_DIR',
  'GIT_INDEX_FILE',
  'GIT_OBJECT_DIRECTORY',
  'GIT_ALTERNATE_OBJECT_DIRECTORIES',
  'GIT_PREFIX',
};

/// Environment for git commands run against a temporary test repository.
Map<String, String> isolatedGitEnvironment() {
  return Map.of(Platform.environment)
    ..removeWhere(
      (key, _) => _repositoryVariables.contains(key.toUpperCase()),
    );
}

/// Runs git in [workingDirectory] and throws if it fails.
Future<void> runGit(String workingDirectory, List<String> arguments) async {
  final result = await Process.run(
    'git',
    arguments,
    workingDirectory: workingDirectory,
    environment: isolatedGitEnvironment(),
    includeParentEnvironment: false,
  );

  if (result.exitCode != 0) {
    throw ProcessException(
      'git',
      arguments,
      result.stderr.toString(),
      result.exitCode,
    );
  }
}

/// Creates a git repository in [directory] with a commit identity set.
Future<void> initRepository(String directory) async {
  await runGit(directory, ['init']);
  await runGit(directory, ['config', 'user.email', 'test@example.com']);
  await runGit(directory, ['config', 'user.name', 'Test User']);
}
