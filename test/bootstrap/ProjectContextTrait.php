<?php

use Behat\Behat\Tester\Exception\PendingException,
    Behat\Gherkin\Node\PyStringNode,
    Behat\Gherkin\Node\TableNode;


trait ProjectContextTrait {

    /**
     * NOTE: there are other ways to get at the project root, this works for
     * a static file while it does not move and is not used in submodule.
     */
    public function getProjectDir()
    {
        return dirname(dirname(dirname(__FILE__)));
    }

    /**
     * This step does very little, checks the PWD equals the ProjectDir. It is
     * the basis though for mover specific `GIVEN <project>` steps, eg. those
     * needing relative paths, and other argument or environment values.
     *
     * @Given /^the current project dir,?$/
     * @Given /^the current project,?$/
     * @Then /^back to current project dir,?$/
     * @Then /^back to current project,?$/
     */
    public function theCurrentProject()
    {
        $projDir = $this->getProjectDir();
        if (getcwd() != $projDir) {
            chdir($projDir);
        }
        return $projDir;
    }

    /**
     * "Given package env": setup to load package.y*ml into shell env.
     *
     * @Given  package env
     */
    public function project_settings()
    {
        $this->theUserRuns("htd package update");

        $this->theCurrentScriptDir();
        $default_env = '. $scriptpath/util.sh ; lib_load';
        $package_env = $default_env .' ; lib_load package && package_lib_set_local .';

        $this->env = $package_env .' && . "$PACKMETA_SH"';
    }

    /**
     * "Given deps" checks build targets given a command and directory in the
     * project config (package.y*ml).
     *
     * @Given deps :deps
     * @Given deps :deps and :dep
     * @Given /^deps (.+) and (.+)$/
     * @Given /^deps ([a-z0-9,_-]+)$/
     * @Given /^deps ([a-z0-9,_-]+) and ([a-z0-9,_-]+)$/
     */
    public function project_build_deps($deps_, $dep_)
    {
      $deps = explode(', ', $deps_);
      if (!empty($dep_)) { $deps[] = $dep_; }
      foreach ($deps as $dep) {
        $this->theUserRuns("lib_load build; __(){ eval \$package_build; }; __ \$cllct_test_base/$dep.tap");
      }
      foreach ($deps as $dep) {
        $this->theUserRuns("lib_load build; grep -q \"^not\ ok\ \" \$cllct_test_base/$dep.tap && { echo Failed $dep dep; exit 1; } || true");
      }
    }
}
