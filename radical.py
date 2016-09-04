#!/usr/bin/env python
"""
Radical
=======
Index and identify tagged comments in documents and source code.

Introduction
-------------
The motivation for this program is that working on a software project is an
ongoing effort to identify and locate existing problems, and room for
enhancements.

However, only one problem can be solved at a time. It will be required
to defer newly encountered (sub)problems to a later time.

This program allows to track comments TODO, FIXME, XXX or even ISSUE:MyId
kind of tags in source code. This local database could be kept in sync with
centralized issue and worklog trackers. [rad-ignore]

For example, a new issue may simply be created by a text embedded in a
*comment*, such as::

    MYPROJECT: Must support X here.

and then run `radical`. The 'MYPROJECT:' in the source would be rewritten to
e.g. 'MYPROJECT:109:', while the text is entered as a title into the
remote issue tracker for the new ticket MYPROJECT-109.

This tag may remain in the source code as long as needed, either until
the issue gets closed, or even remain indefinitely to mark exceptions.
The effect is that tagged comments are tracked for changes, and may have
a reference to some kind of ticket in a remote tracker with an variety
of attributes. To keep it simple, `radical` recognizes an ordering for
certain tags.

Storage
--------
Tagged comments are stored at keys generated from hashsums.
To retrieve these while the contents may have changed,
indices for the line and character range are also kept.

An additional auto-incremented numeric indexed is kept for selected
indices.

The following entities need to be kept:

- file
- comment
- tag


Configuration
-------------
To scan for comments in various syntax-flavours, different regexes are
kept that match start and end-lines or just comment-lines. The provisions are
relatively naive, and won't for example deal with stray '*' in C-style block
comments.

The other main part is the format for the tags. These are used to parse and
print tag instances. These are three parts:

- Regex to parse an existing tag,
- format to serialize a tag,
- the kind of index to use.



TODO: doc review:

It might be an option to remove all these artefacts from source again
before commit, though realisticly these would linger until the
issue gets closed, or remain as comments.

This afford to track existing issues and to create new ones
, or to simply
list all tagged comments for a certain code-base.

Overview
--------
- Comments run from the end of the tag to either the next '.\s' sequence or
  the end of the line, or a new tag.
- Comment whitespace is collapsed and trimmed.

- Comments starting with a tag are continued to the end of the comment line or
  block. Only indentation- and heading/trailing-whitespace is trimmed, meaning
  line markup and other 'preformatting' is retained.
- Tagged comments may be bound to a ticket in a remote tracker, or unbound;
  and tracked, or untracked. Bound tags are always tracked (have an unique
  ID), while unbound tags may be either tracked (explicitly) or untracked
  (implicitly).
- All tagged comments are recorded in a relational database supported by
  SQLAlchemy, and this script also provides an ORM for that data model.
- Service backends allow to keep an tagged comment in sync with a remote
  ticket.

Standard tags
-------------
TODO
    Incomplete implementation, stuff is missing. [rad-ignore]
FIXME
    Known bug or limitation, missing option or degraded user experience.
    [rad-ignore]
XXX
    Remark on hacks and other ugliness. (See Jargon File) [rad-ignore]
WIP
    (Work in progress) Partial implementation, stuff is missing or broken.
    [rad-ignore]

Configuration
-------------
- SQL DB reference (SQLite, MySQL, ...)
- Tag, Scan RegEx[, ID Format[, Service Backend]]
- Comment Flavour, (Start) Scan RegEx[, End RegEx]

Tags may be rewritten to the document with an ID.

Changelog
---------
2011-04-29
    Initial version. Planning for numeric and tiny ID. Need to recode hexdigest
    to full alphanumeric key.
2011-04-30
    Adding command-line options and separate storage service implementations,
    improved scanning, parsing of tagged comments.
2011-05-01
    Improved parser.
2011-05-04
    Improved parser.
2011-05-22
    Updating documentation.
2011-12-18
    Partial documentation, implementation review. Refactored to use libcmd.
2012-02-04
    Lost some recent development.
    Exploration of interface in libtaxus/linetags.py
2014-01-03
    During rewrite of libcmd keeping this up to date,
    perhaps looking to store files/comments/tags in SQL with taxus.
2016-08-27
    Need task scripts for `Pd`. Reviewing.

Issues
------
- Tagging multiline comments is desirable, nesting is not.
  If a comment block starts with a tag, but contains other tags, it is parsed as
  a line comment. (Normally a comment starting with a tag covers all the
  lines in the block)
- Implementation is still based on first development iteration,
  somewhat spotty and seems suboptimal.
- Python syntax allows various form of strings while this only parses block types.

Further comments
----------------
- Handles only Unix likebreaks. Could do a lot better con literal parsing,
  perhaps something enfiladic or based on parallel streams.. for now it should
  help this results in some content ranges.
- There are two styles of comments recognized, line and block.
  Some other styles not implemented:

  - SQL '-- ' prefixed line comments.
  - Vim '"' prefixed line comments.
  - INI ';' prefixed line comments.
  - SGML or XML style embedded comments.


TODO: domain structure::

                                                      INode
                                                        - type
   CommentTag                                           - local_path
    * tagname:String(16)                                - stat (size, etc)
      ^                                                 |
      \--------------------\                            |
                           |          Comment           |
   EmbeddedIssueOld        |           * inode:INode ---/
    * tag:CommentTag ------/           * line_span_start,end:Integer
    * tag_span_start,end:Integer       * comment:Text
    * description_span_start,end       * comment_span_start,end:Integer
    * inline:Boolean                     ^
    * comment:Comment -------------------/
      ^
      |
   TrackedIssue
    * description:Text

"""
# TODO:1: Integrate gate content stream
# TODO:2: Extend supported comment styles

