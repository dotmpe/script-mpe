#!/usr/bin/env bash

### ImageMagick helpers

#shellcheck disable=SC1090,1007


scale () # ~ <Resolution> <Input> [<Output>]
{
  #shellcheck disable=SC2086
  convert "$2" -resize $1^ -gravity center -extent $1 "$3"
}

crop () # ~ <Geometry> <Input> [<Output>]
{
  convert "$2" -crop "$1" "$3"
}

# Tint only affects mid-range colors
tint () # ~ <Color> <Percentage> <Input> [<Output>]
{
  convert "$3" -fill "$1" -tint "$2" "$4"
}

colorize () # ~ <In> <Out> <Color> <Percentage <G, B>
{
  convert "$1" -fill "$3" -colorize "$4" "$2"
}


# Main entry (see user-script.sh for boilerplate)

uc_script_load user-script

# Parse arguments
! script_isrunning "image" .sh || {
  user_script_load || exit $?
  eval "set -- $(user_script_defarg "$@")"

  # Execute argv and return
  script_run "$@"
}
#
