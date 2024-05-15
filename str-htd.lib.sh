#!/bin/sh


# Set env for str.lib.sh
str_htd_lib__load ()
{
  test -n "${uname-}" || export uname="$(uname -s)"
  case "$uname" in
      Darwin ) expr=bash-substr ;;
      Linux ) expr=sh-substr ;;
      * ) error "Unable to init expr for '$uname'" 1;;
  esac

  test -n "${ext_groupglob-}" || {
    test "$(echo {foo,bar}-{el,baz})" != "{foo,bar}-{el,baz}" \
          && ext_groupglob=1 \
          || ext_groupglob=0
    # FIXME: part of [vc.bash:ps1] so need to fix/disable verbosity
    #debug "Initialized ext_groupglob=$ext_groupglob"
  }

  test -n "${ext_sh_sub-}" || ext_sh_sub=0

  #      echo "${1/$2/$3}" ... =
  #        && ext_sh_sub=1 \
  #        || ext_sh_sub=0
  #  #debug "Initialized ext_sh_sub=$ext_sh_sub"
  #}

  test -x "$(which php)" && bin_php=1 || bin_php=0
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
  local s="${2-}" c="${3-}"
  # Use empty c if given explicitly, else default
  test $# -gt 2 || c='\.\\\/:_'
  test -n "$s" || s=-
  test -n "${upper-}" && {
    test "$upper" = "1" && {
      id=$(printf -- "%s" "$1" | tr -sc '[:alnum:]'"$c$s" "$s" | tr '[:lower:]' '[:upper:]')
    }
    test "$upper" = "0" && {
      id=$(printf -- "%s" "$1" | tr -sc '[:alnum:]'"$c$s" "$s" | tr '[:upper:]' '[:lower:]')
    }
  } || {
    id=$(printf -- "%s" "$1" | tr -sc '[:alnum:]'"$c$s" "$s" )
  }
}

# A lower- or upper-case mkid variant with only alphanumerics and hypens.
# Produces ID's for env vars or maybe a issue tracker system.
# TODO: introduce a snake+camel case variant for Pretty-Tags or Build_Vars?
# For real pretty would want lookup for abbrev. Too complex so another function.
mksid() # STR
{
  test $# -gt 2 || set -- "${1-}" "${2-}" "_"
  mkid "$@" ; sid=$id ; unset id
}

# Variable-like ID for any series of chars, only alphanumerics and underscore
mkvid() # STR
{
  test $# -eq 1 -a -n "${1-}" || error "mkvid argument expected ($*)" 1
  local upper=${upper-"-1"} ; test -n "$upper" || upper=-1
  test 1 -eq $upper && {
    vid=$(printf -- "$1" | sed 's/[^A-Za-z0-9_]\{1,\}/_/g' | tr '[:lower:]' '[:upper:]')
    return
  }
  test 0 -eq $upper && {
    vid=$(printf -- "$1" | sed 's/[^A-Za-z0-9_]\{1,\}/_/g' | tr '[:upper:]' '[:lower:]')
    return
  }
  vid=$(printf -- "$1" | sed 's/[^A-Za-z0-9_]\{1,\}/_/g')
  # Linux sed 's/\([^a-z0-9_]\|\_\)/_/g'
}

# Simpler than mksid but no case-change
mkcid()
{
  cid=$(echo "$1" | sed 's/\([^A-Za-z0-9-]\|\-\)/-/g')
}

mknameid()
{
  local id; upper=0 mkid "$1"; nameid="$(echo "$id" | tr -d '-')"
}

# A either args or stdin STR to lower-case pipeline element
str_upper ()
{
  test -n "$1" \
    && { echo "$1" | tr '[:lower:]' '[:upper:]'; } \
    || { cat - | tr '[:lower:]' '[:upper:]'; }
}

# Counter-part to str-upper
str_lower ()
{
  test -n "$1" \
    && { echo "$1" | tr '[:upper:]' '[:lower:]'; } \
    || { cat - | tr '[:upper:]' '[:lower:]'; }
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
fnmatch () # PATTERN STRING
{
  case "$2" in $1 ) return 0 ;; * ) return 1 ;; esac
}
# Derive: str_globmatch

words_to_lines()
{
  test -n "${1-}" && {
    while test $# -gt 0
    do echo "$1"; shift; done
  } || {
    tr -s '\n ' '\n'
  }
}

# Replace each line separator with space and collapse blank lines and multiple
# spaces.
lines_to_words () # ~ # Collapse lines and spaces
{
  tr -s '\n ' ' '
}

# Quote each line
lines_quoted() # [-|FILE]
{
  test -n "${1-}" || set -- "-"
  cat "$1" |
  sed 's/^.*$/"&"/' "$1"
}

