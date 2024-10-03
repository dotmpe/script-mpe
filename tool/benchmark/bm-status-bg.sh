
test_report ()
{
  report_time "${*:-$_}" samples=$samples runs=$runs load:$(less-uptime g 3) host:$HOST
  ${pause:+sleep $pause}
}


source ${US_BIN:=$HOME/bin}/tools/benchmark/_lib.sh
sh_mode strict isleep


status.sh bg running ||
  status.sh bg server &

status.sh bg check

base=$(basename -- "$0")
BMLOG=$HOME/.local/statusdir/log/benchmarks.log

: "${delay_step:=${wait:-10}}"
: "${delay_loop:=50}"
samples=1
runs=1
sleep_v=false
sleep_quiet=false

set -- list active
while true
do

# Show baseline performance
test_baseline $samples $runs std_quiet status.sh "$@" &&
test_report 1. user-script &&
sleep $delay_step || exit $?

# Show run-eval performance

test_baseline $samples $runs status.sh bg run-eval std_quiet script_run "$@" &&
test_report 2.1. us+bg || exit $?
sleep $delay_step || exit $?

test_baseline $samples $runs status.sh scache run-eval std_quiet script_run "$@" &&
test_report 2.2a. scache || exit $?
sleep $delay_step || exit $?

test_baseline $samples $runs bash ${UCONF:?}/.meta/cache/status-run-eval.sh std_quiet script_run "$@" &&
test_report 2.2b. sc-script || exit $?
sleep $delay_step || exit $?

# Do same with run-cmd with capture and pass of stdout/stderr through FIFO iso.
# regular tty fd 1 and 2.

test_baseline $samples $runs std_quiet status.sh bg run-cmd script_run "$@" &&
test_report 3.1 us+bg+out || exit $?
sleep $delay_step || exit $?

test_baseline $samples $runs std_quiet status.sh scache run-cmd script_run "$@" &&
test_report 3.2a. scsrc+out &&
sleep $delay_step || exit $?

test_baseline $samples $runs std_quiet bash ${UCONF:?}/.meta/cache/status-run-cmd.sh script_run "$@" &&
test_report 3.2b. scscr+out &&
sleep $delay_step || exit $?

echo
sleep $delay_loop || exit $?
done | while read -r reportline
do
  test -n "$reportline" &&
    echo "$(date +%s) $base $reportline" >> "$BMLOG"
  echo "$reportline"
done
