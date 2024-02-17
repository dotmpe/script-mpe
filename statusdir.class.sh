class_Statusdir__load ()
{
  uc_class_declare StatusDir --libs stattab-class,ck
}

class_Statusdir_ () # ~ :Class (super,self,id,call) ~ <Call-args...>
{
  case "${call:?}" in

    ( --index )
        Statusdir__index[${1:?}]=${*:2}
      ;;

    ( --key )
        declare -n key=${1:?} &&
        # XXX: read with ws? ie read all lines?
        read -r -a data &&
        key=$(ck_sha2 <<< "${data[*]}")
      ;;

      * ) return ${_E_next:?}

  esac && return ${_E_done:?}
}
