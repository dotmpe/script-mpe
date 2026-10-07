#!/usr/bin/env bash

user_ssh_lib__load ()
{
  lib_require ssh || return
  #metash || return
  #lib_require ssh metash || return

  # Either load profile given static setting, or from template
  #USER_SSH_PROFILE
  #metash_load user_ssh_profile

  # ssh-keygen uses RSA by default as well
  : "${USER_SSH_IDALGO:=rsa}"
  # 3072 bits is default for RSA. DSA is 1024, and ECDSA can be 256, 384 or 512.
  # other key types are fixed length.
  : "${USER_SSH_IDLEN:=4096}"
  # Rounds
  : "${USER_SSH_IDROUNDS:=150}"
  : "${USER_SSH_IDPREF:=id_}"
}
