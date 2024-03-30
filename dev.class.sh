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
        # TODO: look at some package scripts or 'current' if provided
        # TODO: summarize SCM, see new vc-new.lib
        #vc_getscm && {
        #  vc_unversioned || return $?
        #  vc_modified || return $?
        #}
        test ! -d "$package_log" || {
          htd_log_current || return $?
        }
        TODO "$self$call $*"
      ;;

      * ) return ${_E_next:?}

  esac && return ${_E_done:?}
}
