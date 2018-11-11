.. include:: .default.rst

Project Scripts
===============

See also
--------
- Build_, ie. `Project Dev Checks`_ and subdocs
  `Project Dev/Build Scripts`_ and `Project Test Scripts`_
- `Main Dev docs`_

- Pd: pdir and pdoc specs <doc/feature-pd.rst>
- TODO: pdoc lifecycle spec <test/project-lifecycle.rst>
- More ideas about local project dev specs <test/dev.feature>

CI and TDD What, Why, How
-------------------------
Testdriven development requires matching source files with tests, and monitoring
test execution regularly. With the correct tools, the developer should know the
test status before he/she is ready to commit. Even more, statistics and reports
(ie. test coverage) may be available to improve code before it is committed.

But if tools get in the way, they are sidestepped. It may be misbehaving in some
way, not giving helpful results. If that happens too often, things will be
forgotten. Tests get stale, code is left uncovered and perhaps stale or obsolete
as well, and lint is left around.

Successful TDD enforces at least one CI pipeline. In practice this always is a
version-control system tied to a build-system. The nature of such a setup
often means that the pipeline focusses on very specific tests, and perhaps
some other CD tasks. More than checks wrt. style, or real continuous integration
-- rebasing, upstream merging, dependency update checking, (re)tagging, or
other workflows. Depending on the nature of the project, the build itself may be
a thing, and a challenge to keep running. Mevermind the tests.

But the most important reason for a limited test-set is tooling; so the developer
should be given as much of the CI system locally as possible. No sane coder will
accept a broken build because of a style check, and there is little incentive to
go and check the warnings for a succesful build, unless ones' role is that of a
tester. E-mailing developers with warnings, if possible, does not help quickly
enough.

So even though builds may evolve, they will not if they are not both portable
and ported.
Rather, stable build pipelines are preferred. Matching the local test-case
environment with the remote CI execution can be a challenge enough. But then,
there is Kaizen: if we can start with the basics working, we only need to keep
it working while we improve, and add parts.

It is hard to think of unsuccessful TDD |---| every test of a deliverable has
put in something. But also unevitably, something changes. Management. Team.
Vendor. Software. Whatever. But something breaks somewhere, always.

The longer its stays broken, the more work it will take to get it working again.
If it affects the pipeline, it may be lobotomized in some way and never run
again. If left it grows stale and turns into lint. Tests do not remove
themselves, each commit will have the same code and test-cases: wether its a
development or production line and wether they run or not, they can all be
meaningless without a working workflow.

The incentive to solve a problem depends, on wether its mission critical,
its difficulty and time costs, and other perceived benefits. If both dev and ops
are interacting about all aspects of integration at the one hand and delivery
at the other, any pipeline problems should be easy to call-in/assign.

We can try to motivate the developer a bit to follow CI rules by providing pre-
commit hooks. Yet this should not delay the developer, the hook is helpful
but easily overcrowded. The best is to quickly check for the most basic bits
|---| and obviously not to run entire suite, even if for modifications only.

But it is a place to read test reports, and make up any kind of quick checks.
Require some success rate, coverage, or some essential tests; without re-running
them, but strictly by enforcing a workflow. This especially during development
should help to keep all rules in view, but out of the way.

TDD should allow attention to relax from the CI system. And to commit and push
changes confidently and early, without impedements.

The above is not a trivial affair. Using an IDE helps. Homogeneous projects,
deployment environments and standardized service endpoints help even more.

It is important to take as much of the CI system to the development host. It
cannot fully replace a large matrix build on a clean system, but it should help
to keep the developer free from unecessary CI build-error e-mails.

The best and shortest way to do all of the above is to setup an IDE, or some
daemon or shell process and run our test suite(s), contineously.

The module ``build.lib.sh`` `provides some of these functions`__ now too, and
with customizations in mind.

Existing solutions already exist; fswatch, inotify, or even nodemon\ [#]_ can be
used to monitor for changes and restart commands. What is not there if one steps
outside of a certain IDE or language framework are tools to treat all project
equally, while executing them sometimes quite differently.

In that picture, other aspects should be in view too. Workflows like SCM
up/down/feature flows, automatic code cleanup, automatic fixture updates,
automatic documentation updates, etc.

- Local test workflow
- CI pipeline (SCM -> CI test build; )


.. __: build.rst

HOWTO CI & TDD
----------------
So what levels of tooling do we have. The best is to setup a "building" project
and work it out from there. But a dependency based build/test system is
something that takes time; explicit rules have to be setup, source files
grouped, etc.

Depending on project I see three levels wrt. test-setup:

1. Single test-suite
2. Multiple test-suites coupled by table
3. Proper rule setup with prerequisites, cache validation

These obviously fall together with the build system/scripts as well. But
each form should produce usable test-reports.

The first form usually is very project specific, but simple to implement.
Of note here that the project at least provides a single command line. The
output and return status resemble the test-report and test-status. The
configuration may get complex as more features are required.

The second form is an intermediate solution to support more features, while not
introducing any static local build commands yet. If source files are implicitly
(by some basename or tag, etc.) mapped to their test-suite/case files then we
can re-use routines from our ``build.lib.sh`` and sub-libs. With this setup we
can also provide with an explicit mapping file. Or possibly provide customized
shell functions locally.

Our improvement of the single-suite setup however still has no real dependency
resolving, except for the single mapping; and introducing more groupings makes
the script unneeded complex and even unwieldy. So at some point we will have a
hard time getting all the prerequisites for a certain test in order. Symptoms
are a complex CI scripting setup, and extended shell profile files.

The third form is the finally desired tooling setup, with each target being
rebuilt in the proper order. Some of these targets being test targets: groups
of targets that build report files. However to setup a system like that, we need
to know a lot more about our source files. What do they include or depend on,
how are they processed, where does everything go.

This is classically supported by make and redone many times. However make
shows it age somewhat, has some conflicting opinions, and is very focussed on
building C and programs; it is still the ancestor of source to computer code
systems and may teach us something how to do things even while building tests,
or documents.

Many new languages also come with their own ecosystem of builders, testers, and
replacements for Make. In the web world, using JS based asynchronous testers
(ie. grunt), or stream-based filter/transpile/build systems (gulp) are more
appropiate. Still all these require a minimum of shell vars to configure even
the most standardized framework setup, and there will be some flags and options
and path locations involved as well.

And so Java, Ruby, Python, Node or any of the more modern languages may provide
their own package to define a rule-based setup. Failing that, if we would be mad
and Makefile haters, then we could setup scripts for all targets manually, and
code up/down-stream dependencies explicitly, either by hand or some complex
customized ad-hoc setup. Which may be a nightmare to maintain. Luckily there
are better options.

But the point is that the end-choice depends on the project and team. Any of the
build-system I have seen can (or rather need to) execute shell commands. And
at these points we can call our own routines as well, and this is where
`User-Scripts`' ``lib_load`` and ``build.lib.sh`` and derivatives with our setup
comes in again.\ [*]_ They are a means to keep the build config clean, and
possibly reuse more generic routines abstracting the build further.

Using such Make/Ant/Grunt/... file in our project we can code all static targets
and let make resolve the build rules. A modern alternative is ``redo``, which
is nice because it is so language/format agnostic but allows any executable
script aside from Shell/Bash etc. as well.

The downside of all that choice is that we can't have them all without writing
code and meta for each rule system. Ie. choose one. Or mix/layer them as
required, just keep in mind the footnote on re-using shells. It is easy to let
a shell source a profile, but that means a lot of static variables may be
needed or scripts to reinitialize those which all has performance impacts.
This is usually solved per rule language in some path and script templating
features, substitution, macro variables, etc. Or else, our own commands can
evolve from shell routines to proper executable perhaps.

Finally making a bit of opinionated conclusion, I think redo, or old fashioned
make provides for reasonable setups. In practice, we'll see that CI systems and
other pipelines may have some variation. And the biggest challenge of a project
tooling setup is keeping it clear. Splitting up (ie. make or redo recipes)
helps. But so does something like a centralized code-book, from which various
processes can pick the variant command lines they require.

Besides the ``build{,-*}.lib.sh`` module and sub-modules this is why other
development focus lays on managing bits of code, and also trying the generalize
the metadata with `package.y*ml`_.

See also `Tools`_ (YAML/SH), and external projects `User-Conf`_ and `User-Scripts`_
for an older and current setup. Besides


.. [#] The downside of nodemon at least it that is resets the command on new
   changes. This wreaks havoc on some test-harnasses, potentially leaving
   processes and servics hanging. The path-polling solution of build.lib.sh
   ends a run before checking for changes, allowing it to complete and
   gracefully handle all steps and exceptions.

.. [*] Usually builder and tester frameworks isolate envs, and allocate
   new shells to each command requiring any variable/function profile to be
   re-sourced each time. E.g. Ant and Jenkins do this, and require addons to
   get around. CI systems like Travis CI or Docker Hub (while not rule systems)
   re-use a single (console?) shell for their build steps.
