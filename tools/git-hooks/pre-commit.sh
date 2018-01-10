test -z "$scm_nok" || exit $scm_nok ; echo "pre-commit: Set scm_nok= to override exit" >&2
set -e ; pd run htd:gitflow-check-doc :verbose=1:vchk :bats:specs
