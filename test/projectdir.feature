Feature: Project checkout handling
  
  Checkouts imply a source repository. A local folder represents a copy of a
  distinct body of work, and a means of distribution. For VCS detailed tracking
  of blobs stored in filetrees through time and parallel versions is possible.
  Technically publication back to the repository is easy, however while other
  checkouts maybe mere downloads. Ie. compressed filetree archives which in 
  themselves have no upstream publication and little to no tracking of blobs
  except by direct comparison or checksumming.

  All but the most minimal project is a composite of different works. One
  repository may be derived from another ofcourse, but more importantly
  components from other repositories may be needed during any project phase.

  As shown, not all repositories (and thus all checkouts) are equal. Besides the
  format (aka medium), the 'message' or purpose of a checkout (root) varies
  and recognition depends on the presence of different markers. Also, while some
  tracked states of the checkout may be present and readily reported on, others
  will be expensive to retrieve.


  @TODO
  Scenario: checkout paths and their source reposistory are recorded in the projectdoc

    # checkouts have a source with distribution mechanism

    # Projects are checkouts, with a worktree and specific states tied to it.
    # The projectdoc sits at the root of a directory containing projects, and
    # identifies each project both by ID and its prefix at this host/dir.


  @TODO
  Scenario: checkout paths are annotated with the projectdoc

    # projectdoc enables storage of control and state metadata

    # Pd needs to track state, and it does this by recording status and benchmark
    # numbers outside the project, in the projectdoc file where it can be
    # potentially distributed across hosts to other projectdirs. Or tied into
    # other CI/CD sytems.

    # It does not record reports but summarizes them into ID's and numbers.
    # And those it uses to track state too.


  @TODO
  Scenario: checkouts may be composite


  @todo
  Scenario: it intializes, checks, and then cleanup and deinitializes a compatible project without problems


  Scenario: list scm dirs - helps to find checkouts

      Given `env` 'verbosity=0'
      When the user executes "projectdir.py"
      Then the `status` is '0'
      #And the `output` is not empty


  Scenario: list untracked files - helps with project state

      Given `env` 'verbosity=0'
      When the user executes "projectdir.py find-untracked"
      Then the `status` is '0'
      #And the `output` is not empty
      #And the `output` contains ''