# TODO:3: Scan for other literals, recognize language constructs.

import traceback
import optparse, os, re, sys
from pprint import pformat

import zope.interface
from sqlalchemy import Column, Integer, String, Boolean, Text, create_engine,\
                        ForeignKey, Table, Index, UniqueConstraint, Enum
from sqlalchemy.ext.declarative import declarative_base
from sqlalchemy.orm import relationship, backref, sessionmaker

#from cllct.osutil import parse_argv_split

import log
import confparse
import libcmd
import taxus
from taxus import Taxus
from taxus.init import get_session
import res
import res.fs


# Storage model

Base = declarative_base()


class IssueTracker(Base):
    """
    Keep table of tag/contexts together with (remote) backend ID.

    Identifies a remote tracker for instances of a tagname in a context .
    The remote trackers should contain all locally found embedded issues tagged
    with given ID.
    The opposite is not true - associated trackers can contain issues from
    different contexts (ie. different projects, branches).

    There is one tracker per tag instance, per context. Tracker URL's are
    not unique, but reusable remote references. TODO: see backend-ref for
    format.
    """
    __tablename__ = 'issue_trackers'
    id = Column(Integer, primary_key=True)
    tracker_url = Column(String(16))
    context = Column(String(255), primary_key=True)
    slug = Column(String(16), primary_key=True)
    __table_args__ = (
            UniqueConstraint('context', 'slug', name='_slug_context'),
        )


class TagInstance(object):
    def __init__(self, source, slug, char_span):
        self.source = source
        self.slug = slug
        self.start = char_span[0]
        self.end = char_span[1]

    @property
    def char_span(self):
        return self.start, self.end

    def raw(self, data):
        "Retrieve raw string from data"
        return data[slice(*self.char_span)]

    def canonical(self, data):
        "Clean-up raw tag"
        tag = self.raw(data)
        # Strip ends
        ctag = tag
        for p in '^'+tag_chars, tag_sepchars:
            ctag = re.sub('^[%s]+' % p, '', ctag)
            ctag = re.sub('[%s]+$' % p, '', ctag)
        # Replace other non-tag chars
        ctag, num = tag_clean_re.subn(':', ctag)
        return ctag

    def __str__(self):
        return "<TagInstance %s %s#c%s-%s>" % ( self.slug, self.source, self.start, self.end)

#indices_comments = Table('indices_comments', Base.metadata,
#        Column('tag', ForeignKey('tags.tagname'), index=True),
#        Column('comment', ForeignKey('document_embedded_comments.id'), index=True)
#    )

#class Comment(Base):
#    __tablename__ = 'document_embedded_comments'
#    id = Column(Integer(11), primary_key=True)
#    pattern = Column(String(255))
#    tags = relationship(Tag, secondary=indices_comments, backref='comments')

class TrackedIssue(Base):
    __tablename__ = 'tracked_issues'
    id = Column(Integer, primary_key=True)
    src_spec = Column(String(2048))

    tracker_id = Column(Integer, ForeignKey('issue_trackers.id'))
    tracker = relationship(IssueTracker,
            primaryjoin=tracker_id == IssueTracker.id)

    role = Column( Enum( 'primary', 'copy', 'reference' ))

# XXX: old
    #tag_id = Column(String(16), ForeignKey('tags.tagname'))
    #tag = relationship(CommentTag, primaryjoin=tag_id == CommentTag.tagname,
    #        backref='issues')
    description = Column(Text, index=True)
    inline = Column(Boolean, default=False)
    # XXX: unique on filename/linenumber?
    filename = Column(String(255), index=True)
    last_seen_startline = Column(Integer)

# tag ids:
NO_ID = 0
NEED_ID = -1



