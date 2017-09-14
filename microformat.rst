Microformats
============
.. include:: .default.rst

.. footer::

   [2017-07-16]


Plain or RestructuredText, "Markdown" extension, TODO.txt based tags
    | [HH:MM] Time reference
    | @Contextual-Tag
    | +Project-Tag-Id
    | <URL or netpath or other abs/rel path>
    | (priority)
    | ~Username or self '~' reference

Need to see how above jives within various formats.

Microformats, see HTML5 profiles.
Below are descriptions for some HTML profiles, giving them an ID too.

HTML
  HTML5
    Before, there was one profile per HTML document. Now there can be one per
    element instance. Below meta keys still apply.

    meta[name=..]
      application-name
        One name per language allowed. See meta-application-name_.
      author
        Free form.
      descriptions
        One per page.
      generator
        Free form ID field.
      keywords
        CSV.

    Nothing much is said about name value uniqueness per document, and values
    are simply strings. Or empty for no attribute/element.

  .. _du-xhtml:

  Docutils XHTML
    Docutils xhtml writer representations.

    .header hr.header
      ..
    .document
      ..
    .footer hr.footer
      ..
    .docutils
      Generic class for Du generated elements, ie. dl, table, hr

  .. _bootstrap:

  Twitter Bootstrap
    .container
      ..

  .. _sf-htd:

  Sf-Htd
    Document Structure
      - Base on (mix with, extend on) docutils, bootstrap

    Process information
      ``.proc { .pid .cmd [ .ppid .nice .tty .cwd ] }``
        Elements have data and are expected to be representing some readibale
        format of a running process. See ``htd.sh ps``, ps__ itself and htd-proc__
        raw data for more keys.

      ``.pm.proc`` or ``.pm2.proc``
        Same as proc, but management through PM2 god daemon.

    API::

      GET /proc/pm2.json
      GET /proc/pm2/:PID.json

      POST /proc/pm2/:PID:/start
      POST /proc/pm2/:PID:/stop
      POST /proc/pm2/:PID:/resstart

    Apps
      Work in progress of moving some Sf-Htd app/htd to Sitefile.
      And most of all unified sf/main and app/sf-v0.


-----

Microformats
    Live code
        Live code is inline executable code, such as that in Jupyter.

        - `Radical <radical.rst>`__
        - `Sitefile Text Feature <//localhost:7011/doc/feature-text>`_


- If the user runs:

  .. class:: sf-mf sf-code mf-sh-cmd

  ::

    echo foo

  .. class:: sf-mf sf-code mf-sh-cmd

  ::

    whoami && pwd && hostname


- Lorem ipsum dolor sit amet, consectetaur adipisicing elit, sed do eiusmod
  tempor incididunt ut labore et dolore magna aliqua. :sh:`pd status`.
  Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut
  aliquip ex ea commodo consequat. :sh:`whoami && pwd && hostname`.
  Duis aute irure dolor in reprehenderit in voluptate velit esse cillum dolore
  eu fugiat nulla pariatur.
  :sh:`magnet.py "http://www.viking-z.org/index.htm" ~/htdocs/personal/journal/today.rst`.
  Excepteur sint occaecat cupidatat non proident, sunt in culpa qui officia
  deserunt mollit anim id est laborum.


Refs
--------------------------------

.. __: /man/ps
.. __: //localhost:2000/proc/

.. _meta-application-name: https://www.w3.org/TR/html5/document-metadata.html#meta-application-name

.. [#] <https://developer.mozilla.org/en/docs/Web/HTML/Element/meta>

