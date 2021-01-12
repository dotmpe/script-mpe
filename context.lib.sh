#!/bin/sh

# Tag-name records wip


context_lib_load()
{
  lib_load statusdir ctx-base contextdefs match-htd stattab &&
  true "${CTX:=""}" &&
  true "${PCTX:=""}" &&
  true "${CTX_DEF_NS:="HT"}" &&

  # TODO context-id and context-status
  first_only=1 contextdefs_cmd_seq_all context_id id '$(contexttab_super_orders $CTX)' &&
  # first_only=1 contextdefs_cmd_seq_all context_id id &&
  contextdefs_cmd_seq_all context_status status '-- $(context_env_list tags)'
}

# TODO: add dry-run/stat/update mode, and add to install/provisioning script +U-c
context_lib_init()
{
  test "${context_lib_init-}" = "0" && return
  test -n "${package_lists_contexts_default-}" || package_lists_contexts_default=@Std
  true "${CTX_TAB:="${STATUSDIR_ROOT}index/context.list"}"
  test -e "$CTX_TAB" || {
    touch "$CTX_TAB" || return $?
  }
}

# Show root context.tab filename
context_file ()
{
  test -n "${context_tab-}" || local context_tab="$CTX_TAB"
  echo "$context_tab"
}

# List includes. Reference and path names.
context_files()
{
  test -n "${context_tab-}" || local context_tab="$CTX_TAB"
  echo "$context_tab $context_tab"
  list_preproc include "$context_tab"
}

# Echo table after preproc
context_tab ()
{
  test -n "${context_tab-}" || local context_tab="$CTX_TAB"

  grep -q '^#include\ ' "$context_tab" && {
    expand_preproc include "$context_tab" | grep -Ev '^\s*(#.*|\s*)$'
    ignore_sigpipe
    return $?
  } || {
    read_nix_style_file "$context_tab"
  }
}

# List name IDs only
context_tag_list()
{
  context_tab | cut -d' ' -f3 | cut -d':' -f1
}

# List current context envs (CTX/CTXP and others)
context_env_list() # [FMT]
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

contexttab_builtin=builtin
contexttab_root=Base

# Start at TAG and find all related
contexttab_all_tags () # TAG
{
  test $# -eq 1 -a -n "${1-}" || return 98 # Wrong arguments
  local tags
  while true; do
    fnmatch "* $1 *" " $contexttab_builtin " && {
      tags="${tags-}${tags+" "}$1"
      shift
    } || {
      context_tag_env $1 || return 90 # Related tag should/does not exist
      tags="${tags-}${tags+" "}$1"
      shift
      for ref in $rest
      do fnmatch "@*" "$ref" || continue
        set -- "${ref:1}" "$@"
      done
    }
    test $# -gt 0 || break
  done
  echo $tags
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

context_check () # [case_match=1] [match_sub=0] ~ Tags...
{
  p= s= act=context_check_inner foreach_do "$@"
}

context_check_inner()
{
  context_exists_tag "$1" && {
    $LOG ok "" "Exists" "$1"
    return
  } || {
    context_exists_tagi "$1" && {
      warn "Wrong case for '$1'"
      return 3
    } || {
      context_exists_subtagi "$1" && {
        warn "Sub-tag exists for '$1'"
        return 2
      } || {
        $LOG nok "" "No such tag" "$1"
        return 1
      }
    }
  }
}

# Check that given tag exists. Return 0 for an exact match,
# 1 for missing, 2 for case-mismatch or 3 for sub-context exists.
# Setting case-match / match-sub to 0 / 1 resp. makes those return 0.
context_exists () # [case_match=1] [match_sub=0] ~ Tag
{
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
context_exists_tag () # Tag
{
  generator=context_tab stattab_exists "$@"
}

# Compile and match grep for tag in Ctx-Table, case insensitive
context_exists_tagi () # Tag
{
  grep_f=-qi context_exists_tag "$@"
}

# Compile and match grep for sub-tag in Ctx-Table
context_exists_subtagi ()
{
  test "unset" != "${grep_f-"unset"}" || local grep_f=-qi
  match_grep_arg "$1"
  context_tab | $ggrep $grep_f "^[0-9a-z -]*\b[^ ]*\/$p_:\?\\ "
}

# Return record for given ctx tag-id
context_tag_entry () # TAG
{
  test $# -eq 1 -a -n "$1" || error "arg1:tag expected" 1 || return
  test -n "${NS:-}" || local NS=$CTX_DEF_NS
  test "unset" != "${grep_f-"unset"}" || local grep_f=-nm1
  match_grep_arg "$1"
  context_tab | $ggrep $grep_f "^[0-9a-z -]*\b\\($NS:\\)\\?$p_:\\?\\ "
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

# Fetch exactly one record with given URL attribute
context_url_entry () # URL
{
  test $# -eq 1 -a -n "$1" || error "arg1:URL expected" 1 || return
  test "unset" != "${grep_f-"unset"}" || local grep_f=-nm1
  match_grep_arg "$1"
  context_tab | $ggrep $grep_f "^[0-9a-z -]*\b[^:]*:\\? .* <$p_>\( \|$\)"
}

context_literalid_entry () # STR
{
  test $# -eq 1 -a -n "$1" || error "arg1:URL expected" 1 || return
  test "unset" != "${grep_f-"unset"}" || local grep_f=-nm1
  match_grep_arg "$1"
  context_tab | $ggrep $grep_f "^[0-9a-z -]*\b[^:]*:\\?\( .*\)\\? \`\`$p_\`\`\( \|$\)"
}

# TODO: Return tagged entries
context_tagged() # [File] Tag-Names...
{
  context_tab
}

context_parse()
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

# Retrieve tag record and parse, see context-parse.
context_tag_env () # TAG
{
  context_parse "$( context_tag_entry "$1" )"
}

# Retrieve sub-tag record and parse, see context-parse.
context_subtag_env () # SUBTAG
{
  context_parse "$( context_subtag_entries "$1" )"
}

context_tag_init ()
{
  test -n "${context_tab-}" || local context_tab="$CTX_TAB"
  context_echo entry | normalize_ws >>"$context_tab"
}

# TODO: docs
context_tag_new ()
{
  test -n "${context_tab-}" || local context_tab="$CTX_TAB"
  context_tag_fields_init | normalize_ws >>"$context_tab"
}

context_tag_fields_init()
{
  date +'%Y-%m-%d'
  echo "$tagid"
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

# Prep/parse (primary) context given or default
contexttab_init()
{
  test -n "${1-}" || set -- $package_lists_contexts_default
  ctx="$1"
  primctx="$(echo "$1" | cut -f 1 -d ' ')"
  # Remove '@'
  upper=0 mkvid "$(echo "$primctx" | cut -c2-)" && primctx_sid="$vid"
  upper= mkvid "$(echo "$primctx" | cut -c2-)" && primctx_id="$vid"
}

contexttab_load_entry()
{
  test -n "${primctx:-}" || contexttab_init "$@"
  context_tag_env "$primctx_id"
}

# Look for filename/path as context, or as URL attribute to one.
# , or if
# matching glob literalid
context_find_fileref () # FILE
{
  test $# -eq 1 -a -n "${1-}" || return 98
  context_tag_entry "$1" && return
  context_url_entry "$1" && return
}

context_fileref_env () # FILE
{
  context_parse "$( context_find_fileref "$@" )"
}

#
