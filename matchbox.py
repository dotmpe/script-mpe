#!/usr/bin/env python
"""
matchbox - a (file)naming libcmd_docoptity based on regular expressions.

A filename cleaning and reformatting libcmd_docoptity. See matchbox.rst.
"""
from __future__ import print_function

__version__ = '0.0.4-dev' # script-mpe

import inspect
import sys
import os
import re
from pprint import pformat
#from optparse import Values

from script_mpe import libcmd_docopt
from script_mpe.res import js, mb
from script_mpe.confparse import Values
from script_mpe.confparse import yaml_load, yaml_safe_dumps



escape_meta_rx = re.compile(mb.escape_meta_r)
name_var_match_rx = re.compile('@(%s)' % mb.simple_varname_r)

def name_template_opts(name_template):
    "Return place holders in name pattern"
    return [ varname for varname
            in name_var_match_rx.findall(name_template) ]

vartable_basic = {}
vartable = {}

resolvers = {
    'SZ': lambda path: os.path.getsize(path)
}

templates = {
    'std-ascii': '@NAMEPART.@EXT'
}
paths = {
#    '*.*': 'std-ascii'
}

def load_vars(name='table.vars'):
    """
    Load `name` from ``~/bin`` and `cwd`.
    """
    homedir=os.path.expanduser('~/bin')
    load_from_bre(os.path.join(homedir, name))
    cwd=os.getcwd()
    if cwd != homedir:
        load_from_bre(os.path.join(cwd, name))

def load_from_bre(filepath):
    """
    Load Bash BRE patterns and keys from shell script, and try
    to translate to Python. Syntax::

        match_<TAG>='<BRE-pattern>'

    """
    if not os.path.exists(filepath):
        return
    fl = open(filepath)
    for line in fl.readlines():
        line = line.strip()
        if not line or line[0:6] != 'match_':
            continue
        varname, regexpat = line[6:].split('=')
        vartable_basic[ varname ] = regexpat
        # get simple bash regex as python regex
                # remove escaping
                # remove optgroup
        vartable[ varname ] = re.sub(
                r'\\([\(){}|])', r'\1',
                re.sub(r'^\\\((.*)\\\)\\\?$', r'\1', regexpat.strip("'")))

    print('# Loaded %s' % filepath)

def load_templates(name='table.names'):
    """
    Load table `name` (with name templates)
    from the local dir and/or parents,
    and from the script dir.
    """
    homedir=os.path.expanduser('~/bin')
    load_names_from(os.path.join(homedir, name))
    cwd=os.getcwd()
    if cwd != homedir:
        load_names_from(os.path.join(cwd, name))

def load_names_from(filepath):
    """
    Load templates from file, using tags field as ID.
    Iow. tags must be unique. Put the globs for each
    template as key in the global `paths`, pointing
    to a list of tags. Iow. one globs may provide filepaths
    that match one of multiple tags.
    """
    global templates, paths
    if not os.path.exists(filepath):
        return
    fl = open(filepath)
    for line in fl.readlines():
        line = line.strip()
        if not line or line[0] == '#':
            continue
        parts = list(line.split(' '))
        if len(parts) > 3 or len(parts) < 2:
            raise Exception("Parser error %s at line: '%s'"%(filepath,line))
        if len(parts) ==2:
            parts += ['',]
        glob, pattern, tags = parts
        if tags in templates:
            print("# Duplicate template %s" % tags, file=sys.stderr)
        #tags = tags.split(',')
        #assert tags not in templates, "Duplicate template %s" % tags
        templates[tags] = pattern
        if glob in paths:
            paths[glob] += [tags]
        else:
            paths[glob] = [tags]


def name_regex(name_template, var_names=None):
    """
    Give name template, return Python regex string. Syntax e.g.::

        ./path/@TAGfilename-@NUM.@CODEC.@EXT

    The pattern includes named capture groups for each name tag.
    """
    if not var_names:
        var_names = name_template_opts(name_template)
    name_regexpat = escape_meta_rx.sub(r'\\\1', name_template)
    for name in var_names:
        if name not in vartable:
            raise Exception("No such var: %s" % name)
        optional = name[:3] == 'OPT' # XXX hacky name convention
        # XXX if bre: raise Exception("No named capture groups in BRE")
        subs = '(?P<%s>%s)' % ( name, vartable[name] )
        if optional:
            subs += '?'
        name_regexpat = name_regexpat.replace('@'+name, subs)
    return '^%s$' % name_regexpat

