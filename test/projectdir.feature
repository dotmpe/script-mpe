Feature: projectdir is a tool to handle projects as groups

    Projects are checkouts, with a worktree and specific states tied to it.
    The projectdoc sits at the root of a directory containing projects, and
    identifies each project both by ID and its prefix at this host/dir.

    To manage these entities, `projectdir` or alias `pd` provides scripts, and
    reserves certain script ID's. So that projects can extend (override or
    amend) Pd's standard routines on a per-project basis.

    These scripts are part of a basic project lifecycle, which can basicly be
    described as:

      init > (dev) > deinit

    But each project provides its own specific flow, likely more than one, e.g.:

      init > build > test
           > package > dist
           > release > dist
           > deinit

    Pd needs to track state, and it does this by recording status and benchmark
    numbers outside the project, in the projectdoc file where it can be
    potentially distributed across hosts to other projectdirs. Or tied into
    other CI/CD sytems.

    It does not record reports but summarizes them into ID's and numbers.
    And those it uses to track state too.

      init{,-*}
      {,*-}init
      build{,-*}
      check{,-*}
      {,*-}status


    @todo
    Scenario: it intializes, checks, and then cleanup and deinitializes a compatible project without problems

        A project does something, it will need to tell something about what it does or wants. There are ways to assume a certain type of build, or stack, but it is hard to auto-detect what exactly is meant. If the goal is to check compliance to a certain build pipeline then ofcourse we can just impose a lifecycle on it, run that, but miss out on possibly many other aspects of the project. Unless the detection is all dynamic, but this adds too much complexity while it would be easy for the project to tell how its parts conforms to one or more pre-scribed contracts.

        NOTE: The first way for Pd to support project metadata is using `package.y*ml <package.rst>`. After some flows and commands have crystalized and its support and costs are more clear, then others can be added; `composer.json`, `package.json` are obvious candidates. Others may be plugged in in specific ways, ie. `bower.json`, `manifest.json`, even `Makefile`.


    Scenario: list scm dirs

        When the user executes "projectdir.py"
        Then the `status` is '0'
        #And the `output` is not empty

    Scenario: list untracked files

        When the user executes "projectdir.py find-untracked"
        Then the `status` is '0'
        #And the `output` is not empty
        #And the `output` contains ''

