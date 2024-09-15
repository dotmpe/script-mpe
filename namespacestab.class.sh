namespace_class__load ()
{
  true # XXX: might want to require or register env
  #class_init UConf &&
  #class.UConf :install \
  #  alias class_Namespace_vars 'declare -n \
  #        id=Namespace__id[$OBJ_ID] \
  #        type=Namespace__type[$OBJ_ID] \
  #        value=Namespace__value[$OBJ_ID]'
}

class_Namespace__load ()
{
  Class__static_type[Namespace]=Namespace:Class
  Class__libs[Namespace]=todotxt-fields,namespacetab-reader
  declare -gA Namespace__{tab_obj,line_number,id,type,value} &&
  sh_als class_Namespace_vars
}

class_Namespace_ () # ~ :Class (super,self,id,call) ~ <Call-args...>
# .__init__ <Concrete-type> <Line-nr> <Line-entry>
# .exists
# .init
# .parse <Entry>
{
  case "${call:?}" in

    ( .__init__ )
        declare ct=${1:?} tabobj=${2:?} lnr=${3:?}
        shift 3
        $super.__init__ "$ct" || class_loop_done || return
        Namespace__tab_obj[$id]=${tabobj##* }
        Namespace__line_number[$id]=$lnr
        $self.parse $* &&
        $self.exists || $self.init
      ;;

    ( .entry )
        class_Namespace_vars
        echo "$id: $value ($type)"
      ;;

    ( .exists )
      ;;

    ( .init )

      ;;

    ( .parse )
        class_Namespace_vars

        declare flags root label title
        declare -a ctags refs trefs

        namespacetab_reader_parse "$@" || return

        # XXX: cleanup debug:
        #: "${label:+: $label.}"
        #: "$_${title:+ \`$title\`}"
        #: "$_$(test 0 -eq ${#ctags[@]} || printf ' @%s' "${ctags[@]}")"
        #: "$_$(test 0 -eq ${#trefs[@]} || printf ' [%s]' "${trefs[@]}")"
        #: "$_$(test 0 -eq ${#refs[@]} || printf ' <%s>' "${refs[@]}")"
        #echo "$id $value$_" # raw:$(printf '"%s" ' "${*:2}")"
      ;;

      * ) return ${_E_next:?}

  esac && return ${_E_done:?}
}


class_NamespacesTab__load ()
{
  Class__static_type[NamespacesTab]=NamespacesTab:TabFile
  Class__rel_types[NamespacesTab]=Namespace
}

class_NamespacesTab_ () # ~ :TabFile (super,self,id,call) ~ <Call-args...>
{
  case "${call:?}" in

    ( .__init__ ) # ~ <Concrete-type> <Tab-file> <Entry-type> <...>
        $super.__init__ "${@:1:2}" "${3:-Namespace}" "${@:4}" ;;

    ( .fetch-var ) # ~ ~ <Var> <Id> [...]
        ! uc_debug || $LOG debug "$lk" "Retrieving" "${1#local:}=$2"
        # Get entry and source linenr with Id
        declare {grep,tab}line srcln
        grepline="$(tf_fs=' ' grep_f="-m1 -n" $self.grep-tab "${2:?}")" &&
        srcln=${grepline%%:*} &&
        tabline=${grepline:$(( ${#srcln} + 1 ))} &&

        # XXX: old alt to get entry
        #if_ok "$($self.by-key-at-index 1 "${2:?}")" &&

        # Parse with Namespace class
        class_new "$1" Namespace "$self" "$srcln" "$tabline"
      ;;

    ( .ids ) # ~ [...]
        $self.col-by-index 1
      ;;

      * ) return ${_E_next:?}

  esac && return ${_E_done:?}
}

#
