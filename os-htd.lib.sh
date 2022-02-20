#!/bin/sh
# Htd ctx cleanup for OS wip: files, paths.


os_htd_lib_load()
{
  test -n "${uname-}" || uname="$(uname -s)"
  test -n "${os-}" || os="$(uname -s)"
}

os_htd_lib_init()
{
  test "${os_htd_lib_init-}" = "0" || {
    test -n "$LOG" -a \( -x "$LOG" -o "$(type -t "$LOG")" = "function" \) \
      && os_htd_lib_log="$LOG" || os_htd_lib_log="$INIT_LOG"
    test -n "$os_htd_lib_log" || return 108
    $os_htd_lib_log debug "" "Initialized os-htd.lib" "$0"
  }
}


short()
{
  test -n "$1" || set -- "$PWD"
  # XXX maybe replace python script. Only replaces home
  $HOME/bin/short-pwd.py -1 "$1"
}

# Use `stat` to get birth time (in epoch seconds)
filebtime() # File
{
  local flags=- ; file_stat_flags
  case "$uname" in
    Darwin )
        trueish "${file_names-}" && pat='%N %B' || pat='%B'
        stat -f "$pat" $flags "$1" || return 1
      ;;
    Linux )
        # XXX: %N is deref-file
        trueish "${file_names-}" && pat='%N %W' || pat='%W'
        stat -c "$pat" $flags "$1" || return 1
      ;;
    * ) error "filebtime: $1?" 1 ;;
  esac
}



# Split expression type from argument and set envs expr_/type_
foreach_match_setexpr () # [Type:]Expression
{
  test -n "$1" || set -- '*'
  expr_="$1"
  fnmatch "*:*" "$expr_" && {
    type_="$(echo "$expr_" | cut -c1)"
    expr_="$(echo "$expr_" | sed 's/^[^:]*://')"
  } || {
    type_=g
  }
  std_info "Mode: $type_, Expression: '$expr_'"
}

# Execute act/no-act based on expression match, function/command or shell statement
# Types are [g]lob-match, grep-[r]egex, local-cmd e[x]pression or [e]val expression.
# Subjects (stdin lines) may be provided as arguments instead, and to do
# additional prefix/suffix addition on subjects (and only there).
foreach_match () # [type_=(grxe) expr_= act=echo no_act=/dev/null p= s=] [Subject...]
{
  test "$1" != "-" || shift
  test -n "$expr_" || { type_=g expr_='*'; }
  test -n "$act" || act="echo"
  test -n "$no_act" || no_act=/dev/null
  # Read arguments or lines from stdin
  { test -n "$*" && { for a in "$@"; do printf -- '%s\n' "$a"; done; } || cat -
  } | while read -r _S ; do S="$p$_S$s"
  # NOTE: Allow inline comments or processing instructions passthrough
  fnmatch "#*" "$S" && { echo "$S" ; continue; }
  # Execute, echo on success or do nothing except print on stdout in debug-type
  case "$type_" in
      g ) fnmatch "$expr_" "$S" ;;
      r ) echo "$S" | grep -q "$expr_" ;;
      x ) $expr_ "$S" ;;
      e ) eval "$expr_" ;;
      * ) error "foreach-expr-type? '$type_'" 1 ;;
  esac && $act "$S" || $no_act "$S" ; done
}

# Read single multipath to one path per line
split_multipath()
{
  local root=
  { test -n "${1-}" && echo "$@" || cat - ; } \
     | grep -Ev '^(#.*|\s*)$' \
     | sed 's/\([^\.]\)\/\.\./\1\
../g' \
     | grep -v '^\.[\.\/]*$' \
     | while read -r rel_leaf
  do
    echo $rel_leaf | grep -q '^\.\.\/' && {
      normalize $root/$rel_leaf
    } || {
      root=$rel_leaf
      normalize $rel_leaf
    }
  done
  test -n "$root" || error "No root found" 1
}

# Go to dir and set OLDPWD, but only if not already there
#go_to_dir()
#{
#  test -n "$1" || set -- "."
#  test "$1" = "." || cd "$1"
#  # -o "$(pwd -P)" = "$(cd "$1" && pwd -P)" || cd $1
#}


