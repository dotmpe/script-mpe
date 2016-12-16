Edit Decision Lists
===================


Range link formats
------------------
Lets define
- *ranges* as start and end position.
- *Spans* are offset (same as start) and length (ie. end - start + 1 ).
- All serialized references should have 1-indexed offsets.

* To keep character count down, only serialize spans, and allow to leave out
  the second number and '-' (if length is 1).

- Still some (redundant) variants of spans and ranges are usually preferable to
  have, in particular the offset(s) relative to a particular line.

  Conventional shell tools like sed, grep and cut are all line based.
  While the algoritm proposed by `transquoter` disregards all whitespace.
  To resolve a standard span requires a `read` command that 1. decodes all
  bytes to symbols and 2. then collapses all whitespace.

* Living with ASCII source code, we can allow to forgo the bytestream to
  character stream mapping.

- But to handle line-wrapped content, either the `read` utility is required,
  or the spans available should be based on lines. Iow. a shell compatible
  references list both a line range or span, and a character range or span
  within these lines.

With the above in mind, the initial format expands on the `grep -rn` output.
E.g.::

  $ grep -rn tag edl.rst
  edl.rst:14:  Conventional shell tools like sed, grep and cut are all line based.
  edl.rst:26:With the above in mind, the initial format expands on the `grep -rn` output:

There are a lot of fields, in the hope its flexible enough to last as a
standard for some initial tooling. The colon-separated fields are:
::

  <1-prefix>
  <2-file>
  <3-line-span>
  <4-descr-span>
  <5-descr-line-offset-span>
  <6-cmnt-span>
  <7-cmnt-line-offset-span>
  <8-optional single line label/text/description/...>

Prefix and File Path
  I added the prefix to enable an optional path-based context to a reference.
  If <file> does not represent an existing file by itself, then it might
  be a relative path from <prefix>.

  But the first two fields might as well be used not for directory or filenames
  but other location or identification schemes. In general field 1 is not used
  unless its given meaning in some workflow, and field 2 would be the local
  relative or absolute filename.

Spans
  I added but then removed fields for every range variant of a span.
  But given the possible verbosity of ranges in long streams, that seemed
  too excessive. And it is trivial and fool proof to convert between the two
  given that::

    offset = start
    width = end - start + 1
    end = start + width - 1

Streaming
  Besides dropping ranges some further compression may be added by considering
  preceeding lines.
  Ie. use relative delta's iso. absolute positions.

  But that syntax is for a more complex EDL spec.




