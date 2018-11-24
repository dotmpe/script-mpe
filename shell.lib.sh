#!/bin/sh

shell_lib_load()
{
  # Dir to record env-keys snapshots:SD-Shell-Dir
  test -n "$SD_SHELL_DIR" || SD_SHELL_DIR="$HOME/.statusdir/shell"

  test -n "$base" || base=$(test -e "$0" && basename "$0" .sh || printf -- "$0")

  test -n "$SH_SID" || SH_SID=$(get_uuid)

  # Shell Name (no path/ext)
  SHELL_NAME="$(basename "$SHELL")"
}

# Init env by testing for key vars, set <SHELL>_SH=[01] based on name,
# and IS_<SHELL>_SH=[01] to indicate actual detected shell. Shells are
# hardcoded bash, z, k (Korn), dash/ash (Debian-Almquist shells), and ofcourse
# sh usually used as alias/symlinked '/bin/sh' mode with bash and others.
# Here also a BusyBox [bb] and Heirloom Bourne shell [heir] are detected.
#
# TODO: z-shell builtins table, add others as well
# NOTE: that leaves a host of other popular, novell or modern shells untested;
# fish, posh, yash, and osh are candidates to be added.
# XXX: also these checks are snapshots w/o version checks, also maybe other
# variations in bi/sbi/a/bin may invalidate thise code.
#
# See shell-check, shell-test-sh and sh-env-init,
# and also <doc/shell-builtins.tab>
shell_init()
{
  # Try to figure out what we are.. and how to keep it Bourne Shell compatible
  test "$SHELL_NAME" = "bash" && BA_SHELL=1 || BA_SHELL=0
  test "$SHELL_NAME" = "zsh" && Z_SHELL=1 || Z_SHELL=0
  test "$SHELL_NAME" = "ksh" && KORN_SHELL=1 || KORN_SHELL=0
  test "$SHELL_NAME" = "dash" && D_A_SHELL=1 || D_A_SHELL=0
  test "$SHELL_NAME" = "ash" && A_SHELL=1 || A_SHELL=0
  test "$SHELL_NAME" = "sh" && B_SHELL=1 || B_SHELL=0
  shell_check && sh_init_mode && sh_env_init
}

# is-bash check, expect no typeset (ksh) TODO: zshell bi table.
shell_check()
{
  type typeset 2>&1 >/dev/null && {
    test 1 -eq $KORN_SHELL -o 1 -eq $Z_SHELL -o 1 -eq $BA_SHELL || {

      # Not spent much time outside GNU, busybox or BSD 'sh' & Bash.
      echo "Found typeset cmd, expected Bash or Z-Sh ($SHELL_NAME)" >&2
      return 1
    }
  } || true
}

sh_init_mode()
{
  IS_BASH_SH=0
  IS_DASH_SH=0
  IS_BB_SH=0
  IS_HEIR_SH=0
  test "$SHELL_NAME" != "sh" || {
    shell_test_sh
  }

  test $BA_SHELL -eq 1 -o $IS_BASH_SH -eq 1 && IS_BASH=1 || IS_BASH=0

  test $D_A_SHELL -eq 1 -o $IS_DASH_SH -eq 1 && IS_DASH=1 || IS_DASH=0
  test $D_A_SHELL -eq 1 -o $A_SHELL -eq 1 -o $IS_DASH_SH -eq 1 && IS_A=1 || IS_A=0
  # FIXME A_SHELL=..

  #test $BB_SH -eq 1 -o $IS_BB_SH -eq 1 && IS_BB=1 || IS_BB=0
  # XXX: do Korn or Z have Sh-modes?

  test $IS_HEIR_SH -eq 1 && IS_HIER=1 || IS_HIER=0
  HEIR_SH=$IS_HEIR_SH
}

# Try to detect Shell variant based on specific commands.
# See <doc/shell-builtins.tab>
shell_test_sh()
{
  sh_is_type_bi 'bind' && IS_BASH_SH=1 || {

    sh_is_type_sbi 'local' && {
      sh_is_type_bi 'let' && IS_BB_SH=1 || IS_DASH_SH=1

    } || {
      sh_is_type_bin 'false' &&
        # Assume heirloom shell
        IS_HEIR_SH=1 || false # unknown Sh
    }
  }
}


