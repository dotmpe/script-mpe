
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
    log "Regenerating $metajs from $metaf.."
    jsotk.py yaml2json $metaf $metajs
  }
}

jsotk_package_sh_defaults()
{
  jsotk.py -I yaml -O fkv objectpath $1 '$..*[@.*.defaults]' \
    | sed 's/^\([^=]*\)=/test -n "$\1" || \1=/g'
}

update_package_sh()
{
  test -n "$1" || set -- ./
  test -n "$metash" || metash=$1/.package.sh
  metash=$(normalize_relative "$metash")
  test $metaf -ot $metash \
    || {

    log "Regenerating $metash from $metaf.."

    jsotk_package_sh_defaults "$metaf" > $metash
    ( jsotk.py -I yaml objectpath $metaf '$.*[@.main is not None]' \
        || rm $metash; exit 31 ) \
        | jsotk.py --output-prefix=package to-flat-kv - >> $metash
  }
}

# Given package.yaml metafile, extract and fromat as SH, JSON.
update_package()
{
  test -n "$1" || set -- ./
  test -n "$metaf" || metaf="$(echo $1/package.y*ml | cut -f1 -d' ')"
  metaf=$(normalize_relative "$metaf")
  test -e "$metaf" || warn "No package def '$metaf'" 0
  # Package.sh is used by other scripts
  update_package_sh "$1"
  # .package.json is not used, its a direct convert of te entire YAML doc.
  # Other scripts can use it with jq if required
  update_package_json "$1"
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



