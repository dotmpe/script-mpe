set -e ;
git annex pre-commit .
pd check vchk bats-specs
