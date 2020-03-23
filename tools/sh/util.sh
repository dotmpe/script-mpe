#!/usr/bin/env bash
test -z "${sh_util_:-}" && sh_util_=1 || return 198 # Recursion

info() { exit 123; }

git_version()
{
  test $# -eq 1 -a -d "$1" || return
  ( test "$PWD" = "$1" || cd "$1"
    git describe --always )
}

assert_nonzero()
{
  test $# -gt 0 && test -n "$1"
}

# Web-like ID for simple strings, input can be any series of characters.
# Output has limited ascii.
#
# alphanumerics, periods, hyphen, underscore, colon and back-/fwd dash
# Allowed non-hyhen/alphanumeric ouput chars is customized with env 'c'
#
# mkid STR '-' '\.\\\/:_'
mkid() # Str Extra-Chars Substitute-Char
{
  #test -n "$1" || error "mkid argument expected" 1
  local s="$2" c="$3"
  # Use empty c if given explicitly, else default
  test $# -gt 2 || c='\.\\\/:_'
  test -n "$s" || s=-
  test -n "${upper-}" && {
    trueish "${upper-}" && {
      id=$(printf -- "%s" "$1" | tr -sc 'A-Za-z0-9'"$c$s" "$s" | tr 'a-z' 'A-Z')
    } || {
      id=$(printf -- "%s" "$1" | tr -sc 'A-Za-z0-9'"$c$s" "$s" | tr 'A-Z' 'a-z')
    }
  } || {
    id=$(printf -- "%s" "$1" | tr -sc 'A-Za-z0-9'"$c$s" "$s" )
  }
}
# Sync-Sh: BIN:str-htd.lib.sh

# A lower- or upper-case mkid variant with only alphanumerics and hypens.
# Produces ID's for env vars or maybe a issue tracker system.
# TODO: introduce a snake+camel case variant for Pretty-Tags or Build_Vars?
# For real pretty would want lookup for abbrev. Too complex so another function.
mksid()
{
  test $# -gt 2 || set -- "${1-}" "${2-}" "_"
  mkid "$@" ; sid=$id ; unset id
}
# Sync-Sh: BIN:str-htd.lib.sh

# Variable-like ID for any series of chars, only alphanumerics and underscore
# mkvid STR
mkvid()
{
  test $# -eq 1 -a -n "${1-}" || error "mkvid argument expected ($*)" 1
  trueish "${upper-}" && {
    vid=$(printf -- "$1" | sed 's/[^A-Za-z0-9_]\{1,\}/_/g' | tr 'a-z' 'A-Z')
    return
  }
  falseish "${upper-}" && {
    vid=$(printf -- "$1" | sed 's/[^A-Za-z0-9_]\{1,\}/_/g' | tr 'A-Z' 'a-z')
    return
  }
  vid=$(printf -- "$1" | sed 's/[^A-Za-z0-9_]\{1,\}/_/g')
  # Linux sed 's/\([^a-z0-9_]\|\_\)/_/g'
}
# Sync-Sh: BIN:str-htd.lib.sh

# Error unless non-empty and trueish
trueish()
{
  test $# -eq 1 -a -n "${1:-}" || return
  case "$1" in
    [Oo]n|[Tt]rue|[Yyj]|[Yy]es|1 )
      return 0;;
    * )
      return 1;;
  esac
}
# Sh-Copy: HT:tools/u-s/parts/trueish.inc.sh
# Sh-Copy: U-S:src/sh/lib/sys.lib.sh

# Error unless non-empty and falseish
falseish()
{
  test $# -eq 1 -a -n "${1:-}" || return
  case "$1" in
    [Oo]ff|[Ff]alse|[Nn]|[Nn]o|0)
      return 0;;
    * )
      return 1;;
  esac
}
# Sh-Copy: U-S:src/sh/lib/sys.lib.sh

# Error unless empty or falseish
not_trueish()
{
  test $# -eq 1 -a -n "${1:-}" || return 0
  falseish "$1"
}

# Error unless empty or trueish
not_falseish()
{
  test $# -eq 1 -a -n "${1:-}" || return 0
  trueish "$1"
}

# Read file filtering octothorp comments and empty lines
sh-read () # ( FILE | - )
{
  test $# -gt 0 -a $# -le 2 || return 98
  test -n "$1" -a -e "$1" || return 97
  test -n "${2:-}" || set -- "$1" '^\s*(#.*|\s*)$'
  {
    test -z "${cat_f:-}" && {
      grep -Ev "$2" "$1" || return 1
    } || {
      cat $cat_f "$1" | grep -Ev "$2" || return 1
    }
  } | sed 's/\ \#.*$//' # Strip trailing comments
}
# Sh-Copy: read_nix_style_file

test -n "${U_S-}" ||
  $LOG "error" "" "Expected U-S env" "" 1

test -d $U_S/.git || {
  trueish "$ENV_DEV" && {
    {
      test ! -d "$U_S" || rm -rf "$U_S"
      git clone https://github.com/dotmpe/user-scripts.git $U_S
    }
    ( cd $U_S/ && git fetch --all &&
        git checkout feature/docker-ci &&
        git pull origin feature/docker-ci )
  } ||
      $LOG "error" "" "Expected U-S checkout" "" 1
}

. "$U_S/tools/sh/parts/fnmatch.sh" # No-Sync
. "$U_S/tools/ci/parts/print-err.sh" # No-Sync
. "$U_S/tools/sh/parts/include.sh" # No-Sync

sh_include hd-offsets suite-from-table suite-source suite-run

# Sync: X-CI-0.1:
# Sync: U-S:
