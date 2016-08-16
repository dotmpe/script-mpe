
node('devbox') {

  // Simple "pipeline"
  // see .jenkins-pipeline.groovy for experiments

  checkout scm

  def PWD = pwd()

  withEnv([
    'PYTHONPATH=$HOME/lib/py:$PATH',
    'PATH='+PWD+':/usr/local/bin:$HOME/.basher/bin:$HOME/.local/bin:$PATH'
  ]) {

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

    sh """#!/bin/sh
      . ./tools/sh/env.sh
      export TEST_ENV=jenkins
      . ./tools/ci/build.sh
    """
  }
}

// vim:ft=groovy:
