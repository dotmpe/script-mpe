import unittest
import re

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
        # Select a commented line
        ( 1, 'restructuredtext', '\n\n.. Foo\n\n', 2 ),
        # Negate possible directives
        ( 2, 'restructuredtext', '\n\n.. include: Foo\n\n', None ),
    ])
    def test_1_1_comment_scan(self, testnr, flavour, source, expected):
        """1.1 some comment-scan regexes do what is expected"""
        result = re.search(radical.STD_COMMENT_SCAN[flavour][0], source)
        if expected == None:
            self.assert_(result == None, "Expected no match at %i, %s" % (
                testnr, flavour ) )
        else:
            self.assert_(result, "No result for %i, %s" % ( testnr, flavour ) )
            self.assertEquals(result.start(), expected,
                "Offset mismatch, expected %i. Result: %i" % (
                    expected, result.start() ) )

    @parameterized.expand([
        ( 1,  'FIXME', '  FIXME  ',             '  FIXME  ',        ), # tasks:no-check
        ( 2,  'XXX',   '  XXX  ',               '  XXX  ',          ), # tasks:no-check
        ( 3,  'TODO',  '  TODO  ',              '  TODO  ',         ), # tasks:no-check
        ( 4,  'BUG',   '  BUG  ',               '  BUG  ',          ), # tasks:no-check
        ( 5,  'NOTE',  '  NOTE  ',              '  NOTE  ',         ), # tasks:no-check
        ( 6,  'TEST',  '  TEST  ',              '  TEST  '          ), # tasks:no-check
        ( 7,  'XXX',   '-  XXX  -',             '  XXX  ',          ), # tasks:no-check
        ( 8,  'XXX',   '-  XXX:1ax0d  -',       '  XXX:1ax0d  ',    ), # tasks:no-check
        ( 9,  'XXX',   '-  XXX:_a:0d  -',       '  XXX:_a:0d  ',    ), # tasks:no-check
        ( 10, 'XXX',   '-  XXX:1ax 0d  -',      '  XXX:1ax ',       ), # tasks:no-check
        ( 11, 'XXX',   '-  XXX:1ax: 0d  -',     '  XXX:1ax: ',      ), # tasks:no-check
        ( 12, 'PRJ',   '-  PRJ-09af-2: Foo  -', '  PRJ-09af-2: ',   ), # tasks:no-check
        ( 13, 'FIXME', '_ FIXME_af09 _',        ' FIXME_af09 ',     ), # tasks:no-check
    ])
    def test_1_2_tag_regex(self, testnr, tag, source, expected):
        """1.2 Tag regex does what is expected"""
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
        ( 1, 'test/var/nix_comments.txt', 0, (
            0, 18, 45, 72, 99, 100, 125, 126, 147, 168, 169, 185, 186
        ) ),
    ])
    def test_5_1_SrcDoc_line_dsp(self, testnr, source, start, expected):
        """5.1 SrcDoc gives char-offset for all lines"""
        tname=self.id().replace(__name__, '').strip('.')
        srcdoc = radical.SrcDoc( source )
        for idx, exp_dsp in enumerate(expected):
            dsp = srcdoc.line_dsp(idx)
            self.assertEquals( dsp, exp_dsp,
                    "%s: %r vs. expected %r" % (tname, dsp, exp_dsp))
        self.assertEquals(len(srcdoc.lines), len(expected))

    @parameterized.expand([
        ( 1, 'test/var/nix_comments.txt', 0, (
            17, 26, 26, 26, 0, 24, 0, 20, 20, 0, 15, 0, 13
        ) ),
    ])
    def test_5_2_SrcDoc_line_wid(self, testnr, source, start, expected):
        """5.2 SrcDoc gives char-width for all lines"""
        tname=self.id().replace(__name__, '').strip('.')
        srcdoc = radical.SrcDoc( source )
        for idx, exp_wid in enumerate(expected):
            wid = srcdoc.line_wid(idx)
            self.assertEquals( wid, exp_wid,
                    "%s: %r vs. expected %r" % (tname, wid, exp_wid))
        self.assertEquals(len(srcdoc.lines), len(expected))

    @parameterized.expand([
        ( 1, 'test/var/nix_comments.txt', 200, [
            ( 0, 0, 17, 17 ),
            ( 1, 18, 26, 44 ),
            ( 2, 45, 26, 71 ),
            ( 3, 72, 26, 98 ),
            ( 12, 186, 13, 199 ),
        ]),
    ])
    def test_5_3_SrcDoc_line_char_range_and_span(self, testnr, source, flen, expected):
        """5.3 SrcDoc maps line to char-range or span"""
        srcdoc = radical.SrcDoc( source )
        for line, dsp, wid, end in expected:
            cspan = srcdoc.line_char_span(line)
            self.assertEquals(cspan, (dsp, wid))
            crange = srcdoc.line_char_range(line)
            self.assertEquals(crange, (dsp, end))
        self.assertEquals(flen, len(srcdoc.data))



    @parameterized.expand([
        ( 1, 'radical-test1.txt', [
          [ '<TagInstance FIXME radical-test1.txt#c107-115>', ' FIXME: '    ], # tasks:no-check
          [ '<TagInstance XXX radical-test1.txt#c161-169>',   ' XXX:2: '    ], # tasks:no-check
          [ '<TagInstance XXX radical-test1.txt#c405-412>',   ' XXX 7 '     ], # tasks:no-check
          [ '<TagInstance NOTE radical-test1.txt#c6-21>',     ' NOTE Comment\n ' ], # tasks:no-check
          [ '<TagInstance NOTE radical-test1.txt#c291-298>',  ' NOTE: '     ], # tasks:no-check
          [ '<TagInstance NOTE radical-test1.txt#c322-333>',  ' NOTE this ' ], # tasks:no-check
          [ '<TagInstance TEST radical-test1.txt#c70-77>',    ' TEST: '     ], # tasks:no-check
          [ '<TagInstance TODO radical-test1.txt#c349-359>',  ' TODO 123 '  ], # tasks:no-check
          [ '<TagInstance TODO radical-test1.txt#c369-378>',  ' TODO-45 '   ], # tasks:no-check
          [ '<TagInstance TODO radical-test1.txt#c388-396>',  None          ], # tasks:no-check
          [ '<TagInstance TODO radical-test1.txt#c421-430>',  ' TODO 17 '   ], # tasks:no-check
        ] ),
        ( 2, 'test/var/radical-tasks-1.txt', [
          ( '<TagInstance TODO test/var/radical-tasks-1.txt#c2-9>', ' TODO: ' ), # tasks:no-check
        ] ),
        ( 3, 'test/var/radical-tasks-2.txt', [
          ( '<TagInstance FIXME test/var/radical-tasks-2.txt#c1-11>', ' FIXME:2: ' ), # tasks:no-check
        ] ),
        ( 4, 'test/var/radical-tasks-3.txt', [
          ( '<TagInstance TODO test/var/radical-tasks-3.txt#c2-9>', ' TODO: ' ), # tasks:no-check
          ( '<TagInstance TODO test/var/radical-tasks-3.txt#c68-75>', ' TODO: ' ), # tasks:no-check
        ] ),
        ( 5, 'test/var/radical-tasks-4.txt', [
          ( '<TagInstance TODO test/var/radical-tasks-4.txt#c2-9>', ' TODO: ' ), # tasks:no-check
          ( '<TagInstance TODO test/var/radical-tasks-4.txt#c457-464>', ' TODO: ' ), # tasks:no-check
          ( '<TagInstance TODO test/var/radical-tasks-4.txt#c523-530>', ' TODO: ' ), # tasks:no-check
          ( '<TagInstance TODO test/var/radical-tasks-4.txt#c773-780>', ' TODO: ' ), # tasks:no-check
        ] ),
    ])
    def test_2_1_Parser_find_tags(self, testnr, source, expected):
        """2.1 Parser find-tags returns TagInstances """

        parser = Parser(None, self.mb, source, '')
        tags = list(parser.find_tags())
        for idx, ( tagrepr, result ) in enumerate(expected):
            self.assert_( str(tags[idx]) == expected[idx][0], "%i: %s not found" % (
                idx, tags[idx] ) )
            exp = expected[idx][1]
            if exp:
                rs = parser.srcdoc.data[slice(*tags[idx].char_span)]
                self.assertEquals( rs, exp,
                        "No match at %i: result %r vs. expected %r" % (idx, rs, exp ) )
        self.assertEquals( len(tags), len(expected),
                "%i: Missing tag tests for %r, %i != %i " % (
                    idx, source, len(tags), len(expected) ) )

    @parameterized.expand([
        ( 1, 'test/var/nix_comments.txt', -1, (
            # Expected:
            # 1:flavour+comment-lines, 2:comment-char-spans
            ('unix_generic', (1,3)), [
                (18,44), (45,71), (72,98) ],
            # 3:comment-text
            [ '# Header comment lines 1/3',
              '# Header comment lines 2/3',
              '# Header comment lines 3/3' ]
        ) ),
        ( 2, 'radical-test1.txt', -1, (
            ('c', (0,4)), [
                (0, 3), (4, 19), (20, 39), (40, 51), (52, 55)
            ], [ ], ) ),
        ( 3, 'radical-test1.txt', -1, (
            ('unix_generic', (7,7)), [
            ], [ ], ) ),
        ( 4, 'radical-test1.txt', 7, (
            ('unix_generic', (12,13)), [
                #(160, 245)
                (160, 195), (196, 245)
            ], [
                '# XXX:2: another unix-style comment', # tasks:no-check
                '#     runs two lines also. And has two sentences.'
            ], ) ),
        ( 5, 'test/var/radical-tasks-1.txt', -1, ( ('unix_generic', (1,1)), (), ) ),
        ( 6, 'test/var/radical-tasks-2.txt', -1, ( ('unix_generic', (0,0)), (), ) ),
        ( 7, 'test/var/radical-tasks-4.txt', -1, ( ('unix_generic', (1,1)), (), ) ),
        ( 8, 'test/var/c_header-1.txt', -1, ( ('c', (0,2)), (), ) ),
        ( 9, 'test/var/c_header-2.txt', -1, ( ('c', (0,0)), (), ) ),
    ])
    def test_2_2_Parser_find_comment(self, testnr, source, start, expected):
        """2.2 Parser find-comment returns comment ranges (lines or chars)"""

        tname=self.id().replace(__name__, '').strip('.')
        prsr = Parser('', self.mb, source, '<unittest>')
        srcdoc = prsr.srcdoc
        cmnt_spec = radical.find_comment_start_after(start, srcdoc.data,
                srcdoc.lines, [ expected[0][0] ], self.mb)
        self.assert_(cmnt_spec)
        flavour, cmnt_start_line = cmnt_spec
        self.assertLessEqual(start, cmnt_start_line)
        self.assertEquals( expected[0][1][0], cmnt_start_line )
        self.assertEquals( expected[0][0], flavour )
        cmnt_range = radical.find_comment(start, srcdoc.data, srcdoc.lines,
                [ flavour ], self.mb )
        self.assertEquals( expected[0], cmnt_range )
        if not expected[1]:
            return
        if expected[2]:
            # Verify test-file and test-case numbers by expected string values
            for idx, value in enumerate(expected[2]):
                self.assertEquals( srcdoc.data[slice(*expected[1][idx])], value )
        cmnt_char_spans = prsr.find_comment(flavours=[expected[0][0]], from_line=start)
        self.assertEquals( expected[1] , cmnt_char_spans )

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
            ( '', (22, 23), (421, 435), 'TODO 17 baz \n', ' TODO 17 baz \n' ), # tasks:no-check
        ] ),
        ( 2, 'test/var/radical-tasks-1.txt', [
            ( '', (1, 1), (2, 66), '', '' ),
        ] ),
        ( 3, 'test/var/radical-tasks-2.txt', [
            ( '<EmbeddedIssue unix_generic 2-67 0-0>', ( 0, 0 ), ( 1, 68 ),
                'FIXME:2: Lorem ipsum dolor sit amet, consectetur adipiscing elit.', # tasks:no-check
                ' FIXME:2: Lorem ipsum dolor sit amet, consectetur adipiscing elit.\n' ), # tasks:no-check
        ] ),
        ( 4, 'test/var/radical-tasks-3.txt', [
            ( '<EmbeddedIssue unix_generic 3-65 1-1>', ( 1, 1 ), ( 2, 66 ), '',
                ' TODO: Lorem ipsum dolor sit amet, consectetur adipiscing elit.\n' ), # tasks:no-check
            ( '', (3, 6), (68, 148), '',
                # FIXME: scan comments properly?
                #'TODO: Lorem ipsum dolor sit amet, consectetur adipiscing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat.'
                ' TODO: Lorem ipsum dolor sit amet, consectetur adipiscing elit, sed do eiusmod \n' ), # tasks:no-check
        ] ),
        ( 5, 'test/var/radical-tasks-4.txt', [
            ( '<EmbeddedIssue unix_generic 3-80 1-1>', (), (2, 81), '',
                ' TODO: Lorem ipsum dolor sit amet, consectetur adipiscing elit, sed do eiusmod' # tasks:no-check
            ),
            ( '<EmbeddedIssue unix_generic 458-520 8-8>', (), (457, 521), '', '' ),
            ( '<EmbeddedIssue unix_generic 524-602 10-10>', (), (523, 603), '', '' ),
            ( '<EmbeddedIssue unix_generic 774-852 15-15>', (), (773, 853), '', '' ),
        ] ),
    ])
    def test_2_3_Parser_for_tag(self, testnr, source, expected):
        """2.3 Parser for-tag returns embedded issues"""

        tname=self.id().replace(__name__, '').strip('.')
        parser = Parser(None, self.mb, source, '')
        tags = list(parser.find_tags())
        for idx, ( ei_str, lspan, dspan, raw, descr ) in enumerate(expected):
            tag = tags[idx]
            try:
                ei = parser.for_tag(tag)
            except Exception, err:
                self.assert_(False, "%i: error for %s: %s" % ( testnr, tag, err))
            if not ei:
                continue
                # XXX:
                self.assert_( ei, "Expected comment at %i: %i: for %r" % (testnr, idx, tag))
            if ei_str:
                self.assertEquals( str(ei), ei_str,
                    "%i: %r vs. expected %r" % ( idx, str(ei), ei_str ) )
            if lspan:
                self.assertEquals( ei.comment_line_span, lspan,
                    "%i: %r vs. expected %r\n<<<< result %s %i\n%r\n====\n%r\n>>>> expected %s %i" % (
                        idx, ei.comment_line_span, lspan,
                        tname, idx,
                        '\n'.join(parser.srcdoc.lines[slice(*ei.comment_line_span)]),
                        '\n'.join(parser.srcdoc.lines[slice(*lspan)]),
                        tname, idx
                    ) )
            if dspan:
                pass
                # FIXME self.assertEquals( ei.description_span, dspan,
                #    "%i: %r vs. expected %r" % ( idx, ei.description_span, dspan ) )
            if raw:
                self.assertEquals( ei.raw, raw,
                    "%i: %r vs. expected %r" % ( idx, ei.raw, raw ) )
            # TODO: ei.description
            #if descr:
            #    self.assertEquals( ei.descr, descr,
            #        "%i: %r vs. expected %r" % ( idx, ei.descr, descr ) )
        self.assertEquals( len(tags), len(expected),
                "%i: Missing comment tests for %r, %i != %i " % (
                    idx, source, len(tags), len(expected) ) )

    @parameterized.expand([
        ( 1, 'radical-test1.txt', 11, [
        ] ),
        ( 3, 'test/var/radical-tasks-2.txt', 1, [
        ] ),
        ( 5, 'test/var/radical-tasks-4.txt', 4, [
        ] ),
    ])
    def test_6_1_tag_formats(self, testnr, source, tagcnt, expected):
        """6.1 Format tag to string, embedded issues to multiple formats"""
        prsr = Parser(None, self.mb, source, '')
        tags = list(prsr.find_tags())
        self.assertEquals(len(tags), tagcnt)
        for tag in tags:
            self.assert_(str(tag))
            ei = prsr.for_tag(tag)
            if not ei:
                continue
            for pf, cb in radical.EmbeddedIssue.formats.items():
                # Just test the callback has no exceptions
                self.assert_(cb(ei, prsr.srcdoc.data), "%i %s: %s"%(testnr,
                    source, pf))



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
        "3. at_line returns line number and span for a given sub-line char span"
        lines = get_lines(data)
        pos = data.index('FOO')
        line_number, line_offset, line_width = at_line(pos, 3, data, lines)
        self.assertEquals( line_number, expected[0] )
        self.assertEquals( line_offset, expected[1] )
        self.assertEquals( line_width, expected[2] )



    def test_4_1_1_1_get_tagged_comment(self):
        """4.1.1.1 simple get-tagged-comment, Parser and TagInstance initialize test-case; finds flavour, spans"""
        source_name = 'test/var/radical-tasks-1.txt'
        prsr = Parser(None, self.mb, source_name, '')
        tag = radical.TagInstance(source_name, 'TODO', (2, 9))
        # sanity check on test file data
        self.assertEquals(prsr.srcdoc.data[3:7], 'TODO')
        cmnt = radical.get_tagged_comment(prsr, tag, None, self.rc)
        self.assert_(cmnt,
        "radical.get_tagged_comment TODO returned nothing on %s (%s chars)" % (
            source_name, len(prsr.srcdoc.data)))
        self.assertEquals(len(cmnt), 3)
        comment_flavour, char_span, line_span = cmnt
        self.assertEquals(comment_flavour, 'unix_generic')
        self.assertEquals(line_span, (1, 1))
        self.assertEquals(char_span, (1, 65))

    @parameterized.expand([
        #( 1, '/** TODO comment */', ( (3, 14), 'c', (0, 19), (0, 0) ) ),
        #( 2, '/** TODO comment */\n', (  (), 'c', (0, 19 ), (0, 0) ) ),
        #( 3, '     /** TODO comment */\n', ( (), 'c', (5, 24), (0, 0) ) ),
        #( 4, 'lkj\nlkj lkj\nfoo /** TODO comment */ bar\nqwiefn\n', (  'c', (16, 35), (2, 2) ) ),
        #( 5, 'lkjlkj lkj\nfoo /** TODO comment */ bar\nqwiefn\n', (  'c', (15, 34), (1, 1) ) ),
        #( 6, '     \n/**\n TODO comment \n*/\n', (  (), 'c', (6, 27 ), (1, 3) ) ),

        ( 7, '// TODO comment ', ( (2, 16), 'c_line', (0, 16), (0, 0) ) ),
        ( 8, '# TODO comment ', ( (1, 15), 'unix_generic', ( 0, 15 ), ( 0, 0 ) ) ),
        ( 9, '  # TODO comment ', ( (3, 17), 'unix_generic', ( 0, 17 ), ( 0, 0 )
            , '   TODO comment ' ) ),
        ( 9, 'asdf\nfdsa\n// TODO comment \nfoo', ( (12, 26), 'c_line', (10, 26), (2, 2) ) ),
        ( 10, 'asdf fdsa // TODO comment \nfoo', ( (12, 26), 'c_line', (10, 27), (0, 0) ) ),
        #( 11, '// asdf fdsa TODO comment \nfoo', ( 'c_line', (12, 27), (0, 0) ) ),
    ])
    def test_4_1_2_get_tagged_comment_2016(self, testnr, data, expected):
        """4.1.2 get-tagged-comment given tag find comment"""
        prsr = Parser(None, self.mb, '<inline>', '<unittest>', data)
        tag = radical.TagInstance('<inline>', 'TODO', expected[0])
        # Sanity
        self.assertEquals( prsr.srcdoc.data[slice(*expected[0])], ' TODO comment ')
        # call test function
        cmnt = radical.get_tagged_comment(prsr, tag, None, self.rc)
        comment_flavour, char_span, line_span = cmnt
        # Verify test (ever case should have same str result)
        if len(expected) <= 4:
            comment = ' TODO comment '
        else:
            comment = expected[4]
        cmnt_exp = re.sub( r'[/*#\n]', '', data[slice(*expected[2])] )
        self.assertEquals( cmnt_exp, comment )
        # Actual tests
        self.assertEquals( comment_flavour, expected[1] )
        self.assertEquals( line_span, expected[3] )
        # XXX:
        #self.assertEquals( char_span, expected[2] )

            #descr = data[slice(*descr_span)]
            #exp_descr = data[slice(*exp_descr[2])]
            #self.assertEquals( descr, exp_descr )

    @parameterized.expand([
        ( 12, 'asdf\nfdsa\n// TODO comment \n// foo\n\n', ( 'c_line', (10, 32), (2,
            3), '// TODO comment \n// foo\n' ) ),
        ( 13, 'asdf\nfdsa\n// TODO comment \n// foo', ( 'c_line', (10, 32), (2,
            3), '// TODO comment \n// foo' ) ),

        ( 14, 'asdf fdsa // comment ', None ),
        ( 15, 'asdf fdsa TODO comment \nfoo', None ),
    ])
    def test_4_1_3_get_tagged_comment(self, testnr, data, expected):
        pass



    # XXX: stubs
    @parameterized.expand([
        ( 12, 'asdf\nfdsa\n// TODO comment \n// foo\n\n', ( 'c_line', (), )),
    ])
    def test_4_2_get_comment_tag_description(self, testnr, data, expected):
        pass
    @parameterized.expand([
        #( 1, 'radical-test1.txt', [
        #    ] )
    ])
    def test_find_tagged_comments(self, testnr, source, expected):
        data = open(source).read()
        #comments = list(find_tagged_comments(source, self.mb, source, data))




def get_cases():
    return [
            RadicalTestCase
        ]


if __name__ == '__main__':
    unittest.main()

