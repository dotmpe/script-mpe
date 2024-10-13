true "${feh_bg:=$(test "${CS:-dark}" = "dark" && echo "#1c1c1c" || echo "#dadada")}"
true "${feh_delay:=4}"
true "${feh_delay_fast:=1.5}"

# Draw filename and info blocks (left-top and -bottom)
alias feh+info='feh -d --draw-tinted --info "file -bLs \"%f\""'

# Fit to window and color excess space
alias feh+passepartout="feh --class pf -B '${feh_bg:-black}'"
alias feh+info+passepartout="feh+info --class pf -B '${feh_bg:-black}'"

# Scale to fit inside window XXX: I didnt make a matrix with this zoom mode...
# it would be useful to autogenerate one

# Fill window leaving no passe partout but pad (centered) picture to compensate ratio diff
alias feh+frame='feh+passepartout -Z -.'
alias feh+info+frame='feh+info+passepartout -Z -.'

# Cover entire window, clipping (centured) picture to window ratio
alias feh+wmask="feh --zoom fill"
alias feh+info+wmask="feh+info --zoom fill"


# Some frame "sub" aliases for slideshows etc.

alias feh-wmask-ordered-files="feh+wmask -S name --version-sort"
alias fehinfo-wmask-ordered-files="feh+info+wmask -S name --version-sort"

alias feh-wmask-slideshow="feh-wmask-ordered-files -D ${feh_delay:?}"
alias feh-wmask-slideshow-fast="feh-wmask-ordered-files -D ${feh_delay_fast:?}"

alias fehinfo-wmask-slideshow="fehinfo-wmask-ordered-files -D ${feh_delay:?}"
alias fehinfo-wmask-slideshow-fast="fehinfo-wmask-ordered-files -D ${feh_delay_fast:?}"

alias feh-wmask-pictureshow="feh+wmask --randomize -D ${feh_delay:?}"
alias feh-wmask-pictureshow-fast="feh+wmask --randomize -D ${feh_delay_fast:?}"

alias fehinfo-wmask-pictureshow="feh+info+wmask --randomize -D ${feh_delay:?}"
alias fehinfo-wmask-pictureshow-fast="feh+info+wmask --randomize -D ${feh_delay_fast:?}"

# Default to fullscreen (and hide pointer!)
alias feh-fs-slideshow-="feh-wmask-slideshow -Y -F"
alias feh-fs-slideshow-fast="feh-wmask-slideshow-fast -Y -F"

alias feh-fs-pictureshow="feh-wmask-pictureshow-fs -z"
alias feh-fs-pictureshow-fast="feh-pictureshow-fs-fast -z"


# See user-desktop
#alias feh-backgrounds-preview=
#alias feh-backgrounds-choose=

#
