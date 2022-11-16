#!/bin/sh
set -eu
. "$(dirname "$0")/../lib.sh"

help() {
  cat <<EOF
usage: $0 [--rebuild] [--prerelease] [--dry-run] [--skip-build] [--publish] --version=<version>

$0 implements the $REPO release process.

Flags:

--rebuild
    Normally the release script will avoid rebuilding release assets if they already exist
    but if you changed something and need to force rebuild, use this flag.
--prerelease
    Pass to mark the release on GitHub as a pre-release. For pre-releases the version
    format should include a suffix like v0.0.99-alpha.1 As well, for pre-releases the
    script will not overwrite changelogs/next.md with changelogs/template.md and instead
    keep it the same as changelogs/v0.0.99-alpha.1.md. This is because you want to
    maintain the changelog entries for the eventual final release.
--dry-run
    Print the commands that would be ran without executing them.
--skip-build
    Skip the build in case you want to upload your own specific assets. Mainly for testing
    and debugging.
--publish
    Do not publish a draft, publish the release if uploading assets succeeds.
    PRs wil be merged as well.

Process:

Let's say you passed in v0.0.99 as the version:

1. It creates branch v0.0.99 based on master if one does not already exist.
   - It then checks it out.
2. It moves changelogs/next.md to changelogs/v0.0.99.md if there isn't already a
   changelogs/v0.0.99.md.
   - If the move occured, changelogs/next.md is replaced with changelogs/template.md.
3. If the current commit does not have a title of v0.0.99 then a new commit with said
   title will be created with all uncommitted changes.
   - If the current commit does, then the uncommitted changes will be amended to the commit.
4. It pushes branch v0.0.99 to origin.
5. It creates a v0.0.99 git tag if one does not already exist.
   If one does, it ensures the v0.0.99 tag points to the current commit.
   Then it pushes the tag to origin.
6. It creates a draft GitHub release for the tag if one does not already exist.
   - It will also set the release notes to match changelogs/v0.0.99.md even
     if the release already exists.
7. It creates a draft PR for branch v0.0.99 into master if one does not already exist.
8. It builds the release assets if they do not exist.
   Pass --rebuild to force rebuilding all release assets.
9. It uploads the release assets overwriting any existing assets on the release.

Only a draft release will be created so do not fret if something goes wrong.
You can just rerun the script again as it is fully idempotent.

To complete the release, merge the release PR and then publish the draft release.

Testing:

For testing, change the origin remote to a private throwaway repository and push master to
it. Then the PR, tag and draft release will be generated against said throwaway
repository.

Example:
  $0 --version=v0.0.99
EOF
}

