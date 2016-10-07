#!/bin/bash


plugin_name=mpe_matador_
instance_name=$(basename $0 .sh)
instance_args=${instance_name:${#plugin_name}}

node=${instance_args%%_*}
measure=${instance_args##*_}


case "$1" in

    autoconf)
        echo yes
        exit 0
        ;;

    config )
        case "$measure" in
            usew )
                echo 'graph_args --base 1000 --lower-limit 0'
                ;;
            use2 )
                echo 'graph_args --base 1000 --lower-limit 950 --upper-limit 1000'
                ;;
            use1 )
                echo 'graph_args --base 1000 --lower-limit 1050 --upper-limit 1100'
                ;;
            * )
                echo 'graph_args --base 1000'
                ;;
        esac
        printf 'graph_title %s metrics from %s' $measure $node
        printf '%s_%s.label %s metrics from %s' $node $measure $measure $node
        printf '%s_%s.type GAUGE' $node $measure

        #graph_vlabel temp in C
        #temp.warning 60
        #temp.critical 85
        cat <<'EOM'

graph_category sensors

EOM
        exit 0
        ;;

esac

path=/tmp/matador/$node/$measure

# Print average
printf '%s_%s.value %f' $node $measure $(
    awk '{ total += $1; count++ } END { print total/count }' $path
)

# Truncate
echo > $path


