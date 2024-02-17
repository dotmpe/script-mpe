class_Bash_Cache__load ()
{
  uc_class_declare Bash/Cache --rel-types Statusdir
}

class_Bash_Cache_ () # ~ :Class (super,self,id,call) ~ <Call-args...>
{
  case "${call:?}" in

    ( : )
      ;;

      * ) return ${_E_next:?}

  esac && return ${_E_done:?}
}
