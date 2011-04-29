#!/usr/bin/env python

"""radical - Index and identify tagged comments in documents and source code.

Overview
--------
- Comments run from the end of the tag to the next '.\s' sequence or the end of
  the line. 
- Comment whitespace is collapsed and trimmed.  
- Comments starting with a tag are continued to the end of the comment line or
  block. Only indentation- and heading/trailing-whitespace is trimmed, meaning
  line markup and other 'preformatting' is retained.

Standard tags
-------------
TODO
    Incomplete implementation, stuff is missing.
FIXME
    Known bug or limitation, missing option or degraded user experience. 
XXX
    Remark on hacks and other ugliness. (See Jargon File)
WIP
    (Work in progress) Partial implementation, stuff is missing or broken.

Configuration
-------------
- Comment Regexes.
- Tag[, ID-Format[, ID-Generator]]
- Default-ID-Generator
- Default-ID-Format

Tags may be rewritten to the document with an ID.

Project Changelog
-----------------
2011-04-29
    Initial version. Planning for numeric and tiny ID. Need to recode hexdigest
    to full alphanumeric key.
2011-04-30
    Adding command-line options and separate storage service implementations.


Issues
-------
- If this'd use a extended context on the document IO stream, it could handle
  different line-endines. Currently UNIX-only.
- There are only two styles of comment markup implemented, which captures a
  decent set of document formants, but excludes numerous others. 
  
  Notable other styles:
  
  - SQL '-- ' prefixed line comments.
  - Vim '"' prefixed line comments.
  - INI ';' prefixed line comments.
  - SGML or XML style embedded comments.

- In extension of issue 2, also literals, as embedded in various document
  languages might be used in the same way as comments are. In fact, Python is
  known to use its literal markup to define inline documentation for interpreted
  scripts.


"""
# TODO:1: Integrate gate content stream
# TODO:2: Extend supported comment styles
# TODO:3: Scan for other literals, recognize language constructs.

#TODO comments run from the 
#start to the end line.
#whitespace collapsed.

import os, re, sys

from sqlalchemy import Column, Integer, String, Boolean, Text, create_engine,\
                        ForeignKey, Table, Index
from sqlalchemy.ext.declarative import declarative_base
from sqlalchemy.orm import relationship, backref, sessionmaker



Base = declarative_base()

class Index(Base):
    __tablename__ = 'tags'
    tagname = Column(String(16), primary_key=True)
    storage = Column(String(1024))

indices_comments = Table('indices_comments', Base.metadata,
        Column('index', ForeignKey('tags.tagname'), index=True),
        Column('comment', ForeignKey('document_embedded_comments.id'), index=True)
    )

class Comment(Base):
    __tablename__ = 'document_embedded_comments'
    id = Column(Integer(11), primary_key=True)
    filename = Column(String(255), index=True)
    pattern = Column(String(255))
    # XXX: unique on filename/linenumber?
    last_seen_linenumber = Column(Integer(11))
    tags = relationship(Index, secondary=indices_comments, backref='comments')
    comment = Column(Text, index=True)


# Storage & service IO
def store_comments(session, data, comment_span, flavour_spec, tagname, matchbox):
    """
    """
    comment_data = data[slice(*comment_span)]
    
    pass

# Content data scanning

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

collapse_ws = re.compile('\s*').sub

def get_tagged_comment(offset, width, data, language_scan):
    """
    Return the comment span that has a tag embedded at offset/width.
    This scans for continues sequences of comment lines, and may return spans
    for comment blocks that contain other tags. Also, this span may include 
    metacharacters used to markup comments. Further parsing of the comment
    block is left to the caller.
    """
    tag_line, line_offset, line_width = at_line(offset, width, data)

    lines = data.split('\n')

    for language_key in language_scan:
        comment_scan = language_scan[language_key]
        match_start = re.compile(comment_scan[0], re.M).match

        if not match_start(lines[tag_line]):
            continue

        if len(comment_scan) > 1:
            match_end = re.compile(comment_scan[1], re.M).match
        else:
            match_end = match_start
        
        data = lines[tag_line]
        start_line = tag_line 
        comment_start = line_offset
        while match_start(data):
            data = lines[start_line-1]
            if match_start(data):
                start_line -= 1
                comment_start -= len(data)    
        
        data = lines[tag_line]
        end_line = tag_line
        comment_end = line_offset + len(data)
        while match_end(data):
            data = lines[end_line+1]
            if match_end(data):
                end_line += 1
                comment_end += len(data)
        
        return language_key, (comment_start, comment_end), (start_line, end_line)


