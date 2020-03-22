#!/bin/sh

#lib_load()
#{
#}

ssh_keygen() # Tag
{
  test -n "$1" || return
  test -n "$2" || set -- "$1" "$(whoami)+$1@$(hostname)"
  ssh-keygen -t rsa -C "$2" -f "$HOME/.ssh/$1-id_rsa"
}

# Echo path for private SSH key
ssh_keyfile() # Tag
{
  test -n "$1" || return
  echo "$HOME/.ssh/$1-id_rsa"
}

ssh_key_exists() # Tag
{
  test -n "$1" || return
  test -e "$HOME/.ssh/$1-id_rsa"
}

ssh_token_name() # Tag
{
  local tmpf="$(setup_tmpf .ssh_token_name.out)" r=
  echo $HOME/.conf/tokens/ssh/*$1* | tr ' ' '\n' >"$tmpf"
  test -s "$tmpf" -a -e "$(head -n 1 "$tmpf")" && {
    cat "$tmpf"
  } || r=1
  rm "$tmpf"
  return $r
}

ssh_token_new()
{
  ssh_keygen "$@" || return
  mv "$HOME/.ssh/$1-id_rsa"* $HOME/.conf/tokens/ssh/
  ssh_token_install "$1"
}

ssh_token_fetch() # Tag
{
  ( cd $HOME/.conf/tokens && git annex sync && git annex get ssh/*$1* )
}

ssh_token_install() # Tag
{
  for x in ~/.conf/tokens/ssh/*$1*.pub
  do
    pk="$(dirname "$x")/$(basename "$x" .pub)"
    test -e "$pk" || { warn "Skipping $x missing private-key" ; continue ; }

    ln -s "$pk" ~/.ssh/$(basename "$x" .pub)
    ln -s "$x" ~/.ssh/$(basename "$x")
  done
}

# Create SSH key for tag; if token does not already exists, fetch if not present
# locally
ssh_init_key() # Tag
{
  ssh_key_exists "$1" || {

    ssh_token_name "$1" && {

      ssh_token_fetch "$1" || return
      ssh_token_install "$1"

    } || {

      ssh_token_new "$@" || return
    }
  }
}
