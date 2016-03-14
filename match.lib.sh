

match_req_names_tab()
{
  #local to_root=$(pwd | sed -E 's/[^\/]*/../g')
  local tabpaths="$HOME/bin/default-names.tab"
  local pwd="$(pwd)"
  while test "$pwd" != '/'
  do
    tabpaths="$pwd/table.names $tabpaths"
    pwd="$(dirname $pwd)"
  done

  # export
  paths=
  for path in $tabpaths
  do
    test -e "$path" || continue
    tabs="$path $tabs"
  done
}

# Load part names and patterns
match_load_table()
{
  test -n "$1" || set -- book
  match_load_defs ~/bin/table.$1
  test -s "$(pwd)/table.$1" && {
    test "$(pwd)" != "$(echo ~/bin)" &&
      match_load_defs "$(pwd)/table.$1" || noop
    } || noop
    #error "No local table.$1" 1
}


