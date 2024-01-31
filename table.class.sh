
class_Table__load ()
{
  #Class__libs[Table]=
  Class__static_type[Table]=Table:Class
}

class_Table_ () # (super,self,id,call) ~ <Args>
{
  case "${call:?}" in

      * ) return ${_E_next:?}

  esac && return ${_E_done:?}
}


class_Table_Names__load ()
{
  #Class__libs[Table_Names]=
  Class__static_type[Table_Names]=Table_Names:Table
}

class_Table_Names_ ()
{
  case "${call:?}" in

      * ) return ${_E_next:?}

  esac && return ${_E_done:?}
}

#
