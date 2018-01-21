#!/bin/sh

set -e



# Set env for str.lib.sh
str_lib_load()
{
  case "$(uname)" in
      Darwin )
          expr=bash-substr ;;
      Linux )
          expr=sh-substr ;;
      * )
          error "Unable to init expr" 1;;
  esac

  test -n "$ext_groupglob" || {
    test "$(echo {foo,bar}-{el,baz})" != "{foo,bar}-{el,baz}" \
          && ext_groupglob=1 \
          || ext_groupglob=0
    # FIXME: part of [vc.bash:ps1] so need to fix/disable verbosity
    #debug "Initialized ext_groupglob=$ext_groupglob"
  }

  test -n "$ext_sh_sub" || ext_sh_sub=0

  #      echo "${1/$2/$3}" ... =
  #        && ext_sh_sub=1 \
  #        || ext_sh_sub=0
  #  #debug "Initialized ext_sh_sub=$ext_sh_sub"
  #}

  test -x "$(which php)" &&
    bin_php=1 || bin_php=0
}

# Web-like ID for simple strings, input can be any series of characters.
# c='\.\\\/:_' mkid STR
# Output has alphanumerics, periods, hyphen, underscore, colon and back-/fwd dash
# Allowed non-hyhen/alphanumeric ouput chars is customized with env 'c'
mkid()
{
  test -n "$1" || error "mkid argument expected" 1
  var_isset c || c='\.\\\/:_'
  id=$(printf -- "$1" | tr -sc 'A-Za-z0-9'$c'-' '-' )
}

# Variable-like ID for any series of chars, only alphanumerics and underscore
# mkvid STR
mkvid()
{
  test -n "$1" || error "mkvid argument expected" 1
  trueish "$upper" && {
    vid=$(printf -- "$1" | sed 's/[^A-Za-z0-9_]\{1,\}/_/g' | tr 'a-z' 'A-Z')
    return
  }
  falseish "$upper" && {
    vid=$(printf -- "$1" | sed 's/[^A-Za-z0-9_]\{1,\}/_/g' | tr 'A-Z' 'a-z')
    return
  }
  vid=$(printf -- "$1" | sed 's/[^A-Za-z0-9_]\{1,\}/_/g')
  # Linux sed 's/\([^a-z0-9_]\|\_\)/_/g'
}

# A lower- or upper-case mkid variant with only alphanumerics and hypens.
# upper= mkcid STR
# Produces ID's for env vars or maybe a issue tracker system.
# TODO: introduce a snake+camel case variant for Pretty-Tags or Build_Vars?
# For real pretty would want lookup for abbrev. Too complex so another function.
mksid()
{
  test -n "$1" || error "mkcid argument expected" 1
  var_isset c || c=_
  test -n "$upper" && {
    trueish "$upper" &&
      mkid "$(printf -- "$1" | tr 'a-z' 'A-Z')"
    falseish "$upper" &&
      mkid "$(printf -- "$1" | tr 'A-Z' 'a-z')"
  } ||
    mkid "$(printf -- "$1" )"
  sid="$id"
}

# A either args or stdin STR to lower-case pipeline element
str_upper()
{
  test -n "$1" \
    && { echo "$1" | tr 'a-z' 'A-Z'; } \
    || { cat - | tr 'a-z' 'A-Z'; }
}

# Counter-part to str-upper
str_lower()
{
  test -n "$1" \
    && { echo "$1" | tr 'A-Z' 'a-z'; } \
    || { cat - | tr 'A-Z' 'a-z'; }
}

# XXX: deprecate in favor of fnmatch/case X in Y expressions?
str_match()
{
  expr "$1" : "$2" >/dev/null 2>&1 || return 1
}

