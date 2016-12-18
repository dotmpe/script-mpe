
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
    debug "$metaf is newer than $metajs"
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
        # TODO: check ret codes warn "Failed reading package defaults from $1 ($?)"
        return 1
      }

  } | sed 's/^\([^=]*\)=/test -n "$\1" || \1=/g'
}

# Easy access for shell to package.yml/json: convert to Sh vars.
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
    { jsotk_package_sh_defaults "$metaf" || {
      test ! -e $metash || rm $metash
    }; } | sort -u > $metash

    grep -q Exception $metash && rm $metash
    test -s "$metash" || rm $metash

    test -e "$metaf" || return

    # Format main block
    { jsotk.py -I yaml objectpath $metaf '$.*[@.main is not None]' || {
      warn "Failed reading package main from $1 ($?)"
      rm $metamain
      return 17
    }; }  > $metamain

    test -s "$metamain" || {
      warn "Failed reading package main from $1"
      rm $metamain
      return 16
    }

    jsotk.py --output-prefix=package to-flat-kv $metamain | sort -u >> $metash || {
      warn "Failed writing package Sh from $1 ($?)"
      rm $metash
      return 15
    }
  }
}


update_temp_package()
{
  test -n "$pd" || error pd 21
  test -n "$ppwd" || ppwd=$(cd $1; pwd)
  mkvid "$ppwd"
  metaf=$(setup_tmpf .yml "-meta-$vid")
  test -e $metaf || touch $metaf $pd
  #test -e "$metaf" && return || {
    metash=$1/.package.sh
    test -e $metaf -a $metaf -nt $pd || {
      pd__meta package $1 > $metaf
    }
  #}
}


# Given package.yaml metafile, extract and fromat as SH, JSON. If no local
# package.yaml exists, try to extract one temp package YAML from Pdoc.
update_package()
{
  test -n "$1" || set -- .
  test -d "$1" || error "update-package dir '$1'" 21
  test -z "$2" || error "update-package args '$*'" 22
  test -n "$ppwd" || ppwd=$(cd $1; pwd)
  test -n "$metaf" || metaf="$(echo $1/package.y*ml | cut -f1 -d' ')"
  metaf=$(normalize_relative "$metaf")

  test -e "$metaf" || {
    update_temp_package "$1" || { r=$?
      rm $metaf
      error update_temp_package-$r
      return 23
    }
  }
  test -e "$metaf" || error "metaf='$metaf'" 34

  # Package.sh is used by other scripts
  update_package_sh "$1" || {
    r=$?
    grep -q Exception $metash && rm $metash
    return $r
  }

  # .package.json is not used, its a direct convert of te entire YAML doc.
  # Other scripts can use it with jq if required
  update_package_json "$1" || return $?
}

package_sh()
{
  update_package
  test -e .package.sh || error package.sh 1
  (
    eval $(cat .package.sh | sed 's/^package_//g')

    while test -n "$1"
    do
      key=$1
      value="$(eval echo "\$$1")"
      shift
      test -n "$value" || continue
      echo "$key=$value"
    done
  )
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



meta_attribute()
{
  test -e .attributes || return
  test -n "$1" || error meta-attributes-act 1
  case "$1" in
    tagged )
        test -n "$2" || set -- "$1" "src"
        grep $2 .attributes | cut -f 1 -d ' '
      ;;
  esac
}


