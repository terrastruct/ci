#!/bin/sh
if [ "${LIB_GIT-}" ]; then
  return 0
fi
LIB_GIT=1
. ./log.sh

ensure_git_base() {
  if [ "${GIT_BASE+x}" = x ]; then
    return
  fi

  if [ -n "${CI_FORCE-}" ]; then
    return
  fi

  if [ "$(git_commit_count)" -lt 2 ]; then
    GIT_BASE=
    export GIT_BASE
    return
  fi

  if git show --no-patch --format=%s%n%b | grep -qiF '\[ci-all\]'; then
    return
  fi

  if [ "$(git rev-parse --is-shallow-repository)" = true ]; then
    git fetch --recurse-submodules=no --unshallow origin master
  fi

  # Unfortunately --grep searches the whole commit message but we just want the header
  # searched. Should fix by using grep directly later.
  GIT_BASE="$(git log --grep="Merge pull request" --grep="\[ci-base\]" --format=%h HEAD~1 | head -n1)"
  export GIT_BASE
  if [ -n "$GIT_BASE" ]; then
    echop "GIT_BASE=$GIT_BASE"
  fi
}

is_changed() {
  ensure_git_base
  if [ -z "${GIT_BASE-}" ]; then
    return
  fi

  ! git diff --quiet "$GIT_BASE" -- "$@" ||
    [ -n "$(git ls-files --other --exclude-standard -- "$@")" ]
}

ensure_changed_files() {
  ensure_git_base

  if [ -n "${CHANGED_FILES-}" ]; then
    return
  fi

  CHANGED_FILES=$(mktemp -d)/changed-files
  trap changed_files_exittrap EXIT
  git ls-files --other --exclude-standard > "$CHANGED_FILES"
  if [ -n "${GIT_BASE-}" ]; then
    git diff --relative --name-only "$GIT_BASE" | filter_exists >> "$CHANGED_FILES"
  else
    git ls-files >> "$CHANGED_FILES"
  fi
  export CHANGED_FILES
  logpcat changed <"$CHANGED_FILES"
}

changed_files_exittrap() {
  rm -f "$CHANGED_FILES"
}

git_assert_clean() {
  if should_color; then
    git -c color.diff=always diff --exit-code
  else
    git -c color.diff=never diff --exit-code
  fi
}

filter_exists() {
  while read -r p; do
    if [ -e "$p" ]; then
      printf '%s\n' "$p"
    fi
  done
}

git_describe_ref() {
  TAG="$(git describe --exact-match 2> /dev/null || true)"
  if [ -n "$TAG" ]; then
    _echo "$TAG"
  else
    git rev-parse --short HEAD
  fi
}

# subshell for cd ..
search_up() {(
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
)}

xargsd() {
  ensure_changed_files

  pattern="$1"
  shift

  < "$CHANGED_FILES" grep "$pattern" | hide xargs ${CI:+-r} -t -P16 "-n${XARGS_N:-256}" -- "$@"
}

nofixups() {
  ensure_git_base
  if [ "$(git_commit_count)" -lt 2 ]; then
    return
  fi
  commits="$(git log --grep='fixup!' --format=%h ${GIT_BASE:+"$GIT_BASE..HEAD"})"
  if [ -n "$commits" ]; then
    echo "$commits" | FGCOLOR=1 logpcat 'fixup detected'
    return 1
  fi
}

git_commit_count() {
  commit_count=$(git rev-list HEAD --count 2>/dev/null) || true
  echo "${commit_count:-0}"
}

configure_github_token() {
  git config --global credential.helper store
  cat > ~/.git-credentials <<EOF
https://cyborg-ts:$GITHUB_TOKEN@github.com
EOF
}

gitpure() {
  if [ -z "${GIT_CONFIG_PURE-}" ]; then
    GIT_CONFIG_PURE="$(mktemp -d)/gitconfig-pure"
    export GIT_CONFIG_PURE
  fi

  if [ -z "${_GIT_CONFIG_PURE-}" ]; then
    if command -v diff-highlight >/dev/null; then
      GIT_CONFIG_GLOBAL=$GIT_CONFIG_PURE command git config --global pager.log 'diff-highlight | less'
      GIT_CONFIG_GLOBAL=$GIT_CONFIG_PURE command git config --global pager.show 'diff-highlight | less'
      GIT_CONFIG_GLOBAL=$GIT_CONFIG_PURE command git config --global pager.diff 'diff-highlight | less'
    fi
    GIT_CONFIG_GLOBAL=$GIT_CONFIG_PURE command git config --global init.defaultBranch master
    GIT_CONFIG_GLOBAL=$GIT_CONFIG_PURE command git config --global user.name "Cyborg Tstruct"
    GIT_CONFIG_GLOBAL=$GIT_CONFIG_PURE command git config --global user.email "info+cyborg@terrastruct.com"
    export _GIT_CONFIG_PURE=1
  fi
  GIT_CONFIG_GLOBAL=$GIT_CONFIG_PURE command git "$@"
}
