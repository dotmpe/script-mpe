deb_src_pre=Debian.Source
deb_src_fun=(
  .find-for
)

Debian.Source.find-for ()
{
  dpkg -S ${1}
}

Debian.Source.get ()
{
  apt source ${@}
}
