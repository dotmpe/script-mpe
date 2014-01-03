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

TODO: doc review:

VIt might be an option to remove all these artefacts from source again
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

Issues
------
- Tagging multiline comments is desirable, nesting is not.
  If a comment block starts with a tag, but contains other tags, it is parsed as
  a line comment. (Normally a comment starting with a tag covers all the
  lines in the block)
- Implementation is still based on first iteration, 
  somewhat spotty and quite suboptimal.
- Python allows various form of strings while this only parses block types.

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
   EmbeddedIssue           |           * inode:INode ---/
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

import zope
from sqlalchemy import Column, Integer, String, Boolean, Text, create_engine,\
                        ForeignKey, Table, Index
from sqlalchemy.ext.declarative import declarative_base
from sqlalchemy.orm import relationship, backref, sessionmaker

#from cllct.osutil import parse_argv_split

import log
import confparse
import libcmd
from libcmd import optparse_override_handler
import taxus
from taxus import Taxus
from taxus.init import get_session
import res
import res.fs


# Storage model

Base = declarative_base()

class CommentTag(Base):
    __tablename__ = 'tags'
    tagname = Column(String(16), primary_key=True)
    #storage = Column(String(1024))

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
    __tablename__ = 'issues'
    id = Column(Integer, primary_key=True)
    tag_id = Column(String(16), ForeignKey('tags.tagname'))
    tag = relationship(CommentTag, primaryjoin=tag_id == CommentTag.tagname,
            backref='issues')
    description = Column(Text, index=True)
    inline = Column(Boolean, default=False)
    # XXX: unique on filename/linenumber?
    filename = Column(String(255), index=True)
    last_seen_startline = Column(Integer)

# tag ids:
NO_ID = 0
NEED_ID = -1


class EmbeddedIssue:
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
                self.file_name, self.tag_name, self.inline, data[slice(*self.tag_span)],
                self.description
            )
        
    @property
    def description(self):
        global rc
        data = open(self.file_name).read()
        description = clean_comment(
                rc.comment_scan[self.comment_flavour],
                data[slice(*self.description_span)].lstrip())
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
    

def at_line(offset, width, data):
    #data = data.decode('utf-8')
    lines = data.split('\n') 
    chars = 0
    for line, line_data in enumerate(lines):
        #print line, chars
        if offset < chars+len(line_data)+1:
            return line, chars, len(line_data)+1
        chars += len(line_data)+1
    assert not (offset+width > chars),  \
"Span is beyond document bounds: %r while document bytes:%r %r, lines:%s " % \
((offset, width), chars, len(data), len(lines))


collapse_ws_sub = re.compile(r'[\ \n]+').sub
collapse_ws = lambda s: collapse_ws_sub(' ', s)


_parsed_file_comments = {}

def get_tagged_comment(offset, width, data, language_keys, matchbox):
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
    tag_line, line_offset, line_width = at_line(offset, width, data)

    lines = data.split('\n')

    for language_key in language_keys:

        comment_scan = matchbox[language_key]
        # line based or start/end
        match_line, match_start, match_end = None, None, None
        if len(comment_scan) == 1:
            match_line = comment_scan[0].match
        elif len(comment_scan) == 2:
            match_start, match_end = comment_scan[1].match, comment_scan[1].match
        elif len(comment_scan) == 3:
            match_start, match_end = comment_scan[1].match, comment_scan[2].match

        data = lines[tag_line]
        start_line = tag_line 

        if match_line:
            # scan multiline for line-style comment
            if match_line(data):
                data = lines[tag_line]
                end_line = tag_line
                comment_end = line_offset + len(data)
                while match_end(data):
                    data = lines[end_line+1]
                    if match_line(data):
                        end_line += 1
                        comment_end += len(data) + 1
            else:
                print "No match at", language_key, tag_line, lines[tag_line]
                continue

        else: # seek multiline block comment

            comment_start = line_offset
            while match_start(data):
                data = lines[start_line-1]
                # adjust start-line and start-char
                if match_start(data):
                    start_line -= 1
                    comment_start -= len(data) + 1
           
            if not match_end:
                match_end = match_start

            data = lines[tag_line]
            end_line = tag_line
            comment_end = line_offset + len(data)
            while match_end(data):
                data = lines[end_line+1]
                if match_end(data):
                    end_line += 1
                    comment_end += len(data) + 1
        
        return language_key, (comment_start, comment_end), (start_line, end_line)

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

    # strip heading and trailing comment markup metachars
    m = match[0].match(comment_data)
    if not m:
        #  FIXME: c-style comments have embedded junk
        if comment_data != comment_data.strip():
            pass # TODO: block trim_comment
        return data[start:end], (start, end)
        raise Exception(m, comment_data)

    _1 = comment_data[m.end(1):]
    start += m.end(1)

    # and trailing markup if non-line comments
    if len(match)>1:
        m = match[1].match(_1)
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


