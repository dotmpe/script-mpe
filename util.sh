req_arg()
{
	label=$(eval echo \${req_arg_$4[0]})
	varname=$(eval echo \${req_arg_$4[1]})
	test -n "$1" || {
		err "$2 requires argument at $3 '$label'"
		return 1
	}
	test -n "$varname" && {
		export $varname="$1"
	} || {
		export $4="$1"
	}
}

pushd_cwdir()
{
	test -n "$CWDIR" -a "$CWDIR" != "$(pwd)" && {
		echo "pushd $CWDIR" "$(pwd)"
		pushd $WDIR
	} || echo -n
}

popd_cwdir()
{
	test -n "$CWDIR" -a "$CWDIR" = "$(pwd)" && {
		echo "popd $CWDIR" "$(pwd)"
		test "$(popd)" = "$CWDIR"
	} || echo -n
}

