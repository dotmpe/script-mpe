#!/bin/sh


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


req_htdir()
{
  test -n "$HTDIR" -a -d "$HTDIR" || return 1
}

# Check if binary is available for tool
installed()
{
  test -e "$1" || error installed-arg1 1
  test -n "$2" || error installed-arg2 1
  test -z "$3" || error "installed-args:$3" 1

  # Get one name if any
  local bin="$(jsotk.py -O py path $1 tools/$2/bin)"
  test "$bin" = "True" && bin="$2"
  test -n "$bin" || {
    warn "Not installed '$2' (bin/$bin)"
    return 1
  }

  case "$bin" in
    "["*"]" )
        local k="htd:installed:$1:$2"
        stderr ok "$sd_be($k): $(statusdir.sh set "$k" 0 180)"

        # Or a list of names
        jsotk.py -O py items $1 tools/$2/bin | while read bin_
        do
          test -n "$bin_" || continue
          test -n "$(eval echo "$bin_")" || warn "No value for $bin_" 1
          test -n "$(eval which $bin_)" && {
            statusdir.sh incr "htd:installed:$1:$2"
          }
        done

        count=$(statusdir.sh get htd:installed:$1:$2)
        test -n "$count" -a 0 -ne $count || return 1

        return 0;
      ;;
  esac

  test -n "$(eval echo "$bin")" || warn "No value for $bin" 1
  test -n "$(eval which $bin)" && return
  #local version="$(jsotk.py objectpath $1 '$.tools.'$2'.version')"
  #$bin $version && return || break

  return 1;
}

install_bin()
{
  test -e "$1" || error install-bin-arg1 1
  test -n "$2" || error install-bin-arg2 1
  test -z "$3" || error "install-bin-args:$3" 1

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
          pip install --user $id || return 2
        ;;
      git )
          url="$(jsotk.py -N -O py path $1 tools/$2/url)"
          test -d $HOME/.htd-tools/cellar/$id || (
            git clone $url $HOME/.htd-tools/cellar/$id
          )
          (
            cd $HOME/.htd-tools/cellar/$id
            git pull origin master
          )
          bin="$(jsotk.py -N -O py path $1 tools/$2/bin)"
          src="$(jsotk.py -N -O py path $1 tools/$2/src)"
          test -n "$src" || src=$bin
          (
            cd $HOME/.htd-tools/bin
            test ! -e $bin || rm $bin
            ln -s $HOME/.htd-tools/cellar/$id/$src $bin
          )
        ;;
    esac
  } || {
    jsotk.py objectpath $1 '$.tools.'$2'.install'
  }

  jsotk.py items $1 tools/$2/post-install | while read scriptline
  do
    scr=$(echo $scriptline | cut -c2-$(( ${#scriptline} - 1 )) )
    note "Running '$scr'.."
    eval $scr || exit $?
  done
}

uninstall_bin()
{
  test -e "$1" || error uninstall-bin-arg1 1
  test -n "$2" || error uninstall-bin-arg2 1
  test -z "$3" || error uninstall-bin-args 1

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
  test -e $HTD_TOOLSFILE || return $?
  test $HTD_TOOLSFILE -ot $B/tools.json \
    || jsotk.py yaml2json $HTD_TOOLSFILE $B/tools.json
}

tools_json_schema()
{
  default_env Htd-ToolsSchemaFile ~/bin/schema/tools.yml
  test -e $HTD_TOOLSSCHEMAFILE || return $?
  test $HTD_TOOLSSCHEMAFILE -ot $B/tools-schema.json \
    || jsotk.py yaml2json $HTD_TOOLSSCHEMAFILE $B/tools-schema.json
}


tools_list()
{
  echo $(
      jsotk.py -O lines keys $B/tools.json tools || return $?
    )
}


htd_report()
{
  # leave htd_report_result to "highest" set value (where 1 is highest)
  htd_report_result=0

  while test -n "$1"
  do
    case "$1" in

      passed )
          test $passed_count -gt 0 \
            && info "Passed ($passed_count): $passed_abbrev"
        ;;

      skipped )
          test $skipped_count -gt 0 \
            && {
              note "Skipped ($skipped_count): $skipped_abbrev"
              test $htd_report_result -eq 0 -o $htd_report_result -gt 4 \
                && htd_report_result=4
            }
        ;;

      error )
          test $error_count -gt 0 \
            && {
              error "Errors ($error_count): $error_abbrev"
              test $htd_report_result -eq 0 -o $htd_report_result -gt 2 \
                && htd_report_result=2
            }
        ;;

      failed )
          test $failed_count -gt 0 \
            && {
              warn "Failed ($failed_count): $failed_abbrev"
              test $htd_report_result -eq 0 -o $htd_report_result -gt 3 \
                && htd_report_result=3
            }
        ;;

      * )
          error "Unknown $base report '$1'" 1
        ;;

    esac
    shift
  done

  return $htd_report_result
}

