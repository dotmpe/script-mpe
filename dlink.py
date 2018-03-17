#!/usr/bin/python
"""
:Created: 2011-03-29
:Updated: 2018-03-14

Double link.

 $ dlink link-target [link-source]

Create or update double symlink to target: one from this side directly to target,
and one back from remote basename plus numbered extension to local dir/name. Use
remote side's basename and CWD for local side if not given. No action if remote
side has existing backlink to given source dir or name.

Given the normal `ln` or `link` argument spec is::

 ln <src> [<trgt-dir>|<trgt-file>]

Then the equivalent `ln` invocations for `dlink` are::

 ln -s link-source link-target(.link.<n>)
 ln -s link-target link-source

"""

import sys, os


def main():
    args = list(sys.argv[1:])
    if '-h' in args or '--help' in args:
        print(__doc__)
        return
    return 1
"""TODO: refactor old dlink code
    cwd = os.getcwd()
    assert 0 < len(args) < 3
    link = None
    if len(args) == 2:
        link = args.pop()
    target = args.pop(0)
    if target[-1] == os.sep:
        target = target[:-1]
    backlink = target + '.link'
    count = 0
    while os.path.exists(backlink) or os.path.islink(backlink):
        assert os.path.islink(backlink), backlink
        count += 1
        backlink = "%s.%s.%i" % (target, 'link', count)
    assert not os.path.islink(backlink)
    if not link:
        link = os.path.join(cwd, os.path.basename(target))
    if not ( os.path.exists(link) or os.path.islink(link)):
        print(link, '->', target)
        #os.symlink(target, link)
    print(backlink, '->', link)
    os.symlink(link, backlink)
"""

if __name__ == '__main__':
    sys.exit(main())
