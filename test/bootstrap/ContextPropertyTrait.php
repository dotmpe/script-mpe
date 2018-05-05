<?php

use Behat\Behat\Tester\Exception\PendingException,
	Behat\Gherkin\Node\PyStringNode,
	Behat\Gherkin\Node\TableNode;


trait ContextPropertyTrait {

	/**
	 * Store value on context for later use by name reference.
	 *
	 * @Given /^property "([^"]*)" with value \'([^\']*)\'$/
	 */
	public function ctxPropertySetting($propertyName, $value)
	{
		$this->$propertyName = $value;
	}

//  All these should be superseded by ctxPropertyCmd
//    /**
//     * Literal string comparison, no expansion whatsoever.
//     * To negate @see ctxPropertyShouldNotEqual.
//     *
//	 * @Then `:propertyName` should be ':string'
//	 * @Then `:propertyName` should equal ':string'
//	 * @Then `:propertyName` has value ':string'
//	 * @Then `:propertyName` equals ':string'
//	 */
//	public function ctxPropertyShouldEqual($propertyName, $string) {
//		if ("$string" != "{$this->$propertyName}") {
//			throw new Exception(" $propertyName is '{$this->$propertyName}' and does not match '$string'");
//		}
//	}
//
//	/**
//	 * @Then `:propertyName` should not equal ':string'
//	 * @Then /^`([^`]+)` should not equal \'([^\']*)\'$/
//	 * @Then /^`([^`]+)` should not be \'([^\']*)\'$/
//	 */
//	public function ctxPropertyShouldNotEqual($propertyName, $string) {
//		if ("$string" == "{$this->$propertyName}") {
//			throw new Exception(" $propertyName is '{$this->$propertyName}' and matches '$string'");
//		}
//	}
//
//	/**
//	 * @Then /^`([^`]+)` should be empty.?$/
//	 */
//	public function ctxPropertyShouldBeEmpty($propertyName) {
//		if (!empty($this->$propertyName)) {
//			throw new Exception("Not empty (but '{$this->$propertyName}')");
//		}
//	}

	/**
	 * Test an attribute of the context, compare modes are:
	 * equals, contains-string and contains-line for exact
	 * (partial) string comparisons. Modes contains and
	 * match(es) trigger regex comparison.
	 *
	 * @Then `:attr` should :mode the pattern :spec
	 * @Then `:attr` should :mode :spec
	 * @Then `:attr` :mode the pattern :spec
	 * @Then `:attr` :mode :spec
	 * @Then the `:attr` :mode :spec
	 */
	public function ctxPropertyCmp($propertyName, $mode, $spec)
	{
		if (substr("$spec", 0, 5) == "empty") {
			if (!empty($this->$propertyName)) {
				throw new Exception("Not empty (but '{$this->$propertyName}')");
			}
			return;
		}
		if ($mode=="has" or $mode=="be" or $mode=="is" or substr($mode, 0, 5)=='equal') {
			if ("$spec" != "{$this->$propertyName}") {
				throw new Exception("$propertyName is '{$this->$propertyName}' and does not equal '$spec'");
			}
		} else if (substr($mode, 0, 9) == 'contains-') {
			throw new Exception("TODO $mode");
		} else if (
			substr($mode, 0, 7) == 'contain' ||
			substr($mode, 0, 5) == 'match'
		) {
			$this->ctxPropertyPregForPattern($propertyName, $mode, $spec);
		} else {
			throw new Exception("Unknown property compare mode '$mode'");
		}
	}

	function ctxPropertyPregForPattern($propertyName, $mode, $spec)
	{
		$matches = $this->pregForPattern($this->$propertyName, $mode, $spec);
		if (!count($matches)) {
			throw new Exception("Pattern '$spec' not found");
		}
	}

	/**
	 * Test an attribute of the context, compare modes are:
	 * equals, be/is/has, contains-string and contains-line for exact
	 * (partial) string comparisons. Modes contains and
	 * match(es) trigger regex comparison.
	 *
	 * @Then `:attr` should not :mode the pattern :spec
	 * @Then `:attr` should not :mode :spec
	 * @Then `:attr` not :mode the pattern :spec
	 * @Then `:attr` not :mode :spec
	 * @Then `:attr` :mode not :spec
	 * @Then the `:attr` :mode not :spec
	 */
	public function ctxPropertyNotCmp($propertyName, $mode, $spec)
	{
		if ("$spec" == "empty") {
			if (empty($this->$propertyName)) {
				throw new Exception("$propertyName is empty");
			}
			return;
		}
		if ($mode=="has" or $mode=="be" or $mode=="is" or substr($mode, 0, 5) == 'equal') {
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
	 * Then /^`([^`]+)` ((contain|match)[es]*) the patterns:$/
	 * @Then /^`([^`]+)` ((contain|match)[es]*) patterns:$/
	 */
	public function ctxPropertyCmpMultiline($propertyName, $mode, PyStringNode $specs)
	{
		if ($mode=="be" or $mode=="is" or substr($mode, 0, 5)=='equal') {
			$this->ctxPropertyShouldEqualMultiline($propertyName, $specs);
		} else if ($mode=="has") {
			$this->ctxPropertyHasLinesMultiline($propertyName, $specs);
		} else {
			$specs = explode(PHP_EOL, $specs);
			if (empty($specs[-1])) array_pop($specs);
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
		if (empty($lines[-1])) array_pop($lines);
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
		if (empty($patterns[-1])) array_pop($patterns);
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
		if (empty($arr_lines[-1])) array_pop($arr_lines);
		$content = explode(PHP_EOL, $this->$propertyName);
		if (empty($content[-1])) array_pop($content);

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
	 * Then /^`([^`]+)` equals:$/
	 * Then /^`([^`]+)` matches:$/
	 */
	public function ctxPropertyShouldEqualMultiline($propertyName, PyStringNode $string)
	{
        $this->cmpMultiline($this->$propertyName, $string);
    }
}
