"""
        Python has flexible signatures, which take a bit of effort to understand
        and call.
        Here is a straightforward example showing all the elements:

            def test(a1, a2, kwd='A', *args, **kwds):
                pass

            test('arg1', 'arg2', 'B', 'arg3', 'arg4', a=9, b=2)

        But this is also possible::

            test(None, None, notkwd='C', kwd='B')
"""
from __future__ import print_function


def test(a1, a2, kwd=None, *args, **kwds):
    print(a1, a2)
    print('kwd', kwd)
    print('args', args)
    print('kwds', kwds)


test('arg1', 'arg2', 'kwd', 'arg3', 'arg4', a=9, b=2)
test(None, None, notkwd='C', kwd='B')
