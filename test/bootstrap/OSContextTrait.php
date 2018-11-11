<?php



/**
 * This implements a set of steps that set/get and match properties on the
 * context.
 */
trait OSContextTrait {

    /**
     * Read file contents to named context property.
     *
     * @Given /^`([^`]+)` from file '([^"]+)'\.?$/
     */
    public function ctxPropertyFromFile($propertyName, $fileName, $withError='')
    {
        if (!$withError) {
            if (!file_exists($fileName)) {
                throw new Exception("File '$fileName' does not exist");
            }
            $this->{$propertyName} = file_get_contents($fileName);
        } else {
            $this->{$propertyName} = "";
        }
    }

    /**
     * Read file contents to `contents` given filename, then check the value
     * using regex.
     *
     * @Then /^the file `([^`]+)` contains the pattern '([^"]+)'\.?$/
     * @Then /^the file `([^`]+)` contains '([^"]+)'\.?$/
     */
    public function theFileContainsThePattern($outputFileName, $pattern)
    {
        $this->ctxPropertyFromFile("output", $outputFileName);
        $this->ctxPropertyPregForPattern("contents", "contains", $pattern);
    }

    /**
     * @Then /^`([^`]+)` should equal contents of \"([^\']*)\"$/
     * @Then /^`([^`]+)` equals \"([^\']*)\" contents$/
     */
    public function ctxPropertyShouldEqualContents($propertyName, $filename)
    {
        $string = file_get_contents($filename);
        $this->cmpMultiline($this->$propertyName, $string);
    }

    /**
     * Execute command and match in one step.
     *
     * @Given /^the output of "([^"]*)" does not (contain|match) pattern "([^"]*)"$/
     */
    public function theOutputOfDoesNotContainPattern($command, $mode, $pattern)
    {
        $this->theUserRuns($command, false);
        $this->ctxPropertyPregForPattern("output", $mode, $pattern);
    }
}
