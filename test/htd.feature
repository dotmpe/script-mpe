
Feature: Htd

  Scenario: prints existing main documents
    When the user runs "htd main-doc-paths"
    Then `output` should match:
    """
    ReadMe ReadMe.rst
    """


  @todo
  Scenario: lists journal paths tagged today, tomorrow and yesterday


  @todo
  Scenario: lists cabinet paths tagged today, tomorrow and yesterday


  @todo
  Scenario: shows open directories

  @todo
  Scenario: shows open resources

  @todo
  Scenario: bdd

    # http://superuser.com/questions/181517/how-to-execute-a-command-whenever-a-file-changes

  Scenario: I have list items structured, and the structure validated

    features (unit-test):
    - map field implementation to context attribute
    - structures are field which can contain other fields
    - base or root structure is context item, holds all root fields
    - each structure can impose rules, ie. schema can be drafted and used for 
      validation.
    - also for serialization some specific sequence rules are important.
    - there is a root text (w/o field or attribute name) that needs a place too,
      and then maybe other text spans?

    info
    - std todo.txt has no structs, and limits some tags very specifically:
      priority, date, hold. (and has no concept of cite)


  Scenario: I have list items added and removed by a context with update

    - XXX: id modes: key, attr...

  Scenario: I have list items updated by a metadata resolver matching the context

  
  Scenario: I have records creates for validated list items

