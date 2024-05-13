class_OS_FileStat__load ()
{
  Class__static_type[OS/FileStat]=OS/FileStat:Class
  class_static=OS/FileStat call=--fields \
    class_Class_ {inode,os_{size,blocks,type},{a,m,c}time,perm,{u,g}id} ||
    class_loop_done
}

class_OS_FileStat_ ()
{
  case "${call:?}" in
    ( .__init__ )
        $super$call "${1:?}" &&
        $self.read-local-stat "${2:?}"
      ;;

    ( .read-local-stat )
        eval "local -n $($self.attr-refs \
          inode os_{size,blocks,type} {a,m,c}time perm {u,g}id)"
        if_ok "$(stat --printf '%i\t%s\t%b\t%F\t%X\t%Y\t%Z\t%a\t%u\t%g' "${1:?}")" &&
        <<< "$_" IFS=$'\t' read -r inode os_{size,blocks,type} {a,m,c}time perm {u,g}id
      ;;

    ( .toString )
        eval "local -n $($self.attr-refs \
          inode os_{size,blocks,type} {a,m,c}time perm {u,g}id)"
        local var
        for var in inode os_{size,blocks,type} {a,m,c}time perm {u,g}id
        do
          printf '%s="%s" ' "$var" "${!var}"
        done
      ;;

    ( * ) return ${_E_next:?}
  esac && return ${_E_done:?}
}
