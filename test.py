import unittest

from test_libcmd import CMDTest1
from test_confparse import CPTest1, CPTest2
from test_confparse2 import CP2Test1
from test_taxus import TaxusTest1
from test_radical import RadicalTestCase
import test_res


def gather_tests():
    tests = []
    for testcase in (CMDTest1, CPTest1, CPTest2, CP2Test1, TaxusTest1,
            RadicalTestCase):
        tests.append(unittest.TestLoader().loadTestsFromTestCase(testcase))
    tests += test_res.wrap_functions(test_res.tests)
    return tests


if __name__ == '__main__':
    testsuite = unittest.TestSuite(gather_tests())
    unittest.TextTestRunner(verbosity=2).run(testsuite)


