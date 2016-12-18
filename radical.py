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


TODO: see line-based tasks format (for shell) in tasks.rst

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


# Static global metadata

"""
scan
    a dict with start,[end] expressions for each comment flavour
tags
    a format and item index service name
"""
# TODO: groups of filetype tags for each flavour scanned comment
# FIXME: probably use gate to map between content-type and format tag
#flavour_format_map = {
#        'unix_generic': (),
#        'c':   ('c', 'js', 'hx', 'php', ),
#        'c_line':   ('c', 'js', 'hx', 'php', ),
#        'vim': ('vim', 'vimrc'),
#        'rst': ('rst', 'text',),
#        'sql': ('sql', 'mysql',),
#        'ini':  ('ini',),
#        'py':  ('py',),
#        'xml': ('xml', 'xslt', 'xsd', 'relax', 'xhtml', 'html', 'htm'),
#        'sgml': ('sgml','html','htm'),
#    }

# Start/end regex patterns per comment flavour
STD_COMMENT_SCAN = {
        'c': [ '(\/\*+)', '(\*\/)' ],
        'unix_generic': [ '(\#\s)' ], #(?![^\s]+)
        'c_line': [ '(\/\/)' ],

        # Match comment start line but not directives,
        # NOTE: directive format in negative lookahead
        'restructuredtext': [ '(\.\.)(?!\s+[a-zA-Z0-9-]*:)\s' ]
# TODO: differentiate comment scans. restructuredtext has indented
#   continuations (without trailing \). I think c_line should support
#   this. Just like shell programs should and readline does. Its probably
#   evil to use in source like C or something. But for a generic comment
#   parser its essential to understand I think.
# FIXME: Alternatively as a "solution" radical currently supports continued
#   task descriptions using a single/double? or more indent.
    }
# Tag pattern, format and index type
DEFAULT_TAG_RE = r'\s*\b(%s)(?:[:_\ -]([A-Za-z0-9:_-]+))?\b[:]?\s+'
DEFAULT_TAGS = {
    'FIXME': [ DEFAULT_TAG_RE ],
    'TEST':  [ DEFAULT_TAG_RE, '%s:%i:', 'numeric_index' ],
    'TODO':  [ DEFAULT_TAG_RE, '%s:%i:', 'numeric_index' ],
    'XXX':   [ DEFAULT_TAG_RE ], # tasks:no-check
    'NOTE':  [ DEFAULT_TAG_RE ],
    'BUG':   [ DEFAULT_TAG_RE ]
}
#    'BUG': [ '(\\b\s*%s)(?:[:_\s-]([0-9]+))?[:_\s-]*\\b' ]

rc = confparse.Values()

tag_chars = 'A-Za-z0-9\/:\._-'
tag_sepchars = ':\.'
tag_clean_re = re.compile('[^%s]' % tag_chars)
tag_match_re = re.compile('[%s]{2,}' % tag_chars)


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
    filename = Column(String(255), index=True)
    last_seen_startline = Column(Integer)

# tag ids:
NO_ID = 0
NEED_ID = -1



class SrcDoc:

    """
    Holder for tag/comments found in source.
    """

    def __init__(self, source_name, data=None ):

        assert isinstance(source_name, str), "source_name: %r" % source_name
        self.source_name = source_name
        "Location for source."

        if data:
            assert isinstance(data, str), "data: %r" % data
            self.data = data
        else:
            self.data = open(source_name).read()

        self.newline = '\n'
        self.lines = get_lines(self.data, self.newline)

        self.scei = []

    def line_dsp(self, number):
        line = 0
        dsp = 0
        while line < number:
            dsp += len(self.lines[line]+self.newline)
            line += 1
        return dsp

    def line_wid(self, number):
        "return char position to end of line"
        return len(self.lines[number])

    def line_char_span(self, from_line=0, to_line=None):
        if to_line == None:
            to_line = from_line
        return self.line_dsp(from_line), self.line_wid(to_line)

    def line_char_range(self, from_line=0, to_line=None):
        """translate line range to character range
        Excluding last but including all intermediate newlines characters
        """
        if to_line == None:
            to_line = from_line
        start = self.line_dsp(from_line)
        end = self.line_dsp(to_line) + self.line_wid(to_line)
        return start, end


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
            description_span, comment_flavour, inline=False, tags=[]):
        self.srcdoc = srcdoc
        self.description_span = description_span
        self.comment_char_span = comment_char_span
        self.comment_line_span = comment_line_span
        self.comment_flavour = comment_flavour
        self.inline = inline
        self.tags = tags

    def __str__(self):
        # NOTE: 0-index ranges/spans in ID
        return "<EmbeddedIssue %s %i-%i %i-%i>" % ( ( self.comment_flavour,
                ) + self.comment_char_span + self.comment_line_span )

    @property
    def line_span(self):
        return tuple([ i + 1 for i in self.comment_line_span ])

    @property
    def char_span(self):
        return tuple([ i + 1 for i in self.comment_char_span ])

    @property
    def raw(self):
        return self.srcdoc.data[slice(*self.comment_char_span)]

    @property
    def descr(self):
        return self.srcdoc.data[slice(*self.description_span)]

    def scei_id(self, full=True):
        # NOTE: turn ranges from 0-index into 1-indexed (lines, chars, etc)
        dspan = tuple([ x+1 for x in self.description_span ])
        scei_id = self.srcdoc.source_name
        if full:
            cspan = tuple([ x+1 for x in self.comment_char_span ])
            scei_id += ":lines=%i-%i;flavour=%s;comment=%i-%i" % ( \
                    self.line_span + ( self.comment_flavour, ) + self.char_span )
        else:
            #scei_id += ":%s-%s" % dspan
            scei_id += ":%s-%s" % self.char_span
        return scei_id


    formats = {
            #'todo.txt': lambda ei, data: "",
            'id': lambda ei, data: ei.scei_id(False),
            'full-id': lambda ei, data: ei.scei_id(),
            'full-sh': lambda ei, data: ":".join(
                map(str, [
                    '',
                    ei.srcdoc.source_name,
                    # NOTE: 0 to 1-indexed, and add spans for Sh
                    "%i-%i" % tuple([ x+1 for x in ei.line_span ]),
                    "", # FIXME: "%i-%i" % tuple([ x+1 for x in ei.description_span ]),
                    '', # line-offset-descr-span
                    '', # cmnt-span
                    '', # line-offset-cmnt-span
                    '',# FIXME: ei.descr
                ])),
            'raw': lambda ei, data: " ".join(
                map(str, [ ei.srcdoc.source_name,
                    ei.line_span, \
                    ei.comment_flavour, \
                    repr(ei.raw), \
                    '', # FIXME: repr(ei.descr)
                    ])),
            'raw2': lambda ei, data:
                ei.tags and \
                    "/".join([ "%s '%s' <%s> %s" %(
                        tag, tag.raw, tag.canonical(data), ei
                    ) for tag in ei.tags ])
                or "No tags %r" % ei
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

def get_lines(data, newline='\n'):
    lines = data.split(newline)
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
    assert isinstance(lines, ( list, tuple )), lines
    chars = 0
    for line, line_data in enumerate(lines):
        assert isinstance(line, int), "line: %r" % line
        assert isinstance(line_data, str), "line_data: %r " % line_data
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

# [2016-12-17] rewriting get_tagged_comment

def get_tagged_comment(parser, tag_or_offset, tag_width, rc):
    """
    Return the comment line and character ranges for a tagged comment.

    that has a tag embedded at offset/width.

    This scans for continues sequences of comment lines, and may return spans
    for comment blocks that contain other tags.
    Given a found tag it looks at the like of the match using a
    comment start/end exrepssion.

        Also, this span may include
    metacharacters used to markup comments. Further parsing of the comment
    block is left to the caller.
    """
    if not tag_width:
        assert isinstance(tag_or_offset, TagInstance)
        tag = tag_or_offset
        tag_offset = tag.start
        tag_width = tag.end-tag.start+1
    else:
        tag_offset = tag_or_offset

    srcdoc = parser.srcdoc
    tag_line, line_offset, line_width = at_line(tag_offset, tag_width,
            srcdoc.data, srcdoc.lines)

    #print 'get_tagged_comment', offset, width, 'tag', tag_line, line_offset, line_width, language_keys

    language_key = None
    comment_start, comment_end = -1, -1
    start_line, end_line = -1, -1
    for language_key in rc.comment_flavours:

        # Comment re.search methods; either two for a block-start/end or
        # just one for a line-based comment parser.
        scan_spec = parser.matchbox[language_key]
        search_line, search_start, search_end = scan_spec

        linedata = srcdoc.lines[tag_line]
        # scan for lines,
        if search_line:

            # Match first line, ignore non-commented tag-line
            line_start = search_line(linedata)
            if line_start:
                start_line = end_line = tag_line
                comment_start = line_offset
                comment_end = line_offset + len(linedata)
                #print 'search_line', language_key, linedata, start_line
                # TODO: assert indentation remains constant.. or warn about
                #   messy stuff

                # Track indent
                # NOTE: the first match group of search_line.start should be at
                # a clean comment match. Leading line data is ignored, iow.
                # this parses block comments regardless of the text before the
                # line comment.
                comment_line_offset = line_start.start(1)

                # Search to first line
                while start_line < 0:
                    line_start_ = search_line(srcdoc.lines[start_line-1])
                    while line_start_:
                        start_line -= 1
                        comment_start -= len(srcdoc.lines[start_line])
                        line_start = line_start_
                        line_start_ = search_line(srcdoc.lines[start_line-1])
                    break
                # Search to end line
                while end_line+1 < len(srcdoc.lines):
                    line_end_ = search_line(srcdoc.lines[end_line+1])
                    while line_end_:
                        end_line += 1
                        comment_end += len(srcdoc.lines[end_line])
                        line_end = line_end_
                        line_end_ = search_line(srcdoc.lines[end_line+1])
                    break
                #print "Line-match ", language_key, tag_line, srcdoc.lines[tag_line]
                #print 'Comment:', comment_start, comment_end, srcdoc.data[comment_start:comment_end]
                break

            else:
                #print "No line-match at", language_key, tag_line, lines[tag_line]
                continue

        else: # seek multiline block comment

            comment_start = line_offset
            continue
        # FIXME
            data_ = srcdoc.data
            while data_:
                break
                start_line = end_line = tag_line
                comment_start = line_offset
                #comment_end = line_offset + len(linedata)
                #print 'comment_start', comment_start, 'len-data', len(data_)
                start = search_start(data_)
                if start:
                    comment_start += start.start()
                    comment_end = comment_start
                    data_ = data_[start.start():]
                    break
                if start_line == 0:
                    break
                start_line -= 1
                data_ = srcdoc.lines[start_line]
                comment_start -= len(data_) + 1

            if comment_end == -1:
                continue
            #print 'Start match', comment_end, comment_start, start_line, data.

            if not search_end:
                search_end = search_start

            end_line = start_line
            while data_:
                end = search_end(data_)
                if end:
                    comment_end += end.end()
                    break
                comment_end += len(data_) + 1
                end_line += 1
                data_ = srcdoc.lines[end_line]

            #print 'End match', comment_end, end_line, data.

            break

    if comment_end > -1:
        #print language_key, 'found comment', start_line, comment_start, \
        #            end_line, comment_end,\
        #            srcdoc.lines[start_line:end_line+1]
        return language_key, (comment_start, comment_end), \
                (start_line, end_line)



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


def find_comment_start(line, data, lines, flavours, matchbox):
    """Return at first comment match in lines before line, starting with comment line.
    Iow. given a comment line, return first line of continuous commentlines.
    """

def find_comment_start_after(line, data, lines, flavours, matchbox):
    """Return at first comment match of lines after line, starting with non-comment line.
    Iow. given a non comment line (or "any-line" -1), return first following
    comment line number.
    """
    assert isinstance(line, int)
    assert isinstance(lines, list)
    assert isinstance(lines[0], str)
    assert isinstance(flavours, list)
    assert isinstance(flavours[0], str)
    start = line
    if line == -1:
        start = 0
    for language_key in flavours:
        find = start
        scan_spec = matchbox[language_key]
        search_line, search_start, search_end = scan_spec
        if search_line:
            if line == -1 and search_line(lines[find]):
                return language_key, find
            while find+1 < len(lines):
                find += 1
                if search_line(lines[find]):
                    return language_key, find
        else:
            if line == -1 and search_start(lines[find]):
                return language_key, find
            while find+1 < len(lines):
                find += 1
                if search_start(lines[find]):
                    return language_key, find

def find_comment_end_after(line, data, lines, flavours, matchbox):
    assert isinstance(line, int), type(line)
    assert isinstance(lines, list), type(lines)
    assert isinstance(flavours, list), type(flavours)
    end = line
    for language_key in flavours:
        line = end
        scan_spec = matchbox[language_key]
        search_line, search_start, search_end = scan_spec
        if search_line:
            if not search_line(lines[line]):
                continue
            while line+1 < len(lines):
                if search_line(lines[line+1]):
                    line += 1
                else:
                    break
            return language_key, line
        else:
            if search_end(lines[line]):
                return language_key, line
            while line < len(lines):
                if search_end(lines[line]):
                    return language_key, line
                line+=1

def find_comment(line, data, lines, flavours, matchbox):
    "Return range of first comment, if any. "
    assert isinstance(line, int), type(int)
    assert isinstance(lines, list), type(lines)
    assert isinstance(flavours, list), type(flavours)
    cmnt_spec = find_comment_start_after(line, data, lines,
            flavours, matchbox)
    if not cmnt_spec:
        return
    flavour, cmnt_start_line = cmnt_spec
    if cmnt_start_line == None:
        return
    assert isinstance(cmnt_start_line, int), cmnt_spec
    flavour, cmnt_end_line = find_comment_end_after(cmnt_start_line, data,
            lines, [ flavour ], matchbox)
    assert isinstance(cmnt_end_line, int)
    return flavour, ( cmnt_start_line, cmnt_end_line )


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
        if end < len(data) and data[end] == ' ':
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
    def __init__(self, session, matchbox, source_name, context, data=None):
        self.session = session
        self.matchbox = matchbox
        self.source_name = source_name
        self.context = context
        self.srcdoc = SrcDoc( self.source_name, data )

    def find_tags(self):
        "scan for tags. return entire tag spec"
        for tagname in rc.tags:
            for tag_match in self.matchbox[tagname].finditer(self.srcdoc.data):
                tag_span = tag_match.start(), tag_match.end()
                yield TagInstance(self.source_name, tagname, tag_span)

    def find_comment_lines(self, flavours=STD_COMMENT_SCAN.keys(), from_line=None, at_span=None):
        if at_span:
            # Get comment at tag
            at_spec = at_line( *(
                    at_span + ( self.srcdoc.data, self.srcdoc.lines ) ) )
            if not at_spec:
                return
            start_line, line_offset, line_width = at_spec
            cmnt_spec = find_comment_start(start_line,
                    self.srcdoc.data, self.srcdoc.lines, flavours,
                    self.matchbox)
            if not cmnt_spec:
                return
            flavour, start_line = cmnt_spec
            flavour, end_line = find_comment_end_after(start_line,
                    self.srcdoc.data, self.srcdoc.lines, [ flavour ],
                    self.matchbox)
        else:
            if not from_line:
                # Get header comment by default
                from_line = 0
            flavour, cmnt_range = find_comment(from_line, self.srcdoc.data, self.srcdoc.lines,
                    flavours, self.matchbox)
            if not cmnt_range:
                return
            start_line, end_line = cmnt_range
        return flavour, start_line, end_line

    def find_comment(self, flavours=STD_COMMENT_SCAN.keys(), from_line=None, at_span=None):
        """Return ranges for comment. with no arg returns header comment.
        If some lines contain non-ws chars other than the comment itself
        then a list of ranges is returned, one for each line. Otherwise
        ranges are concatenated.
        """
        cmnt_spec = self.find_comment_lines(flavours=flavours, from_line=from_line, at_span=at_span)
        if not cmnt_spec:
            return
        assert len(cmnt_spec) == 3, cmnt_spec
        cmnt_line_range = cmnt_spec[1:3]
        ranges = []
        #ranges.append(cmnt_range)
        line = cmnt_line_range[0]
        while line <= cmnt_line_range[1]:
            ranges.append( self.srcdoc.line_char_range( line ) )
            line += 1
        return ranges

    def for_tag(self, tag):
        "retrieve comment for TagInstance TODO: map streams"

        # Get entire comment
        comment = get_tagged_comment(self, tag, None, rc)
        if not comment:
            return
        comment_flavour, comment_span, lines = comment

        # Clean comment from markup and adjust source span
        comment_data, comment_span = \
                trim_comment(self.matchbox[comment_flavour], self.srcdoc.data,
                                                            comment_span)
        (comment_start, comment_end) = comment_span

        return EmbeddedIssue(self.srcdoc, comment_span, lines, (),
                comment_flavour)



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

            tag_range = tag_match.start(), tag_match.end()

            # Get entire comment
            comment = get_tagged_comment(parser, tag_range[0],
                    tag_range[1]-tag_span[0]+1, rc)
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
        pass

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

        # pre-compile patterns TODO: per context
        matchbox = compile_rdc_matchbox(rc)

        taskdocs = {}

        for source in source_iter:
            parser = Parser(sa, matchbox, source, context)
            taskdocs[source] = srcdoc = parser.srcdoc

            for tag in parser.find_tags():

                try:
                    cmt = parser.for_tag(tag)
                except (Exception) as e:
                    if not opts.quiet:
                        log.err("Unable to find comment span for tag '%s' at %s:%s " % (
                            srcdoc.data[tag.start:tag.end], srcdoc.source_name, tag.char_span))
                        traceback.print_exc()
                    continue

                if not cmt:
                    continue

                srcdoc.scei.append(cmt)

                if opts.quiet:
                    issue_format = 'id'

                print EmbeddedIssue.formats[issue_format](cmt, srcdoc.data)
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
    pass
    #Radical.main()


