<?php

use Behat\Behat\Context\SnippetAcceptingContext,
    Behat\Behat\Tester\Exception\PendingException,
    Behat\Gherkin\Node\PyStringNode,
    Behat\Gherkin\Node\TableNode;


/**
 * Features context.
 */
class SrvFeatureContext implements SnippetAcceptingContext
{
    /**
     * Initializes context.
     * Every scenario gets its own context object.
     */
    public function __construct()
    {
    }

    /**
     * @When the user runs any subcommand '' of srv
     */
    public function theUserRunsAnySubcommandOfSrv()
    {
        throw new PendingException();
    }

    /**
     * @Then the known states and current state for the service names are shown
     */
    public function theKnownStatesAndCurrentStateForTheServiceNamesAreShown()
    {
        throw new PendingException();
    }

    /**
     * @Then the identical data is shown
     */
    public function theIdenticalDataIsShown()
    {
        throw new PendingException();
    }

    /**
     * @Then warnings are shown for rogue \/srv\/* paths
     */
    public function warningsAreShownForRogueSrvPaths()
    {
        throw new PendingException();
    }

    /**
     * @When unitialized
     */
    public function unitialized()
    {
        throw new PendingException();
    }

    /**
     * @Then \/srv and LIST are undefined and the DB should not exist
     */
    public function srvAndListAreUndefinedAndTheDbShouldNotExist()
    {
        throw new PendingException();
    }

    /**
     * @Then schema is present in res\/srv.py and store\/at-Service*yml
     */
    public function schemaIsPresentInResSrvPyAndStoreAtServiceYml()
    {
        throw new PendingException();
    }

    /**
     * @Then the database is created and initialized with current schema
     */
    public function theDatabaseIsCreatedAndInitializedWithCurrentSchema()
    {
        throw new PendingException();
    }

    /**
     * @Then views to join\/denormalize certain record ID mappings into useful, presentable rows
     */
    public function viewsToJoinDenormalizeCertainRecordIdMappingsIntoUsefulPresentableRows()
    {
        throw new PendingException();
    }

    /**
     * @Then the locally found volumes are initialized
     */
    public function theLocallyFoundVolumesAreInitialized()
    {
        throw new PendingException();
    }

    /**
     * @Then remote volumes are by default added, for selected domains
     */
    public function remoteVolumesAreByDefaultAddedForSelectedDomains()
    {
        throw new PendingException();
    }

    /**
     * @Then the \/srv directory is updated from the text entries of LIST tagged `@Service`
     */
    public function theSrvDirectoryIsUpdatedFromTheTextEntriesOfListTaggedService()
    {
        throw new PendingException();
    }

    /**
     * @Then the LIST has `@Service` tagged entries for existing and new service container instances
     */
    public function theListHasServiceTaggedEntriesForExistingAndNewServiceContainerInstances()
    {
        throw new PendingException();
    }
}
