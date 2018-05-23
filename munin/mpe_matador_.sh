#!/bin/bash


plugin_name=mpe_matador_
instance_name=$(basename $0 .sh)
instance_args=${instance_name:${#plugin_name}}

node=${instance_args%%_*}
measure=${instance_args##*_}


# Available measures with P1 scanner
# use1 use2 gen1 gen2 mode usew genw gas

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
            use1|use2 )
                echo 'graph_args --base 1000'
                printf '%s_%s.type COUNTER' $node $measure
                ;;
            mode )
                printf '%s_%s.type ABSOLUTE' $node $measure
                ;;
            * )
                echo 'graph_args --base 1000'
                printf '%s_%s.type GAUGE' $node $measure
                ;;
        esac
        printf 'graph_title %s metrics from %s' $measure $node
        printf '%s_%s.label %s metrics from %s' $node $measure $measure $node

        echo graph_category sensors
        echo .
        exit 0
        ;;

esac

path=/tmp/matador/$node/$measure

# Print average
printf '%s_%s.value %f' $node $measure $(
    awk '{ total += $1; count++ } END { print total/count }' $path
)
echo .

# Truncate, so that next run doesn't repeat values
echo > $path
