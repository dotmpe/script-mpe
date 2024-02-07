namespacestab_class__load()
{
  true
}


class_Namespace__load ()
{
  Class__static_type[Namespace]=Namespace:Class
  Class__libs[Namespace]=todotxt-fields,namespacetab-reader
  #declare -gA Namespace__{line_number,id,type,value}
  declare -gA Namespace__line_number
}

class_Namespace_ () # ~ :Class (super,self,id,call) ~ <Call-args...>
# .__init__ <Concrete-type> <Line-nr> <Line-entry>
# .exists
# .init
# .parse <Entry>
{
  case "${call:?}" in

    ( .__init__ )
        declare ct=${1:?} lnr=${2:?}
        shift 2
        $super.__init__ "$ct" || class_loop_done || return
        Namespace__line_number[$id]=$lnr
        $self.parse $* &&
        $self.exists || $self.init
      ;;

    ( .exists )

      ;;

    ( .init )

      ;;

    ( .parse )
        declare id flags value type root label title value ctags refs trefs
        namespacetab_reader_parse "$@" || return
        : "${label:+: $label.}"
        : "$_${title:+ \`$title\`}"
        : "$_$(test 0 -eq ${#ctags[@]} || printf ' @%s' "${ctags[@]}")"
        : "$_$(test 0 -eq ${#trefs[@]} || printf ' [%s]' "${trefs[@]}")"
        : "$_$(test 0 -eq ${#refs[@]} || printf ' <%s>' "${refs[@]}")"
        echo "$id $value$_" # raw:$(printf '"%s" ' "${*:2}")"
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

    ( .__init__ )
        $super.__init__ "${@:1:2}" "${3:-Namespace}" "${@:4}" ;;

    ( .fetch ) # ~ ~ <Var> <Id>
        # quiet: $LOG notice "$lk" "Retrieving" "${1#local:}=$2"
        # Get entry and source linenr with Id
        declare {grep,tab}line srcln
        grepline="$(tf_fs=' ' grep_f="-m1 -n" $self.grep-tab "${2:?}")" &&
        srcln=${grepline%%:*} &&
        tabline=${grepline:$(( ${#srcln} + 1 ))} &&

        # XXX: old alt to get entry
        #if_ok "$($self.key-by-index 1 "${2:?}")" &&

        # Parse with Namespace class
        class_new "$1" Namespace "$srcln" "$tabline"
      ;;

    ( .ids ) # ~ ~ <...>
        $self.keys-by-index 1
      ;;

      * ) return ${_E_next:?}

  esac && return ${_E_done:?}
}

#
