#!/usr/bin/env bash


context__grp=user-script
context_sh__grp=context
context_sh__hooks=context_sh_init
context_sh__libs=os-htd,context

# all-tags
#   List tag names
context_sh_entries () # (y) ~ <action:-list> <...>
# all-tags
#   List tag names
{
  local act=${1-}
  act="${act:+$(str_globstripcl "$act" "-")}" || return
  : "${act:=list}"
  test $# -eq 0 || shift
  local lk=${lk:-:context}:entries:-$act
  case "$act" in

  ( tags|all-tags ) # ~ # List tag names
      #about "List tag names"
      context_tags_list
    ;;
  ( c|count ) # ~ # Count context.tab lines
      context_tab_cache && ctx_grep_f=Evc context_tab
    ;;
  ( check-tags ) # ~ # Look for (sub)tag and warn about case
      context_tab_cache && context_check "$@"
    ;;
  ( d|data ) context_tab_cache &&
      read_nix_user_data "${CTX_TAB_CACHE:?}" ;;
  ( e|exists|tags-exist )
      context --exists "$@"
    ;;
  ( F|fr|fetch-raw )
        context_tag_entry "${1:?}"
      ;;
  ( f|fetch )
        if_ok "$(context_tag_entry "${1:?}")" &&
        context_parse "$_"
      ;;
  ( find-by-id-part | grep-id )
        [[ $# -eq 1 ]] || return ${_E_MA:?}
        {
          : "${ctx_grep_f:-Ev}"
          echo "# $ grep_f=-i ctx_grep_f=$_ generator=context_tab stattab_grep ${@@Q}"
          grep_f=-i \
          generator=context_tab stattab_grep "${1:?}" -idp "${CTX_TAB_CACHE:?}"
        } |
          IF_LANG=todo.txt $PAGER
      ;;
  ( find-id | fuzzy-id | list-id )
        context_sh_entries find-by-id-part ".*${1:?}.*"
      ;;
  ( fl|files )
        # Get file references from other table
        context_sh_files tab | sed 's/^/#id /'
      ;;
  ( G|anycs|grep ) # ~ ~ <Grep> <Mode> # Like g|any|grepi but case sensitive
        test $# -gt 1 || set -- "${1:?}" -any
        test $# -gt 2 || set -- "${1:?}" "${2:?}" "${CTX_TAB_CACHE:?}"
        {
          : "${ctx_grep_f:-Ev}"
          echo "# $ ctx_grep_f=$_ generator=context_tab stattab_grep ${@@Q}"
          generator=context_tab stattab_grep "$@"
        } |
          IF_LANG=todo.txt $PAGER
      ;;
  ( g|any|grepi ) # ~ ~ <Grep> <Mode> # Normal mode -any greps entire line,
      # Set -alias (or -id) to match only the entry Id part.
      # Since tab only includes entries, not all modes make sense.
        test $# -gt 1 || set -- "${1:?}" -any
        test $# -gt 2 || set -- "${1:?}" "${2:?}" "${CTX_TAB_CACHE:?}"
        {
          : "${ctx_grep_f:-Ev}"
          echo "# $ grep_f=-i ctx_grep_f=$_ generator=context_tab stattab_grep ${@@Q}"
          grep_f=-i generator=context_tab stattab_grep "$@"
        } |
          IF_LANG=todo.txt $PAGER
      ;;
  ( l|list )
        context_tab
      ;;
  ( r|raw ) context_tab_cache &&
      read_nix_data "${CTX_TAB_CACHE:?}" ;;
  ( rel|related-tags )
        user_script_initlibs stattab-reader &&
        context_tab_cache &&
        contexttab_related_tags "$@" &&
        echo "Related tags: $tag_rel"
      ;;
  ( tagged )
        user_script_initlibs stattab-reader &&
        stb_fp=${CTX_TAB_CACHE:?} grep_f=-n generator=context_tab \
          stattab_grep "$1" -tagged
      ;;

  ( * ) $LOG error "$lk" "No such action" "-$act:$*" ${_E_nsa:-68}
  esac
}
context_sh_entries__grp=context-sh

context_sh_files () # (y) ~ <Switch:-list> <...>
{
  local act=${1-}
  act="${act:+$(str_globstripcl "$act" "-")}" || return
  : "${act:=list}"
  test $# -eq 0 || shift
  local lk=${lk:-:context}:files:-$act
  case "$act" in ( c|check|check-* ) ;; * ) context_sh_files --check; esac
  case "$act" in
  ( a|all )
      context_files
    ;;
  ( c|check )
      context_sh_files --check-global &&
      context_sh_files --check-local
    ;;
  # TODO: see status.sh, get faster more meaningful stat for (context) index
  ( check-global )
      local files
      : "$(context_files)" &&
      #mapfile -t files <<< "$_" &&
      #stderr script_debug_arr files
      <<< "$_" foreach2 os_isfile
    ;;
  ( check-local )
      # TODO: use statusdir or other to go over unique names
      test ! -e .meta/stat/index/context.list ||
          $LOG warn "$lk" "Should not have context.list" ;;
  ( c-a|count-all )
      wc -l <<< "$(context_files)"
    ;;
  ( e|enum )
      local cached=${CTX_CACHE:?}/context-file-includes.tab
      context_files_cached "$cached" &&
      cat "$cached"
    ;;
  ( E | edit )
      local -a files
      if_ok "$(context_files)" &&
      mapfile -t files <<< "$_" &&
      $EDITOR "${files[@]}"
    ;;

  ( f|find ) # XXX: get look path
      files_existing ".meta/stat/index/{context,ctx}{,-*}.list"
    ;;
  ( g|grep )
      local -a files
      if_ok "$(context_files)" &&
      mapfile -t files <<< "$_" &&
      grep "$@" "${files[@]}"
    ;;
  ( l|ls|list )
      context_sh_files -all && context_sh_files -find
    ;;

  ( p | preview )
      shopt -s expand_aliases &&
      . ${US_BIN:?}/tools/sh/parts/fzf.sh &&
      # Alias will not resolve yet unless we return to root first, so just
      # resolve the command by hand
      context_files | eval "IF_LANG=todo.txt $(sh_als_cmd fzf-preview)"
    ;;

  ( pp|preproc )
      preproc_includes_list "" "$CTX_TAB"
    ;;

  ( lr|list-raw )
      context_list_raw "$CTX_TAB"
    ;;

  ( sc|sed-script )
      #preproc_resolve_sedscript "" "$CTX_TAB"
      preproc_expand_1_sed_script "" "$CTX_TAB"
      echo "$sc"
    ;;
  ( tab|ids )
      local cached=${CTX_CACHE:?}/context-file-ids.tab
      context_files | os_up_to_date "$cached" || {
        context_files | while read -r context_tab
        do echo "$(context_file_attributes id) $context_tab"
        done >| "$cached" || return
      }
      cat "$cached"
    ;;

  ( * ) $LOG error "$lk" "No such action" "$act" ${_E_nsa:-68}
  esac
}
context_sh_files__grp=context-sh

context_sh_path ()
{
  local act=${1-}
  act="${act:+$(str_globstripcl "$act" "-")}" || return
  : "${act:=short}"
  test $# -eq 0 || shift
  local lk=${lk:-:context}:path:-$act
  case "$act" in
  ( s|short|list )
      out_fmt=list cwd_lookup_paths
      out_fmt=list sys_path
      #out_fmt=list cwd_lookup_path .
    ;;

  ( * ) $LOG error "$lk" "No such action" "$act" ${_E_nsa:-68} ;;
  esac
}
context_sh_path__grp=context-sh

context_sh_shell () # ~ <Switch:-user> ~ [-i] [-l] [-c "<Command...>"] [<Shell-args...>]
{
  local switch=${1-}
  switch="${switch:+${switch##-}}"
  test 0 -eq $# || shift
  local lk=${lk:-:context}:shell:-${switch:=user}
  #context_load ctx XContext
  create ctx XContext || return
  case "${switch:?}" in
  ( f | functions )
      compgen -A function
    ;;
  ( ic | lc | lic )
      $ctx+Shell --user-command
      TODO shell -${switch} "${1:?}" "${@:2}"
    ;;
  ( i | l | li )
      $ctx+Shell -${switch} "$@"
    ;;
  ( executable-scripts )
      scripts=$(user_script_list_shell_scripts)
      wc -l <<< "$scripts"
    ;;
  ( shell-libs )
      locate -be '*.lib.sh' | sort -r |
        awk -F / '!a[$NF]++ { print $0 }'
    ;;
  ( count-shell-libs )
      if_ok "$(locate -be '*.lib.sh' | sort -r |
        awk -F / '!a[$NF]++ { print $0 }')" &&
      wc -l <<< "$_"
    ;;
  ( count-shell-lib-lines )
      locate -be '*.lib.sh' |
              user_script_unique_names_count_script_lines
    ;;
  ( count-shell-script-lines )
      {
          user_script_list_shell_scripts
      } | user_script_filter_userdirs |
              user_script_unique_names_count_script_lines
    ;;
  ( s|short )
      if_ok "$(context_sh_shell user-scripts)" &&
      stderr echo "Shell scripts: $_"
      if_ok "$(context_sh_shell shell-libs)" &&
      stderr echo "Shell libs: $_"
    ;;
  ( user )
      $ctx+Shell --user-repl
    ;;
  ( user-scripts )
      #$ctx+UserScript --count-user

      lib_require ctx-userscript &&
      @UserScript .count

      #create us UserScripts &&
      #$us.count
      scripts=$(user_script_list_shell_scripts | user_script_filter_userdirs)
      wc -l <<< "$scripts"
    ;;
  ( * ) $LOG error "$lk" "No such switch" "$switch" ${_E_nsk:-67}
  esac
}
context_sh_shell__grp=context-sh
context_sh_shell__libs=user-script-htd,str-uc,context-uc

