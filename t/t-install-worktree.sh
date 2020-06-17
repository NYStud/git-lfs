#!/usr/bin/env bash

. "$(dirname "$0")/testlib.sh"

# These tests rely on behavior found in Git versions higher than 2.20.0 to
# perform themselves, specifically:
#   - worktreeConfig extension support
ensure_git_version_isnt $VERSION_LOWER "2.20.0"

begin_test "install --worktree outside repository"
(
  set -e

  # If run inside the git-lfs source dir this will update its .git/config & cause issues
  if [ "$GIT_LFS_TEST_DIR" == "" ]; then
    echo "Skipping install --worktree because GIT_LFS_TEST_DIR is not set"
    exit 0
  fi

  has_test_dir || exit 0

  set +e
  git lfs install --worktree >out.log
  res=$?
  set -e

  [ "Not in a git repository." = "$(cat out.log)" ]
  [ "0" != "$res" ]
)
end_test

begin_test "install --worktree with single working tree"
(
  set -e

  # old values that should be ignored by `install --worktree`
  git config --global filter.lfs.smudge "git lfs smudge %f"
  git config --global filter.lfs.clean "git lfs clean %f"

  mkdir install-single-tree-repo
  cd install-single-tree-repo
  git init
  git lfs install --worktree

  [ "git-lfs clean -- %f" = "$(git config filter.lfs.clean)" ]
  [ "git-lfs clean -- %f" = "$(git config --local filter.lfs.clean)" ]
  [ "git-lfs clean -- %f" = "$(git config --worktree filter.lfs.clean)" ]
  [ "git lfs clean %f" = "$(git config --global filter.lfs.clean)" ]
  [ "git-lfs filter-process" = "$(git config filter.lfs.process)" ]
  [ "git-lfs filter-process" = "$(git config --local filter.lfs.process)" ]
  [ "git-lfs filter-process" = "$(git config --worktree filter.lfs.process)" ]
)
end_test

begin_test "install --worktree with multiple working trees"
(
  set -e

  mkdir install-multi-trees-repo
  cd install-multi-trees-repo
  git init

  # old values that should be ignored by `install --worktree`
  git config --global filter.lfs.smudge "git lfs smudge %f"
  git config --global filter.lfs.clean "git lfs clean %f"
  git config --local filter.lfs.smudge "git-lfs smudge %f"
  git config --local filter.lfs.clean "git-lfs clean %f"

  touch a.txt
  git add a.txt
  git commit -m "initial commit"

  git config extensions.worktreeConfig true
  git worktree add ../install-multi-trees-repo-tree

  cd ../install-multi-trees-repo-tree
  git lfs install --worktree

  [ "git-lfs clean -- %f" = "$(git config filter.lfs.clean)" ]
  [ "git-lfs clean -- %f" = "$(git config --worktree filter.lfs.clean)" ]
  [ "git-lfs clean %f" = "$(git config --local filter.lfs.clean)" ]
  [ "git lfs clean %f" = "$(git config --global filter.lfs.clean)" ]
  [ "git-lfs filter-process" = "$(git config filter.lfs.process)" ]
  [ "git-lfs filter-process" = "$(git config --worktree filter.lfs.process)" ]
)
end_test

begin_test "install --worktree without worktreeConfig extension"
(
  set -e

  mkdir install-no-tree-config-repo
  cd install-no-tree-config-repo
  git init

  touch a.txt
  git add a.txt
  git commit -m "initial commit"

  git worktree add ../install-no-tree-config-repo-tree

  cd ../install-no-tree-config-repo-tree

  set +e
  git lfs install --worktree >out.log
  res=$?
  set -e

  cat out.log
  grep -E "error running.*git.*config" out.log
  [ "$res" -eq 2 ]
)
end_test

begin_test "install --worktree with conflicting scope"
(
  set -e

  mkdir install-tree-scope-conflict
  cd install-tree-scope-conflict
  git init

  set +e
  git lfs install --local --worktree 2>err.log
  res=$?
  set -e

  [ "Only one of --local and --worktree options can be specified." = "$(cat err.log)" ]
  [ "0" != "$res" ]

  set +e
  git lfs install --worktree --system 2>err.log
  res=$?
  set -e

  [ "Only one of --worktree and --system options can be specified." = "$(cat err.log)" ]
  [ "0" != "$res" ]
)
end_test
