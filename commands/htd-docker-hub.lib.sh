htd_docker_hub__help ()
{
  cat <<EOM

  tags IMAGE-NAME
  tags-raw IMAGE-NAME
    List tag names for repository (using registry v1 API)

  tag-digests IMAGE-NAME
  tag-digests-raw IMAGE-NAME
    Fetch and list all tag names and digest IDs (using registry v2 API)

  See BIN:docker-hub.lib
EOM
}

htd__docker_hub()
{
  test -n "$1" || set -- help
  subcmd_prefs=${base}_docker_hub__\ docker_hub_ try_subcmd_prefixes "$@"
}
htd_run__docker_hub=l
htd_libs__docker_hub=web\ docker-hub