# TODO: show info about ctx/cache, and last computed status
context_sh_status () # ~
{
  local act=${1-}
  act="${act:+${act##-}}"
  : "${act:=short}"
  test $# -eq 0 || shift
  local lk=${lk:-:context}:status:-$act
  #context_load @Status || return
  case "$act" in
  ( i|info )
          stderr echo "Main file: ${CTX_TAB:-(unset)}"
          stderr echo "Main Cache file: ${CTX_TAB_CACHE:-(unset)}"
          stderr echo "File count: $(context_sh_files c-a)"
      ;;
  ( s|short )
          script_part=context-sh-files user_script_load groups &&
          context_sh_files check
          $LOG info "$lk" "Files check" E$? $? || return
          wc -l $(context_sh_files -a)

          local cached=${CTX_TAB_CACHE:?}
          local context_tab="${context_tab:-${CTX_TAB:?}}"

          echo ctx.tab: $context_tab
          echo cached=$cached
          wc -l "$cached"
      ;;

  ( * ) $LOG error "$lk" "No such action" "$act" ${_E_nsa:-68}
  esac
}
context_sh_status__grp=context-sh
context_sh_status__libs=str-uc,context-uc,class-uc

# XXX:
context_sh_tag ()
{
  local act=${1-}
  act="${act:+$(str_globstripcl "${act-}" "-")}" || return
  : "${act:=entry}"
  test $# -eq 0 || shift
  local lk=${lk:-:context}:tags:-$act
  case "$act" in
  ( entry )
        context_tag_entry "${1:?}"
      ;;

  ( * ) $LOG error "$lk" "No such action" "$act" ${_E_nsa:-68}
  esac
}
context_sh_tag__grp=context-sh

