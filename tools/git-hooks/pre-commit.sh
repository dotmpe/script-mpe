#!/usr/bin/env bash

# Executes before commit-msg is determined, to check stage or tree and abort if desired

# See man 5 githooks

test -z "${scm_nok:-}" || exit $scm_nok

: "${LOG:="/srv/project-local/user-scripts/tools/sh/log.sh"}"
test -x "${LOG:-}" || exit 103

set -euo pipefail -o posix

: "${PROJECT_BASE:="`git rev-parse --show-toplevel`"}"

BRANCH_NAME="$(git rev-parse --abbrev-ref HEAD)"

# TODO: limit output to about one screen max, about 80 lines;
# start with top-10's for below scans.

: "${max_lines_per_check:=10}"

# Compare to-be committed against HEAD or emty for initial commit

if git rev-parse --verify HEAD >/dev/null 2>&1
then
  against=HEAD
else
  # Initial commit: diff against an empty tree object
  against=4b825dc642cb6eb9a060e54bf8d69288fbee4904
fi

# Use config hooks.allownonascii to configure this check
# If you want to allow non-ASCII filenames set hooks.allownonascii to true.
allownonascii=$(git config --bool hooks.allownonascii) || true

# Redirect output to stderr.
exec 1>&2


test -n "${git_pre_commit_asciinames:-}" || {

  # Cross platform projects tend to avoid non-ASCII filenames; prevent
  # them from being added to the repository. We exploit the fact that the
  # printable range starts at the space character and ends with tilde.
  if [ "$allownonascii" != "true" ] &&
    # Note that the use of brackets around a tr range is ok here, (it's
    # even required, for portability to Solaris 10's /usr/bin/tr), since
    # the square bracket bytes happen to fall in the designated range.
    test $(git diff --cached --name-only --diff-filter=A -z $against |
      LC_ALL=C tr -d '[ -~]\0' | wc -c) != 0
  then
    cat <<\EOF
Error: Attempt to add a non-ASCII file name.

This can cause problems if you want to work with people on other platforms.

To be portable it is advisable to rename the file.

If you know what you are doing you can disable this check using:

  git config hooks.allownonascii true

EOF

    test -x "$(which ggrep)" && ggrep=ggrep || ggrep=grep
    { git diff --cached --name-only --diff-filter=A -z $against |
      tr -s '\n\r' '\n' |
      $ggrep --color='auto' '[^[:print:]]' ||
        echo "Cannot find trouble files..."
    } | head -n $max_lines_per_check
    echo
    exit 1
  fi

  git_pre_commit_asciinames=1
}

test -n "${git_pre_commit_whitespace:-}" || {

  # If there are whitespace errors, print the offending file names and fail.
  git diff-index --check --cached $against -- &&
    $LOG note "OK" "Git whitespace checked" ||
    $LOG warn "Not OK" "Git whitespace check failed" "$?" 1

  git_pre_commit_whitespace=1
}

test -n "${git_pre_commit_global:-}" || {

  test ! -x $HOME/.git-checks || {
    test -e ${PROJECT_BASE}/.git/checks || {
      ln -s $HOME/.git-checks ${PROJECT_BASE}/.git/checks
    }

  }
  test ! -x ${PROJECT_BASE}/.git-checks || {
    $LOG info "" "Global/local Git checks..."
    . ${PROJECT_BASE}/.git/checks
  }

  git_pre_commit_global=1
}

test -n "${git_pre_commit_versioning:-}" || {
  test \
       -e ${PROJECT_BASE}/.version-attributes \
    -o -e ${PROJECT_BASE}/.versioned-files.list && {

    git-versioning check &&
      $LOG note "OK" "Git-version checked" ||
      $LOG warn "Not OK" "Git versioning check failed" "$?" 1
  }
  git_pre_commit_versioning=1
}

test -n "${git_pre_commit_make:-}" || {
  test ! -e ${PROJECT_BASE}/Makefile || {

    $LOG info "" "Makefile default..."
    make -C ${PROJECT_BASE} &&
      $LOG note "OK" "Makefile default" ||
      $LOG warn "Not OK" "Makefile default failed" "$?" 1
  }
  git_pre_commit_make=1
}

# From GIT Annex hooks

test -n "${git_pre_commit_annex:-}" || {
  test ! -d .git/annex || {
    git annex pre-commit . ||
      $LOG error "" "GIT Annex pre-commit hook failed" $? 1
  }
  git_pre_commit_annex=1
}

# Id: User-scripts/0.0 ~/.git-pre-commit.bash
