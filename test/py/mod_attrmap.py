import optparse
import unittest
import re

from nose_parameterized import parameterized

import res
from res import attrmap


test_data = [
    ( dict(foo='123',unkn=True), dict(bar='foo'), False, False ),
    ( dict(foo='123',unkn=True), dict(bar='foo'), True, False ),
    ( dict(foo='123',unkn=True), dict(bar='foo'), False, True ),
]

class AttributeMapWrapperTestCase(unittest.TestCase):

    @parameterized.expand(test_data)
    def test_1_(self, s_, m_, ignore_unknown, strict):
        s = optparse.Values(s_)
        a = attrmap.AttributeMapWrapper(s, m_, strict=strict, ignore_unknown=ignore_unknown)

        self.assertEquals( a.bar, '123' )

        if strict:
            with self.assertRaises(AttributeError):
                a.foo
        else:
            self.assertEquals( a.foo, '123' )

        if ignore_unknown or strict:
            with self.assertRaises(AttributeError):
                a.unkn
        else:
            self.assertEquals( a.unkn, True )


def get_cases():
    return [
            TodoTestCase
        ]


if __name__ == '__main__':
    unittest.main()