# Quote each line, remove linebreaks. Print one line on stdout.
lines_to_args() # [-|FILE]
{
  lines_quoted "$@" | tr '\n' ' '
}

# replace linesep with given char
linesep()
{
  test -n "${1-}" || set -- " "
  tr '\n' "$1"
}
wordsep()
{
  test -n "${1-}" || set -- " "
  tr ' ' "$1"
}
words_to_unique_lines()
{
  words_to_lines "$@" | sort -u
}
unique_words()
{
  words_to_unique_lines "$@" | lines_to_words
}
reverse_lines()
{
  sed '1!G;h;$!d'
}

## Put each line into lookup table (with Awk), print on first occurence only
#
# To remove duplicate lines in input, without sorting (unlike uniq -u).
remove_dupes () # <line> ... ~
{
  awk '!a[$0]++'
}

remove_dupes_at_col () # ~ <Column>
{
  awk -F "${FS:- }" '!a[$'"$1"']++'
}

## Put each word into lookup table (with Awk), print on first occurence only (1)
#
# Like remove-dupes but act on words from each line, printing every word not
# yet encountered on a line to stdout.
# The input can contain newlines however these are seen as belonging to the last
# word of that line. Adding a space before the newline introduces blank lines in
# the output that separate the word lists into groups of output per line of input.
#
# This remembers each word of every line read.
# Alternatively use unique-words to de-dupe words only per line.
# To *print* one line of output but still remove all dupe words from a stream
# use the remove-dupe-words-lines variant.
remove_dupe_words () # <words> ... ~
{
  awk 'BEGIN { RS = " " } !a[$0]++'
}

## Put each word into lookup table (with Awk), print on first occurence only (2)
#
# Unlike remove-dupe-words this prints one line of output per line of input.
# To remove newlines completely, these need to be removed from input
# as wel or just filtered on output with lines-to-words.
# See remove-dupes and remove-dupe-words for variants.
#
# To only remove words per-line, call for every line.
# See unique-line-words.
unique_words () # <words> ... ~
{
  awk 'BEGIN { RS = " "; ORS = " " } !a[$0]++'
}

## Put each word into lookup table per line, print each first occurence only on that line
#
# A loop calling remove-dupe-words on each line of input.
# The last line must be followed by newline or it is ignored.
unique_line_words ()
{
  while IFS= read -r line
  do printf '%s' "$line" | unique_words; echo
  done
}

# Try to turn given variable names into a more "terse", human readble string seq
var2tags()
{
  echo $(local varname; for varname in $@
  do
    local value="${!varname-}"
    test -n "$value" || continue
    pretty_print_var "$varname" "$value"
  done)
}

# Read meta file and re-format (like mkvid) for shell use
meta2sh()
{
  # NOTE: AWK oneliner to transforms keys for ':' as-is MIME header style
  # file. (no continuations). Quotes values.
  awk '
    /^ *#/ { next }
    /^[A-Za-z_-][A-Za-z0-9_ -]+: / {
      st = index($0,":") ;
      key = substr($0,0,st-1) ;
      gsub(/[^A-Za-z0-9]/,"_",key) ;
      print key "=\"" substr($0,st+2) "\""
    }' "$@"
}
# Sh-Copy: HT:tools/u-s/parts/ht-meta-to-sh.inc.sh vim:ft=bash:

# Read properties file and re-format (like mkvid) for shell use
properties2sh()
{
  # NOTE: AWK oneliner to transforms keys for '=' separated kv list, leaving the
  # value exactly as is.
  awk '{ st = index($0,"=") ;
      key = substr($0,0,st-1) ;
      gsub(/[^a-z0-9]/,"_",key) ;
      print key "=" substr($0,st+1) }' "$@"

  # NOTE: This works but it splits at every equals sign
  #awk 'BEGIN { FS = "=" } ;
  #    { if (NF<2) next;
  #    gsub(/[^a-z0-9]/,"_",$1) ;
  #    print $1"="$2 }' $1
}

# Take some Propertiesfile compatible lines, strip/map the keys prefix and
# reformat them as mkvid for use in shell script export/eval/...
sh_properties () # ~ <File|-> [<Prefix> [<Substitution>]]
{
  test -n "$*" || error "sh-properties expects args: '$*'" 1
  test -e "$1" -o "$1" = "-" || error "sh-properties file '$1'" 1
  # NOTE: Always be carefull about accidentally introducing newlines, will give
  # hard-to-debug syntax failures here or in the local evaluation
  read_nix_style_file $1 | grep '^'"$2" | sed 's/^'"$2"'/'"$3"'/g' | properties2sh -
}
# See also derived build.lib:properties_sh

# A simple string based key-value lookup with some leniency and translation convenience
property () # PROPSFILE PREFIX SUBST KEYS...
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
    while test $# -gt 0
    do
      local __key= __value=
      test -n "$vid" && __key=${vid}$1 || __key=$1
      __value="$(eval printf -- \'%s\' \"\${$__key-}\")"
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
  while test $# -gt 0
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
    } || true
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
# Divide output into X columns of colw=32 wide, filling terminal width
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
  test ${bin_php:-0} -eq 1 && {
    test ${first_word_only:-1} -eq 1 &&
      php -r "echo ucfirst('$1');" ||
      php -r "echo ucwords('$1');"
  } || {
    test ${first_word_only:-1} -eq 1 && {
      echo "$1" | awk '{ print toupper(substr($0, 1, 1)) substr($0, 2) }'
    } || {
      first_word_only=1 str_title "$(echo "$1" | tr ' ' '\n')" | tr '\n' ' '
    }
  }
}

# Remove last n chars from stream at stdin
strip_last_nchars() # Num
{
  rev | cut -c $(( 1 + $1 ))- | rev
}

# Normalize whitespace (replace newlines, tabs, subseq. spaces)
normalize_ws ()
{
  test -n "${1-}" || set -- '\n\t '
  tr -s "$1" ' ' # | sed 's/\ *$//'
}

# Normalize string ws. for one line (stripping trailing newline first)
normalize_ws_str()
{
  tr -d '\n' | normalize_ws "$@"
}

