#!/bin/sh


context_lib__load()
{
  lib_require sys os-htd src-htd stattab{,-reader} ctx-base contextdefs match-htd \
      contextdefs || return

  : "${CTX:=""}"
  : "${PCTX:=""}"
  : "${CTX_DEF_NS:="HT"}"
  : "${CTX_FATTR:=id}"

  # TODO context-id and context-status
  first_only=1 contextdefs_cmd_seq_all context_id id '$(contexttab_super_orders $CTX)' &&
  # first_only=1 contextdefs_cmd_seq_all context_id id &&
  contextdefs_cmd_seq_all context_status status '-- $(context_env_list tags)'
}

# TODO: add dry-run/stat/update mode, and add to install/provisioning script +U-c
context_lib__init()
{
  test -z "${context_lib_init-}" || return $_
  test -n "${package_lists_contexts_default-}" || package_lists_contexts_default=@Std
  : "${CTX_TAB:="${STATUSDIR_ROOT:?}index/${CTX_TAB_NAME:-context.list}"}"
  : "${CTX_CACHE:="${STATUSDIR_ROOT:?}cache"}"
  : "${CTX_TAB_CACHE:="${CTX_CACHE:?}/context.tab"}"
  test -e "$CTX_TAB" || {
    touch "$CTX_TAB" || return $?
  }
}


context ()
{
  #test $# -gt 0 -a "${1:0:1}" = "-"
  local _switch=${1:-list}
  _switch=${_switch:+$(str_globstripcl "${_switch:?}" -)}
  test -n "${switch-}" || {
    : "${_switch:=local}"
  }
  case "$_switch" in

    ( l|load )
        context --exists "$@"
      ;;
    ( exists )
        stb_fp=${ctx_tab:-${CTX_TAB_CACHE:?}} stattab_exist_all "$@"
      ;;

    ( * ) $LOG alert :context "No such option" "$_switch" ${_E_NF:=124}
  esac
}

context_cache ()
{
  # Export every function for access in shell subprocess
  export -f \
    filereader_statusdir_cache \
    src_htd_resolve_fileref \
    context_read_include \
    context_file_attributes \
    context_file_attribute std_noerr
  preproc_run "${1:?}" \
    filereader_statusdir_cache \
    context_read_include \
    src_htd_resolve_fileref
}

# See that all given tags exist
context_check () # [case_match=1] [match_sub=0] ~ Tags...
{
  p= s= act=context_check_inner foreach_do "$@"
}

context_check_inner () # ~ <Tag> <...>
{
  context_exists_tag "$1" && {
    $LOG notice :tag "Exists" "$1"
    return
  } || {
    context_exists_tagi "$1" && {
      $LOG error :tagi "Wrong case" "$1" 3 || return
    } || {
      context_exists_subtagi "$1" && {
        $LOG notice :subtagi "Sub-tag exists" "$1"
      } || {
        $LOG alert :nok "No such tag" "$1"
      }
    }
  }
}

# XXX: New more simple query, see context-uc-cmd-seq for old
context_cmd_seq () # ~ <ctx-var-name> <cmd-seq...>
{
  declare -n sys_csp=${1:?}
  shift
  sys_cse=true sys_cmd_seq "$@"
}

context_define ()
{
  contexttab_init &&
  contexttab_commit
}

# Echo last context-parse values
context_echo () # [FMT]
{
  case "${1:-"debug"}" in

    entry )
        echo "${stat}"
        echo "${ids:-$tagid}:"
        echo "${rest}"
      ;;

    debug )
        printf -- "line: $line\nstat: $stat\nids: $ids\ntagid: $tagid\ncid: $cid\n"\
"tagns: $tagns\nrest: $rest\n"
      ;;

    * ) $LOG error "" "context-echo:${1-}?"
        return 1
      ;;

  esac
}

context_env_define ()
{
  context_fetch
}

# List current context envs (CTX/CTXP and others)
context_env_list () # ~ [FMT]
{
  test $# -ge 1 || set -- env
  case "${1-}" in

    env )
        for e in PCTX ${!CTX*}
        do
          echo "$e: ${!e-}"
        done
      ;;

    tags )
        echo ${CTX:-} | tr ' ' '\n'
        echo '--'
        echo ${PCTX:-} | tr ' ' '\n'
      ;;

    oneline )
        echo ${CTX:-} -- ${PCTX:-}
      ;;

    ""|libids )
        echo ${ENV_D:-} | tr ' ' '\n'
      ;;

    * ) echo "context:env-list:$1?" >&2; return 1 ;;
  esac
}

