import unittest



class RadicalTestCase(unittest.TestCase):

    def setUp(self):
        this.dbref = '';
        this.session = radical.get_session(this.dbref)
    
    def test_000_main_argv(self):
        argv_tests = (
                'radical --help', 
                'radical -h',
                'radical --version',
                'radical -V',
                'radical -F=+'
            )

    def test_001_get_tagged_comment(self):
        radical.find(this.session, )

    def test_002_at_line(self):
        radical.find(this.session, )

    def test_003_find(self):
        radical.find(this.session, )



