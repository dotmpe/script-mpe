Feature: statusdir records with any backend

    Scenario Outline: statusdir behaves normally
        Given `env` '<env>'

        When the user runs 'statusdir.sh ping'
        Then `stderr` is empty
        And `status` is '0'
        When the user runs 'statusdir.sh foo'...
        Then `stderr` is not empty
        And `status` is not '0'
        When the user runs 'statusdir.sh help'
        Then `output` is not empty
        Then `stderr` is empty
        When the user runs 'statusdir.sh version'
        Then `output` is not empty
        And `stderr` is empty
        When the user runs 'statusdir.sh backend'
        Then `output` should match '^<be_name>.*'
        Then `stderr` not empty
        And `status` is '0'

        Examples:
            | env | be_name |
            | sd_be=fsdir | fsdir |
            | sd_be=redis | redis |
            | sd_be=membash | memcache |
            | sd_be=couchdb_sh COUCH_DB=test | couchdb |

    Scenario: couch backend
        Given `env` 'sd_be=couchdb_sh COUCH_URL=ABC COUCH_DB=xyz'
        When the user runs 'statusdir.sh backend'
        Then `output` should be 'couchdb ABC xyz'

    Scenario Outline: statusdir records numbers
        Given `env` '<env>'

        When user executes 'statusdir.sh del mykey1'..
        When user executes 'statusdir.sh get mykey1'..
        Then `status` is not '0'

        When the user runs 'statusdir.sh set mykey1 10'
        Then `stderr` is empty
        And `status` is '0'

        When user executes 'statusdir.sh get mykey1'
        Then `stderr` is empty
        And `output` equals '10'
        
        And the user executes 'statusdir.sh del mykey1'
        Then `stderr` is empty
        And `status` is '0'

        Examples:
            | env |
            | sd_be=fsdir |
            | sd_be=redis |
            | sd_be=membash |
            | sd_be=couchdb_sh COUCH_DB=test |


    Scenario Outline: some backens increment and decrement numbers
        Given `env` '<env>'

        When the user runs 'statusdir.sh set mykey1 10'
        Then `stderr` is empty
        And `status` is '0'

        When the user executes 'statusdir.sh incr mykey1'
        Then `stderr` is empty
        And `output` equals '11'
        
        When the user executes 'statusdir.sh decr mykey1'
        And the user executes 'statusdir.sh decr mykey1'
        Then `stderr` is empty
        And `output` equals '9'

        * the user executes 'statusdir.sh del mykey1'

        Examples:
            | env |
            | sd_be=fsdir |
            | sd_be=redis |
            | sd_be=membash |
            | sd_be=couchdb_sh COUCH_DB=test |


    Scenario Outline: statusdir records strings
        # TODO , and sets of strings
        Given `env` '<env>'

        When user executes 'statusdir.sh del mykey1'..
        When user executes 'statusdir.sh get mykey1'..
        Then `status` is not '0'

        When the user runs 'statusdir.sh set mykey1 str'
        Then `stderr` is empty
        And `status` is '0'

        When user executes 'statusdir.sh get mykey1'
        Then `stderr` is empty
        And `output` equals 'str'
        
        And the user executes 'statusdir.sh del mykey1'
        Then `stderr` is empty
        And `status` is '0'

        Examples:
            | env |
            | sd_be=fsdir |
            | sd_be=redis |
            | sd_be=membash |
            | sd_be=couchdb_sh COUCH_DB=test |

    @todo
    Scenario: statusdir records simple JSON structures

