
req_path_arg()
{
  test -n "$1"  && path="$1"  || path=.
  test -d "$path" || {
    error "Must pass directory" 1
  }
}

htd_relative_path()
{
  cwd=$(pwd)
  test -e "$1" && {
    x_re "${1}" '\/.*' && {
      error "TODO make rel"
    }
    x_re "${1}" '[^\/].*' && {
      x_re "${1}" '((\.\/)|(\.\.)).*' && {
        relpath="${1: 2}"
      } || {
        relpath="$1"
      }
      return 0
    }
  }
  return 1
}


htd_init_ignores()
{
  test -n "$HTD_IGNORE" || exit 1

  test -e $HTD_IGNORE.merged && grep -qF $HTD_IGNORE.merged $HTD_IGNORE.merged || {
    test -e "$HTD_IGNORE.merged" && {
      test -w "$HTD_IGNORE.merged" || error "Cannot write $(pwd)/$HTD_IGNORE.merged" 1
    }
    echo $HTD_IGNORE.merged > $HTD_IGNORE.merged
  }

  test -n "$pwd" || pwd=$(pwd)
  test ! -e $HTDIR || {
    cd $HTDIR

    for x in .git/info/exclude .gitignore $HTD_IGNORE
    do
      test -s $x && {
        cat $x | grep -Ev '^(#.*|\s*)$'
      }
    done

    cd $pwd

  } >> $HTD_IGNORE.merged

  for x in .git/info/exclude .gitignore $HTD_IGNORE
  do
    test -s $x && {
      cat $x | grep -Ev '^(#.*|\s*)$' >> $HTD_IGNORE.merged
    }
  done
}

htd_find_ignores()
{
  find_ignores=""$(echo $(cat $HTD_IGNORE.merged | \
    grep -Ev '^(#.*|\s*)$' | \
    sed -E 's/^\//\.\//' | \
    grep -v '\/' | \
    sed -E 's/(.*)/ -o -name "\1" -prune /g'))"\
  "$(echo $(cat $HTD_IGNORE.merged | \
    grep -Ev '^(#.*|\s*)$' | \
    sed -E 's/^\//\.\//' | \
    grep '\/' | \
    sed -E 's/(.*)/ -o -path "*\1*" -prune /g'))
  find_ignores="-path \"*/.git\" -prune $find_ignores "
  find_ignores="-path \"*/.bzr\" -prune -o $find_ignores "
  find_ignores="-path \"*/.svn\" -prune -o $find_ignores "
}

htd_grep_excludes()
{
  grep_excludes=""$(echo $(cat $HTD_IGNORE.merged | \
    grep -Ev '^\s*(#.*|\s*)$' | \
    sed -E 's/^\//\.\//' | \
    sed -E 's/(.*)/ --exclude "*\1*" --exclude-dir "\1" /g'))
  grep_excludes="--exclude-dir \"*/.git\" $grep_excludes"
  grep_excludes="--exclude-dir \"*/.bzr\" $grep_excludes"
  grep_excludes="--exclude-dir \"*/.svn\" $grep_excludes"
}

# return paths for names that exist along given path
htd_find_path_locals()
{
  local name path stop_at
  name=$1
  path="$(cd $2;pwd)"
  test -z "$3" && stop_at= || stop_at="$(cd $3;pwd)"
  path_locals=
  while test -n "$path" -a "$path" != "/"
  do
    test -e "$path/$name" && {
        path_locals="$path_locals $path/$name"
    }
    test "$path" = "$stop_at" && {
        break
    }
    path=$(dirname $path)
  done
}


# TODO: move date routines to lib
# NOTE: these use BSD date -v, see GNU date -d
case "$(uname)" in Darwin )
    date_fmt() {
      tags=$(for tag in $1; do echo "-v $tag"; done)
      date $tags +$2
    }
    ;;
  Linux )
    date_fmt() {
      # NOTE patching for GNU date
      tags=$(for tag in $1; do echo "-d $tag" \
          | sed 's/1d/1day/g' \
          | sed 's/7d/1week/g'; done)
      date $tags +$2
    }
    ;;
esac

datelink()
{
  test -z "$1" && datep=$(date "+$2") || datep=$(date_fmt "$1" "$2")
  target_path=$3
  test -d "$(dirname $3)" || error "Dir $(dirname $3) must exist" 1
  test -L $target_path && {
    test "$(readlink $target_path)" = "$(basename $datep)" && {
        return
    }
    printf "Deleting "
    rm -v $target_path
  }
  mkrlink $datep $target_path
}

mkrlink()
{
  # TODO: find shortest relative path
  printf "Linking "
  ln -vs $(basename $1) $2
}

installed()
{
  # Check if binary is available
  local bin="$(jsotk.py -q -O py path $1 tools/$2/bin)"
  test "$bin" = "True" && bin=$2
  test -n "$bin" || {
    return 1
  }
  case "$bin" in
    "["*"]" )
      jsotk.py -O list items $1 tools/$2/bin | while read bin_
      do
        test -n "$bin_" || continue
        test -n "$(eval echo $bin_)" || warn "No value for $bin_" 1
        test -n "$(eval which $bin_)" && return
      done
      ;;
    * )
      test -n "$(eval which $bin)" && return
      #local version="$(jsotk.py objectpath $1 '$.tools.'$2'.version')"
      #$bin $version && return || break
      ;;
  esac
  return 1
}

install_bin()
{
  installed "$@" && return

  # Look for installer
  installer="$(jsotk.py -N -O py path $1 tools/$2/installer)"
  test -n "$installer" || return 3
  test -n "$installer" && {
    id="$(jsotk.py -N -O py path $1 tools/$2/id)"
    test -n "$id" || id="$2"
    debug "installer=$installer id=$id"
    case "$installer" in
      npm )
          npm install -g $id || return 2
        ;;
      pip )
          pip install $id || return 2
        ;;
    esac
  } || {
    jsotk.py objectpath $1 '$.tools.'$2'.install'
  }

  jsotk.py items $1 tools/$2/post-install | while read scriptline
  do
    note "Running '$scriptline'.."
    eval $scriptline || exit $?
  done
}

uninstall_bin()
{
  installed "$@" || return 0

  installer="$(jsotk.py -N -O py path $1 tools/$2/installer)"
  test -n "$installer" || return 3
  test -n "$installer" && {
    id="$(jsotk.py -N -O py path $1 tools/$2/id)"
    debug "installer=$installer id=$id"
    test -n "$id" || id=$2
    case "$installer" in
      npm )
          npm uninstall -g $id || return 2
        ;;
      pip )
          pip uninstall $id || return 2
        ;;
    esac
  }

  jsotk.py items $1 tools/$2/post-uninstall | while read scriptline
  do
    note "Running '$scriptline'.."
    eval $scriptline || exit $?
  done
}

tools_json()
{
  test ./tools.yml -ot ./tools.json \
    || jsotk.py yaml2json ./tools.yml ./tools.json
}


