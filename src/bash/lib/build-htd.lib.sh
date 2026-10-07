#!/bin/sh

# Htd ctx cleanup for build tooling wip


# Initialize Project Build Scripts shell modules
build_htd_lib__load ()
{
  #lib_require date match $package_build_tool || return

  # XXX cleanup lib_load std stdio build-checks

  test -n "${cllct_set_base-}" || cllct_set_base=.cllct/specsets
  test -n "${cllct_src_base-}" || cllct_src_base=.cllct/src
  test -n "${cllct_test_base-}" || cllct_test_base=.cllct/testruns
  test -n "${docbase-}" || docbase="doc/src/sh"
}

build_htd_lib__init ()
{
  lib_require package vc-htd sys-htd logger-std log || return
  ! sys_debug -dev -debug -init ||
    $LOG notice "" "Initialized build-htd.lib" "$(sys_debug_tag)"
}


#  lib_assert \
#      main args date tasks du vc-htd vc match src function functions shell ||
#      return

# Initialize Project Build Scripts settings
# TODO: set spec for build
build_init()
{
  test -n "${base-}" || base=build.lib
  test -n "${build_id-}" || build_id=$(uuidgen)

  test -n "${src_stat-}" || src_stat="$PWD/$cllct_src_base"

  test -n "${sh_list-}" || sh_list="$src_stat/sh-files.list"

  test -n "${TAP_COLORIZE-}" || TAP_COLORIZE="$PWD/script-bats.sh colorize"

  # DEBUG=${REDO_DEBUG-${DEBUG-0}}

  test -n "${project_scm_add_checks-}" ||
      project_scm_add_checks=project_scm_add_checks
  test -n "${project_scm_commit_checks-}" ||
      project_scm_commit_checks=project_scm_commit_checks

  test -n "${package_specs_script_libs-}" ||
      package_specs_script_libs="./\${id}.lib.sh \
                                 ./contexts/\${id}.lib.sh \
                                 ./contexts/ctx-\${id}.lib.sh \
                                 ./commands/\${id}.lib.sh \
                                 ./commands/htd-\${id}.lib.sh"
  test -n "${package_specs_libs-}" ||
    package_specs_libs="$package_specs_script_libs"
  test -n "${package_specs_scripts-}" ||
      package_specs_scripts="./\${id}.sh \
                                 ./\${id} \
                                 ./\${id}.py"

  test -n "${package_build-}" || package_build=redo\ \"\$@\"
  test -n "${package_specs_required-}" ||
      package_specs_required=str\ sys\ os\ std\ args\ shell\ match\ src\ main\ sh\ bash\ redo\ build\ box\ functions\ oshc\ vc\ ck\ schema

  package_lib__init || return
  build_io_init || return
  build_init=ok
}

get_tmpio_env()
{
  test -n "${1-}" -a -n "${2-}" || return
  local tmpf="$( setup_tmpf .$1 "$build_id-$2" )"
  eval "$1=\"$tmpf\""
}

build_io_init()
{
  test -n "${failed-}" || get_tmpio_env failed build-io-init
}

show_spec()
{
  local spec_set="$1" ; shift 1
  eval echo \"\$package_specs_${spec_set}\" | tr -s ' '
}
show_globspec()
{
  show_spec "$1" | sed 's/\${[0-9a-z]*}/\*/g'
}

build_srcfiles()
{
  test -n "${1-}" || return 1
  test -n "${package_paths-}" || package_paths=vc_tracked
  $package_paths "$@"
}

# XXX: redo-ifchanged .cllct/specsets/$1.
expand_spec_src() # Spec-Set [Filter-From]
{
  test -n "${2-}" || set -- "$1" "$cllct_set_base/$1.excludes"
      # | tr ' ' '\n' | xargs -I % echo "'%'" | tr '\n' ' '
  eval build_srcfiles $(
      show_globspec "$1"
    ) | { test -s "$2" && { $ggrep -vf "$2" || return ; } || cat ; }
}