class SrcDoc:

    """
    Holder for tag/comments found in source.
    """

    def __init__(self, source_name, line_count=None ):

        self.source_name = source_name
        "Location for source."

        self.line_count = line_count

        self.scei = []


class CommentTag:
    """ TODO: hold some types of tags:
    TODO-10af
    TODO-1234
    BUG:1.2.3-a.b.c+d
    """
    def __init__(self, slug, id, matchbox):
        self.slug = slug
        self.id = id
        self.matchbox = matchbox


class EmbeddedIssue:

    """
    Holder for specific tagged comment found in source.
    """

    def __init__(self, srcdoc, comment_char_span, comment_line_span,
            description_span, comment_flavour, inline, tags):
        self.srcdoc = srcdoc
        self.description_span = description_span
        self.comment_char_span = comment_char_span
        self.comment_line_span = comment_line_span
        self.comment_flavour = comment_flavour
        self.inline = inline
        self.tags = tags

    def __str__(self):
        return "<EmbeddedIssue %s %i-%i %i-%i>" % ( ( self.comment_flavour,
                ) + self.comment_char_span + self.comment_line_span )

    def raw(self, data):
        return data[slice(*self.comment_char_span)]

    def descr(self, data):
        return data[slice(*self.description_span)]

    def scei_id(self, full=True):
        scei_id = self.srcdoc.source_name
        if full:
            scei_id += ":%s-%s;lines=%i-%i;flavour=%s;comment=%i-%i" % ( \
                    self.description_span + self.comment_line_span + (
                        self.comment_flavour, ) + self.comment_char_span )
        else:
            scei_id += ":%s-%s" % self.description_span
        return scei_id


    formats = {
            'todo.txt': lambda cmt, data: "",
            'id': lambda cmt, data: cmt.scei_id(False),
            'full-id': lambda cmt, data: cmt.scei_id(),
            'raw': lambda cmt, data: " ".join(
                map(str, [ cmt.srcdoc.source_name, cmt.comment_line_span, \
                            cmt.comment_flavour, \
                            repr(cmt.raw(data)), \
                            repr(cmt.descr(data)) ])),
            'raw2': lambda cmt, data: "%s '%s' <%s> %s" %( tag, tag.raw(data),
                    tag.canonical(data), cmt )

        }


class EmbeddedIssueOld:

    def __init__(self, file_name, comment_span, tag_name, tag_id, tag_span,
            description_span, inline, comment_flavour, comment_lines):

        self.file_name = file_name
        "Local file location for source."

        self.tag_name = tag_name
        self.tag_id = tag_id
        self.tag_span = tag_span
        "The tag and its location in the source code. "
        self.description_span = description_span
        "The complete description extracted from source and reformatted. "
        self.comment_span = comment_span
        self.comment_lines = comment_lines
        "Identifies the comment for this session, maybe shared by several issues. "
        self.inline = inline
        "Wether description is short message, or extended description. "
        self.comment_flavour = comment_flavour

    def format(self):
        if len(rc.tags[self.tag_name]) > 1:
            p = rc.tags[self.tag_name][1]
        else:
            p = "%s:"
            if self.tag_id != None:
                p += '%i:'
        if self.tag_id != None:
            return p % (self.tag_name, self.tag_id)
        else:
            return p % self.tag_name

    formats = dict(
        short = lambda embedded:
            embedded.format() +' '+ embedded.description.strip(),
        complete = lambda embedded:
            ' '.join([
                "%s:%s:%s" % ( ( embedded.file_name, ) + embedded.comment_lines ),
                "%i:%i" % embedded.comment_span,
                embedded.format(),
                embedded.description.strip()
            ])
    )

    def set_new_id(self, id):
        global rc
        data = open(self.file_name).read()
        data = data[:self.tag_span[0]] + self.format() + data[self.description_span[0]:]
        #print self.file_name, data
        #open(self.file_name, 'w+').write(data)

    def store(self, session):
        if self.tag_id:
            pass

    def __str__(self):
        # FIXME: cache source file reads
        data = open(self.file_name).read()
        return "<%s> %s %s %s\n\t%s\n\t" % (
                self.file_name, self.tag_name, self.inline,
                data[slice(*self.tag_span)],
                self.description
            )

    @property
    def description(self):
        global rc
        data = open(self.file_name).read()
        span = tuple(self.description_span)
        #span = self.description_span[0], self.description_span[1]+1
        description = clean_comment(
                rc.comment_scan[self.comment_flavour],
                data[slice(*span)].lstrip())
        if self.inline:
            description = collapse_ws(description)
            if not description.endswith(' '):
                description += ' '
        return description


# Storage & service IO

def store_comments(session, data, comment_span, flavour_spec, tagname, matchbox):
    """
    """
    comment_data = data[slice(*comment_span)]

    pass


