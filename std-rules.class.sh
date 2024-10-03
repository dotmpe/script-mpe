class_Std_Rules__load ()
{
  : about "TODO: Static 'run' handler loads @User/Conf/rules and goes over each key"
  uc_class_declare Std/Rules User/Conf --libs stattab-class \
    --fields stattab &&
    #--uc-config rules StatTab ${UCONF:?}/user/rules/new.tab &&
    #uconf:rules.tab
    #--rel-types StatTab
  true
}

class_Std_Rules_ () # ~ :User/Conf (super,self,id,call) ~ <Call-args...>
{
  case "${call:?}" in

  #( .__init__ )
  #    ${super:?}$call "$@"
  #  ;;

  ( .load-file ) # ~ ~ [<Tab>]
      local ruletab
      ruletab=${1:-$($self.get-config rules -)} &&
      [[ -e "$ruletab" ]] || return

      class_init StatTab{,Entry} &&
      local -n rules="Std_Rules__tab[\"$OBJ_ID\"]" &&
      class_new rules StatTab "$ruletab" &&

      local -n filestat &&
      $rules.filestat filestat &&
      true # $filestat
    ;;


  ( :current ) # TODO: show/list files, where runner is/was at, summarize
    ;;

  ( :run ) # ~ ~ [<Tab>]
      TODO "run this, run that"
    ;;

  ( :run-all ) # ~ ~ [<Tab>]
      local -n rules="Std_Rules__tab[\"$OBJ_ID\"]" &&
      $LOG notice "$lk" "Starting rules" "$rules" &&

      #$rules.__cache__

      # TODO: iterator for items
      $rules.load &&

      local rule IFS=$'\n' oldIFS=$IFS &&
      for rule in $(IFS=$oldIFS; $rules.__items__)
      do
        stderr declare -p rule
        IFS=$oldIFS
      #  #$rules.fetch-var rule "$rule_id" &&
        stderr echo $rule.toString
        $rule.toString
      done
      IFS=$oldIFS


      # TODO: track data as Bash dump files .Speedup .Cache
      #$rules.__cache__ &&
      #stderr script_debug_arrs StatTab__entry &&

      # loop over entries by reference to array key
      #declare -n items=$($self.rules@keys) &&

      # alt. loop by reading keys from call output
      #local rule_id rule &&
      #declare -a items &&
      #sys_execmap items $rules.ids &&

      # Output rules
      #for rule_id in "${items[@]}"
      #do
      #  $rules.fetch-var rule "$rule_id" &&
      #  $rule.toString
      #done

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
