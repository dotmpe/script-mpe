<?php

use Behat\Gherkin\Node\PyStringNode;


trait FileContextTrait {

	/**
	 * Store line into file.
	 *
	 * @Given a file ":name" containing ":contents"/
	 */
	public function aFileContaining($fileName, $contents)
	{
		file_put_contents($fileName, (string) $contents);
	}

	/**
	 * Store multiline into file.
	 *
	 * @Given /^a file "([^"]*)" containing:$/
	 */
	public function aFileContainingLines($fileName, PyStringNode $contents)
	{
		file_put_contents($fileName, (string) $contents);
    }

    /**
     * Compare line by line, ignore file terminator EOL. Give per-line
     * match feedback: unexpected and/or missing.
     */
    public function cmpMultiline($value, $expected)
    {
        if ($expected != $value) {
            $out = explode(PHP_EOL, $value);
			if (empty($out[-1])) array_pop($out);
			$str = explode(PHP_EOL, $expected);
			if (empty($str[-1])) array_pop($str);
			$extra = array_diff( $out, $str );
            $missing = array_diff( $str, $out );
            if (empty($extra) && empty($missing)) {
                return;
            }

            $errMsg = '';
            if (!empty($extra)) {
			    $errMsg .= " +".implode(" +", $extra);
            }
            if (!empty($missing)) {
			    $errMsg .= " -".implode(" -", $missing);
            }

			throw new Exception("Mismatched: ".$errMsg);
		}
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
        $this->cmpMultiline((string) $arg2, file_get_contents($arg1));
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
        $this->cmpMultiline(file_get_contents($expectedContentsFileName), file_get_contents($outputFileName));
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
	 * @Given :type path :spec doesn't exist
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

	public function pathname_type_symlink($spec, $exists=True)
	{
		foreach (glob($spec, GLOB_BRACE|GLOB_NOCHECK) as $pathname) {
			if ($exists) {
				if (!symlink($pathname)) {
					throw new Exception("File '$pathname' does not exist, it should");
				}
			} else {
				if (symlink($pathname)) {
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
		if (empty($lines_arr[-1])) array_pop($lines_arr);
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
