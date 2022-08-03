#!/bin/sh


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
          for ipaddr in "$@"
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
          lognote "Bt-Peers-Banned" "$btp_banned"
        ;;

    ( update-pg-gz | update-peerguardian-gzip )
          BLOCKLIST="$SHARE_DIR/meta/net/blocklist.pg" &&
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
          for pgz in $SHARE_DIR/meta/net/*.gz
          do
            echo "$(basename "$pgz") $(zcat "$pgz" | wc -l) lines"
            #zcat "$pgz" | cut -d ':' -f 2 | wc -l
            #zcat "$pgz" | cut -d ':' -f 2 | remove_dupes | wc -l
          done
        ;;
    ( pg )
          for pgz in $SHARE_DIR/meta/net/*.gz
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
          test $# -gt 0 || set -- "$BT_PEER_LOG"
          for pl in "$@"
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
    ( harvest ) grep '[^[:alnum:]()\.? -]' "$BT_PEER_LOG" || r=$? ;;

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

#
