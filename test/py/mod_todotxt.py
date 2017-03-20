import unittest
import re

from nose_parameterized import parameterized

from script_mpe.res import todo


class TodoTestCase(unittest.TestCase):

    @parameterized.expand([
        ( 1, 'test/var/todo.txt', () ),
    ])
    def test_1_(self, testnr, testfn, expected):
        ""
        i = todo.TodoTxtParser(
                    tags=['X-TRCK', 'FIXME', 'TODO', 'XXX'],
                )
        list(i.load(testfn))
        self.assertEquals( i['X-TRCK-999'].priority, None )
        self.assertEquals( i['X-TRCK-999'].text, 'X-TRCK-999: setup testing for gizmo' )
        self.assertEquals( i['X-TRCK-999'].creation_date, '2017-03-19' )
        self.assertEquals( i['X-TRCK-1001'].text, 'X-TRCK-1001: rewrite +jelly layer to +peanut, improve @coverage' )
        self.assertEquals( i['X-TRCK-1001'].priority, 'A' )
        self.assertEquals( i['X-TRCK-1001'].creation_date, '2017-03-19' )
        self.assertEquals( i['test/var/todo.txt:3'].priority, 'D' )
        self.assertEquals( i['test/var/todo.txt:3'].text, 'clean up old code XXX-jybtyDKFdOCC XXX-ZnV3whzhLzOM XXX-KSPpSK8SiElJ' )
        self.assertEquals( i['test/var/todo.txt:4'].priority, 'F' )
        self.assertEquals( i['test/var/todo.txt:4'].text, 'foo +AnotherPrefTag @DifferentPrefTag' )
        self.assertEquals( i['test/var/todo.txt:5'].priority, None )
        self.assertEquals( i['test/var/todo.txt:5'].contexts, [] )
        self.assertEquals( i['test/var/todo.txt:5'].projects, ['prj1', 'prj2', 'prj3', 'prj4'] )
        self.assertEquals( i['test/var/todo.txt:6'].priority, None )
        self.assertEquals( i['test/var/todo.txt:6'].projects, [] )
        self.assertEquals( i['test/var/todo.txt:6'].contexts, ['ctx-1', 'ctx2', 'ctx3', 'ctx4'] )



def get_cases():
    return [
            TodoTestCase
        ]


if __name__ == '__main__':
    unittest.main()