# Check that given tag exists. Return 0 for an exact match,
# 1 for missing, 2 for case-mismatch or 3 for sub-context exists.
# Setting case-match / match-sub to 0 / 1 resp. makes those return 0.
context_exists () # [case_match=1] [match_sub=0] ~ Tag
{
  true "${match_alias:=0}"
  context_exists_alias "$1" && {
    trueish "$match_alias " && return 0 || return 4
  }
  true "${match_sub:=0}"
  context_exists_subtagi "$1" && {
    trueish "$match_sub" && return 0 || return 3
  }
  true "${case_match:=1}"
  context_exists_tag $1 && return
  context_exists_tagi $1 && {
    trueish "$case_match" && return 2 || return 0
  }
  return 1
}

# Compile and match grep for tag with Ctx-Table
context_exists_tag () # Tag [Grep-Fmt]
{
  test -n "${2-}" || set -- "$1" "${grep_fmt:-"id"}"
  generator=context_tab stattab_exists "$@"
}

# Compile and match grep for tag in Ctx-Table, case insensitive
context_exists_tagi () # Tag [Grep-Fmt]
{
  grep_f=${grep_f:-"-qi"} context_exists_tag "$@"
}

# Compile and match grep for sub-tag in Ctx-Table
context_exists_subtagi ()
{
  #match_grep_arg "$1"
  #context_tab | $ggrep $grep_f "^[0-9a-z -]*\b[^ ]*\/$p_:\?\\ "
  generator=context_tab stattab_exists "$1" sub
}

context_exists_alias () # TAG
{
  generator=context_tab stattab_exists "$1" alias
}

context_field () # ~ <Attr> <Context-record>
{
  sh_fun context_field_${1//[:-]/_} && {
    "$_" "${@:2}" || return
  } || {
    context_field_meta "$@"
  }
}

# XXX: meta field ':' contains no spaces in key or value
context_field_meta ()
{
  : "${2:-${stab_record:?}}"
  : "${_##* $1:}"
  : "${_%% *}"
  echo "$_"
}

# XXX: all tag references (contexts and projects)
context_field_tag_refs ()
{
  : "${2:-${stab_record:?}}"
  for word in $_
  do
    str_globmatch "$word" "@*" ||
    str_globmatch "$word" "+*" ||
      continue
    echo "$word"
  done
}

# Show root context.tab filename
context_file ()
{
  local context_tab="${context_tab:-${CTX_TAB:?}}"
  echo "$context_tab"
}

context_file_attribute () # ~ <Key> <Value> <Context-list>
{
  #meta_xattr__set
  xattr -w user.${1:?} "${2:?}" "${3:?}"
  # TODO: flush value to file later context_file_flush_xattr_cache
}

# record attributes specifically for context.tab, where attributes-values are
# embedded (backed up) as preprocess directives into the tab file as well.
context_file_attributes () # ~ <Keys...>
{
  local context_tab="${context_tab:-${CTX_TAB:?}}" v xp
  local -a ids
  true "${xattr_noerr:=1}"
  xp=${xattr_noerr:+std_noerr }
  # Look for each requested key
  while test $# -gt 0
  do
    v=$(${xp}xattr -p user.${1:?} "$context_tab")
    test -n "$v" && echo "$v" || {
      v=$(grep -Po '#'"${1:?}"' \K.*' "$context_tab") ||
        v=_$RANDOM
      context_file_attribute ${1:?} "${v:?}" "$context_tab" ||
        $LOG warn : "Failed caching ${1:?} attribute" "$context_tab"
      echo "$v"
    }
    shift
  done
}

context_file_flush_xattr_cache ()
{
  local c v xp
  xp=${xattr_noerr:+std_noerr }
  v=$(${xp}xattr -p user.${1:?} "${3:?}") &&
  c=$(grep -Po '#'"${1:?}"' \K.*' "$context_tab") && {
    test "$c" = "$v" ||
        sed -m 's/^#'"${1:?}"' .*$/#'"${1:?}"' '"${v:?}"'/' "${3:?}" ||
            return
  } || {
    echo "#${1:?} ${v:?}" >>"${3:?}"
  }
}

context_file_read ()
{
  fr_ctx=context file_reader "$@" || return

  sh_fun "$fr_spec" &&
    set -- "$fr_spec" "$@" ||
    set -- context_run "$fr_spec @FileReader @class-uc" "$@"

  "$@"
}

context_file_path ()
{
  modeline_file_path "$@"
}

context_file_reader ()
{
  modeline_file_reader "$@" || return

  # Infer reader otherwise, ie. from filepath/name but note that we may have a
  # modeline-less file on stdin with no known format extension.
  test -n "${fr_spec:-}" || {
    # XXX: need to process basename here: $filename vs $fp
    fr_spec=$(${file_reader_detect:-file_format_reader} "$fr_p") || return
  }
}

context_fileids () # [Ctx-tab] ~
{
  local files file id
  if_ok "$(context_files)" &&
  mapfile -t files <<< "$_" &&
  for file in "${files[@]}"
  do
    id=$(CTX_TAB=$file context_file_attributes id) || return
    echo "$id $file"
  done
}

context_fileref_env () # ~ <File>
{
  context_parse "$(context_find_fileref "$@")"
}

# List includes. These are cached as output by preproc-includes-enum, but
# preproc-includes-list may be invoked directly bypassing cache by setting
# <context-cache-files=false>.
context_files () # (ctx-tab) ~
{
  local context_tab="${context_tab:-${CTX_TAB:?}}"
  "${context_cache_files:-true}" || {
    echo "${context_tab:?}"
    preproc_includes_list "" "$context_tab"
    return
  }
  #"${context_cache_tab:-true}"
  local cached=${CTX_CACHE:?}/context-file-includes.tab
  context_files_cached "$cached" &&
  cut -d $'\t' -f 4 "$cached"
}

# Track (recursively) table of all source files given current context table.
#
# Ensures given include table (TSV) for current context-tab exists and is UTD,
# or regenerate. If table does not exist yet, recurse all includes to get the
# file list and then decide wheter to (recurse again and) generate the table. If
# the table exists it can be used to shortcut the check. A missing context-tab
# returns E:user (3).
context_files_cached () # (ctx-tab) ~ <Cached-enum-file>
{
  local context_tab="${context_tab:-${CTX_TAB:?}}"
  test -e "$context_tab" || return ${_E_user:?}
  declare -a files
  # Read file-line-src table, or generate ad-hoc file list
  test -e "${1:?}" &&
    mapfile -t files <<< "$(cut -d $'\t' -f 4 "$1")" ||
    mapfile -t files <<< "$(
      echo "$context_tab"
      preproc_includes_list "" "$context_tab")" || return
  # Compare file utimes with those of source files, set non-zero if OOD
  test -e "${1:?}" -a "$1" -nt "$context_tab" ||
  printf '%s\n' "${files[@]}" | os_up_to_date "$1" || {
    # (Re)generate src,linenr,ref,file table
    {
      if_ok "$(realpath "$context_tab")" &&
      printf "\t\t%s\t%s" "${context_tab/#$HOME\//~\/}" "$_" &&
      preproc_includes_enum "" "$context_tab"
    } >| "$1" || return
  }
}

# Look for filename/path as context, or as URL attribute to one.
# , or if
# matching glob literalid
context_find_fileref () # ~ <File>
{
  test $# -eq 1 -a -n "${1-}" || return 98
  context_tag_entry "$1" && return
  context_url_entry "$1" && return
}

context_hook () # ~ <Call> <Arg...>
{
  false
}

context_ids_list ()
{
  context_tab | grep -Po '^['"$STTAB_FS$STTAB_STATC"']* \K((.*(?=:($| )))|[^ ]*)'
}

context_list_raw () # ~ <File>
{
  export -f context_read_include \
        context_file_attributes context_file_attribute std_noerr
  preproc_run "${1:?}" filereader_statusdir_cache context_read_include
}

context_load () # ~ <Target-var> <Types>
{
  false
}

context_new_fileid ()
{
  local newid files
  mapfile -t files <<< "$(context_files)"
  newid=$(rnd_str 3) || ignore_sigpipe || return
  while grep -q '#'"$newid" "${files[@]}"
  do
    newid=$(rnd_str 3) || ignore_sigpipe || return
  done
  echo "$newid"
}

