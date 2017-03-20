
Tools allows to store scripts and metadata for named dependencies.

Initial implementation is in ``htd.sh``::

  $ htd tools json-spec todotxt-machine
  $ htd installed todotxt-machine
  $ htd installed json-spec
  $ htd uninstall json-spec
  $ htd script # list named scripts

Adapted to store arbitrary scripts too.

- schema/tools.yml for JSON draft-04 schema

Keeping structured metadata while allowing flexible use requires some inference
and switching of alternate schema.

The complexity is used to allow recording data for and interacting with package
managers.

For example consider the following functionally equiv. examples, some of which
could exist in the same file at once::

  tools:

    myscript: grep ...

    myscript:
      - grep ...

    myscript:
      scripts:
        myscript: grep ...

    myscript:
      scripts:
        myscript:
          - grep ...

    myscript:
      scripts:
        default: grep ...

    myscript:
      scripts:
        default:
          - grep ...


FIXME: the default keys are not supported, neither is the dep key.