expand_spec_ignores()
{
  local ignore= set_ignore= set_ignore_from=
  ignore="$( show_globspec "ignore" )"
  set_ignore="$( show_globspec "${1}_ignore" )"
  set_ignore_from="$( show_globspec "${1}_ignore_from" )"

  {
    test -z "$set_ignore_from" || cat $ignore_from
    test -z "$set_ignore" || echo "$ignore" | tr ' ' '\n'
    test -z "$ignore" || echo "$ignore" | tr ' ' '\n'
  } | remove_dupes | node_globs2regex
}

build_modified()
{
  vc_modified "$@"
}

# NOTE: direct build spec-set to listfile; not used except for dev,
# redo manages the file. Ie. redo-ifchange "$cllct_set_base/$1.list" instead.
build_list() # Spec-Set
{
  test -n "$1" || return
  expand_spec_src "$1" >"$cllct_set_base/$1.list"
}

# XXX: components, see package.lib

# Lookup Basename-Id for given src file, passed to project-tests this should
# resolve to a test-file path-name.
component_map_basenameid() # SRC-FILE
{
  echo "$(component_id "$@") $1"
}

component_id()
{
  # XXX: test echo "$(basename "$1" .$(filenamext "$1")) $1"
  #filename_baseid "$1"
  basename="$(exts="-spec -lib" basenames "$(filestripext "$1")")"
  mkid "$basename" '' '_-'
  echo "$id"
}

# Checkout from given remote if it is ahead, for devops work on branch & CI.
# Allows to update from amended commit in separate (local/dev) repository,
# w/o adding new commit and (for some systems) getting a new build number.
checkout_if_newer()
{
  test -n "$1" -a -n "$2" -a -n "$3" || error checkout-if-newer.args 1
  test -z "$4" || error checkout-if-newer.args 2

  local behind= url="$(git config --get remote.$2.url)"
  test -n "$url" && {
    test "$url" = "$3" || git remote set-url $2 $3
  } || git remote add $2 $3
  git fetch $2 || return

  git show-ref -q --heads $1 || return # Not a local branch
  git show-ref -q --heads $2/$1 || return # Not at remote

  behind=$( git rev-list $1..$2/$1 --count )
  test $behind -gt 0 && {
    from="$(git rev-parse HEAD)"
    git checkout --force $2/$1
    to="$(git rev-parse HEAD)"
    export BUILD_REMOTE=$2 BUILD_BRANCH_BEHIND=$behind \
        BUILD_COMMIT_RANGE=$from...$to
  }
}

checkout_for_rebuild()
{
  test -n "$1" -a -n "$2" -a -n "$3" || error checkout_for_rebuild-args 1
  test -z "$4" || error checkout_for_rebuild-args 2

  test -n "$BUILD_CAUSE" || export BUILD_CAUSE=$TRAVIS_EVENT_TYPE
  test -n "$BUILD_BRANCH" || export BUILD_BRANCH=$1

  export BUILD_COMMIT_RANGE=$TRAVIS_COMMIT_RANGE
  checkout_if_newer "$@" && export \
    BUILD_CAUSE=rebuild \
    BUILD_REBUILD_WITH="$(git describe --always)"
}

# FIXME: couchdb service data
list_builds()
{
  sd_be=couchdb_sh COUCH_DB=build-log \
      statusdir.sh be doc $package_vendor/$package_id > .tmp.json
  last_build_id=$( jq -r '.builds | keys[-1]' .tmp.json )

  sd_be=couchdb_sh COUCH_DB=build-log \
      statusdir.sh be doc $package_vendor/$package_id:$last_build_id > .tmp-2.json

  #jq -r '.tests[] | ( ( .number|tostring ) +" "+ .name +" # "+ .comment )' .tmp-2.json
  jq -r '.tests[] | "\(.number|tostring) \( if .ok then "pass" else "fail" end ) \(.name)"' .tmp-2.json

  {
    jq '.stats.total,.stats.failed,.stats.passed' .tmp-2.json |
        tr '\n' " "; echo ; } | { read total failed passed

      test 0 -eq $failed && {
          note "Last test $last_build_id passed (tested $passed of $total)"
      } || {
          error "Last test $last_build_id failed $failed tests (passed $passed of $total)"
      }
  }
}

# build-redo-static builds prereq but skips rebuild to speed up during dev.
build_redo()
{
  test ! -e "$1" -o -n "$build_redo_changed" || {

    # Skip build in static-mode
    words_to_lines "$@" | p= s= act=lookup_exists foreach_do && return
    # lookup_exists() # Local-Name [ Base-Dir ]
  }
  scriptpath= redo-ifchange "$@"
}

clean()
{
  test -n "$src_stat" || return
  git clean -dfx $src_stat
}

static()
{
  test -n "$build_id" || build_init

  test -n "$sh_list" || error "Static-Init error" 1
  echo redo-ifchange $sh_list
  redo-ifchange $sh_list

  test -n "$src_stat" || error "Static-Init error" 2
  redo-ifchange $src_stat/sh-libs.list

  # XXX: testing...
  redo-ifchange $src_stat/functions/default-lib.func-list
  redo-ifchange $src_stat/functions/default-lib/default_lib__load.func-deps
  redo-ifchange $src_stat/functions/default-lib/default_init.func-deps
  redo-ifchange $src_stat/functions/default-lib/default_test.func-deps
  # XXX: cannot expand names not there, need static group targets
  #redo-ifchange $src_stat/functions/*.func-list
  #redo-ifchange $src_stat/functions/*/*.func-deps
}

all()
{
  lib_load build-checks && check || return
  build_sh_idx || return
  build_graphs || return
  build_refdocs || return
}

# Build all shell script lib lookup lists
build_sh_idx()
{
  mkdir -p $src_stat/functions
  _inner()
  {
    local id= docid
    docid=$(str_sid "$(basename "$1" .sh)")

    build_redo $src_stat/functions/$docid.func-list || return

    while read -r caller
    do build_redo $src_stat/functions/$docid/$caller.func-deps
    done <$src_stat/functions/$docid.func-list
  }
  expand_spec_src script_libs | p= s= act=_inner foreach_do
}

# Build all graphs
build_graphs()
{
  package_env_req || return

  _inner()
  {
    local id= cid docid
    docid=$(str_sid "$(basename "$1" .sh)")
    cid=$($package_component_name "$1")

    build_redo "$docbase/$docid.calls-1.dot.gv"

    #deps_gv=$docbase/$docid-deps.dot.gv
    #test -e "$deps_gv" \
    #  -a "$deps_gv" -nt "$src_stat/functions/$docid.func-deps" ||
    #{
    #  build_libs_deps_gv "$1" >$deps_gv
    #}
  }
  expand_spec_src script_libs | p= s= act=_inner foreach_do
}

build_package_script_lib_list()
{
  test -n "${package_component_name-}" || { package_env_req || return; }
  test -n "$package_component_name" ||
    $LOG alert "" "Expeccted mapping function" "" 1

  expand_spec_src script_libs |
      p= s= act=$package_component_name foreach_inscol
}

build_components_id_path_map()
{
  package_env_req || return

  $package_components "$@"
}

# Build deps list for one function
# See <src-stat>/functions/<docid>/<func-name>.func-deps
build_lib_func_deps_list()
{
  { copy_function "$1" "$2" | list_sh_calls - | remove_dupes
  } || {
    {
        echo $1 $2
        copy_function "$1" "$2"
        echo calls:
        copy_function "$1" "$2" | list_sh_calls - >&2
    }>&2
    error "parsing callees from $2 '$1'"
    return 2
  }
}

# Build function list for lib
# See <src-stat>/functions/<docid>.func-list
build_lib_func_list() # FILE [FILTER-OUT] [STRIP]
{
  test -e "${1-}" || return 98
  test -n "${2-}" || set -- "$1" '^\s*$' "${3-}"
  test -n "${3-}" || set -- "$1" "$2" '().*$'
  list_functions "$1" | grep -v "$2" | sed 's/'"$3"'//'
}

build_sh_lookup_func_lib() # Func
{
  test -n "$1" || return
  local listname= list=
  list="$( $ggrep -l '^'"$1"'$' "$src_stat"/functions/*.func-list )"
  listname=$(basename "$list" -lib.func-list)
  build_sh_lookup_lib "$listname"
}

# Return sh-lib path given doc-id
build_sh_lookup_lib() # Doc-Id
{
  test -n "$1" || return
  build_redo $src_stat/sh-libs.list || return
  $ggrep '^'"$1"'\>	' "$src_stat/sh-libs.list" | $gsed 's/^[^\t]*\t//g'
}

