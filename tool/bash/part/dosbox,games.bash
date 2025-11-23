games_dosbox_pre=Games.DOSBox
games_dosbox_fun=(
  .find-game
  .start-game
)
declare -gA \
games_dosbox_hooks=(
  [init]='test -h ~/.dosbox || >&2 ln -vs ~/.conf/etc/dosbox ~/.dosbox || return
: "${DOTFILES:=$HOME/.local/share/dotfiles}"
: "${ANNEX_DIR:=/srv/annex-local/archive-1}"
. /var/local/statusdir/games-dosbox-cache.bash
shopt -s nullglob'
  [deinit]=''
  [update]=''

  [start]=\
'( echo "Mounting DOS drive..."; cd ${ANNEX_DIR:?} &&
  test -s media/archive/dosdrive.tar.bz2 || {
    git annex get media/archive/dosdrive.tar.bz2 ||
      failerr "E$? getting dosbox filesytem archive file" || return
  } && git annex unlock media/archive/dosdrive.tar.bz2
) &&
mkdirs ~/.local/mnt/dosbox-c &&
mountpoint -q ~/.local/mnt/dosbox-c ||
archivemount ${ANNEX_DIR:?}/media/archive/dosdrive.tar.bz2 ~/.local/mnt/dosbox-c ||
  failerr "E$? mounting dosbox filesytem file"'

  [stop]='umount ~/.local/mnt/dosbox-c &&
rmdir ~/.local/mnt/dosbox-c &&
echo DOS drive unmounted'

  [status]=\
'( cd ${ANNEX_DIR:?} &&
  git status media/archive/dosdrive.tar.bz2
)'

)

Games.DOSBox.find-gamedata ()
{
  local _echo
  (($#-1)) && local -n _gd_dest=${2:?} || _echo=1
  local _fgd_gamedata
  for _fgd_gamedata in ${ANNEX_DIR:?}/media/application/dos,games/${1:?}*.zip
  do
    [[ $_fgd_gamedata == *,gamedir[,.]* ]] || {
      >&2 echo "Found $gamedata but not an executable or data directory" && continue
    }
    ((${_echo:-0})) && echo "$_fgd_gamedata" || _gd_dest=$_fgd_gamedata
    break
  done
}

Games.DOSBox.find-game ()
{
  (($#-1)) && local -n _gn_dest=${2:?} || local _echo=1
  local name dir
  local -n gamedir='games_dosbox_dirmap[$name]'
  for name in ${!games_dosbox_dirmap[@]}
  do
    [[ ${gamedir} == $1 ]] && break || unset name
  done
  [[ ${name:+set} ]] || return
  ((${_echo:-0})) && echo "$name" || _gn_dest=$name
}

Games.DOSBox.setup-game ()
{
  local game{{base,}name,data,conf,exe}

  Games.DOSBox.find-game "${1^^}" gamebasename || : "${gamebasename:=${1^}}"
  Games.DOSBox.find-gamedata "${gamebasename}" gamedata &&
  [[ -s "$gamedata" ]] ||
    failerr "No data for ${1@Q} (looking for ${gamebasename@Q} at ${ANNEX_DIR:?})" || return
  echo "Looking for ${1@Q} found data ${gamedata@Q}..."

  local game{,zip}dir
  local -n \
    _gameexe='games_dosbox_exemap["$gamename"]' \
    _gamedir='games_dosbox_dirmap["$gamename"]' \
    _gamezipdir='games_dosbox_zipdirmap["$gamename"]'

  : "${gamedata##*/}"
  gamename=${_%%,*}
  #[[ ${#gamename} -le 8 ]] ||
  #[[ ${_gamedir:+set} ]] ||
  #  failerr "No dir map for ${gamename@Q}"

  gamedir=${_gamedir:-${gamebasename^^}}

  [[ -d ~/.local/mnt/dosbox-c/GAMES/${gamedir} ]] &&
  >&2 echo "DOSBox dir exists GAME/${gamedir}" || {

    mkdirs /tmp/gamezip-$gamename &&
    >&2 echo "Unzipping $gamedata to /tmp..." &&
    unzip "$gamedata" -d /tmp/gamezip-$gamename &&

    [[ ! ${_gamezipdir:+set} && ! -d /tmp/gamezip-$gamename/"$gamename" ]] && {
      mkdirs ~/.local/mnt/dosbox-c/GAMES/${gamedir} &&
      >&2 mv -v /tmp/gamezip-$gamename/* ~/.local/mnt/dosbox-c/GAMES/${gamedir}/ ||
        failerr "E$? while moving to dosdrive" || return
    } || {
      gamezipdir=${_gamezipdir:-${gamename:?}}
      >&2 mv -v /tmp/gamezip-$gamename/"$gamezipdir" ~/.local/mnt/dosbox-c/GAMES/${gamedir} ||
        failerr "E$? while moving to dosdrive" || return
    }

    rm -rf /tmp/gamezip-$gamename
  }

  gameexe=${_gameexe:-${gamedir:?}}
  gameconf=${DOTFILES:?}/etc/dosbox/${gamedir,,}.conf
  [[ -s "$gameconf" ]] &&
  >&2 echo "DOSBox config exists ${gamedir,,}.conf" || {
  > "$gameconf" eval "cat <<EOM
$(< ${DOTFILES:?}/etc/dosbox/game,conf.tpl )
EOM"
  }
}

Games.DOSBox.start-game ()
{
  local startgame gameconf=${DOTFILES:?}/etc/dosbox/${1,,}.conf
  [[ -s "$gameconf" ]] ||
    Games.DOSBox.setup-game "$@" ||
      failerr "No such game configuration ${1@Q}" || return
  dosbox -userconf -conf "$gameconf"
}
