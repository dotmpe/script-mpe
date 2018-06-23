#!/usr/bin/env python
"""

2018-06-23
    Adapted from M. Simionato <E-mail: mis6@pitt.edu>, 2003

License: Python-like
"""

import os, itertools

from braceexpand import braceexpand
from docutils.nodes import *

from script_mpe.res.py import if_, MRO, MROgraph, testHierarchy



def du_test():
    class Node_(Node, object): pass
    docnodes = (
            Node_, Text, Element, TextElement, FixedTextElement,
            # Mixins
            #Resolvable, BackLinkable,
            ## Element categories
            #Root, Titular, PreBibliographic, Invisible, Bibliographic, Structural, Body,
            #General, Sequential, Admonition, Special,

            #document,
            #title, subtitle, rubric,

            #emphasis, strong, literal, reference, footnote_reference, citation_reference, substitution_reference, title_reference, abbreviation, acronym, superscript, subscript,
            #image,
            #inline, problematic, generated
    )
    MROgraph(*docnodes)

_load_class = {}
def load_class_by_refstr(refstr):
    package, module, name = refstr.split(':')
    pikey = "%s.%s" % (package, module)
    if pikey not in _load_class:
        mod = __import__(pikey, fromlist=[package])
        _load_class[pikey] = mod
    else:
        mod = _load_class[pikey]
    return getattr(mod, name)

def main(*args):
    classes = []
    for classref_spec in itertools.chain(*[ braceexpand(a) for a in  args ]):
        classes.append(load_class_by_refstr(classref_spec))

    print(classes)
    MROgraph(*classes, filename='py-MRO-graph.png')


if __name__=="__main__":
    args = sys.argv[1:]
    if '-h' in args:
        print(__doc__)
        sys.exit(0)

    elif '--du-test' in args:
        du_test();
        sys.exit(0)

    sys.exit(main(*args))

# vim:et:
