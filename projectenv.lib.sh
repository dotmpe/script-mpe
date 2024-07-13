#!/bin/sh



projectenv_lib__load ()
{
  test -n "$build_errors" ||
    export build_errors=build/$scriptname.failed
  mkdir -vp $(dirname $build_errors)
  test ! -e "$build_errors" || rm $build_errors
}


project_env_bin()
{
  local key= bin=

  for id in $@
  do
    key=bin_$(printf -- "$id" | tr '-' '_')
    test -z "$(eval echo \$$key)" && bin=$id || bin="$(eval echo \$$key)"
    export projectenv_dep_$id=$( test -x "$(which $bin)" && echo 1 || echo 0 )
  done
}


# FIXME: unused SCRIPT-MPE-5 projectenv.lib.sh
# Given a variable holding the environments requirements,
# expand that string to include all dependencies. Meanwhile looking for env
# settings, functions or files and exporting projectenv_dep_<id>=... where found.
prepare_env()
{
  local list="$1"
  shift

  # Expand implied dependencies provided by main tags
  expand_item $list sugarcrm-site sugarcrm-db
  expand_item $list sugar-project project-project
  expand_item $list remote-project project-project

  # Expand pre-requisite deps
  export $list="$( expand_deps $list | words_to_unique_lines | lines_to_words )"

  # Check/cache each
  # XXX: try_var "$list"
  export $(for id in $value
    do
      out="$( provided_by_env $id || continue )"
      test -n "$out" && echo $id=$out
      str_vword id
      echo projectenv_dep_$id=1
    done)
}


# Check env for feature tag-id availability. See Mango-builds/tests/bats/ main.rst
require_env()
{
  for dep in $@
  do
    provided_by_env "$dep" || {

      fnmatch "* $dep *" " $Project_Env_Requirements " && {
        echo "Required dependency '$dep' missing" >&2
        return 1
      } ||
        # FIXME: alternative to 'skip' for non-BATS env. seealso
        # projectadmin/tests/bats/helper.bash
        skip "Not listed in Project-Env-Requirements: $dep"
    }
  done
}


# Requirements are given as a tag-id that is either:
#   an existing path
#   if titled, an existing, non-empty env <Name> as-is (first letter is uppercase), or
#   if env variable projectenv_dep_<name>=1
#   a function projectenv_dep_<name> that returns 0
provided_by_env()
{
  # File exists
  test -e "$1" && return || true

  local vid
  str_vword vid "$1"

  # Check for titled Varname value
  fnmatch "[A-Z]*" "$vid" && {
    # this is bash indirect expansion, but Bats is bash anyway
    not_falseish "${!vid}" && return
  }

  # Other env value provided
  env_key="projectenv_dep_$vid"
  not_falseish "${!env_key}" && return

  # Function
  func_key="projectenv_$vid"
  type $func_key >/dev/null 2>&1 && {
    $func_key
    return $?
  }

  return 1
}

# TODO: expand-dep is unused except by prepare-env SCRIPT-MPE-5
# Look for additional prerequisites given deps list
expand_deps()
{
  local list="$1"
  shift
  try_value $list
  set -- $value
  for id in $value
  do
    expand_dep $id
  done
}

# TODO: expand-deps is unused except by expand-dep, prepare-env SCRIPT-MPE-5
# recursive
expand_dep()
{
  local value=
  while test $# -gt 0
  do
    dep_key="projectenv_$(printf -- "$1" | tr -cs 'A-Za-z0-9_' '_')_dep"
    try_value $dep_key && {
      expand_dep $value
    }
    echo $1
    shift
  done
}


build_params()
{
  req_vars Env_Param_Re Job_Param_Re
  env | grep -i "$Env_Param_Re"
  env | grep -i "$Job_Param_Re"
  env | grep '_ts='
  note "Project_Env_Requirements=$Project_Env_Requirements"
}


# TODO: build-error unused except by unittest SCRIPT-MPE-5
build_error()
{
  echo "$1" >> $build_errors
  error "$1"
}