str_replace_start()
{
    test -n "$1" || err "replace-subject" 1
    test -n "$2" || err "replace-find" 2
    test -n "$3" || err "replace-replace" 2
    test -n "$ext_sh_sub" || err "ext-sh-sub not set" 1

    test "$ext_sh_sub" -eq 1 && {
        echo "${1##$2/$3}"
    } || {
        match_grep_pattern_test "$2"
        local find=$p_
        match_grep_pattern_test "$3"
        echo "$1" | sed "s/^$find/$p_/g"
    }
}
str_replace_back()
{
    test -n "$1" || err "replace-subject" 1
    test -n "$2" || err "replace-find" 2
    test -n "$3" || err "replace-replace" 2
    test -n "$ext_sh_sub" || err "ext-sh-sub not set" 1

    test "$ext_sh_sub" -eq 1 && {
        echo "${1%%$2/$3}"
    } || {
        match_grep_pattern_test "$2"
        local find=$p_
        match_grep_pattern_test "$3"
        echo "$1" | sed "s/$find$/$p_/g"
    }
}


# Trim end off Str by Len chars
str_trim_end() # Str Len [Start]
{
  test -n "$3" || set -- "$1" "$2" 1
  echo "$1" | cut -c$3-$(( ${#1} - $2 ))
}


str_replace()
{
    test -n "$1" || err "replace-subject" 1
    test -n "$2" || err "replace-find" 2
    test -n "$3" || err "replace-replace" 2
    test -n "$ext_sh_sub" || err "ext-sh-sub not set" 1

    test "$ext_sh_sub" -eq 1 && {
        echo "${1/$2/$3}"
    } || {
        match_grep_pattern_test "$2"
        local find=$p_
        match_grep_pattern_test "$3"
        echo "$1" | sed "s/$find/$p_/"
    }
}

str_strip_rx()
{
  echo "$2" | sed "s/$1//"
}

# x-platform regex match since Bash/BSD test wont chooche on older osx
x_re()
{
  echo $1 | grep -E "^$2$" > /dev/null && return 0 || return 1
}

# Easy matching for strings based on glob pattern, without adding a Bash
# dependency (keep it vanilla Bourne-style shell). Quote arguments with '*',
# to prevent accidental expansion to local PWD filenames.
fnmatch() # Glob Str
{
  case "$2" in $1 ) return 0 ;; *) return 1 ;; esac
}

words_to_lines()
{
  test -n "$1" && {
    while test -n "$1"
    do echo "$1"; shift; done
  } || {
    tr ' ' '\n'
  }
}
lines_to_words()
{
  test -n "$1" && {
    { while test -n "$1"
      do cat "$1"; shift; done
    } | tr '\n' ' '
  } || {
    tr '\n' ' '
  }
}
words_to_unique_lines()
{
  words_to_lines | sort -u
}
unique_words()
{
  words_to_unique_lines | lines_to_words
}
reverse_lines()
{
  sed '1!G;h;$!d'
}

expr_substr()
{
    test -n "$expr" || error "expr init req" 1
    case "$expr" in
        sh-substr )
            expr substr "$1" "$2" "$3" ;;
        bash-substr )
            bash -c 'MYVAR=_"'"$1"'"; printf -- "${MYVAR:'$2':'$3'}"' ;;
        * ) error "unable to substr $expr" 1
    esac
}


# Try to turn given variable names into a more "terse", human readble string seq
var2tags()
{
  echo $(for varname in $@
  do
    local value="$(eval printf \"\$$varname\")"
    test -n "$value" || continue
    pretty_print_var "$varname" "$value"
  done)
}

# Read properties file and re-format (like mkvid) for shell use
properties2sh()
{
  # NOTE: AWK oneliner to transforms keys for '=' separated kv list, leaving the
  # value exactly as is.
  awk '{ st = index($0,"=") ;
      key = substr($0,0,st-1) ;
      gsub(/[^a-z0-9]/,"_",key) ;
      print key "=" substr($0,st+1) }' $1

  # NOTE: This works but it splits at every equals sign
  #awk 'BEGIN { FS = "=" } ;
  #    { if (NF<2) next;
  #    gsub(/[^a-z0-9]/,"_",$1) ;
  #    print $1"="$2 }' $1
}

# Take some Propertiesfile compatible lines, strip/map the keys prefix and
# reformat them as mkvid for use in shell script export/eval/...
sh_properties()
{
  test -n "$*" || error "sh-properties expects args: '$*'" 1
  test -e "$1" -o "$1" = "-" || error "sh-properties file" 1
  # NOTE: Always be carefull about accidentally introducing newlines, will give
  # hard-to-debug syntax failures here or in the local evaluation
  read_nix_style_file $1 | grep '^'"$2" | sed 's/^'"$2"'/'"$3"'/g' | properties2sh -
}

