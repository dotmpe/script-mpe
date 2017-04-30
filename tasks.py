#!/usr/bin/env python
""":created: 2016-09-10

TODO: Read and sync between tasks.ttxtm and todo.list.
tasks.ttxtm is formatted as todo.txt. todo.list is compatible with
``grep -Hn`` output, and with Radical full-sh format.

    <file> ':' <line> ': ' <matched>

    <file> [ ':' [ <line_nr> ]
        [ ':' [ <line_range> ]
            [ ':' [ <outer_char_range> ]
                [ ':' [ <inner_char_range> ] ]
            ]
        ]
        ': ' <inner_text>
    ]

TODO: add datetime, modeline and other sentinel comment lines to output.

Objects
    Issue
        - strid
        - priority|prio
        - project
        - projects
        - contexts
    Comment
        - srcfile
        - line|line_range|outer_range|inner_range
"""
__description__ = "tasks - time ordered, grouped tasks"
__version__ = '0.0.4-dev' # script-mpe
__tasks_file__ = 'tasks.ttxtm'
__grep_file__ = 'TODO.list'
__to_do_list__ = 'to/do.list'
__usage__ = """
Usage:
  tasks.py [options] info
  tasks.py [-T|--tag TAG]... [options] list-issues
  tasks.py [-T|--tag TAG]... [options] new-scan
  tasks.py [-T|--tag TAG]... [options] read-issues
  tasks.py [options] update-list [TODOLIST]
  tasks.py [options] parse-list [TODOLIST]
  tasks.py help
  tasks.py -h|--help
  tasks.py --version

Tasks is a chunk of radical.py split off to do some specific things:

- Interact with issue records in a backend, specifically an initial prototype
  implementation using TODO.txt. And then have a looksee at potential uses..
  rSt please?
- Read/write to a list of matches like from radical or grep -nH.

The input is lines from source, represented in grep -nH syntax lines.
For radical, the input is source-code comment lines specificly. But the
principle is more generic provided a srcfile/linenr/text (grep -nH) input
can be provided.

To link a line there is a tag required, combined with unique Id. Linking
is done to a backend record, which Id may also be represented as a tag+id combo.

XXX: Which data is present is a constant editorial effort, and will vary from
case to case.

Options:
  -t FILE --tasks-file=FILE
                Document with ``todo.txt`` formatted tickets [default: %s].
  -g FILE --grep-file=FILE
                Result file with line references and single line descriptions
                parsed from source [default: %s].
  -T TAG --tag TAG
                Append [default: FIXME TODO XXX]
  -s SLUG --project-slug=SLUG
                Project name Id slug, used to match existing issues with
                comments. Defaults to current directory reformatted in all
                capitals and with non alphanumeric characters removed.
  -S SEP --key-sep=SEP
                Separator [default: -].
  -k TYPE --key-type=TYPE
                Mode to create new issue tags, 'number': append count+1 or
                'hex': append random hex ID, to project slug.
                [default: hex]
  --key-arg=LEN
                Argument to create new issue tags: length of hex or offset
                for number [default: 5].
  --must-exist
                Unless interactive or keep-going is on, fail the read
                immediately if there is no match. Exit will always be
                non-zero, if any input failed to link.
  --redis
  --no-redis
                Enable/disable redis backend.
  --link-other
                Upon reading
  --link-given
                Use given ID?
  --no-link-all
  --link-all
                Automatically create issue references for inputs.
  -i --interactive
                Allow for non-fully configured invocations to query the user
                via readline. Also enables different settings per input.
  -K --keep-going
                Recover from failure, dont exit but skip.
  -v            Increase verbosity.
  --verbosity VALUE
                Set verbosity.
  -h --help     Show this usage description.
                For a command and argument description use the command 'help'.
  -V --version     Show version (%s)

Defaults:
    (Would want to set defaults, but see docopt#36)

    TODOLIST      [default: %s]

""" % ( __tasks_file__, __grep_file__, __version__, __to_do_list__ )
from datetime import datetime
import os
import re
import hashlib
from pprint import pformat

from lib import Prompt
import log
import script_util
import res


grep_nH_rs = re.compile('^([^:]+):([0-9]+):\ (.*)')

rad_cmnt_rs = re.compile('''^ ([^:\ ]+)
    (:
        (?:[0-9]+)?
        (:
            (?:[0-9]+-[0-9]+)?
            (:
                (?:[0-9]+-[0-9]+)?
                (:
                    (?:[0-9]+-[0-9]+)?
                )
            )
        )
    ): \ (.*) $''', re.VERBOSE)



class Comment:

    def __init__(self, srcfile, **values):
        self.srcfile = srcfile
        attr = dict( # Default attrs: TODO: hide radical attr
                line_nr=None,
                line_range=None,
                inner_range=None,
                outer_range=None,
                _tag_def_sep=':',
                _comment_id=None,
                _comment_prefix='_r',
                _issue_id=None
            )
        attr.update(values)
        for k, v in attr.items():
            setattr(self, k, v)

        if self.line_nr and not self.line_range:
            self.line_range = self.line_nr, self.line_nr
        elif self.line_range and not self.line_nr:
            self.line_nr = self.line_range[0]

    def get_cid(self, sep=None):
        "Comment-Id: "
        if not sep: sep = self._tag_def_sep
        if self._comment_prefix and self._comment_id:
            return self._comment_prefix+sep+self._comment_id
        raise AttributeError("Missing attributes for comment-id: %s%s%s" %
            ( self._src_tag, sep, self._issue_id ))
    cid = property(get_cid)
    def try_cid(self, sep=None, ret=None):
        try:
            return self.get_cid(sep=sep)
        except AttributeError, e:
            return ret
    comment_id = property(try_cid)

    def get_eiid(self, sep=None):
        "Issue-Id give a local ID "
        if not sep: sep = self._tag_def_sep
        if self._issue_id and self._src_tag:
            return self._src_tag+sep+self._issue_id
        raise AttributeError("Missing attributes for issue-id: %s%s%s" %
            ( self._src_tag, sep, self._issue_id ))
    eiid = property(get_eiid)
    def try_eiid(self, sep=None, ret=None):
        try:
            return self.get_eiid(sep=sep)
        except AttributeError, e:
            return ret
    issue_id = property(try_eiid)

    def __repr__(self):
        return "Comment(srcfile=%r, text=%r)" % ( self.srcfile, self.text, )
    def __str__(self):
        return "%s %s %r" % (
                self.comment_id or '(blank)', self.issue_id or '', self.text )

    def store(self, storage):
        "TODO: Prepare instance for storage and commit"
        issue_id = storage.new_issue(self.text, src_name=self.srcfile,
                src_line=self.line_nr)
        #comment_id = storage.new_comment(issue_id, '_r')
        self.issue_id = issue_id
        self.storage = storage

    @classmethod
    def parse_tag_grep(cls, file, settings):
        """
        Go over `grep -nH`-style line matches, and recognize+parse line using
        regex. Then defer to Comment instance for further parsing.

        This takes a command-line settings object. It is used here to pre-parse
        the raw comment data, and to determine the primary ID.

        Yields instances of `Comment` for given file.
        """
        default_attr = dict( _tag_def_sep='-' )
        for line in open(file).readlines():
            attr = dict(default_attr)
            srcfile, comment = None, None
            grep_nH_rs_match = grep_nH_rs.match(line)
            if grep_nH_rs_match:
                srcfile, linenr, comment = grep_nH_rs_match.groups()
                attr['line_nr'] = linenr
            rad_cmnt_rs_match = rad_cmnt_rs.match(line)
            if rad_cmnt_rs_match:
                # TODO: radical sh-compat line format
                groups = list(rad_cmnt_rs_match.groups())
                srcfile, comment = groups.pop(0), groups.pop()
                fa = groups[0].count(':')
                fr = map(int, groups[0].strip(':').split('-'))
                if fa == 4:
                    inner_char_range = fr
                attr['inner_range'] = inner_char_range
            if not srcfile:
                log.warn('No match for %r', line)
                continue
            raw_comment = comment
            attr['tags'] = list(res.task.parse_tags(' '+raw_comment+' .'))
            for tag in settings.scan_tags:
                eiid, comment_ = try_parse_issue_id( tag, comment )
                if eiid:
                    comment = comment_
                    attr['_issue_id'] = eiid
                    attr['_src_tag'] = tag
                    break
            yield Comment(srcfile, text=comment, **attr)


def get_project_slug(name_id):
    return re.sub('[^A-Z_-]+', '-', name_id.upper())


def try_parse_issue_id(tag, text):
    "Retrieve issue-id usig tag from text. Return id and cleaned text."
    r = re.compile(res.task.re_issue_id_match % tag)
    m = r.search(text)
    if m:
        tag = text[slice(*m.span(1))]
        text = text.replace(text[slice(*m.span())], '')
        return tag.strip(res.task.tag_seps+' '), text
    return None, None


def parse_scan_options(settings, opts):
    """
    Seperate function to parse options to  read-issues.
    A bunch of weirdness going on with docopts repeating option.
    """
    settings.scan_tags = []
    if settings.project_slug:
        settings.scan_tags += [ settings.project_slug ]
    if settings.tag:
        if not isinstance(settings.tag, list):
            if ' ' in settings.tag:
                settings.tag = settings.tag.split(' ')
            else:
                settings.tag = [ settings.tag ]
        settings.scan_tags += settings.tag
    assert settings.scan_tags, "Either project-slug or tag options required"


def parse_redis(settings, opts):
    return res.task.RedisSEIStore(settings.project_slug, prefix='htd:tasks')


