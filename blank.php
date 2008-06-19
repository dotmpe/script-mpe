<?php

$paths = ini_get("include_path");
ini_set('include_path', $paths . ":lib/php/");

include ("anewt/core/main.lib.php");

anewt_include('page/blank');

$page = new BlankPage();
$page->flush();

?>
