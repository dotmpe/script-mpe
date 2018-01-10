# NOTE [2017-10-18] salvaged from prototype, integrate later

# Insert line in front of file
prepend_line()
{
	test -n "$1" -a -f "$1" || error "prepend-line Expected existing file '$1'" 1
	mv $1 $1.tmp
	{
		echo "#!/bin/sh"
		cat $1.tmp
	} > $1
	rm $1.tmp
}

# Insert or update generate-by-brixadmin line
generated_by_ba()
{
	test -n "$1" -a -f "$1" ||
		error "generated-by-ba Expected existing file '$1'" 1
}

# Update Sh script and reinitialize header comment if shebang or
# "Generated by brixadmin" line is missing.
# check-sh-header DEST SRC
check_sh_header()
{
	test -n "$1" -a -f "$1" || error "check-sh-header Expected existing file '$1'" 1
	test -n "$2" || set -- "$1" "$scriptpath/sh-compile/header.sh"
	test -f "$1" || error "check-sh-header Expected existing file '$1'" 1
	( head -n 1 "$1" | grep -q '\#\!.*sh.*' ) && {
		note "OK, found shebang"
	} || {
		prepend_line "$1" "#!/bin/sh" &&
			note "Added shebang" || error "adding shebang" $?
	}
	generated_by_ba "$1" || {
		cat $2
	}
}

# TODO:
# ENV= ENV_NAME= update-or-add-after-header SENTINEL-ID SRC DEST
update_or_add_after_header()
{
	test -n "$2" -a -f "$2" ||
		error "generated-by-ba Expected existing file '$2'" 2
	test -n "$3" -a -f "$3" ||
		error "generated-by-ba Expected existing file '$3'" 3
	test -n "$2" || set -- "$(pathname "$2" .sh)" "$2" "$3"
	header_comment "$3" >/dev/null
	#insert_at
	#splice_file_at "$3" "$last_comment_line" "$2"
}

# TODO:
# update-or-add-sh SENTINEL-ID SRC DEST
update_or_add_sh()
{
	test -n "$2" -a -f "$2" ||
		error "generated-by-ba Expected existing file '$2'" 2
	test -n "$3" -a -f "$3" ||
		error "generated-by-ba Expected existing file '$3'" 3
	test -n "$2" || set -- "$(pathname "$2" .sh)" "$2" "$3"
}

