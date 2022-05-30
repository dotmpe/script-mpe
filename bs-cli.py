#!/usr/bin/env python3
"""BeautifulSoup xpath
"""
import os, sys, html5lib, requests
from bs4 import BeautifulSoup
from lxml import etree


args = sys.argv[:]
script = args.pop(0)
if len(args) > 0:
    if args[0] in ("-h", "--help", "--version", "-V", "help"):
        print(__doc__)
        sys.exit()

HEADERS = ({'User-Agent':
            'Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 \
            (KHTML, like Gecko) Chrome/44.0.2403.157 Safari/537.36',\
            'Accept-Language': 'en-US, en;q=0.5'})

if args[0] == 'xpath':
    XPATH = args[1]
    URLS = args[2:]

    for arg in args[2:]:
        if arg == '-':
            content = sys.stdin.read()
        elif os.path.exists(arg):
            content = sys.stdin.read()
        else:
            content = requests.get(URL, headers=HEADERS).content

        soup = BeautifulSoup(content, "html.parser")

        dom = etree.HTML(str(soup))

        el = dom.xpath(XPATH)[0]

        #etree.dump(el)
        sys.stdout.buffer.write(etree.tostring(el))

else:
    sys.exit(1)
