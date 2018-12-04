#!/bin/sh

htd__function()
{
  test -n "$1" || set -- copy
  case "$1" in

    copy ) shift
        copy_function "$@" || return $?
      ;;

    start-line ) shift
        function_linenumber "$@" || return $?
        echo $line_number
      ;;

    range ) shift
        function_linerange "$@" || return $?
        echo $start_line $span_lines $end_line
      ;;

    help ) shift ; local file= grep_line=
        htd_function_comment "$@"
        htd_function_help
      ;;

    comment ) shift
        test -n "$1" || error "name or string-id expected" 1
        htd_function_comment "$@"
      ;;

    copy-paste ) shift

        test -f "$2" -a -n "$1" -a -z "$3" || error "usage: FUNC FILE" 1
        copy_paste_function "$1" "$2"
        note "Moved function $1 to $cp"
      ;;

    * ) error "'$1'?" 1
      ;;
  esac
}
