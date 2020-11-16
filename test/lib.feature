

     Feature: Libraries, paths, packages and metadata


  Background: To keep scripts going, some basic steps need to keep going. For the user-scripts steps baseline see runner.feature, this case focusses on initializing for and loading with `lib_load`.

       Given  the current script dir

        Then  assert `opts` key `debug_command` 'off'
        Then  assert `opts` key `debug_output` 'off'
        Then  assert `opts` key `debug_stderr` 'on'

        Then  assert `opts` key `debug_command_exc` 'on'
        Then  assert `opts` key `debug_output_exc` 'on'
        Then  assert `opts` key `debug_stderr_exc` 'on'


    Scenario: Function library load and init requires `lib_{load,init}`

       Given  `vars` key `lib_loaded` ''
       Given  `vars` key `U_S` '/srv/project-local/user-scripts'
       Given  `env` '. $U_S/tools/sh/parts/include.sh; init_sh_libs= verbosity=7'
        When   the user runs `. tools/sh/init.sh`?
        Then   `output` is empty
         And   `status` equals 0

              # Tested init.sh, use as default env now and continue tests
       Given  `vars` key `verbosity` ''
       Given  `vars` key `init_sh_libs` ''
       Given  `env` '. $U_S/tools/sh/parts/include.sh; . ./tools/sh/init.sh'

        When   the user runs `lib_load os sys std str`
        When   the user runs `lib_assert os sys std str`
        When   the user runs `lib_init`
        When   the user runs `lib_loaded`


    Scenario: Project settings from package metadata
        
        When   the user run `htd package update`


    Scenario: Project settings from package metadata
        
       Given   package env

#                                                                               vim:cc=13
