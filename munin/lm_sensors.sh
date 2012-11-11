#!/bin/bash
#
# use MUNIN_ENV<fieldname>.cricitical :80
# etc. from /etc/munin/plugin-conf.d/
#
TYPE=$1
[ -n "$TYPE" ] || { exit 1 ; }

if [ "$2" = "config" ]; then
    echo "graph_info Output of lm-sensors ($TYPE only)"
    echo "graph_category sensors"
    echo "graph_args --base 1000 -l 0"

    case $TYPE in
        fan)
                echo "graph_title $(hostname -s|tr 'a-z' 'A-Z') Hardware Fan Speed"
                echo "graph_vlabel rpm"
            ;;
        temp)
                echo "graph_title $(hostname -s|tr 'a-z' 'A-Z') Hardware Temperature"
                echo "graph_vlabel temperature celcius"
            ;;
    esac
    # Overrides from config
	env|grep MUNIN_ENV|sed 's/MUNIN_ENV//'|sed 's/=/ /'
fi

interface_id=
interface_label=
sensors -u | while read line
do
    [ -z "$line" ] && {
        interface_id=
        interface_label=
    } || {
        
        [ -z "$interface_id" ] && {
            interface_id=`echo $line|sed 's/-/_/g'`
        } || {
            
            [ -z "$interface_label" ] && {
                interface_label=`echo $line|sed 's/^Adapter:\ //'`

            } || {
                
                [ -n "$(echo -n $(echo $line|grep input))" ] && {
                    vars=(`echo $line|sed 's/^\([a-z]*\)\([0-9]\+\)_input\:.\([0-9\.]\+\)$/\1 \2 \3/g'`)
                    name=${vars[0]}
                    [ "$name" = "$TYPE" ] && {
                        number=${vars[1]}
                        value=${vars[2]}
                        if [ "$2" = "config" ]; then
                            echo $interface_id"_"$name"_"$number.label $(hostname -s|tr 'a-z' 'A-Z') $interface_label $name $number
                        else
                            echo $interface_id"_"$name"_"$number.value $value
                        fi
                    }
                }
#                || {
#                    echo -n
#                    #echo "Line: $line"
#                    #echo "'"$(echo -n $(echo $line|sed 's/^[a-z_]\+[0-9]\+_input:\s\+$//'))"'"
#                } 
            }
        }
    }

done
