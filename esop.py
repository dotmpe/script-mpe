"""
:Created: 2016-08-28

- Specification is nested definitions with test cases;
  terms a are (sub)components, TODO: test items are script lines from literal or
  line-blocks.

- TODO: Components (or parts) can be numbered.

- TODO: Path Ids are created for each component. Can be mapped to script names.
  Test case

- Directives, roles, field lists could be used for parametrization maybe?
  But.. why.

"""
from __future__ import print_function

try:
    import locale
    locale.setlocale(locale.LC_ALL, '')
except:
    pass

from docutils.core import publish_doctree
from docutils import nodes


class TestSpecVisitor(nodes.SparseNodeVisitor):
    """
    TODO: Reduce tree to nested k/v pairs
    TODO: Format values
    """
    def __init__(self, doc, store):
        nodes.SparseNodeVisitor.__init__(self, doc)
        self.store = store

    def apply(self):
        self.document.walkabout(self)

    def visit_term(self, node):
        print("Term %r" % ( node ))

    def visit_definition(self, node):
        print("Definition %r" % ( node ))


class TestSpecNode:
    """
    """
    def __init__(self):
        pass


if __name__ == '__main__':
    fn = '/srv/project-local/script-mpe/test/pd-spec.rst'
    #fn = '/srv/project-local/script-mpe/test/var/esop/1-simple-spec.rst'
    source = open(fn).read()

    doctree = publish_doctree(source, source_path=fn,
        reader=None, reader_name='standalone',
        parser=None, parser_name='restructuredtext',
        settings=None, settings_spec=None, settings_overrides=None, config_section=None,
        enable_exit_status=False)

    v = DefinitionVisitor(doctree, {})
    v.apply()

    print("Store %s" % ( v.store, ))

