:Created: 2016-01-24

Start docs for some projectdir actions.

Most docs, TODO points are in projectdir-meta for now.
Migrate here upon testing.

Sub-commands are documented in projectdir.sh


TODO: testing
TODO: submodule support
TODO: annex support


FIXME: run bg instance per unique document. add reload command.

TODO: compile packaged scripts from literate style scripting like below. Package for subcomamnds, and with relations/decorations, with embedded scripts or to annotated external scripts.

- Annotation like this should eliminate scattered metadata files
  like .pd-test
  and consolidate the settings into a single definitive document.

pd
  - annotate ./projectdir.sh

  pd run
    bats-spec
      ..
    bats
      - dependencies bats
      - ``./test/*-spec.bats | bats-color.sh``
    mk-test
      - make test
    git-versioning
      - git-versioning check
    sh:*
      ..

  pd install
    bats
      - installs bats BATS_VERSION PREFIX
    jjb
      .. etc.

