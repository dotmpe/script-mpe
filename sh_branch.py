from __future__ import print_function
import re

# comments
sub1 = re.compile(r'\#.*$\n', re.M).subn
# blank lines
sub2 = re.compile(r'((\s*\n)+\s*)+', re.M).subn

def bashlex_parse(src):
  src = open(fn).read()
  src, srcr = sub1('', src)
  src, srcr = sub2('\n', src.strip())
  #sub3 = re.compile(r'(?<![{\(])(\s*\n\s*)+', re.M).subn
  #src, srcr = sub3(';', src.strip())
  print(src)
  #src = """
  #test -n "$scriptpath" || scriptpath="$(pwd -P)"
  #""".strip()
  import bashlex
  parts = bashlex.parse(src)
  for ast in parts:
    print(ast.dump())

def shlex_parse(fn):
  import shlex
  src = open(fn).read()
  src, srcr = sub1('', src)
  src, srcr = sub2('\n', src.strip())
  o = shlex.shlex(src)
  import sys
  for x in o:
      sys.stdout.write(x)


if __name__ == '__main__':
    # NOTE: bashlex does not support parsing case/esac patterns
    fn = './tools/sh/init.sh'
    bashlex_parse(fn)
    #shlex_parse(fn)
