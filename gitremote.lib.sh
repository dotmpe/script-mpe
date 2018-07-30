#!/bin/sh

gitremote_lib_load()
{
  true
}

gitremote_init_uconf()
{
  C=$UCONFDIR/git/remote-dirs/$1.sh

  test -e "$C" || { local vendor=
    info "No config for '$1'"

    # See for specific account per vendor
    gitremote_list_for_ns $1 | while read remote
    do
      test -h "$remote" && continue # ignore account aliases
      get_property "$remote" VENDOR
      vendor="$(get_property "$remote" VENDOR)" || continue
      test -n "$vendor" || continue
      #set -- "$1" "$1" "$(basename $remote .sh)" "$vendor"
      stderr ok "account $1 for vendor $3 at file $2"

    done

    # FIXME
    error "no account $1 for vendor $3 at file $2" 1

    test -n "$3" -a -n "$2" &&
        stderr ok "account $1 for vendor $3 at $2" ||
        error "Missing any remote-dir file for ns-name '$1'" 1
    C=$UCONFDIR/git/remote-dirs/$2.sh
    #set -- "$1" "$(basename $C .sh)" "$vendor" "$NS_NAME"
  }

  . $C

  test -n "$2" || {

    test -n "$vendor" || error "Vendor for remote now required" 1
    test -n "$NS_NAME" || error "Expected NS_NAME still.. really" 1
  }

  #|| error "Missing remote GIT dir script" 1
  test -n "$remote_dir" || {
    info "Using $NS_NAME for $1 remote vendor path"
     remote_dir=$NS_NAME
  }

  note "Cmd initialized '$*'"
}

# List remote-dirs XXX: for user/domain
gitremote_list_for_ns()
{
  grep -l NS_NAME=$1 $UCONFDIR/git/remote-dirs/*.sh
}

# List
gitremote_list_for_hostinfo()
{
  grep -lF "remote_hostinfo=$remote_hostinfo" $UCONFDIR/git/remote-dirs/*.sh
}

# Retrieve hostname for remote and check wether online
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
          $UCONFDIR/git/remote-dirs/*.sh)"
    remote_id="$(basename "$remotedir_conf" .sh)"
    remote_name="$1"

  } || {

    remote_id="$1"
    test -e $UCONFDIR/git/remote-dirs/$remote_id.sh || error "No remote-id" 1
    . $UCONFDIR/git/remote-dirs/$remote_id.sh
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
    repos=$UCONFDIR/git/remote-dirs/$rt.list
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

gitremote_list()
{
  test -z "$2" || error "no filter '$2'" 1
  gitremote_init_uconf "$@"
  test -n "$remote_dir" && {
    ssh_cmd="cd $remote_dir && ls | grep '.*.git$' | sed 's/\.git$//g' "
    ssh $ssh_opts $remote_hostinfo "$ssh_cmd"
  } ||
     error "No SSH or list API for GIT remote '$1'" 1
}

gitremote_github_list()
{
  #test -n "$1" || error "vendor-name required" 1
  #test -n "$2" || error "remote-name required" 1
  #test -n "$3" || error "ns-name required" 1
  #gitremote_init_uconf "$@"

  test -n "$remote_list" || remote_list=$2.list
  confd=$UCONFDIR/git/remote-dirs
  repos=$UCONFDIR/git/remote-dirs/$2.json

  { test -e $repos && newer_than $repos $_1DAY
  } && stderr ok "File UCONFDIR:git/remote-dirs/$2.json" || {

    URL="https://api.github.com/users/$3/repos"
    per_page=100
    htd_resolve_paged_json $URL per_page page > $repos || return $?
  }

  test -e $confd/$remote_list -a $confd/$remote_list -nt $repos && {

    cat $confd/$remote_list || return $?
  } || {
    jq -r 'to_entries[] as $r | $r.value.full_name' $repos | tee $confd/$remote_list
  }
  wc -l $confd/$remote_list
}
