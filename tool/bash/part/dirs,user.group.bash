user_dirs_pre=User.Dirs
user_dirs_grp=( user-config user-grep )
declare -gA \
user_dirs_als=(
  )
declare -gA \
user_dirs_ssc=(
  [grep-dirs]=\
'  local _grep_match=${1:?} _grep_fnmatch=${2:-*} _dirsgrep _grep_opts
  [[ $# -gt 2 ]] && shift 2 || set -- ${user_dev[@]}
  # FIXME: look at term cap and user conf for color/term/filter settings
  _grep_opts=( -sI --color=always )
  _dirsgrep=( -r --include "$_grep_fnmatch" "$_grep_match" . )
  User.Grep.at-basedirs _dirsgrep "$@"'
  [grep-dirs-all]=\
'  local _grep_match=${1:?} _grep_fnmatch=${2:-*} _dirsgrep _grep_opts
  [[ $# -gt 2 ]] && shift 2 || set -- ${user_basedirs[@]}
  # FIXME: look at term cap and user conf for color/term/filter settings
  _grep_opts=( -sI --color=always )
  _dirsgrep=( -r --include "$_grep_fnmatch" "$_grep_match" . )
  User.Grep.at-basedirs _dirsgrep "$@"'
)
declare -gA \
user_dirs_hooks=(
  [define]=\
'User.Config.expand-keymatch-filterhandle  user_dirs     basedir.user-dirs   test -d
User.Config.expand-keymatch-filterhandle   user_dev      basedir.uc-dev      test -d
User.Config.expand-keymatch-filterhandle   user_basedirs basedir."*"         test -d'
  [init]=\
'  user_config[basedir.uc-dev]="~/{.conf,bin,.l/c,htdocs,project/{user-conf,user-scripts{,-incubator}}}"
  user_config[basedir.user-dirs]=~/{Desktop,Documents,Downloads,Pictures,Videos,Music}'
)