# Content data scanning

end_of_description = re.compile('([\.?!](?:\ |$))', re.M + re.S).search

def end_of_line(data):
    pos = 0
    for c in data:
        if c == '\n':
            return pos
        pos += 1

def get_lines(data):
    lines = data.split('\n')
    if lines[-1] == '':
        lines.pop()
    return lines

def at_line(offset, width, data, lines=None):
    """Return the line number, and its char-span. Given a sub-line char span
    (of single word span, ie. never crossing a line-end).

    Assumes single-char line-end.
    And that it is always present, and included in line-width.

    """
    if not lines:
        lines = get_lines(data)
    chars = 0
    for line, line_data in enumerate(lines):
        if offset < chars+len(line_data)+1:
            return line, chars, len(line_data)+1
        chars += len(line_data)+1
    assert not (offset+width > chars),  \
"Span is beyond document bounds: %r while document bytes:%r %r, lines:%s " % \
((offset, width), chars, len(data), len(lines))


collapse_ws_sub = re.compile(r'[\ \n]+').sub
collapse_ws = lambda s: collapse_ws_sub(' ', s)


def compile_rdc_matchbox(rc):
    """Pre-compile patterns"""
    matchbox = {}

    for tagname in rc.tags:
        pattern = r"(%s)" % tagname
        if rc.tags[tagname]:
            pattern = rc.tags[tagname][0] % tagname
        matchbox[tagname] = re.compile(pattern)

    for flavour in rc.comment_scan:
        scan = rc.comment_scan[flavour]
        search_line = re.compile(scan[0], re.M)
        if len(scan) > 1:
            search_end = re.compile(scan[1], re.M)
            matchbox[flavour] = (None, search_line.search, search_end.search)
        else:
            matchbox[flavour] = (search_line.search, None, None)

    return matchbox


_parsed_file_comments = {}

def get_tagged_comment(offset, width, data, lines, language_keys, matchbox):
    """
    Return the comment span that has a tag embedded at offset/width.

    This scans for continues sequences of comment lines, and may return spans
    for comment blocks that contain other tags.
    Given a found tag it looks at the like of the match using a
    comment start/end exrepssion.

        Also, this span may include
    metacharacters used to markup comments. Further parsing of the comment
    block is left to the caller.
    """
    tag_line, line_offset, line_width = at_line(offset, width, data, lines)

    #print 'get_tagged_comment', offset, width, 'tag', tag_line, line_offset, line_width, language_keys

    comment_offset, comment_end = -1, -1
    description_offset, description_end = -1, -1
    start_line, last_line = -1, -1
    for language_key in language_keys:

        scan_spec = matchbox[language_key]
        search_line, search_start, search_end = scan_spec

        data = lines[tag_line]
        start_line = tag_line

        if search_line:
            # scan for line-style comment, concatenate multiple lines
            line_start = search_line(data)

            if line_start:
                #print 'search_line', language_key, data, start_line, line_start.span()
                comment_offset = line_offset + line_start.start()
                description_offset = offset
                last_line = tag_line
                comment_end = line_offset + line_width
                description_end = comment_end
                if last_line == 0:
                    break
                data = lines[last_line+1]
                while search_line(data):
                    last_line += 1
                    comment_end = len(data) + 1
                    data = lines[last_line+1]

                #print "Line-match ", language_key, tag_line, lines[tag_line]
                break

            else:
                #print "No line-match at", language_key, tag_line, lines[tag_line]
                continue

        else: # seek multiline block comment

            comment_offset = line_offset
            while data:
                #print 'comment_offset', comment_offset, 'len-data', len(data)
                start = search_start(data)
                if start:
                    description_offset = comment_offset + start.end()
                    comment_offset += start.start()
                    comment_end = comment_offset
                    data = data[start.start():]
                    break
                if start_line == 0:
                    break
                start_line -= 1
                data = lines[start_line]
                comment_offset -= len(data) + 1

            if comment_end == -1:
                continue
            #print 'Start match', comment_end, comment_offset, start_line, data

            if not search_end:
                search_end = search_start

            last_line = start_line
            while data:
                end = search_end(data)
                if end:
                    description_end = comment_end + end.start()
                    comment_end += end.end()
                    break
                comment_end += len(data) + 1
                last_line += 1
                data = lines[last_line]

            #print 'End match', comment_end, last_line, data

            break

    if comment_end > -1 and description_end > -1:
        #print language_key, 'found comment', start_line, comment_offset, \
        #            last_line, comment_end,\
        #            lines[start_line:last_line+1]
        return language_key, (comment_offset, comment_end), \
                (description_offset, description_end), \
                (start_line, last_line)



