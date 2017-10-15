
Feature: srv

  Background:
    The current status of /srv/ is reflected in LIST, or list_name. It is the staging area for commits to the DB records. This makes srv.py effectively a variant on the list.py processor, while it is also a schema module for db_sa.py. Scrpipt srv.sh is the intendent srv frontend, and comes with a similar dependence on list processor capabilities in htd. Finally the todo.txt extended LIST formatting is preferred to using YAML.


  Scenario: service container lifecycle

    When the user runs ``srv run``
    Then the known states and current state for the service names are shown

    When the user runs ``list_name=data/srv.txt htd storage Service status``
    Then the identical data is shown


  Scenario: generic reports in summary, brief and complete formats


  Scenario: on run, see about rogue paths

    When the user runs any subcommand '' of srv
    Then warnings are shown for rogue /srv/* paths


  Scenario: on inital run, volumes

    When unitialized
    Then /srv and LIST are undefined and the DB should not exist
    And schema is present in res/srv.py and store/at-Service*yml

    When the user runs ``srv init``
    Then the database is created and initialized with current schema
    And views to join/denormalize certain record ID mappings into useful, presentable rows


    Then the locally found volumes are initialized
    And remote volumes are by default added, for selected domains
    

  
  Scenario: given DB or LIST an object data serialization can be produced, and the instance data's scheme be validated


  Scenario: /srv is reflected to LIST or vice versa

    When the user runs ``srv apply``
    When the user runs ``htd storage Service apply``
    Then the /srv directory is updated from the text entries of LIST tagged `@Service`

    When the user runs ``htd storage Service update``
    Then the LIST has `@Service` tagged entries for existing and new service container instances


