Objective
---------
Use script engines on host env to build more or less complex (semi) automated setups.

Provide simple user and machine invocation paradigms, and work on regular UNIX host "objects"; files, streams, lines, text-formats, FIFO/named-pipes, descriptors, etc. etc.

Delegate sophisticated user interfaces to specific verticals. Use
appropiate languages to build programs with complex objects, and handle
in-memory opeartions and non-file storeage and queries.

Design
------
- shell scripts for user-command frontends, move reusable code to
  shell function libraries (``*.lib.sh``)
- (Py) misc. classes (ie. parsers) into ``res``, SQL ORM in ``taxus``,
  backend ``*.py`` scripts using ``libcmd*``

* Maybe look at dispatch_ a bit, a run-subcmd handler in 48 lines Bash.
  But Bash.

- TODO: Documentation generate `Shell library docs </doc/src/sh/main.rst>`__
- and revise per-component docs, ie. start with Htd, Ht.
- See ../.default.rst for in-rSt approach of current script-mpe docs..

* TODO: https://github.com/ok-borg/borg
  see also u-s/user-scripts

Spec
----
See index.rst for spec listing wip

Issues
------
v0.0.3-3-g39b5e59 1143 lines of todo.txt

TODO: Vagrant, here or in uconf setup testbed

Bugs
~~~~~
1. Regression in radical.py::

    Traceback (most recent call last):
      File "/Users/berend/bin/./radical.py", line 1234, in <module>
        Radical.main()
      File "/Users/berend/bin/libcmd.py", line 456, in main
        self.execute( handler_name )
      File "/Users/berend/bin/libcmd.py", line 516, in execute
        for res in g:
      File "/Users/berend/bin/libcmd.py", line 78, in start
        for r in ret:
      File "/Users/berend/bin/rsr.py", line 319, in rsr_session
        repo_root = session.context.settings.data.repository.root_dir
    AttributeError: 'dict' object has no attribute 'data'

  - Radical broken after 449ea4f, fork and build unittest
  - Fixed (tests/bugs/1-radical-regression) by ignoring session.context


SCRIPT-MPE-5 TODO: use projectenv.lib iso. test/helper.bash
  - use `require-env` in setup or test-cases.
  - deprecate is-skipped, current-test-env etc.
  - see env-deps.lib.sh for per-project collections of callbacks. Should
    start to scan scriptpath elements somehow?

  SCRIPT-MPE-6 TODO: deprecate most of helper.bash, restructure
    - See user-conf for up to date setup, and minimal lib versions.


.. _dispatch: https://github.com/Mosai/workshop/blob/master/doc/dispatch.md