# Define sh-env. to get plain env var name/value list, including local vars
sh_env_init()
{
  # XXX: test other shells.. etc. etc.
  test $IS_BASH -eq 1 && {
    sh_env()
    {
      set | grep '^[a-zA-Z_][0-9a-zA-Z_]*=.*$'
    }
  } || {
    sh_env()
    {
      set
    }
  }
  sh_isset()
  {
    sh_env | grep -q "^$1="
  }
  sh_isenv()
  {
    env | grep -q "^$1="
  }
}


# Test true if CMD is a builtin command
sh_is_type_bi() # CMD
{
  type "$1" | grep -q '^[^ ]* is a shell builtin$'
}

# Test true if CMD is a special builtin command
sh_is_type_sbi() # CMD
{
  type "$1" | grep -q '^[^ ]* is a special shell builtin$'
}

# Test true if CMD is an shell command alias
sh_is_type_a() # CMD
{
  type "$1" | grep -q '^[^ ]* is \(aliased to\|an alias for\) .*$'
}

# Test true if CMD resolves to an executable at path
sh_is_type_bin() # CMD
{
  type "$1" | grep -q '^[^ ]* is /[^ ]*$'
}

# Test true if CMD is not builtin or executable, or any of the above
sh_is_type_na() # CMD
{
  type "$1" | grep -q '^.* not found$'
}


# Tell what CMD definition for given ALIAS is defined (extended Sh-mode covering
# common shell)
sh_aliasinfo_sh() # ALIAS
{
  sh_is_type_a "$1" || return
  type "$1" | sed -E 's/^[^ ]* is (aliased to|an alias for) .(.*)./\2/g'
}

# Tell what given CMD name is, like `type`
sh_aliasinfo() # ALIAS
{
  sh_aliasinfo_sh "$1"
}


# Tell what given CMD name is, like `type`
sh_execinfo() # CMD...
{
  local i= ; test $# -gt 1 && i=":\$1"
  s= p= act=sh_execinfo_ foreach_do "$@"
}

# Inner foreach-do routine for sh-execinfo
sh_execinfo_() # CMD
{
  sh_is_type_na "$1" && {

    echo na$i
    return 2
  }

  sh_is_type_sbi "$1" && eval echo \"sbi$i\"
  sh_is_type_bi "$1" &&  eval echo \"bi$i\"
  sh_is_type_a "$1" &&   eval echo \"a$i:"\$(sh_aliasinfo "$1")"\"
  sh_is_type_bin "$1" && eval echo \"bin$i:"\$(which "$1")"\"
  true
}


# TODO: maybe use env with shell-test/detect etc. And/otherwise move this,
# env.lib.sh? Consolidate user-conf first.

# Record env keys only; assuming thats safe, no literal dump b/c of secrets
record_env_keys()
{
  test -n "$1" || return
  env_keys > "$SD_SHELL_DIR/$1.sh"
}

record_env_ls()
{
  test -n "$1" && set -- "$$$1" || set -- "$SD_PREF"
  for name in "$SD_SHELL_DIR/$1"*
  do
    echo "$(ls -la "$name") $( count_lines "$name") keys"
  done
}

env_keys()
{
  sh_env | sed 's/=.*$//' | grep -v '^_$' | sort -u
}

record_env_diff_keys()
{
  test -n "$1" || set -- "$(ls "$SD_SHELL_DIR" | head -n 1)" "$2"
  test -n "$2" || set -- "$1" "$(ls "$SD_SHELL_DIR" | tail -n 1)"

  # FIXME:
  #test -e "$1" -a -e "$2" || stderr "record-env-keys-diff" '' 1
  #test -e "$SD_SHELL_DIR/$1" -a -e "$SD_SHELL_DIR/$2" || error "record-env-keys-diff" 1

  #note "comm -23 '$SD_SHELL_DIR/$2' '$SD_SHELL_DIR/$1'"
  comm -23 "$SD_SHELL_DIR/$2" "$SD_SHELL_DIR/$1"
}
