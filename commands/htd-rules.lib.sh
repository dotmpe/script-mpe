#!/bin/sh


htd_rules_lib__load()
{
  #2017-05-01
  test -n "${htd_rules-}" || htd_rules=$UCONF/user/rules/$hostname.tab
}

htd_man_1__rules='
  edit - Edit the HtD rules file.
  show - Resolve and show HtD rules with Id, Cwd and proper Ctx.
  table -
  status
    Show Id and last status for each rule.
  run [ Target-Grep [ Cmd-Grep ] ]
    Evalute all rules and update status and targets. Rule selection arguments
    like `each`.
  ids [ Target-Grep [ Cmd-Grep ] ]
    Resolve rules and list IDs generated from the command, working dir and context.
  foreach Targets-Grep Cmds-Grep [CMD=id]
      pre-proc and CMD
  each Line-Nr | Targets-Grep | [ "" Cmds-Grep ]
    Filter rules using given Grep patterns, or return one line
  id
  env-id
  parse-ctx
  eval-ctx
  pre-proc
    TODO: parse-ctx eval-ctx
  update | post-proc

Development documentation in HT:Dev/Shell/Rules.rst
TODO: proc rules, output log.
TODO: Transform log to new rule states...
'
htd_rules__help() { std_help rules; }
htd__rules()
{
  test -n "${htd_chatter-}" || htd_chatter=$verbosity
  test -n "${htd_rule_chatter-}" || htd_rule_chatter=3
  test -n "${1-}" || set -- table
  case "$1" in

    edit )                        htd__edit_rules || return  ;;
    table|tab|raw ) shift ;       raw=true htd__show_rules "$@" || return  ;;
    show ) shift ;                htd__show_rules "$@" || return  ;;
    status ) shift ;              htd__period_status_files "$@" || return ;;
    run ) shift ;                 htd__run_rules "$@" || return ;;
    ids ) shift ;                 htd__rules foreach "$1" "$2" id || return ;;
    foreach ) shift
        test -n "$*" || set -- 'local\>' "" id
        htd__rules each "$1" "$2" | while read vars
        do
          local package_id= ENV_NAME= htd_rule_id=
          line= row_nr= CMD= RT= TARGETS= CWD= CTX=
          eval "$vars"
          htd__rules pre-proc || continue
          htd__rules "$3" "$vars" ||
            error "Running '$3' for $row_nr: '$line' ($?)"
          continue
        done
      ;;
    each ) shift
        # TODO: use optparse instead test -z "$1" || local htd_rules=$1 ; shift
        fixed_table $htd_rules CMD RT TARGETS CTX | {

          # Filter prop-lines by line-nr or by column values
          case " $* " in
            " "[0-9]" "|" "[0-9]*[0-9]" " ) grep "row_nr=$1\>" - ;;
            * ) { test -n "${2-}" &&
                  grep '^.*\ CMD=\\".*'"$2"'.*\\"\ \ RT=.*$' - || cat -
              } | { test -n "${1-}" &&
                  grep '^.*\ TARGETS=\\".*'"$1"'.*\\"\ \ CTX=.*$' - || cat -
              } ;;
          esac
        }
      ;;
    id ) shift
        case " $* " in
          " "[0-9]" "|" "[0-9]*[0-9]" " )
              vars="$(eval echo "$(htd__rules each $1)")"
              line= row_nr= CMD= RT= TARGETS= CWD= CTX=
              set -- "$vars"
              eval export "$@"
              verbosity=$htd_chatter
              htd__rules parse-ctx "$*" || return
              local package_id= ENV_NAME= htd_rule_id=
              htd__rules eval-ctx "$vars" || return
            ;;
          *" CMD="* ) # from given vars
              line= row_nr= CMD= RT= TARGETS= CWD= CTX=
              vars="$@"
              verbosity=$htd_rule_chatter eval export "$vars"
              verbosity=$htd_chatter
            ;;
          * ) # Cmd Ret Targets Ctx
              line= row_nr= CMD="$1" RT="$2" TARGETS="$3" CWD="$4" CTX="$5"
              vars="CMD=\"$1\" RT=\"$2\" TARGETS=\"$3\" CWD=\"$4\" CTX=\"$5\""
            ;;
        esac
        test -z "$DEBUG" ||
          note "$row_nr: CMD='$CMD' RET='$RT' CWD='$CWD' CTX='$CTX'"
        htd__rules env-id || return
      ;;
    env-id ) shift
        test -n "$htd_rule_id" || { local sid=
          test -n "$package_id" && {
              mksid "$CWD $package_id $CMD"
            } || {
              test -n "$ENV_NAME" && {
                mksid "$CWD $ENV_NAME $CMD"
              } || {
                mksid "$CWD $CMD"
              }
            }
            htd_rule_id=$sid
          }
          echo $htd_rule_id
      ;;
    parse-ctx ) shift
        test -n "$CTX" || {
          ctx_var="$(echo "$vars" | sed 's/^.*CTX="\([^"]*\)".*$/\1/')"
          warn "Setting CWD to root, given empty '$ctx_var' env. "
          CTX=/
        }
        CWD=$(echo $CTX | cut -f1 -d' ')
        test -d "$CWD" && CTX=$(echo $CTX | cut -c$(( ${#CWD} + 1 ))- ) || CWD=
      ;;

    eval-ctx ) shift
        test -n "$CTX" -a -n "$CWD" -a \( \
          -n "$package_id" -o -n "$htd_rule_id" -o "$ENV_NAME" \
        \) || {
          # TODO: alternative profile locations, config/tools/env.sh,
          # .local/etc , ~/.conf
          test -e "$HOME/.local/etc/profile.sh" && CTX="$CTX . $HOME/.local/etc/profile.sh"
        }
        test -n "$CTX" && {
          verbosity=$htd_rule_chatter eval $CTX
          verbosity=$htd_chatter
        }
        test -n "$CWD" || {
          ctx_var="$(echo "$*" | sed 's/^.*CTX="\([^"]*\)".*$/\1/')' env"
          warn "Setting CWD to root, given '$ctx_var' ctx"
          CWD=/
        }
      ;;

    pre-proc ) shift
        htd__rules parse-ctx || {
          error "Parsing ctx at $row_nr: $ctx" && continue ; }
        htd__rules eval-ctx || {
          error "Evaluating ctx at $row_nr: $ctx" && continue ; }
        # Get Id for rule
        htd_rule_id=$(htd__rules env-id "$vars")
        test -n "$htd_rule_id" || {
          error "No ID for $row_nr: '$line'" && continue ; }
        return 0

        # TODO: to run rules, first get metadata for path, like max-age
        # In this case, metadata like ck-names might provide if matched with a
        # proper datatype chema

        htd_tasks_buffers $TARGET "$@" | while read buffer
        do test -e "$buffer" || continue; echo "$buffer"; done

        target_files= targets= max_age=
        #targets="$(prefix_expand $TARGETS "$@")"
        #are_newer_than "$targets" $max_age && continue
        #sets_overlap "$TARGETS" "$target_files" || continue
        #for target in $targets ; do case "$target" in

        #    p:* )
        #        #test -e "$(statusdir.sh file period ${target#*:})" && {
        #        #  echo "TODO 'cd $CWD;"$CMD"' for $target"
        #        #} || error "Missing period for $target"
        #      ;;

        #    @* ) echo "TODO: run at context $target"; continue ;;

        #  esac
        #done
        test -z "$DEBUG" ||
          $htd_log ok pre-proc "CMD=$CMD RT=$RT TARGETS=$TARGETS CWD=$CWD CTX=$CTX" >&2
      ;;

    update | post-proc ) shift
        test -n "$3" || set -- "$1" "$2" 86400
        # TODO: place record in each context. Or rather let backends do what
        # they want with the ret/stdout/stderr.
        note "targets: '$TARGETS'"
        for target in $TARGETS
        do
          scr="$(htd_tasks_buffers "$target" | grep '\.sh$' | head -n 1)"
          test -n "$scr" ||
              error "Error lookuping backend for target '$target'" 1
          test -x "$scr" || { warn "Disabled: $scr"; continue; }
          note "$target($scr): Status $RT, $CMD $CWD $CTX"
        done
        note "TODO record $1: $2 $3"
        #test -e "$stdout" -o -e "$stderr" ||
        #note "Done: $(filesize $stdout $stderr) $(filemtype $stdout $stderr)"
      ;;

    * ) error "'$1'? 'rules $*'"
      ;;
  esac
}
htd_libs__rules=package,table
htd_flags__rules=lp

# htdoc rules development documentation in htdocs:Dev/Shell/Rules.rst
# pick up with config:user/rules/comp.json and build `htd comp` aggregate metadata
# and update statemachines.
#
htd__period_status_files()
{
  touch -t $(date +%H%M) $(statusdir.sh file period 1min)
  #M=$(date +%M)
  #_5M=$(( $(( $M / 5 )) * 5 ))
  #touch -t $(date +%y%m%d%H${_5M}) $(statusdir.sh file period 5min)
  #touch -t $(date +%y%m%d%H00) $(statusdir.sh file period hourly)
  #H=$(date +%H)
  #_3H=$(printf "%02d" $(( $(( $H / 3 )) * 3 )))
  #touch -t $(date +%y%m%d${_3H}00) $(statusdir.sh file period 3hr)
  #touch -t $(date +%y%m%d0000) $(statusdir.sh file period daily)
  #ls -la $(statusdir.sh file period 3hr)
  #ls -la $(statusdir.sh file period 5min)
  #ls -la $(statusdir.sh file period hourly)
}

# Run either when arguments given match a targets, or if any of the linked
# targets needs regeneration.
# Targets should resolve to a path, and optionally a maximum age which defaults
# to 0.
#
htd__run_rule()
{
  line= row_nr= CMD= RT= TARGETS= CWD= CTX=
  local package_id= ENV_NAME= htd_rule_id= vars="$1"
  eval local "$1"
  htd__rules pre-proc "$var" || {
    error "Parsing ctx at $row_nr: $ctx" && continue ; }
  note "Running '$htd_rule_id'..."
  local stdout=$(setup_tmpf .stdout) stderr=$(setup_tmpf .stderr)
  R=0 ; {
    cd $CWD # Home if empty
    htd__rules eval-ctx || { error "Evaluating $ctx" && continue ; }
    test -n "$CMD" || { error "Command required" && continue; }
    test -n "$CWD" || { error "Working dir required" && continue; }
    #test -n "$ENV_NAME" || { error "Env profile required" && continue; }
    note "Executing command.."
    ( cd $CWD && $CMD 2>$stderr >$stdout )
  } || { R=$?
    test "$R" = "$RT" || warn "Unexpected return from rule exec ($R)"
  }
  test "$RT" = "0" || {
    test "$R" = "$RT" &&
      note "Non-zero exit ignored by rule ($R)" ||
        warn "Unexpected result $R, expected $RT"
  }
  htd__rules post-proc $htd_rule_id $R
  rm $stdout $stderr 2>/dev/null
  return $R
}

htd__run_rules()
{
  test -n "$1" || set -- '@local\>'
  htd__rules each "$1" "$2" | while read vars ; do
    htd__run_rule "$vars"
    continue
  done
}

htd__edit_rules()
{
  $EDITOR $htd_rules
}

htd__show_rules()
{
  # TODO use optparse htd_host_arg
  upper=0 default_env out-fmt plain
  upper=0 default_env raw false
  test -s "${htd_rules-}" || error "No rules found <${htd_rules-}>" 1
  trueish "$raw" && {
    test -z "$*" || error "Raw mode does not accept filter arguments" 1
    local cutf= fields="$(fixed_table_hd_ids "$htd_rules")"
    fixed_table_cuthd "$htd_rules" "$fields"
    cat $htd_rules | case "$out_fmt" in
      txt|plain|text ) cat - ;;
      csv )       out_fmt=csv   htd__table_reformat - ;;
      yml|yaml )  out_fmt=yml   htd__table_reformat - ;;
      json )      out_fmt=json  htd__table_reformat - ;;
      * ) error "Unknown format '$out_fmt', use txt|plain|text,csv,yml|yaml or json" 1 ;;
    esac
  } || {
    local fields="Id Nr CMD RT TARGETS CWD CTX line"
    test "$out_fmt" = "csv" && { echo "#"$fields | tr ' ' ',' ; }
    htd__rules each "$@" | while read vars
    do
      line= row_nr= CMD= RT= TARGETS= CWD= CTX=
      local package_id= ENV_NAME= htd_rule_id=
      {
        eval local "$vars" && htd__rules pre-proc "$vars"
      } || {
        error "Resolving context at $row_nr ($?)" && continue
      }
      case "$out_fmt" in
        txt|plain|text ) printf \
            "$htd_rule_id: $CMD <$CWD> [$CTX] ($RT) $TARGETS <$htd_rules:$row_nr>\n"
          ;;
        csv ) printf \
            "$htd_rule_id,$row_nr,\"$CMD\",$RT,\"$TARGETS\",\"$CWD\",\"$CTX\",\"$line\"\n"
          ;;
        yml|yaml ) printf -- "- nr: $row_nr\n  id: $htd_rule_id\n"\