def scan_for_tag(tags, matchbox, data):
    pos = len(data)
    for t in tags:
        m = matchbox[t].search(data)
        if m and m.start() < pos:
            pos = m.start()
    if pos == len(data):
        return None
    else:
        return pos

def trim_comment(match, data, (start, end)):
    comment_data = data[start:end]

    match_start = match[0] or match[1]
    # strip heading and trailing comment markup metachars
    m = match_start(comment_data)
    if not m:
        #  FIXME: c-style comments have embedded junk
        if comment_data != comment_data.strip():
            pass # TODO: block trim_comment
        return data[start:end], (start, end)
        raise Exception(m, comment_data)

    _1 = comment_data[m.end(1):]
    start += m.end(1)

    # and trailing markup if non-line comments
    if match[1]:
        m = match[2](_1)
        if m:
            _2 = _1[:m.start(1)]
            end = start + m.start(1)
        else:
            _2 = _1
    else:
        _2 = _1

    assert _2 == data[start:end]

    # strip heading and collapse trailing whitespace

    m = re.match('^.*(\s*)$', _2, re.M + re.S)
    if m:
        end = start + m.start(1)
        if data[end] == ' ':
            end += 1

    start += re.search('[^\s]', _2).start()

    return data[start:end], (start, end)

def clean_comment(scan, data):

    d = 0
    if len(scan) == 1:
        for m in re.finditer(scan[0], data, re.M):
            #print (m.start(), m.end()), (m.start(1), m.end(1)), repr(data[m.start(1)-d:m.end(1)-d])
            data = data[:m.start(1)-d] + data[m.end(1)-d:]
            d += m.end(1) - m.start(1)

    else:
        #raise NotImplemented
        data = re.sub(scan[0], ' ', data, re.M)
        if len(scan)>1:
            data = re.sub(scan[1], '', data)

    return data


class Parser:
    """
    TODO: parse/cache comments from source. Map between tag and comment specs.
    Keep context.
    """
    def __init__(self, session, matchbox, source_name, context, data, lines):
        self.session = session
        self.matchbox = matchbox
        self.source_name = source_name
        self.context = context
        self.data = data
        self.lines = lines

    def find_tags(self):
        "scan for tags. return entire tag spec"
        for tagname in rc.tags:
            for tag_match in self.matchbox[tagname].finditer(self.data):
                tag_span = tag_match.start(), tag_match.end()
                yield TagInstance(self.source_name, tagname, tag_span)

    def for_tag(self, srcdoc, tag):
        "retrieve comment for TagInstance TODO: map streams"

        # Get entire comment
        comment = get_tagged_comment(tag.start, tag.end-tag.start,
                self.data, self.lines,
                rc.comment_flavours, self.matchbox)
        if not comment:
            return
        comment_flavour, comment_span, descr_span, lines = comment

        # Clean comment from markup and adjust source span
        comment_data, comment_span = \
                trim_comment(self.matchbox[comment_flavour], self.data,
                                                            comment_span)
        (comment_start, comment_end) = comment_span

        # XXX:
        inline = None
        tags = []
        return EmbeddedIssue(srcdoc, comment_span, lines, descr_span,
                comment_flavour, inline, tags)




# XXX: old
def find_tagged_comments(session, matchbox, source, data, lines=None):
    """
    Scan a single source for embedded-issues/tagged-comments.

    Use tag regexes from matchbox to scan data from source,
    Use tag reLook for tags in data, using the compiled tag regexes
    in matchbox, and
    post processing each found flavour of comment block to the
    distinct tagged comments.

    The tagged comment body text runs from the end of the tag, to the next '.'
    followed by whitespace, or the end of the line.
    *Comment blocks* **starting with a tag** include the body text up to the end of
    the comment block. This makes a distinction between tagged comment lines and
    blocks.

    TODO: Needs rewrite, to index comments first, then scan for tags in result
    structure.
    This works inefficent, looking for tags and then finding the comment for it.
    Also, this scans for every language.

    FIXME: C-style line and block comments.
    """

    if not lines:
        lines = get_lines(data)

    # pass data along each tag-name and regexes from matchbox
    for tagname in rc.tags:
        for tag_match in matchbox[tagname].finditer(data):
            #print
            #print 'Tag match', tag_match.start(), tag_match.end(), \
            #        tag_match.group().strip(), tag_match.span()

            tag_span = tag_match.start(), tag_match.end()

            # Get entire comment
            comment = get_tagged_comment(tag_span[0],
                    tag_span[1]-tag_span[0], data, lines,
                    rc.comment_flavours, matchbox)
            if not comment:
                #log.err("Unable to find comment span for tag '%s' at %s:%s " % (
                #    data[tag_span[0]:tag_span[1]], source, tag_span, lines))
                continue
            comment_flavour, comment_span, description_span, lines = comment

            # Clean comment from markup and adjust source span
            comment_data, comment_span = \
                    trim_comment(matchbox[comment_flavour], data,
                                                                comment_span)
            (comment_start, comment_end) = comment_span

            # Determine end of tag value: the Issue description boundary
            inline = False

            next_tag = scan_for_tag(rc.tags, matchbox,
                    data[tag_match.end():comment_end])
            if next_tag:
                next_tag = next_tag + tag_match.end()

            if not next_tag and comment_start == tag_match.start():
                # Comment starts with Tag, Tag spans entire comment block
                description_end = comment_end
            else:
                inline = True
                # Scan for end of Issue description
                find_description_end = end_of_description(data[tag_match.end():comment_end])
                if find_description_end:
                    description_end = tag_match.end() + find_description_end.end()
                else: # Line comment
                    end_offset = end_of_line(data[tag_match.end():comment_end])#.end()
                    if end_offset:
                        # TODO: stop at end of line
                        description_end = tag_match.end() + end_offset
                    else:
                        description_end = comment_end

            # Always stop at next tag
            if next_tag and next_tag < description_end:
                description_end = next_tag

            current_id = None
            if rc.tags[tagname]:
                if tag_match.group(2):
                    assert tagname in rc.tags, "Need index type for tracked tag at %s" % (tag_span,)
                    current_id = tag_match.group(2)
                else:
                    current_id = NEED_ID

            yield EmbeddedIssueOld(source, (comment_start, comment_end), tagname,
                    current_id,
                    (tag_match.start(), tag_match.end()),
                    (tag_match.end(), description_end),
                    inline, comment_flavour, lines)
            continue

            # FIXME:
            #  Get and further clean the issue text from the source data
            tag_data = clean_comment(rc.comment_scan[comment_flavour],
                    data[tag_match.end():description_end].lstrip())
            if inline:
                tag_data = collapse_ws(tag_data)
                if not tag_data.endswith(' '):
                    tag_data += ' '

            # Use tracker service, or anonymous tags
            if rc.tags[tagname]:
                current_id = None
                if tag_match.group(2):
                    assert tagname in rc.tags, "Need index type for tracked tag at %s" % (tag_span,)
                    current_id = tag_match.group(2)

                if current_id:
                    #print 'Existing:', tagname, current_id, source, tag_span, repr(data[slice(*tag_span)])
                    yield source, tagname, current_id, tag_data
                else:
                    #print 'New:', tagname, source, tag_span, repr(data[slice(*tag_span)])
                    yield source, tagname, -1, tag_data # Identify new tracked tagged comment
            else:
                #print 'Anonymous:', tagname, source, tag_span, repr(data[slice(*tag_span)])
                yield source, tagname, None, tag_data # Anonymous tag




def plain_text_flavor(peek, source):
    try:
        peek.decode('ascii')
        return True
    except UnicodeDecodeError, e:
        print e

def get_peek(source):
    try:
        filesize = os.path.getsize(source)
        bytes = 1024
        if filesize < 1024:
            bytes = filesize
        return open(source).read(bytes)
    except Exception, e:
        log.debug("get-peek: %s", e)

def find_files_with_tag(session, matchbox, paths):

    """
    Look for tags in the data at each file path.

    This is the main routine for scanning multiple sources
    for embedded issues.
    It scans all the paths and resolves any directory to source files.
    Then each source is read, and another routine called to scan for and
    process tagged comments.
    """

    # Walk files, XXX: ignore non-ascii, retrieve tag references
    for source in sources:

        try:
            tag_generator = find_tagged_comments(session, matchbox, source, data)
        except Exception, e:
            log.err("Find: %s", e)
            traceback.print_exc()
            tag_generator = None

        while tag_generator:
            try:
                tag = tag_generator.next()
                yield tag
            except StopIteration, e:
                tag_generator = None
            except Exception, e:
                log.err("Find: %s", e)
                traceback.print_exc()


def get_service(t):
    return __import__('radical_'+t)

# Optparse callbacks
def append_comment_scan(option, value, parser):
    print "TODO comment_scan", (option, value, parser)
    pass


# Static metadata

"""
scan
    a dict with start,[end] expressions for each comment flavour
tags
    a format and item index service name
"""
# TODO: groups of filetype tags for each flavour scanned comment

# XXX: probably use gate to map between content-type and format tag
#flavour_format_map = {
#        'unix_generic': (),
#        'c':   ('c', 'js', 'hx', 'php', ),
#        'c_line':   ('c', 'js', 'hx', 'php', ),
#        'vim': ('vim', 'vimrc'),
#        'rst': ('rst', 'text',),
#        'sql': ('sql', 'mysql',),
#        'ini':  ('ini',),
#        'py':  ('py',),
# XXX: collapse htm and html
#        'xml': ('xml', 'xslt', 'xsd', 'relax', 'xhtml', 'html'),
#        'sgml': ('sgml','html'),
#    }

# Start/end regex patterns per comment flavour
STD_COMMENT_SCAN = {
        'c': [ '(\/\*+)', '(\*\/)' ],
        'unix_generic': [ '(\#\s)' ],
        'c_line': [ '(\/\/)' ]
    }
# Tag pattern, format and index type
DEFAULT_TAGS = {
    'FIXME': [ '(\\b%s)[:_\s-]*(?:([0-9]+))?\\b' ],
    'TEST': ['(\\b%s)[:_\s-]*(?:([0-9]+))?\\b', '%s:%i:', 'numeric_index' ],
    'TODO': ['(\\b%s)[:_\s-]*(?:([0-9]+))?\\b', '%s:%i:', 'numeric_index' ],
    'XXX': [ '(\\b%s)[:_\s-]*(?:([0-9]+))?\\b' ],
    'NOTE': [ '(\\b%s)[:_\s-]*(?:([0-9]+))?\\b' ],
    'BUG': [ '(\\b%s)[:_\s-]*(?:([0-9]+))?\\b' ]
}

rc = confparse.Values()

tag_chars = 'A-Za-z0-9\/:\._-'
tag_sepchars = ':\.'
tag_clean_re = re.compile('[^%s]' % tag_chars)
tag_match_re = re.compile('[%s]{2,}' % tag_chars)


# Main

# TODO see bookmarks, basename-reg, mimereg, flesh out Txs
import rsr


