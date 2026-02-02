proc_linux_als_pre=OS.Linux.Alias
proc_linux_als_cnk=06c9414e

proc_linux_als_fun=()

declare -gA \
proc_linux_als_hooks=(
)

declare -gA \
proc_linux_als_als=(
)

declare -gA \
proc_linux_als_ssc=(
  [proc.linux.cpu.cores+cnt]='wc -l < <(< /proc/cpuinfo grep core.id)'
  [proc.linux.cpu.cores+raw]='< /proc/cpuinfo grep core.id'

  [proc.linux.uptime-info-hours]='{
  < /proc/uptime read -r uptime_sec idle_sec
  cores="$(proc.linux.cpu.cores+cnt)"
  idleavg_sec=$(bc <<< "$idle_sec / $cores")
  utilavg_sec=$(bc <<< "$uptime_sec - $idleavg_sec")
  utilavg_pct=$(bc <<< "100 * $utilavg_sec / $uptime_sec")
  stderr echo "Uptime: $(bc <<< "scale=2; $uptime_sec / 60 / 60") hours"
  stderr echo "Idle time $(bc <<< "scale=2; $idleavg_sec / 60 / 60") hours (average of $cores cores)"
  stderr echo "Proc time $(bc <<< "scale=2; $utilavg_sec / 60 / 60") hours (average of $cores cores)"
}'

  [proc.linux.uptime-info]='proc.linux.uptime-info-hours && {
  stderr echo "Cumulative utilization $utilavg_pct%"
  unset {uptime,idle{,avg}}_sec utilavg_pct cores
}'
)
