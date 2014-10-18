import os
import sys

import jsonschema

from confparse import yaml_load
from taxus.init import get_session, extract_orm
from taxus.util import ORMMixin


def load_schema(path):
    path = path.replace('.', os.sep)+'.yml'
    meta = yaml_load(open(path))
    if '$schema' in meta:
        schema = yaml_load(open(meta['$schema']))
        jsonschema.validate(meta, schema)
    else:
        print >>sys.stderr, "No validation for", path
    #schema = extract_schema(meta)
    return list(extract_orm(meta))


#models = load_schema('taxus.core')
#models2 = load_schema('bookmarks')
models = load_schema('schema_test')

Base = models[0]
dbref = ORMMixin.assert_dbref('~/.schema-test.sqlite')
sa = get_session(dbref, True, metadata=Base.metadata)

#sa2 = get_session(dbref, metadata=Base.metadata)
#sa = ORMMixin.get_session('schema_test', dbref)




