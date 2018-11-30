default:

target-1: prereq-1 prereq-2

target-2:: prereqs

target-1a: var := foo
target-1a:

target-2a:: var := foo
target-2a::

target-3a: ; echo line

target-3b: ; @echo line
