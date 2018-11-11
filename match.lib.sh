#!/bin/sh



match_req_names_tab()
{
  local pwd="$(pwd)"

  tabs="$(while test "$pwd" != '/'
      do
        test -e "$pwd/table.names" && printf -- "%s/table.names " "$pwd"
        pwd="$(dirname $pwd)"
      done)"

  export tabs
}

# Load part names and patterns
match_load_table()
{
  test -n "$1" || set -- book

  match_load_defs $scriptpath/table.$1

  test "$scriptpath" = "$(cd "$(pwd)"; pwd -P)" || {
    test -s "$(pwd)/table.$1" && {
      match_load_defs "$(pwd)/table.$1" \
        || error "Error loading ./table.$1" 1
    } || true
  }
}

match_load_defs()
{
  MATCH_NAME_VARS="$(echo $MATCH_NAME_VARS $(echo $(grep '^match_[A-Z_][A-Z0-9_]*=.*' $1 |
    sed 's/^match_\([^=]*\)=.*$/\1/g')) | unique_words)"

  # read in as array? try to clean dupes? overrides?
  #echo MATCH_NAME_VARS_new=$MATCH_NAME_VARS_new
  #read -ra MATCH_NAME_VARS<<<$(printf '%s\n' "$MATCH_NAME_VARS_new" |
  #  awk -v RS='[[:space:]]+' '!a[$0]++{printf "%s%s", $0, RT}')

  trueish "$silent" || note "Loading $1"
  . $1
}

# Take any string and return a Regex to match that exact string, see
# match-grep-pattern-test.
match_grep() # String
{
  echo "$1" | gsed -E 's/([^A-Za-z0-9{}(),?!@+_])/\\\1/g'
}

compile_glob()
{
  echo "$1" | node_globs2regex
}

# simple glob to regex
gsed_globs2regex()
{
  gsed -E '
      s/\*/.*/g
      s/([^A-Za-z0-9{}(),?!@+_*])/\\\1/g
    '
}

# extended glob to regex
node_globs2regex()
{
  node -e '
var globToRegExp = require("glob-to-regexp");
var readline = require("readline");
var rl = readline.createInterface({
  input: process.stdin,
  output: process.stdout,
  terminal: false
});
rl.on("line", function(line){
  console.log(globToRegExp(line, { extended: true }).toString().slice(1,-1));
})
    '
}

perl_globs2regex()
{
  perl -pe '
s{
    ( [?*]+ )  # a run of ? or * characters
|
    \\ (.)     # backslash escape
|
    (\W)       # any other non-word character
}{
    defined $1
        ? ".{" . ($1 =~ tr,?,,) . (index($1, "*") >= 0 ? "," : "") . "}"
        : quotemeta $+
}xeg;
    '
}

# Filter out


# To escape filenames and perhaps other values for use as grep literals
match_grep_pattern_test()
{
  p_="$(match_grep "$1")"
  # test regex (nice for dev mode)
  echo "$1" | grep -q "^$p_$" || {
    error "cannot build regex for $1: $p_"
    echo "$p" > invalid.paths
    return 1
  }
}

# sed/grep tricks to get name parts, find mismatches, matches,
# parse metadata or reformat paths, etc
match_name_pattern()
{
  local pat var
  match_grep_pattern_test "$1" || return 1
  grep_pattern="$p_"
  MATCH_NAME_VAR_matched=
  for var in $MATCH_NAME_VARS
  do
    pat="$(eval echo "\$match_$var")"
    echo "$@" | grep '@'$var > /dev/null && {
      MATCH_NAME_VAR_matched="$(echo $MATCH_NAME_VAR_matched $var)"
    } || {
      continue
    }
    test -n "$2" -a "$2" = "$var" && {
      grep_pattern="$(echo "$grep_pattern" |
        sed 's/@'$var'/\('"$pat"'\)/g' |
        sed 's/\([^\\]\)\([{}()?|]\)/\1\\\2/g' |
        sed 's/\([^\\]\)\([{}()?|]\)/\1\\\2/g'
      )"
    } || {
      #echo "pat=$pat"
      grep_pattern="$(echo "$grep_pattern" |
        sed 's/@'$var'/'"$pat"'/g' |
        sed 's/\([^\\]\)\([{}()?.|]\)/\1\\\2/g' |
        sed 's/\([^\\]\)\([{}()?.|]\)/\1\\\2/g'
      )"
    }
    #echo "grep_pattern='$grep_pattern'"
  done
}

# rewrite file $1 to $1$2, compile-glob each content line
compile_globs()
{
  test -e "$1" || error "source file expected" 1
  test -n "$2" || set -- "$1" ".regex"
  test ! -s "$1$2" || {
    note "truncating existing $1$2"
  }
  read_nix_style_file "$1" | while read glob
  do
    compile_glob "$glob"
  done > $1$2
  info "Recompiled $(count_lines "$1$2") ($1$2)"
}

# wrapper for compile-globs
globlist_to_regex()
{
  while test -n "$1"
  do
    test -e "$1" || error "no globlist file '$1'" 1
    test -s "$1" && {
      test $1 -ot $1.regex || {
        compile_globs $1 .regex || {
          error "error compiling '$1'"
          return 1
        }
      }
      cat $1.regex
    }
    shift
  done
}