# Resolve all symlinks in subtree, return a list with targets
get_targets()
{
  test -n "$1" || set -- /srv
  # Assume
  find $1 -type l | while read -r link
  do
    test -e "$link" || continue
    target=$(readlink $link)
    normalize_relative $(dirname $link)/$target
  done | sort -u
}

xsed_rewrite()
{
  case "$uname" in
    Darwin ) sed -i.applyBack "$@";;
    Linux ) sed -i "$@";;
  esac
}

# FIXME: can Bourne Sh do pushd/popd in a function?
#cmd_exists pushd || {
#pushd()
#{
#  tmp=/tmp/pushd-$$
#  echo "pushd \$\$=$$ $@"
#  echo "$1" >>$tmp
#  cd $1
#}
#popd()
#{
#  tmp=/tmp/pushd-$$
#  echo "popd \$\$=$$ $@"
#  tail -n 1 $tmp
#  cd $(truncate_trailing_lines $tmp 1)
#}
#}
#
#pushd_cwdir()
#{
#  test -n "$CWDIR" -a "$CWDIR" != "$PWD" && {
#    echo "pushd $CWDIR" "$PWD"
#    pushd $WDIR
#  } || set --
#}
#
#popd_cwdir()
#{
#  test -n "$CWDIR" -a "$CWDIR" = "$PWD" && {
#    echo "popd $CWDIR" "$PWD"
#    test "$(popd)" = "$CWDIR"
#  } || set --
#}

# strip-trailing-dash
strip_trail()
{
  fnmatch "*/" "$1" && {
    echo "$1" | sed 's/\/$//'
  } ||
    echo "$1"
}

# if not exists, create directories and touch file for each given path arg
# to print only existing files see filter_files
assert_files()
{
  for fn in $@
  do
    test -n "$fn" || continue
    test -e $fn || {
      test -z "$(dirname $fn)" || mkdir -vp $(dirname $fn)
      touch $fn
    }
  done
}

lock_files()
{
  local id=$1
  shift
  std_info "Reserving resources for session $id ($*)"
  for f in $@
  do
    test -e "$f.lock" && {
      lock="$(head -n 1 $f.lock | awk '{print $1}')"
      test "$lock" = "$id" && echo $f ||
        warn "Ignored existing lock $lock for $f"
    } || {
      assert_files $f
      echo $f && echo $id > $f.lock
    }
  done
}

unlock_files()
{
  local id=$1 lock=
  shift
  std_info "Releasing resources from session $id ($*)"
  for f in $@
  do
    test -e "$f.lock" && {
      lock="$(head -n 1 $f.lock | awk '{print $1}')"
      test "$lock" = "$id" && {
        rm $f.lock
        test -e "$f" || continue
        echo $f
      }
    } || continue
  done
}

verify_lock()
{
  local id=$1
  shift
  for f in $@
  do
    test -e "$f.lock" || return 2
    test "$(head -n 1 $f.lock | awk '{print $1}')" = "$id" || return 1
  done
}


mkrlink()
{
  test $# -gt 1 -a -n "$1" || return
  # TODO: find shortest relative path
  ln -vs "$(basename "$1")" "${2:-"$PWD/"}"
}


filter_dir ()
{
  test -d "$1" && echo "$1"
}

filter_dirs ()
{
  act=filter_dir s= p= foreach_do "$@"
}

filter_file ()
{
  test -f "$1" && echo "$1"
}

filter_files ()
{
  act=filter_file s= p= foreach_do "$@"
}

disk_usage()
{
  test -n "$1" || set -- "." "$2"
  test -n "$2" || set -- "$1" "h"
  du -$2s $1 | awk '{print $1}'
}

isemptydir()
{
  test -d "$1" -a "$(echo $1/*)" = "$1/*"
}

isnonemptydir()
{
  test -d "$1" -a "$(echo $1/*)" != "$1/*"
}

find_one () # ~ DIR NAME
{
  test $# -eq 2 || return 64
  find_num "$@" 1
}

find_num () # ~ DIR NAME [NUM]
{
  test -n "${1-}" -a -n "${2-}" || error "find-num '$*'" 1
  test -n "${3-}" || set -- "$@" 1
  local c=0
  find "$1" -iname "$2" | while read -r path
  do
    c=$(( $c + 1 ))
    test $c -le $3 || return 1
    echo "$path"
  done
}

