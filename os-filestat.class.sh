class_OS_FileStat__load ()
{
  Class__static_type[OS/FileStat]=OS/FileStat:CachedClass
  class_static=OS/FileStat call=--fields \
    class_Class_ {inode,os_{size,blocks,type},{a,m,c}time,perm,{u,g}id} ||
    class_loop_done
}

class_OS_FileStat_ ()
{
  case "${call:?}" in
  ( .__init__ )
      $super$call "${@:?}" &&
      $self.read-local-stat "${2:?}"
    ;;

  ( .class-dump )
      $super.class-dump &&
      class_akdump ${CLASS_NAME:?} "" \
        inode os_{size,blocks,type} {a,m,c}time perm {u,g}id
    ;;

  ( .refresh )
      local filepath
      $self:filepath &&
      [[ ${filepath:?} -ot "${CACHE_DIR:?}/${1:?}.sh" ]] || {
        stderr echo $SELF_NAME:.refresh cache update
        $filestat.read-local-stat &&
        dirty=true || return
      }
    ;;

  ( .read-local-stat )
      local filepath
      $self:filepath &&
      eval "local -n $($self.attr-refs \
        inode os_{size,blocks,type} {a,m,c}time perm {u,g}id)"
      if_ok "$(stat --printf '%i\t%s\t%b\t%F\t%X\t%Y\t%Z\t%a\t%u\t%g\n' "${filepath:?}")" &&
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


  ( :filepath )
      : "${Class__instance["$OBJ_ID"]}"
      : "${_#* }"
      : "${_% *}"
      filepath="${_:?}"
    ;;

  ( * ) return ${_E_next:?}
  esac && return ${_E_done:?}
}