# A simple string based key-value lookup with some leniency and translation convenience
# property PREFIX SUBST KEYS...
property()
{
  test -n "$1" || error "property expects props: '$*'" 1
  local props="$1" prefix="$2" subst="$3" vid=
  local tmpf=$(setup_tmpf)
  sh_properties "$1" "$2" "$3" > $tmpf
  shift 3
  test -z "$subst" || upper=0 mkvid "$subst"
  (
    . $tmpf
    rm $tmpf
    while test -n "$1"
    do
      local __key= __value=
      test -n "$vid" && __key=${vid}$1 || __key=$1
      __value="$(eval printf -- \"\$$__key\")"
      shift
      test -n "$__value" || continue
      print_var "$__key" "$__value"
    done
  )
}

# Get from a properties file
get_property() # Properties-File Key
{
  test -e "$1" -a -n "$2" || error "Args 'File Key' expected: '$1' '$2'" 1
  grep '^'$2'\ *\(=\|:\).*$' $1 | sed 's/^[^:=]*\ *[:=]\ *//'
}

# write line or header+line with key/value pairs (sh, csv, tab, or json format)
# varsfmt FMT [VARNAMES...]
varsfmt()
{
  # set default format
  test -n "$1" && {
      FMT="$(str_upper "$1")"
    } || {
      FMT=TAB
    }
  shift || error "Arguments expected" 1
  set -- "$@"

  # Output line (or header + line) for varnames/-values
  case "$FMT" in
    CSV|TAB )        printf "# $*\n" ;;
    JS* )            printf "{" ;;
  esac
  while test -n "$1"
  do
    case "$FMT" in
      SH )           printf -- "$1=\"$(eval echo "\$$1")\"" ;;
      CSV )          printf -- "\"$(eval echo "\$$1")\"" ;;
      # FIXME: yaml inline is only opt. also shld have fixed-wdth tab
      YAML|JS* )     printf -- "\"$1\":\"$(eval echo "\$$1")\"" ;;
      TAB )          printf -- "$(eval echo "\$$1")" ;;
    esac
    test -n "$2" && {
      case "$FMT" in
        CSV|JS* )    printf "," ;;
        SH )         printf " " ;;
        TAB )        printf "\t" ;;
      esac
    } || noop
    shift
  done
  case "$FMT" in
    JS* )            printf "}\n" ;;
    * )              printf "\n" ;;
  esac
}

# Echo element in a field-separated string the hard way. Fetches one prefix
# at a time to 1. keep the function adn regex simple enough while 2. allow
# the suffix contain field separators.
# For example to parse file names or numbers from grep -rn result lines.
# Or, specifically to parse EDL Sh-references (see edl.rst)
resolve_prefix_element()
{
  test -n "$3" || set -- "$1" "$2" ":"
  while test $1 -gt 1
  do
    set -- "$(( $1 - 1 ))" "$(echo "$2" | sed "s/^[^$3]*$3\\(.*\\)$/\\1/" )" "$3"
  done
  echo "$2" | sed "s/^\\([^$3]*\\)$3.*$/\\1/"
}

# XXX: wouldn't `pr` suffice?
column_layout()
{
  test -n "$colw" || local colw=22
  local cols=$(( $(tput cols) / $colw ))
  while read line
  do
    printf -- "$line\t"
    for i in $(seq $(( $cols - 1 )) )
    do
      read line
      printf -- "$line\t"
    done
    printf "\n"
  done |
    column -t
}

str_title()
{
  # Other ideas to test as ucwords:
  # https://stackoverflow.com/questions/12420317/first-character-of-a-variable-in-a-shell-script-to-uppercase
  trueish "$bin_php" && {
    trueish "$first_word_only" &&
      php -r "echo ucfirst('$1');" ||
      php -r "echo ucwords('$1');"
  } || {
    trueish "$first_word_only" && {
      echo "$1" | awk '{ print toupper(substr($0, 1, 1)) substr($0, 2) }'
    } || {
      first_word_only=1 str_title "$(echo "$1" | tr ' ' '\n')" | tr '\n' ' '
    }
  }
}
