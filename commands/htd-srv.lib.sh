htd_man_1__srv='Manage service container symlinks and dirs.

  find-volumes | volumes [SUB]
      List volume container ids (all or with name SUB)

  check
  check-volume Dir
      Verify Dir as either service-container or entry in one.
  list
  update
  init
      ..
  -instances
      List unique local service-containers.
      Plumping with a grep on ls output.
  -names
      List unique service-name part, from all local service-containers.
      Plumbing for a grep on -instances
  -vpaths [SUB]
      List all existing volume paths, or existing SUB paths (all absolute, with sym. parts)
      Plumbing for shell glob-expansion on all local volume container links,
      checking if any given SUB, lower-case SId of SUB, or title-case of SId
      exists as path.
  -paths SUB
      Like -vpaths, but for every service container, not just the roots.
  -disks SUB
      List all existing volume-ids with existing SUB paths.
      See -vpaths, except this returns disk/part index and `pwd -P` for each dir.
'
htd__srv()
{
  test -n "$1" || set -- list
  case "$1" in

    -instances ) shift
        ls /srv/ | grep -v '^\(\(.*-local\)\|volume-\([0-9]*-[0-9]*-.*\)\)$'
      ;;

    -names ) shift
        htd__srv -instances | sed '
            s/^\(.*\)-[0-9]*-[0-9]*-[a-z][0-9a-z]*-[a-z][0-9a-z]*$/\1/g
            s/^\(.*\)-local$/\1/g
          ' | sort -u
      ;;

    -paths ) shift
        for p in /srv/*/ ; do
          htd__name_exists "$p" "$1" || continue
          echo "$p$name"
        done
      ;;

    -vpaths ) shift
        for p in /srv/volume-[0-9]*-[0-9]*-*-*/ ; do
          htd__name_exists "$p" "$1" || continue
          echo "$p$name"
        done
      ;;

    -disks ) shift
        test $# -eq 1 || return 64
        htd__srv -vpaths "$1" | while read vp ; do
          echo $(echo "$vp" | cut -d '-' -f 2-3 | tr '-' ' ') $(cd "$vp" && pwd -P)
        done
      ;;

    find-volumes | volumes ) shift
        test $# -eq 1 || return 64
        htd__srv -vpaths "$1" | cut -d'/' -f3 | sort -u
      ;;

    check ) shift
        # For all local services, we want symlinks to any matching volume path
        htd__srv -names | while read name
        do
          #htd__srv find-volumes "$name"
          htd__srv -paths "$name"
          #htd__srv -vpaths "$name"

          # TODO: find out which disk volume is on, create name and see if the
          # symlink is there. check target maybe.
        done
      ;;

    check-volume ) shift ; test -n "$1" || error "Directory expected" 1
        test -d "$1" || error "Directory expected '$1'" 1
        local name="$(basename "$1")"

        # 1. Check that disk for given directory is also known as a volume ID

        # Match absdir with mount-point, get partition/disk index
        local abs="$(absdir "$1")"
        # NOTE: match with volume by looking for mount-point prefix
        lib_load match
        local dvid=$( htd__srv -disks | while read di pi dp ; do
            test "$dp" = "/" && p_= || match_grep_pattern_test "$dp";
            echo "$1" | grep -q "^$p_\/.*" && { echo $di-$pi ; break ; } || continue
          done )

        #  Get mount-point from volume ID
        local vp="$(echo "/srv/volume-$dvid-"*)"
        local mp="$(absdir "$vp")"
        test -e "$vp" -a -n "$dvid" -a -e "$mp" ||
            error "Missing volume-link for dir '$1'" 1

        # 2. Check that directory is either a service container, or directly
        #    below one. Warn, or fail in strict-mode.

        # NOTE: look for absdir among realpaths of /srv/{*,*/*}

        test "$abs" = "$mp" && {
          true # /srv/volume-*
        } || {

          # Look for each SUB element, expect a $name-$dvid symbol
          local sub="$(echo "$abs" | cut -c$(( 1 + ${#mp} ))-)"
          for n in $(echo "$sub" | tr '/' ' ') ; do
            test "$n" = "srv" && continue
            nl="$(echo "/srv/$n-$dvid-"*)"
            test -e "$nl" && continue || {
              # Stop on the last element, or warn
              test "$n" = "$name" && break || {
                warn "missing $nl for $n"
              }
            }
          done
        }

        # 3. Unless silent, warn if volume is not local, or exit in strict-mode
      ;;

    list ) shift
        test -n "$1" && {
          htd__srv list-volumes "$1"
          htd__srv find-volumes "$1"
        } || {
          htd__srv_list || return $?
        }
      ;;

    update ) shift
        htd__srv init "$@" || return $?
      ;;

    init ) shift
        # Update disk volume manifest, and reinitialize service links
        disk.sh check-all || {
          disk.sh update-all || {
            error "Failed updating volumes catalog and links"
          }
        }
      ;;

    * ) error "'$1'?" 1 ;;

  esac
}

# Volumes for services

htd_man_1__srv_list="Print info to stdout, one line per symlink in /srv"
htd_spc__srv_list="out_fmt= srv-list"
htd_of__srv_list='DOT'
htd__srv_list()
{
  upper=0 default_env out-fmt plain
  out_fmt="$(echo $out_fmt | str_upper)"
  case "$out_fmt" in
      DOT )  echo "digraph htd__srv_list { rankdir=RL; ";; esac
  for srv in /srv/*
  do
    test -h $srv || continue
    cd /srv/
    target="$(readlink $srv)"
    name="$(basename "$srv" -local)"
    test -e "$target" || {
      stderr warn "Missing path '$target'"
      continue
    }
    depth=$(htd__path_depth "$target")

    case "$out_fmt" in
        DOT )
            NAME=$(str_word "$name")
            TRGT=$(str_word "$target")
            case "$target" in
              /mnt*|/media*|/Volumes* )

                  echo "$TRGT [ shape=box3d, label=\"$(basename "$target")\" ] ; // 1.1"
                  echo "$NAME [ shape=tab, label=\"$name\" ] ;"

                  DISK="$(cd /srv; disk.sh id $target)"

                  #TRGT_P=$(str_word "$(dirname "$target")")
                  #echo "$TRGT_P [ shape=plaintext, label=\"$(dirname $target)\" ] ;"

                  test -z "$DISK" ||
                    echo "$TRGT -> $DISK ; // 1.3 "
                  echo "$NAME -> $TRGT ; "
                  #[ label=\"$(basename "$target")\" ] ;"
                ;;
              *)
                  echo "$NAME [ shape=folder, label=\"$name\"] ; // 2.1"
                  test $depth -eq 1 && {

                    TRGT_P=$(str_word "$(dirname "$target")")
                    echo "$TRGT_P [ label=\"$(dirname "$target")\" ] ;"
                    echo "$NAME -> $TRGT_P [ label=\"$(basename "$target")\" ] ;"
                    stderr info "Chain link '$name' to $target"
                  } || {
                    test $depth -gt 1 && {
                      warn "Deep link '$name' to $target"
                    } || {
                      stderr info "Neighbour link '$name' to $target"
                      echo "$NAME -> $TRGT [style=dotted] ;"
                    }
                  } ;;
            esac
          #        echo "$(str_word "$(dirname "$target")") [ label=\"$(dirname $target)\" ]; "
          #        echo "$(str_word "$(dirname "$target")") -> $TRGT ; "
          ;;
    esac

    case "$target" in
      /mnt*|/media*|/Volumes* )
          note "Volume link '$name' to $target" ;;
      * )
          test $depth -eq 1 && {
            stderr info "Chain link '$name' to $target"
          } || {
            test $depth -gt 1 && {
              warn "Deep link '$name' to $target"
            } || {
              stderr info "Neighbour link '$name' to $target"
            }
          } ;;

    esac

  done
  case "$out_fmt" in
      DOT )  echo "} // digraph htd__srv_list";; esac
}
