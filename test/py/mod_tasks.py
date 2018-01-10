import unittest
import re

from nose_parameterized import parameterized

from script_mpe import tasks


class TasksTestCase(unittest.TestCase):

    @parameterized.expand([
        ( 1, 'vc.rst:39: :sync-mode: TODO: See Pd.\\n', ( ) ), # tasks-ignore
    ])
    def test_1_grep_nH_rs(self, testnr, data, expected):
        "tasks regex should split grep -nH lines"
        m = tasks.grep_nH_rs.match(data)
        assert m


def get_cases():
    return [
            TasksTestCase
        ]


if __name__ == '__main__':
    unittest.main()

