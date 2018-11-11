<?php

use Behat\Behat\Context\SnippetAcceptingContext,
    Behat\Behat\Tester\Exception\PendingException,
    Behat\Gherkin\Node\PyStringNode,
    Behat\Gherkin\Node\TableNode;

include 'ContextPropertyTrait.php';
include 'FileContextTrait.php';
include 'UserExecContextTrait.php';
include 'OSContextTrait.php';
include 'TempContextTrait.php';
include 'ProjectContextTrait.php';


/**
 * Feature context.
 *
 * Attribute opts holds an array for settings affecting the test runner and
 * framework. Env and vars on the other hand are passed to the test command
 * environment.
 *
 * vars are exported first, then string env is evaluated. The default env
 * bootstrap is by sourcing '$scriptpath/util.sh'.
 *
 */
class FeatureContext implements SnippetAcceptingContext
{
    use ContextPropertyTrait;
    use FileContextTrait;
    use UserExecContextTrait;
    use OSContextTrait;
    use TempContextTrait;
    use ProjectContextTrait;

    /**
     * Initializes context.
     * Every scenario gets its own context object.
     */
    public function __construct()
    {
        $this->session_id = uniqid();
        $this->env = "";
        $this->stdin = null;
        $this->opts = array();
        $this->vars = array();

        $opt_keys = array( "debug_output", "debug_stderr",
            "debug_output_exc", "debug_stderr_exc" ) ;

        foreach ($opt_keys as $key) {
            if (array_key_exists($key, $_ENV)) {
                $this->opts[$key] = $_ENV[$key];
            }
        }

        $var_keys = array( "test_scriptpath", "test_verbosity" ) ;
        $this->vars['project_dir'] = $this->getProjectDir();
        foreach ($var_keys as $key) {
            if (array_key_exists($key, $_ENV)) {
                $this->vars[substr($key, 5)] = $_ENV[$key];
            }
        }

        // TODO allowedDirs add $projDir if option set?
        //$this->allowedDirs[] = '/private/tmp';
        //$this->allowedDirs[] = '/tmp';
        $this->allowedDirs[] = realpath('/tmp');
    }


    /**
     * Use 'the current project' setup, and then setup to load script-env and
     * runner options for 'the user runs'.
     *
     * @Given /^the current script directory,?$/
     * @Given /^the current script dir,?$/
     * @Given /^the current script path,?$/
     */
    public function theCurrentScriptDir()
    {
        $projDir = $this->theCurrentProject();
        if (!array_key_exists("scriptpath", $this->opts)) {
            $this->opts["scriptpath"] = $projDir;
        }
        foreach ($this->defaultOptions as $key => $value) {
            if (!array_key_exists($key, $this->opts)) {
                $this->opts[$key] = "on";
            }
        }
    }

    var $defaultOptions = array(
        "debug_command_exc" => "on",
        "debug_output_exc" => "on",
        "debug_stderr_exc" => "on"
    );

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

    public function _getenv() {
        $env = trim($this->env);

        # Prepend vars to literal env expression
        if (!empty($env)) {
            $env = "; $env ";
        }

        $vars = $this->vars or array();
        if (!isset($vars["verbosity"])) {
            // Show warnings and above by default, or override per scenario
            $vars["verbosity"] = 4;
        }
        if (!isset($vars["scriptpath"])) {
            $vars["scriptpath"] = getcwd();
        }
        foreach ($vars as $key=>$value) {
            $env = "$key=\"$value\" $env";
        }
        if (!empty($env)) {
            $env = "export $env;";
        }

        return $env;
    }
}
