
filetype()
{
  test -e "$1" || error "expected existing path <$1>" 1

  case "$uname" in

    Darwin )
      file -b --mime-type "$1"
      ;;

    * )
      error "No filetype for $uname" 1
      ;;

  esac
}


# Deal with package metadata files

update_package_json()
{
  test -n "$1" || set -- ./
  test -n "$metajs" || metajs=$1/.package.json
  metajs=$(normalize_relative "$metajs")
  test $metaf -ot $metajs \
    || {
    note "Regenerating $metajs from $metaf.."
    jsotk.py yaml2json $metaf $metajs \
      || return $?
  }
}

jsotk_package_sh_defaults()
{
  {
    jsotk.py -I yaml -O fkv objectpath $1 '$..*[@.*.defaults]' \
      || {
        warn "Failed reading package defaults from $1"
        return 1
      }

  } | sed 's/^\([^=]*\)=/test -n "$\1" || \1=/g'
}

update_package_sh()
{
  test -n "$1" || set -- ./
  test -z "$2" || error "Surplus arguments '$*'" 1
  # XXX:
  #shopt -s extglob
  #fnmatch "+([A-ZA-z0-9./])" "$1" || error "Illegal format '$*'" 1

  test -n "$metash" || metash=$1/.package.sh
  test -n "$metamain" || metamain=$1/.package.main
  metash=$(normalize_relative "$metash")
  test $metaf -ot $metash \
    || {

    # Format Sh script/vars from local package file
    note "Regenerating $metash from $metaf.."

    # Format Sh default env settings
    jsotk_package_sh_defaults "$metaf" > $metash || {

      warn "Failed reading package defaults from $1"
      rm $metash
      return 1
    }

    test -s "$metash" || rm $metash

    # Format main block
    jsotk.py -I yaml objectpath $metaf '$.*[@.main is not None]' > $metamain \
    || {
      warn "Failed reading package main from $1"
      rm $metamain
      return 1
    }

    test -s "$metamain" || {
      warn "Failed reading package main from $1"
      rm $metamain
      return 1
    }

    jsotk.py --output-prefix=package to-flat-kv $metamain >> $metash || {
      rm $metash
      return 1
    }
  }
}

# Given package.yaml metafile, extract and fromat as SH, JSON. If no local
# package.yaml exists, try to extract one temp package YAML from Pdoc.
update_package()
{
  test -n "$1" || set -- .
  test -n "$metaf" || metaf="$(echo $1/package.y*ml | cut -f1 -d' ')"
  metaf=$(normalize_relative "$metaf")
  local delete_mf=0 ret=0
  test -e "$metaf" || {
    delete_mf=1
    pd__meta package  $1 > $1/package.yml
    metaf=$1/package.yml
  }

  # Package.sh is used by other scripts
  update_package_sh "$1" || ret=$?

  # .package.json is not used, its a direct convert of te entire YAML doc.
  # Other scripts can use it with jq if required
  update_package_json "$1" || ret=$(( $ret + $? ))

  trueish "$delete_mf" && {
    rm $metaf
  }

  return $ret
}


mediadurationms()
{
  echo "General;%Duration%" > /tmp/template.txt
  mediainfo --Output=file:///tmp/template.txt "$1"
}

mediaresolution()
{
  echo "Video;%Width%x%Height%" > /tmp/template.txt
  mediainfo --Output=file:///tmp/template.txt "$1"
}

mediapixelaspectratio()
{
  echo "Video;%PixelAspectRatio/String%" > /tmp/template.txt
  mediainfo --Output=file:///tmp/template.txt "$1"
}

mediadisplayaspectratio()
{
  echo "Video;%DisplayAspectRatio/String%" > /tmp/template.txt
  mediainfo --Output=file:///tmp/template.txt "$1"
}


# General;%CompleteNae% * %FileSize/String3% * %Duration/String%
# Video; |Video: %Width%x%Height% * %DisplayAspectRatio/String% * %Format%
# %Format_Profile%
# Audio; |Audio: %Language/String% * %Channel(s)% CH * %Codec/String%
# Text; |Sub: %Language/String% * %Codec%
# File_End;\n



