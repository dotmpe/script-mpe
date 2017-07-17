From OPML 2.0 spec:

  "An outline is a tree, where each node contains a set of named attributes with string values." [#]_


OPML is an XML format specifying one ``opml`` root element with ``head`` and
``body``, and any configuration of ``outline`` elements below the latter.
The former has a set of metadata and configuration sub-elements that applies to
the entire document, rather than allowing for complex attribute structures.

The `nodes`, or ``outline`` instances in this case, have a specific set of
attributes:

- ``text``, a generic field for the user,
- ``type``, a generic one for implementation classification,
- ``xmlUrl``, required for 'rss' type nodes,
- ``htmlUrl``, optional for 'rss' type nodes, derived from the feed at ``xmlUrl``,
- ``language``, derived from the feed at ``xmlUrl``,
- ``version``, RSS version derived from the feed at ``xmlUrl``,
- ``isComment`` for integrated comments,
- ``isBreakpoint`` for a specific case of application (script processing),
- ``created`` the only generic date-related field, and
- ``category`` a predefined way of applying multiple additional classifiation schemes.

No mention of user, or other date types.

The spec requires XML namespacing for extensions.

For ``type``, it has one particular application 'rss'. No folders, or
separators.



.. [#] <http://dev.opml.org/spec2.html>


