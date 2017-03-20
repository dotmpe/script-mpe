#!/bin/sh
ino__source=$_

# Using Arduino (on Darwin)

set -e

version=0.0.1 # script-mpe



ino_als___V=version
ino_man_1__version="Version info"
ino_spc__version="-V|version"
ino__version()
{
  echo "$(cat $PREFIX/bin/.app-id)/$version"
  app_version=$( basename $(readlink $APP_DIR/Arduino.app) | \
    sed 's/.*Arduino-\([0-9\.]*\).app/\1/' )
  echo "Arduino/$app_version"
}

node_tab=ino.tab


ino_man_1__edit="Edit the main script file"
ino_spc__edit="-E|edit-main"
ino__edit()
{
  locate_name $scriptname || exit "Cannot find $scriptname"
  note "Invoking $EDITOR $fn"
  $EDITOR $fn "$@" $node_tab
}
ino_als___e=edit


ino_man_1__list_ino="List Arduino versions available in APP_DIR"
ino__list_ino()
{
  for path in $APP_DIR/Arduino-*
  do
    basename $path .app \
      | sed 's/^.*Arduino-\([0-9\.]*\)/\1/'
  done
}


ino_man_1__switch="Switch to Arduino version"
ino__switch()
{
  test -n "$1" || err "expected version arg" 1
  cd $APP_DIR || err "cannot change to $APP_DIR" 1
  test -e Arduino-$1.app || err "no version $1" 1
  test -h Arduino.app || err "not a symlink $APP_DIR/Arduino.app" 1
  rm Arduino.app || err "unable to remove symlink $APP_DIR/Arduino.app" 1
  ln -s Arduino-$1.app Arduino.app
}


ino_man_1__list="List sketches"
ino__list()
{
  list__mk_targets Rules.old.mk
}

# list (static) targets in makefile
list__mk_targets()
{
  grep -h '^[a-z0-9]*: [^=]*$' $1 \
    | sed 's/:.*$//' | sort -u | column
}

get_nodes()
{
  fixed_table_hd $node_tab ID PREFIX CORE BOARD DEFINES
}

# Build/upload image for arg1:nodeid reading from $node_tab
ino__build()
{
  test -z "$2" || error "surplus args" 1
  get_nodes | while read vars
  do
    eval local "$vars"
    test -n "$ID" || error \$ID 1
    test "$ID" = "$1" || continue
    test -n "$PREFIX" || error \$PREFIX 1
    test -n "$CORE" || error \$CORE 1
    test -n "$BOARD" || error \$BOARD 1

    test -d "$PREFIX" || error "no dir $PREFIX" 1
    make build \
      INO_PREF=$PREFIX C=$CORE BRD=$BOARD DEFINES="$DEFINES"
  done
}


ino__list_prototype_parts()
{
  ino__list_sketches Prototype Mpe | sort -u \
    | {
      while read ino
      do
        grep '^\/\*\ \*\*\*\ .*\*\*\*\ {{' $ino | \
          sed 's/[^A-Za-z0-9\ ]//g'
      done
    } | sort -u
}

get_sketch()
{
  sketchname=$(basename $1)
  test ! -e "$1/$sketchname.ino" || {
    echo $1/$sketchname.ino
  }
  test ! -e "$1/$sketchname.pde" || {
    echo $1/$sketchname.pde
  }
}

get_sketchname()
{
  case "$(basename $1)" in
    *.ino )
      basename $1 .ino;;
    *.pde )
      basename $1 .pde;;
  esac
}

ino__list_sketch_paths()
{
  test -n "$1" || set -- Mpe Prototype
  while test $# -gt 0
  do
    for path in $1/*
    do
      find $path -iname '*.ino' -o -iname '*.pde'
    done
    shift
  done
}

ino__list_sketches()
{
  { ino__list_sketch_paths | while read path
  do
    get_sketchname $path
  done; } | column
}

# XXX: WIP. on graph with sketches, prototypes later
ino__graph()
{
  export graph=$(realpath ino.gv)
  export sock="$(gv meta print-socket-name)"
  gv bg

  ino__list_sketch_paths | while read path
  do
    sketchname=$(get_sketchname $path)

    gv meta -sq get-node $sketchname && {

        label="$(echo $(gv meta -s get-node-attr "$sketchname" label))"
        echo "Exists $sketchname label=$label"

        fnmatch "*$path*" "$label" \
          && continue \
          || gv meta upate-node "$sketchname" label="$label,$path"

    } || {

        gv meta add-node "$sketchname" label="$path"

        note "Added node for $sketchname"
      }

  done

  info "Closing Bg service"
  gv meta exit
}

ino__list_boards()
{
  cd ~/project/arduino-docs
  make boards
}

ino__read_fuses() # [chip=m328p [method=usbasp]]
{
  test -n "$1" || set -- m328p "$2"
  test -n "$2" || set -- "$1" usbasp
  make _read_fuses C=$1 M=$2
}


ino__esptool_install()
{
  pwd=$(pwd)
  test -x esptool.py || {
    cd ~/project
    test -d esptool || git clone https://github.com/themadinventor/esptool.git
    cd esptool
    sudo python ./setup.py install
  }
  cd $pwd
}

ino__esp_mcu_init()
{
  #/dev/cu.wchusbserial1410
  test -n "$1" || error "expected firmware" 1
  test -e "$1" || error "no firmware: '$1'" 1
  test -n "$2" || error "expected port" 1
  test -e "$2" || error "no port: '$2'" 1
  test -z "$3" || error "surpluss arguments" 1
  esptool.py \
    --port=$2 \
    write_flash \
    -fm=dio -fs=32m \
    0x00000 \
    $1
}



### Main


ino_main()
{
  local scriptpath="$(cd "$(dirname "$0")"; pwd -P)"
  ino_init || return 0

  local scriptname=ino base=$(basename $0 .sh) verbosity=5

  case "$base" in $scriptname )

      local ino_default=version
      ino_lib

      # Execute
      run_subcmd "$@"
      ;;

  esac
}

ino_init()
{
  test -z "$BOX_INIT" || return 1
  test -n "$scriptpath"
  export SCRIPTPATH=$scriptpath
  . $scriptpath/util.sh
  util_init
  . $scriptpath/box.init.sh
  box_run_sh_test
  lib_load main box htd
}

ino_lib()
{
  # -- ino box lib sentinel --
  set --
}

ino_load()
{
  test -n "$UCONFDIR" || UCONFDIR=$HOME/.conf/
  test -n "$INO_CONF" || INO_CONF=$UCONFDIR/ino
  test -n "$APP_DIR" || APP_DIR=/Applications

  hostname="$(hostname -s | tr 'A-Z.-' 'a-z__' | tr -s '_' '_' )"

  test -n "$EDITOR" || EDITOR=vim
  # -- ino box load sentinel --
  set --
}

# Use hyphen to ignore source exec in login shell
if [ -n "$0" ] && [ $0 != "-bash" ]; then
  ino_main "$@"
fi


