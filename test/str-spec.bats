#!/usr/bin/env bats

#export verbosity=6
#load helper

test -z "$PREFIX" && scriptdir=. || scriptdir=$PREFIX

lib=$scriptdir/str.lib

fnames="$(grep '^[a-zA-Z0-9_]*()' $lib.sh | tr -s '()\n' ' ')"
for fname in $fnames
do
  type $fname >/dev/null 2>/dev/null \
     && {

      set | grep '\<'$fname'=' \
        >/dev/null 2>/dev/null \
        && continue

      echo "Unexpected '$fname' function"
      fail "Unexpected '$fname' function"
    }
done


setup()
{
  . $scriptdir/util.sh load-ext
  lib_load sys os std str match
  str_load
}




func=mkvid

@test "$lib $func can make ID from path" {
    mkvid "/var/lib"
    test "$vid" = "_var_lib"
    mkvid "/var/lib/"
    test "$vid" = "_var_lib_"
}

@test "$lib $func cleans up ID from path" {
    mkvid "/var//lib//"
    test "$vid" = "_var_lib_"
    mkvid "/var//lib"
    test "$vid" = "_var_lib"
}


func=str_replace

@test "$lib $func " {
    test "$(str_replace "foo/bar" "o/b" "o-b")" = "foo-bar"
}


@test "resolve_prefix_element" {
  element=$(resolve_prefix_element 1 123:456)
  test "${element}" = "123" || fail "${element}"
  element=$(resolve_prefix_element 2 123:456)
  test "${element}" = "456" || fail "${element}"
  element=$(resolve_prefix_element 1 :123:456)
  test "${element}" = "" || fail "${element}"
  element=$(resolve_prefix_element 3 123:456:)
  test "${element}" = "" || fail "${element}"
  element=$(resolve_prefix_element 4 123:456:abcd-dfs:A:)
  test "${element}" = "A" || fail "${element}"
}

