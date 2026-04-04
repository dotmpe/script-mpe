# .group.bash file, see User-Conf us-part for specification.
#
# Copyright 2008-2026 B. van Berkum <dev@dotmpe.com>
#
# Distributed under terms of the MIT license.
us_config_pre=User-Script.Config
us_config_cnk=f2529052
us_config_fun=(
  .detect-commands
)
declare -gA \
us_config_als=(
  [detect_versions]=.detect-commands
)
declare -gA \
us_config_ssc=(
)
declare -gA \
us_config_hooks=(
  [init]=\
'declare -gA us_uc_{cmd,bin}ver'
)

User-Script.Config.detect-commands ()
{
  :
  local cmd
  local -n verref='us_uc_binver["$cmd"]' vercmd='us_uc_cmdver["$cmd"]'
  for cmd
  do
    User-Script.OS.x.command-assert "$cmd" &&
    verref=$("$cmd" ${vercmd:---version}) ||
      failerr "E$? Determining ${cmd@Q} version"
  done
}

# Id: config,us         vim:set ft=bash sw=2 sts=2 et:
