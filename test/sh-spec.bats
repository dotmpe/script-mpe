#!/usr/bin/env bats

load init
base=projectdir-meta

init
. $lib/util.sh



@test "std globbing" {

  #shopt | grep extglob | grep 'off' \
  #  || fail "Extglob sh option is turned on by default"

  shopt -u nullglob
  shopt -u globstar
  shopt -u failglob
  shopt -u extglob

  tmpd
  cd $tmpd
 
  test "$(echo foo.*)" = "foo.*"
  touch foo.bar
  test "$(echo foo.*)" = "foo.bar"
  rm foo.bar

  test "$(echo {foo,bar}-{el,baz})" = "foo-el foo-baz bar-el bar-baz"

}


@test "Shell variable name indirection" {

  FOO=foo
  BAR=FOO

  test "$( echo ${!BAR} )" = "foo"
}


@test "Shell variable name expansion" {

  foo_1=a
  foo_bar=b

  test "$( echo ${!foo*} )" = "foo_1 foo_bar"
}


@test "Shell substring removal" {

  PARAMETER="PATTERN foo"
  test "${PARAMETER#PATTERN}" = " foo"
  test "${PARAMETER##P* }" = "foo"

  PARAMETER="foo PATTERN"
  test "${PARAMETER%PATTERN}" = "foo "
  test "${PARAMETER%% P*}" = "foo"

}


@test "Shell substring replace" {

  STRING=foobarbar
  PATTERN=bar
  SUBSTITUTE=baz
  test "${STRING/$PATTERN/$SUBSTITUTE}" = "foobazbar"
  test "${STRING//$PATTERN/$SUBSTITUTE}" = "foobazbaz"

	#${PARAMETER/PATTERN}
	#${PARAMETER//PATTERN}

	# Anchoring
	MYSTRING=xxxxxxxxxx
	test "${MYSTRING/#x/y}" = "yxxxxxxxxx"
	test "${MYSTRING/%x/y}" = "xxxxxxxxxy"

}



