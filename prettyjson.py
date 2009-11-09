#!/usr/bin/env python
import sys, pprint, json


data = json.loads(open(sys.argv[1]).read())

pprint.pprint(data)
