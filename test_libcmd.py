import unittest

import libcmd


class CMDTest1(unittest.TestCase):
    
    def setUp(self):
        pass

    def test_1_(self):
        pass#libcmd.Cmd().main()

    def test_2_(self):
        app = libcmd.Cmd()
        # XXX: internals

        default = app.main_default()
        assert isinstance(default, tuple) and len(default) == 3


if __name__ == '__main__':
    unittest.main()
