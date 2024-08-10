#!/bin/sh

# XXX: probably rename annex-htd->uc-annex


annex_htd_lib__load()
{
  : "${ANNEXTAB:=${STATUSDIR_ROOT:?}index/annexes.tab}"
  : "${HTD_ANNEX_DEFAULT:=archive-1}" # Primary Annex, to select during init
  lib_require annex os-uc class-uc stattab-uc srv-htd || return
  ctx_class_types=${ctx_class_types-}${ctx_class_types:+" "}AnnexTab
}

annex_htd_lib__init() # ~ ...
{
  test -z "${annex_htd_lib_init-}" || return $_
}


# Get user-config file and retrieve record for current ANNEX_ID, setting
# ANNEX_DIR to the local primary basedir.
annex_htd_dir_init ()
{
  annex_htd_init_default &&
  $annexes.fetch annex_htd ${ANNEX_ID:?} &&
  : "${ANNEX_DIR:=/srv/annex-local/$ANNEX_ID}" &&
  test -d "$ANNEX_DIR" && {
    ANNEX_DIR=$(realpath "$ANNEX_DIR")
  } || {
    ANNEX_DIR=$($annex_htd.basedir) ||
      $LOG alert "$lk" "No annex basedir" "E$?:$ANNEX_DIR" $? || return
  }
  [[ $PWD = "$ANNEX_DIR" ]] && {
    $LOG info "$lk" "Found annex basedir" "$ANNEX_DIR"
  } || {
    [[ "$(os_basename "$PWD")" == "${ANNEX_ID:?}" ]] || {
      std_silent pushd "$ANNEX_DIR" &&
      $LOG notice "$lk" "Moved to primary ${ANNEX_ID:?} repository"
    }
  }
}

# Setup base env, after lib env has completely initialized
annex_htd_init_default ()
{
  #: "${SHARE_DIRS:=$SHARE_DIR:/srv/share-1:/srv/share-2}"

  class_init AnnexTab{,Entry} &&
  create annexes AnnexTab $ANNEXTAB || return
  : "${annexes:?Expected annexes table}"
}

# Helper to get dynamic annex env/context
annex_htd_load_default ()
{
  : "${annexes:?Expected annexes context}"

  ANNEX_DIRS=$($annex_htd.basedirs) &&
  #stderr echo "annex_htd.basedirs: $($annex_htd.basedirs)"
  # Get canonical paths for storage folders with annex checkouts

  true
  return

  # If not in profile, set ANNEX_DIR to local path.
  # XXX: there may not be a checkout there.
  # XXX: could pick one from ANNEX_DIRS based on volume-id filter
  $srvtab.fetch srv_annex srv/annex &&

  stderr ${srv_annex:?Srv-Annex entry expected}.entry &&
  if_ok "${ANNEX_DIR:=$($srv_annex.local-dir)/$HTD_ANNEX_DEFAULT}"
  $LOG info :annex.lib:init "Initialized user annex shell env" \
      "E$?:tab=$ANNEXTAB" $?
}


