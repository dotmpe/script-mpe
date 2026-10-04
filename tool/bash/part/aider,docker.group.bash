# Copyright: (C) 2026 hari <hari@t470p>
#
# .group.bash file, see User-Conf us-part for specification.
#
# Distributed under terms of the MIT license.

docker_aider_pre=Docker.Aider
docker_aider_cnk=7bc2a6f1
docker_aider_man='Short cuts for docker commands to run Aider (terminal based
LLM code assistant).
'
docker_aider_grp=( uc-docker )

declare -gA \
docker_aider_als=(

  [aider+unsane]='aider+user --no-show-model-warnings'
  [aider+user]=': Id usrtools_user-conf::docker-aider::_als::aider+user
    [[ -d .local/user/data ]] || failerr "not in a basedir" || return;
    \builtin command aider \
       --no-show-release-notes --no-gitignore \
       --no-auto-commits \
       --no-dirty-commits \
       --no-attribute-author \
       --attribute-commit-message-author \
       --input-history-file .local/user/data/input/aider.input.history \
       --chat-history-file .local/user/data/chat/aider.chat.history.md \
       --config $HOME/.local/share/dotfiles/etc/aider/aider.conf.yml'
  [aider]='aider+user'

  # Main execution context (with echo of entire line to mark switch of context)
  [aider+docker]='aider+docker+env &&
    echo "${C_CONTEXT-}> ${C_AUXILIARY-}docker run -it --rm ... ${DIM_GREEN-}${@@Q}${NORMAL-}" && aider+dustinwashington+latest'

  [aider+dustinwashington+latest]='docker run -it --rm \
      "${uc_docker_volume_arg[@]}" \
      "${uc_docker_env_arg[@]}" \
      -w /work \
      -e BASEPROJECT=/project \
      dustinwashington/aider-ce:latest \
      --no-show-release-notes --no-gitignore'

  [aider+paugauthier]='docker run -it --rm \
      "${uc_docker_volume_arg[@]}" \
      "${uc_docker_env_arg[@]}" \
      -w /work \
      -e HOME=/work \
      -e BASEPROJECT=/project \
      paulgauthier/aider-full:dev \
     --no-show-release-notes --no-gitignore'

  # Change docker entry point to get internal shell session
  [aider+docker+bash]='aider+docker+env &&
    echo "${C_CONTEXT-}> ${C_AUXILIARY-}docker run -it --rm ... --entrypoint bash paulgauthier/aider ${DIM_GREEN-}${@@Q}${NORMAL-}" &&
    docker run -it --rm \
      "${uc_docker_volume_arg[@]}" \
      "${uc_docker_env_arg[@]}" \
      -w /work \
      -e HOME=/work \
      -e BASEPROJECT=/project \
      --entrypoint bash \
      paulgauthier/aider-full:dev'

  # Might want to experiment with this, but chat-aider-task is better setup to
  # deal with different Git scenarios.
  #[aider+docker+nogit]='aider+docker --no-git'

  # Main alias, with all current user settings and parameters applied
  [aider+docker+user]='aider+docker \
     --no-show-release-notes --no-gitignore \
     --input-history-file .meta/stat/index/aider.input.history \
     --chat-history-file .meta/stat/index/aider.chat.history.md \
     --config /tmp/aider.conf.yml'

  # Keep model variable, for manual selection. (Listing all still requires partial name argument.)
  [aider+list]='aider --list-models'

  # TODO: test which services and models actually respond,
  # these all seem to work:
  [aider.copilot+claude-haiku-4.5]='aider --model github_copilot/claude-haiku-4.5'
  [aider.copilot+gpt-3.5-turbo]='aider --model github_copilot/gpt-3.5-turbo'
  [aider.copilot+gpt-3.5-turbo-0613]='aider --model github_copilot/gpt-3.5-turbo-0613'
  [aider.copilot+gpt-4]='aider --model github_copilot/gpt-4'
  [aider.copilot+gpt-5-mini]='aider --model github_copilot/gpt-5-mini'
  [aider.copilot+gpt-4o-mini]='aider --model github_copilot/gpt-4o-mini'
)