# List func calls (src/dest-lib, caller/callee) for given lib
build_lib_lib_calls() # Comp-Id Lib-Path
{
  test -n "$1" -a -n "$2" || error "build-lib-lib-calls args '$*'" 1
  build_redo $src_stat/functions/$1.func-list || return

  local comp_id="$1" lib="$2"

  while read -r caller
  do
    build_redo $src_stat/functions/$1/$caller.func-deps
    test -s $src_stat/functions/$1/$caller.func-deps || continue

    while read -r callee
    do
        destlib=$(build_sh_lookup_func_lib "$callee") || continue

        test -e "$destlib" || continue
        test -e "$destlib" || destlib=-

        echo "$lib $caller $destlib $callee"

    done <"$src_stat/functions/$1/$caller.func-deps"
  done <"$src_stat/functions/$1.func-list"
}

# XXX:
build_refdocs()
{
  _inner()
  {
    filename_baseid "$1" ; base_id="$id"
    comp_id="$$(package_component_name "$1")"

    #note "Inner: '$*' $base_id $comp_id"
    #test -e "$cid.do" || continue

    test -e "$comp_id.rst" && {
        echo redo "$docbase/$comp_id.do"
    } || true

    return

    doc=$docbase/$docid.rst
    test -e $doc || {
        echo ".. figure:: /$docbase/$docid-deps.dot.svg" > $doc
    }

    # Separate third-party from locally installed execs
    test -e "$scriptpath/$execname" && {

      # TODO make .build/docs/bin/$execname.html
      echo $execname

    } || {

      # TODO: check/compile into tools.yaml
      echo $execname
    }
  }
  # Generate:
  #   per command man pages
  # TODO: generate docs, either from tools.yaml, project.yaml

  expand_spec_src script_libs | p= s= act=_inner foreach_do
}


# Plot internal lib func calls
build_docs_src_sh_calls_1_gv()
{
  echo "digraph sh_libs_calls_1__gv {"
  echo "  rankdir=LR"
  { test -n "$1" && words_to_lines "$@" || expand_spec_src script_libs
  } | p= s= act=build_doc_src_sh_calls_1_gv_inner foreach_do
  echo "}"
}
build_doc_src_sh_calls_1_gv()
{
  echo "digraph sh_lib_calls_1__gv {"
  echo "  rankdir=LR"
  build_doc_src_sh_calls_1_gv_inner "$@"
  echo "}"
}

build_doc_src_sh_calls_1_gv_inner()
{
  test -n "$2" || set -- "$1" "$(build_sh_lookup_lib "$1")"

  local compid="$1" lib="$2"

  #build_lib_lib_calls "$compid-lib" "$2" | p= s= act=build_lib_call_gv foreach_do

  build_lib_lib_calls "$compid-lib" "$2" | while read -r src caller dest callee
  do
    build_lib_call_gv "$src" "$caller" "$dest" "$callee"
  done
}

build_lib_call_gv_cluster() # Src-Lib Src-Func Dest-Lib Dest-Func
{
  local srclib="$(basename "$1")" caller="$2" destlib="$(basename "$3")" callee="$4"

  test "$srclib" = "$destlib" && return
}

build_lib_call_gv() # Src-Lib Src-Func Dest-Lib Dest-Func
{
  local srclib="$(basename "$1")" caller="$2" destlib="$(basename "$3")" callee="$4"

  local _{,s}{2,4} {src,dest{,v}}id lower=true
  str_vword _2 "$2"
  str_vword _4 "$4"
  _s2=$(str_sid "$2" - -)
  _s4=$(str_sid "$4" - -)
  srcid=$(str_sid "$(basename "$srclib" .sh)")
  destid=$(str_sid "$(basename "$destlib" .sh)")
  str_vword destvid "$(basename "$destlib" .sh)"

  echo "  graph [ fontname=\"times bold\"; fontsize=14; label=\"$srcid <$srclib>\"; ]"

  #echo "  color=black; fontname=\"times\"; "
  echo "  node [ fontsize=12.0, shape=ellipse ];"
  test "$srclib" = "$destlib" && {

    echo "  $_2 [ label=\"$_s2\", href=\"/$docbase/$srcid.rst#$_s2\" ]"
    echo "  $_4 [ label=\"$_s4\", href=\"/$docbase/$srcid.rst#$_s4\"  ]"
    echo "  $_2 -> $_4 [ weight=1.2 ]"
  } || {

    case "$destlib" in std.lib.sh | str.lib.sh | os.lib.sh ) return 0 ;; esac
    #return # XXX: inter-lib deps still makes it too dense, need smaller ndoes

    echo "  $_2 [ label=\"$_s2\", href=\"/$docbase/$srcid.rst#$_s2\" ]"
    echo "  node [ fontsize=9.0, shape=plaintext ];"
    echo "  subgraph cluster_$destvid {"
    echo "    color=grey; fontname=\"times bold\";"
    echo "    label=\""$destlib"\";"
    echo "    $_4 [ label=\"$_s4\", href=\"/$docbase/$destid.rst#$_s4\"  ]"
    echo "  }"
    echo "  $_2 -> $_4 [ weight=0.1, color=grey ]"
  }
}


