command_class__load ()
{
  : "${command_methods:=}"
}

class_Command__load ()
{
  Class__static_type[Command]=Command:Context
  #Class__rel_types[Command]=Context
}

class_Command_ () # (super,self,id,call) ~ <Args...>
{
  case "${call:?}" in

    #( .__init__ )
    #    $super.__init__ "$@"
    #  ;;

      * ) return ${_E_next:?}
  esac &&
    return ${_E_done:?}
}
