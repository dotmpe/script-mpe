
Feature: Htd

  Scenario: prints existing main documents
    When the user runs "htd main-doc-paths"
    Then `output` should match:
    """
    ReadMe.rst
    """


  @todo
  Scenario: lists journal paths tagged today, tomorrow and yesterday


  @todo
  Scenario: lists cabinet paths tagged today, tomorrow and yesterday


  @todo
  Scenario: shows open directories

  @todo
  Scenario: shows open resources