### Commands

def cmd_info(opts):
    """
        Dump settings dict.
    """
    for l, v in (
            ( "Tasks Document", opts.flags.tasks_file ),
            ( "Comment File", opts.flags.grep_file ),
            ( "Project Name Id Slug", opts.flags.project_slug ),
            ( "Key Type", opts.flags.key_type ),
            ( "Key Argument", opts.flags.key_arg ),
            ( "Key Separator", opts.flags.key_sep ),
    ):
        log.std('{green}%s{default}: {bwhite}%s{default}', l, v)


def cmd_list_issues(settings, opts, tasks_file):
    """
        Parse and list issues from taskdoc.
    """
    parse_scan_options(settings, opts) # all tags to settings.scan_tags
    if settings.redis:
        issues = parse_redis(settings, opts)
    elif os.path.exists(tasks_file):
        issues = res.todo.TodoTxtParser()
        list(issues.load(tasks_file))
    else:
        raise Exception("Backend required, an empty %s file will do" %
                settings.tasks_file )
    for k in issues:
        print k,
        print issues[k]


def cmd_read_issues(settings, opts, tasks_file, grep_file):
    """
        Read matches from grep-list. Parse given tags from the text
        and see about any backend that knows about it.

        Given a tasks-doc use it as a prototype backend on TODO.txt.
        If redis option is on, fall back to allow poor-man issues to exist
        there in a tasks.json format as a second prototype backend?

        XXX:z8VNFm3e work in progress
    """
    failed = []
    created = []
    updated = []
    parse_scan_options(settings, opts) # all tags to settings.scan_tags
    if settings.redis:
        issues = parse_redis(settings, opts)
    elif os.path.exists(tasks_file):
        issues = res.todo.TodoTxtParser()
        list(issues.load(tasks_file))
    else:
        raise Exception("Backend required, an empty %s file will do" %
                settings.tasks_file )
    for comment in Comment.parse_tag_grep(grep_file, settings):
        for tagid in comment.tags:
            # XXX: SCRIPT-MPE-2 skip for found reference, try to get to working flow
            if tagid in issues:
                continue
            elif issues.tagid_exists(tagid):
                continue
        if comment.issue_id:
            if not issues.tagid_exists(comment.eiid):
                msg = "Unknown issue reference: %s %r" % ( comment.issue_id,
                    comment )
                if settings.link_given or settings.link_all:
                    comment.store(issues)
                elif settings.interactive:
                    log.note(msg)
                    print comment
                    qopts = "Recreate Clear".split(' ')
                    q = Prompt.query("Recreate issue ID from comment or, clear Id?", qopts)
                    print q
                    if q is 'Recreate':
                        comment.store(issues)
                        created.append(comment)
                        continue
                    else:
                        log.warn("TODO: clear ID")
                if settings.must_exist:
                    failed.append(comment)
                log.warn(msg)
            continue

        if comment.comment_id:
            print list( issues.find_link(comment.comment_id) )
            #log.info("Existing issue for comment: %s" % comment)
            #updated.append(comment)
            # TODO: check, update from changed comment
        else:
            msg = "No %r or tag ID for file %s:%s %r" % (
                settings.project_slug, comment.srcfile, comment.line_nr or '',
                comment.text )
            if settings.link_all:
                comment.store(issues)
                created.append(comment)
                continue
            if settings.interactive:
                log.note(msg)
                print comment
                if Prompt.ask("Create issue from comment?", yes_no='Yn'):
                    comment.store(issues)
                    created.append(comment)
                    continue
            if settings.must_exist:
                failed.append(comment)
            log.warn("No issue link for %r" % ( comment, ) )
    issues.dirty = [ i.issue_id for i in created + updated ]
    print len(issues), 'Issues'
    print len(issues.dirty), 'Dirty'
    #issues.commit()

def cmd_parse_list(settings, opts, TODOLIST):#='to/do.list'):
    """
    """
    # FIXME: defaults
    if not TODOLIST:
        TODOLIST = __to_do_list__
    prsr = res.TodoListParser()
    prsr.parse(TODOLIST)


### Transform cmd_ function names to nested dict

commands = script_util.get_cmd_handlers_2(globals(), 'cmd_')
commands['help'] = script_util.cmd_help


### Util functions to run above functions from cmdline

def main(opts):

    """
    Execute command.
    """

    settings = opts.flags
    values = opts.args

    return script_util.run_commands(commands, settings, opts)

def get_version():
    return 'tasks.mpe/%s' % __version__

if __name__ == '__main__':
    import sys
    opts = script_util.get_opts(__description__ + '\n' + __usage__, version=get_version())
    if opts.flags.v or opts.flags.verbosity:
        log.category = 6
    if not opts.flags.project_slug:
        opts.flags.project_slug = get_project_slug(os.path.basename(os.getcwd()))
    sys.exit(main(opts))