def find_tagged_comments(session, matchbox, source, data, comment_flavours):
    """
    Look for tags in data, using the compiled tag regexes
    in matchbox, and post processing each found flavour of comment block to the
    distinct tagged comments.

    The tagged comment body text runs from the end of the tag, to the next '.' 
    followed by whitespace, or the end of the line.
    *Comment blocks* **starting with a tag** include the body text up to the end of
    the comment block. This makes a distinction between tagged comment lines and
    blocks.
    
    TODO: The `find` implementation needs optimization, more efficient to index comments
    first, then scan for tags. 

    Recognized
    are:

    - Unix line comments (starting with '#', optionally whitespace prefixed).
    - FIXME: C-style line and block comments.
    """
    for tagname in rc.tags:
        for tag_match in matchbox[tagname].finditer(data):
            tag_span = tag_match.start(), tag_match.end()

            # Get entire comment
            comment = get_tagged_comment(tag_span[0],
                    tag_span[1]-tag_span[0], data,
                    rc.comment_flavours, matchbox)
            if not comment: 
                log.err("Unable to find comment span for '%s' at %s:%s " % (
                    data[tag_span[0]:tag_span[1]], source, tag_span))
                continue
            comment_flavour, comment_span, lines = comment

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

            yield EmbeddedIssue(source, (comment_start, comment_end), tagname,
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



# Utils

def detect_flavour(pathname, data):
    pass

def find_files_with_tag(session, matchbox, paths):

    """
    Look for tags in the data at each file path.
    """
        
    sources = []
    for p in paths:
        if not os.path.isdir(p):
            sources.append(p)
        else:
            for p2 in res.fs.Dir.walk(p, opts=dict(recurse=True, files=True)):
                sources.append(p2)
    for source in sources:
        data = open(source).read()
        comment_flavours = detect_flavour(source, data)
        try:
            tag_generator = find_tagged_comments(session, matchbox, source, data, comment_flavours)
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
        'unix_generic': [ '^(\s*\#).*$', ],
        'c': [ 
            None,
            r'^(\s*\/\*).*$', 
            r'^.*(\*\/\s*)$' 
        ],
        'c_line': [ '^(\s*\/\/).*$', ],
        'py_doc': [ 
            None,
            r'^\s*(\"\"\")\s*.*$', 
            r'^.*(\"\"\")\s*$' ]
    }
"""
c
    start: any-space + '/*' + anything
    end: anything + '*/' + any-space
py:

"""
# Tag pattern, format and index type
DEFAULT_TAGS = {
        'TODO': ['(%s)[:_\s-](?:([0-9]+)[\s:])?', '%s:%i:', 'numeric_index'], # rad-ignore
#        'FIXME': ('%(tagname)s:%(id)s', 'tiny_ticket'),
    'XXX': ['(%s)[:_\s-](?:([0-9]+)[\s:])?',], # rad-ignore
#        'FACIOCRM': ('%(tagname)s-%(id)i', 'atlassian_jira'),
}

rc = confparse.Values()

# Main

# TODO see bookmarks, basename-reg, mimereg, flesh out TaxusFe
import txs