htd_passed()
{
  test -n "$passed" || error htd-passed-file 1
  stderr ok "$1"
  echo "$1" >>$passed
}

htd_main_files()
{
  for x in "" .txt .md .rst
  do
    for y in ReadMe main ChangeLog index doc/main docs/main
    do
      for z in $y $(str_upper $y) $(str_lower $y)
      do
        test -e $z$x && printf "$z$x "
      done
    done
  done
}

# Build a table of paths to env-varnames, to rebuild/shorten paths using variable names
htd_topic_names_index()
{
  test -n "$1" || set -- pathnames.tab
  { test -n "$UCONFDIR" -a -s "$UCONFDIR/$1" && {
    local tmpsh=$(setup_tmpf .topic-names-index.sh)
    { echo 'cat <<EOM'
      read_nix_style_file "$UCONFDIR/$1"
      echo 'EOM'
    } > $tmpsh
    $SHELL $tmpsh
    rm $tmpsh
  } || { cat <<EOM
/ ROOT
$HOME/ HOME
EOM
    }
  } | uniq
}

# migrate lines matching tag to to another file, removing the tag
# htd-move-tagged-and-untag-lines SRC DEST TAG
htd_move_tagged_and_untag_lines()
{
  test -e "$1" || error src 1
  test -n "$2" -a -d "$(dirname "$2")" || error dest 1
  test -n "$3" || error tag 1
  test -z "$4" || error surplus 1
  # Get task lines with tag, move to buffer without tag
  set -- "$1" "$2" "$(echo $3 | sed 's/[\/]/\\&/g')"
  grep -F "$3" $1 |
    sed 's/^\ *'"$3"'\ //g' |
      sed 's/\ '"$3"'\ *$//g' |
        sed 's/\ '"$3"'\ / /g' > $2
  # echo '# vim:ft=todo.txt' >>$buffer
  # Remove task lines with tag from main-doc
  grep -vF "$3" $1 | sponge $1
}

# migrate lines to another file, ensuring tag by strip and re-add
htd_move_and_retag_lines()
{
  test -e "$1" || error src 1
  test -n "$2" -a -d "$(dirname "$2")" || error dest 1
  test -n "$3" || error tag 1
  test -z "$4" || error surplus 1
  test -e "$2" || touch $2
  set -- "$1" "$2" "$(echo $3 | sed 's/[\/]/\\&/g')"
  cp $2 $2.tmp
  {
    # Get tasks lines from buffer to main doc, remove tag and re-add at end
    grep -Ev '^\s*(#.*|\s*)$' $1 |
      sed 's/^\ *'"$3"'\ //g' |
        sed 's/\ '"$3"'\ *$//g' |
          sed 's/\ '"$3"'\ / /g' |
            sed 's/$/ '"$3"'/g'
    # Insert above existing content
    cat $2.tmp
  } > $2
  echo > $1
  rm $2.tmp
}

htd_migrate_tasks()
{
  info "Migrating tags: '$tags'"
  echo "$tags" | words_to_lines | while read tag
  do
    test -n "$tag" || continue
    case "$tag" in

      +* | @* )
          buffer=$(htd__tasks_buffers $tag | head -n 1 )
          fileisext "$buffer" $TASK_EXTS || continue
          test -s "$buffer" || continue
          note "Migrating prj/ctx: $tag"
          htd_move_and_retag_lines "$buffer" "$1" "$tag"
        ;;

      * ) error "? '$?'"
        ;;
      # XXX: cleanup
      @be.src )
          # NOTE: src-backend needs to keep tag-id before migrating. See #2
          #SEI_TAGS=
          #grep -F $tag $SEI_TAG
          noop
        ;;
      @be.* )
          #note "Checking: $tag"
          #htd__tasks_buffers $tag
          noop
        ;;
    esac
  done
}

htd_remigrate_tasks()
{
  test -n "$1"  || error todo-document 1
  note "Remigrating tags: '$tags'"
  echo "$tags" | words_to_lines | while read tag ; do
    test -n "$tag" || continue
    case "$tag" in

      +* | @* )
          buffer=$(htd__tasks_buffers "$tag" | head -n 1)
          fileisext "$buffer" $TASK_EXTS || continue
          note "Remigrating prj/ctx: $tag"
          htd_move_tagged_and_untag_lines "$1" "$buffer" "$tag"
        ;;

      * ) error "? '$?'"
        ;;

      # XXX: cleanup
      @be.* )
          #note "Committing: $tag"
          #htd__tasks_buffers $tag
          noop
        ;;

    esac
  done
}


# htd-archive-path-format DIR FMT
htd_archive_path_format()
{
  test -d "$1" || error htd-archive-path-format 1
  fnmatch "*/" "$1" || set -- "$(strip_trail $1)"
  # Default pattern: "$1/%Y-%m-%d"
  test -n "$ARCHIVE_FMT" || {
    test -n "$Y" || Y=/%Y
    test -n "$M" || M=-%m
    test -n "$D" || D=-%d
    # XXX test -n "$EXT" || EXT=.rst
    #ARCHIVE_BASE=$1$Y
    #ARCHIVE_ITEM=$M$D$EXT
    ARCHIVE_FMT=$Y$M$D$EXT
  }
  test -n "$2" || set -- "$1" "$ARCHIVE_FMT"
  f=$1/$2
  echo $1/$2
}


htd_doc_ctime()
{
  grep -i '^:Created:\ [0-9:-]*$' $1 | awk '{print $2}'
}

htd_doc_mtime()
{
  grep -i '^:Updated:\ [0-9:-]*$' $1 | awk '{print $2}'
}


htd_output_format_q()
{
  test -z "$q" || return
  test -n "$of" || error "of env" 1
  test -z "$out_f" -o -n "$f" || error "f env" 1
  case "$out_fmt" in
    list ) test -n "$out_f" && q=0.9 || q=0.5 ;;
    csv | tab )
        test -n "$out_f" && q=0.9 || q=0.5
      ;;
    json ) q=1.0 ;;
    yaml ) q=1.2 ;;
    txt | rst ) q=1.1 ;;
  esac
}

# [remove-swap] vim-swap <file>
vim_swap()
{
  local swp="$(dirname "$1")/.$(basename "$1").swp"
  test ! -e "$swp" || {
    trueish "$remove_swap" && rm $swp || return 1
  }
}


htd_repository_url() # remote url
{
  # Disk on local host
  fnmatch "$hostname.*" "$1" && {

    # Cancel if repo is local checkout
    test "$(cd "$2" && pwd -P)" = "$(pwd -P)" && return 1

    # Use URL as is, remove host from remote
    remote=$(echo $1 | cut -f2 -d'.')
    return 0

  } || {

    # Add hostname for remote disk
    { fnmatch "/*" "$2" || fnmatch "~/*" "$2"
    } || return
    remote=$(echo $1 | cut -f2 -d'.')
    url=$(echo $1 | cut -f1 -d'.'):$2
  }
}
