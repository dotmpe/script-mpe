
node('treebox') {

  // SImple "pipeline"
  // see .jenkins-pipeline.groovy for experiments

  checkout scm

  sh """#!/bin/sh
  test -e $HOME/bin || {
    ln -s $(pwd -P) $HOME/bin
  }
  """

  env.TEST_ENV=jenkins

  sh """#!/bin/sh
    . ./tools/sh/env.sh
    ./tools/ci/build.sh
  """
}

// vim:ft=groovy:
