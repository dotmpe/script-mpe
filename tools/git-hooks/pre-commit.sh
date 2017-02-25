set -e ; pd run htd:gitflow-check-doc :verbose=1:vchk :bats:specs ./vendor/.bin/behat:--dry-run:--no-multiline :git:status