class Radical(txs.TaxusFe):

    zope.interface.implements(res.iface.ISimpleCommand)

    PROG_NAME = os.path.splitext(os.path.basename(__file__))[0]
    VERSION = "0.1"
    USAGE = """Usage: %prog [options] paths """

    DEFAULT_DB = "sqlite:///%s" % os.path.join(
                                        os.path.expanduser('~'), '.radical.sqlite')
    #DEFAULT_RC = 'cllct.rc'
    DEFAULT_CONFIG_KEY = PROG_NAME

    #NONTRANSIENT_OPTS = Taxus.NONTRANSIENT_OPTS + [
    #    'list_flavours', 'list_scans' ]
    #TRANSIENT_OPTS = Taxus.TRANSIENT_OPTS + [ 'run_embedded_issue_scan' ]
    DEFAULT_ACTION = 'run_embedded_issue_scan'

    DEPENDS = dict(
            init = [ 'cmd_options' ],
            run_embedded_issue_scan = [ 'init' ],
            list_flavours = [ 'cmd_options' ],
            list_scans = [ 'cmd_options' ]
        )

    @classmethod
    def get_optspec(klass, inherit):
        """
        Return tuples with optparse command-line argument specification.
        """
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

                (('-F', '--add-flavour'),{ 'action': 'callback', 'callback': append_comment_scan,
                    'help': "Scan for these comment flavours only, by default all known fla." }),

                (('--list-flavours',), libcmd.cmddict()),
                (('--list-scans',), libcmd.cmddict()),

                #(('--no-recurse',),{'action':'store_false', 'dest': 'recurse'}),
                #(('-r', '--recurse'),{'action':'store_true', 'default': True,
                #    'help': 'Recurse into directory paths (default: %default)'}),
            )

    def init_config_defaults(self):
        self.rc.tags = DEFAULT_TAGS
        self.rc.comment_scan = STD_COMMENT_SCAN
        self.rc.comment_flavours = self.rc.comment_scan.keys()
        self.rc.dbref = self.DEFAULT_DB

    def list_flavours(self, args=None, opts=None):
        for flavour in self.rc.comment_scan:
            print "%s:\n\tstart:\t%s" % ((flavour,)+
                    tuple(self.rc.comment_scan[flavour][:1]))
            if len(self.rc.comment_scan[flavour]) > 1:
                print "\tend:\t%s" % self.rc.comment_scan[flavour][1]
            print
        return

    def list_scans(self, args, opts):
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

    def init(self, prog=None):
        # start db session
        dbsession = get_session(self.rc.dbref)
        yield dict( dbsession=dbsession )

        # get backend service
        services = confparse.Values({})
        for tagname in self.rc.tags:
            if self.rc.tags[tagname] and len(self.rc.tags[tagname]) > 2:
                services[tagname] = get_service(self.rc.tags[tagname][2])
                log.info("Using backend %s for %s", services[tagname], tagname)

        yield dict( services=services )

    def run_embedded_issue_scan(self, dbsession, *paths):
        """
        """
        if not paths:
            paths = ['.']
            # XXX debugging
            #paths = ['radical_xmldoctext.xml', 'radical.py']

        # pre-compile patterns
        matchbox = {}
        for tagname in self.rc.tags:
            pattern = r"(%s)" % tagname
            if self.rc.tags[tagname]:
                pattern = self.rc.tags[tagname][0] % tagname
            matchbox[tagname] = re.compile(pattern)

        for flavour in self.rc.comment_scan:
            scan = self.rc.comment_scan[flavour]
            match_start = re.compile(scan[0], re.M)
            if len(scan) > 1:
                match_end = re.compile(scan[1], re.M)
                matchbox[flavour] = (match_start, match_end)
            else:
                matchbox[flavour] = (match_start, )

        # iterate paths
        global rc
        rc = self.rc
        for embedded in find_files_with_tag(dbsession, matchbox, paths):
            if embedded.tag_id:
                #if embedded.tag_id == NEED_ID:
                    log.note('Embedded Issue %r', (embedded.file_name, \
                            embedded.tag_name, embedded.tag_id, \
                            embedded.comment_span, embedded.comment_lines, \
                            embedded.description))
                    #new_id = service.new_issue(embedded.tag_name, embedded.description)
                    #embedded.set_new_id(new_id)
                    #service.update_issue(embedded.tag_name, embedded.tag_id,
                    #        embedded.description)
            else:
                assert False
                pass
            #embedded.store(dbsession)


if __name__ == '__main__':
    Radical.main()
    #TargetResolver().main(['cmd:options'])