str_slice() # Str start [len] [relend] [end]
{
  test -n "$2" || set -- "$1" 1 "$3" "$4" "$5"
  test -n "$3" && {
    test $3 -gt ${#1} && end=${#1} || end=$3
  } || {
    test -n "$4" && end=$(( ${#1} - $4 ))
  }
  test -n "$end" || end=$5
  #set -- "$1" "$2" "$3" "$4" "$5"
  echo "$1" | cut -c$2-$end
}

str_padd () # ~ LEN [PAD [INPUT [PAD]]]
{
  local padding="${3-}" p1="${2-" "}" p2="${4-""}"
  while [ ${#padding} -lt $1 ]; do padding="${p1}$padding${p2}"; done
  printf '%s' "$padding"
}

str_padd_left () # ~ LEN [PAD [INPUT]]
{
  str_padd "$1" "$2" "$3"
}

str_padd_right () # ~ LEN [PAD [INPUT]]
{
  str_padd "$1" "" "$3" "$2"
}

# Treat text as ASCII with other codes, only count ASCII codes.
# Note this may still contain (parts of?) ANSI escaped codes.
str_ascii_len ()
{
  local str
  str="$(echo "$1" | tr -cd "[:print:]")"
  printf '%i' ${#str}
}

# Remove ANSI as best as possible in a single perl-regex
ansi_clean ()
{
  echo "$1" | perl -e '
while (<>) {
  s/ \e[ #%()*+\-.\/]. |
    \r | # Remove extra carriage returns also
    (?:\e\[|\x9b) [ -?]* [@-~] | # CSI ... Cmd
    (?:\e\]|\x9d) .*? (?:\e\\|[\a\x9c]) | # OSC ... (ST|BEL)
    (?:\e[P^_]|[\x90\x9e\x9f]) .*? (?:\e\\|\x9c) | # (DCS|PM|APC) ... ST
    \e.|[\x80-\x9f] //xg;
    1 while s/[^\b][\b]//g;  # remove all non-backspace followed by backspace
  print;
}'
  return

  #XXX: I'm not sure what the differences are, or how to change the script even @Regex @Perl
  echo "$1" | perl -e '
#!/usr/bin/env perl
## uncolor — remove terminal escape sequences such as color changes
while (<>) {
    s/ \e[ #%()*+\-.\/]. |
       \e\[ [ -?]* [@-~] | # CSI ... Cmd
       \e\] .*? (?:\e\\|[\a\x9c]) | # OSC ... (ST|BEL)
       \e[P^_] .*? (?:\e\\|\x9c) | # (DCS|PM|APC) ... ST
       \e. //xg;
    print;
}'
}

# Clean up ANSI with PS1-type escaping.
# XXX: also strips newline chars
str_sh_clean ()
{
  ansi_clean "$1" | sed -e 's/\(\\\(\[\|\]\)\)//g' | tr -d '\n\r'
}

# Remove tmux formatting.
# var-refs, formatting and expressions.
# XXX: also strips newline chars
str_tmux_clean ()
{
  echo "$1" | sed -E -e 's/#\[[^]]+\]//g'
}

# Get the length of the string counting the number of visible characters
# Strips ANSI codes and delimiter escapes (for Bash PS1) before count
str_len ()
{
  local str str_clean=str_${str_fmt:-"sh"}_clean
  str="$($str_clean "$1")"
  printf '%i' ${#str}
}

# Treat text as ASCII with Bash-escaped ANSI codes.
# Does not correct for double-byte chars ie. unicode, NERD/Powerline font symbols etc.
str_sh_padd () # ~ LEN [INPUT]
{
  str_sh_lpadd "$@"
}

str_sh_lpadd () # ~ LEN [INPUT]
{
  local raw="${2-}" invis newpadd
  invis=$(( ${#raw} - $(str_fmt= sh_len "$raw") ))
  newpadd=$(( $1 + $invis ))
  printf '%'$newpadd's' "$raw"
}

str_sh_rpadd () # ~ LEN [INPUT]
{
  local raw="${2-}" invis newpadd
  invis=$(( ${#raw} - $(str_fmt= str_len "$raw") ))
  newpadd=$(( $1 + $invis ))
  printf '%-'$newpadd's' "$raw"
}

str_sh_padd_ch () # ~ LEN [PAD [INPUT [PAD]]]
{
  str_fmt=sh str_padd_ch "$@"
}

str_tmux_padd_ch () # ~ LEN [PAD [INPUT [PAD]]]
{
  str_fmt=tmux str_padd_ch "$@"
}

str_padd_ch () # [str_fmt=] ~ LEN [PAD [INPUT [PAD]]]
{
  local raw="${3-}" p1="${2-" "}" p2="${4-""}" invis
  invis=$(( ${#raw} - $(str_len "$raw") ))
  while [ $(( ${#raw} - $invis )) -lt $1 ]; do raw="${p1}$raw${p2}"; done
  printf '%s' "$raw"
}

str_quote ()
{
  case "$1" in
    ( "" ) printf '""' ;;
    ( *" "* | *[\[\]\<\>$]* )
      case "$1" in
          ( *"'"* ) printf '"%s"' "$1" ;;
          ( * ) printf "'%s'" "$1" ;;
      esac ;;
    ( * ) printf '%s' "$1" ;;
  esac
}

str_quote_var ()
{
  echo "${1%%=*}=$(str_quote "${1#*=}")"
}

str_concat () # ~ <String-1> <String-2> <String-Sep>
{
  test $# -ge 2 -a $# -le 3 || return 64
  test $# -gt 2 || set -- "$@" " "
  test -n "$1" && {
    test -n "$2" && {
        echo "$1$3$2"
    } || {
        echo "$1"
    }
  } || {
    test -z "$2" || echo "$2"
  }
}

# Center ellipsize: put ellipsis in middle
str_c_ellipsize () # ~ <String> [<Maxlength> [<Ellipsis>]]
{
  local str=${1:?} maxlen=${2:-70} ellipsis=${3:-'…'} l{1,2,3,4}
  l1=${#str} l2=${#ellipsis}
  [[ $maxlen -ge $l1 ]] &&
    echo "$str" || {
      l3=$(( ( maxlen / 2 ) - 1 ))
      l4=$(( l1 - ( maxlen / 2 ) - l2 ))
      echo "${str:0:$l3}$ellipsis${str:$l4}"
    }
}

# Ellipsize: put ellipsis at left, center or right if string exceeds maxlength
str_ellipsize () # ~ <lcr> <String> [<Maxlength> [<Ellipsis>]]
{
  local switch=${1:-1} str=${2:?} maxlen=${3:-70} ellipsis=${4:-'…'} l{1,2,3}
  l1=${#str} l2=${#ellipsis}
  [[ $maxlen -ge $l1 ]] &&
    echo "$str" ||
    case "$switch" in
      -1 )
          l3=$(( l1 - maxlen + l2 ))
          echo "$ellipsis${str:$l3}"
        ;;
      0 ) TODO "centered ellipsize or l+r ellipsis is something other than centered ellipsis"
        ;;
      1 )
          l3=$(( maxlen - l2 ))
          echo "${str:0:$l3}$ellipsis"
    esac
}

str_ellipsize_l ()
{
  str_ellipsize -1 "$@"
}

str_ellipsize_c ()
{
  str_ellipsize 0 "$@"
}

str_ellipsize_r ()
{
  str_ellipsize 1 "$@"
}

# Convert As-is style formatted file to double-quoted variable declarations
asis_to_vars () # ~ <File|Awk-argv> # Filter to rewrite .attributes to simple shell variables
{
  awk '/^#/ { next; }
  /^.*: / {
    st = index($0,":") ;
    key = substr($0,0,st-1) ;
    gsub(/[^A-Za-z0-9]/,"_",key) ;
    print toupper(key) "=\"" substr($0,st+2) "\""
  }' "$@"
}
# Id: asis-to-vars


# Error unless non-empty and true-ish value
trueish () # ~ <String>
{
  test $# -eq 1 -a -n "${1-}" || return
  case "${1,,}" in ( true|on|y|yes|1 ) return 0 ;;
    * ) return 1;
  esac
}
# Id: sh-trueish

#
