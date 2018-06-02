Feature: projectdoc specifies how to handle a project

  Automation comes as script stanza's, sometimes in a build-/test-/distribution-
  pipeline form, and other times as standalone script pieces executed at
  specific times.

  Several of these may exist together, testing one and the same or different
  components. Some package description overlap, others are distinct parts.
  Some have specific host requirements, and/or may have unique ways built-in
  to deal with requirements. Etc. Etc.

  The following list has some status-quo:

  - GIT hooks
  - Makefile, also configure.sh, and M4 macro's
  - NPM's package.json, including scripts init/run/test/publish
  - Sf2's components.json
  - Also Bower's component.json. W3C's manifest.json
  - our own package.y*ml
  - Maybe some python packages. And then there's so many more languages, modern
    ones with novell ideas about project/dependency management too.
  - Maybe CI definitions.
    Github pages uses ``_config.yml theme`` to set Jekyll GH page generator.
  - Standard test directories, reports

  Getting all these into a single profile is difficult, although not impossible.
  The following high level steps break it up into seperate features, before
  arriving back here to test high level project behaviour.

  1. Step one is to represent the projects bits in a single form.
     This repsonsibility is taken up by package.y*ml

  2. Next choosing a mode of operation, ie. setting one or more contract in the
     form of workflows for the project to conform to. Ie. a project must compile,
     build, package, test, etc.

  3. Lastly these concepts are exposed in tools. 


  @TODO
  Scenario: checkouts advertise their importance or significance

    To manage these entities, `projectdir` or alias `pd` provides scripts, and
    reserves certain script ID's. So that projects can extend (override or
    amend) Pd's standard routines on a per-project basis.

    These scripts are part of a basic project lifecycle, which can basicly be
    described as:

      init > (dev) > deinit

    But each project provides its own specific flow, likely more than one, e.g.:

      init > build > test
           > package > dist
           > release > dist
           > deinit

      init{,-*}
      {,*-}init
      build{,-*}
      check{,-*}
      {,*-}status
