
node('devbox') {

  stage("Checkout") {

    // Simple "pipeline"
    // see .jenkins-pipeline.groovy for experiments

    sh '''
      echo DCKR_JNK_VERSION=$DCKR_JNK_VERSION
      echo DCKR_JNK_JJB_FILE=$DCKR_JNK_JJB_FILE
    '''

    String checkout_dir="../workspace@script"
    if (fileExists(checkout_dir)) {
      dir checkout_dir
    } else {
      checkout scm
    }

    sh "mkdir -vp build"

    // The rest of this stage deals with build name/description
    rev = getSh "git rev-parse HEAD"
    ref = getSh "git show-ref | grep -v remotes | grep ^${rev} | cut -d ' ' -f 2 | head -n 1"
    branchName = getSh "echo ${ref} | cut -d '/' -f 3- "
    git_descr = getSh "git describe --always"
    rev_abbrev = getSh "echo $rev | cut -c1-11"

    currentBuild.displayName = "${git_descr} b${env.BUILD_NUMBER}"
    currentBuild.description = \
      "$rev_abbrev ($branchName)  Job version: $SCRIPT_MPE_VERSION"
  }

  def PWD = pwd()

  withEnv([
    'PYTHONPATH=$HOME/lib/py:$PATH',
    'PATH='+PWD+':/usr/local/bin:$HOME/.basher/bin:$HOME/.local/bin:$PATH'
  ]) {

    stage("Setup") {

      sh """#!/bin/sh
      pwd
      ls -la \$HOME/
      test -e \$HOME/bin || ln -s \$(pwd -P) \$HOME/bin
      test -d \$HOME/lib/py || mkdir -vp \$HOME/lib/py
      test -h \$HOME/lib/py/script_mpe || ln -s $PWD \$HOME/lib/py/script_mpe
      """

      sh """#!/bin/sh
        Build_Deps_Default_Paths=1 \
        ./install-dependencies.sh -
      """
    }

    stage("CI Build") {

      sh """#!/bin/sh
        . ./tools/sh/env.sh
        export TEST_ENV=jenkins
        . ./tools/ci/build.sh
      """
    }
  }
}

def getSh(cmd) {
	sh "sh -c \"( $cmd ) > build/cmd-out\""
	// returun output minus trailing whitespace
	return readFile("build/cmd-out").trim()
}

// vim:ft=groovy:
