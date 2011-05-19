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
- Tag[, ID-Format[, ID-Generator]]
- Comment start/end scan Regexes.

Tags may be rewritten to the document with an ID?

Project Changelog
-----------------
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

Issues
-------
- Tagging multiline comments is desirable, nesting is not.
  If a comment block starts with a tag, but contains other tags, it is parsed as
  a line comment. (Normally a comment starting with a tag covers all the
  lines in the block)
  

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


import optparse, os, re, sys
from pprint import pformat

from sqlalchemy import Column, Integer, String, Boolean, Text, create_engine,\
                        ForeignKey, Table, Index
from sqlalchemy.ext.declarative import declarative_base
from sqlalchemy.orm import relationship, backref, sessionmaker

#from cllct.osutil import parse_argv_split

import confparse


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
    id = Column(Integer(11), primary_key=True)
    tag_id = Column(String(16), ForeignKey('tags.tagname'))
    tag = relationship(CommentTag, primaryjoin=tag_id == CommentTag.tagname,
            backref='issues')
    description = Column(Text, index=True)
    inline = Column(Boolean, default=False)
    # XXX: unique on filename/linenumber?
    filename = Column(String(255), index=True)
    last_seen_startline = Column(Integer(11))


class EmbeddedIssue:
    def __init__(self, file_name, comment_span, tag_name, tag_id, tag_span,
            description_span, inline, comment_flavour):
        self.file_name = file_name
        self.tag_name = tag_name
        self.tag_id = tag_id
        self.comment_span = comment_span
        self.tag_span = tag_span
        self.description_span = description_span
        self.inline = inline
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

#end_of_line = re.compile('$').search

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

def get_tagged_comment(offset, width, data, language_keys, matchbox):
    """
    Return the comment span that has a tag embedded at offset/width.
    This scans for continues sequences of comment lines, and may return spans
    for comment blocks that contain other tags. Also, this span may include 
    metacharacters used to markup comments. Further parsing of the comment
    block is left to the caller.
    """
    tag_line, line_offset, line_width = at_line(offset, width, data)

    lines = data.split('\n')

    for language_key in language_keys:

        comment_scan = matchbox[language_key]
        match_start = comment_scan[0].match
        match_end = None
        if len(comment_scan)>1:
            match_end = comment_scan[1].match

        if not match_start(lines[tag_line]):
            continue
        
        data = lines[tag_line]
        start_line = tag_line 
        comment_start = line_offset
        while match_start(data):
            data = lines[start_line-1]
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
        raise Exception(m, comment_data)

    _1 = comment_data[m.end(1):]
    start += m.end(1)

    # and trailing markup if non-line comments
    if len(match)>1:
        m = match[1].match(_1)
        _2 = _1[:m.start(1)]
        end = start + m.start(1)
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
        raise NotImplemented
        data = re.sub(scan[0], ' ', data, re.M)
        if len(scan)>1:
            data = re.sub(scan[1], '', data)

    return data

def find(session, matchbox, source, data):
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
    global rc

    for tagname in rc.tags:

        for match in matchbox[tagname].finditer(data):
            tag_span = match.start(), match.end()

            # Get entire comment
            comment = get_tagged_comment(tag_span[0],
                    tag_span[1]-tag_span[0], data,
                    rc.comment_flavours, matchbox)
            if not comment: 
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
                    data[match.end():comment_end])
            if next_tag:
                next_tag = next_tag + match.end()

            if not next_tag and comment_start == match.start():
                # Comment starts with Tag, Tag spans entire comment block
                description_end = comment_end
            else:
                inline = True
                # Scan for end of Issue description
                find_description_end = end_of_description(data[match.end():comment_end])
                if find_description_end:
                    description_end = match.end() + find_description_end.end()
                else: # Line comment
                    end_offset = end_of_line(data[match.end():comment_end])#.end()
                    if end_offset:
                        # TODO: stop at end of line
                        description_end = match.end() + end_offset
                    else:
                        description_end = comment_end

            # Always stop at next tag
            if next_tag and next_tag < description_end:
                description_end = next_tag

            current_id = None
            if rc.tags[tagname]:
                if match.group(2):
                    assert tagname in rc.tags, "Need index type for tracked tag at %s" % (tag_span,)
                    current_id = match.group(2)
                else:
                    current_id = -1

            yield EmbeddedIssue(source, (comment_start, comment_end), tagname,
                    current_id, 
                    (match.start(), match.end()), (match.end(),
                        description_end), inline, comment_flavour)
            continue

            # Get and further clean the issue text from the source data
            tag_data = clean_comment(rc.comment_scan[comment_flavour],
                    data[match.end():description_end].lstrip())
            if inline:
                tag_data = collapse_ws(tag_data)
                if not tag_data.endswith(' '):
                    tag_data += ' '

            # Use tracker service, or anonymous tags
            if rc.tags[tagname]:
                current_id = None
                if match.group(2):
                    assert tagname in rc.tags, "Need index type for tracked tag at %s" % (tag_span,)
                    current_id = match.group(2)

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

