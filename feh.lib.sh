true "${feh_bg:=$(test "${CS:-dark}" = "dark" && echo "#1c1c1c" || echo "#dadada")}"
true "${feh_delay:=4}"

alias feh-slideshow-fs="feh -Z -F -B '$feh_bg' -D $feh_delay"
alias feh-slideshow="feh -Z -. -B '$feh_bg' -D $feh_delay"
alias feh-slideshow-fs-random="feh-slideshow-fs -z"
alias feh-slideshow-random="feh-slideshow -z"

#
