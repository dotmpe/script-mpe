Jsotk
=========
Javascript Object toolkit
~~~~~~~~~~~~~~~~~~~~~~~~~~

Load, query, transform JSON/YAML data to and from (Bourne) Shell.

Features in a nutshel:
  Auto detects YAML or JSON output.
  Has ObjectPath_ and other retrieval commands. And updates or outputs
  plain JSON/YAML elements.

Usage::

  <some-json-output> | jsotk -O yaml --pretty -

  jsotk json2yaml [--pretty] [SRC [DEST]]
  jsotk yaml2json [--pretty] [SRC [DEST]]

  # Print data as Shell usable variables declarations
  eval $(jsotk.py -O fkv path tools.yml tools/jsonwidget --output-prefix jsonwidget)
  echo $jsonwidget_bin

  # Print data at path as Python formatted obj
  jsotk.py -O py path $1 tools/$2/bin

  # Find objects in list with 'main' attribute
  jsotk objectpath <json-fn> '$.*[@.main is not None]'

There is also local background process support, usable with `socat` which
is implemented in http:./projectdir.sh `meta` command. Having a persistent
process while looping over results in shell scripts may improve performance.

See docstrings in http:./jsotk.py for further help, or run with ``-h``.
This file for notes, test descriptions.


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



.. _ObjectPath: http://objectpath.org