find_broken_symlinks () # ~ DIR
{
  test $# -gt 0 || set -- .
  test $# -eq 1 || return 64
  find "$1" -type l ! -exec test -e {} \; -print
}

find_filter_broken_symlinks () # ~ DIR
{
  test $# -gt 0 || set -- .
  test $# -eq 1 || return 64
  find "$1" -type l -exec test -e {} \; -print
}

abbrev_rename()
{
  while read -r oldpath junk newpath
  do
    local idx=1
    while test "$(echo "$oldpath" | cut -c 1-$idx )" = "$(echo "$newpath" | cut -c 1-$idx )"
    do
        idx=$(( $idx + 1 ))
    done
    local end=$(( $idx - 1 ))
    echo "Backed up path: $( echo $oldpath | cut -c 1-$end 2>/dev/null){$(echo $oldpath | cut -c $idx- 2>/dev/null) => $(echo $newpath | cut -c $idx- 2>/dev/null)}"
  done
}

# Add number to file, provide extension to split basename before adding suffix
number_file() # [action=mv] Name [Ext]
{
  local dir=$(dirname "$1") cnt=1 base=$(basename "$1")

  while test -e "$dir/$base-$cnt${2-}"
  do
    cnt=$(( $cnt + 1 ))
  done
  dest="$dir/$base-$cnt${2-}"

  test -n "$action" || action="mv"
  { $action -v "$1" "$dest" || return $?; } | abbrev_rename
}

# make numbered copy, see number-file
backup_file() # [action=mv] Name [Ext]
{
  action="cp" number_file "$1"
}

# rename to numbered file, see number-file
rotate_file() # [action=mv] Name [Ext]
{
  test -s "$1" || return
  action="mv" number_file "$1"
}

wherefrom()
{
  lib_load ${os} || return
  ${os,,}_wherefrom "$@"
}

sameas()
{
  test -f "$1" -a -f "$2" || error "sameas: two file name expected: $*" 1
  test $(stat -f "%i" "$1") -eq $(stat -f "%i" "$2")
}

filesizesum()
{
  sum=0
  while read -r file
  do
      sum=$(( $sum + $(filesize "$file" | tr -d '\n' ) ))
  done
  echo $sum
}

# Read pairs and rsync. Env dry-run=0 to execute, rsync-a to override 'vaL' flags.
rsync_pairs()
{
  test -n "$rsync_a" || rsync_a=-vaL
  falseish "$dry_run" || rsync_a=${rsync_a}n

  while read -r src dest
  do
    mkdir -p "$(dirname "$dest")"
    rsync $rsync_a "$src" "$dest" && {
        falseish "$dry_run" &&
        note "Synced <$src> to <$dest>" ||
        note "**dry run ** Synced <$src> to <$dest>"
    } || {
        error "Syncing <$src> to <$dest>"
        return 1
    }
  done
}

linux_uptime()
{
  cut -d' ' -f1 /proc/uptime
}

linux_boottime()
{
  echo $(( $($gdate +"%s" ) + $(linux_uptime) ))
}

 # Go over pathnames, and compare with file. Return non-zero on first file with differences.
diff_files() # File-Path Path-Name...
{
  #param 'FILE OTHER...'
  # TODO: group 'OS:Diff'
  #group 'OS-Htd:Diff'
  test $# -gt 1 -a -f "$1" || return 98

  local from="$1"
  shift
  for path in "$@"
  do
    test -f "$path" || path="$path/$1"
    diff -bqr "$1" "$path" && continue
  done
}
# Sh-Copy: HT:tools/u-s/parts/diff-files.inc.sh vim:ft=bash:

symlink_assert () # <Symlink-Path> <Target>
{
  test -d "$1" -a ! -h "$1" &&
      set -- "$1" "$2" "$1/$(basename -- "$2")" || set -- "$1" "$2" "$1"
  test -h "$3" && {
    local target="$(readlink "$3")"
    test "$target" = "$2" && return
    rm "$3"
  }
  local v=; test $verbosity -lt 7 || v=v
  ln -s$v "$2" "$3"
}

# Sync: U-S:src/sh/lib/os.lib.sh
