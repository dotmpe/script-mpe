Prefix
========
Prefix_: an affix added in front of the word.

.. _prefix: http://wordnetweb.princeton.edu/perl/webwn?s=prefix

Objective: shorten path, URL and other locator, address, identifier strings.

Use-case: Shell
----------------
Shell vars, values can be anything but lets consider those bearing a local
path name:

1.    <name>DIR=<dirpath>
2.    <name>=<path>
3.    <lookuppath>=<path>[:<path>...]

Value exists as either path, dir or other special filesystem node.
Third variant allows bother multiple paths and ordering.

Given above pattern, we can get a list for all 'named' dirs or other paths
on the current system/namespace.

On some conditions, ie. paths must exist::

    htd env pathvars
    htd env dirvars
    htd env filevars
    htd env symlinkvars

And above `pathvars` will include some URL's as well.

Alternatives:

- template file
- prescribed names and prefix/suffixes, iow. work by convention

Template file
-------------
Instead of using some verbose shell script, or static variable declaration
listing, define prefix paths and names using a listing of ``<path> <varname>``
lines, that may include shell expressions.

This effectively enapsulates a shell profile consisting of variable names
and value(s) for those names.

Because lookup is by path, those fields must be unique. But different paths
may have the same varname, ie. paths with symbolic elements. For those
the first appearance (line from pathnames table template)  is the canonical
value.

::

    htd prefixes check     # See that names from template are defined in current env
    htd prefixes table-id  # See template filename and check it exists
    htd prefixes raw-table
    htd prefixes name <path>
    htd prefixes names <path>...

