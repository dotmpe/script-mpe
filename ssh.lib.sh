#!/bin/sh

ssh_lib__load ()
{
  :
}

ssh_lib__init ()
{
  test -z "${ssh_lib_init-}" || return $_
  #metash_makegroup ssh_lib_profile \
  #  SSH_KEY_DIR $HOME/.ssh
  #  SSH_KEY_IDPREF id_
  #  SSH_KEY_LEN 2048 -- \
  #  SSH_KEY_ROUNDS 150 -- \
  #  SSH_KEY_TYPE rsa -- \
  #  DSA has been removed from latest Debian. The *-sk variants use USB HID
  #  or FIDO using SSH_SK_PROVIDER path, but note sure what the deal is.
  : "${SSH_KEY_TYPES:=ecdsa ecdsa-sk ed25519 ed25519-sk rsa}"
  : "${SSH_RSA_LEN:=3072}"
  : "${SSH_DSA_LEN:=1024}"
  : "${SSH_ECDSA_LEN:=521}"
}

# This always expects a passphrase.
ssh_keygen () # (lib) ~ <Tag> [<Comment>] ... # Create id for tag, and with comment
{
  local \
    tag=${1:?} comment=${2-} fn lk=${lk-}:ssh-keygen flags ktpword \
    klen=${SSH_KEY_LEN-} \
    kpref=${SSH_KEY_IDPREF:=id_} \
    krnds=${SSH_KEY_ROUNDS:-150} \
    ktp=${SSH_KEY_TYPE:-rsa}
  ktpword=${ktp//-/_}
  ktpword=${ktpword,,}
  test -n "${klen}" || {
    local klen_ref=SSH_${ktpword^^}_LEN
    klen=${!klen_ref-}
  }
  test -n "${comment}" || {
    local user=${SSH_USER:-${USER:-$(whoami)}}
    local host=${SSH_USER_HOST:-${OS_HOSTNAME:-$(hostname)}}
    test -n "$user" -a -n "$host" ||
      $LOG alert "$lk" "Unable to build comment" "" ${_E_fail:-1} || return
    comment="$user+$tag@$host"
  }
  fn="${kpref}${ktpword},${tag}"
  ! "${QUIET:-false}" && "${VERBOSE:-false}" || flags=-q
  ssh-keygen ${flags-} \
    -a ${krnds} ${klen:+-b ${klen}} -t ${ktp} \
    -P "${SSH_KEY_PHRASE:?}" \
    -C "$comment" -f "${SSH_KEY_DIR:-$HOME/.ssh}/${fn}"
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
