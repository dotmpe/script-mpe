<?php

use Behat\Gherkin\Node\PyStringNode;


trait UserExecContextTrait {

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
		if ($this->stdin) {
			$exec = "{$this->stdin} | $env $command 2>$stderr";
			$this->stdin = '';
		} else {
			$exec = "$env $command 2>$stderr";
		}
		exec($exec, $output, $return_var);
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
}
