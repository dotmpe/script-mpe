#!/usr/bin/env  python
"""
:created: 2017-05-06
"""
__description__ = "magnet - "
__version__ = '0.0.4-dev' # script-mpe
__usage__= """
Usage:
    magnet.py [options] [ FILE | URI ] [ LIST ] [ --mt=MT... ] [ [ XS | AS | DN | XT ]... ]
        [ --no-dn | [ --no-add-dn ] --dn=DN... ]
        [ --no-uri ]
        [ --no-xs | [ --no-add-xs ] --xs=XS... ]
        [ --as=AS ]
        [ --no-xt | [ --no-add-xt ] [ --xt-type=XTC... ] --xt=XT... ]
        [ --no-xl ]
        [ --no-be ]

Options:
    --mt-type=FMT
                  Explicitly provide format for MT locator or name.
    --output-format=FMT
                  Format to apply to stdout printing (unless quiet).
    --verbose     ..
    --quiet       ..
    -h --help     Show this usage description.
                  For a command and argument description use the command 'help'.
    --version     Show version (%s).


Dereference content at URI, and create `magnet:` URI. Ouput the URI to stdout,
or append it to a file.

The generic arg. seq. is:

FILE | URI
    1. locator to primary content
LIST
    2. context to primary, a container locator. Like .rss, .magma.
XS | AS
    3. additional exact or acceptable names
DN
    If not given, the basename of file, or content-disposition or basename of
    URI path is used for display name ``dn``. Unless ``--no-dn`` is set.
    Using the default can also be prevented by using ``--dn``, or by allowing
    additional arguments to be local names (like file paths or basenames)
    (ie. no ``--no-add-dn`` passed).

With magnets, a topic refers to a tag or metadata value more or less indicating
a particular resource. Or set of resources maybe. While a source is a locator
in the form of a regular http, or perhaps some P2P link. But other attributes
like 'kt' and 'tr' can also provide for some baseline for retrieval of the
primary resource indicated.

Generally the difference of a XS vs. a XT is not clear to me currently. It
depends on the scheme of xs or as perhaps also. But that of XT generally is some
kind of content hashing scheme. In any case, according the the [WP]_ table, MT
seems to be both URN or URL, while XX/AS are http/ftp/dchub scheme (ie. URL of
sorts), and XT is exclusively URN.

Arguments are parsed as a complete and final array, iow. options can follow
arguments.

--mt=MT
    The manifest-topic property can link to manifests. It can be a http or
    urn:sha1 for example, and the resource it points at is to be used to provide
    a context for the subject. Which would usually be a simple list, and/or
    provide additional information about the subject resource. Like an outline?
    Or home document.

    TODO: should support (somewhat) .magma, .list (todo.txt compat) and maybe
    .rss and/or .rst, .md, wiki also.

--no-uri
    Disables validating the primary locator for some reason. Also causes it
    to use local absolute or relative paths as-is.

--as=...

--no-xs
    Normally additional names are used as XS refs. Passing this option causes
    them to be set as AS refs instead.
    With option argument, that value is used for such ref. Multiple occurences
    allowed.

    Acceptable sources can be used for see-also, or possible xt/same-as refs.

--xs=XS
    Exact sources list alternatives to the primary locator. XS refs can be
    passed as additional arguments, if a ``--mt`` or ``LIST`` (empty or not)
    is provided first and ``--as`` is not present. Otherwise use this option.

--xt=XT
    Sets an exact topic. This usually is a URN for checksum type of indicator
    for a stream or hashable (local file, http entity etc.). Multiple arguments
    required.

--no-dn
    Prevents adding dn. Iow. do not set default, and ignore given ``--dn`` or
    DN from AS/XS. See also *DN*.

--no-add-dn
    Prevents filtering of DN from AS/XS args. This does not affect the
    ``--no-dn`` setting, but only disables the validation for AS/XS args.
    Allows to keep values that do not look like URN still as AS/XS refs,
    see also ``--no-uri``.

--no-xl
    Prevents adding the exact length property `xl`.

Done:
    | W.o. ``--mt``, second arg is the list.
    |

TODO:
Any further arg is either AS, XS, XT or DN.
AS or XS is URIRef compatible. W.o. ``--no-dn``
Print simple keys, but add index number for multiple occurences (not sure as to
standard, but this should work better with simple to-dict parsing).
W.o. ``--no-be`` does not try to invoke a save-to-context for the generated
magnet. Otherwise open files and add the generated magnet as a reference.

""" % ( __version__, )
from datetime import datetime
import os
import re
import hashlib

import uriref
import script_util


def cmd_magnet_rw(FILE, URI, LIST, DN, XS, AS, XT, opts, settings):
    """
    """

    # Process arguments
    if uriref.scheme.match(FILE):
        URI = FILE
        FILE = None
    ARGS_ =  XS + AS + DN + XT
    XS, AS, DN, XT = [], [], [], []
    REFS_, TOPICS_ = [], []
    if opts.flags.mt:
        if LIST:
            ARGS_ = [ LIST ] + ARGS_
        LIST = opts.flags.mt
    if opts.flags['dn']:
        DN += opts.flags['dn']
    if opts.flags['as']:
        AS += opts.flags['as']
    if opts.flags['xs']:
        XS += opts.flags['xs']
    if opts.flags['xt']:
        XT += opts.flags['xt']
    if not opts.flags.no_add_dn:
        for a in ARGS_:
            m = uriref.absoluteURI.match(a)
            if m:
                if a.startswith('urn:'):
                    TOPICS_.append(a)
                else:
                    REFS_.append(a)
            else:
                DN.append(a)
    if not opts.flags.no_add_xt:
        XT += TOPICS_
    if not opts.flags.no_add_xs:
        XS += REFS_
    else:
        AS += REFS_
    if not opts.flags.no_uri:
        if not URI:
            URI = 'file:///'+FILE
        uriref.URIRef(URI)
    #print 'FILE', FILE
    #print 'URI', URI
    #print 'LIST', LIST
    #print 'DN', DN
    #print 'XS', XS
    #print 'AS', AS
    #print 'XT', XT

    # Create magnet URI

    # Output



### Transform cmd_ function names to nested dict

commands = script_util.get_cmd_handlers_2(globals(), 'cmd_')
commands['help'] = script_util.cmd_help


### Util functions to run above functions from cmdline

def main(opts):

    """
    Execute using docopt-mpe options.
    """

    settings = opts.flags
    opts.default = 'magnet-rw'
    opts.flags.verbose = not opts.flags.quiet
    return script_util.run_commands(commands, settings, opts)

def get_version():
    return 'magnet/%s' % __version__

if __name__ == '__main__':
    import sys
    reload(sys)
    sys.setdefaultencoding('utf-8')
    opts = script_util.get_opts(__doc__ + __usage__, version=get_version())
    sys.exit(main(opts))
