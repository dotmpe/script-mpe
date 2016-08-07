
pd
  Test specifications for Projectdir, using Projectdoc.
  For generic project metadata testing, see Package specs.


  0. Specs (Bats)

     1. pd is exec cmd

        1. pd functions like expected from a command line program

           1. default no-args
           2. ${bin} help
           3. ${bin} version

        2. pd detects checkout

           - handles SCM backends

        3. pd detects projectdoc

           - lists prefixes, handles metadata updates
           - each prefix metadata matches schema

        4. pd detects package

           - works with Projectdoc, default metafiles, has overrides

           - generates pre-commit hook from a .package.sh

              - ${bin} regenerate

           - TODO: consolidates Package metadata (core, pd-meta) into Projectdoc
             (on enable, ci, reload)

           - updates package from Projectdoc (on initialize)

        - pd  enables/disables projects

           - pd enable restores disabled project

     2. pd/sh lib syntax is valid
     3. projectdoc is valid YAML


  1. Uses cases (Bats)

     1. Consolidate and cleanup existing project

        - TODO: Pd use-case 4: add a new prefix from existing checkout

     2. Hack on any previous project

        1. enable, disable a checkout without errors
        2. update and check for remotes.
        3. track enabled per host, or globally.

     3. TODO: determine SCM and test status of all projects

        - TODO: tell about a prefix; description, remotes, default branch, upstream/downstream settings, other dependencies.


  meta-spec.bats
    - default no-args
    - ${bin} help
    - ${bin} $f_pd1 -H host1 list-enabled
    - ${bin} $f_pd1 -H host1 list-disabled
    - ${bin} $f_pd1 -H host2 list-enabled
    - ${bin} $f_pd1 -H host2 list-disabled
    - TODO: ${bin} $f_pd1 -H host1
    - ${bin} clean-mode

  args-spec.bats
    Verify shell works as expected wrt. shifting arguments, iot. enable a preset
    number of default arguments; ie. that are allowed to be empty.

    - argument defaults, shift to 2
    - argument defaults, shift to 3

