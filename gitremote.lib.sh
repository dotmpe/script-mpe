#!/bin/sh

### Manage GIT remote metadata in simple shell config files


gitremote_lib__load()
{
  true "${GIT_REMOTE_CONF:=${UCONF?}/etc/git/remotes}"
}

gitremote_lib__init()
{
  export GIT_REMOTE_CONF
  true "${GITREMOTE_MAX_AGE:=${_1DAY:?}}"
}


gitremote_clearenv () # [gitremote] ~ # Set all empty gitremote env vars
{
  domain= vendor= gitremote= remote_id= remote_alias= remote_ns=
  remote_type= remote_dir= remote_hostinfo=
  remote_enabled= remote_cache= remote_items=
}

gitremote_exists () # [gitremote] ~ [<Remote-Id>] # Check if config for gitremote exists.
{
  test -e "$GIT_REMOTE_CONF/${1:-${remote_id:?}}.sh"
}

# XXX: unused?
# Get host for remote repository. NOTE SSH config alias to hide user/host
# details behind aliases.
gitremote_hostinfo() # Remote-Name or Remote-Id
{
  # Remote-Name test before Id test
  remote_url="$(git config remote.$1.url)"
  test -n "$remote_url" && {
    remote_hostinfo="$(printf "$remote_url" | cut -f1 -d':')"
    test -n "$remote_hostinfo" || {
        warn "No hostinfo on '$1' URL"
        return 0 # localhost/mount
    }
    remotedir_conf="$(grep -lF "remote_hostinfo=$remote_hostinfo" \
          $GIT_REMOTE_CONF/*.sh)"
    remote_id="$(basename "$remotedir_conf" .sh)"
    remote_name="$1"

  } || {

    remote_id="$1"
    test -e $GIT_REMOTE_CONF/$remote_id.sh || error "No remote-id" 1
    . $GIT_REMOTE_CONF/$remote_id.sh
  }

  test -z "$remote_hostinfo" -o "$remote_hostinfo" = "$hostname" && {
    echo "$hostname"
  } || {
    echo "$remote_hostinfo"
  }
}

# Get environment indicated for by <Remote-Id> argument or env. Unless remote-id
# env exists, the env will be cleared and reset to settings from config.
gitremote_getenv () # [remote_id] ~ [<Remote-Id>] # Get env for Remote-Id
{
  test -n "${remote_id:-}" || gitremote_load "$@" || return
}

gitremote_getlist () # (gitremote) ~
{
  set -- "${remote_id:?}"
  type gitremote_list_${remote_type:-$1} >/dev/null 2>&1 && {

    gitremote_list_${remote_type:-$1} || return
  } ||
       error "No list API for GIT remote '$1'" 1
}

gitremote_getconfig () # ~ (gitremote) ~
{
  set -- "${remote_id:?}"
  gitremote=$GIT_REMOTE_CONF/$1.sh
  test ! -L "$gitremote" || {
    local rcp=$(realpath "$GIT_REMOTE_CONF")
    gitremote=$(realpath $gitremote)
    test "${gitremote:0:${#rcp}}" = "$rcp" || return 13
    remote_id=$(basename $gitremote .sh)
    remote_alias="$1"
  }
}

