#!/bin/sh

# Basic assumptions about Shell, for polyglot script check/test

sh_tester_lib__load ()
{
  # Bash reports all these as '.* is a shell builtin'
  bash_bi_cmds=". : [ alias bg bind break builtin caller cd command compgen "\
"complete compopt continue declare dirs disown echo enable eval exec exit "\
"export false fc fg getopts hash help history jobs kill let local logout "\
"mapfile popd printf pushd pwd read readarray readonly return set shift shopt "\
"source suspend test times trap true type typeset ulimit umask unalias unset "\
"wait"

  # Bash-Sh reports part as '.* is a shell builtin' and the rest as special
  bash_sh_sbi_cmds=". : break continue eval exec exit export readonly return "\
"set shift source times trap unset"
  bash_sh_bi_cmds="[ alias bg bind builtin caller cd command compgen complete"\
" compopt declare dirs disown echo enable false fc fg getopts hash help"\
"history jobs kill let local logout mapfile popd printf pushd pwd read "\
"readarray shopt suspend test true type typeset ulimit umask unalias wait"

 # Heirloom-Sh has no special bi's or aliases
 heirloom_sh_bi_cmds=". : [ bg break cd continue echo eval exec exit export "\
"fg getopts hash jobs kill pwd read readonly return set shift suspend test "\
"times trap type ulimit umask unset wait"
 heirloom_sh_sbi_cmds=""
 heirloom_sh_bin_cmds="false printf true env"
 heirloom_sh_na_cmds="alias bind builtin caller command compgen complete "\
"compopt declare dirs disown enable fc help history let local logout mapfile "\
"popd pushd readarray shopt source typeset unalias no_such_cmd"
}

sh_tester_bash_check_cmds()
{
  p= s= act=sh_is_shell_sbi foreach_do $bash_sh_sbi_cmds &&
      p= s= act=sh_is_shell_bi foreach_do $bash_sh_bi_cmds
}

sh_tester_bash_sh_check_cmds()
{
  p= s= act=sh_is_shell_bi foreach_do $bash_sh_bi_cmds
}

sh_tester_heirloom_sh_check_cmds()
{
  p= s= act=sh_is_shell_bi foreach_do $heirloom_sh_bi_cmds &&
    p= s= act=sh_is_shell_bin foreach_do $heirloom_sh_bin_cmds &&
      p= s= act=sh_is_shell_na foreach_do $heirloom_sh_na_cmds
}

sh_tester_check()
{
  test $SH_SH -eq 1 && {
    test $IS_BASH_SH -eq 1 && {
      sh_tester_bash_sh_check_cmds
      return $?
    }
    test $IS_HEIR_SH -eq 1 && {
      sh_tester_heirloom_sh_check_cmds
      return $?
    }
  } || {
    test $BASH_SH -eq 1 && {
      sh_tester_bash_check_cmds
      return $?
    }
  }
}

sh_tester()
{ true
}
