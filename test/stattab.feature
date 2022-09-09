

     Feature: track status in plain-text table


  Background: the `stattab.lib` is tested with `htd` frontend, using `package.y*ml` for project settings

       Given  the current commandpath
       Given  package env
       Given  deps os, sys, str, match, table, date and build


    Scenario: can add new status, track entry time, and update

      Given  `vars` key `new_ctime` '1539038820'
      Given  `vars` key `new_short` "Some entry" 

       When  the user runs `htd sttab new`
       Then  file '.statusdir/index/stattab.list' lines equal:
              """
              # status ctime     entry-id        short  @ctx
              - 20181009-0047+02 test-script-1 Some script @Std
              """

#                                                                               vim:cc=13
