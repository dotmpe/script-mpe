Docstat
=======
Statusfile for documents. Each entry records descriptor attributes and simple
document outline in semi-TODO.txt line format.

Document Ids generated from basename, so basenames need to be unique per
project. See htd components.

Ids are prefixed, see htd prefixes. So Ids need only to be unique per project
or working dir. [PREFNAME]_

To be as flexible as possibly with allowed characters, the line has two
markers used for parsing. Allowing to split the line into three variable length
parts:

- The first is ``[^_A-Za-z]``, ie. the first part can be all numbers, any of
  some helper chars. Only exception it can't have a variable/Id character.
  [descriptor]_

- The first context ``[@+]``\ ... marks the end of the document title/label/short descr.
  And also the primary context.

  A context is required, default of ``@/`` or ``@.`` is fine for now.

This allows any seq of number, including dates or times in the first line part,
second exactly two (id and title) with any spaces (and not-\ ``[@+]``) in the title,
and finally any sort of tag set.

::

    \*Ts        Doc-Id            Document-Title   Primary and other contexts, Ids, refs, metafields
    1535632541  HT:record-id-123  Some Title       @Context +project @context ABC-123 #ref [citeref] meta:foo

Given that the first parts and Id are generated, the only sanitation needed is
on the title, and tags. But some of those we'll solve in the source documents
rather than in the ``docstat.lib.sh``.

.. [PREFNAME] Prefix name is required, ie. for '/' should be 'ROOT:' not ':'.
.. [descriptor] Can be empty, ie. docstat format may start with Id or descriptor
   can be stripped for ease of interaction with other lib, sys.

..

  TODO: include section outline targets (#-prefixed), can create paths just as dl-term-paths does for contexts


Contexts and tags
-----------------
Tag formats allow misc. user-defined strings for different purposes, the format
indicating the role.

The main purposes for tags are external Id and reference.

Tags can be generated from the content, e.g. list sections, cites, references,
footnotes, figures, etc.

These Ids allow external reference to document segments, cross-indices etc. Ie.
linking of content naturally across files boundaries, but also processing like
duplication, synchronisation, or migration.

It implies more modelling, and imposing structures. But only for specific tags,
and purposes. Leaving hopefully as flexible setup as possible for different
projects, deployments.


See generic doc_ for some

XXX: more on contexts and lists; but lots of work, code, docs to-do there

Example use cases, XXX: thoughts and ideas

  - not all document structures intially conform to global standards, documents
    can only evolve if no global standard is imposed. In other words not all
    docuemnts (and contexts) are equal, but some just are special.

    Using camel case vs. lower-case we can recognize either type,
    and with package.yml ctx/pwd names can be mapped, and other settings given.

  - a literal user document w/o tags has only its Id. And while user-readable,
    the only automated processing available is cross-referencing the Id with
    other documents. Or to be done a level down; the markup language parser.
    Aside no internal structure is known, so the cross-reference targets span the
    entire range of the document.

  - what tag would link to what sort of segment is an arbitrary affair, but
    some decision needs to be made. Detailed mapping requires a suite to be
    build around the parser.

    initial efforts are more simplistic, focus on context-tag to rSt
    definition-list term mapping, its a personal favorite to write outlines.

    And with rst2xml plus a XSLT 1 or 2 processor the structure can be retrieved
    without writing any new binary distributable or scripted API impl.

    Though beside some sanitation there is a bit of shell scripting involved
    reformatting the XSLT output.

  - similary context might be mapped with sections.
    other formats like Markdown would make for nice plain text outlines.

    But giving Ids to the document segments might require a bit extra code.
    Du/rSt shines in the area of internal doc structure Id and cross-reference.


Multi-leaf relative path
------------------------
Since not documented elsewhere, some notes on single-line notation for several
paths within the same (document) structure. A side product of the tpaths XSLT
script::


    Term 1./Term 1.1./../Term 1.2./../../Term 2.

A nested structure of four terms given as one path.
But any nested structure that has sensible Ids can be used.

Outlines of titles, sections. Allowing for external reference to segments,
and locating spans within sub-document spans.


Extended stats
--------------
recording stats with descr. allows to sync values accross hosts.
but primarily to update docstat entry as mtime increases.
and track build status, rebuild failures.

ctime is always updated with mtime as content length would have changed too,
it is not usefull to track individual stat attr either

not sure about atime. maybe sync is usefull, maybe not.

missing are things like birth date, first seen, last seen and other lifecycle
events, or states.

TODO.txt monitors none, creation, or delete/close and creation.

monitoring lifecycle is usefull, but should assume docs or contexts can be
re-opened. Ie. the current period is only the last in a seq.

the exact descriptor format can vary per class, primary context is used to
automap to stat parser. Extra parsers should be provided per env.


