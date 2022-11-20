#!/bin/sh
if [ "${LIB_GIT-}" ]; then
  return 0
fi
LIB_GIT=1
. ./log.sh

set_git_base() {
  if [ -n "${GIT_BASE_DONE:-}" ]; then
    return
  fi

  if [ -n "${CI_ALL:-}" ]; then
    return
  fi

  if git show --no-patch --format=%s%n%b | grep -qiF '\[ci-all\]'; then
    return
  fi

  if [ "$(git rev-parse --is-shallow-repository)" = true ]; then
    git fetch --unshallow origin master
  fi

  # Unfortunately --grep searches the whole commit message but we just want the header
  # searched. Should fix by using grep directly later.
  export GIT_BASE="$(git log --merges --grep="Merge pull request" --grep="\[ci-base\]" --format=%h HEAD~1 | head -n1)"
  export GIT_BASE_DONE=1
  if [ -n "$GIT_BASE" ]; then
    echop make "GIT_BASE=$GIT_BASE"
  fi
}

is_changed() {
  set_git_base
  if [ -z "${GIT_BASE:-}" ]; then
    return
  fi

  ! git diff --quiet "$GIT_BASE" -- "$@" ||
    [ -n "$(git ls-files --other --exclude-standard -- "$@")" ]
}

set_changed_files() {
  set_git_base

  if [ -n "${CHANGED_FILES:-}" ]; then
    return
  fi

  CHANGED_FILES=./.changed-files
  git ls-files --other --exclude-standard > "$CHANGED_FILES"
  if [ -n "${GIT_BASE:-}" ]; then
    git diff --relative --name-only "$GIT_BASE" | filter_exists >> "$CHANGED_FILES"
  else
    git ls-files >> "$CHANGED_FILES"
  fi
  export CHANGED_FILES
}

git_assert_clean() {
  should_color || true
  git ${_COLOR:+-c color.diff=always} diff --exit-code
}

filter_exists() {
  while read -r p; do
    if [ -e "$p" ]; then
      printf '%s\n' "$p"
    fi
  done
}

git_describe_ref() {
  TAG="$(git describe 2> /dev/null || true)"
  if [ -n "$TAG" ]; then
    _echo "$TAG"
  else
    git rev-parse --short HEAD
  fi
}

search_up() {
  file="$1"
  git_root="$(git rev-parse --show-toplevel)"
  while true; do
    if [ -e "$file" ]; then
      _echo "$file"
      return
    fi
    if [ "$PWD" = "$git_root" ]; then
      break
    fi
    cd ..
  done
  return 1
}

xargsd() {
  set_changed_files

  pattern="$1"
  shift

  < "$CHANGED_FILES" grep "$pattern" | hide xargs ${CI:+-r} -t -P16 "-n${XARGS_N:-256}" -- "$@"
}
