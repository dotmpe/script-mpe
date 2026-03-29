# Copyright: (C) 2026 hari <hari@t470p>
#
# .group.bash file, see User-Conf us-part for specification.
#
# Distributed under terms of the MIT license.

docker_aider_pre=Docker.Aider
docker_aider_cnk=7bc2a6f1
docker_aider_man='Aider is an LLM "coding" agent. Most agentic text generation
LLM are set up as chat, and are enhanced with session maps, modes, contexts and
such concepts to provide additional resources to a chat session.

Aider (dockerized) works with many several such LL models, from the directory
/app. There, the client expects a Git checkout which then an online LLM can
offer to "help to modify". All through using the aider program as client. And
running more or isolated from the user OS, through cgroups.

As each session thus accumulates a context, all the input to the model starts to
eat at a token quota. Some services may be free, most require an account with
active pay-for-service plan. Aider can use Ollama API endpoints to run local LLM
models (if sufficient RAM and CPU or GPU capacity is available).

The ~ scripts use /work to mount PWD, as a better semantic match. It also
prepares non-PWD paths for the container. And specify wether any of those have
write access. I do not have any experience with these client programs, so this
is all for experimenting with current interfaces.

NOTE: HOME ie. ~/ also points to /app, and USER is appuser.
TODO: have not taken any effort to try and create/rerun containers, current
  setup starts a new container from the local image and will need a new server
  session
FIXME: since aider seems to use PWD as writable temp the worktree
  cannot be read-only
'
docker_aider_grp=( uc-docker )

declare -gA \
docker_aider_als=(
  # Main execution context (with echo of entire line to mark switch of context)
  [aider+docker]='aider+docker+env &&
  echo "> docker run -it --rm ... paulgauthier/aider ${@@Q}" &&
  docker run -it --rm \
    "${uc_docker_volume_arg[@]}" \
    "${uc_docker_env_arg[@]}" \
    -e HOME=/work \
    -w ${AIDER_BASEDIR:-/work} \
    paulgauthier/aider'

  [aider+docker+bash]='aider+docker+env &&
  echo "> docker run -it --rm ... --entrypoint bash paulgauthier/aider ${@@Q}" &&
  docker run -it --rm \
    "${uc_docker_volume_arg[@]}" \
    "${uc_docker_env_arg[@]}" \
    -e HOME=/work \
    -w ${AIDER_BASEDIR:-/work} \
    --entrypoint bash \
    paulgauthier/aider'

  #[aider+docker+nogit]='aider+docker --no-git'

  # Main alias, with all current user settings and parameters applied
  [aider+docker+user]='aider+docker \
    --no-show-release-notes --no-gitignore \
     --input-history-file .meta/stat/index/aider.input.history \
     --chat-history-file .meta/stat/index/aider.chat.history.md \
     --config /tmp/aider.conf.yml'
  [aider]='aider+docker+user'

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
        > "$x" cat <<EOM

# Generated placeholder file at $(date --iso=ns)
EOM
      } ||
        failerr "E$? touching required file ${x@Q}" || return
    done; unset x;

    > .gitconfig cat <<EOM

[safe]
  directory = /work
EOM
    >> .gitconfig cat "$HOME/.gitconfig-user"

    uc_docker_volume_map+=(
      [/work]="$PWD"
      [/tmp/aider.conf.yml]="$(realpath $HOME/.local/etc/aider/aider.conf.yml)"
    )
    # all mounts should be read-only implicitly unless other flag is set here
    uc_docker_hostpath_flag+=(
      ["$PWD"]=rw
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

  [aider+with-task]=\
'  local task=${1} aider=${2} file
  local -n AIDER_TASK='\''aider_task["$task"]'\''
  local -n AIDER_BASEDIR='\''aider_basedir["$task"]'\''
  local -n read_files='\''aider_read_files["$task"]'\''
  local -a argv
  while read -r file
  do
    argv+=( --read "${file}" )
  done < <(echo "${read_files}")

  [[ ${AIDER_TASK:+set} ]] && {
    "$aider" "${argv[@]}" --message "$AIDER_TASK"
    return
  } ||
    "$aider" "${argv[@]}" "${@:3}"'
)

# Id: aider,docker                               vim:set ft=bash sw=2 sts=2 et:
