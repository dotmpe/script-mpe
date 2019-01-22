#!/usr/bin/env bash
test ${SHLVL:-0} -le ${lib_lvl:-0} && status=return || { lib_lvl=$SHLVL && set -euo pipefail -o posix && status=exit ; } # Inherit shell or init new

test -z "${scm_nok:-}" || $status $scm_nok

: "${PROJECT_BASE:="`git rev-parse --show-toplevel`"}"

: "${max_lines_per_check:=10}"
# XXX: : "${keep_going:=1}"

: "${fail_cnt:=0}"
: "${pass_cnt:=0}"
: "${step:=$(( $pass_cnt + $fail_cnt ))}"

c_nr=070
c_lbl="Filename encoding check"
_070_stat=

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

for file in $(git diff --cached --name-only)
do
  test -e "$file" || continue # Ignore deleted (assuming it is, or renamed)
  step=$(( $step + 1 ))

  # Cross platform projects tend to avoid non-ASCII filenames; prevent
  # them from being added to the repository. We exploit the fact that the
  # printable range starts at the space character and ends with tilde.
  if [ "$allownonascii" != "true" ] &&
    # Note that the use of brackets around a tr range is ok here, (it's
    # even required, for portability to Solaris 10's /usr/bin/tr), since
    # the square bracket bytes happen to fall in the designated range.
    test $(git diff --cached --name-only --diff-filter=A -z $against -- "$file" |
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
    { git diff --cached --name-only --diff-filter=A -z $against -- "$file" |
      tr -s '\n\r' '\n' |
      $ggrep --color='auto' '[^[:print:]]' ||
        echo "Cannot find trouble files..."
    } | head -n $max_lines_per_check
    echo
    _070_stat=1
    fail_cnt=$(( $fail_cnt + 1 ))
    test ${keep_going} -ne 0 || break
  fi

done

: "${CMD:=$(basename -- "$0" .sh)}"
test $step -gt $(( $pass_cnt + $fail_cnt )) ||
  $LOG "warn" "$CMD" "No staged files to check!"

export step
pass_cnt=$(( $step - $fail_cnt ))
test $fail_cnt -eq 0 &&
  echo "Pass [$c_nr] $c_lbl done: $pass_cnt/$step" >&2 ||
  echo "Fail [$c_nr] $c_lbl errored: $pass_cnt/$step" >&2
$status $_070_stat

# Copy: U-S:
