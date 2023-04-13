#!/usr/bin/env bash

## Fzf utils for use in user-shell

. ${US_BIN:?}/feh.lib.sh
. ${US_BIN:?}/fzf.lib.sh

: "${FZF_DEFAULT_COMMAND:=find . -not -type l}"

# Fzf env var for user preferences
: "${FZF_DEFAULT_OPTS:=--exact -i}"
#--layout=reverse-list
# XXX: I think --ansi is default?

# Initial Chauvet theme for Fzf
FZF_CHAUVET='
    --color=bg:#121212,bg+:#303030,info:#4e4e4e,border:#6c6c6c,spinner:#ffd700
    --color=hl:#ff8700,fg:#D9D9D9,fg+:#D9D9D9
    --color=marker:#75f000,prompt:#d78700,header:#d7d75f
    --color=pointer:#ffd700,hl+:#8787ff'

test ${BG:-0} -eq 1 ||
  # Transparent
  FZF_CHAUVET=$FZF_CHAUVET' --color=bg:-1'

# Additional options for fzf-edit-* functions
: "${FZF_EDIT_OPTS:=--multi}"

typeset -gx FZF_DEFAULT_OPTS FZF_DEFAULT_COMMAND FZF_CHAUVET


alias fzf_chdir='cd $(FZF_DEFAULT_COMMAND="find ./ -type d" FZF_CTRL_T_COMMAND="cd" fzf)'

# Edit files after interactive selection on name
alias fzf-edit='$EDITOR $(fzf $FZF_EDIT_OPTS)'
alias fzf-edit-preview='$EDITOR $(fzf-preview $FZF_EDIT_OPTS)'

# Use batcat to preview highlighted plain-text files
alias fzf-preview="fzf --preview='${BAT_BIN:-bat} --color always --style numbers {}'"

alias fzf-preview-bat-themes='bat --list-themes | fzf --preview="bat --theme={} --color=always ~/bin/user-script.sh"'

# Feh is a good choice for any WM env I think
alias fzf-view-nomux="fzf --preview='feh --title feh-preview -B ${feh_bg:-} -Z {} -.' --preview-window=0"
alias fzf-view="fzf-tmux --preview='feh --title feh-preview -B ${feh_bg:-} -Z {} -.' --preview-window=0"


# Select file using ripgrep+fzf and edit, using bat for preview.
#
# 1. Search for text in files using Ripgrep
# 2. Interactively restart Ripgrep with reload action
# 3. Open the file(s) in Vim
fzf_ripgrep_preview ()
{
  RG_PREFIX="rg --column --line-number --no-heading --color=always --smart-case"
  INITIAL_QUERY="${*:-}"
  IFS=: read -ra selected < <(
    FZF_DEFAULT_COMMAND="$RG_PREFIX $(printf %q "$INITIAL_QUERY")" \
    # These FZF_* may not be exported, so insert them in subshell command explicitly
    fzf-preview ${FZF_EDIT_OPTS:-} \
    fzf \
        ${FZF_DEFAULT_OPTS:-} \
        ${FZF_EDIT_OPTS:-} \
        --query "$INITIAL_QUERY" \
        --bind "change:reload:sleep 0.1; $RG_PREFIX {q} || true" \
        --delimiter : \
        --preview 'bat --color=always {1} --highlight-line {2}' \
        --preview-window 'right:53%:noborder'
  )
  echo "Selected: ${selected[*]}"
  #[ -n "${selected[*]}" ] && "${EDITOR:?}" "${selected[@]}" "+${selected[1]}"
}

eval "ripgrep_file_${EDITOR:?} () { fzf_ripgrep_edit \"\$@\"; }"


#
