"""
:created: 2014-10-19

Schema to ORM.
Somewhat JSON schema compatible.
"""
from __future__ import print_function
import os
import sys

import jsonschema

from confparse import yaml_load
from taxus.init import get_session, extract_orm
from taxus.util import ORMMixin


def load_schema(path):
    path = path.replace('.', os.sep)+'.yml'
    yml_meta = yaml_load(open(path))
    if '$schema' in yml_meta:
        schema = yaml_load(open(yml_meta['$schema']))
        jsonschema.validate(yml_meta, schema)
    else:
        print("No validation for", path, file=sys.stderr)
    print('Schema loaded:', path, file=sys.stderr)
    #schema = extract_schema(yml_meta)
    return list(extract_orm(yml_meta))


#models = load_schema('taxus.core')
#models2 = load_schema('bookmarks')
models = load_schema('schema_test')
print(models)

#Base, MyRecord, Extended = models

dbref = ORMMixin.assert_dbref('~/.schema-test.sqlite')
#sa = get_session(dbref, True, metadata=Base.metadata)

#sa2 = get_session(dbref, metadata=Base.metadata)
#sa = ORMMixin.get_session('schema_test', dbref)
