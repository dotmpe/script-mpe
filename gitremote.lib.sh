#!/bin/sh


gitremote_lib_load()
{
  test -n "$GIT_REMOTE_CONF" ||
      export GIT_REMOTE_CONF"=$UCONFDIR/etc/git/remotes"
}

gitremote_init_uconf()
{
  C=$GIT_REMOTE_CONF/$1.sh

  . $C || return

  test -n "$remote_dir" || {
    info "Using $NS_NAME for $1 remote vendor path"
    remote_dir=$NS_NAME
  }

  note "GIT remote '$1' loaded"
}

# List remote-dirs XXX: for user/domain
gitremote_list_for_ns()
{
  grep -l NS_NAME=$1 $GIT_REMOTE_CONF/*.sh
}

# List
gitremote_list_for_hostinfo()
{
  grep -lF "remote_hostinfo=$remote_hostinfo" $GIT_REMOTE_CONF/*.sh
}

# TODO: Retrieve hostname for remote and check wether online
gitremote_ping() #
{
  remote_hostinfo=
  remote_host=
}

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

gitremote_stat()
{
  for rt in github dotmpe wtwta-1
  do
    repos=$GIT_REMOTE_CONF/$rt.list
    { test -e $repos && newer_than $repos $_1DAY
    } || htd git-remote list $rt > $repos
    note "$rt: $(count_lines "$repos")"
  done
}

gitremote_url()
{
  test -n "$2" || error "repo name expected" 1
  gitremote_init_uconf "$@"
  #git_url="ssh://$remote_host/~$remote_user/$remote_dir/$1.git"
  echo "$remote_hostinfo:$remote_dir/$2"
}

gitremote_info()
{
  test -n "$1" || error "remote name required" 1
  gitremote_init_uconf "$@"
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

gitremote_sh_env()
{
  test -n "$2" || error "repo name expected" 1
  test -n "$3" || set -- "$1" "$2" remote_
  gitremote_info "$1" "$2" | sh_properties - 'remote\.'"$1"'\.' "$3"
}

gitremote_names()
{
  exts=.sh basenames $GIT_REMOTE_CONF/*.sh
}

gitremote_list()
{
  test $# -lt 3 || error "surplus arguments '$3'" 1
  test -n "$2" || set -- "$1" "*"
  gitremote_init_uconf "$@"
  test -n "$remote_dir" && {
    filter="$(compile_glob "$2")"
    ssh_cmd="cd $remote_dir && ls | grep '^$filter\\.git$' | sed 's/\\.git$//g' "
    ssh $ssh_opts $remote_hostinfo "$ssh_cmd"
  } ||
     error "No SSH or list API for GIT remote '$1'" 1
}

gitremote_github_list()
{
  test -n "$1" || set -- "$NS_NAME"
  gitremote_init_uconf "$1"
  test "github" = "$vendor" -o "github.com" = "$domain" ||
      error "Unhandled vendor '$vendor' <$domain>" 1

  test -n "$remote_user" || remote_user=$NS_NAME
  test -n "$remote_list" || remote_list=$1.list
  confd=$GIT_REMOTE_CONF
  cache=$confd/$1.json

  { test -e $cache && newer_than $cache $_1DAY
  } && stderr ok "File UCONFDIR:etc/git/remotes/$1.json" || {

    URL="https://api.github.com/users/$remote_user/repos"
    per_page=100
    htd_resolve_paged_json $URL per_page page > $cache || return $?
  }

  test -e $confd/$remote_list -a $confd/$remote_list -nt $cache && {

    cat $confd/$remote_list || return $?
  } || {
    jq -r 'to_entries[] as $r | $r.value.full_name' $cache | tee $confd/$remote_list
  }
  wc -l $confd/$remote_list
}
