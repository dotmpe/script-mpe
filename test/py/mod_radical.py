import unittest

from nose_parameterized import parameterized

from script_mpe import confparse, radical
from script_mpe.radical import compile_rdc_matchbox, Parser, DEFAULT_TAGS, \
        find_tagged_comments, get_tagged_comment, get_lines, STD_COMMENT_SCAN,\
        at_line




class RadicalTestCase(unittest.TestCase):

    """
    Test some specific functions in radical module.
    """


    def setUp(self):
        self.rc = confparse.Values(dict(
            tags = DEFAULT_TAGS,
            comment_scan = STD_COMMENT_SCAN,
            comment_flavours = STD_COMMENT_SCAN.keys()
        ))
        # FIXME: do away with global config in radical
        radical.rc = self.rc
        self.mb = compile_rdc_matchbox(self.rc)


    @parameterized.expand([
        ( 1, 'radical-test1.txt', [
          '<TagInstance NOTE radical-test1.txt#c7-12>',
          '<TagInstance TEST radical-test1.txt#c71-75>',
          '<TagInstance FIXME radical-test1.txt#c108-115>',
          '<TagInstance XXX radical-test1.txt#c162-167>',
          '<TagInstance NOTE radical-test1.txt#c292-298>',
          '<TagInstance NOTE radical-test1.txt#c323-328>',
          '<TagInstance TODO radical-test1.txt#c350-358>',
          '<TagInstance TODO radical-test1.txt#c370-377>',
          '<TagInstance TODO radical-test1.txt#c389-395>',
          '<TagInstance TODO radical-test1.txt#c406-412>',
          '<TagInstance TODO radical-test1.txt#c423-430>'
        ] ),
    ])
    def test_find_tags(self, testnr, source, expected):
        data = open(source).read()
        lines = data.split('\n')
        if lines[-1] == '':
            lines.pop()
        parser = Parser(None, self.mb, source, '', data, lines)
        tags = list(parser.find_tags())
        for tag in tags:
            self.assert_( str(tag) in expected, "%s not found" % tag )
        self.assertEquals( len(tags), 11 )


    @parameterized.expand([
        ( 1, 'radical-test1.txt', [
            ] )
    ])
    def test_find_tagged_comments(self, testnr, source, expected):
        data = open(source).read()
        #comments = list(find_tagged_comments(source, self.mb, source, data))

    # XXX: old unittest stubs
    #def setUp(self):
    #    self.dbref = '';
    #    self.session = radical.get_session(self.dbref)
    #
    #def test_000_main_argv(self):
    #    argv_tests = (
    #            'radical --help',
    #            'radical -h',
    #            'radical --version',
    #            'radical -V',
    #            'radical -F=+'
    #        )

    #def test_001_get_tagged_comment(self):
    #    radical.find(self.session, )

    #def test_002_at_line(self):
    #    radical.find(self.session, )

    #def test_003_find(self):
    #    radical.find(self.session, )


    @parameterized.expand([
        ( 1, 'FOO', ( 0, 0, 4 )),
        ( 2, '  FOO', ( 0, 0, 6 )),
        ( 3, "\nFOO", ( 1, 1, 4 )),
        ( 4, "\nFOO\n", ( 1, 1, 4 )),
        ( 5, "  \n  FOO\n", ( 1, 3, 6 )),
        ( 6, 'lkjlkj lkj\nfoo /** FOO comment */ bar\nqwiefn\n', ( 1,  11, 27 ) ),
        ( 7, '     \n/**\n FOO comment \n*/\n', (  2, 10, 14 ) ),
        ( 8, '// FOO comment', ( 0, 0, 15 ) ),
        ( 9, '# FOO comment', ( 0, 0, 14 ) ),
    ])
    def test_at_line(self, testnr, data, expected):
        "at_line returns line number and span for a given sub-line char span"
        lines = get_lines(data)
        pos = data.index('FOO')
        line_number, line_offset, line_width = at_line(pos, 3, data, lines)
        self.assertEquals( line_number, expected[0] )
        self.assertEquals( line_offset, expected[1] )
        self.assertEquals( line_width, expected[2] )


    @parameterized.expand([
        ( 1, '/** TODO comment */', ( 'c', (0, 19), (0, 0) ) ),
        ( 2, '/** TODO comment */\n', (  'c', (0, 19 ), (0, 0) ) ),
        ( 3, '     /** TODO comment */\n', (  'c', (5, 24), (0, 0) ) ),
        ( 4, 'lkj\nlkj lkj\nfoo /** TODO comment */ bar\nqwiefn\n', (  'c', (16, 35), (2, 2) ) ),
        ( 5, 'lkjlkj lkj\nfoo /** TODO comment */ bar\nqwiefn\n', (  'c', (15, 34), (1, 1) ) ),
        ( 6, '     \n/**\n TODO comment \n*/\n', (  'c', (6, 27 ), (1, 3) ) ),

        ( 7, '// TODO comment ', ( 'c_line', (0, 17), (0, 0) ) ),
        ( 8, '# TODO comment ', ( 'unix_generic', ( 0, 16 ), ( 0, 0 ) ) ),
        ( 9, 'asdf\nfdsa\n// TODO comment \nfoo', ( 'c_line', (10, 27), (2, 2) ) ),
        ( 10, 'asdf fdsa // TODO comment \nfoo', ( 'c_line', (10, 27), (0, 0) ) ),
        #( 11, '// asdf fdsa TODO comment \nfoo', ( 'c_line', (12, 27), (0, 0) ) ),
        #( 11, 'asdf\nfdsa\n// TODO comment \n// foo', ( 'c_line', (10, 32), (2, 3) ) ),
    ])
    def test_get_tagged_comment(self, testnr, data, expected):
        lines = get_lines(data)
        offset = data.index('TODO')
        width = 4
        tag_line, line_offset, line_width = at_line(offset, width, data, lines)
        comment_flavour, char_span, descr_span, line_span = get_tagged_comment(
                offset, width, data, lines, self.rc.comment_flavours, self.mb)
        # Verify test
        self.assertEquals( data[slice(*expected[1])].strip('/*#\n'), ' TODO comment ' )
        # Actual tests
        self.assertEquals( comment_flavour, expected[0] )
        self.assertEquals( char_span, expected[1] )
        self.assertEquals( line_span, expected[2] )
        self.assertEquals( data[slice(*descr_span)].strip('\n '), 'TODO comment' )
        self.assertEquals( data[slice(*descr_span)].strip('/*\n '), 'TODO comment' )


def get_cases():
    return [
            RadicalTestCase
        ]


if __name__ == '__main__':
    unittest.main()