# TODO: replace by cllct.osutil once that is packaged
def parse_argv_split(options, argv, usage="%prog [args] [options]"):
    """Parse argument vector to a an arguments list and an
    option dictionary. Return parser, optsv, args tuple.
    """
    parser = optparse.OptionParser(usage)

    optnames = []
    nullable = []
    for opt in options:
        #parser.add_option(*_optprefix(opt[0]), **opt[1])
        parser.add_option(*opt[0], **opt[1])
        if 'dest' in opt[1]:
            optnames.append(opt[1]['dest'])
        else:
            optnames.append(opt[0][-1].lstrip('-').replace('-','_'))
        if 'default' not in opt[1]:
            nullable.append(optnames[-1])

    optsv, args = parser.parse_args(argv)

    # FIXME: instead of degrade by converting to dict, add optname/nullable name
    # lists to options Values instance
    opts = {}
    for name in optnames:
        if not hasattr(optsv, name) and name in nullable:
            continue
        opts[name] = getattr(optsv, name)
    return parser, opts, args

def find_files(session, matchbox, paths):
    """
    Look for tags in the data at each file path.
    """

    for p in paths:
        if not os.path.exists(p):
            err("Path does not exist: %s", p)
        elif os.path.isdir(p):
            subs = [ os.path.join(p, d) for d in os.listdir(p) ]
            # recurse
            for f in find_files(session, matchbox, subs):
                yield f
        elif not os.path.isfile(p):
            err("Ignored non-file path: %s", p)
        else:
            data = open(p).read()
            for f in find(session, matchbox, p, data):
                yield f


def get_session(dbref):
    engine = create_engine(dbref)
    Base.metadata.create_all(engine)
    session = sessionmaker(bind=engine)()
    return session

def get_service(t):
    return __import__('radical_'+t)

def err(msg, *args):
    print >> sys.stderr, msg % args


# Optparse callbacks
def append_comment_scan(option, value, parser):
    print 'TODO comment_scan', (option, value, parser)
    pass


# Static metadata

__usage__ = """Usage: %prog [options] paths """

DEFAULT_DB = "sqlite:///%s" % os.path.join(
                                    os.path.expanduser('~'), '.radical.sqlite')
DEFAULT_RC = os.path.join(os.path.expanduser('~'), '.radicalrc')

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
        'unix_generic': ['^(\s*\#).*$',],
        'c': ['^(\s*\/\*).*$','^.*(\*\/\s*)$'],
        'c_line': ['^(\s*\/\/).*$',],
    }
# Tag pattern, format and index type
DEFAULT_TAGS = {
        'TODO': ['(%s)[:_\s-](?:([0-9]+)[\s:])?', '%s:%i:', 'numeric_index'],
#        'FIXME': ('%(tagname)s:%(id)s', 'tiny_ticket'),
    'XXX': ['(%s)[:_\s-](?:([0-9]+)[\s:])?',],
#        'FACIOCRM': ('%(tagname)s-%(id)i', 'atlassian_jira'),
}

__options__ = (
    (('-c', '--config'),{ 'metavar':'PATH', 'default': DEFAULT_RC, 
        'dest': "config_file",
        'help': "Run time configuration. This is loaded after parsing command "
        "line options, non-default option values wil override persisted "
        "values (see --update-config) (default: %default). " }),

    (('-C', '--update-config'),{ 'action':'store_true', 'help': "Write back "
        "configuration after updating the settings with non-default option "
        "values.  This will lose any formatting and comments in the "
        "serialized configuration. " }),

    (('-d', '--database'),{ 'metavar':'URI', 'dest':'dbref',
        'help': "A URI formatted relational DB access description, as "
            "supported by sqlalchemy. Ex:"
            " `sqlite:///radical.sqlite`,"
            " `mysql://radical-user@localhost/radical`. "
            "The default value (%default) may be overwritten by configuration "
            "and/or command line option. ",
        'default': DEFAULT_DB }),

    # -f PATTERN   Include only matching files.

    (('-F', '--add-flavour'),{ 'action': 'callback', 'callback': append_comment_scan,
        'help': "Scan for these comment flavours only, by default all known fla." }),

    (('--list-flavours',),{ 'action':'store_true', 'help': "" }),
    (('--list-scans',),{ 'action':'store_true', 'help': "" }),

    (('--print-config',),{ 'action':'store_true', 'help': "" }),

    #(('--no-recurse',),{'action':'store_false', 'dest': 'recurse'}),
    #(('-r', '--recurse'),{'action':'store_true', 'default': True,
    #    'help': 'Recurse into directory paths (default: %default)'}),

#    (('-v', ''),{'dest':'verboseness','default': 0, 'action':'count',
#        'help': "Increase chattyness (defaults to 0 or the CLLCT_DEBUG env.  var.)"}),
    (('-V', '--version'),{ 'action':'version', 'help': "" }),
)


