#!/bin/sh
script_bats_src="$_"

set -e



version=0.0.4-dev # script-mpe


script_bats_man_1__version="Version info"
script_bats__version()
{
  echo "script-mpe/$version"
}
script_bats_als__V=version


script_bats__specs()
{
  set --
}


script_bats__update()
{
  local path= spec_name= feat_cat=
  for path in test/*-spec.bats
  do
    spec_name= feat_cat= is_spec= for_lib= for_bin=
    script_bats__parse_name "$path"
    falseish "$is_spec" && {
      strerr info "Skipping non-spec $path" ; continue; } || noop
    eval grep -q "'^$spec_name\\s'" features.tab || {
      stderr warn "Missing from features.tab: $path"
    }
    test -n "$feat_cat" || continue
    script_bats__check_prefix "$feat_cat" "$path"
    #echo spec_name=$spec_name
    #echo for_bin=$for_bin
    #echo for_lib=$for_lib
  done
}


script_bats__parse_name()
{
  test_file "$1"
  check_argc 1
  # FIXME: dev this on *nix first
  #var_isset spec_name || local spec_name=
  #var_isset feat_cat || local feat_cat=
  #local bn="$(basename "$1")"
  spec_name="$(basename "$1" -spec.bats | sed 's/^[0-9\.]*_//')"
  feat_cat="$(basename "$1" -spec.bats | sed -E 's/^([0-9\.]+)*(.*)?$/\1/')"
  is_spec=$(fnmatch "*-spec.bats" "$1" && echo 1)
  for_lib=$(fnmatch "*-lib*.bats" "$1" && echo 1)
  for_bin=$(fnmatch "*-lib*.bats" "$1" || { test ! -x "./$spec_name.sh" || echo 1; })
  test -n "$feat_cat" &&
  stderr info "Spec: $feat_cat $spec_name ($1)" ||
  stderr warn "uncategorized: $path"
}


# See if @test descriptions are all prefixed with category
script_bats_man_1__check_prefix='check-prefix PREFIX FILE'
script_bats__check_prefix()
{
  test -n "$1" || error "category prefix expected" 1
  test_file "$2"
  check_argc 2
  grep '^@test\s' "$2"
}

# Create a lookup table from features.tab
script_bats__update_tab()
{
  rm .features.tab || noop
  fixed_table features.tab ID CAT TYPE DOC_REF PREREQ | while read vars
  do
    echo "$vars" >> .features.tab
  done
  # XXX: should have no newlines mucking up things?
  #test "$rec_cnt" = "$(count_lines ".features.sh")" ||
  #  stderr err "Line mismatch"
}

script_bats__features()
{
  newer_than .features.tab features.tab ||
    script_bats__update_tab

}

# Colorize BATS-style TAP output
script_bats__colorize()
{
  # TODO: rename to libexec/
  $scriptpath/bats-color.sh
}


# Main

script_bats_main()
{
  local \
      scriptname=script-bats \
      base="$(basename $0 ".sh")" \
      scriptpath="$(cd $(dirname $0); pwd -P)" \
      failed=
  case "$base" in
    $scriptname )
      local scriptpath="$(dirname $0)"
      script_bats_init || return $?
      run_subcmd "$@" || return $?
      ;;
    * )
      echo "$scriptname: not a frontend for $base"
      exit 1
      ;;
  esac
}


script_bats_init()
{
  test -n "$scriptpath"
  export SCRIPTPATH=$scriptpath
  . $scriptpath/util.sh load-ext
  lib_load
  lib_load table
  # -- htd box init sentinel --
  set --
}

script_bats_lib()
{
  # -- htd box lib sentinel --
  set --
}

# Use hyphen to ignore source exec in login shell
case "$0" in "" ) ;; "-"* ) ;; * )
  # Ignore 'load-ext' sub-command
  test -z "$__load_lib" || set -- "load-ext"
  case "$1" in load-ext ) ;; * )
    script_bats_main "$@"
  ;; esac
;; esac

