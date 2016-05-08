
node('treebox') {

  // SImple "pipeline"
  // see .jenkins-pipeline.groovy for experiments

  checkout scm

  sh """#!/bin/sh
  test -e \$HOME/bin || ln -s \$(pwd -P) \$HOME/bin
  """

  sh """#!/bin/sh
    . ./tools/sh/env.sh
    export TEST_ENV=jenkins
    ./tools/ci/build.sh
  """
}

// vim:ft=groovy:
