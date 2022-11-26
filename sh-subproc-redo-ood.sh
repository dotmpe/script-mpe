
### Lookup performance of Bash arrays


# Ofcourse array lookup outperforms any sort of stdio streaming and string
# matching.


source tools/benchmark/_lib.sh

sh_mode strict test


read_content_array_bash4 ()
{
  iarr=()
  while IFS= read -r line; do
      arr+=("$line")
  done < file
}

is_target ()
{
	declare target
	for target in "${target_arr[@]}"
	do
	  if [ "$target" = "${1:?}" ] ; then
			return
	  fi
	done
	return 0
}

is_ood ()
{
	declare target
	for target in "${ood_arr[@]}"
	do
	  if [ "$target" = "${1:?}" ] ; then
			return
	  fi
	done
	return 0
}

redo-istarget ()
{
  while test $# -gt 0
  do
    redo-targets | grep -qxF "${1:?}" ||  {
      $LOG error "" "No such target" "$1" ; return 1
    }
		shift
  done
}

redo-istarget2 ()
{
  while test $# -gt 0
  do
    echo "$targets" | grep -qxF "${1:?}" ||  {
      $LOG error "" "No such target" "$1" ; return 1
    }
    shift
  done
}

redo-istarget3 ()
{
  while test $# -gt 0
  do
    is_target "${1:?}" || {
      $LOG error "" "No such target" "$1" ; return 1
    }
    shift
  done
}


redo-ifdone ()
{
  while test $# -gt 0
  do
    redo-targets | grep -qxF "${1:?}" ||  {
      $LOG error "" "No such target" "$1" ; return 1
    }
    # Target is up-to-date unless it appears in OOD listing
    redo-ood 2>/dev/null | grep -vqxF "${1:?}" || return
    shift
  done
}

redo-ifdone2 ()
{
  while test $# -gt 0
  do
    echo "$targets" | grep -qxF "${1:?}" ||  {
      $LOG error "" "No such target" "$1" ; return 1
    }
    # Target is up-to-date unless it appears in OOD listing
    echo "$ood" | grep -vqxF "${1:?}" || return
    shift
  done
}

redo-ifdone3 ()
{
  while test $# -gt 0
  do
    is_target "${1:?}" || {
      $LOG error "" "No such target" "$1" ; return 1
    }
		! is_ood "${1:?}" || return
    shift
  done
}

declare targets ood
targets=$(redo-targets)
ood=$(redo-ood)

declare -a target_arr ood_arr
mapfile -t target_arr <<< $(redo-targets)
mapfile -t ood_arr <<< $(redo-ood)


#ref=.meta/cache/redo-env.sh
ref=.meta/cache/context.list
refs="$ref .cllct/src/scm-status .cllct/src/sh-files.list .cllct/src/sh-libs.list"
refs="xxx foo bar baz"
test_cmd ()
{
  "$@"
}

runs=10

echo
echo "Repeated redo-targets calls"
time run_test $runs cmd redo-istarget $refs
echo
echo "Cached redo-targets output string"
time run_test $runs cmd redo-istarget2 $refs
echo
echo "Cached redo-targets lines array"
time run_test $runs cmd redo-istarget3 $refs

echo
echo "Repeated redo-targets/ood calls"
time run_test $runs cmd redo-ifdone $refs
echo
echo "Cached redo-targets/ood output string"
time run_test $runs cmd redo-ifdone2 $refs
echo
echo "Cached redo-targets/ood lines array"
time run_test $runs cmd redo-ifdone3 $refs

#"$@"
#
