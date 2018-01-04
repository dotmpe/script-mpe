#!/bin/sh
td__source=$_
test -z "$__load_lib" || set -- "load-ext"


# ----

#choice_strict=true



td__status()
{
  redis-cli
  echo TODO find new repos
}

td__foo()
{
  redis-cli set foo bar
  redis-cli set foo1 1.123
  redis-cli set topic:Dev:foo 1
  redis-cli set topic:Dev 1
  redis-cli set topic:Research:foo 1
  redis-cli set topic:Research 1
}

td__bar()
{
  redis-cli get foo
  redis-cli get foo1
  redis-cli --scan --pattern 'foo*'
  redis-cli --scan --pattern 'topic:*'
}

td_req_name()
{
  test -n "$1" || return 1
}

td__save()
{
  td_req_name "$1" || {
    error "NAME expected" 1
  }
  for x in $1
  do
    test "$(redis-cli --raw get tag:$x)" != "" && {
      note "Existing $x"
    } || {
      note "New $x"
    }
  done
}


# ----


def_func=td__status


td__usage()
{
	echo 'Usage: '
	echo "  $scriptname.sh <cmd> [<args>..]"
}

td__help()
{
	td__usage
	echo 'Functions: '
	echo '  status                           List topics'
	echo ''
	echo '  help                             print this help listing.'
}

td__lib()
{
  __load=ext . ~/bin/std.lib.sh
  __load=ext . ~/bin/match.lib.sh
  match_load_table
  __load=ext . ~/bin/vc.sh
}


# Main

# Use hyphen to ignore source exec in login shell
case "$0" in "" ) ;; "-*" ) ;; * )
  # Ignore 'load-ext' sub-command
  case "$1" in load-ext ) ;; * )

    scriptname=topicdir
		cmd=$1
		func=$cmd
		[ -n "$def_func" -a -z "$func" ] \
			&& func=$def_func \
			|| func=$(echo "td__$cmd" | tr '-' '_')
		td__lib
		type $func >/dev/null 2>&1 && {
			func_exists=1
			shift 1
			$func "$@"
		} || {
			e=$?
			[ -z "$cmd" ] && {
				td__usage
				error 'No command given, see "help"' 1
			} || {
				[ "$e" = "1" -a -z "$func_exists" ] && {
					td__usage
					error "No such command: $cmd" 1
				} || {
					error "Command $cmd returned $e" $e
				}
			}
		}

  esac
esac