context_parse ()
{
  test -n "$1" || return

  # Split grep-line number from rest
  line="$(echo "$1" | cut -d ':' -f 1)"
  rest="$(echo "$1" | cut -d ':' -f 2-)"

  # Split rest into three parts (see docstat format), first stat descriptor part
  stat="$(echo "$rest" | grep -o '^[^_A-Za-z]*' )"
  rest="$(echo "$rest" | sed 's/[^_A-Za-z]*//' )"

  # TODO: Use tags to find contexts with parse interface, and finish parsing
  #for ctx in ctx_${}
  #do
  #  # TODO: context-parse contexts
  #  ctx_iface__${ctx}
  #  ctx__${ctx}__parse
  #done

  # Split Ids from description
  ids="$(echo "$rest" | sed 's/\(:\| \).*$//')"
  rest="$(echo "$rest" | sed 's#^'"$ids"':\?\ ##')"
  # rest="$(echo "$rest" | cut -d ' ' -f 2-)"
  tagid="$(echo "$ids" | cut -d ' ' -f 1)"

  # Parse NS: from tag if present
  fnmatch "*:*" "$tagid" && {
    prefix_require_names_index &&
    local _tagns=$(echo "$tagid" | cut -d':' -f1) &&
    prefix_pathnames_tab | grep -q "\\ $_tagns$" && {
        tagid=$(echo "$tagid" | sed "s/^[^:]*://g") &&
        tagns=$_tagns
    }
  }

  true "${tagns:="$CTX_DEF_NS"}"
}

# Get all content lines, adding file-source Id tag to each entry.
# Every line must start with a non-space character,
context_read_include () # ~ <Ref> <File> [<Src-file> <Src-line>]
{
  local id
  id=$(context_tab=${2:-${1:?}} context_file_attributes id) &&
  grep -v '^[\t ]' "${2:-${1:?}}" |
    sed -E 's/^([^# ].*)(#[^ ]|$)/\1 #'"$id"' \2 /'
}

context_require ()
{
  uc_field
  exit 123
}

context_run () # ~ <Spec> <Arg...>
{
  # stattab_data_list <fun arg...>
  # stattab_data_outline <fun arg...>

  # Load everything
  context_update_env $1 || return

  # context-init
  # Find first context with 'run' hook, or if context matches class
  # attempt to initialize that and set its 'run' call as handler.
  for t in $1
  do
    class_exists "$t" && {
      ! class_hasattr "$t" run || {
        create ctx $t
        set -- $ctx.run "$@"
        break
      }
    }

    ! if_ok "$(context_hook "$t" run)" || {
      set -- $_ "$@"
      break
    }
  done

  "${@:?}"
}

# XXX: Return record for given ../subtag.
context_subtag_entries () # SUBTAG
{
  test $# -eq 1 -a -n "$1" || error "arg1:tag expected" 1 || return
  #test -n "${NS:-}" || local NS=$CTX_DEF_NS
  test "unset" != "${grep_f-"unset"}" || local grep_f=-nm1
  match_grep_arg "$1"
  context_tab | $ggrep $grep_f "^[0-9a-z -]*\b[^ ]*\/$p_:\?\\ "
}

# Retrieve sub-tag record and parse, see context-parse.
context_subtag_env () # SUBTAG
{
  context_parse "$(context_subtag_entries "$1")"
}

# Echo table after first checking/updating preproc cache
context_tab () # [Ctx-tab] ~ # List context list items
{
  context_tab_cache &&
    $LOG info :context-tab "Cache file ready, reading..." "$CTX_TAB_CACHE" &&
    grep -${ctx_grep_f:-Ev} '^\s*(#.*|\s*)$' "${CTX_TAB_CACHE:?}"
}

# list files, and if cached list is OOD regenerate
# TODO: return status to indicate data reload may be required
context_tab_cache () # [Ctx-tab] ~
{
  local cached=${CTX_TAB_CACHE:?}
  $LOG debug :context-tab-cache "Checking cache file" "$cached"
  context_files | os_up_to_date "$cached" || {
    $LOG info :context-tab-cache "Updating cache file" "$cached"
    local context_tab="${context_tab:-${CTX_TAB:?}}"
    context_list_raw "${context_tab:?}" >| "$cached"
  }
}

# Return record for given ctx tag-id
context_tag_entry () # ~ <Tag-id> [<Context-tab>]
{
  test $# -eq 1 -a -n "$1" || error "arg1:tag expected" 1 || return
  test -n "${NS:-}" || local NS=$CTX_DEF_NS
  test "unset" != "${grep_f-"unset"}" || local grep_f=-nm1
  generator=context_tab stattab_grep "$1" -ns-id "${2:-$CTX_TAB_CACHE}"
}

# Retrieve tag record and parse, see context-parse.
context_tag_env () # ~ <Tag>
{
  context_parse "$(context_tag_entry "$1")"
}

context_tag_fields_init ()
{
  date +'%Y-%m-%d'
  echo "$tagid"
}

context_tag_init () # [Ctx-tab] ~
{
  local context_tab="${context_tab:-${CTX_TAB:?}}"
  context_echo entry | normalize_ws >>"$context_tab"
}

