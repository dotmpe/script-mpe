<?php

use Behat\Behat\Context\SnippetAcceptingContext,
    Behat\Behat\Tester\Exception\PendingException,
    Behat\Gherkin\Node\PyStringNode,
    Behat\Gherkin\Node\TableNode;


/**
 * Features context.
 */
class FeatureContext implements SnippetAcceptingContext
{
    /**
     * Initializes context.
     * Every scenario gets its own context object.
     */
    public function __construct()
    {
        $this->session_id = uniqid();
        $this->env = "";
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
     * Store multiline into file.
     *
     * @Given /^a file "([^"]*)" containing:$/
     */
    public function aFileContaining($fileName, PyStringNode $contents)
    {
        file_put_contents($fileName, (string) $contents);
    }

    /**
     * @Given `:ctx` :arg1
     */
    public function env($ctx, $arg1)
    {
        $this->$ctx = $arg1;
    }

    /**
     * Execute command, and set `status`, `output`, `stderr`.
     * Use trailing period(s) or question-mark to allow non-zero exit status,
     * otherwise fail step. Versions with different qoutes are offered to allow
     * verbatim passing of other quotes. The multiline version allows anything.
     *
     * When user executes :arg1
     * When the user runs :arg1
     * @When /^(?:the )?user (?:(?:runs|executes) )?`([^`]*)`(\?|\.+)?$/
     * @When /^(?:the )?user (?:(?:runs|executes) )?'([^']*)'(\?|\.+)?$/
     * @When /^(?:the )?user (?:(?:runs|executes) )?"([^"]*)"(\?|\.+)?$/
     */
    public function theUserRuns($command, $withErrror='')
    {
        $stderr = ".{$this->session_id}.stderr";
        $env = $this->env or '';
        exec((string) "$env $command 2>$stderr", $output, $return_var);
        $this->status = $return_var;
        $this->output = trim(implode("\n", $output));
        $this->stderr = trim(file_get_contents($stderr));
        unlink($stderr);
        if (!$withErrror and $return_var) {
            throw new Exception("Command return non-zero: '$return_var' for '$command'");
        }
    }

    /**
     * Like theUserRuns but accepts multiline command.
     * Use trailing period(s) or question-mark to allow non-zero exit status,
     * otherwise fail step.
     *
     * @see theUserRuns()
     * @When /^user runs:(\?|\.*)$/
     * @When /^the user runs:(\?|\.*)$/
     * @When /^user executes:(\?|\.*)$/
     * @When /^the user executes:(\?|\.*)$/
     */
    public function theUserRunsMultiline($withErrror, PyStringNode $command)
    {
        $this->theUserRuns((string) $command, $withErrror);
    }

    /**
     * @Then file :arg1 contains:
     * @Then file :arg1 should have:
     * @Then file :arg1 contents should equal:
     * @Then file :arg1 contents should be equal to:
     */
    public function fileShouldHave($arg1, PyStringNode $arg2)
    {
        if (!file_exists($arg1)) {
            throw new Exception("File '$arg1' does not exist");
        }
        if (file_get_contents($arg1) != $arg2) {
            throw new Exception("File '$arg1' contents do not match second argument");
        }
    }

    /**
     * @Then /^file "([^"]*)" should be created, and contain the same as "([^"]*)"\.?$/
     * @Then /^"([^"]*)" is created, same contents as "([^"]*)"\.?$/
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
     * Read file contents to `contents`, then check value using regex.
     *
     * @Then /^the file `([^`]+)` contains the pattern '([^"]+)'\.?$/
     * @Then /^the file `([^`]+)` contains '([^"]+)'\.?$/
     */
    public function theFileContainsThePattern($outputFileName, $pattern)
    {
        if (!file_exists($outputFileName)) {
            throw new Exception("File '$outputFileName' does not exist");
        }
        $this->contents = file_get_contents($outputFileName);
        $this->ctxPropertyPregForPattern("output", $pattern);
    }

    /**
     * Test an attribute of the context, compare modes are:
     * equals, contains-string and contains-line for exact
     * (partial) string comparisons. Modes contains and
     * match(es) trigger regex comparison.
     *
     * @Then `:attr` should :mode the pattern :arg1
     * @Then `:attr` should :mode :arg1
     * @Then `:attr` :mode the pattern :arg1
     * @Then `:attr` :mode :arg1
     */
    public function ctxPropertyCmp($propertyName, $mode, $spec)
    {
        if ("$spec" == "empty") {
            if (!empty($this->$propertyName)) {
                throw new Exception("Not empty (but '{$this->$propertyName}')");
            }
            return;
        }
        if ($mode=="be" or $mode=="is" or substr($mode, 0, 5)=='equal') {
            if ("$spec" != "{$this->$propertyName}") {
                throw new Exception("$propertyName is '{$this->$propertyName}' and does not equal '$spec'");
            }
        } else if (substr($mode, 0, 9) == 'contains-') {
            throw new Exception("TODO $mode");
        } else if (
            substr($mode, 0, 7) == 'contain' ||
            substr($mode, 0, 5) == 'match'
        ) {
            $matches = $this->pregForPattern($this->$propertyName, $mode, $spec);
            if (!count($matches)) {
                throw new Exception("Pattern '$spec' not found");
            }
        } else {
            throw new Exception("Unknown property compare mode '$mode'");
        }
    }

    /**
     * Test an attribute of the context, compare modes are:
     * equals, contains-string and contains-line for exact
     * (partial) string comparisons. Modes contains and
     * match(es) trigger regex comparison.
     *
     * @Then `:attr` should not :mode the pattern :arg1
     * @Then `:attr` should not :mode :arg1
     * @Then `:attr` not :mode the pattern :arg1
     * @Then `:attr` not :mode :arg1
     * @Then `:attr` :mode not :arg1
     */
    public function ctxPropertyNotCmp($propertyName, $mode, $spec)
    {
        if ("$spec" == "empty") {
            if (empty($this->$propertyName)) {
                throw new Exception("$propertyName is empty");
            }
            return;
        }
        if ($mode=="be" or $mode=="is" or substr($mode, 0, 5) == 'equal') {
            if ("$spec" == "{$this->$propertyName}") {
                throw new Exception(" $propertyName is '{$this->$propertyName}' and matches '$spec'");
            }
        } else if (substr($mode, 0, 9) == 'contains-') {
            throw new Exception("TODO $mode");
        } else if (
            substr($mode, 0, 7) == 'contains' ||
            substr($mode, 0, 5) == 'match'
        ) {
            $matches = $this->pregForPattern($this->$propertyName, $mode, $spec);
            if (count($matches)) {
                throw new Exception("Pattern '$spec' found");
            }
        } else {
            throw new Exception("Unknown property compare mode '$mode'");
        }
    }

    /**
     * Match string against regular expression.
     * Mode is 'contains' for Match-All for submatches, or 'match' for start-to
     * end.
     */
    public function pregForPattern($string, $mode, $pattern)
    {
        $matches = array();
        if (substr($mode, 0, 7) == 'contain') {
            preg_match_all("/$pattern/", $string, $matches);
        } else if (substr($mode, 0, 5) == 'match') {
            preg_match("/$pattern/", $string, $matches);
        } else {
            throw new Exception("Unknown preg-for mode '$mode'");
        }
        return $matches;
    }

    /**
     * Test an attribute of context with every line from patterns as regex.
     *
     * @Then `:attr` :mode:
     * @Then `:attr` :mode the patterns:
     * @Then /^`([^`]+)` ((contain|match)[es]*) the patterns:$/
     * @Then /^`([^`]+)` ((contain|match)[es]*) patterns:$/
     */
    public function ctxPropertyContainsThePatterns($propertyName, $mode, PyStringNode $specs)
    {
        if ($mode=="equals") {
            $this->ctxPropertyShouldEqualMultiline($propertyName, $specs);
        } else {
            $specs = explode(PHP_EOL, $specs);
            array_pop($specs);
            foreach ($specs as $idx => $spec ) {
                $this->ctxPropertyPregForPattern($propertyName, $mode, trim($spec));
            }
        }
    }

    /**
     * @Then each `:attr` line :mode the pattern :pattern
     * @Then /^each `([^`]+)` line ((?:contain|match)[es]*) \'([^\']*)\'$/
     */
    public function ctxPropertyLinesEachPreg($propertyName, $mode, $pattern)
    {
        $lines = explode(PHP_EOL, $this->$propertyName);
        array_pop($lines);
        foreach ($lines as $line) {
            $matches = $this->pregForPattern($line, $mode, $pattern);
            if (!count($matches)) {
                throw new Exception("Pattern '$pattern' not found at '$line'");
            }
        }
    }

    /**
     * @Then each `:attr` line :mode the patterns:
     * @Then each `:attr` line :mode:
     */
    public function ctxPropertyLinesEachPregMultiline($propertyName, $mode, PyStringNode $pattern_ml)
    {
        $patterns = explode(PHP_EOL, $pattern_ml);
        array_pop($patterns);
        foreach ($patterns as $pattern) {
            $this->ctxPropertyLinesEachPreg($propertyName, $mode, $pattern);
        }
    }

    /**
     * Compare all lines (contains), or some lines (has) or look for patterns.
     *
     * @Then `:attr` :mode the lines:
     */
    public function ctxPropertyLinesMultiline($propertyName, $mode, PyStringNode $lines)
    {
        if ($mode == 'contains') {
            $this->ctxPropertyShouldEqualMultiline($propertyName, $lines);
        } else if ($mode == 'has') {
            $this->ctxPropertyHasLinesMultiline($propertyName, $lines);
        } else {
            $this->ctxPropertyLinesEachPregMultiline($propertyName, $mode, $lines);
        }
    }

    public function ctxPropertyHasLinesMultiline($propertyName, $lines)
    {
        $arr_lines = explode(PHP_EOL, $lines);
        array_pop($arr_lines);
        $content = explode(PHP_EOL, $this->$propertyName);
        array_pop($content);
        foreach ($arr_lines as $line) {
            if (!in_array($line, $content)) {
                throw new Exception("Expected '$line' line in $propertyName");
            }
        }
    }

    /**
     * Compare given attribute value line-by-line for exact match.
     *
     * @Then `:propertyName` should match:
     * @Then `:propertyName` should equal:
     * @Then /^`([^`]+)` should be:$/
     * @Then /^`([^`]+)` should equal:$/
     * @Then /^`([^`]+)` matches:$/
     */
    public function ctxPropertyShouldEqualMultiline($propertyName, PyStringNode $string)
    {
        if ($string != $this->$propertyName) {

            $out = explode(PHP_EOL, $this->$propertyName);
            array_pop($out);
            $str = explode(PHP_EOL, $string);
            array_pop($str);
            $extra = array_diff( $out, $str );
            $missing = array_diff( $str, $out );

            throw new Exception("Mismatched: "
                    .implode(" +", $extra)
                    .implode(" -", $missing)
                );
        }
    }

    /**
     * Store a context value for later use by name.
     *
     * @Given /^property "([^"]*)" with value \'([^\']*)\'$/
     */
    public function ctxPropertySetting($propertyName, $value)
    {
        $this->$propertyName = $value;
    }

    /**
     * @Then /^`([^`]+)` should equal contents of \"([^\']*)\"$/
     * @Then /^`([^`]+)` equals \"([^\']*)\" contents$/
     */
    public function ctxPropertyShouldEqualContents($propertyName, $filename)
    {
        $string = file_get_contents($filename);
        if ("$string" != "{$this->$propertyName}") {
            throw new Exception(" $propertyName value does not equal to contents of '$filename'");
        }
    }


    /**
     * @Given /^the project and localhost environment$/
     */
    public function theProjectAndLocalhostEnvironment()
    {
        throw new PendingException();
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

    /**
     * @Given /^the output of "([^"]*)" does not (contain|match) pattern "([^"]*)"$/
     */
    public function theOutputOfDoesNotContainPattern($command, $mode, $pattern)
    {
        $this->theUserRuns($command, false);
        $this->ctxPropertyPregForPattern("output", $mode, $pattern);
    }

    /**
     * Cleanup files matching glob spec.
     *
     * @Then cleanup :spec
     */
    public function cleanupFile($spec)
    {
        foreach (glob($spec) as $filename) {
            if (file_exists($filename)) {
                unlink($filename);
            }
        }
    }

    /**
     * Fail if path does not exists, or on failing match in glob spec.
     *
     * @Given file :spec exists
     * @Given :type path :spec exists
     * @Given a :type :spec exists
     * @Given /^that (\w*) paths "([^"]*)" exists $/
     */
    public function pathExists($spec, $type='file')
    {
        $this->{"pathname_type_${type}"}($spec, True);
    }

    /**
     * Fail if path exists, or on matching glob spec.
     *
     * @Given no file :spec exists
     * @Given no :type path :spec exists
     * @Given a :type :spec doesn't exist
     * @Given /^that (\w*) paths "([^"]*)" doesn't exist $/
     */
    public function noPathExists($spec, $type='file')
    {
        $this->{"pathname_type_${type}"}($spec, False);
    }

    public function pathname_type_directory($spec, $exists=True)
    {
        foreach (glob($spec, GLOB_BRACE|GLOB_NOCHECK) as $pathname) {
            if ($exists) {
                if (!is_dir($pathname)) {
                    throw new Exception("Directory '$pathname' does not exist, it should");
                }
            } else {
                if (is_dir($pathname)) {
                    throw new Exception("Directory '$pathname' exists, it shouldn't");
                }
            }
        }
    }

    public function pathname_type_file($spec, $exists=True)
    {
        foreach (glob($spec, GLOB_BRACE|GLOB_NOCHECK) as $pathname) {
            if ($exists) {
                if (!file_exists($pathname)) {
                    throw new Exception("File '$pathname' does not exist, it should");
                }
            } else {
                if (file_exists($pathname)) {
                    throw new Exception("File '$pathname' exists, it shouldn't");
                }
            }
        }
    }

    /**
     * @Then /^`([^`]+)` has( not)? (exactly|more|less)(?: than)?( or equal to)? ([0-9]+) lines$/
     */
    public function countFilelines($propertyName, $invert, $mode, $or_equal, $linecount)
    {
        $lines_arr = explode(PHP_EOL, $this->$propertyName);
        array_pop($lines_arr);
        $lines = count($lines_arr);
        if ($invert) {
            $or_equal = !$or_equal;
            if ($mode == 'more') { $mode = 'less'; }
            else if ($mode == 'less') { $mode = 'more'; }
        }
        if ($mode == 'more') {
            if ($or_equal and $lines < intval($linecount) or $lines <= intval($linecount)) {
                throw new Exception("Length was $lines");
            }
        }
        else if ($mode == 'less') {
            if ($or_equal and $lines > intval($linecount) or $lines >= intval($linecount)) {
                throw new Exception("Length was $lines");
            }
        }
        else if ($mode == 'exactly') {
            if ($lines != intval($linecount)) {
                throw new Exception("Length was $lines");
            }
        } else {
            throw new Exception("Unknown count-file-lines '$mode'");
        }
    }
}
