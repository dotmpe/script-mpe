# Copyright: (C) 2026 qwrt <qwrt@t460s>
#
# .group.bash file, see User-Conf us-part for specification.
#
# Distributed under terms of the MIT license.

feh_als_pre=Feh.Alias
feh_als_cnk=b0fa15b5
declare -gA \
feh_als_als=(
  # Draw filename and info blocks (left-top and -bottom)
  [feh.info]='feh -d --draw-tinted --info "file -bLs \"%f\""'

  # Fit to window and color excess space
  [feh+passepartout]='feh --class pf -B "${feh_bg:-black}"'
  [feh+info+passepartout]='feh.info --class pf -B "${feh_bg:-black}"'

# Scale to fit inside window XXX: I didnt make a car.prod. with this zoom mode...
# it would be useful to autogenerate one

  # Fill window leaving no passe partout but pad (centered) picture to compensate ratio diff
  [feh+frame]='feh+passepartout -Z -.'
  [feh+info+frame]='feh+info+passepartout -Z -.'

  # Cover entire window, clipping (centured) picture to window ratio
  [feh.wmask]="feh --zoom fill"
  [feh+info+wmask]="feh.info --zoom fill"

  # Some frame "sub" aliases for slideshows etc.

  [feh+wmask+ordered-files]='feh.wmask -S name --version-sort'
  [fehinfo+wmask+ordered-files]='feh+info+wmask -S name --version-sort'

  [feh+wmask+slideshow]='feh+wmask+ordered-files -D ${feh_delay:?}'
  [feh+wmask+slideshow+fast]='feh+wmask+ordered-files -D ${feh_delay_fast:?}'

  [fehinfo+wmask+slideshow]='fehinfo+wmask+ordered-files -D ${feh_delay:?}'
  [fehinfo+wmask+slideshow+fast]='fehinfo+wmask+ordered-files -D ${feh_delay_fast:?}'

  [feh+wmask+pictureshow]='feh.wmask --randomize -D ${feh_delay:?}'
  [feh+wmask+pictureshow+fast]='feh.wmask --randomize -D ${feh_delay_fast:?}'

  [fehinfo+wmask+pictureshow]='feh+info+wmask --randomize -D ${feh_delay:?}'
  [fehinfo+wmask+pictureshow+fast]='feh+info+wmask --randomize -D ${feh_delay_fast:?}'

  # Default to fullscreen (and hide pointer!)
  [feh+fs+slideshow-]="feh+wmask+slideshow -Y -F"
  [feh+fs+slideshow+fast]="feh+wmask+slideshow+fast -Y -F"
  [feh+fs+pictureshow-]="feh+wmask+pictureshow -Y -F"
  [feh+fs+pictureshow+fast]="feh+wmask+pictureshow+fast -Y -F"
)
declare -gA \
feh_als_hooks=(
  [init]=\
': "${feh_bg:=$(test "${CS:-dark}" = "dark" && echo "#1c1c1c" || echo "#dadada")}"
: "${feh_delay:=4}"
: "${feh_delay_fast:=1.5}"'
)


# XXX: See user-desktop
#alias feh-backgrounds-preview=
#alias feh-backgrounds-choose=

# Id: als,feh         vim:set ft=bash sw=2 sts=2 et:
