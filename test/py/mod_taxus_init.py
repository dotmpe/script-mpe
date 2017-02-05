import os
import unittest
from datetime import datetime

from sqlalchemy.ext.declarative import declarative_base

from confparse import yaml_load
from taxus.init import extract_orm, get_session
from taxus.util import ORMMixin


def load_schema(path):
    path = path.replace('.', os.sep)+'.yml'
    try:
        meta = yaml_load(open(path))
    except Exception, e:
        print e
        raise Exception("Error loading %s from %s" % (path, os.getcwd()), e)
    #schema = extract_schema(meta)
    return list(extract_orm(meta))


class TestTaxusSchema(unittest.TestCase):

    prefix = '/tmp/'
    schema = None
    models = [ ]
    fields = {}

    def setUp(self):
        self.pwd = os.getcwd()

    def test_taxus_schema_basic_load(self):
        if not self.schema:
            return
        models = load_schema(self.schema)
        Base = models.pop(0)
        assert str(Base)[8:-2] == "sqlalchemy.ext.declarative.api.Base", str(Base)
        for idx, Model in enumerate(models):
            modname = self.models[idx]
            assert str(Model)[8:-2] == modname, Model
            for name in self.fields[modname]:
                table = Model.metadata.tables[Model.__tablename__]
                assert hasattr(Model, name) or name in table.c, (Model, name)

    def tearDown(self):
        assert self.pwd == os.getcwd(), (self.pwd, os.getcwd())


class TestTaxusInitBasic(TestTaxusSchema):

    schema = 'test.var.schema_test.basic'
    models = [ 'taxus.init.Basic' ]
    fields = {
        'taxus.init.Basic': [
            'name', 'label', 'date_added', 'deleted', 'date_deleted'
        ]
    }

    def test_taxus_schema_basic_commit(self):
        dbref = ORMMixin.assert_dbref(self.prefix+'taxus-schema-test.sqlite')

        models = load_schema(self.schema)
        Base = models[0]
        sa = get_session(dbref, True, metadata=Base.metadata)
        Basic = models[1]

        basic = Basic(
                name="Fist Basic record",
                label="basic 1",
                date_added=datetime.now()
            )
        sa.add(basic)
        sa.commit()

        SqlBase = declarative_base()
        sa2 = get_session(dbref, metadata=SqlBase.metadata)
        SqlBase.metadata.reflect()
        basics = SqlBase.metadata.tables['basics']
        rs = sa2.query(basics).all()
        assert len(rs) == 1
        r = rs[0]
        for attr in self.fields[self.models[0]]:
            assert hasattr(r, attr), r
            assert getattr(r, attr) == getattr(basic, attr)

        os.unlink(os.path.expanduser(self.prefix+'taxus-schema-test.sqlite'))


class TestTaxusInitExtends(TestTaxusSchema):

    schema = 'test.var.schema_test.extends'
    models = [ 'taxus.init.MyRecord', 'taxus.init.Extended' ]
    fields = {
        'taxus.init.MyRecord': [
            'r_id', 'name', 'label', 'date_added', 'deleted', 'date_deleted'
        ],
        'taxus.init.Extended': [
            'r_id', 'ext_id', 'name', 'description', 'label', 'date_added', 'deleted', 'date_deleted'
        ]
    }

    def test_taxus_schema_ext_commit(self):
        dbref = ORMMixin.assert_dbref(self.prefix+'taxus-schema-test.sqlite')

        models = load_schema(self.schema)
        Base, MyRecord, Extended = models

        sa = get_session(dbref, True, metadata=Base.metadata)

        basic = MyRecord(
                name="Fist Basic record",
                label="basic 1",
                date_added=datetime.now()
            )
        sa.add(basic)
        sa.commit()

        os.unlink(os.path.expanduser(self.prefix+'taxus-schema-test.sqlite'))


def get_cases():
    return [
        #TestTaxusInitBasic,
        #TestTaxusInitExtends
    ]

if __name__ == '__main__':
    unittest.main()

