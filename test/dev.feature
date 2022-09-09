Feature: project deployment, monitoring, standalone dev helpers

  Background: Project-lifecycle needs a few addons.
        
  Scenario: extract and update tasks, issues
    tasks

  Scenario: compile and view benchmarks
    stats
    update

  Scenario: running instances
    create
    start
    status
    stop
    delete/destroy

  Scenario: working with projectdirs
    enable
    init/update
    show
    disable

#                                                                               vim:cc=13
