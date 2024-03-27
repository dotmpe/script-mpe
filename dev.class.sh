class_Dev__load ()
{
  : about "Dev class context"
  uc_class_declare Dev XContext
}

class_Dev_ ()
{
  case "${call:?}" in
    ( .__init__ ) $super$call "$@" ;;

    ( :current )
        $LOG warn "$lk" "Looking at current Dev context..."
        if_ok "$(compgen -A variable | grep scm)" &&
        echo "$_" &&
        stderr declare -p scm{,dir} package_{pd_meta_checks,log} $_
        #vc_getscm && {
        #  vc_unversioned || return $?
        #  vc_modified || return $?
        #}
        test ! -d "$package_log" || {
          htd_log_current || return $?
        }
      ;;

      * ) return ${_E_next:?}

  esac && return ${_E_done:?}
}
