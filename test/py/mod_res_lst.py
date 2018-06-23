import unittest
import re

from nose_parameterized import parameterized

from script_mpe.res import lst



class ListItemTxtParserTestCase(unittest.TestCase):
    @parameterized.expand([
        (1, '')
    ])
    def test_1_(self, testnr, raw):
        tlp = todo.TodoListParser()
