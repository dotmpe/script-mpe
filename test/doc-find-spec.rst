
Find document(s)

See feature-doc__ for top-level business case description, this amends
doc-find component in doc__

To provide a level of flexibility at both user interface and backend
implementation, the fixed argument setup allows to detect arguments within a
local package context. And based on that, decide which of the following
subroutine forms to invoke:

- find-name-fragment
- find-fragment
- find-name

Output can be grep-forms,
and should allow for absolute host path, relative path or local name.

Ordering is more difficult and expensive to implement so does not need to be
available everytime.
But if it is, can help to select the most important doc(s) 1-n

The units under test are described by the component trees and package schema:

Components include

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
