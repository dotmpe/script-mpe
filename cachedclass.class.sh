# XXX: cached data is not prefixed, ie its the same as actual data.
# prefixing could narrow data set for find-cache which currently is more like
# find-instance

class_CachedClass__load ()
{
  : "${CACHE_DIR:=${METADIR:?}/cache}"
  Class__static_type[CachedClass]=CachedClass:Class
  #class_static=CachedClass call=--fields class_Class_ group
  declare -gA CachedClass__cache{group,status}
}

class_CachedClass_ ()
{
  case "${call:?}" in
  ( .__init__ )
      $super$call "${@:?}" &&
      local -n group="CachedClass__cachegroup[$id]" &&
      if_ok "${group:=$(lower=true str_uc_id "${SELF_NAME:?}")}"
    ;;

  ( .commit-cache ) # ~ ~ [<Group>]
        [[ ${1-} ]] && {
          local group=${1:?}
        } || {
          local -n group="CachedClass__cachegroup[\"$id\"]"
        }
        local sh_cache=${CACHE_DIR:?}/${group:?}.sh
        {
          echo "[[ ! \${Class__instance[\"$id\"]+set} ]] || { "
          echo "  \$LOG error '' \"Cache incompatible or already loaded\" \"E3:$sh_cache\" 3 || return"
          echo "}"
          $self.class-dump
        } >| "${sh_cache:?}"
      ;;

  ( .class-dump )
      $super.class-dump &&
      class_akdump ${CLASS_NAME:?} "" cachegroup
    ;;


  ( --find-cache ) # ~ ~ <Key>
        : about "Retrieve instance from cache (cache data must be loaded)"
        : param "<Key>"
        : extended "Key corrsesponds to exact constructor params (excluding"
        : extended "type). Subclass can override method to customize. "
        stderr echo looking for cache key "'${1:?}'"
        stderr declare -p Class__instance
        class.Class --find-instance "${SELF_NAME:?} ${1:?}"
      ;;

  ( --get-from-cache ) # ~ ~ <Key> <Var> [<Group=SELF-NAME>]
      local group=${3-}
      : "${group:=$(str_uc_id "${SELF_NAME:?}")}"
      local -n status="CachedClass__cachestatus[\"$group\"]"
      [[ ${status-} ]] || {
        stderr echo loading cache group "'${group:?}'"
        class.CachedClass --load-cache "$group"
        #  sys_astat -eq 200
        status=$?
        #[[ $status -eq 0 ]] || return $status
        stderr echo new cache status "'${status:?}'"
      }
      [[ $status -eq 0 ]] || return
      local oid
      oid=$(class.CachedClass --find-cache "${1:?}") ||
        sys_astat -eq 200 || return
      [[ ${oid-} ]] || return
      stderr echo found oid=$oid
      local -n __obj=${2:?}
      __obj=$(class.Class --ref ${oid:?}) ||
        sys_astat -eq 200 || return
      stderr echo __obj:$2=$__obj
    ;;

  ( --load-cache ) # ~ ~ [<Group>]
      local group=${1-}
      : "${group:=$(str_uc_id "${SELF_NAME:?}")}"
      stderr echo source "${CACHE_DIR:?}/${group:?}.sh"
      . "${CACHE_DIR:?}/${group:?}.sh"
    ;;

  ( * ) return ${_E_next:?}
  esac && return ${_E_done:?}
}
