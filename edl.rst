Edit Decision Lists
===================
:Created: 2016-12-16
:Updated: 2020-06-29
:Log:
  - 2020-06-29 Added defs
  - 2018-11-11 #55600ccd Added intro paragraphs.
  - 2018-08-14 #e9e33e4e Moved links, punctuation.
  - 2016-12-30 #aacc69fe Blank line added
  - 2016-12-27 #1e407c09 Added figures and scrow links on localhost.
  - 2016-12-16 #ecf9ce43 Initial version

.. figure:: compo:viz/edl.svg
  :target: compo:viz/edl.plantuml

transquoter EDL are lists of clinks (content-links), referencing pieces of
text (ie. char ranges at URL's or files).

other link styles could "markup" ranges: add styling, semantics, jump
hyperlinks, or other relations.

Ie. EDL could be used to list other sort of links beside refs to remote
ranges.
Two elements (no typing, possibly simple cite or transclusion, jump),
three elements (one "relation" spec)
or four elements (ie. one home-document for link or additional context ID)

Links in Xu88/Green are four-element, made up of three tumbler
address ranges and one home-document tumbler address.


Range link formats
------------------
Lets define

- *ranges* as start and end position;
- *Spans* are offset (same as start) and length (ie. end - start + 1 ).
- All serialized references should have 1-indexed offsets.
- All positions refer to decoded character positions.

* To keep character count down, use spans instead of range serializations. Also allow '1'-length spans of just the offset number.

* Need to deal with several string indexes at once: characters, lines+characters and
  perhaps even other segmentations. While character indexing is is the most absolute,
  lots of time the line range is more convenient to deal with instead.
  Conventional shell tools like sed, grep and cut are all line based.
  Also, absolute character offset tracking is often lost somewhere in the
  software stack and unavailable to script.
  Then yet another problem can be presented tracking byte position with (decoded) character positions.

  The algorithm proposed by `transquoter` disregards all whitespace.
  Presenting yet another text-indexing method. Words or tokens may be
  another.

- For a simple app with decoded data the following would do::

    <1-prefix>
    <2-file>
    <3-line-span>
    <4-col-span>
    <5-char-span>
    <6-literal>

* Living with ASCII source code, we can allow to forgo the bytestream to
  character stream mapping. But with unicode we get into grey waters.

  Not all shell tools may behave. And some interfaces may require byte
  positions while we deal with character positions.



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


See also
---------
- Scrow http://localhost:4501 (demo)
- Scrow http://localhost:8067 (dev)
