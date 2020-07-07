"""
Sphinx setup for script-mpe.readthedocs.io
"""
from recommonmark.parser import CommonMarkParser

source_parsers = {
  '.md': CommonMarkParser,
}

source_suffix = ['.rst', '.md']

"""
# print globals().keys()
['source_parsers', 'tags', '__builtins__', 'CommonMarkParser', '__file__', '__doc__']
"""
keep_warnings = True

intersphinx_mapping = {
    'python': ('http://python.readthedocs.io/en/latest/', None),
    'django': ('http://django.readthedocs.io/en/1.8.x/', None),
    'sphinx': ('http://sphinx.readthedocs.io/en/latest/', None),
    'script-mpe': ('http://script-mpe.readthedocs.io/en/latest/', None),
    'node-sitefile': ('http://node-sitefile.readthedocs.io/en/latest/', None),
}