class Radical(rsr.Rsr):

    zope.interface.implements(res.iface.ISimpleCommand)

    NAME = 'rdc'#radical'
    PROG_NAME = os.path.splitext(os.path.basename(__file__))[0]
    OPT_PREFIX = 'rdc'

    VERSION = "0.1"
    USAGE = """Usage: %prog [options] paths """

    DEFAULT_DB = "sqlite:///%s" % os.path.join(
                                        os.path.expanduser('~'), '.radical.sqlite')
    DEFAULT_CONFIG_KEY = PROG_NAME
    INIT_RC = 'init_config_defaults'

    #NONTRANSIENT_OPTS = Taxus.NONTRANSIENT_OPTS + [
    #    'list_flavours', 'list_scans' ]
    #TRANSIENT_OPTS = Taxus.TRANSIENT_OPTS + [ 'run_embedded_issue_scan' ]
    DEFAULT = [ 'rdc_run_embedded_issue_scan' ]

    DEPENDS = dict(
            rdc_init = [ 'rsr_session' ],
            rdc_run_embedded_issue_scan = [
                'rdc_init', 'rsr_session', 'prepare_output' ],
            rdc_list_flavours = [ 'rdc_init', 'load_config', 'prepare_output' ],
            rdc_list_scans = [ 'load_config', 'prepare_output' ],
            rdc_info = [ 'rdc_init' ]
        )

    @classmethod
    def get_optspec(Klass, inheritor):
        """
        Return tuples with optparse command-line argument specification.
        """
        p = inheritor.get_prefixer(Klass)
        return (
#                (('-d', '--database'),{ 'metavar':'URI', 'dest':'dbref',
#                    'help': "A URI formatted relational DB access description, as "
#                        "supported by sqlalchemy. Ex:"
#                        " `sqlite:///radical.sqlite`,"
#                        " `mysql://radical-user@localhost/radical`. "
#                        "The default value (%default) may be overwritten by configuration "
#                        "and/or command line option. ",
#                    'default': klass.DEFAULT_DB }),

                # -f PATTERN   Include only matching files.

                p(('-F', '--add-flavour'),{ 'action': 'callback', 'callback': append_comment_scan,
                    'help': "Scan for these comment flavours only, by default all known fla." }),

                p(('--list-flavours',), libcmd.cmddict(inheritor.NAME)),
                p(('--list-scans',), libcmd.cmddict(inheritor.NAME)),
                p(('--info',), libcmd.cmddict(inheritor.NAME)),

                p(('--issue-format',), {
                    'dest': 'issue_format',
                    'action': 'store',
                    'default': 'id',
                    'help': "" }),

                #(('--no-recurse',),{'action':'store_false', 'dest': 'recurse'}),
                #(('-r', '--recurse'),{'action':'store_true', 'default': True,
                #    'help': 'Recurse into directory paths (default: %default)'}),
            )

    def init_config_defaults(self, opts):
        self.rc = confparse.Values(dict(
            tags = DEFAULT_TAGS,
            comment_scan = STD_COMMENT_SCAN,
            comment_flavours = STD_COMMENT_SCAN.keys(),
            dbref = self.DEFAULT_DB
        ))
        self.settings[opts.config_key] = self.rc
        return self.rc

    def rdc_list_flavours(self, args=None, opts=None):
        for flavour in self.rc.comment_scan:
            print "%s:\n\tstart:\t%s" % ((flavour,)+
                    tuple(self.rc.comment_scan[flavour][:1]))
            if len(self.rc.comment_scan[flavour]) > 1:
                print "\tend:\t%s" % self.rc.comment_scan[flavour][1]
            print
        return

    def rdc_list_scans(self, args, opts):
        for tag in self.rc.tags:
            print "%s:" % (tag)
            if self.rc.tags[tag]:
                if len(self.rc.tags[tag]) > 0:
                    print "\tmatch:\t%s" % (self.rc.tags[tag][0] % tag)
                if len(self.rc.tags[tag]) > 1:
                    print "\tformat:\t%s" % self.rc.tags[tag][1]
                if len(self.rc.tags[tag]) > 2:
                    print "\tindex:\t%s" % self.rc.tags[tag][2]
            else:
                print "\tmatch:\t(%s)" % tag
            print
        return

    def rdc_init(self, prog=None):
        global rc
        rc = self.rc
        # start db session
        #dbsession = get_session(self.rc.dbref)
        #yield dict( dbsession=dbsession )

        # get backend service
        services = confparse.Values({})
        for tagname in self.rc.tags:
            if self.rc.tags[tagname] and len(self.rc.tags[tagname]) > 2:
                services[tagname] = get_service(self.rc.tags[tagname][2])
                log.info("Using backend %s for %s", services[tagname], tagname)

        yield dict( services=services )

    def walk_paths(self, paths):
        # Recurse dirs, return all file paths
        sources = []
        for p in paths:
            if not os.path.isdir(p):
                sources.append(p)
            else:
                for p2 in res.fs.Dir.walk(p, opts=dict(recurse=True, files=True)):
                    sources.append(p2)

        for source in sources:
            peek = get_peek(source)
            if not peek:
                log.err("Error reading %s" % source)
                continue

            if not plain_text_flavor(peek, source):
                log.warn("Ignored non-ascii %s" % source)
                continue

            yield source

    def rdc_run_embedded_issue_scan(self, sa, issue_format=None, opts=None, *paths):

        """
        Main function: scan multiple sources and print/log embedded issues
        found.
        """

        if not paths: paths=['.']

        # TODO: make ascii peek optional, charset configurable
        # TODO: implement contexts, ref per source
        context = ''
        source_iter = self.walk_paths(paths)

        # pre-compile patterns XXX: per context
        matchbox = compile_rdc_matchbox(rc)

        taskdocs = {}

        for source in source_iter:
            data = open(source).read()

            lines = get_lines(data)

            srcdoc = SrcDoc( source, len(lines) )
            taskdocs[source] = srcdoc

            parser = Parser(sa, matchbox, source, context, data, lines)

            for tag in parser.find_tags():

                try:
                    cmt = parser.for_tag(srcdoc, tag)
                except (Exception) as e:
                    if not opts.quiet:
                        log.err("Unable to find comment span for tag '%s' at %s:%s " % (
                            parser.data[tag.start:tag.end], srcdoc.source_name, tag.char_span))
                    continue

                if not cmt:
                    continue

                # XXX
                srcdoc.scei.append(cmt)

                if opts.quiet:
                    issue_format = 'id'

                print EmbeddedIssue.formats[issue_format](cmt, data)
        return

        # TODO: old clean/rewrite functions

        # iterate paths
        for embedded in find_files_with_tag(sa, matchbox, paths):

            if embedded.tag_id:
                #if embedded.tag_id == NEED_ID:
                    yield dict(issues=[ embedded ])
                    try:
                        if issue_format:
                            print EmbeddedIssueOld.formats[issue_format](embedded)
                        log.note('Embedded Issue %r', (embedded.file_name, \
                                embedded.tag_name, embedded.tag_id, \
                                embedded.comment_span, embedded.comment_lines, \
                                embedded.description, embedded.comment_flavour))
                    except Exception, e:
                        log.err(e)
                    #new_id = service.new_issue(embedded.tag_name, embedded.description)
                    #embedded.set_new_id(new_id)
                    #service.update_issue(embedded.tag_name, embedded.tag_id,
                    #        embedded.description)
            else:
                assert False
                pass
            #embedded.store(dbsession)

    def rdc_info(self, prog, sa):
        print 'Radical info', prog, sa
        r = self.execute('rdc_run_embedded_issue_scan')
        print r


if __name__ == '__main__':
    Radical.main()

