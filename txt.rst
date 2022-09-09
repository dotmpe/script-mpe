Feature: fold/unfold hierarchy (the outline) to/from records (the list)

Background:
  TODO: move to syntax docs

  lists have multiple x-refs:

  - cite to record-id or unid
  - provide link from record-id to global id or complex specs via link
    records, ie 'see also', so to keep long strings out of human readable
    records.


Plain text file formats
-------------------------

sha256e
    A list format where each line is a SHA256E GIT Annex backend content key
sha2list
    A list format where each line contains the parts of a SHA256E Annex key with
    something extra: the entire filename iso. only filename extension, and
    more optional tab-separated fields.

table.{ck,md5,sha,sha2}
    A list of checksums followed by filename. Ordrinarily two spaces for
    separation, full filename path. Only for the cksum the key is two parts: the
    hash, a space, and size in bytes.

todo.txt
    List for plain-text tasks
outline
    A YAML + todo.txt format?

catalog, package, etc.
    A YAML/JSON list with objects, see schema/catalog, package

