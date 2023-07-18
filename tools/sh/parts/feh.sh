true "${feh_bg:=$(test "${CS:-dark}" = "dark" && echo "#1c1c1c" || echo "#dadada")}"
true "${feh_delay:=4}"

alias feh-info='feh -d --draw-tinted --info "file -bLs %f"'

# Fit to window and color excess space
alias feh-frame="feh-zoom-extents --class pf -B '${feh_bg:-black}'"

alias feh-slideshow="feh-frame -D ${feh_delay:?}"
alias feh-slideshow-fs="feh-slideshow -Y -F"
alias feh-slideshow-fs-random="feh-slideshow-fs -z"
alias feh-slideshow-random="feh-slideshow -z"

# Scale to fit inside window
alias feh-zoom-extents="feh -Z -."
# XXX: Scale to cover entire window?
alias feh-zoom-frame="feh-zoom-extents --zoom fill"
#alias feh-zoom-frame="feh ..."

# See user-desktop
#alias feh-backgrounds-preview=
#alias feh-backgrounds-choose=

#
