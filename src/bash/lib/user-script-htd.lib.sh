# Some fooling around for user-script context.

user_script_unique_names_count_script_lines ()
{
  while read -r path
  do
    test -e "$path" || continue
    : "$(basename "$path")"
    echo "$path $_"
  done | awk '!a[$2]++' | user_script_count_script_lines
}

user_script_count_script_lines ()
{
  while read -r path rest
  do
    : "$(grep -v '^\(#\| *\)$' "$path" | wc -l)"
    echo "$path $_ $rest"
  done | awk 'a+=$2; END { print "total "a" lines" }'
}

user_script_list_shell_scripts ()
{
  local path hashbang
  for path in ${PATH//:/ }
  do
    for x in $path/*
    do
      test -f "$x" -a -x "$x" || continue
      read hashbang < "$x" && fnmatch "#!*sh*" "$hashbang" || continue
      echo "$x"
    done
  done
}

user_script_filter_userdirs ()
{
  while read -r fspath
  do
    test "${fspath:0:${#HOME}}" = "$HOME" || continue
    for x in .
    do
        : "${HOME}/$x"
        test "${fspath:0:${#_}}" != "$_" || continue 2
    done
    echo "$fspath"
  done
}

#