context_sh_tags () # ~ <Switch:-list> <...>
{
  local act=${1-}
  act="${act:+$(str_globstripcl "${act-}" "-")}" || return
  : "${act:=list}"
  test $# -eq 0 || shift
  local lk=${lk:-:context}:tags:-$act
  case "$act" in
  ( for )
      contexttab_related_tags "${1:-}" && echo $tag_rel
    ;;
  ( count|c )
      context_tags_list | count_lines ;;
  ( list )
      context_tags_list ;;

  ( * ) $LOG error "$lk" "No such action" "$act" ${_E_nsa:-68}
  esac
}
context_sh_tags__grp=context-sh

context_sh_user () # (y) ~ <Switch:-> ...
{
  local act=${1-}
  act="${act:+$(str_globstripcl "${act-}" "-")}" || return
  : "${act:=list}"
  test $# -eq 0 || shift
  local lk=${lk:-:context}:user:-$act
  case "$act" in
  ( debug )
      script_debug_genv -i script
      script_debug_genv -i context
      script_debug_genv -i base
      script_debug_genv -i dir
      script_debug_genv -i meta
      script_debug_genv -i '\(user\|usr\)'
      script_debug_genv -i 'tab'
      script_debug_genv -i '^xdg'
    ;;
  ( list ) locate -ibe 'user-*.class.sh' ;;
  ( basedir ) us_xctx_init && us_basedir_init ;;
  ( conf ) us_userconf_init && $user_conf.class-tree;;
  ( dir ) us_userdir_init && $user_dir.class-tree;;

  ( * ) $LOG error "$lk" "No such action" "$act" ${_E_nsa:-68}
  esac
}
context_sh_user__grp=context-sh


## User-script parts

#context_sh_name=foo
#context_sh_version=xxx
context_sh_maincmds="entries files help list path shell status short version"
context_sh_shortdescr='Provide context entities and relations based on tags'

# Not using shell aliases in this script because they are a pain. But I wonder
# if they could make below setup a bit nicer.

context_sh_aliasargv ()
{
  case "${1:?}" in
  ( entries|e ) set -- entries "${@:2}" ;;
  ( tags|t ) set -- tags "${@:2}" ;;
  ( list|l ) set -- entries -l "${@:2}" ;;
  ( short|s ) set -- status --short ;;
  ( files|f ) set -- files "${@:2}" ;;
  esac &&
  script_defenv[HT]=${HT:-${HTDIR:-${HTDOCS:-$HOME/htdocs}}}
}

context_sh_init ()
{
  user_script_initlibs stattab-class class-uc context &&
  class_init XContext
}

context_sh_loadenv ()
{
  shopt -s nullglob &&
  return ${_E_continue:-195}
}

context_sh_unload ()
{
  shopt -u nullglob
}


# Main entry (see user-script.sh for boilerplate)

us-env -r user-script || ${us_stat:-exit} $?

! script_isrunning "context.sh" || {
  script_base=context-sh,user-script-sh
  user_script_load default || exit $?

  # Default value used if argv is empty
  script_defcmd=short
  user_script_defarg=defarg\ aliasargv
  # Resolve aliased commands or set default
  if_ok "$(user_script_defarg "$@")" &&
  eval "set -- $_" &&
  script_run "$@"
}
