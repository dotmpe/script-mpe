#!/bin/sh

env_scriptpath_dev ()
{
  # XXX: not sure where/how/why to put this but keeping a cache to capture
  # pipeline result value
  ENV_D_SCRIPTPATH=$UCACHE/user-env/$$-SCRIPTPATH.txt

  support_libs="user-scripts user-scripts-support user-scripts-incubator user-conf script-mpe"

  #base_dirs="$HOME/.basher/cellar/packages/user-tools $HOME/.basher/cellar/packages/dotmpe $HOME/project $VND_GH_SRC/dotmpe $HOME/build/dotmpe $HOME/build/user-tools $HOME/lib/sh"
  # XXX: Prefer dev/build/src location for CI
  base_dirs="$HOME/project /srv/project-local $VND_GH_SRC/user-tools $VND_GH_SRC/dotmpe $HOME/lib/sh $HOME/.basher/cellar/packages/user-tools $HOME/.basher/cellar/packages/dotmpe"

  test -n "${sh_src_base-}" || sh_src_base=/src/sh/lib


  # Pipe interesting paths to SCRIPTPATH-builder
  {
    for basedir in $base_dirs
    do
      for supportlib in $support_libs
      do
        test -d "$basedir/$supportlib" || continue
        echo "$basedir/$supportlib"
      done
    done

    # FIXME: script-path legacy, some for cleanup
    test -d $HOME/bin && echo $HOME/bin
    test -d $HOME/lib/sh && echo $HOME/lib/sh
    test -d $HOME/.conf && echo $HOME/.conf/script

    true

  } | while read path
  do
    for base in "" /script/lib /script /commands /contexts $sh_src_base
    do
      test -d "$path$base" || continue
      realpath "$path$base"
    done
  done | awk '!a[$0]++' | tr '\n' ':' | sed 's/:$/\
  /' | {

    read SCRIPTPATH

    # FIXME: script-path legacy, soem for cleanup
    #test -d $HOME/bin && SCRIPTPATH=$SCRIPTPATH:$HOME/bin
    #test -d $HOME/build/dotmpe/script-mpe && SCRIPTPATH=$SCRIPTPATH:$HOME/build/dotmpe/script-mpe

    test -d $HOME/lib/sh && SCRIPTPATH=$SCRIPTPATH:$HOME/lib/sh
    test -d $HOME/.conf && SCRIPTPATH=$SCRIPTPATH:$HOME/.conf/script

    echo $SCRIPTPATH >"$ENV_D_SCRIPTPATH"
  }
  read SCRIPTPATH_ <"$ENV_D_SCRIPTPATH"
  rm "$ENV_D_SCRIPTPATH"
  unset ENV_D_SCRIPTPATH

  test -n "$SCRIPTPATH" && {

    $LOG "info" "" "Adding to SCRIPTPATH" "$SCRIPTPATH_"
    SCRIPTPATH=$SCRIPTPATH_:$SCRIPTPATH
  } || {

    $LOG "info" "" "New SCRIPTPATH" "$SCRIPTPATH_"
    SCRIPTPATH=$SCRIPTPATH_
  }
  unset SCRIPTPATH_ support_libs base_dirs
  export SCRIPTPATH

}

test -n "${SCRIPTPATH:-}" || env_scriptpath_dev
# Sync: U-S:
