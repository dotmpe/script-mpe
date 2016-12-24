<?php

use Behat\Behat\Context\ClosuredContextInterface,
    Behat\Behat\Context\TranslatedContextInterface,
    Behat\Behat\Context\BehatContext,
    Behat\Behat\Exception\PendingException;
use Behat\Gherkin\Node\PyStringNode,
    Behat\Gherkin\Node\TableNode;

//
// Require 3rd-party libraries here:
//
//   require_once 'PHPUnit/Autoload.php';
//   require_once 'PHPUnit/Framework/Assert/Functions.php';
//

/**
 * Features context.
 */
class FeatureContext extends BehatContext
{
    /**
     * Initializes context.
     * Every scenario gets its own context object.
     *
     * @param array $parameters context parameters (set them up through behat.yml)
     */
    public function __construct(array $parameters)
    {
        // Initialize your context here
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
     * @Given /^a file "([^"]*)" containing:$/
     */
    public function aFileContaining($fileName, PyStringNode $contents)
    {
        file_put_contents($fileName, (string) $contents);
    }

    /**
     * @When /^the user runs:$/
     */
    public function theUserRunsMultiline(PyStringNode $command)
    {
        $this->theUserRuns((string) $command);
    }

    /**
     * @When /^the user runs "([^"]*)"(.*)?$/
     */
    public function theUserRuns($command, $withErrror)
    {
        $stderr = '.stderr'; # FIXME: proper session file
        exec((string) "$command 2>$stderr", $output, $return_var);
        if (!$withErrror and $return_var) {
            throw new Exception("Command return non-zero: '$return_var' for '$command'");
        }
        $this->status = $return_var;
        $this->output = trim(implode("\n", $output));
        $this->stderr = trim(file_get_contents($stderr));
        unlink($stderr);
    }

    /**
     * @Then /^file "([^"]*)" should be created, and contain the same as "([^"]*)"\.?$/
     */
    public function fileShouldBeCreatedAndContainTheSameAs($outputFileName, $expectedContentsFileName)
    {
        if (!file_exists($outputFileName)) {
            throw new Exception("File '$outputFileName' does not exist");
        }
        if (file_get_contents($outputFileName) !=
                file_get_contents($expectedContentsFileName)) {
            throw new Exception("File '$outputFileName' contents do not match '$expectedContentsFileName'");
        }
    }

    /**
     * @Then /^the file `([^`]+)` contains the pattern "([^"]+)"\.?$/
     */
    public function theFileContainsThePattern($outputFileName, $pattern)
    {
        if (!file_exists($outputFileName)) {
            throw new Exception("File '$outputFileName' does not exist");
        }
        $this->contents = file_get_contents($outputFileName);
    }

    /**
     * @Then /^`([^`]+)` contains the pattern "([^"]+)"\.?$/
     */
    public function thePropertyContainsThePattern($propertyName, $pattern)
    {
        $data = $this->$propertyName;
        $matches = array();
        preg_match($pattern, $data, $matches);
        if (!count($matches)) {
            throw new Exception("Pattern not found");
        }
    }

    /**
     * @Then /^`([^`]+)` should be:$/
     * @Then /^`([^`]+)` should match:$/
     */
    public function theOutputShouldMatch($propertyName, PyStringNode $string)
    {
        if ($string != $this->$propertyName) {
            //throw new Exception("'$propertyName' does not match '$string'");
            $out = explode(PHP_EOL, $this->$propertyName);
            $str = explode(PHP_EOL, $string);
            $extra = array_diff( $out, $str );
            $missing = array_diff( $str, $out );

            throw new Exception("Mismatched: "
                .implode(" +", $extra)
                .implode(" -", $missing)
              );
        }
    }

    /**
     * @Then /^`([^`]+)` should not be \'([^\']*)\'$/
     * @Then /^`([^`]+)` should not match \'([^\']*)\'$/
     */
    public function returnShouldNotBe($propertyName, $value)
    {
        if ("$value" == $this->$propertyName) {
            throw new Exception("'$propertyName' does match '$string'");
        }
    }

    /**
     * @Then /^`([^`]+)` should be empty.$/
     */
    public function outputShouldBeEmpty($propertyName)
    {
      if (!empty($this->$propertyName)) {
        throw new Exception("Not empty (but '{$this->$propertyName}')");
      }
    }
}