def name_format(seed, template, names=None):
    """
    Helper for rename.
    """
    if not names:
        names = name_template_opts(template)
    name_new = template
    for name in names:
        optional = name[:3] == 'OPT' # XXX hacky name convention
        if optional and not seed[name]:
            subst = ''
        else:
            subst = seed[name]
        name_new = name_new.replace('@'+name, subst)
    return name_new

def resolve_seed(path, seed, names):
    for name in names:
        if name not in seed:
            seed[name] = str(resolvers[name](path))


### Main entry handlers

def c_show():
    "Print name and internal var/name table data"
    print('matchbox.py')
    print('Var-table:')
    print(pformat(vartable))
    print('Templates:')
    print(pformat(templates))
    print('Paths:')
    print(pformat(paths))

def c_dump():
    """
    Dump internal table data to output using a writer.
    """
    load_templates()
    data = Values(dict(
        vars=Values(vartable),
        templates=Values(templates),
        names=Values()
      ))
    #for key in templates:
    outf = sys.stdout
    opts = Values(dict(
        flags = Values(dict(
            pretty=True,
            output_format='json',
        ))
      ))
    writers[opts.flags.output_format](data.todict(), outf, opts)

def c_help():
    "Print generic usage help info and docs for each command. "
    for x in globals():
        c = globals()[x]
        if x.startswith('c_') and callable(c):
            print("matchbox.py", x[2:].replace('_', '-'), format_f_spec(c))
            if hasattr(c, '__doc__') and c.__doc__:
                print('   ', c.__doc__.strip())

def format_f_spec(func):
    args, varargs, keywords, defaults = inspect.getargspec(func)
    argspec = [ arg.upper() for arg in args ]
    if defaults:
        dfidx = len( args ) - len( defaults )
        defaults = list(defaults)
    while defaults:
        argspec[dfidx] += '=%s' % defaults.pop()
        dfidx += 1
    if varargs:
        argspec += [ '%s...' % varargs.upper() ]
    if keywords:
        argspec += [ '%s=...' % keywords.upper() ]

    return ' '.join(argspec)

def c_name_regex(name_template):
    "Print regex pattern for given name template. "
    print(name_regex(name_template))

def c_match_name_vars(name, name_template_or_tag="@NAMEPART.@EXT"):
    """
    Given name `name` and template or template tag, parse
    and print a column formatted table.
    """
    load_templates()
    name_template = name_template_or_tag
    if name_template in templates:
        name_template = templates[name_template_or_tag]
    var_names = name_template_opts(name_template)
    regex = name_regex(name_template, var_names)
    print("# Compiled pattern to '%s'" % regex)
    regex_r = re.compile(regex)
    rows = []
    if name:
        match = regex_r.match(name)
        if not match:
            print("Mismatched '%s'" % name, file= sys.stderr)
            return 1
        else:
            mdict = match.groupdict()
            rows += [
              [ mdict[var] if var in mdict else '' for var in var_names ]
            ]

    print_tab_cols(var_names, rows)


def print_tab_cols(fields, rows):
    """
    Helper to print columnized data, checking with max. datum widths first.
    """
    widths = [ 1 ] * len(fields)
    widths[0] = 2

    for idx, field in enumerate(fields):
        l = len(field)
        if widths[idx] < l+1:
            widths[idx] = l+1

    for row in rows:
        for idx, field in enumerate(row):
            l = len(field)
            if widths[idx] < l+1:
                widths[idx] = l+1

    widths[0] -= 2
    print('# '+''.join([field.ljust(widths[i]) for i, field in enumerate(fields)]))
    widths[0] += 2
    for row in rows:
        print(''.join([datum.ljust(widths[i]) for i, datum in enumerate(row)]))


def c_match_names_vars(name_template_or_tag="@NAMEPART.@EXT"):
    """Read filenames from lines at std, extract fields by regex
    and output result line by line.
    The regex is build according to the name template,
    """
    name_template = name_template_or_tag
    if name_template in templates:
        name_template = templates[name_template_or_tag]
    var_names = name_template_opts(name_template)
    regex = name_regex(name_template, var_names)
    print("# Fields: '%s'" % ', '.join(var_names))
    print("# Compiled pattern to '%s'" % regex)
    regex_r = re.compile(regex)
    while True:
        line = sys.stdin.readline().strip()
        if line == "\l":
            break
        if line:
            match = regex_r.match(line)
            if not match:
                print("Mismatched '%s'" % line, file= sys.stderr)
            else:
                mdict = match.groupdict()
                print("\t".join([
                    mdict[var] if var in mdict else '' for var in var_names
                ]))