# Deps to other libs, don't plot funcnames
build_libs_deps_gv()
{
  _gv_tpl_inner()
  {
    docid=$(str_sid "$(basename "$1" .sh)")
    #note "Build-Libs-Deps-Gv: $1 ($sid)"

    build_lib_lib_calls "$docid" "$1" | while read -r srclib caller destlib callee
    do
      build_lib_lib_dep_gv "$(basename "$srclib")" "$(basename "$destlib")"
    done
  }

  echo "digraph libs_deps_gv {"
  echo "  rankdir=LR"
  { test -n "$1" && words_to_lines "$@" || expand_spec_src script_libs
  } | p= s= act=_gv_tpl_inner foreach_do | sort -u
  echo "}"
}

# Plot lib to lib
build_lib_lib_dep_gv() # Src-Lib Dest-Lib
{
  test "$1" = "$2" && return

  str_vword _1 "$1"
  str_vword _2 "$2"
  srcid=$(str_sid "$(basename "$1" .sh)")
  destid=$(str_sid "$(basename "$2" .sh)")

  echo " $_1 [ label=\"$1\", href=\"/$docbase/$srcid.rst\" ]"
  echo " $_2 [ label=\"$2\", href=\"/$docbase/$destid.rst\"  ]"
  echo " $_1 -> $_2 "
}

build_coverage()
{
  _kcov()
  {
    test -x "$(which kcov)" && {

      kcov "$@" || return
    } || {

      docker run --security-opt seccomp=unconfined \
          --workdir /dut -v $PWD:/dut dotmpe/treebox:dev kcov "$@" || return
    }
  }

  _kcov \
      --exclude-pattern='.list,.func-deps,.func-list' \
      --exclude-path='/usr/local,/dut/.cllct/kcov,/dut/.git,/dut/doc,/dut/vendor,/dut/node_modules,/tmp/' \
      .cllct/kcov "$@" || return
}

# Copy local statusdir index to local cache
build_sd_cache () # Index-Name Prefix [Cache-Name]
{
  test $# -gt 2 || set -- "$1" "$2" "$1"
  local index table="${2:-}${2+"-"}$1" verbose=${DEBUG+"v"}
  index="$(statusdir_lookup index "$table")" || return
  test -n "$index" || index=.meta/stat/index/"$table"
  test -d .meta/cache/ || mkdir -p$verbose .meta/cache/ >&2
  test -s "$index" || return 0
  cat $index > .meta/cache/$3
}

build_sd_commit () # Cache-Name Prefix [Index-Name]
{
  test $# -gt 2 || set -- "$1" "$2" "$1"
  local index table="${2:-}${2+"-"}$3" verbose=${DEBUG+"v"}
  index="$(statusdir_lookup index "$table")" || return
  test -n "$index" || index=.meta/stat/index/"$table"
  test -d "$(dirname "$index")" || mkdir -p$verbose "$(dirname "$index")" >&2
  # TODO: should merge with index, not overwrite
  cat ".meta/cache/$1" >"$index"
}

build_conv_list () # Src-Exts Trgt-Ext [Src-Dir [Trgt-Dir ]] -- Paths...
{ false
}
build_conv_table () # ...?
{ false
}

build_context_to_index () # Context.list
{ false
}

#
