#!/bin/sh

[ -n "${PROJECT-}" ] || export PROJECT="$(project_id "")"

test -z "$PROJECT" && {

  warn "No project dir recognized"
} || {

  test -n "${UNVERSIONED_FILES-}" || {

    # TODO: move UNVERSIONED_FILES setting to jenkins-ci
    test "$(hostname -s)" = "jenkins" && {
      export UNVERSIONED_FILES=$JENKINS_HOME/unversioned-files/$PROJECT
    } || {

      [ -n "${UNVERSIONED_DIR-}" ] || export UNVERSIONED_DIR=../unversioned-files
      export UNVERSIONED_FILES=$UNVERSIONED_DIR/$PROJECT
    }
  }
}

#
