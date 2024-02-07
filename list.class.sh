
class_List__load ()
{
  Class__libs[List]=list
  Class__static_type[List]=List:XContext
}

class_List_ () # (super,self,id,call) ~ <Args>
{
  case "${call:?}" in

    #( .__init__ )
        #test -f "${2:?}"
        #FileReader__file[$id]=$_ &&
        #$super.__init__ "${@:1:2}" "${@:3}" ;;
    #  ;;

      * ) return ${_E_next:?}

  esac && return ${_E_done:?}
}


class_List_Name__load ()
{
  #Class__libs[List_Name]=
  Class__static_type[List_Name]=List_Name:List
}

class_List_Name_ ()
{
  case "${call:?}" in

    ( :attributes-definitions )
        $LOG info "$lk" "Attributes definitions"
        ${ctx}_stddef
      ;;

    ( :attributes-paths )
        test $# -gt 0 || set -- local global
        $LOG info "$lk" "Attributes paths" "$*"
        # XXX: context ref
        user_settings_paths "$@"
      ;;

    ( :attributes-pathspecs )
        test $# -gt 0 || set -- local global
        $LOG info "$lk" "Attributes pathspecs" "$*"
        ${ctx}_pathspecs "$@"
      ;;

    ( :attributes-summary )
        ctx=attributes
        $self:attributes-definitions
        $self:attributes-pathspecs
        $self:attributes-paths local
        $self:attributes-paths global
      ;;

    ( :names )
        ctx=attributes
        case "${1:-}" in
          ( all ) shift; local glk gk
              glk="$(${ctx}_globlistkey)[*]" &&
              gk="$(${ctx}_groupkey)[*]" || return
              $LOG info "$lk" "Listing group- and list-names" "groups=$gk:globlists=$glk"
              echo ${!gk} ${!glk}
            ;;
          ( cache ) shift;
              ${ctx}_cachefile ;;
          ( groups ) shift; local gk
              gk="$(${ctx}_groupkey)[*]" || return
              $LOG info "$lk" "Listing groupnames" "groups=$gk"
              echo ${!gk} ;;
          ( globlists ) shift
              ${ctx}_paths "$@"
            ;;
          ( specs ) shift; local glk
              glk="$(${ctx}_globlistkey)[*]" || return
              $LOG info "$lk" "Listing listnames" "globlists=$glk"
              echo ${!glk} ;;
          ( * ) return 67 ;;
        esac
      ;;

    ( :files-find )
          find_arg="-o -type f -a -print" ${xctx}_find_files "$@"
      ;;

    ( :files-find-expr )
          ${xctx}_find_expr "$@"
      ;;

    ( :files-groups )
      ;;

    ( :files-globlist )
          ${xctx}_paths "$@" | filter_lines test -f
      ;;

    ( :files-relative )
          TODO "files relative"
      ;;

      * ) return ${_E_next:?}

  esac && return ${_E_done:?}
}


class_List_Glob__load ()
{
  #Class__libs[List_Glob]=
  Class__static_type[List_Glob]=List_Glob:List
}

class_List_Glob_ ()
{
  case "${call:?}" in

    ( :globs-list )
        ctx=attributes

        case "${1:-list}" in
          ( l|list ) shift;
              ${ctx}_raw "$@" | remove_dupes_nix ;;
          ( r|raw ) shift;
              ${ctx}_raw "$@" ;;

          ( * ) return ${_E_nsk?}
        esac
        return

        test $# -eq 0 || set -- $(printf '%s\n' "$@" | sort -u)
        test $# -gt 0 || set -- $IGNORE_GROUPS
        {
          ${choice_nocache:-false} && {
            ignores_raw "$@" | remove_dupes_nix
            return
          } || {
            ignores_cache "$@" ||
              $LOG error : "Updating cache" "E$?:$*" $? || return
            if_ok "$(ignores_cache_file "$@")" &&
            test -f "$_" &&
            cat "$_" ||
              $LOG error : "Reading from cache file" "E$?:$*:$_" $? || return
            return $?
          }
        } | { ! ${choice_raw:-false} && {
            grep -Ev '^\s*(#.*|\s*)$' || return
          } || {
            cat - || return
          }
        }
        # XXX: cleanup old list-oldmk setup
        #lst_init_ignores "$ext" local global
        #echo read_nix_style_file $IGNORE_GLOBFILE$ext
      ;;

      * ) return ${_E_next:?}

  esac && return ${_E_done:?}
}

#
