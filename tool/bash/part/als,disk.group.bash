script_mpe_part_als_disk_load ()
{
  : source script-mpe:tool/sh/part/als-disk.sh
}


df_volume_local () # ~ <df-args> [-- <Basedirs>]
{
  local -a df_args
  while [[ $# -gt 0 && $1 != -- ]]
  do
    df_args+=( "$1" )
    shift
  done
  test $# -gt 0 || set -- /srv/volume-*/*/
  #[[ ${#} -gt 0 ]] ||
  #  _ERROR "Basedirs expected" || return
  for __df_bd
  do
    std_quiet pushd "$__df_bd" || return
    command df "${df_args[@]}"
    std_quiet popd
  done
}

df_volume_local_allcol () # ~ <df-args> [-- <Basedirs>]
{
  df_volume_local --output "$@"
}

df_volume_local_readable () # ~ <df-args> [-- <Basedirs>]
{
  df_volume_local -h "$@"
}

df_volume_local_allcol_readable () # ~ <df-args> [-- <Basedirs>]
{
  df_volume_local --output -h "$@"
}

alias df:volume:local=df_volume_local
alias df:volume:local:allcol=df_volume_local_allcol
alias df:volume:local:readable=df_volume_local_readable
alias df:volume:local:allcol:readable=df_volume_local_allcol_readable

alias dfh='df -h' # readable df
alias dff='df --output' # df with all fields

alias gdf=df:annex:local:allcol:readable

du_annex_local () # ~ <du-args> [-- <Basedirs>]
{
  local -a du_args
  while [[ $# -gt 0 && $1 != -- ]]
  do
    du_args+=( "$1" )
    shift
  done
  test $# -gt 0 || set -- /srv/annex-*/*/
  #[[ ${#} -gt 0 ]] ||
  #  _ERROR "Basedirs expected" || return
  for __du_bd
  do
    std_quiet pushd "$__du_bd" || return
    command du "${du_args[@]}"
    std_quiet popd
  done
}

du_annex_local_readable () # ~ <du-args> [-- <Basedirs>]
{
  du_annex_local -h "$@"
}

alias du:annex:local=du_annex_local
alias du:annex:local:allcol=du_annex_local_allcol
alias du:annex:local:readable=du_annex_local_readable
alias du:annex:local:allcol:readable=du_annex_local_allcol_readable

# ex:ft=bash:
