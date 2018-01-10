# tasks-ignore-file
import unittest
import re

from nose_parameterized import parameterized

from script_mpe import confparse, radical
from script_mpe.radical import compile_rdc_matchbox, SEIParser, DEFAULT_TAGS, \
        find_tagged_comments, get_tagged_comment, get_lines, STD_COMMENT_SCAN,\
        at_line




class RadicalTestCase(unittest.TestCase):

    """
    Test some specific functions in radical module.
    """


    def setUp(self):
        self.rc = confparse.Values(dict(
            tags = DEFAULT_TAGS.keys(),
            tag_specs = DEFAULT_TAGS,
            ignored_tags = [],
            ignored_scans = {},
            comment_scan = STD_COMMENT_SCAN,
            comment_flavours = STD_COMMENT_SCAN.keys()
        ))
        radical.rc = self.rc
        self.mb = compile_rdc_matchbox(self.rc)


    @parameterized.expand([
        ( 1,  'FIXME', '  FIXME  ',             '  FIXME  ',        ),
        ( 2,  'XXX',   '  XXX  ',               '  XXX  ',          ),
        ( 3,  'TODO',  '  TODO  ',              '  TODO  ',         ),
        ( 4,  'BUG',   '  BUG  ',               '  BUG  ',          ),
        ( 5,  'NOTE',  '  NOTE  ',              '  NOTE  ',         ),
        ( 6,  'TEST',  '  TEST  ',              '  TEST  '          ),
        ( 7,  'XXX',   '-  XXX  -',             '  XXX  ',          ),
        ( 8,  'XXX',   '-  XXX:1ax0d  -',       '  XXX:1ax0d  ',    ),
        ( 9,  'XXX',   '-  XXX:_a:0d  -',       '  XXX:_a:0d  ',    ),
        ( 10, 'XXX',   '-  XXX:1ax 0d  -',      '  XXX:1ax ',       ),
        ( 11, 'XXX',   '-  XXX:1ax: 0d  -',     '  XXX:1ax: ',      ),
        ( 12, 'PRJ',   '-  PRJ-09af-2: Foo  -', '  PRJ-09af-2: ',   ),
        ( 13, 'FIXME', '_ FIXME_af09 _',        ' FIXME_af09 ',     ),
    ])
    def test_1_tag_regex(self, testnr, tag, source, expected):
        result = re.search(radical.DEFAULT_TAG_RE % tag, source)
        self.assert_(result, "No result for %s: %s" % ( testnr, tag) )
        matchgroups = result.groups()

        # VERIFY
        self.assertEquals( result.string, source,
                "Sanity check, Python failed?" )
        self.assertEquals( result.span(), ( result.start(), result.end() ),
                "Sanity check, Python failed?" )

        # TEST
        self.assertEquals( source[slice(*result.span())], expected,
            "Mismatch at #%i: '%s' should have matched '%s'" % ( testnr,
                source[slice(*result.span())], expected ))


    @parameterized.expand([
        ( 1, 'radical-test1.txt', [
          [ '<TagInstance FIXME radical-test1.txt#c107-115>', ' FIXME: '    ],
          [ '<TagInstance XXX radical-test1.txt#c161-169>',   ' XXX:2: '    ],
          [ '<TagInstance XXX radical-test1.txt#c405-410>',   ' XXX '     ],
          #[ '<TagInstance XXX radical-test1.txt#c405-412>',   ' XXX 7 '     ],
          [ '<TagInstance NOTE radical-test1.txt#c6-12>',     ' NOTE ' ],
          #[ '<TagInstance NOTE radical-test1.txt#c6-21>',     ' NOTE \n ' ],
          [ '<TagInstance NOTE radical-test1.txt#c291-298>',  ' NOTE: '     ],
          #[ '<TagInstance NOTE radical-test1.txt#c322-333>',  ' NOTE this ' ],
          [ '<TagInstance NOTE radical-test1.txt#c322-328>',  ' NOTE ' ],
          [ '<TagInstance TEST radical-test1.txt#c70-77>',    ' TEST: '     ],
          [ '<TagInstance TODO radical-test1.txt#c349-355>',  ' TODO '  ],
          #[ '<TagInstance TODO radical-test1.txt#c349-359>',  ' TODO 123 '  ],
          [ '<TagInstance TODO radical-test1.txt#c369-378>',  ' TODO-45 '   ],
          [ '<TagInstance TODO radical-test1.txt#c388-394>',  None          ],
          [ '<TagInstance TODO radical-test1.txt#c421-427>',  ' TODO '   ],
          #[ '<TagInstance TODO radical-test1.txt#c421-430>',  ' TODO 17 '   ],
        ] ),
        ( 2, 'test/var/radical-tasks-1.txt', [
          ( '<TagInstance TODO test/var/radical-tasks-1.txt#c2-9>', ' TODO: ' ),
        ] ),
        ( 3, 'test/var/radical-tasks-2.txt', [
          ( '<TagInstance FIXME test/var/radical-tasks-2.txt#c1-11>', ' FIXME:2: ' ),
        ] ),
        ( 4, 'test/var/radical-tasks-3.txt', [
          ( '<TagInstance TODO test/var/radical-tasks-3.txt#c2-9>', ' TODO: ' ),
          ( '<TagInstance TODO test/var/radical-tasks-3.txt#c68-75>', ' TODO: ' ),
        ] ),
        ( 5, 'test/var/radical-tasks-4.txt', [
          ( '<TagInstance TODO test/var/radical-tasks-4.txt#c2-9>', ' TODO: ' ),
          ( '<TagInstance TODO test/var/radical-tasks-4.txt#c457-464>', ' TODO: ' ),
          ( '<TagInstance TODO test/var/radical-tasks-4.txt#c523-530>', ' TODO: ' ),
          ( '<TagInstance TODO test/var/radical-tasks-4.txt#c773-780>', ' TODO: ' ),
        ] ),
    ])
    def test_2_SEIParser_find_tags(self, testnr, source, expected):
        """
        radical.SEIParser.find_tags
            - should return all expected TagInstances.
        """
        data = open(source).read()
        lines = data.split('\n')
        if lines[-1] == '':
            lines.pop()
        parser = SEIParser(None, self.mb, source, '', data, lines)
        tags = list(parser.find_tags(self.rc))
        for idx, ( tagrepr, result ) in enumerate(expected):
            self.assert_( str(tags[idx]) == expected[idx][0],
                    "%i: %s, %r not found" % ( idx, tags[idx],
                        tags[idx].raw(data) ) )
            exp = expected[idx][1]
            if exp:
                rs = data[slice(*tags[idx].char_span)]
                self.assertEquals( rs, exp,
                        "No match at %i: result %r vs. expected %r" % (
                            idx, rs, exp ) )
        self.assertEquals( len(tags), len(expected),
                "%i: Missing tag tests for %r, %i != %i " % (
                    idx, source, len(tags), len(expected) ) )


    @parameterized.expand([
        ( 1, 'radical-test1.txt', [
            ( '', (9, 10), (107, 138), '', '' ),
            ( '', (), (), '', '' ),
            ( '', (), (), '', '' ),
            ( '', (), (), '', '' ),
            ( '', (), (), '', '' ),
            ( '', (), (), '', '' ),
            ( '', (), (), '', '' ),
            ( '', (), (), '', '' ),
            ( '', (), (), '', '' ),
            ( '', (), (), '', '' ),
            ( '', (22, 23), (421, 435), 'TODO 17 baz \n', ' TODO 17 baz \n' ),
        ] ),
        ( 2, 'test/var/radical-tasks-1.txt', [
            ( '', (1, 1), (2, 66), '', '' ),
        ] ),
        ( 3, 'test/var/radical-tasks-2.txt', [
            ( '<EmbeddedIssue unix_generic 2-68 0-0>', ( 0, 0 ), ( 1, 68 ),
                'FIXME:2: Lorem ipsum dolor sit amet, consectetur adipiscing elit.\n',
                ' FIXME:2: Lorem ipsum dolor sit amet, consectetur adipiscing elit.\n' ),
        ] ),
        ( 4, 'test/var/radical-tasks-3.txt', [
            ( '<EmbeddedIssue unix_generic 3-66 1-1>', ( 1, 1 ), ( 2, 66 ), '',
                ' TODO: Lorem ipsum dolor sit amet, consectetur adipiscing elit.\n' ),
            ( '', (3, 6), (68, 148), '',
                # FIXME: scan comments properly?
                #'TODO: Lorem ipsum dolor sit amet, consectetur adipiscing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat.'
                ' TODO: Lorem ipsum dolor sit amet, consectetur adipiscing elit, sed do eiusmod \n' ),
        ] ),
        ( 5, 'test/var/radical-tasks-4.txt', [
            ( '<EmbeddedIssue unix_generic 3-81 1-1>', (), (2, 81), '',
                ' TODO: Lorem ipsum dolor sit amet, consectetur adipiscing elit, sed do eiusmod\n'
            ),
            ( '<EmbeddedIssue unix_generic 458-521 8-8>', (), (457, 521), '', '' ),
            ( '<EmbeddedIssue unix_generic 524-603 10-10>', (), (523, 603), '', '' ),
            ( '<EmbeddedIssue unix_generic 774-853 15-15>', (), (773, 853), '', '' ),
        ] ),
    ])
    def test_SEIParser_for_tag(self, testnr, source, expected):
        data = open(source).read()
        lines = data.split('\n')
        if lines[-1] == '':
            lines.pop()
        parser = SEIParser(None, self.mb, source, '', data, lines)
        tags = list(parser.find_tags(self.rc))
        for idx, ( ei_str, lspan, dspan, raw, descr ) in enumerate(expected):
            tag = tags[idx]
            try:
                ei = parser.for_tag(tag, self.mb, self.rc)
            except Exception, err:
                self.assert_(False, err)
            if ei_str:
                self.assertEquals( str(ei), ei_str,
                    "%i: %r vs. expected %r" % ( idx, str(ei), ei_str ) )
            if lspan:
                self.assertEquals( ei.comment_line_span, lspan,
                    "%i: %r vs. expected %r" % ( idx, ei.comment_line_span, lspan ) )
            if dspan:
                self.assertEquals( ei.description_span, dspan,
                    "%i: %r vs. expected %r" % ( idx, ei.description_span, dspan ) )
            if raw:
                self.assertEquals( ei.raw, raw,
                    "%i: %r vs. expected %r" % ( idx, ei.raw, raw ) )
            if descr:
                self.assertEquals( ei.descr, descr,
                    "%i: %r vs. expected %r" % ( idx, ei.descr, descr ) )
        self.assertEquals( len(tags), len(expected),
                "%i: Missing comment tests for %r, %i != %i " % (
                    idx, source, len(tags), len(expected) ) )


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
    def test_3_at_line(self, testnr, data, expected):
        "at_line returns line number and span for a given sub-line char span"
        lines = get_lines(data)
        pos = data.index('FOO')
        line_number, line_offset, line_width, linecnt = at_line(pos, 3, data, lines)
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
    def test_4_get_tagged_comment(self, testnr, data, expected):
        lines = get_lines(data)
        offset = data.index('TODO')
        width = 4
        tag_line, line_offset, line_width, linecnt = at_line(offset, width, data, lines)
        comment_flavour, char_span, descr_span, line_span = get_tagged_comment(
                offset, width, data, lines, self.rc.comment_flavours,
                self.rc.ignored_scans, self.mb)
        # Verify test (ever case should have same str result)
        self.assertEquals( data[slice(*expected[1])].strip('/*#\n'), ' TODO comment ' )
        # Actual tests
        self.assertEquals( comment_flavour, expected[0] )
        self.assertEquals( char_span, expected[1] )
        self.assertEquals( line_span, expected[2] )
        self.assertEquals( data[slice(*descr_span)].strip('\n '), 'TODO comment' )
        self.assertEquals( data[slice(*descr_span)].strip('/*\n '), 'TODO comment' )


    # XXX: old unittests, stubs

    @parameterized.expand([
        #( 1, 'radical-test1.txt', [
        #    ] )
    ])
    def test_find_tagged_comments(self, testnr, source, expected):
        data = open(source).read()
        comments = list(find_tagged_comments(source, self.mb, source, data))


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


def get_cases():
    return [
            RadicalTestCase
        ]


if __name__ == '__main__':
    unittest.main()
