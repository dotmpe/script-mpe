true "${feh_bg:=$(test "${CS:-dark}" = "dark" && echo "#1c1c1c" || echo "#dadada")}"
true "${feh_delay:=4}"
true "${feh_delay_fast:=1.5}"

alias feh-info='feh -d --draw-tinted --info "file -bLs %f"'

# Fit to window and color excess space
alias feh-frame="feh-zoom-extents --class pf -B '${feh_bg:-black}'"

# Some frame "sub" aliases for slideshows
alias feh-ordered-files="feh-frame -S name --version-sort"
alias feh-slideshow="feh-ordered-files -D ${feh_delay:?}"
alias feh-slideshow-fast="feh-ordered-files -D ${feh_delay_fast:?}"
alias feh-slideshow-fs="feh-slideshow -Y -F"
alias feh-slideshow-fs-fast="feh-slideshow-fast -Y -F"
alias feh-slideshow-fs-random="feh-slideshow-fs -z"
alias feh-slideshow-fs-random-fast="feh-slideshow-fs-fast -z"
alias feh-slideshow-random-fast="feh-slideshow-fast -z"

# Scale to fit inside window XXX: I didnt make a matrix with this zoom mode...
# it would be useful to autogenerate one
alias feh-zoom-extents="feh -Z -."
# XXX: Scale to cover entire window?
alias feh-zoom-frame="feh-zoom-extents --zoom fill"
#alias feh-zoom-frame="feh ..."

# See user-desktop
#alias feh-backgrounds-preview=
#alias feh-backgrounds-choose=

#
