#!/bin/sh

shell_lib_load()
{
  test -n "$SD_SHELL_DIR" || SD_SHELL_DIR="$HOME/.statusdir/shell"
  SH_NAME="$(basename "$SHELL")"
  shell_init
}

shell_init()
{
  # Try to figure out what we are.. and how to keep it Bourne Shell compatible
  test "$SH_NAME" = "bash" && BASH_SH=1 || BASH_SH=0
  test "$SH_NAME" = "zsh" && Z_SH=1 || Z_SH=0
  test "$SH_NAME" = "ksh" && KORN_SH=1 || KORN_SH=0
  test "$SH_NAME" = "dash" && DASH_SH=1 || DASH_SH=0
  test "$SH_NAME" = "ash" && ASH_SH=1 || ASH_SH=0
  test "$SH_NAME" = "sh" && SH_SH=1 || SH_SH=0
  shell_check && {
    test "$SH_NAME" != "sh" && {
      IS_BASH_SH=0
      IS_DASH_SH=0
      IS_BB_SH=0
      IS_HEIR_SH=0
    } || shell_test_sh
  } && shell_init_env
}

# Define _env_. to get plain env var name/value list, including local vars
shell_init_env()
{
  # XXX: test other shells.. etc. etc.
  test $BASH_SH -eq 1 -o $IS_BASH_SH -eq 1 && {
    _env_()
    {
      printenv
    }
  } || {
    _env_()
    {
      set
    }
  }
}

# is-bash check, expect no typeset (ksh) TODO: zshell bi table.
shell_check()
{
  type typeset 2>&1 >/dev/null && {
    test 1 -eq $KORN_SH -o 1 -eq $Z_SH -o 1 -eq $BASH_SH || {

      # Not spent much time outside GNU, busybox or BSD 'sh' & Bash.
      echo "Found typeset cmd, expected Bash or Z-Sh ($SH_NAME)" >&2
      return 1
    }
  } || true
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
  _env_ | sed 's/=.*$//' | grep -v '^_$' | sort -u
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
