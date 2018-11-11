<?php


/**
 * Bootstrap temporary setups from template
 */
trait TempContextTrait {


    var $allowedDirs = array();

    /**
     * @Given temp dir :path
     */
    public function tempDir($path)
    {
        mkdir("/tmp/${path}");
        chdir("/tmp/${path}");
    }

    /**
     * @Given clean temp. :glob_spec
     */
    public function cleanTempDir($glob_spec)
    {
        foreach (glob("/tmp/$glob_spec") as $pathname) {
            if (!file_exists($pathname)) {
                continue;
            }
            if (is_dir($pathname)) {
                $this->dropDir($pathname);
            } else {
                unlink($filename);
            }
        }
    }

    /**
     * Setup temp. dir, and initialize files from sh-tpl. Stay in new dir.
     * This requires a script-env.
     *
     * @Given :dir setup from :tpl
     * When /^'([^']*)' setup from '([^']*)'$/
     */
    public function workingDirFromTpl($dirname, $tpl)
    {
        $tpl = realpath($tpl);
        $this->tempDir($dirname);
        $this->theUserRuns("lib_load build && setup_sh_tpl \"$tpl\"");
    }

    /**
     * @Then drop temp. dir :arg1
     */
    public function dropTempDir($arg1)
    {
        $this->dropDir("/tmp/$arg1");
    }

    /**
     * @Then drop dir :arg1
     */
    public function dropDir($arg1)
    {
        $pathname = realpath($arg1);
        if (!$this->checkBaseDir($pathname)) {
            throw new Exception("Not allowed to drop '$pathname'");
        }
        exec("rm -rf \"${pathname}\"", $output, $return_var);
        if ($return_var) {
            throw new Exception("Command return non-zero: '$return_var' for '$command'");
        }
    }

    /**
     * Check for allowed base dir
     */
    public function checkBaseDir($path)
    {
        if (substr($path, 0, 1) != '/') {
            throw new Exception("Absolute path required");
        }
        $basedir = $path;
        while (!in_array($basedir, $this->allowedDirs)) {
            $basedir = dirname($basedir);
            if ($basedir == '/') {
                break;
            }
        }
        return in_array($basedir, $this->allowedDirs);
    }

    /**
     * @Given dir copy from :path
     */
    public function workingDirCopyFromTestVar($path)
    {
        throw new PendingException();
    }
}
