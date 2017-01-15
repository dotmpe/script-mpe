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
   * @When /^the user runs:(\.+)?$/
   */
  public function theUserRunsMultiline($withErrror, PyStringNode $command)
  {
    $this->theUserRuns((string) $command, $withErrror);
  }

  /**
   * @When /^the user runs "([^"]*)"(\.+)?$/
   */
  public function theUserRuns($command, $withErrror='')
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
   * @Then /^`([^`]+)` (contains|matches) the pattern "([^"]+)"\.?$/
   */
  public function thenPropertyPregForPattern($propertyName, $mode, $pattern)
  {
    $data = $this->$propertyName;
    $matches = array();
    //echo "/$pattern/".PHP_EOL;
    if ($mode == 'contains') {
      preg_match_all("/$pattern/", $data, $matches);
    } else {
      preg_match("/$pattern/", $data, $matches);
    }
    if (!count($matches)) {
      throw new Exception("Pattern not found");
    }
  }

  /**
   * @Then /^`([^`]+)` (contains|matches) the patterns:$/
   */
  public function thePropertyContainsThePatterns($propertyName, $mode, $patterns)
  {
    $patterns = explode(PHP_EOL, $patterns);
    foreach ($patterns as $idx => $pattern ) {
      $this->thenPropertyPregForPattern($propertyName, $mode, trim($pattern));
    }
  }

  /**
   * Compare given attribute value line-by-line.
   *
   * @Then /^`([^`]+)` should be:$/
   * @Then /^`([^`]+)` should match:$/
   */
  public function theOutputShouldMatch($propertyName, PyStringNode $string)
  {
    if ($string != $this->$propertyName) {

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
   * @Then /^`([^`]+)` should be \'([^\']*)\'$/
   * @Then /^`([^`]+)` should match \'([^\']*)\'$/
   */
  public function returnShouldBe($propertyName, $string)
  {
    if ("$string" != $this->$propertyName) {
      throw new Exception(" $propertyName is '{$this->$propertyName}' and does not match '$string'");
    }
  }

  /**
   * @Then /^`([^`]+)` should not be \'([^\']*)\'$/
   * @Then /^`([^`]+)` should not match \'([^\']*)\'$/
   */
  public function returnShouldNotBe($propertyName, $string)
  {
    if ("$string" == $this->$propertyName) {
      throw new Exception(" $propertyName is '{$this->$propertyName}' and matches '$string'");
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


  /**
   * @Given /^the project and localhost environment$/
   */
  public function theProjectAndLocalhostEnvironment()
  {
    # NOTE: theProjectAndLocalhostEnvironment: Current dir & host should be fine
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
