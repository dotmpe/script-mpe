#!/bin/sh
# Creates: 2018-11-11

  # TODO: incorporate global/other projects and get glboal host picture
  # local dirs="Desktop Downloads bin .conf" ; foreach pd check
  #pd check && stderr ok "Projectdir checks out"

htd_check_tasks_hub()
{
    #check: pd check
  echo htd_tasks_load tasks-hub && {
    std_info "Looking for open contexts..."
    echo htd tasks-hub tagged
  }
  # TODO ":tasks-hub htd:gitflow-check-doc :verbose=1:vchk :bats:specs"
  #./vendor/bin/behat:--dry-run:--no-multiline :git:status"
}

htd_check_vcflow()
{
  true
}

htd_check_vcstat()
{
  true
}

htd_check_features()
{
  true
}

htd_check_specs()
{
  true
}

htd_check_vchk()
{
  true
}

htd_check_fsck()
{
  # Check file integrity
  std_info "Checking file integrity"
  echo subcmd=fsck htd__fsck && stderr ok "File integrity check successful"
}

htd_check_names()
{
  # TODO check (some) names htd_name_precaution
  #htd check-names && stderr ok "Filenames look good"
  echo htd__check_names

  # Check local names
  #{
  #  htd check-names ||
  #    echo "htd:check-names" >>$failed
  #} | tail -n 1
}
