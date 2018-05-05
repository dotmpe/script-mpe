Feature: Find document(s)

    Using strictly names, extensions and other path/glob values

    track

    - main document (per CWD, or inherit)
    - other main documents, or
    - all local documents
    - reference and fragment ids, and
    - cross references

    Given a local context it should be possible to list and query all documents.

    To order the results various levels of metadata might be required.

    # See feature-doc__ for top-level business case description, this amends
    # doc-find component in doc__


TODO:

- Ideally rst, md, txt, wiki, feature are supported but basic shell implementation does simple txt only.
- Feature docs have no inherent syntax.
- Vimdoc provides a nice and simple ref/target ID syntax.
- Fragments would include ranges, ie. more complexity. Leave that to markup processors too.


To provide a level of flexibility at both user interface and backend
implementation, the fixed argument setup allows to detect arguments within a
local package context. And based on that, decide which of the following
subroutine forms to invoke:

- find-name-fragment
- find-fragment
- find-name

Output can be grep-forms,
and should allow for absolute host path, relative path or local name.

TODO: Components include

- htd docs - group
- htd doc - group
- htd docs find - frontend to the primary handler
- htd doc find - idem. to the second

Schema includes package env declaring which routine handles arg forms,
both at frontend, and backend side:

- package_doc_find
- package_docs_order
- package_docs_find
- package_docs_find_name_fragment{,_default}
- package_docs_find_name{,_default}
- package_docs_find_fragment{,_default}

.. __: <../doc.rst>`__
.. __: ./doc-find-spec.feature

    Scenario Outline: given either or both a name and content match pattern, give the matching documents ordered by priority

        When the user runs "echo"..

        Examples:
            | foo | bar |
            | 1 | 2 |
