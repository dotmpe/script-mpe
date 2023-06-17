### URLRes: manage local copies for URls


urlres_lib__load ()
{
  lib_require web || return
  : "${CACHE_DIR:=.meta/cache}"
  #: "${urlres_key_format:=md5}"
  #: "${urlres_cachekey_salt:=123}"
  : "${urlres_key_prefix:=urlres:}"
}


# Retrieve resource.
urlres () # ~ <Key> [<Inputs...>]
{
  urlres_files "$@" || return
  #http_deref "$url" "$cachef" "$etagf"
  http_deref_cache_etagfile "$cachef" "$etagf" "$url"
}

# Encode urlres key and md5summed options into cache name
urlres_cachekey_md5 () # ~ <Key> <Inputs...>
{
  : "$(md5sum <<< "${urlres_cachekey_salt:-}${*:2}")"
  cache_name=$(echo "${urlres_key_prefix:-}$1:${_/  *}")
}

# Encode urlres key and options directly into cache name
urlres_cachekey_plain () # ~ <Key> <Inputs...>
{
  local oldIFS=$IFS;IFS=:
  cache_name=$(echo "${urlres_key_prefix:-}$*")
  IFS=$oldIFS
}

urlres_clear ()
{
  unset key kid pattern format format_inputs inputs url cache_name cachef etagf
}

# Set url, and paths of cache files for entity and etag.
urlres_files ()
{
  urlres_ref "$@" || return
  cachef_ext=${urlres_fext:-}
  test -n "$cachef_ext" || {
    : "${url//*.}"
    test -n "$_" && cachef_ext=.$_ || {
      #urlres_meta "$url"
      #cachef_ext=
      TODO "DO a HEAD request and map content-type to filename ext" || return
    }
  }
  : "${cachef:="${CACHE_DIR:?}/$cache_name$cachef_ext"}"
  : "${etagf:="${CACHE_DIR:?}/$cache_name.etag"}"
}

# Process arguments and set url, but do nothing else.
urlres_ref () # ~ <Key> <Inputs...> # Produce URL reference
{
  test -z "${urlres_id:-}" -o "${1:?}" = "${urlres_id:-}" || {
    urlres_clear
    urlres_id=$1
  }
  urlres_parse_arg "$@" &&
  urlres_ref_${urlres_store:-env} "$@" || return
  urlres_format || return
}

urlres_ref_arr ()
{
  true
}

# Take key to retrieve URL pattern and options from env variable(s)
urlres_ref_env () # ~
{
  pattern=${!kid:-}
  test -n "$pattern" && {
    format=${pattern/:*}
    : "$(( ${#format} + 1 ))"
    pattern="${pattern:$_}"
    format_inputs=${pattern/:*}
    : "$(( ${#format_inputs} + 1 ))"
    pattern=${pattern:$_}
  } || {
    : "${kid}_format"
    format=${!_:-printf}
    : "${kid}_format_inputs"
    format_inputs=${!_:-}
    : "${kid}_pattern"
    pattern=${!_:?Pattern expected for \'$key\'}
  }
}

urlres_ref_fields ()
{
  true
}

urlres_ref_lestid ()
{
  true
}

urlres_ref_tab ()
{
  true
}

# Format the url using the method, first formatting inputs if function for that
# was specified.
urlres_format () # ~
{
  test -z "$format_inputs" || {
    local i
    for i in ${!inputs[*]}
    do
      inputs[i]=$($format_inputs "${inputs[i]}")
    done
  }
  url=$(uc_format_${format:?} "${pattern:?}" "${inputs[@]:?}")
}

# Parse key and inputs, so that URL pattern can be retrieved. Also sets
# cache-name, but cache extension will depend on formatted url or HTTP HEAD
# later.
urlres_parse_arg () # ~ <Key> <Inputs...>
{
  key=${1:?} kid="${1//[:-]/_}"

  declare -ga inputs=( "${@:2}" )

  urlres_cachekey_${urlres_key_format:-md5} "$@"
}


uc_format_printf ()
{
  printf -- "$@"
}

#