declare -gA \
docker_aider_ssc=(
  [aider+docker+env]='{
    # NOTE: env should not export. I do not like the idea of keeping secrets in
    # the env slice as the entire process subtree normally would "inherit" a
    # copy of all values. The secure method to pass them depends, if the command
    # process forks or hides arguments from the process list then arguments are
    # okay. If not may be a compatible file or standard input, readable by the
    # client process should be used. Or an entirely different API or IPC.
    [[ ! -s ~/.conf/etc/aider/env ]] || {
      . ~/.conf/etc/aider/env || failerr "E$? loading $_" || return
    }
    docker_aider_required_files=(
      $HOME/.conf/etc/aider/aider.conf.yml
      $PWD/.meta/stat/index/aider.chat.history.md
      $PWD/.meta/stat/index/aider.input.history
    )
    for x in "${docker_aider_required_files[@]}"
    do [[ -e "$x" ]] && {
        [[ -f "$x" ]] ||
          failerr "E$? required path is not a file: ${x@Q}" || return
      } || {
        # NOTE: required file formats must accept nix-style line comments
        > "$x" cat <<EOM
# Generated as generic stand-in for file ${x@Q} by aider+docker+env at $(date --iso=ns)
EOM
      } ||
        failerr "E$? touching required file ${x@Q}" || return
    done; unset x;

    # Concatenate ./.gitconfig
    # NOTE: stuff like this works bc in the container, /app is $HOME is $PWD.
    # This should not confuse the host/users Git, but it does need to be cleaned
    # up and/or hidden.
    if [[ ! -e .gitconfig ]]; then
      > .gitconfig cat <<EOM

[safe]
  directory = /work
EOM
      >> .gitconfig cat "$HOME/.gitconfig-user"
    fi

    declare -gA uc_docker_volume_map uc_docker_hostpath_flag

    uc_docker_volume_map+=(
      [/work]="${PWD:?}"
      #[/work]="${AIDER_WORKTREE:?}"
      #[/project]="${AIDER_BASEDIR:?}"
      [/tmp/aider.conf.yml]="$(realpath $HOME/.local/etc/aider/aider.conf.yml)"
    )
    # all mounts should be read-only implicitly unless other flag is set here
    uc_docker_hostpath_flag+=(
      ["${PWD:?}"]=rw
      #["${AIDER_WORKTREE:?}"]=rw
      #["${AIDER_BASEDIR:?}"]=ro
    )
    # TODO: assemble from env file keys
    uc_docker_env_arg=(
      -e OPENAI_API_KEY=${OPENAI_API_KEY-}
      -e ANTHROPIC_API_KEY=${ANTHROPIC_API_KEY-}
      -e GOOGLE_API_KEY=${GOOGLE_API_KEY-}
      -e XAI_API_KEY=${XAI_API_KEY-}
    )
    uc_docker_volume_arg=()
    User-Conf.Docker.generate-volume-args uc_docker_volume_{map,arg}
  }'

  [aider+with-task]='
  local taskid=${1:?} file
  local -n AIDER_TASK='\''chat_aider_task["$taskid"]'\''
  if [[ ! ${AIDER_TASK:+set} ]]; then
    failerr "No such task" || return
  fi
  local -n AIDER_BASEDIR='\''chat_aider_task_basedir["$taskid"]'\''
  local -n AIDER_WORKTREE='\''chat_aider_task_worktree["$taskid"]'\''
  local -n rw_files='\''chat_aider_task_edit_files["$taskid"]'\''
  local -n ro_files='\''chat_aider_task_read_files["$taskid"]'\''
  local -a argv
  [[ ! ${rw_files:+set} ]] ||
  while read -r file
  do
    argv+=( --file "${file}" )
  done < <(echo "${rw_files}")
  [[ ! ${ro_files:+set} ]] ||
  while read -r file
  do
    argv+=( --read "${file}" )
  done < <(echo "${ro_files}")
  if ((DEBUG)); then
    declare -p argv | str_prefix "${DARKGREY}  $FUNCNAME: "
  fi
  ((QUIET)) ||
  echo "${C_AUXILIARY-}Starting task ${taskid@Q} ${C_SECONDARY-}aider+user ${DARKGREY-}${*@Q}...${NORMAL-}"
  aider+user "${argv[@]}" --message "$AIDER_TASK" "${@:2}"'
)

# Id: aider,docker                               vim:set ft=bash sw=2 sts=2 et:
