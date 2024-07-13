
test -n "${uc_lib_profile:-}" ||
  . "${UCONF:?}/etc/profile.d/bash_fun.sh" || ${stat:-exit} $?
uc_script_load user-script || ${stat:-exit} $?

# Use alsdefs set to cut down on small multiline boilerplate bits.
#user_script_alsdefs
! script_isrunning "vc.sh" ||
  ALIASES=1 user_script_shell_mode || ${stat:-exit} $?


### Vc:


## Main command handlers

vc_sh__libs=vc-htd,stdlog-uc
vc_sh_branches__grp=vc-sh
vc_sh_branches () # ~
{
  local actdef='l' n='branches'; sa_a1_act_lk_2
  case "$act" in
  ( l|all|list|list-all ) # ~ [<remotes>]
      test 0 -lt $# || set -- origin github dotmpe
      for vc_rt in "$@"
      do
        #vc_ rt $vc_rt &&
        vc_branches_git all
      done | remove_dupes
    ;;

  ( * ) sa_E_nsa
  esac
}


vc_sh_tracked_files__grp=vc-sh
#vc_sh_als__tracked=tracked-files
vc_sh_tracked_files ()
{
  local scm= scmdir=
  vc_getscm || return $?
  vc_tracked "$@"
}

# List unversioned files (including temp, cleanable and any excluded)
vc_sh_untracked__grp=vc-sh
vc_sh_untracked_files__grp=vc-sh
#vc_sh_als__untracked=untracked-files
#vc_sh_als__ufx=untracked-files
#vc_sh_als__excludes=untracked-files
vc_sh_untracked () { vc_sh_untracked_files "$@"; }
vc_sh_untracked_files()
{
  local scm= scmdir=
  vc_getscm || return $?
  vc_untracked "$@"
}

# List untracked paths. Unversioned files excluding ignored/excluded
vc_sh_unversioned_files__grp=vc-sh
#vc_sh_als__unversioned=unversioned-files
#vc_sh_als__uf=unversioned-files
vc_sh_unversioned_files()
{
  test -z "$*" || error "unexpected arguments" 1

  local scm= scmdir=
  vc_getscm || return $?
  vc_unversioned "$@"
}

# List (untracked) cleanable files
vc_sh_unversioned_cleanable_files__grp=vc-sh
#vc_sh_als__ufc=unversioned-cleanable-files
vc_sh_unversioned_cleanable_files()
{
  note "Listing unversioned cleanable paths"
  test -d .git || return
  test -d .git/info || mkdir .git/info
  vc__cleanables_regex > .git/info/exclude-clean.regex || return $?
  vc__untracked_files | grep -f .git/info/exclude-clean.regex || {
    warn "No cleanable files"
    return 1
  }
}

vc_sh_unversioned_temporary_files__grp=vc-sh
vc_sh_uft() { vc_sh_unversioned_temporary_files ; }
vc_sh_unversioned_temporary_files ()
{
  note "Listing unversioned temporary paths"
  test -d .git || return
  test -d .git/info || mkdir .git/info
  vc__temp_patterns_regex > .git/info/exclude-temp.regex || return $?
  vc__untracked_files | grep -f .git/info/exclude-temp.regex || {
    warn "No temporary files"
    return 1
  }
}

vc_sh_unversioned_uncleanable_files__grp=vc-sh
vc_sh_ufu() { vc_sh_unversioned_uncleanable_files ; }
vc_sh_unversioned_uncleanable_files()
{
  note "Listing unversioned, uncleanable paths"
  test -d .git || return
  test -d .git/info || mkdir .git/info
  {
    vc__cleanables_regex
    vc__temp_patterns_regex
  } > .git/info/exclude-clean-or-temp.regex

  vc__untracked_files | grep -v -f .git/info/exclude-clean-or-temp.regex || {
    warn "No uncleanable files"
    return 1
  }
}
#vc_flags__ufu=f
#vc_flags__unversioned_uncleanable_files=f

vc_sh_modified() { vc_sh_modified_files ; }
vc_sh_modified_files()
{
  test -z "$*" || error "unexpected arguments" 1

  local scm= scmdir=
  vc_getscm || return $?
  vc_modified
}

vc_sh_staged() { vc_sh_staged_files ; }
vc_sh_staged_files()
{
  test -z "$*" || error "unexpected arguments" 1

  local scm= scmdir=
  vc_getscm || return $?
  vc_staged
}



## User-script parts

vc_sh_maincmds="names var-names"
vc_sh_shortdescr='Split and assemble file names and strings from patterns'

vc_sh_aliasargv ()
{
  test -n "${1:-}" || return
  case "${1//_/-}" in

  ( "-?"|-h|h|help ) shift; set -- user_script_help "$@" ;;
  esac
}

vc_sh_loadenv () # ~ <Cmd-argv...>
{
  #user_script_loadenv || return
  : "${CWD:=$PWD}"
  : "${_E_not_found:=127}"
  : "${_E_next:=196}"
  user_script_baseless=true \
  script_part=${1#vc_} user_script_load groups || {
      # E:next means no libs found for given group(s).
      test ${_E_next:?} -eq $? || return $_
    }
  #lib_load "${base}" &&
  #lib_init "${base}" || return
  lk="$UC_LOG_BASE"
  user_script_announce "$@"
}

# Main entry (see user-script.sh for boilerplate)

! script_isrunning "vc.sh" || {
  export UC_LOG_BASE="${SCRIPTNAME}[$$]"
  user_script_load || exit $?
  script_defcmd=check
  user_script_defarg=defarg\ aliasargv
  eval "set -- $(user_script_defarg "$@")"
  script_run "$@"
}
