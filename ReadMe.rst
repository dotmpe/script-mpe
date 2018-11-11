script.mpe
==========
:Version: 0.0.4-dev
:Created: 2008-06-19
:Updated: 2018-04-15


Build-status
    .. BUG: cannot add ?branch= without Du/rSt2html breaking
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

::

  git@github.com:bvberkum/google-chrome-htdocs.git


.. _user-conf: https://github.com/bvberkum/user-conf



Testing
--------
::

       ./test/*-spec.bats

See also `.travis.yml`.


Documentation
-------------
Install sitefile::

  npm install sitefile
  cd .../script-mpe
  sitefile

Surf to sitefile service, default is `localhost:4500 <http://localhost:4500>`__.

Documents are here and there, mostly rSt maybe some MD, etc. The main entries
are:

- `Dev Docs <doc/dev.rst>`_
- `Documentation index <doc/index.rst>`_

And then there are many docs together with Sh or Py files, feature tests, specs.
the SCM timestamps should indicate wether they may be stale.

Also:

- `Change Log <ChangeLog.rst>`_
- `Bugs <Bugs.rst>`_

.. _dispatch: https://github.com/Mosai/workshop/blob/master/doc/dispatch.md

