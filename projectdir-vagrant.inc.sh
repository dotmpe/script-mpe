

pd_load__vagrant=iI
pd__vagrant()
{
  test -z "$2"

  note "Vagrant: $*"

  cd $1

  vagrant up --provision \
    || echo "pd:$comp:$*" >> $failed

  test -s "$failed" && return 1

  return 0
}



