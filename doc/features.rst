Features
________
:Created: 2016-03-27
:Updated: 2016-10-10

Some thoughts and notes on script-mpe features; documentation and automation.
Mostly ToDo, epic-style text. See http:index for a temporary listing to all
documented parts in script-mpe.

TODO: [2018-01-28] Also have a look at apiblueprint.org and perhaps variants

----

Did some experimental writeups on feature or behaviour driven test cases.

Need to return to defining features within a project.

- To specify suites or scenarios of related sets of checks and tests,
  and possibly sub-versions in nested sets
- To specify supported functionality (per version, feature, etc.).
- To specify dependencies or requirements (per ...)
- To calculate required build matrices
- To validate inputs, environments, prerequisites


GIT/Shell Versioning Analysis
=============================

XXX: old notes in git-versioning/test

Format
------
The general format for behaviour or scenario driven test case notation is::

  component
    with gizmo
      - is awesome
    subcomponent
      has feature x
        - that evalautes to ...
        - or does such and such


Nothing much specific is covered, but a specific numbering proposed.

The hierarchical format is suited for writing a body of well organized
scenarios. But they depend on an underlying interpreting layer that is not very
well defined and rather highly customized.

The literal format lends itself for various extensions based on spefic tokens
or syntax.

What is not covered:

- Tools available for each test
- Referring to other tests
- The type of hierachy used, it is nothing much than a generic "outline".
  (Behat's Gherkin uses a Feature-Scenario-type type structure, but nothing much
  is enabled by this afaics.)
- Dealing with environments, matrices and the builds' requirements


Test Tools
----------
List items under a component/feature make up the actual test cases.

Behat uses some keywords to establish and modify context.

    *Given* some precondition
    *And* some other precondition
    *When* some action by the actor
    *And* some other action
    *And* yet another action
    *Then* some testable outcome is achieved
    *And* something else we can check happens too

The explicit generic modifiers are interesting,
but we require an extensible set that allows progressively complex
test scenarios.

So first building it with shell scripting with Bats idiom.

Also, why note optionally remove the test steps entirely from a feature/component
hierarchy--there is going to be some decoration to support feature tagging and
environment matrices anyway.


Syntax
------
Each hiearchy has a root and branches, which are regarded as generic feature
descriptions. They may use any required form.

At the leaf ends are lists of tests, or references to tests.

The lists of test steps are execution blocks.
Each step should be evaluated in the same environment, and can modify it.
Successfully running all tests should validate the (sub)component/feature that
contains the tests.

Alternatively an internal or external link is given. The internal reference
is a relative or absolute component/feature path.

An external reference is also absolute or relative,
to either an executable, or another feature speficiation document.
There should also be an option an anchor with internal absolute reference.



Build Environments
------------------

Environments are the most easy way to parameterize a shell script driven build
process.

The requirement is to iterate and combine lists, and for each executing a single block
several times usually in parallel.


New Syntax
==========
Simply put, rSt subset with:

- nested rSt:definition-list-item correspond to feature, or component under test
- contents are either rSt references, or rSt bullet/enumerated lists
- rSt:list-item contains interpreted test steps

I like using rSt as superset.
It does not need to impose additional syntax.
Except literal escaping (\`\`) for inline commands maybe.

Some additional idiom beyond that of Bats or Bash is introduced.
Most importantly requires ask that a env var is provided for,
or injected.
And also provides and cases modifiy a component as injectors
for requires, and/or specify eiter build prerequisites or build matrices.

Example:

component v0.0.1
  feature version
    scenario cli prints version
      - feature cli:scenario cli prints version
    scenario lib function prints version
      - feature lib:scenario cli prints version

  feature cli
    scenario cli prints version
      - requires bin
      - run $bin version
      - test "${lines[*]}" = "$bin_version"

  feature lib
    scenario lib prints version
      - requires lib
      - source $lib
      - cmd_print_version
      - test "${lines[*]}" = "$bin_version"

  feature with prerequisites (ext)
    - dependencies some-3rd-party-bin, lib>=4.0.*
    - test

  feature only on dev
    - require-env ENV dev
    - test

  feature testing on a specific build node/host/env
    - require-node label
    - test

  build environments
    - provides ENV
    - (cases)

      * ENV=dev
      * ENV=test

      - UNAME=Darwin
      - UNAME=Linux

    feature bin environment
      - provides bin
      - bin=bar

    feature lib environment
      - provides lib
      - lib=foo/bar.sh


Two key words and a new structure:

requires ENV
  remaining script requires injector script for ENV to be resolved and evaluated
  first

provides ENV
  marks the code block an dependency provider, an injector as simple as an export FOO=bar statement or as complex as a scenario script.
  It exposes a return value, but the codeblock still tests the working of the
  above component.

cases (nested lists)
  iso. var names, this deals with specific values of vars.
  a nested list causes the remaining script to require one execution
  for each environment described in that list.
  multiple lists combine.

  the vars given in the matrix can be exposed by the script itself,
  or another injector may be required and should be used to initialze each
  execution. Ie. above UNAME would probably require another injector.

Some relations to ponder to come up with directives:

- requires - provides: environment settings
- depend(encie)s - installs: lib, binary
- cases - options: test/build matrices and/or choices

Dev
----
- Focus on script lines, pd run could maybe work on compiled/packaged scripts.

- Nice output format for nav. big sets of items, maybe a Sf or nodejs in Htd.

- The 'build environments' block does some additional mixing of branches and
  lists, but that is too specific for now.

- Not sure were to start with literate style scripting.

  htd has some rst-esque tpath stuff. Should get text offset info along.

  at the other end, various subcmds in htd, pd and others would be candidate to
  run packaged scripts. and other projects too.

- Should generate script/annotation for specific sh constructs:
  bats, scripts packaged into case's, boxed user-scripts maybe.

  Making some notes in projectdir.rst and htd.rst.
  Also maybe some stuff from htd rules/components should be consolidated at some point
  to clean things up.

..
