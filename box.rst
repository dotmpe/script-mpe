box - Shell-function script-command framwork wip

Design
------
Evocation pattern::

  $ <exec-cmd-name> <sub-cmd-name> <args...>

Translates to::

  <base>__<cmdid> <subcmdid> <args...>

Spec
----
- ``$ <box> <handler-name> ...``
- ``$ <box> <lib-name> <func-name>``

See Composure/main and `main <main.rst>`__

------

Older 2015-10-21 doc version for box framework.

Background:
   Box is a little shell framework, with one example ``box-instance`` as demo,
   and an utility command ``box`` for inspection and updates to script/lib-files
   (even itself).

   TODO: Move specific code from ``htd*sh`` and ``script*sh`` into here.
   Main code still is found in ``main.lib``.
   See sh-libs: main, box, src, script-sh.

   A bit of a work in progress, but applied in many local ``*.sh`` executables.

Feature:
    a command line script instance using ``{main,box}.lib.sh}`` [#1.1]

Scenario: Has an executable file, present on $PATH and with basic behaviour and etiquette

    - Is a command line script providing a user command with sub-commands,
      accepting long-style options and further arguments.
    - Script is the command. Sub-command the first given argument.
      Options apply to the command they follow.

      XXX: Subcommands can be aliased .. but should not be to short-opts. fix that.
      See -E etc.


    Has a command to retrieve help::

      box help [ID]

    Has a command to retrieve version::

      box version


Feature: the script is build by naming conventions for functions and variables,
  enabling inspection and annotation [#1.2.1]

  Background
    based on functions with '__' separated name parts, attributes using similar
    patterned variable names, and other name conventions. The scripts
    basename is used as prefix or namespace. The syntax and a practical examples
    are::

        <base> '_' <attr-name> '__' <field-or-subcmd>
        <base> '__' <field-or-subcmd>

        cmd__subcmd() { #...
        cmd_als__sc=subcmd # resolve alias 'sc' to 'subcmd'
        cmd_als___sc=subcmd # resolve '-sc' as alias

        <base> '_main'
        <base> '_lib'
        <lib> '_lib_load'

Feature: it is based on amendable scopes [#1.2.2]

    Background:
        Sentinel comment lines used as insert point, ie.
        for statements or source scripts.
        E.g. to add subcommands, append new instances, params to existing
        routines.

        Syntax::

            '# -- ' <base> ' ' <scope> ' ' <action> ' sentinel --'

Feature: it can edit scripts or script parts

Scenario: Has a command to edit the user command script::

      box -E|edit-main

    Has a facility to keep extensions with new commands.
    The first extension is managing commands per directory.

Scenario:
    Extensions
        - It should list all extension commands, and/or all local paths for commands::

            box

    Has a command to run a local sub-cmd::

      box run [-l]

Scenario:
    Has a command to create a new host box user script.
      ..

    Has a command to add a new local sub-cmd to a box script.
      ..


Scenario: it can insert a new function


Host box script

  Is a command-line script with the same specs as Box.
    ..

