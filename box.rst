Box

  Has an executable file, present on $PATH
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

    Has a command to edit the user command script::

      box -E|edit-main

    Has a facility to keep extensions with new commands.
    The first extension is managing commands per directory.

    Extensions
        - It should list all extension commands, and/or all local paths for commands::

            box

    Has a command to run a local sub-cmd::

      box run [-l]

    Has a command to create a new host box user script.
      ..

    Has a command to add a new local sub-cmd to a box script.
      ..



Host box script

  Is a command-line script with the same specs as Box.
    ..



