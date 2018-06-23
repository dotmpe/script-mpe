import unittest
import re

from nose_parameterized import parameterized

from script_mpe.res import txt2


class ConcreteTxtLineParserTestCase(unittest.TestCase):
    """Test case for ConcreteTxtLineParser(AbstractTxtLineParser)
    """

    @parameterized.expand([
        (1, '')
    ])
    def test_1_(self, testnr, raw):
        list_parser = txt2.AbstractTxtListParser()
        line_parser = txt2.AbstractTxtLineParser(list_parser)

        #ctlp = txt2.ConcreteTxtLineParser()

        #tlp = todo.TodoListParser()
        #tlip = todo.TodoListItemParser(tlp)


class AbstractTxtListParserTestCase(unittest.TestCase):
    """Test case for AbstractTxtListParser
    """

    @parameterized.expand([
        (1, '+script-mpe amanda, invidia, esop', 'amanda, invidia, esop',
            ['script-mpe'], []),
    ])
    def test_1_(self, testnr, raw, txt, projects, contexts):
        atlp = txt2.AbstractTxtListParser()
        ctx = {'index': testnr}
        text, it = atlp.parse(raw, ctx)

        self.assertEquals(txt, text)


if __name__ == '__main__':
    unittest.main()
