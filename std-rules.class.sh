class_Std_Rules__load ()
{
  uc_class_declare Std/Rules User/Conf --libs stattab-class \
    --rel-types StatTab --uc-config uconf:rules.tab user/rules/new.tab
}

class_Std_Rules_ () # ~ :User/Conf (super,self,id,call) ~ <Call-args...>
{
  case "${call:?}" in

    ( :run )
        test $# -gt 0 || set -- "${UCONF:?}/user/rules/new.tab"
        class_init StatTab{,Entry} &&
        class_new rules StatTab "$1" &&
        $rules.__cache__
        return

        $rules.__items__ &&

        # Debug
        for cid in "${!StatTab__entry[@]}"
        do
          eid=${cid#*:}
          echo "Entry $eid"
          for f in {b,c,u}time id idrefs meta meta_keys short refs status tags
          do
            : "StatTabEntry__${f}[$eid]"
            echo "  $f: ${!_-(unset)}"
          done
        done
        #stderr script_debug_arrs StatTab__entry
      ;;

      * ) return ${_E_next:?}

  esac && return ${_E_done:?}
}