# List UCONF:git:remote dirs XXX: for user/domain
gitremote_grep_for_ns()
{
  grep -l NS_NAME=$1 $GIT_REMOTE_CONF/*.sh
}

gitremote_grep_for_hostinfo()
{
  grep -lF "remote_hostinfo=$remote_hostinfo" $GIT_REMOTE_CONF/*.sh
}

gitremote_haslist () # (gitremote) ~
{
  test -n "${remote_items:-}" || {
    set -- "${remote_id:?}"
    type gitremote_list_${remote_type:-$1} >/dev/null 2>&1
  }
}

gitremote_info() # ~ [gitremote] ~ [<Remote-id>]
{
  gitremote_getenv "$1" || { error "remote name required" 1 ; return ; }

  test -n "$2" && {
    echo "remote.$1.git.url=$remote_hostinfo:$remote_dir/$2"
    echo "remote.$1.scp.url=$remote_hostinfo:$remote_dir/$2.git"
    echo "remote.$1.repo.dir=$remote_dir/$2.git"
    echo "remote.$1.hostinfo=$remote_hostinfo"
  } || {
    echo "remote.$1.repo.dir=$remote_dir"
    echo "remote.$1.hostinfo=$remote_hostinfo"
  }
}

gitremote_isalias () # ~ [gitremote] ~ [<Remote-Id>]
{
  test $# -eq 1 || set -- "${remote_id:?}"
  test -L "${GIT_REMOTE_CONF:?}/${1:?}.sh"
}

gitremote_lenvkeys ()
{
  type gitremote_clearenv | tail -n +4 | head -n -1
}

# Reset gitremote environment by loading config using <Remote-Id> argument.
gitremote_load () # ~ <Remote-Id>
{
  remote_id= gitremote_exists "$@" || return
  gitremote_clearenv && remote_id=$1
  gitremote_getconfig || return
  . $gitremote || {
    error "Failure loading '$1' config" 1 || return
  }
  true "${remote_id:="$1"}"
  #test -n "$remote_dir" || {
  #  std_info "Using $NS_NAME for $1 remote vendor path"
  #  remote_dir=$NS_NAME
  #}
  set -- "$1" "$GIT_REMOTE_CONF/$1"
  test -z "$remote_dir" || true "${remote_type:=dir}"
  test -e "${remote_items:=$2.list}" -a -z "${remote_type:-}" && {
    remote_type=dummy
  }
  test "$remote_type" = "dummy" && {
    test -z "$remote_dir" -a -z "$remote_cache" || {
        error "in config" 1
    }
  } || true "${remote_cache:=$2.cache.list}"
  note "GIT remote '$1' loaded"
}

# Take the manually compiled or cached repo list for remote, and grep for
# project namespace and names.
#
gitremote_list () # [gitremote] ~ [<Remote-Id> [<Project-Name-Glob>]]
{
  test $# -lt 3 || error "surplus arguments '$3'" 1
  test -z "${1:-}" || gitremote_getenv "$1" || return
  test -n "${1:-}" || set -- "$remote_id" "${2:-}"
  test -n "${2:-}" || set -- "$1" "*"

  test "$remote_type" = "dummy" \
      && set -- "$1" "$2" "$remote_items" \
      || set -- "$1" "$2" "$remote_cache"

  grep -E "^$(compile_glob "$2")$" "$3"
}

gitremote_list_dir () # [gitremote] ~ [<Remote-id> [<Hostinfo> [<Dir> [<Project-Glob>]]]]
{
  test $# -le 4 || return 64
  test $# -ge 3 || set -- "${remote_id:?}" "${remote_hostinfo:?}" "${remote_dir:?}"
  local filter ssh_cmd ns ns_re
  test ${remote_tree:-0} -eq 1 && {
    filter=
    ssh_cmd="cd $3 && find . -type d -iname '${4:-*}.git' -print -prune"
  } || {
    filter="$(compile_glob "${4:-*}")"
    ssh_cmd="cd $3 && ls | grep -E '^$filter\\.git$'"
  }
  # There is no argument to set NS, it defaults to remote-dir if remote-ns and
  # NS-Name are unset or empty, or any of the latter in that order.

  ns=${remote_ns:-${NS_NAME:-$3}}
  std_info "Contacting remote $1:$ns via '$2:$3'..."
  ns_re=$(match_grep "$ns")
  ssh ${ssh_opts:-} $2 "$ssh_cmd" | sed -e 's/\\.git$//' -e 's/^/'"$ns_re"'\//'
}

gitremote_list_github () # ~ [gitremote] ~ [<Remote-id>]
{
  test -n "${1:-}" || set -- "${NS_NAME:?}"

  gitremote_getenv "$1" || { error "remote name required" 1 ; return ; }
  test "github" = "$vendor" -o "github.com" = "$domain" ||
      error "Unhandled vendor '$vendor' <$domain>" 1

  true "${remote_user:=$NS_NAME:?}"
  true "${remote_list:=$1.list}"

  local confd cache
  confd=${GIT_REMOTE_CONF:?}
  cache=$confd/$1.json
  { test -e $cache && newer_than $cache ${GITREMOTE_MAX_AGE:?}
  } && stderr ok "File UCONF:etc/git/remotes/$1.json" || {

    URL="https://api.github.com/users/$remote_user/repos"
    per_page=100
    htd_resolve_paged_json $URL per_page page > $cache || return $?
  }

  test -e $confd/$remote_list -a $confd/$remote_list -nt $cache && {

    cat $confd/$remote_list || return $?
  } || {
    jq -r 'to_entries[] as $r | $r.value.full_name' $cache | tee $confd/$remote_list
  }
}

# Prints all name Ids without tags, but including aliases.
gitremote_nameids () # ~ [<Glob>] # List remote Id names from config
{
  gitremote_names "$@" | cut -d '-' -f 1 | remove_dupes
}

# List all names including base Ids and those with tags. Names with leading '_'
# are ignored.
gitremote_names () # ~ [<Glob>] # List all remote names from config, include name Ids with tags
{
  exts=.sh basenames $GIT_REMOTE_CONF/${1:-*}.sh | grep -v '^_'
}

# TODO: Retrieve hostname for remote and check wether online
gitremote_ping() #
{
  remote_hostinfo=
  remote_host=
}

gitremote_sh_env()
{
  test -n "$2" || error "repo name expected" 1
  test -n "$3" || set -- "$1" "$2" remote_
  gitremote_info "$1" "$2" | sh_properties - 'remote\.'"$1"'\.' "$3"
}

gitremote_update () # ~ [gitremote] ~ [<Remote-id>]
{
  gitremote_getenv "$@" || { error "remote name required" 1 ; return ; }
  test "${remote_type:-${1:-}}" != "dummy" || return
  gitremote_getlist > "${remote_cache:?}"
}

gitremote_url () # ~ [gitremote] ~ [<Remote-id>] <Repo-Name>
{
  gitremote_getenv "$1" || { error "remote name required" 1; return; }
  test -n "$2" || { error "repo name expected" 1; return; }
  #git_url="ssh://$remote_host/~$remote_user/$remote_dir/$1.git"
  echo "$remote_hostinfo:$remote_dir/$2"
}

# If remote can list projects, this determines wether the cached list is
# up-to-date or stale.
gitremote_stat () # (remote_id) ~
{
  # Set filepath or abort shell on missing vars.
  set -- "${GIT_REMOTE_CONF:?}/${remote_id:?}.cache.list"
  # Set list env so caller can use it.
  test ${gr_lv:-0} -eq 0 || remote_list=$1
  # Test wether cache is new enough, and if we don't do manual updates also if
  # config was changed after cache was updated.
  test -e $1 && newer_than $1 ${GITREMOTE_MAX_AGE:?} && {
      test ${gr_m:-0} -eq 1 || newer_than $1 $GIT_REMOTE_CONF/$remote_id.sh
    }
}

# To stat files we don't need to source each config but can simply check
# for the file names.
gitremotes_stat () # ~ [<Remote-Id...>]
{
  test $# -gt 0 || set -- $(gitremote_names)
  local remote_id remote_list stat $(gitremote_lenvkeys)
  for remote_id
  do
    test "$remote_type" = "dummy" \
        && remote_list=$remote_items \
        || {
          remote_list=$remote_cache
          gr_lv=1 gitremote_stat || stat=$?
        }
    test -e "$remote_list" && {
      test -s "$remote_list" \
        && note "$remote_id: $(count_lines "$remote_list")" \
        || warn "$remote_id: (empty)"

    } || warn "$remote_id: (missing-list)"
  done
  return ${stat:-0}
}

gitremotes_update () # ~ [<Remote-Id...>]
{
  test $# -gt 0 || set -- $(gitremote_nameids)
  local r $(gitremote_lenvkeys)
  for remote_id
  do
    gitremote_stat && {
      notice "Cached '$remote_id' list up-to-date"
      continue
    }
    #gitremote_update || r=$?
    gitremote_getlist
    gitremote_clearenv
  done
}

#
