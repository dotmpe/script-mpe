#!/usr/bin/env php
<?php

list( $scriptname, $local, $base, $remote, $merged ) = $_SERVER['argv'];


/**
 * Return values in $aArray1 different from $aArray2.
 */
function arrayRecursiveDiff($aArray1, $aArray2) {
    $aReturn = array();

    foreach ($aArray1 as $mKey => $mValue) {
        if (is_array($aArray2) && array_key_exists($mKey, $aArray2)) {
            if (is_array($mValue)) {
                $aRecursiveDiff = arrayRecursiveDiff($mValue, $aArray2[$mKey]);
                if (count($aRecursiveDiff)) { $aReturn[$mKey] = $aRecursiveDiff; }
            } else {
                if ($mValue != $aArray2[$mKey]) {
                    $aReturn[$mKey] = $mValue;
                }
            }
        } else {
            $aReturn[$mKey] = $mValue;
        }
    }
    return $aReturn;
}

$data_local = file_get_contents( $local );
$data_remote = file_get_contents( $remote );

$dictname = null;

function set_dictname() {
    global $dictname;
    if (array_key_exists('dictionary', $GLOBALS)) {
        $dictname = 'dictionary';
    } else if (array_key_exists('viewdefs', $GLOBALS)) {
        $dictname = 'viewdefs';
    } else if (array_key_exists('mod_strings', $GLOBALS)) {
        $dictname = 'mod_strings';
    } else if (array_key_exists('app_strings', $GLOBALS)) {
        $dictname = 'app_strings';
    } else if (array_key_exists('app_list_strings', $GLOBALS)) {
        $dictname = 'app_list_strings';
    } else {
        echo "Cannot determine top-level dictionary name. Exiting..";
        exit(1);
    }
}

function recursive_print( $indent, $arr ) {

    if (empty($arr)) {
        echo $indent."null";
        return;
    }

    $keys = array_keys( $arr );
    if (is_numeric($keys[0])) {
        sort($keys, SORT_NUMERIC);
    }

    foreach( $keys as $key ) {
        $value = $arr[ $key ];
        if (is_array($value)) {
            echo "$indent$key:\n";
            recursive_print( "$indent  ", $value );
        //} else if (is_numeric($value)) {
        //    echo "$indent$key: '$value'\n";
        } else {
            echo "$indent$key: $value\n";
        }
    }

}

function print_diff( $msg, $arr_local, $arr_remote ) {
    global $dictname, $scriptname;
    $diff = arrayRecursiveDiff( $arr_local, $arr_remote );

    echo "dictdiff $msg\n";
    if (basename($scriptname) == 'dictdiff-yaml.php') {
        recursive_print( '', $diff );
    } else {
        var_export( $diff );
    }
}

define( 'sugarEntry', 1 );

try {
    include $local;
    set_dictname();
    $arr_local = $GLOBALS[ $dictname ];
} catch(Exception $e) {
    echo "import error for local";
}

try {
    include $remote;
    $arr_remote = $GLOBALS[ $dictname ];
} catch(Exception $e) {
    echo "import error for remote";
}

echo "dictname:$dictname\n";
echo "local: $local\n";
echo "remote: $remote\n";
print_diff( "local to remote", $arr_local, $arr_remote );
print_diff( "remote to local", $arr_remote, $arr_local );

echo "\ndictdiff end. Goodbye.\n";
exit(0);


