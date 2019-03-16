<?php

use Behat\Gherkin\Node\PyStringNode;

/**
 * Partial class for FeatureContext adding user-command handling steps.
 */
trait UserExecContextTrait {

    var $booleanOptions = array(
        "on" => true, "off" => false,
        "yew" => true, "no" => false,
        "true" => true, "false" => false,
        "1" => true, "0" => false
    );

    public function parseBooleanOption($key)
    {
        $value = $this->opts[$key];
        if (!array_key_exists($value, $this->booleanOptions)) {
            return false;
        }
        return $this->booleanOptions[$value];
    }

    /**
     * Execute command, and set `status`, `output`, `stderr`.
     *
     * Use trailing period(s) or question-mark to allow non-zero exit status,
     * otherwise fail step. Versions with different qoutes are offered to allow
     * verbatim passing of other quotes. The multiline version allows anything.
     *
     * See env and vars context-properties to provide env vars and other
     * expressions apart from the command-line.
     *
     * @Then /^(?:tests?) `([^`]*)`(?: ok)?(\?|\.+)?$/
     * @Then /^(?:tests?) '([^']*)'(?: ok)?(\?|\.+)?$/
     * @Then /^(?:tests?) "([^"]*)h(?: ok)?(\?|\.+)?$/
     * @When /^(?:(runs?|executes?)) `([^`]*)`(?: ok)?(\?|\.+)?$/
     * @When /^(?:(runs?|executes?)) '([^']*)'(?: ok)?(\?|\.+)?$/
     * @When /^(?:(runs?|executes?)) "([^"]*)h(?: ok)?(\?|\.+)?$/
     * @When /^(?:the )?user (?:(?:runs?|executes?) )?`([^`]*)`(\?|\.+)?$/
     * @When /^(?:the )?user (?:(?:runs?|executes?) )?'([^']*)'(\?|\.+)?$/
     * @When /^(?:the )?user (?:(?:runs?|executes?) )?"([^"]*)"(\?|\.+)?$/
     */
    public function theUserRuns($command_line, $withErrror='')
    {
        $stderr = ".behat-userexec-{$this->session_id}.stderr";
        $local_prefix = $this->_getenv();
        $command = trim($command_line);
        if (substr($command, -1, 1) != ';') {
            $command .= ';';
        }

        if ($this->stdin) {
            $exec = "{ {$this->stdin} | { $local_prefix $command }; } 2> $stderr";
            $this->stdin = '';
        } else {
            $exec = "{ $local_prefix $command } 2> $stderr";
        }
        exec("\$SHELL -c '$exec'", $output, $return_var);
        $this->status = $return_var;
        $this->output = trim(implode(PHP_EOL, $output));
        $this->stderr = trim(file_get_contents($stderr));
        unlink($stderr);

        if (!$withErrror and $return_var) {
            if ($this->parseBooleanOption('debug_command_exc')) {
                echo "$exec".PHP_EOL;
            }
            if ($this->parseBooleanOption('debug_stderr_exc')) {
                echo $this->stderr.PHP_EOL;
            }
            if ($this->parseBooleanOption('debug_output_exc')) {
                echo $this->output.PHP_EOL;
            }
            $msg = "Command return non-zero: '$return_var' for '$command'";
            throw new Exception($msg);

        } else {
            if ($this->parseBooleanOption('debug_command')) {
                echo "$exec".PHP_EOL;
            }
            if ($this->parseBooleanOption('debug_output')) {
                if (!empty($this->output)) {
                    echo "Output:".PHP_EOL;
                    echo $this->output.PHP_EOL;
                }
            }
            if ($this->parseBooleanOption('debug_stderr')) {
                if (!empty($this->stderr)) {
                    echo "Stderr:".PHP_EOL;
                    echo $this->stderr.PHP_EOL;
                }
            }
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
}
