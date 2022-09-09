#!/bin/sh

htd_man_1__ips='
    --block-ips
    --unblock-ips
    -grep-auth-log
    --init-blacklist
    --deinit-blacklist
    --blacklist-ips
    -list
    -table
    --blacklist-ssh-password
      Use iptables to block IPs with password SSH login attempts.
'
htd__ips()
{
  fnmatch *" root "* " $(groups) " || sudo="sudo "
  case "$1" in

      deinit-wlist ) shift
          for ip in 185.27.175.61 anywhere
          do
            ${sudo}iptables -D INPUT -s ${ip} -j ACCEPT
          done
        ;;

      init-wlist ) shift
          set -e

          ${sudo}iptables -P FORWARD DROP # we aren't a router
          ${sudo}iptables -A INPUT -m state --state INVALID -j DROP
          ${sudo}iptables -A INPUT -m state --state RELATED,ESTABLISHED -j ACCEPT
          ${sudo}iptables -A INPUT -i lo -j ACCEPT
          #${sudo}iptables -A INPUT -s ${ip} -j ACCEPT

          wlist=./allowed-ips.list
          wc -l $wlist
          read_nix_style_file $wlist |
          while read ip
          do
            ${sudo}iptables -A INPUT -s ${ip} -j ACCEPT
          done

          ${sudo}iptables -P INPUT DROP # Drop everything we don't accept
        ;;

      init-blist ) shift
          blist=./banned-ips.list
          wc -l $blist
          {
            cat $blist
            htd ips -grep-auth-log
          } | sort -u >$blist
          wc -l $blist
          htd ips --init-blacklist
          read_nix_style_file $blist |
          while read ip
          do
            ${sudo}ipset add blacklist $ip
          done
        ;;

      --block-ips ) shift
          for ip in "$@" ; do
              ${sudo}iptables -I INPUT -s $ip -j DROP ; done
        ;;

      --unblock-ips ) shift
          for ip in "$@" ; do
              ${sudo}iptables -D INPUT -s $ip -j DROP ; done
        ;;

      -grep-auth-log-ips ) # get IP's to block from auth.log
          htd__ips -grep-auth-log |
            sed 's/.*from\ \([0-9\.]*\)\ .*/\1/g' |
            sort -u
        ;;

      -grep-auth-log ) # get IP's to block from auth.log
          ${sudo}grep \
              ':\ Failed\ password\ for [a-z0-9]*\ from [0-9\.]*\ port\ ' \
              /var/log/auth.log
        ;;


      --init-blacklist )
          test -x "$(which ipset)" || error ipset 1
          ${sudo}ipset create blacklist hash:ip hashsize 4096

          # Set up iptables rules. Match with blacklist and drop traffic
          #${sudo}iptables -A INPUT -m set --match-set blacklist src -j DROP
          ${sudo}iptables -A INPUT -m set --match-set blacklist src -j DROP ||
              warn "Failed setting blacklist for INPUT src"
          ${sudo}iptables -A FORWARD -m set --match-set blacklist src -j DROP ||
              warn "Failed setting blacklist for FORWARD src"
          #${sudo}iptables -I INPUT -m set --match-set IPBlock src,dst -j Drop
        ;;

      --deinit-blacklist )
          test -x "$(which ipset)" || error ipset 1
          ${sudo}ipset destroy blacklist
        ;;

      --blacklist-ips ) shift
          for ip in "$@" ; do ${sudo}ipset add blacklist $ip; done
        ;;

      -list ) shift ; test -n "$1" || set -- blacklist
          ${sudo}ipset list $blacklist | tail -n +8
        ;;

      -table ) ${sudo}iptables -L
        ;;

      --blacklist )
          htd__ips -grep-auth-log | while read ip;
          do
            ${sudo}ipset add blacklist $ip
          done
        ;;


      * ) error "? 'ips $*'" 1
        ;;
  esac
}

#
