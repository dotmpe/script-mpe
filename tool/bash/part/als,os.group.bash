os_als_pre=OS.Alias
os_als_cnk=5c8b2bc9
os_als_fun=()

declare -gA \
os_als_als=(

  [fname]='find . -iname'
  [fnfind]='find . -iname'

  [fpath]='find . -ipath'

  [fName]='find . -name'
  [fPath]='find . -path'

  # [2017-04-16] find executables on OSX with BSD/Darwins 2011 find w/o -executable flag support
  #[find-exec]='find . -type f -exec test -x {} \; -a -print'

  [fnexe]='find . -executable -iname'
)

declare -gA \
os_als_ssc=(

  [find.largest-file]='find "${1:-$PWD}" -type f -printf "%s %p\\n" | sort -rn | head ${@:2}'
  [find.larger-than]='local min_size=${1:-15M} find_filter
  find_filter=( -not -iname .git -a -type f )
  find "${2:-$PWD}" "${find_filter[@]}" -a -size +${min_size} -a -printf "%s %p\\n" |
    sort -rn | head ${@:3}'
  [find.newest-file]='find "${1:-$PWD}" -type f -printf "%T+ %p\\n" | sort -n | tail ${@:2}'
  [find.oldest-file]='find "${1:-$PWD}" -type f -printf "%T+ %p\\n" | sort -rn | head ${@:2}'
  [find.symlinks]='find . -xtype l'
  # FIXME:
  [find.symlink-targets]='find . -xtype l -printf "%p %l\\n" '
  #[find-symlink-fnmatch]=''
  [find.symlinks.broken]='find . -type l \( -exec test -e {} \; -a -prune -o -print \)'

  [fnames]='local x; for x; do fname "$x"; done'
  [fzname]='fname "*$1*"'
  [fznames]='local x; for x; do fname "*$x*"; done'

)
