Jsotk
=========
Javascript Object toolkit
~~~~~~~~~~~~~~~~~~~~~~~~~~

Load, query, transform JSON/YAML data on the command line.

Features in a nutshell:
  - Detects YAML or JSON output, convert, pretty print.
  - Get data using simple path expressions, or using ObjectPath_ expression.
  - Update using data provided from shell, query for parts, merge, clear, move.


Usage::

  # e.g. pretty print JSON as YAML
  <some-json-output> | jsotk -O yaml --pretty -

  # Default subcommand is 'dump', shortcuts for dump:

  jsotk json2yaml [--pretty] [SRC [DEST]]
  jsotk yaml2json [--pretty] [SRC [DEST]]

  # Print data at path as Python formatted obj
  jsotk.py -O py path $1 tools/$2/bin

  # Find objects in list with 'main' attribute. File can be JSON or YAML, uses
  # extension auto detection.
  jsotk objectpath <fn> '$.*[@.main is not None]'

  # Update data using simple shell constructs
  echo key=val | jsotk update SRC DEST
  # TODO: jsotk update-from-args SRC DEST

  # Print data as Shell usable variables declarations
  eval $(jsotk.py -O fkv path tools.yml tools/jsonwidget --output-prefix jsonwidget)
  echo $jsonwidget_bin

FIXME::

  echo xyz/abc[1]/attr=val | jsotk from-kv -
  echo xyz_abc__1_attr=val | jsotk from-flat-kv -


There is also local background process support, usable with `socat` which
is implemented in projectdir_.sh `meta` command. Having a persistent
process while looping over results in shell scripts may improve performance.

See docstrings in jsotk.py_ for further help, or run with ``-h``.
This file for notes, test descriptions.


Issues
------
``jsotk update`` does not obey ``--list-union``.
    In fact, YAML aliases can get in the way of proper updates.

    Consider the update test cases using fixtures ``test/var/jsotk/5-*.yaml``. The list 'entries' is never merged, since due to the reference the list item is destroyed while 'entry' is being updated::

        mydict:
          entry: &id1
            my: data
          entries:
          - *id1

        mydict:
          entry: &id1
            my: other data
          entries:
          - *id1


    The solution is to clear ``mydict.entry`` in the destination document, thereby breaking the reference.

Dev
---
Formats wishlist: xml, ini, properties.


Specs
------

jsotk
  dump
    Read data in using one of the input formats, and write out in an output format.
    The option pretty affects YAML output formatting.

jsotk_xml_dom
  1. There are some forms of XML-YAML/JSON mapping.
     One school maps 'attribute', 'name', 'content' and or 'text'
     attributes to the XML equavalents.

     See test/var/jsotk/xml-1.*

     A straight mapping should not be too difficult. However as the structure
     is not native to JSON or YAML, it is hard to find a practical appliation
     for that. Instead, it may be usefull to update/insert or maybe rewrite
     XML data using a full Jstok XML I/O implementation.

  2. The trick is getting to a sensible default handling, and set of options
     to switch or change behaviours.

     A more direct approach is mapping all attribute names to element names, or
     maybe attribute names. And handle alike all content, text or element,
     sequenced or not.

     See test/var/jsotk/xml-2.*

     Spec
       Bin jsotk.py dump
       Flag --xml-mode-2

       Map attributes with element nodes, and
         values to #text content nodes always (mode-2), or
         values to attribute nodes if leafs (mode-2-leaf-attrs).

       Optionally switch default type at branch points,
         ie. all or some leafs as attributes (iso. elements, leafs vs. ).
         Example::

            path/to/leaf::type=attribute

         Outputs(pxml)::

            <path>
              <to leaf="value>
                <leaf2>value2

         Given(yaml)::

            path:
              to:
                leaf: value
                leaf2: value2


Formats
--------
See ``jsotk --help`` for usage and current format listing.

Notable custom formats are `pkv` ('path' key, values) and `fkv` ('flat' key,
values) which translate any object notation to a single, global list of long
var names.

  TODO: testing etc. The main use is for fkv as a format for shell or Java
  properties compatible settings.

Examples:
  pkv::

    path/to[1]/item=value-for-object-path
    path/to[]=append-item-value

  fkv::

    path_to__1_item=value-for-object-path
    path_to__2=append-item-value)


.. _projectdir: ./projectdir.rst
.. _jsotk.py: ./jsotk.py

.. _ObjectPath: http://objectpath.org
