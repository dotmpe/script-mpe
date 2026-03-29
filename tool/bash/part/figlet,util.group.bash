# Copyright: (C) 2025 qwrt <qwrt@t460s>
#
# .group.bash file, see User-Conf us-part for specification.
#
# Distributed under terms of the MIT license.

util_figlet_pre=Util.Figlet
util_figlet_cnk=90370ed6
util_figlet_fun=(
)
declare -gA \
util_figlet_als=(
)
declare -gA \
util_figlet_ssc=(
)
declare -gA \
util_figlet_hooks=(
  [init]='{
      #/usr/share/figlet
    util_figlet_dir=(
      /src/vendor/github.com/xero/figlet-fonts
      /srv/annex-local/archive-1/media/graphic/font/figlet
    )
}'
  [init]=\
': "${FIGLET_FONTS_DIR:=$(figlet -I 2)}"'
)

Util.Figlet.install-fonts ()
{
  local srcdir
  for srcdir in "${util_figlet_fontdir[@]}"
  do
    :
  done
}

Util.Figlet.list-fonts ()
{
: param '~ [<Dir>] [<Dest>]'
  ! (($#)) || ! (($#-1)) || local -n _dest=${2-}
  local -a flfs
  local flf
  if_ok "$(find "${1:-$FIGLET_FONTS_DIR}" -iname '*.[tf]lf')" &&
  mapfile -t flfs <<< "$_" &&
  for flf in "${flfs[@]}"
  do
    : "${flf##*/}"
    : "${_%.[tf]lf}"
    [[ ${2-} ]] && _dest+=( "${_}" ) || echo "${_}"
  done
}

Util.Figlet.preview-figlets ()
{
  FIGLET_TEST=\
'ABCDEFGHIJKLMNOPQRSTUVWXYZ abcdefghijklmnopqrstuvwxyz 0123456789 - + _ , . ; : ~ ^ * ! ? @ # $ % & < > ( ) [ ] { }'

  #FIGLET_TEST='Abc 0123'
  Util.Figlet.list-fonts | fzf --preview-window='follow,90%' --preview="figlet -w \$COLUMNS -f {} \"${FIGLET_TEST}\""
}

# Id: figlet,util                                vim:set ft=bash sw=2 sts=2 et:
