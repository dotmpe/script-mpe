#!/bin/ash

export ci_init_ts=$($gdate +"%s.%N")

note "Entry for CI pre-install / init phase"

note "PWD: $(pwd && pwd -P)"
note "Whoami: $( whoami )"
note "CI Env:"
{ env | grep -i 'shippable\|travis\|ci' | sed 's/^/	/' >&2; } || true
note "Build Env:"
build_params | sed 's/^/	/' >&2

test -n "$GITHUB_TOKEN" || error "Github token expected for Travis login" 1

test -z "$TRAVIS_BRANCH" || {

    # Update GIT anyway on Travis rebuilds, but from different remote
    note "Checking '$TRAVIS_BRANCH' on bitbucket for rebuild..."
    checkout_for_rebuild $TRAVIS_BRANCH \
      bitbucket https://dotmpe@bitbucket.org/dotmpe-personal/script-mpe.git && {
        note "Updated branch for rebuild (INVALIDATES ENV, new Build-Commit-Range: $BUILD_COMMIT_RANGE)"
      } || true

  }


. "$ci_util/parts/check-git.sh"


note "GIT version: $GIT_DESCRIBE"

export PATH=$PATH:$HOME/.basher/bin:$HOME/.basher/cellar/bin

# Basicly if these don't run dont bother with anything,
# But cannot abort/skip a Travis build without failure, can they?

# This is also like the classic software ./configure.sh stage.

test -z "$BUILD_ID" || {
  test ! -d build || {
    rm -rf build
    note "Cleaned build/"
  }
  mkdir -vp build
}

( mkdir -vp ~/.local && cd ~/.local/ && mkdir -vp  bin lib share )
mkdir ~/build/local

not_trueish "$SHIPPABLE" || {
  mkdir -vp shippable/{testresults,codecoverage}
  test -d shippable/codecoverage
}

fnmatch "* basename-reg *" " $TEST_SPECS " && {
  test -e ~/.basename-reg.yaml ||
    cp basename-reg.yaml ~/.basename-reg.yaml
}

for x in composer.lock .Gemfile.lock
do
  test -e .htd/$x || continue
  rsync -avzui .htd/$x $x
done

echo '---------- Finished CI setup'
echo "Travis Branch: $TRAVIS_BRANCH"
echo "Travis Commit: $TRAVIS_COMMIT"
echo "Travis Commit Range: $TRAVIS_COMMIT_RANGE"
# TODO: gitflow comparison/merge base
#vcflow-upstreams $TRAVIS_BRANCH
# set env and output warning if we're behind
#vcflow-downstreams
# similar.
echo
echo "User Conf: $(cd ~/.conf && git describe --always)" || true
echo "User Composer: $(cd ~/.local/composer && git describe --always)" || true
echo "User Bin: $(cd ~/bin && git describe --always)" || true
echo "User static lib: $(find ~/lib )" || true
echo
echo '---------- Listing user checkouts'
for x in $HOME/build/*/
do
    test -e $x/.git && {
        echo "$x at GIT $( cd $x && git describe --always )"
        continue

    } || {
        for y in $x/*/
        do
            test -e $y/.git &&
                echo "$y at GIT $( cd $y && git describe --always )" ||
                echo "Unkown $y"
        done
    }
done
echo
note "ci/parts/init Done"
echo '---------- Starting build'
# Id: script-mpe/0.0.4-dev tools/ci/parts/init.sh
