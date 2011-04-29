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
    filename = Column(String(255), index=True, unique=True)
    pattern = Column(String(255))
    last_seen_linenumber = Column(Integer(11))
    tags = relationship(Index, secondary=indices_comments, backref='comments')
    comment = Column(Text, index=True)


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


def get_tagged_comment(offset, width, data):
    """
    Return the comment span that has a tag embedded at offset/width.

    The comment runs from the end of the tag, to the next '.' followed by
    whitespace, or the end of the line. 
    
    This span may include metacharacters used to markup comments. Recognized
    are:

    - Unix line comments (starting with '#', optionally whitespace prefixed).
    - FIXME: C-style line and block comments.

    """
    tag_line, line_offset, line_width = at_line(offset, width, data)

    lines = data.split('\n')

    language_key = 'unix_generic'
    # TODO:
    language_keys = {
            'c':   ('c', 'js', 'hx', 'php', ),
            'vim': ('vim', 'vimrc'),
            'rst': ('rst', 'text',),
            'sql': ('sql', 'mysql',),
            'ini':  ('ini',),
            'py':  ('py',),
            # XXX: collapse htm and html
            'xml': ('xml', 'xslt', 'xsd', 'relax', 'xhtml', 'html'),
            'sgml': ('sgml','html'),
        }
    language_markup = {
            'unix_generic': ('^#.*$',)
        }

    comment_scan = language_markup[language_key]
    match_start = re.compile(comment_scan[0], re.M).match
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
    
    return (comment_start, comment_end), (start_line, end_line)


def get_service(t):
    __import__('gtd_'+t)
    pass

def find(session, tags, matchbox, paths):
    for p in paths:
        if not os.path.exists(p):
            err("Path does not exist: %s", p)
        elif os.path.isdir(p):
            subs = [ os.path.join(p, d) for d in os.listdir(p) ]
            find(session, tags, matchbox, subs)
        elif not os.path.isfile(p):
            err("Ignored non-file path: %s", p)
        else:
            data = open(p).read()
            for tagname in matchbox:

                storage = None
                if tags[tagname]:
                    id_fmt, id_generator = tags[tagname]
                    storage = get_service(id_generator)

                # TODO
                for match in matchbox[tagname].finditer(data):
                    start, end = match.start(), match.end()
                    comment_span = get_tagged_comment(start, end-start, data)
                    (comment_start, comment_end), (start_line, end_line) = comment_span
                    print p, comment_span, data[comment_start:comment_end]
                    current_id = None
                    #print '\t',t,m

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

    tags = {
        'TODO': ('%(tagname)s:%(id)i', 'numeric_index'),
#        'FIXME': ('%(tagname)s:%(id)s', 'tiny_ticket'),
        'XXX': None,
#        'FACIOCRM': ('%(tagname)s-%(id)i', 'atlassian_jira'),
    }

    dbref = 'sqlite:////gtd.sqlite';

    matchbox = {}
    for tagname in tags:
        matchbox[tagname] = re.compile(r"(%s)" % tagname)

    dbsession = get_session(dbref)
    find(dbsession, tags, matchbox, paths) 


if __name__ == '__main__':
    main()
