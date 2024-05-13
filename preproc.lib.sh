#!/usr/bin/env bash

preproc_lib__load()
{
  true "${CACHE_DIR:=${STATUSDIR_ROOT:?}cache}"
}


# List values for include-type pre-processor directives from file and all
# included files (recursively).
preproc_includes_list () # ~ <Ref-resolver-> <File>
{
  local resolve_fileref=${1:-src_htd_resolve_fileref}
  shift 1 || return ${_E_GAE:?}
  preproc_recurse preproc_includes $resolve_fileref 'echo "$file"' "$@"
}

preproc_recurse () # ~ <Generator> <Resolve-fileref> <Action-cmd> <Source...>
{
  local select="${1:?}" refres="${2:?}" act="${3:?}"
  shift 3 || return ${_E_GAE:?}
  grep_f=-HnPo "$select" "$@" | while IFS=$':\n' read -r srcf srcl ref
  do
    file=$($refres "$ref" "$srcf") || {
      $LOG alert :preproc-recurse "Resolve failure" \
          "E$?:$select:$refres:$act::$srcf:$srcl:$ref" $? || return
    }
    eval "$act"
    preproc_recurse "$select" "$refres" "$act" "$file" || true
  done
}

preproc_run () # ~ <source-file> <cache-handler> <read-handler> <file-res-handler>
{
  ! grep -q '^#include\ ' "${1:?}" && {
    return
  } || {
    declare cache_file ref res=${4:-src_htd_resolve_fileref}
    cache_file=$("${2:?}" "${1:?}") || return

    stderr echo "cache: $cache_file"
    stderr wc -l "$cache_file"* || true

    test ! -e "$cache_file.lock" ||
        $LOG error : "Lock exists" "$cache_file:$*" $? || return

    >| "$cache_file.sources" \
    preproc_recurse preproc_includes "$res" 'echo "$file"' "${1:?}" &&

    while read -r include_file
    do
      preproc_run "$include_file" "${2:?}" "${3:?}" "$res" || return
    done < "$cache_file.sources" &&

    stderr echo "Sources: $(< "$cache_file.sources")"

    < "$cache_file.sources" \
    os_up_to_date "$cache_file" &&
    $LOG info : "Cache is up to date" "$cache_file" || {
      stderr echo "Generating $cache_file.preproc bc OOD sources"
      touch "$cache_file.lock"
      preproc_read_include=${3:?} preproc_expand "" "$1" >| "$cache_file.preproc" ||
        ignore_sigpipe || return
      stderr file -s "$cache_file"*
      $LOG info : "TODO: Updated cache" "$cache_file"
      rm "$cache_file.lock"
    }
  }
}

preproc_lines () # [grep_f] ~ <Dir-match> [<File|Grep-argv>] # Select only preprocessing lines
{
  local grep_re=${1:-"\K[\w].*"}; test $# -eq 0 || shift
  grep ${grep_f:--Po} '^#'"$grep_re" "$@"
}

preproc_includes () # [grep_f] ~ [<File|Grep-argv>] # Select args for preproc lines
{
  preproc_lines 'include \K.*' "$@"
}

# Recursively resolve include directives and output as TSV. The table columns
# are source file plus line number, reference, and resolved file path for
# reference.
preproc_includes_enum () # ~ <Resolver-> <File|Grep-argv...>
{
  local resolve_fileref=${1:-src_htd_resolve_fileref}; shift 1
  preproc_recurse \
    preproc_includes \
      $resolve_fileref 'echo -e "$srcf\t$srcl\t$ref\t$file"' "$@"
}

preproc_expand () # ~ <Resolver-> <File>
{
  # TODO: fix caching
  preproc_expand_1_sed "${@:?}"

  # TODO: apply recursively
  #preproc_expand_2_awk "${@:?}"
}

