script.mpe
==========
:Version: 0.0.3-dev
:Updated: 2016-11-19


Build-status
    .. FIXME: cannot att ?branch= without Du/rSt2html breaking
    .. image:: https://secure.travis-ci.org/dotmpe/script-mpe.svg
      :width: 89
      :target: https://travis-ci.org/dotmpe/script-mpe
      :alt: Build

Issues
    .. image:: https://img.shields.io/github/issues/dotmpe/script-mpe.svg
      :target: http://githubstats.com/dotmpe/script-mpe/issues
      :alt: GitHub issues


Various tools and ongoing experiments that have not yet deserved their own
project.



Quickstart
-----------
Prerequisites
  User-Conf_
    - Not required. But as for the shell tooling, this may contain
      some context.

https://gist.github.com/jczaplew/bf3a33c5a82a2d93bba4
::

  git@github.com:dotmpe/google-chrome-htdocs.git


.. _user-conf: https://github.com/dotmpe/user-conf



Testing
--------
::

       ./test/*-spec.bats

See also `.travis.yml`.


Other documents
---------------
- `Change Log <ChangeLog.rst>`_
- `Bugs <Bugs.rst>`_
- `Documentation <doc/>`_


Dev
---
- Maybe look at dispatch_ a bit, a run-subcmd handler in 48 lines Bash.


.. _dispatch: https://github.com/Mosai/workshop/blob/master/doc/dispatch.md


