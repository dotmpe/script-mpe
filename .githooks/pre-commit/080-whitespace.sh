#!/usr/bin/env bash
test ${SHLVL:-0} -le ${lib_lvl:-0} && status=return || { lib_lvl=$SHLVL && set -euo pipefail -o posix && status=exit ; } # Inherit shell or init new

test -z "${scm_nok:-}" || $status $scm_nok

: "${LOG:="/srv/project-local/user-scripts/tools/sh/log.sh"}"
test -x "${LOG:-}" || exit 103

: "${PROJECT_BASE:="`git rev-parse --show-toplevel`"}"

: "${max_lines_per_check:=10}"
: "${keep_going:=1}"

: "${fail_cnt:=0}"
: "${pass_cnt:=0}"
: "${step:=$(( $pass_cnt + $fail_cnt ))}"

c_nr=080
c_lbl=Whitespace\ check
_080_stat=

# Compare to-be committed against HEAD or emty for initial commit
if git rev-parse --verify HEAD >/dev/null 2>&1
then
  against=HEAD
else
  # Initial commit: diff against an empty tree object
  against=4b825dc642cb6eb9a060e54bf8d69288fbee4904
fi

{
  for file in $(git diff --cached --name-only)
  do
    test -e "$file" || continue # Ignore deleted (assuming it is, or renamed)
    step=$(( $step + 1 ))

    # If there are whitespace errors, print the offending file names and fail.
    git diff-index --check --cached $against -- $file && {
      $LOG note "OK" "Git whitespace checked" "$file"
    } || {
        _080_stat=$?
        fail_cnt=$(( $fail_cnt + 1 ))
        $LOG warn "Not OK" "Git whitespace check failed" "$_080_stat $file"
        test ${keep_going} -ne 0 || break
    }
  done

  : "${CMD:=$(basename -- "$0" .sh)}"
  test $step -gt $(( $pass_cnt + $fail_cnt )) ||
    $LOG "warn" "$CMD" "No staged files to check!" "$step <= $(( $pass_cnt + $fail_cnt ))"

  export step
  pass_cnt=$(( $step - $fail_cnt ))
  test $fail_cnt -eq 0 &&
    echo "Pass [$c_nr] $c_lbl done: $pass_cnt/$step" >&2 ||
    echo "Fail [$c_nr] $c_lbl errored: $pass_cnt/$step" >&2
  $status $_080_stat

} | head -n ${max_lines_per_check}

# Copy: U-S:
