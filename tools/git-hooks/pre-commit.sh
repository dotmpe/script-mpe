test -z "$scm_ok" || exit 0
htd gitflow-check-doc &&
pd vchk
#set -e ; pd run htd:gitflow-check-doc :verbose=1:vchk :bats:specs
#behat:--dry-run:--no-multiline :git:status
