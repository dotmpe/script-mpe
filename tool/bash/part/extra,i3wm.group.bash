# Copyright: (C) 2026 qwrt <qwrt@t460s>
#
# .group.bash file, see User-Conf us-part for specification.
#
# Distributed under terms of the MIT license.

i3wm_extra_pre=I3wm.x
i3wm_extra_cnk=9c2a0825
i3wm_extra_fun=(
)

declare -gA \
i3wm_extra_als=(
)

declare -gA \
i3wm_extra_ssc=(

  [i3-msg.events.shell+example]=\
'while read json_msg
do
  change=$(jq -r .change <<< "$json_msg")
  keys=$(jq -r '\''keys[]'\'' <<< "$json_msg") || {
    >&2 echo "Error E$? at ${json_msg@Q}"
    declare -p json_msg
    continue
  }
  case "$change" in
    ( close | new )
        container=$(jq -r .container <<< "$json_msg") &&
        [[ $container != null ]] &&
        id=$(jq .id <<< "$container") &&
        echo $id $change window
      ;;
    ( floating | title )
        container=$(jq -r .container <<< "$json_msg") &&
        [[ $container != null ]] &&
        id=$(jq .id <<< "$container") &&
        state=$(jq .$change <<< "$container") &&
        echo $id $change = $state
      ;;
    ( focus )
        container=$(jq -r .container <<< "$json_msg") &&
        [[ $container != null ]] || {
          current=$(jq -r .current <<< "$json_msg")
          old=$(jq -r .old <<< "$json_msg")
          new_id=$(jq .id <<< "$current")
          old_id=$(jq .id <<< "$old")
          echo $new_id focus change 1 old=$old_id
          continue
        }
        new_id=$(jq .id <<< "$container")
        echo $new_id focus change 2
      ;;
    ( null ) # echo "First message: ${json_msg@Q}"
      ;;
    ( run )
        binding=$(jq -r .binding <<< "$json_msg")
        mode=$(jq -r .mode <<< "$json_msg")
        b_cmd=$(jq -r .binding.command <<< "$json_msg")
        [[ $b_cmd == null ]] &&
        echo run binding=$binding mode=$mode ||
        echo run key command ${b_cmd@Q} mode=$mode
      ;;
    ( * ) echo change: $change, keys: $keys
  esac
done < <(
i3-msg -m -t subscribe '\''["window","workspace","output","mode","barconfig_update","binding","shutdown","tick"]'\'' )'

)

# Id: extra,i3wm         vim:set ft=bash sw=2 sts=2 et:
