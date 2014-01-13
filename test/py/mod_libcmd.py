import unittest

import libcmd


class CMDTest1(unittest.TestCase):
    
    def setUp(self):
        pass

    def test_1_(self):
        # TODO: test libcmd.Cmd
        pass

def get_cases():
    return [
            CMDTest1,
        ]

if __name__ == '__main__':
    unittest.main()

