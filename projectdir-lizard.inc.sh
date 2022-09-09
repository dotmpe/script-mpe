
# Lizard is a python based Py/Java/C/PHP... code complexity reporter

pd_register lizard build

pd_autoconfig__lizard()
{
  test -x "$(which lizard 2>/dev/null)" || return 1
  return 0
  # IMPR: may want to detect languages
}


pd_flags__lizard=iI
pd__lizard()
{
  pd_autoconfig__lizard || error pd-lizard 12
  test -n "$report" || local report=$(setup_tmpf .lizard-report $io_id)

  # Total nloc   Avg.NLOC  AvgCCN  Avg.token   Fun Cnt  Warning cnt   Fun Rt nloc Rt
  trueish "$verbose" && {
    lizard $@ | tee $report
  } || {
    lizard $@ > $report
  }

  local totals="$(echo $(tail -n 1 $report))" \
    nloc nloc_avg ccn_avg tokens_avg warnings fun_rt nloc_rt

  nloc=$(getidx "$totals" 1)
  nloc_avg=$(getidx "$totals" 2)
  ccn_avg=$(getidx "$totals" 3)
  tokens_avg=$(getidx "$totals" 4)
  fun_cnt=$(getidx "$totals" 5)
  warnings=$(getidx "$totals" 6)
  fun_rt=$(getidx "$totals" 7)
  nloc_rt=$(getidx "$totals" 8)

  note "nloc=$nloc"
  note "nloc_avg=$nloc_avg"
  note "ccn_avg=$ccn_avg"
  note "tokens_avg=$tokens_avg"
  note "warnings=$warnings"
  note "fun_rt=$fun_rt"
  note "nloc_rt=$nloc_rt"
  #note "line=$line"
}


#-Ewordcount


