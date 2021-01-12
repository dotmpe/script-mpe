Feature: fold/unfold hierarchy (the outline) to/from records (the list)

    TODO.txt lists are suitable for terse task descriptions, but allow for
    very, very long lines which are not very nice to edit. To accommodate for
    all the bits involved by a task, the texts and tag parts can easily (will)
    grow beyond "terse". Splitting into different files with specific scopes
    can only alleviate a little to none.

    To allow for easier plain text editing and accommodate for growth, a way to
    break up items and pull-out reusable parts common to sets of items to and
    reassemble from lines would help.

    The TODO.txt format already defines some meta parts, we need to add
    rules for breaking up tasks into parts and vice versa, and one or more
    formats to represent those parts in broken down form.
    The simplest way would be to extract TODO.txt tags and other fields, lookup
    the usage histogram for each part, and then output an indented text file with
    extracted parts as nodes. Our target format could also allow (soft)
    linebreaks, while ofcourse TODO.txt files have no newlines in task descriptions.

    This however creates a strictly exclusive nesting of tasks under items.
    With lots of parts, this may create a long file if nothing smart is done
    about combining nodes ie. by adjacency.


    would be to split on meta character(s), a more complex way
    would be to go by substructures, possibly apply cardinality rules. Etc.

    That gives roughly two text op-modes, rearrangement, and insert/remove.

    Rearrangement is probably better left to other extensions, for (un)fold it
    only requires the latter. Iot. simplify parsing as much as possible.

    Enter unfold/fold. Based on the TODO.txt we recognize some extended syntax,
    and identify ranges and nesting level.

    - record-id/sections: retrieve the spans and break up to indented list.
    - lists: break up into lines
    - (date)time annotations


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