# Replace include directives with file content, using two sed's and two
# functions to resolve and dereference the file. See preproc-resolve-sedscript
preproc_expand_1_sed () # ~ <Resolver-> <File|Grep-argv...>
{
  local lk=${lk:-}:expand-preproc:sed1 sc
  preproc_expand_1_sed_script "$@" || return
  $LOG debug :preproc:expand-sed1 "Sed script prepared" "$sc"
  ${preproc_read_include:-read_nix_data} "${2:?}" | {
    $LOG debug :preproc:expand-sed1 "Reader started, initializing Sed script" \
      "$preproc_read_include:$2:$sc"
    "${gsed:?}" -f "$sc" - ||
      $LOG error $lk "Error executing sed script" "E$?:($#):$*" $? || return
  }
}
preproc_expand_1_sed_script ()
{
  local fn=${2//[^A-Za-z0-9\.:-]/-}
  sc=${CACHE_DIR:?}/$fn.sed1
  # Get include lines, reformat to sed commands, and execute sed-expr on input
  local resolve_fileref=${1:-src_htd_resolve_fileref}
  preproc_resolve_sedscript "$resolve_fileref" "${2:?}" >| "$sc" ||
      $LOG error $lk "Error generating sed script" "E$?:($#):$*" $? || return
}

preproc_expand_2_awk () # ~ <Directive-tag> <File>
{
  # Awk does not leave sentinel line.
  awk -v HOME=$HOME -v v=${verbosity:-${v:-3}} '
    function insert_file (file)
    {
        if (v > 4)
            print "Reading \""file"\" for "FILENAME"..." >> "/dev/stderr"
        gsub(/~\//,HOME"/",file)
        if (system("[ -s \""file"\" ]") == 1) {
            if (v > 2)
                print "No such include for "FILENAME" named "file >> "/dev/stderr"
            exit 4
        }
        if (file in sources) {
            if (v > 2)
                print "Recursion from "FILENAME" into already loaded "file >> "/dev/stderr"
            exit 3
        }
        sources[file]=1
        while (getline line < file)
            print line
        close(file)
        if (v > 5)
            print "Closed \""file"\"" >> "/dev/stderr"
    }
    /#'"${1:-include}"'/ { insert_file($2); next; }
  ' "${2:?}"
}

preproc_hasdir () # ~ <Dir-match> <File|Grep-argv...>
{
  local dir=${1:?}; shift
  grep -q '^[ \t]*#'"$dir"' ' "$@"
}

# Generate Sed script to assemble file with include preproc directives.
# Like preproc
preproc_resolve_sedscript () # ~ <Resolver> [<File>] # Generate Sed script
{
  local resolve_fileref=${1:-src_htd_resolve_fileref}; shift 1
  preproc_recurse \
    preproc_includes \
      $resolve_fileref preproc_resolve_sedscript_item "$@"
}

preproc_resolve_sedscript_item ()
{
  ref_re="$(match_grep "$ref")"
  test "${preproc_read_include:-file}" = file && {
    printf '/^[ \\t]*#include\ %s/r %s\n' "$ref_re" "$file"
    # Replace directive with 'from' filepath line
    printf 's/^[ \\t]*#include\ \(%s\)/#from\ \\1/\n' "$ref_re"
  } || {
    printf '/^[ \\t]*#include\ %s/e %s' "$ref_re" "${preproc_read_include:?}"
    printf ' "%s"' "$ref" "$file" "$srcf" "$srcl"
    printf '\n'
    # Replace directive with 'from-include' name line
    printf 's/^[ \\t]*#include\ \(%s\)/#from-include\ \\1/\n' "$ref_re"
  }
  # XXX: cleanup directives
  #printf 's/^[ \t]*#\(include\ %s\)/#-\1/g\n' "$ref_re"
  #printf 's/^#include /#included /g\n'
}

# Resolve include reference to use,
#from file, echo filename with path. If cache=1 and
# this is not a plain file (it has its own includes), give the path to where
# the fully assembled, pre-processed file should be instead.
# XXX: should consolidate function into preproc or some U-S lib collection
# eventually
src_htd_resolve_fileref () # [cache=0,cache_key=def] ~ <Ref>
{
  local fileref

  [[ "${1:?}" =~ /^([\<\"])(.*)[\>\"]$/ ]] && {
    test "${BASH_REMATCH[1]}" = '"' && {
      set -- src_htd_resolve_pathref "${BASH_REMATCH[2]}" "${2-}"
    } || {
      test "${BASH_REMATCH[1]}" = "<" &&
        set -- src_htd_resolve_include "${BASH_REMATCH[2]}" "${2-}"
    }
    "$@"
    return
  }

  # test "$" = "${1:1:1}" ...

  # Ref must be absolute path (or var-ref), or we prefix the file's basedir
  fnmatch "[/~]*" "$1" \
      && fileref=$1 \
      || fileref=$(dirname -- "$2")/$1 # make abs path

  #file="$(eval "echo \"$fileref\"" | sed 's#^\~/#'"${HOME:?}"'/#')" # expand vars, user
  file=$(os_normalize "${fileref/#~\//${HOME:?}/}") &&
  test -e "$file" || {
    $LOG warn :src-htd:resolve-fileref "Cannot resolve reference" "ref:$1 file:$file"
    return 9
  }
  echo "$file"
# FIXME:
  #{ test ${cache:-0} -eq 1 && grep -q '^ *#'"${3:?}"' ' "$file"
  #} \
  #    && echo "TODO:$file" \
  #    || echo "$file"
}

src_htd_resolve_pathref () # ~ <Name> <Context> [<Extensions>]
{
  test -e "${1:?}" || {
    for ext in "${@:1}"
    do test -e "$1.$ext" && { echo "$1.$ext"; break; }
    done
  }

  test -e "$1" || { $LOG error "preproc" "Cannot find include '$1'" ; exit 1; }
  echo "$1"
}

src_htd_resolve_include () # ~ <ID> [<Global>] [<PATH>] [<Exts...>]
{
  local ID="${1:?}" Lookup_Path="${3:-$SCRIPTPATH}" ; shift 3 || true

  test -n "$*" || set -- .inc.sh

    f_inc_path="$( echo "$Lookup_Path" | tr ':' '\n' | while read sp
      do
        for ext in "$@"
        do
          test -e "$sp/$ID.$ext" || continue
          echo "$sp/$ID.$ext"
          break
        done
      done )"

    test -n "$f_inc_path" || { $LOG error "preproc" "No path for global include '$1'" ; exit 1; }
}

preproc_define_r='^\ *#\ *define\ ([^\ ]*)\ (.*)$'
preproc_include_r='^\ *#\ *include\  *(.+)$'

preproc_runner () # (s) ~ # Rewrite stream
{
  declare lnr=0 directive= args_rx_ref= args_arr= \
    lk=:preproc-runner lctx
  while read -r line
  do
    lnr=$(( lnr + 1 ))
    [[ "$line" =~ ^\ *#([^\ ]+).*$ ]] && {
      directive="${BASH_REMATCH[1]}"
      lctx=$lnr:$directive

      # Validate line using regex
      args_rx_ref="preproc_${directive}_r"
      test -n "${!args_rx_ref}" ||
      sh_fun preproc_d_"$directive" || $LOG error $lk \
          "Unknown '$directive' preproc instruction at $lnr" "" 1 || return

      [[ "$line" =~ ${!args_rx_ref} ]] && {
        $LOG info $lk "Processing '$directive' at $lnr"
        args_arr=("${BASH_REMATCH[@]}")
        unset -v "args_arr[0]"
        preproc_d_"$directive" "${args_arr[@]}" || $LOG error $lk \
          "Non-zero status while running directive" E$?:$lctx $? || return

      } || $LOG error $lk "Illegal arguments" $lctx 1 || return
      continue
    }

    echo "$line"
  done
}

# XXX: look at var_update
preproc_d_define () # ~ <Varname> <Value>
{
  eval $1=$2
  $LOG note "preproc:define" "New value" "$1='${!1}'"
}

# Resolve path and produce contents
preproc_d_include () # ~ <Ref> <...>
{
  declare fileref
  fileref=$(src_htd_resolve_fileref "${@:?}") || return
  $LOG note "preproc:preproc" "Pre-processing..." "$fileref"
  "${pp_rd:-src_reader_}" "$fileref" &&
  if_ok "$(sh_caller 1)" &&
  "$_" || return
  $LOG debug "preproc:preproc" "Pre-processed" "$fileref"
}
