import zope.component
import unittest

from script_mpe import res


tests = (
    ("sha1sum", res.SHA1Sum,
    # unparsed source document and parsed structure:
    [
        "9c288c453bebe44d67224b1ffaf650bb7adf4960  us-navy-time.sh",
        "0aa970d96eb971303c45b39c0f5ceb7d49383d6b  vcard2n3.sh",
        "3306a06a042d5e8361288dfa7aca93630d5370e5  vc.sh",
        "a14aa8d3379d07bc09283cf62cae432cc0309a05  volume.py",
        "5bf5eae6238afaff0a142da7b6df9a2030ae25d0  workLog.py",
        "810b7cbf9d05fd56227ef859f7b715f806d8564c  some test file",
    ], {
        '9c288c453bebe44d67224b1ffaf650bb7adf4960': 'us-navy-time.sh',
        '0aa970d96eb971303c45b39c0f5ceb7d49383d6b': 'vcard2n3.sh',
        '3306a06a042d5e8361288dfa7aca93630d5370e5': 'vc.sh',
        'a14aa8d3379d07bc09283cf62cae432cc0309a05': 'volume.py',
        '5bf5eae6238afaff0a142da7b6df9a2030ae25d0': 'workLog.py',
        '810b7cbf9d05fd56227ef859f7b715f806d8564c': 'some test file',
    }),
)

def FormatTestGenerator(name, formatter, source, expected):
    for name in expected:
        def _test():
            obj = formatter()
            obj.parse_data(source)
            assert name in obj, "Missing key %s" % name
            assert obj[name] == expected[name], "Values do not match for %s" % name
        _test.__name__ = 'test_res_format_'+name
        yield _test

def wrap_functions(format_tests):
    for name, formatter, source, data in format_tests:
        for func in FormatTestGenerator(name, formatter, source, data):
            yield unittest.FunctionTestCase(
                    func,
                    description='Res_FormatTest_'+name)

def get_cases():
    return list( wrap_functions(tests) )


if __name__ == '__main__':
    import sys
    for klass in get_cases():
        setattr( sys.modules['__main__'], klass._description, klass )
    # FIXME: how to get cases into unittest.main
    unittest.main()
