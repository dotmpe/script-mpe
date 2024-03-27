class_Std__load ()
{
  : about "Std class context TODO: cleanup ctx-std.lib"
  uc_class_declare Std XContext
}

class_Std_ ()
{
  case "${call:?}" in
    ( .__init__ ) $super$call "$@" ;;

    ( :current )
        # This doesnt do anything yet, see Dev
      ;;

      * ) return ${_E_next:?}

  esac && return ${_E_done:?}
}