def get_service(t):
    __import__('radical_'+t)
    pass

def find(session, tags, matchbox, data, comment_flavours):
    """
    Look for tags in data, using the compiled tag regexes
    in matchbox, and post processing each found flavour of comment block to the
    distinct tagged comments.

    The tagged comment body text runs from the end of the tag, to the next '.' 
    followed by whitespace, or the end of the line for embedded comments.
    Comment blocks starting with a tag include the body text up to the end of
    the comment block. This makes a distinction between tagged comment lines and
    blocks.
    
    Recognized
    are:

    - Unix line comments (starting with '#', optionally whitespace prefixed).
    - FIXME: C-style line and block comments.
    """
    for tagname in matchbox:

        for match in matchbox[tagname].finditer(data):
            tag_span = match.start(), match.end()

            # Get entire comment
            comment = get_tagged_comment(tag_span[0],
                    tag_span[1]-tag_span[0], data,
                    comment_flavours)
            if not comment: 
                continue
            comment_flavour, comment_span, lines = comment
            #(comment_start, comment_end), (start_line, end_line) = comment_span, lines
            comment_data = data[slice(*comment_span)]

            # Tracked or anonymous tags
            #print tag_span, tagname, data[slice(*tag_span)], match.groups()
            if tags[tagname]:
                current_id = None
                if match.group(2):
                    assert tagname in tags, "Need index type for tracked tag at %s" % (tag_span,)
                    current_id = match.group(2)
                if current_id:
                    print 'Existing:', tagname, current_id, tag_span, comment_data
                    pass
                else:
                    print 'New:', tagname, tag_span, comment_data
                    pass # Identify new tracked tagged comment
                    # Write ID to file
            else:
                print 'Anonymous:', tagname, tag_span, comment_data
                pass # Anonymous tag

            style_regexes = comment_flavours[comment_flavour]
            continue
            # TODO: store
            for tagged in store_comments(session, data, comment_span, 
                    style_regexes, tagname, matchbox[tagname]):
                storage = None
                if tags[tagname]:
                    id_pattern, id_fmt, id_generator = tags[tagname]
                    storage = get_service(id_generator)


def find_files(session, tags, matchbox, paths, comment_flavours):
    """
    Look for tags in the data at each file path.
    """

    for p in paths:
        if not os.path.exists(p):
            err("Path does not exist: %s", p)
        elif os.path.isdir(p):
            subs = [ os.path.join(p, d) for d in os.listdir(p) ]
            find_files(session, tags, matchbox, subs, comment_flavours)
        elif not os.path.isfile(p):
            err("Ignored non-file path: %s", p)
        else:
            data = open(p).read()
            find(session, tags, matchbox, data, comment_flavours)
                    
# 

def get_session(dbref):
    engine = create_engine(dbref)
    Base.metadata.create_all(engine)
    session = sessionmaker(bind=engine)()
    return session

def err(msg, *args):
    print >> sys.stderr, msg % args

#

def main():
    paths = sys.argv[1:]
 
    dbref = 'sqlite:////radical.sqlite';

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
    #        # XXX: collapse htm and html
    #        'xml': ('xml', 'xslt', 'xsd', 'relax', 'xhtml', 'html'),
    #        'sgml': ('sgml','html'),
    #    }

    # Start/end regex patterns per comment flavour
    comment_flavours = {
            'unix_generic': ('^(\s*#).*$',),
            'c': ('^(\s*\/\*).*$','^.*(\*\/\s*)$'),
            'c_line': ('^(\s*\/\/).*$',),
        }
    # Tag pattern, format and index type
    tags = {
        'TODO': ('(%s)\:?(?:([0-9]+)\:)?', '%(tagname)s:%(numid)i', 'numeric_index'),
#        'FIXME': ('%(tagname)s:%(id)s', 'tiny_ticket'),
        'XXX': None,
#        'FACIOCRM': ('%(tagname)s-%(id)i', 'atlassian_jira'),
    }

    matchbox = {}
    for tagname in tags:
        pattern = r"(%s)" % tagname
        if tags[tagname]:
            pattern = tags[tagname][0] % tagname
        matchbox[tagname] = re.compile(pattern)

    dbsession = get_session(dbref)
    find_files(dbsession, tags, matchbox, paths, comment_flavours) 


if __name__ == '__main__':
    main()

# vim:et:
