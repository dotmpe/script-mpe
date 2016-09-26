
pd
  Test specifications for Projectdir, using Projectdoc.
  For a description of the generic project metadata testing, see also
  ``package.y*ml`` manual.


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

        - pd supports several modes of project identification/metadata,
          aided by either/or the filesystem context, the Pdoc, and the package
          metadata document.

          - Basic attributes [spec pd-2.1.]
          - Context sensitive [spec pd-2.1.]

     2. pd/sh lib source code syntax is valid
     3. projectdoc is YAML, and valid acc. to schema/package.yml


  1. Uses cases (Bats)

     1. Consolidate and cleanup existing project

        - TODO: Pd use-case 4: add a new prefix from existing checkout

     2. Hack on any previous project

        1. enable, disable a checkout without errors
        2. update and check for remotes.
        3. track enabled per host, or globally.

     3. TODO: determine SCM and test status of all projects

        - TODO: tell about a prefix; description, remotes, default branch, upstream/downstream settings, other dependencies.


  2. Metadata

     1. Basic attributes

        an object, block of key -> value mappings, which
        identifies a project by:

        - id; (required) an ID string that corresponds to a globally unique project
        - name; a more loose unique title/label string
        - pd-meta/prefix; corresponds to a checkout in a projectdir relative to a
          projectdocument.

      2. Contexts (documents/filesystem)

         FIXME: `application/x-*` is not a valid mediatype [#]_

         Pdir/Pdoc:
          a per-host directory of prefix to repo path mappings, with data in
          the `pd-meta` schema recorded in a Pdoc.

         ``package.y?ml``:
           a per project metadata container YAML, containing a list of objects.
           At least one object has an `id`, `type` and `main` attribute,
           and the type equals `application/vnd.dotmpe.project`.

         pd-meta:
           the schema for the records in a Pdoc, or the like-named attributed
           in a `application/vnd.dotmpe.project` object.

          other:
            with none of the above present, the following local files have a
            special significance

            - .app-id
            - .pd-check
            - .pd-test


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


.. [#] http://stackoverflow.com/questions/18969938/vendor-mime-types-for-api-versioning