# Main

rc = confparse.Values()

# XXX: or only list the complement of these (the setting keys)?
rc_transient = ['print_config', 'list_flavours', 'list_scans', 'update_config']

def rc_init_default():
    global rc
    # TODO: setup.py script
    os.mknod(DEFAULT_RC)
    rc = confparse.yaml(DEFAULT_RC)

    rc.set_source_key('config_file')
    rc.config_file = DEFAULT_RC

    rc.tags = DEFAULT_TAGS
    rc.comment_scan = STD_COMMENT_SCAN
    rc.comment_flavours = rc.comment_scan.keys()
    rc.dbref = DEFAULT_DB

    rc.commit()

def rc_cli_override(parser, opts):
    global rc
    for o in opts:
        if o in rc_transient:
            continue
        elif hasattr(rc, o):
            setattr(rc, o, opts[o])
        else:
            err("Ignored option %s", o)


def main(argv=None):
    global rc

    # parse arguments
    if not argv:
        argv = sys.argv[1:]
    parser, opts, paths = parse_argv_split(__options__, argv, __usage__)

    rc_cli_override(parser, opts)
    if opts['update_config']:
        rc.commit()

    if opts['print_config']:
        yaml_dump(rc.copy(), sys.stdout)
        return

    elif opts['list_flavours']:
        for flavour in rc.comment_scan:
            print "%s:\n\tstart:\t%s" % ((flavour,)+
                    tuple(rc.comment_scan[flavour][:1]))
            if len(rc.comment_scan[flavour]) > 1:
                print "\tend:\t%s" % rc.comment_scan[flavour][1]
            print
        return

    elif opts['list_scans']:
        for tag in rc.tags:
            print "%s:" % (tag)
            if rc.tags[tag]:
                if len(rc.tags[tag]) > 0:
                    print "\tmatch:\t%s" % (rc.tags[tag][0] % tag)
                if len(rc.tags[tag]) > 1:
                    print "\tformat:\t%s" % rc.tags[tag][1]
                if len(rc.tags[tag]) > 2:
                    print "\tindex:\t%s" % rc.tags[tag][2]
            else:
                print "\tmatch:\t(%s)" % tag
            print
        return

    # pre-compile patterns
    matchbox = {}
    for tagname in rc.tags:
        pattern = r"(%s)" % tagname
        if rc.tags[tagname]:
            pattern = rc.tags[tagname][0] % tagname
        matchbox[tagname] = re.compile(pattern)

    for flavour in rc.comment_scan:
        scan = rc.comment_scan[flavour]
        match_start = re.compile(scan[0], re.M)
        if len(scan) > 1:
            match_end = re.compile(scan[1], re.M)
            matchbox[flavour] = (match_start, match_end)
        else:
            matchbox[flavour] = (match_start, )

    # start db session
    dbsession = get_session(rc.dbref)

    if not paths:
        paths = ['.']

    # get backend service
    service = None
    if rc.tags[tagname] and len(rc.tags[tagname]) > 2:
        service = get_service(rc.tags[tagname][2])

    # iterate paths
    for embedded in find_files(dbsession, matchbox,
            paths):
        if embedded.tag_id:
            if embedded.tag_id == -1:
                new_id = service.new_issue(embedded.tag_name, embedded.description)
                embedded.set_new_id(new_id)
            else:
                service.update_issue(embedded.tag_name, embedded.tag_id,
                        embedded.description)
        else:
            pass

        embedded.store(dbsession)


if __name__ == '__main__':

    rcfile = list(confparse.get_config('radicalrc'))
    if rcfile:
        rc.config_file = rcfile.pop()
    else:
        rc.config_file = DEFAULT_RC
    "Configuration filename."

    if not rc.config_file or not os.path.exists(rc.config_file):
        rc_init_default()
    assert rc.config_file, \
        "No existing configuration found, please rerun/repair installation. "

    rc = confparse.yaml(rc.config_file)
    "Static, persisted settings."

    main()
    "Start CLI invocation handling. "

# vim:et:
