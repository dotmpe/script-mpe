

     Feature: The feature-context should manage aspects of testing user-scripts

  Background: Since user scripts run in a separate (bash) interpreter that is not interactive, we need to concatenate all requirements from steps. The runner needs some options which are set from env or static defaults. See _boilerplate.feature for a complete set.
        
       Given  the current script dir


    Scenario: Defaults for (user) script dir/env runner

        # Then  env PWD equals the ProjectDir
        Then  `opts` key `debug_command` equals 'on'
         And  `opts` key `debug_stderr` equals 'on'

#                                                                               vim:cc=13
