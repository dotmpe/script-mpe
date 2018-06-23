import unittest
import re

from nose_parameterized import parameterized

from script_mpe.res import todo


class TodoListItemParserResourceTestCase(unittest.TestCase):
    """Test case for TodoListItemParser
    """

    @parameterized.expand([
        (1, '')
    ])
    def test_1_(self, testnr, raw):
        tlp = todo.TodoListParser()
        tlip = todo.TodoListItemParser(tlp)


class TodoTxtTaskParserResourceTestCase(unittest.TestCase):

    @parameterized.expand([
        (1, '+script-mpe amanda, invidia, esop',
            '+script-mpe amanda, invidia, esop',
            ['script-mpe'], []),
#        (2, '+script-mpe htd open/close? up/down? Rules. @refine', '',
#            ['script-mpe'], ['refine']),
#        (3, '+script-mpe pd enable unpack tgz @Dev', '', ['script-mpe'], ['Dev']),
#        (4, '+Radical SQL (SCEI)', '', ['Radical'], []),
#        (5, '@Dev +script-mpe diskdoc @Darwin', '', ['script-mpe'], ['Dev',
#            'Darwin']),
#        (6, '@Dev htd.sh interact with tmux.py open/close default or pre-defined sessions per project @tmux +node-sitefile',
#            '', ['node-sitefile'], ['Dev', 'tmux']),
#        (7, '+Esop - test runner', '+Esop - test runner', ['Esop'], []),
#        (8, '2018-01-28  Also have a look at apiblueprint.org and perhaps variants',
#            ' Also have a look at apiblueprint.org and perhaps variants', [], [])
    ])
    def test_1_(self, testnr, raw, txt, projects, contexts):
        tttp = todo.TodoTxtTaskParser(raw)
        self.assertEquals(tttp.contexts, contexts)
        self.assertEquals(tttp.projects, projects)
        self.assertEquals(tttp.text, txt)
        #print(tttp, tttp.projects, tttp.contexts, tttp.text)

class TodoTxtParserResourceTestCase(unittest.TestCase): pass
#class TodoResourceTestCase(unittest.TestCase): pass

if __name__ == '__main__':
    unittest.main()
