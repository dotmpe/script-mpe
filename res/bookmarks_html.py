import os
import sys

import BeautifulSoup

from script_mpe import res


def parse_json(data):
    """
    Complex object with tree organiation and bookmark cards.
    """
    return res.json_read

def parse_html(data):
    """
    A `definition-list` with hyperlinks for terms
    with custom attributes for bookmark properties, 
    and bookmark description for definition. 
    """
    soup = BeautifulSoup(data)
    return soup

def parse(path):
    
    fname = os.path.basename(path)
    ext = os.path.splitext(fname)

    data = open(fname).read()

    funcname = 'parse_'+ext
    if funcname in sys.modules[__name__]:
        return getattr(sys.modules[__name__], funcname)(data)

