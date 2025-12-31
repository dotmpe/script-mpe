
script_mpe_part_als_linux_load ()
{
: source script-mpe:tool/sh/part/als-linux.sh
}

alias cpu-cores-cnt='< /proc/cpuinfo grep core.id | wc -l'

alias uptime-info-hours='{
  < /proc/uptime read -r uptime_sec idle_sec
  cores="$(cpu-cores-cnt)"
  idleavg_sec=$(bc <<< "$idle_sec / $cores")
  utilavg_sec=$(bc <<< "$uptime_sec - $idleavg_sec")
  utilavg_pct=$(bc <<< "100 * $utilavg_sec / $uptime_sec")
  stderr echo "Uptime: $(bc <<< "scale=2; $uptime_sec / 60 / 60") hours"
  stderr echo "Idle time $(bc <<< "scale=2; $idleavg_sec / 60 / 60") hours (average of $cores cores)"
  stderr echo "Proc time $(bc <<< "scale=2; $utilavg_sec / 60 / 60") hours (average of $cores cores)"
}'

alias uptime-info='uptime-info-hours && {
  stderr echo "Cumulative utilization $utilavg_pct%"
  unset {uptime,idle{,avg}}_sec utilavg_pct cores
}'
