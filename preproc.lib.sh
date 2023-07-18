#!/usr/bin/env bash

preproc_lib_load()
{
  true
}


preproc_define_r='^\ *#\ *define\ ([^\ ]*)\ (.*)$'
preproc_include_r='^\ *#\ *include\ (.)(.*).$'

preproc()
{
  local lnr=0 directive= args_rx_ref= args_arr=
  while read line
  do
    lnr=$(( $lnr + 1 ))
    [[ "$line" =~ ^\ *#\ *([^\ ]*).*$ ]] && {
      directive="${BASH_REMATCH[1]}"
      args_rx_ref="preproc_${directive}_r"

      test -n "${!args_rx_ref}" || {
        $LOG error "preproc" "Unknown '$directive' preproc instruction at $lnr"
        exit 1
      }

      [[ "$line" =~ ${!args_rx_ref} ]] && {
        $LOG info "preproc" "Processing '$directive' at $lnr"

        args_arr=("${BASH_REMATCH[@]}")
        unset args_arr[0]
        preproc_d_$directive "${args_arr[@]}"

      } || {
        $LOG error "preproc" "Illegal arguments for '$directive' at $lnr"
        exit 1
      }
      continue
    }

    echo "$line"
  done
}

preproc_d_define()
{
  eval $1=$2
  $LOG note "preproc:define" "New value" "$1='${!1}'"
}

#preproc_d_ifdef() { }
#preproc_d_ifndef() { }

#preproc_d_if() { }
#preproc_d_elif() { }
#preproc_d_endif() { }

# Resolve path and produce contents
preproc_d_include()
{
  local global=0
  test "$1" = "<" && global=1
  set -- "$1" "$2" "$( resolve_include "$2" $global )"
  $LOG note "preproc:preproc" "Pre-processing..." "$3"
  preproc < "$3"
  $LOG debug "preproc:preproc" "Pre-processed" "$3"
}

resolve_include() # ID [Global] [PATH] [Exts...]
{
  local ID="$1" global=$2 Lookup_Path="$3" ; shift 3 || true

  test -n "$*" || set -- .inc.sh
  test "1" = "$global" && {

    test -n "$Lookup_Path" || Lookup_Path="$SCRIPTPATH"

    f_inc_path="$( echo "$Lookup_Path" | tr ':' '\n' | while read sp
      do
        for ext in $@
        do
          test -e "$sp/$ID.$ext" || continue
          echo "$sp/$ID.$ext"
          break
        done
      done )"

    test -n "$f_inc_path" || { $LOG error "preproc" "No path for global include '$1'" ; exit 1; }
  } || {

    test -e "$ID" || {
      for ext in $@
      do test -e "$ID.$ext" && { echo "$ID.$ext"; break; }
      done
    }

    test -e "$ID" || { $LOG error "preproc" "Cannot find include '$ID'" ; exit 1; }
    echo "$ID"
  }
}

test -n "$1" || set -- preproc

"$@"
