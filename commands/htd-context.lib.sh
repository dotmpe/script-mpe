#!/bin/sh


# Use docstat built-in to retrieve cached tag list
htd_context_list()
{
  #docstat_taglist
  #context_list
  context_list | $gsed 's/^[0-9 -]*\([^ ]*\).*$/\1/g'
}

# Filter docstat cached tag list for context containing '/'
htd_context_roots_docstat()
{
  docstat_taglist | $gsed 's/@\([^@/]*\).*/\1/g' | sort -u
}

# Check that given context names exist, either as root or sub-context
htd_context_check()
{
  htd_context_check_inner()
  {
    context_exists "$1" && {
      return
    } || {
      context_existsi "$1" && {
        warn "Wrong case for '$1'"
        return 3
      } || {
        context_existsub "$1" && {
          warn "Sub-tag exists for '$1'"
          return 2
        } || {
          return 1
        }
      }
    }
  }

  p= s= act=htd_context_check_inner foreach_do "$@"
}

# Initialize Ctx-Table line for given context
htd_context_new()
{
  fnmatch "*/*" "$1" && {
      htd_context_new "$(dirname "$1" )"
  }
  context_exists "$1" && return 1
  context_existsub "$1" && return 1
  context_parse "0: - $1"
  context_tag_init
}

# Other context actions

htd_context_update()
{
  true
}

htd_context_start()
{
  echo TODO: start
}

htd_context_close()
{
  echo TODO: close
}

htd_context_destroy()
{
  echo TODO: destroy
}

htd_context_tree()
{
  txt.py txtstat-tree "$HTDCTX_TAB"
}
