class_Std_Rules__load ()
{
  : about "TODO: Static 'run' handler loads @User/Conf/rules and goes over each key"
  uc_class_declare Std/Rules User/Conf --libs stattab-class \
    --uc-config rules StatTab ${UCONF:?}/user/rules/new.tab &&
    #uconf:rules.tab
    #--rel-types StatTab
  true
}

class_Std_Rules_ () # ~ :User/Conf (super,self,id,call) ~ <Call-args...>
{
  case "${call:?}" in

    ( :current ) # TODO: show/list files, where runner is/was at, summarize
      ;;

    ( :run ) # ~ ~ [<Tab>]
        local ruletab
        ruletab=${1:-$($self.get-config rules -)} &&
        [[ -e "$ruletab" ]] || return
        $LOG notice "$lk" "Starting rules" "$ruletab"

        class_init StatTab{,Entry} &&
        class_new rules StatTab "$ruletab" &&

        #$rules.__items__ &&
        #$rules.__cache__ &&
        #stderr script_debug_arrs StatTab__entry &&

        # loop over entries by reference to array key
        #declare -n items=$($self.rules@keys) &&

        # alt. loop by reading keys from call output
        local rule_id rule &&
        declare -a items &&
        sys_arr items $rules.keys &&
        for rule_id in "${items[@]}"
        do
          $rules.fetch rule "$rule_id" &&
          $rule.toString
        done

        return

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
      ;;

      * ) return ${_E_next:?}

  esac && return ${_E_done:?}
}