context_tag_new ()
{
  local context_tab="${context_tab:-${CTX_TAB:?}}"
  context_tag_fields_init | normalize_ws >>"$context_tab"
}

context_tag_order() # Tag
{
  context_tag_env "$1" || {
    $LOG warn "" "Cannot get context spec" "$1"; return 1
  }
  test -n "${rest-}" || return
  local tags= ctx ctxid vid
  set -- $rest
  while test $# -gt 0
  do
    case "$1" in "@"* ) ;; * ) shift ; continue;; esac
    ctx=${1:1}; mkvid $ctx; ctxid=$vid; tags="${tags}$ctx"
    echo $ctx
    context_tag_env "$ctx" && {
      set -- "$@" $rest
    }
    shift
  done
}

context_tags_list () # ~ # Scan for every referred tag
{
  context_tab | grep -Po ' \K(@|\+)[^ ]*' | remove_dupes
}

# TODO: context-update-env
context_update_env ()
{
  CTX
  CTX_ENV

  context_add
  context_remove
}

# Fetch exactly one record with given URL attribute
context_url_entry () # URL
{
  test $# -eq 1 -a -n "$1" || error "arg1:URL expected" 1 || return
  test "unset" != "${grep_f-"unset"}" || local grep_f=-nm1
  match_grep_arg "$1"
  context_tab | $ggrep $grep_f "^[0-9a-z -]*\b[^:]*:\\? .* <$p_>\( \|$\)"
}

contexttab_builtin=builtin
contexttab_root=Base

# Start at TAG and find all related
contexttab_related_tags () # (tag-rel) ~ <Tag>
{
  test $# -eq 1 -a -n "${1-}" || return ${_E_GAE:-193} # Wrong arguments
  : "${tag_rel:=}"
  while true; do
    fnmatch "* $1 *" " $contexttab_builtin " && {
      str_wordmatch "$1" $tag_rel ||
        tag_rel="${tag_rel-}${tag_rel:+" "}$1"
      shift
    } || {
      context_tag_env $1 || return 90 # Related tag should/does not exist
      str_wordmatch "$1" $tag_rel ||
        tag_rel="${tag_rel-}${tag_rel:+" "}$1"
      shift

      for ref in $rest
      do fnmatch "@*" "$ref" || continue
        set -- "${ref:1}" "$@"
      done
    }
    test $# -gt 0 || break
  done
}

# Resolve 'super:' attribute for tag. And list all tags including given tag,
# on one line starting from root-most to given 'sub' tag. (Not the same as
# tag names/ids with subtags)
contexttab_super_order () # TAG [FMT]
{
  test $# -ge 1 -a $# -le 2 -a -n "${1-}" || return 98 # Wrong arguments
  local count=1 fmt=${2:-"oneline"}; set -- "$1"
  while true; do
    context_tag_env $1 || return 90 # Super tag should/does not exist
    for ref in $rest
    do fnmatch "super:*" "$ref" || continue
        set -- "${ref:6}" "$@"
        break
    done
    test $count -lt $# || break
    count=$#
  done
  test $# -gt 1 || set -- $contexttab_root "$@"
  case "$fmt" in
      oneline|leafward ) echo $* ;;
      list|leafward-list ) echo $* | words_to_lines ;;
      rootward ) echo $* | words_to_lines | tac | lines_to_words ;;
      rootward-list ) echo $* | words_to_lines | tac ;;
      * ) return 97 ;;
  esac
}

contexttab_super_orders () # TAGS...
{
  act=contexttab_super_order s= p= foreach_do "$@"
}

# Prep/parse (primary) context given or default
contexttab_init()
{
  test -n "${1-}" || set -- $package_lists_contexts_default
  ctx="$1"
  primctx="$(echo "$1" | cut -f 1 -d ' ')"
  # Remove '@'
  upper=0 mkvid "${primctx:1}" && primctx_sid="$vid"
  upper= mkvid "${primctx:1}" && primctx_id="$vid"
}

contexttab_load_entry()
{
  test -n "${primctx:-}" || contexttab_init "$@"
  context_tag_env "$primctx_id"
}

# XXX: keeping this last because arguments break Vim syntax
context_literalid_entry () # STR
{
  test $# -eq 1 -a -n "$1" || error "arg1:URL expected" 1 || return
  test "unset" != "${grep_f-"unset"}" || local grep_f=-nm1
  match_grep_arg "$1"
  context_tab | $ggrep $grep_f "^[0-9a-z -]*\b[^:]*:\\?\( .*\)\\? \`\`$p_\`\`\( \|$\)"
}

#