annex_htd_banlist ()
{
  local r=0
  test $# -gt 0 || set -- list
  case "$1" in
    ( exists ) test -s "$BTP_BANNED" || r=$? ;;
    ( list ) annex_htd_banlist exists && cat "$BTP_BANNED" && annex_htd_banlist summary ; r=$? ;;
    ( ips ) annex_htd_banlist exists && cut -d ' ' -f 2 "$BTP_BANNED" ; r=$? ;;
    ( update ) set -- $(annex_htd_banlist harvest | cut -d ' ' -f 2) && {
          test -e "$BTP_BANNED" || touch "$BTP_BANNED" || r=$?; } &&
          for ipaddr
          do
            grep -q " $ipaddr$" "$BTP_BANNED" && continue
            echo "$(date +'%s') $ipaddr" >> "$BTP_BANNED"
          done &&
          annex_htd_banlist update-pg-gzip &&
          annex_htd_banlist summary
          r=$?
        ;;
    ( summary )
          btp_banned=$(count_lines "$BTP_BANNED") || r=$?
          $LOG notice :htd:banlist "Bt-Peers-Banned" "$btp_banned"
        ;;

    ( update-pg-gz | update-peerguardian-gzip )
          BLOCKLIST="$ANNEX_DIR/meta/net/blocklist.pg" &&
          {
            cut -d ' ' -f 2 "$BTP_BANNED" | sed '
                    s/^[0-9\.]*$/&-&/
                    s/^/"Banned client":/
                ' &&
            annex_htd_banlist pg
          } >"$BLOCKLIST" &&
              gzip "$BLOCKLIST" &&
              scp "$BLOCKLIST.gz" dotmpe:www-data/dotmpe,www/
          r=$?
        ;;

    ( pg-summary )
          for pgz in $ANNEX_DIR/meta/net/*.gz
          do
            echo "$(basename "$pgz") $(zcat "$pgz" | wc -l) lines"
            #zcat "$pgz" | cut -d ':' -f 2 | wc -l
            #zcat "$pgz" | cut -d ':' -f 2 | remove_dupes | wc -l
          done
        ;;
    ( pg )
          for pgz in $ANNEX_DIR/meta/net/*.gz
          do
            test "$(basename "$pgz" .gz)" != "blocklist" || continue
            zcat "$pgz"
          done | FS=: remove_dupes_at_col 2
        ;;

    ( urls ) log_list "$BLOCKLIST_URLS" || r=$? ;;
    ( urls-add ) shift;
          test $# -gt 1 || {
            test -n "$(basename "$1")" || {
              $LOG error "" "Basename required to download URL"
              return 1
            }
          }
          log_add "$BLOCKLIST_URLS" "$@" && annex_htd_banlist urls-update ; r=$?
        ;;
    ( urls-update ) shift;
          (
            cd "$(dirname "$BLOCKLIST_URLS")" &&
              while read -r ts url bn
              do true "${bn:="$(basename "$url")"}"
                web_new_clean "$url" "$bn" "/tmp/annex_htd_banlist:urls-update:$bn"
              done <"$BLOCKLIST_URLS"
          ) && annex_htd_banlist update-peerguardian-gzip ; r=$?
        ;;

    # XXX: try to scan for peers but need something proper to match ranges
    ( pg-scan-peerlog ) shift
          test $# -gt 0 || set -- "$BTLOG_PEERS"
          for pl
          do
              remove_dupes_at_col 2 < "$pl" | while read -r ts ipaddr _ mode client
              do
                  ip_re=$(match_grep "${ipaddr%.*}.")
                  match=$(annex_htd_banlist pg | grep ":$ip_re") || continue
                  echo "Found possible match $ipaddr"
                  grep " $ipaddr " "$pl" | remove_dupes_at_col 3 | tail -n 25
                  echo "$match" | sed 's/^/\t/g'
              done
          done
        ;;

    # List peers with improper names as candidates for blocklist
    # XXX: might also check for proper name-version format
    ( harvest ) grep '[^[:alnum:]()\.? -]' "$BTLOG_PEERS" || r=$? ;;

    # List peers without shares as candidates for blocklist
    ( noshares )
        #remove_dupes_at_col 2
        #< "$pl" | while read -r ts ipaddr _ mode client
        ;;

    ( * ) return 67 ;;
  esac
  test -s "$BTP_BANNED" || rm "$BTP_BANNED"
  return $r
}


class_AnnexTabEntry__load ()
{
  Class__static_type[AnnexTabEntry]=AnnexTabEntry:StatTabEntry
}

class_AnnexTabEntry_ () # ~ <Instance-Id> .<Message-name> <Args...>
{
  case "${call:?}" in

  ( .basedir ) # ~~ # Return local primary basedir/checkout path
      # XXX: just using initial record, should use [,+-]<tag> in name or scheme
      # to select on role of value
      : "${StatTabEntry__refs[$OBJ_ID]}"
      echo "${_%%$'\n'*}"
    ;;
  ( .basedirs ) # ~~ # Return canonical paths for checkouts
      printf '%s\n' "${StatTabEntry__refs[$OBJ_ID]}"
      # FIXME $self.var refs | filter_dir_paths
    ;;

    * ) return ${_E_next:?}
  esac && return ${_E_done:?}
}


class_AnnexTab__load ()
{
  Class__static_type[AnnexTab]=AnnexTab:StatTab
}

class_AnnexTab_ () # (super,self,id,call) ~ <Args>
#   .__init__ <Type> <Table> [<Entry-class>] # constructor
{
  case "${call:?}" in

    ( .__init__ )
        $super.__init__ "${@:1:2}" "${3:-AnnexTabEntry}" "${@:4}" ;;

      * ) return ${_E_next:?}

  esac && return ${_E_done:?}
}

#
