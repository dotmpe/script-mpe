test -z "$scm_ok" || exit $scm_ok
set -e ; pd run htd:gitflow-check-doc :verbose=1:vchk :bats:specs
