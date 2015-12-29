#!/usr/bin/env python
"""
matchbox - a (file)naming utility based on regular expressions.

A filename cleaning and reformatting utility.

Version 0.1 flow:
- Read input strings (filenames or any text lines) from standard-input.
- Loads BRE name/pattern pair definitions and  from .vars files. For example::

    match_EXT='[a-z0-9]\{2,5\}'
    match_NAMEPART='[A-Za-z_][A-Za-z0-9_,-]\{1,\}'

  These are Bourne Shell compatible script for interoperability.
- Match and parse using regular expressions build from named
  Basic Regular Expressions parts, arranged into a `name-template`,
  and compiled into a Py re::

    $ matchbox show_name_regex @NAMEPART.@EXT
    ^(?P<NAMEPART>[A-Za-z_][A-Za-z0-9_,-]{1,})\.(?P<EXT>[a-z0-9]{2,5})$

- Supplement parsed data (to add defaults, env values, etc.) for certain
  'special' tags (ie. filesize, encoding, format or content-type).

- Simply reorder 'tags' (the BRE match-group name) to rewrite names,
  adding, merging or removing tags. E.g.::

    $ matchbox rename @NAMEPART.@EXT @NAMEPART.old.@EXT < echo my-file.txt
    my-file.txt -> my-file.old.txt

    $ matchbox rename @NAMEPART.@EXT @SHA1_CKS-@NAMEPART-@SZ.@EXT < echo my-file.txt
    my-file.txt -> a8fdc205a9f19cc1c7507a60c4f01b13d11d7fd0-my-file-3.txt

Dev
- TODO: manage named BRE through subcmds, add some layer to deal with inherited
  and/or set-based name tags.

- TODO: add shell-program resolver, and subcmd to rm/add resolved tags+cmds.

"""
import sys
import os
import re


escape_meta_re = re.compile(r'(?!\\)([^\\A-Za-z0-9{}(),!@+_])')
name_var_match_re = re.compile('@([A-Z][A-Z0-9_]*)')

def name_template_opts(name_template):
    "Return place holders in name pattern"
    return [ varname for varname
            in name_var_match_re.findall(name_template) ]

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
        vartable[ varname ] = re.sub(r'\\([\(){}|])', r'\1',
                re.sub(r'^\\\((.*)\\\)\\\?$', r'\1', regexpat.strip("'")))

    print '# Loaded %s' % filepath

def load_templates(name='table.names'):
    homedir=os.path.expanduser('~/bin')
    load_names_from(os.path.join(homedir, name))
    cwd=os.getcwd()
    if cwd != homedir:
        load_names_from(os.path.join(cwd, name))

def load_names_from(filepath):
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
            print >>sys.stderr, "# Duplicate template %s" % tags
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
    name_regexpat = escape_meta_re.sub(r'\\\1', name_template)
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


# Main entry handlers
def c_show():
    print 'matchbox.py'

def c_name_regex(name_template):
    "Print regex pattern for given name template. "
    print name_regex(name_template)

def c_match_name_vars(name_template):
    """Read filenames from lines at std, extract fields by regex
    and output result line by line.
    The regex is build according to the name template,
    """
    var_names = name_template_opts(name_template)
    regex = name_regex(name_template, var_names)
    print "# Fields: '%s'" % ', '.join(var_names)
    print "# Compiled pattern to '%s'" % regex
    regex_r = re.compile(regex)
    while True:
        line = sys.stdin.readline().strip()
        if line == "\l":
            break
        if line:
            match = regex_r.match(line)
            if not match:
                print >> sys.stderr, "Mismatched '%s'" % line
            else:
                mdict = match.groupdict()
                print "\t".join([
                    mdict[var] if var in mdict else '' for var in var_names
                ])

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
    print "# Regex from: %s" % regex_from
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
            print '# (eof) '
            break
        if not line:
            print '# (blank line) '
        else:
            match = regex_from_r.match(line)
            if not match:
                print >> sys.stderr, "Mismatched '%s'" % line
                print "# (mismatched line '%s') " % line
                continue
            mdict = match.groupdict()
            if stat and exists:
                # TODO implement other resolvers than local fs
                if not os.path.exists(line):
                    print >> sys.stderr, "Cannot stat '%s'" % line
                    print "# (missing file '%s') " % line
                    continue
                resolve_seed(line, mdict, var_names_to)
            name_new = name_format(mdict, to_template, names=var_names_to)
            print line, name_new

def c_check_names(*tags):
    """Read filenames from stdin, check all name templates to see if at least one
    matches and print their tags. Optionally pass set of valid tags on argv,
    and fail for paths that match a tagged template not listed on argv.
    """
    load_templates()
    matchbox = {}
    for name in templates:
        regex = name_regex(templates[name])
        matchbox[name] = re.compile(regex)
    while True:
        line = sys.stdin.readline().strip()
        if line == "\l":
            print '# (eof) '
            break
        if not line:
            print '# (blank line) '
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
                    print "No match for", line
                else:
                    print 'OK', ','.join(passed), line
            else:
                print 'INVALID', ','.join(invalid), ','.join(passed), line


if __name__ == '__main__':
    argv = sys.argv
    scriptname = argv.pop(0)
    if not len(argv):
        cmdname = 'c_show'
    else:
        cmdname = 'c_'+argv.pop(0).replace('-', '_')
    load_vars()
    sys.exit(locals()[cmdname](*argv))

