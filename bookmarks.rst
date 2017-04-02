
.. figure:: bookmarks.svg

This uses the rsr/taxus database to store/dump data related to bookmarks.

It uses several 'datastores' to establish pluggable import and export sources
from the local database.
The default action is ``sync: local`` to import new and changed bookmarks
from the remote source once it changes.

FIXME: sync only supports local and remote

Datastores
  - :type: JSONExport
    :host: dm, pandora
    :glob: ~/htdocs/personal/bookmark/export/moz/\*.json

  - :type: HTMLExport
    :host: dm, pandora
    :glob: ~/htdocs/personal/bookmark/export/moz/\*.html

    This should be compatible with many clients, including
    those from Mozilla, Google Chrome.

  - :type: DeliciousXML
    :path: ~/htdocs/personal/bookmark/export/dlcs/posts.xml

    Parses posts and tags XML dumps.