"  CMD: \"$CMD\"\n  RT: $RT\n  CWD: \"$CWD\"\n  CTX: \"$CTX\"\n"\
"  TARGETS: \"$TARGETS\"\n  line: \"$line\"\n"
          ;;
        json ) test $row_nr -eq 1 && printf "[" || printf ",\n"
          printf "{ \"id\": \"$htd_rule_id\", \"nr\": $row_nr,"\
" \"CMD\": \"$CMD\", \"RT\": $RT, \"TARGETS\": \"$TARGETS\","\
" \"CWD\": \"$CWD\", \"CTX\": \"$CTX\", \"line\": \"$line\" }"
          ;;
        * ) error "Unknown format '$out_fmt'" 1 ;;
      esac
    done
    test "$out_fmt" = "json" && { echo "]" ; } || true
  }
}
htd_of__show_rules='plain csv yaml json'


# arg: 1:target
# ret: 2: has run but failed or incomplete, 1: not run, 0: run was ok
htd__rule_target()
{
  case "$1" in

    # Period: assure exec once each period
    p:* )
      case "$1" in
        [smhdMY]* ) ;;
        [0-9]* )
          tdate=$(date +%y%m%d0000)
          ;;
      esac
      ;;

    # Domain
    d:* )
      sf=$(statusdir.sh file domain-network)
      test -e "$sf" || return 0
      test "d:$(cat $sf)" = "$1" || return 1
      ;;

    @* )
      sf=$(statusdir.sh file htd-rules-$1)
      test -s $sf && return 2 || test -e $sf || return 1
      ;;

  esac
}

#
