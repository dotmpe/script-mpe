ssh_als_pre=User.Alias.SSH
ssh_als_cnk=d8d96d83

ssh_als_fun=()

declare -gA \
ssh_als_hooks=(
)

declare -gA \
ssh_als_als=(
  [ssh-add.list]=ssh.keys+list
  [ssh-add.forget]=ssh.keys+forget

  [ssh.keys+load]='ssh-add'
  [ssh.keys+list]='ssh-add -L'
  [ssh.keys+forget]='ssh-add -D'
)

declare -gA \
ssh_als_ssc=(
)

# Id: als,ssh                                    vim:set ft=bash sw=2 sts=2 et:
