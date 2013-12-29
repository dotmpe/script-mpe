#!/usr/bin/env python
import sys, pprint

import res.js


data = res.js.loads(open(sys.argv[1]).read())

pprint.pprint(data)
