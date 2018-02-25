Commands and functions dealing with documents.

Objectives
----------
- Recognize document files by filename extension, default(s)::

    .rst .md .txt .feature .html .htm .wiki .textile .confluence

  See `htdocs:note/text``, ``basename-reg.yaml``

- Find by name or content, or both.

  Select handler from context:

    - find, grep
    - git ls-files, git grep
    - other

- Specify name, content or both in specs or override handler::

    file-*-name content-grep
    path/name ^Title

    glob:
    find:
    git-ls-files:
    git-grep:

- Order files to find most significant result
- List results in line-based formats, for use by other scripts


Design
------
- Htd subcommands, shell library using list, match, htd
- Htd subcommand group `doc` to expose plumbing func in htd/doc env
- Load package env, and initialize local doc context for main functions.

    TODO: Initial design for main functions to find docs. Update edit scripts
    later. Then step back to files/res, see about non-fs store and metadata.

Handlers
    - Select both preferred doc handler and get new handlers from ``package.y*ml``
    - For `find-doc|find-docs`, ``$package_doc_find`` specifies handler.
    - Related schema emerges, either more specific--to select any file
      name/content (not only docs)--and more generic to select any local resouce
      given name, fragment sepc.
    - Override local or default handler by ID-prefixing the spec.

Arguments
    Initial arguments are specific to handler. The last, optional argument is
    package context. Thus a chicken and the egg problem arises detecting the
    handler.

    Also to allow flexible use, we have three permutations of arguments which
    may require different handlers for optimal implementation.

    So for documents search the arguments are fixed to three,
    with the first two specifying name and content match patterns or IDs.
    Thereupon it is possible to specify a basic fall-back scenario for
    handlers to use for main function `find-docs`.

More details on the exact business heuristics, and design/component implications
are are in addendums to the unit/feature tests, listed in the Test__ section
below.

Components
----------
`documents <doc.lib.sh>`__
    * doc-load
    * doc-init-local

    - doc-path-args - XXX: parse path args
    - doc-find-name - look for filenames based on find+ignores
    - doc-grep-content- look for filenames/lines based on grep
    - doc-main-files - XXX: return main (local) document files

    htd-rst-doc-create-update
        Generate or update document file (rst only)

    htd-edit-and-update
        Get editor session, remove unchanged boilerplate document

`htd <htd.sh>`__
    doc [ARGS...]
        | htd_doc_<subcmdid> [ARGS...]
        | doc_<subcmdid> [ARGS...]

    find-doc [ARGS...]
        | -F|find-doc [<path>|<localname>] [<fragment>] [<project>]

        TODO: find one document by name or content
        Accept one to three arguments

    find-docs [ARGS...]
        TODO: find all documents by name or content

Test
____
The test documentation is also the natural place for more verbose notes on
the workings of the components.

- `find-doc-spec <test/doc-find-spec.rst>`_


Schema
______
``package``
    :res:
        :find:
            | htd-find-local [PATHNAME] [FRAGMENT]

    :doc:
        :find:
            | htd-doc-find-local | head -n 1
            | doc-find | head -n 1

    :docs:
        :find:
            | htd-doc-find-local [PATHNAME] [FRAGMENT]

        :find-name-fragment-default: <id>
        :find-name-fragment:
            :<id>:
                | func(): [ARG]

        :find-name-default: <id>
        :find-name:
            :<id>:
                | func(): [ARG]

        :find-fragment-default: <id>
        :find-fragment:
            :<id>:
                | func(): [ARG]

..