main() {
  if [ -z "${REPO-}" ]; then
    REPO=$(gh_repo)
    REPO_DIR=.
  fi

  while :; do
    flag_parse "$@"
    case "$FLAG" in
      h|help)
        help
        return 0
        ;;
      rebuild)
        flag_noarg && shift "$FLAGSHIFT"
        REBUILD=1
        ;;
      prerelease)
        flag_noarg && shift "$FLAGSHIFT"
        PRERELEASE=1
        ;;
      dry-run)
        flag_noarg && shift "$FLAGSHIFT"
        DRY_RUN=1
        ;;
      skip-build)
        flag_noarg && shift "$FLAGSHIFT"
        SKIP_BUILD=1
        ;;
      version)
        flag_nonemptyarg && shift "$FLAGSHIFT"
        VERSION=$FLAGARG
        ;;
      '')
        shift "$FLAGSHIFT"
        break
        ;;
      *)
        flag_errusage "unrecognized flag $FLAGRAW"
        ;;
    esac
  done

  if [ $# -gt 0 ]; then
    flag_errusage "no arguments are accepted"
  fi

  VERSION=${VERSION:-$(git describe 2>/dev/null)}
  if [ -z "${VERSION-}" ]; then
    echoerr "no --version passed and unable to determine version from git describe"
    exit 1
  fi

  if [ -z "${REPO_DIR-}" ]; then
    # Releases must be published onto a different repo than the one in which we currently
    # are.
    REPO_DIR="$HOME/.cache/tstruct/release/repo/$REPO"
    if [ ! -e "$REPO_DIR" ]; then
      sh_c mkdir -p "$REPO_DIR"
      sh_c git clone "https://github.com/$REPO" "$REPO_DIR"
    fi
  fi

  header '1_ensure_branch' && _1_ensure_branch
  header '2_ensure_changelog' && _2_ensure_changelog
  header '3_ensure_commit' && _3_ensure_commit
  header '4_push_branch' && _4_push_branch
  header '5_ensure_tag' && _5_ensure_tag
  header '6_ensure_release' && _6_ensure_release
  header '7_ensure_pr' && _7_ensure_pr
  header '8_ensure_assets' && _8_ensure_assets
  header '9_upload_assets' && _9_upload_assets

  if [ -n "${PUBLISH-}" ]; then
    _10_publish
    COLOR=2 header 'success'
    log "1. merged $pr_url"
    if [ -n "${pr_url_repo-}" ]; then
      log "2. merged $pr_url_repo"
      log "3. published $release_url"
    else
      log "2. published $release_url"
    fi
    return 0
  fi

  COLOR=2 header 'final steps'
  log "1. Review and test the release: $release_url"
  log "2. Merge the PR: $pr_url"
  if [ -n "${pr_url_repo-}" ]; then
    log "3. Merge the release repo PR: $pr_url_repo"
    log '4. Publish the release!'
  else
    log '3. Publish the release!'
  fi
}

_1_ensure_branch() {
  if [ -z "$(git branch --list "$VERSION")" ]; then
    sh_c git branch "$VERSION" master
  fi
  sh_c git checkout -q "$VERSION"
  _1_ensure_branch_repodir
}

_1_ensure_branch_repodir() {
  if [ "$REPO_DIR" == . ]; then
    return 0
  fi
  if [ -z "$(git -C "$REPO_DIR" branch --list "$VERSION")" ]; then
    sh_c git -C "$REPO_DIR" branch "$VERSION" master
  fi
  sh_c git -C "$REPO_DIR" checkout -q "$VERSION"
}

_2_ensure_changelog() {
  if [ -f "./ci/release/changelogs/$VERSION.md" ]; then
    log "./ci/release/changelogs/$VERSION.md"
    _2_ensure_changelogs_repodir
    return 0
  fi

  sh_c cp "./ci/release/changelogs/next.md" "./ci/release/changelogs/$VERSION.md"
  if [ -z "${PRERELEASE-}" ]; then
    sh_c cp "./ci/release/changelogs/template.md" "./ci/release/changelogs/next.md"
  fi
  _2_ensure_changelogs_repodir
}

_2_ensure_changelogs_repodir() {
  if [ "$REPO_DIR" == . ]; then
    return 0
  fi
  if [ -f "$REPO_DIR/ci/release/changelogs/$VERSION.md" ]; then
    log "$REPO_DIR/ci/release/changelogs/$VERSION.md"
    return 0
  fi
  sh_c mkdir -p "$REPO_DIR/ci/release/changelogs"
  sh_c cp "./ci/release/changelogs/next.md" "$REPO_DIR/ci/release/changelogs/$VERSION.md"
}

_3_ensure_commit() {
  sh_c git add --all
  if [ "$(git show --no-patch --format=%s)" = "$VERSION" ]; then
    sh_c git commit --allow-empty --amend --no-edit
  else
    sh_c git commit --allow-empty -m "$VERSION"
  fi
  _3_ensure_commit_repodir
}

_3_ensure_commit_repodir() {
  if [ "$REPO_DIR" == . ]; then
    return 0
  fi
  sh_c git -C "$REPO_DIR" add --all
  if [ "$(git -C "$REPO_DIR" show --no-patch --format=%s)" = "$VERSION" ]; then
    sh_c git -C "$REPO_DIR" commit --allow-empty --amend --no-edit
  else
    sh_c git -C "$REPO_DIR" commit --allow-empty -m "$VERSION"
  fi
}

_4_push_branch() {
  sh_c git push -f origin "refs/heads/$VERSION"
  _4_push_branch_repodir
}

_4_push_branch_repodir() {
  if [ "$REPO_DIR" == . ]; then
    return 0
  fi
  sh_c git -C "$REPO_DIR" push -f origin "refs/heads/$VERSION"
  sh_c git -C "$REPO_DIR" push origin master:master
}

_5_ensure_tag() {
  sh_c git -C "$REPO_DIR" tag --force -a "$VERSION" -m "$VERSION"
  sh_c git -C "$REPO_DIR" push -f origin "refs/tags/$VERSION"
}

_6_ensure_release() {
  release_url="$(gh release view --repo "$REPO" "$VERSION" --json=url '--template={{ .url }}' 2>/dev/null || true)"
  if [ -n "$release_url" ]; then
    release_url="$(sh_c gh release edit --repo "$REPO" \
      --notes-file "./ci/release/changelogs/$VERSION.md" \
      ${PRERELEASE:+--prerelease} \
      "--title=$VERSION" \
      "$VERSION" | tee /dev/stderr)"
    return 0
  fi
  release_url="$(sh_c gh release create --repo "$REPO" \
    --draft \
    --notes-file "./ci/release/changelogs/$VERSION.md" \
    ${PRERELEASE:+--prerelease} \
    "--title=$VERSION" \
    "$VERSION" | tee /dev/stderr)"
}

_7_ensure_pr() {
  # We do not use gh pr view as that includes closed PRs.
  pr_url="$(gh pr list --head "$VERSION" --json=url '--template={{ range . }}{{ .url }}{{end}}')"
  body="Will be available at $(cd "$REPO_DIR" && gh repo view --json=url '--template={{ .url }}')/releases/tag/$VERSION"
  if [ -n "$pr_url" ]; then
    pr_url=$(sh_c gh pr edit --body "'$body'" "$VERSION" | tee /dev/stderr)
    return 0
  fi

  pr_url="$(sh_c gh pr create --repo "$REPO" --fill --body "'$body'" | tee /dev/stderr)"

  _7_ensure_pr_repodir
}

_7_ensure_pr_repodir() {
  if [ "$REPO_DIR" == . ]; then
    return 0
  fi

  # We do not use gh pr view as that includes closed PRs.
  pr_url_repo="$(gh pr list --repo "$REPO" --head "$VERSION" --json=url '--template={{ range . }}{{ .url }}{{end}}')"
  body="Will be available at $(cd "$REPO_DIR" && gh repo view --json=url '--template={{ .url }}')/releases/tag/$VERSION"
  if [ -n "$pr_url_repo" ]; then
    pr_url_repo=$(sh_c gh pr edit --repo "$REPO" --body "'$body'" "$VERSION" | tee /dev/stderr)
    return 0
  fi

  pr_url_repo="$(cd "$REPO_DIR" && sh_c gh pr create --repo "$REPO" --fill --body "'$body'" | tee /dev/stderr)"
}

_8_ensure_assets() {
  if [ "${SKIP_BUILD-}" ]; then
    warn "skipping building of assets due to --skip-build"
    return 0
  fi
  sh_c ./ci/release/build.sh ${REBUILD:+--rebuild} --version="$VERSION"
}

_9_upload_assets() {
  REPO=$REPO "$(dirname "$0")/upload_assets.sh" --version="$VERSION"
}

# Only ran if --publish is passed.
_10_publish() {
  release_url="$(sh_c gh release edit --repo "$REPO" --draft=false "$VERSION" | tee /dev/stderr)"
  sh_c gh pr merge "$pr_url"
  if [ -n "${pr_url_repo-}" ]; then
    sh_c gh pr merge "$pr_url_repo"
  fi
}

main "$@"
