namespacetab_reader_lib__load()
{
  : "${NSTAB_SH:=cache/ns-main.sh}"
  : "${NSTAB:=index/ns.tab}"
}

namespacetab_reader_lib__init ()
{
  true
  #declare -gA ${USER_NS_:?}{alias,exec,group,resource,sub,universal,user}
}

namespacetab_reader_parse ()
{
  id=${1:?} flags=${2:?} value=${3:-} ctags=() refs=() trefs=()
  shift 3
  test "${value:0:2}" != "--" || value=
  <<< "$*" sys_arr ctags todotxt_field_context_tags ||
    ctags=( Namespace )
  [[ "$id" =~ ^[A-Za-z_-][A-Za-z0-9_-]+$ ]] && root=true
  label=$(todotxt_fielda_words "$*")
  case "$flags" in
    ( -e )
        type=exec
        ctags+=( NS/Program ) ;;
    ( -g ) # Group (set of contexts)
        type=group
        value=$(printf -- '@%s' "${ctags[@]}")
        ctags+=( NS/Group )
      ;;
    ( -r )
        type=resource
        <<< "$*" sys_arr refs todotxt_field_chevron_refs &&
        value=${refs[0]:?} &&
        ctags+=( NS/Resource ) ;;
    ( -p ) # Path (sub) NS
        type=sub
        value=$value:$id:
      ;;
    ( -s ) # Custom user NS
        type=pattern
        #value=$value:$id:
      ;;
    ( - | -a ) # User alias
        type=alias
        while test 0 -lt $# -a "${1-}" != "--"
        do
          value="${value:+$value }$1"
          shift
        done
        shift
        # TODO: resolve relative
        test "${value:0:2}" = ".." && {
          value=todo:relref:$value
        }
        ctags+=( NS/Alias )
      ;;
    ( -u )
        type=universal
        <<< "$*" sys_arr trefs todotxt_field_square_refs &&
        title=$(<<< "$*" todotxt_field_single_rev9) &&
        #printf -v label '`%s`' "$title"
        value=${trefs[0]:-(fixme:noref)} &&
        ctags+=( NS/Cite ) ;;
    ( -- ) # tablines not ready for ns inclusion...
        return
      ;;
      * ) $LOG error : "Unknown flags" "$flags" 1
  esac || return
  ! "${root-false}" || ctags+=( Root )
  declare var="${USER_NS_:?}${type:?}"
  declare -g "${var}[$id]=$value"
  #"${root-false}" && {
  #  $self.attr id Namespace "$id" &&
  #  $self.attr type Namespace $type &&
  #  $self.attr value Namespace "$value" || return
  #}
}

#