def c_rename(from_template, to_template, exists=None, stat=None):
    """Read filenames from lines at stdin, extract fields, reformat name
    and write file path to stdout. Resolve values for new template placeholder
    fields as needed. Does not rename the file.

    `exists` boolean or none wether file should exists or not
    `stat` boolean or none; use local filesystem to resolve missing fields,
    """
    var_names_to = name_template_opts(to_template)
    var_names_from = name_template_opts(from_template)
    regex_from = name_regex(from_template)
    print("# Regex from: %s" % regex_from)
    regex_from_r = re.compile(regex_from)
    for name in var_names_to:
        if name not in var_names_from:
            if stat or stat is None:
                stat = True
                exists = True
                assert name in resolvers, name
            else:
                exists = False
    while True:
        line = sys.stdin.readline().strip()
        if line == "\l":
            print('# (eof) ')
            break
        if not line:
            print('# (blank line) ')
        else:
            match = regex_from_r.match(line)
            if not match:
                print("Mismatched '%s'" % line, file= sys.stderr)
                print("# (mismatched line '%s') " % line)
                continue
            mdict = match.groupdict()
            if stat and exists:
                # TODO implement other resolvers than local fs
                if not os.path.exists(line):
                    print("Cannot stat '%s'" % line, file= sys.stderr)
                    print("# (missing file '%s') " % line)
                    continue
                resolve_seed(line, mdict, var_names_to)
            name_new = name_format(mdict, to_template, names=var_names_to)
            print(line, name_new)

def c_check_name(line, *tags):
    """
    Given line with path name, match against entire matchbox.
    Returns an error if not a single match was found,
    or if the match does not have a tag listed in given `tags`.
    """
    load_templates()
    matchbox = {}
    for name in templates:
        regex = name_regex(templates[name])
        matchbox[name] = re.compile(regex)

    passed = []
    invalid = []
    for name in matchbox:
        match = matchbox[name].match(line)
        if tags:
            if name in tags:
                if match:
                    passed.append(name)
            continue
        else:
            if match:
                passed.append(name)
                continue
        invalid.append(name)

    if not invalid:
        if not passed:
            print("! No match for", line)
            return 2
        else:
            print('OK', ','.join(passed), line)

    else:
        print('INVALID', ','.join(invalid), ','.join(passed), line)
        return 1


def c_check_names(*tags):
    """Read filenames from stdin, check all name templates to see if at least one
    matches and print their tags. Optionally pass set of valid tags on argv,
    and fail for paths that match a tagged template not listed on argv.
    """
    load_templates()
    unmatched = 0
    failed = 0
    matchbox = {}
    for name in templates:
        regex = name_regex(templates[name])
        matchbox[name] = re.compile(regex)
    while True:
        line = sys.stdin.readline().strip()
        if line == "\l":
            print('# (eof) ')
            break
        if not line:
            print('# (blank line) ')
            break
        else:
            passed = []
            invalid = []
            for name in matchbox:
                match = matchbox[name].match(line)
                if match:
                    if not tags or name in tags:
                        passed.append(name)
                    else:
                        invalid.append(name)
            if not invalid:
                if not passed:
                    print("No match for", line)
                    unmatched += 1
                else:
                    print('OK', ','.join(passed), line)
            else:
                print('INVALID', ','.join(invalid), ','.join(passed), line)
                failed += 1
    if unmatched or failed:
        if not failed:
            print("# Errors: %i unmatched" % ( unmatched, ))
        elif not unmatched:
            print("# Errors: %i invalid" % ( failed ))
        else:
            print("# Errors: %i unmatched, %i invalid" % ( unmatched, failed ))
        return 4

### Readers/Writers

readers = dict(
        json=js.load,
        yaml=yaml_load
    )


def json_writer(data, file, opts):
    # XXX: SHOULD filter comments for proper JSON output, this program doesn't care
    kwds = {}
    if opts.flags.pretty:
        kwds.update(dict(indent=2))
    file.write(js.dumps(data, **kwds))

def yaml_writer(data, file, opts):
    kwds = {}
    if opts.flags.pretty:
        kwds.update(dict(default_flow_style=False))
    yaml_safe_dumps(data, file, **kwds)

writers = dict(
        json=json_writer,
        yaml=yaml_writer
    )



def c_version():
    global __version__
    return '%s' % __version__


cmd_aliases = dict(
    _h='help', __help='help',
    _v='version', __version='version'
)

if __name__ == '__main__':
    argv = sys.argv
    scriptname = argv.pop(0)

    if not len(argv):
        cmdname = 'c_show'
    else:
        cid = argv.pop(0).replace('-', '_')
        while cid in cmd_aliases:
            cid = cmd_aliases[cid]
        cmdname = 'c_'+cid
    load_vars()
    sys.exit(locals()[cmdname](*argv))
