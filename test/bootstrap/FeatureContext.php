<?php

use Behat\Behat\Context\SnippetAcceptingContext,
    Behat\Behat\Tester\Exception\PendingException,
    Behat\Gherkin\Node\PyStringNode,
    Behat\Gherkin\Node\TableNode;

include 'ContextPropertyTrait.php';
include 'FileContextTrait.php';
include 'UserExecContextTrait.php';
include 'OSContextTrait.php';


/**
 * Features context.
 */
class FeatureContext implements SnippetAcceptingContext
{
    use ContextPropertyTrait;
    use FileContextTrait;
    use UserExecContextTrait;
    use OSContextTrait;

    /**
     * Initializes context.
     * Every scenario gets its own context object.
     */
    public function __construct()
    {
        $this->session_id = uniqid();
        $this->env = "";
        $this->stdin = null;
    }

    /**
     * @Given /^the current project,$/
     */
    public function theCurrentProject()
    {
        $projDir = dirname(dirname(dirname(__FILE__)));
        if (getcwd() != $projDir) {
            chdir($projDir);
        }
    }

    /**
     * @Then /^"([^"]*)" is an command-line executable with ([^\ ]+) behaviour$/
     */
    public function isAnCommandLineExecutable($cmd, $class)
    {
        $class = str_replace('.', '', $class);
        switch ($class) {
            case "std":
                throw new PendingException("Todo run CLI outline ... $cmd $class");
                break;
            default:
                throw new PendingException("Foo $cmd $class");
        }
    }
}
