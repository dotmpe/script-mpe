

     Feature: Boilerplate for a component test

  Background: a description about component, included before each scenario. This
contains basic settings for the user shell script runner, see `lib.feature` for
a good outline illustrating its various steps and usage of the runner.

# Setup scriptpath env
       Given the current script directory

# Set runner options/override runner opts from env
      #Given `opts` key `debug_output` 'on'
      #Given `opts` key `debug_stderr` 'on'
       Given `opts` key `debug_output_exc` 'on'
       Given `opts` key `debug_stderr_exc` 'on'
      #Given `opts` key `debug_command` 'off'
        
# Set env for user command or other user-exec
       Given `vars` key `VAR` 'value'

# Set final env expression, inerted before command after export
        Given `env` '. $scriptpath/util.sh'


    Scenario: something about the component
       Given  package env
       Given  deps os, sys and str
       Given  deps os, sys, str, date, main, src, argv, shell, list, match, box, functions and vc
        When  the user executes `false`...
         And  user runs `true`
         And  runs `echo foo 1`
         And  executes `echo foo 2`
         And  the user executes `echo foo 3`
        Then  executes `echo foo 5.1.1` ok
         And  execute `echo foo 5.1.2` ok
        Then  tests `echo foo 4.1`
        Then  test `echo foo 4.2`
        Then  tests `echo foo 5.4.1` ok
        Then  test `echo foo 5.4.2` ok
    #   #   #   #
