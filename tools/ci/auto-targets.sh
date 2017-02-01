

test -n "$TRAVIS_COMMIT" || GIT_CHECKOUT=$TRAVIS_COMMIT
GIT_CHECKOUT=$(git log --pretty=oneline | head -n 1 | cut -f 1 -d ' ')
BRANCH_NAMES="$(echo $(git ls-remote origin | grep -F $GIT_CHECKOUT \
        | sed 's/.*\/\([^/]*\)$/\1/g' | sort -u ))"


test -n "$ENV" || {

  echo "Branch Names: $BRANCH_NAMES"
  case "$BRANCH_NAMES" in

    # NOTE: Skip build on git-annex branches
    *annex* ) exit 0 ;;

    gh-pages ) ENV=jekyll ;;

    * ) ENV=dev ;;

  esac
}


test -n "$ENV"  || {
  error "CI Env Error: '$ENV' (commit $TRAVIS_COMMIT, branches $BRANCH_NAMES)" 1
}


set -- "$ENV"

