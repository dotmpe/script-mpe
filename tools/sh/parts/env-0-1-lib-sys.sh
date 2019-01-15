#!/usr/bin/env bash
: "${sys_lib_loaded:=""}"

: "${base:=}"
: "${lookup_test:=}"

: ${HOST:="`hostname -s | tr 'A-Z' 'a-z'`"}
: ${uname:-"`uname -s | tr 'A-Z' 'a-z'`"}

# Set GNU 'aliases' to try to build on Darwin/BSD

case "$uname" in
  darwin )
      export gsed=${gsed:-"gsed"}
      export ggrep=${ggrep:-"ggrep"}
      export gawk=${gawk:-"gawk"}
      export gdate=${gdate:-"gdate"}
      export gstat=${gstat:-"gstat"}
      export guniq=${guniq:-"guniq"}
      export gsort=${gsort:-"gsort"}
      export greadlink=${greadlink:-"greadlink"}
      export grealpath=${grealpath:-"grealpath"}
    ;;
  linux )
      export gsed=${gsed:-"sed"}
      export ggrep=${ggrep:-"grep"}
      export gawk=${gawk:-"awk"}
      export gdate=${gdate:-"date"}
      export gstat=${gstat:-"stat"}
      export guniq=${guniq:-"uniq"}
      export gsort=${gsort:-"sort"}
      export greadlink=${greadlink:-"readlink"}
      export grealpath=${grealpath:-"realpath"}
    ;;
  * ) $LOG "warn" "" "Unknown OS" "$uname"
    ;;
esac

# XXX: Alternative robust setup
#test -x "$(which gsed)" && gsed=gsed || gsed=sed
#test -x "$(which ggrep)" && ggrep=ggrep || ggrep=grep
#test -x "$(which gawk)" && gawk=gawk || gawk=awk
#test -x "$(which gdate)" && gdate=gdate || gdate=date
#test -x "$(which gstat)" && gstat=gstat || gstat=stat
#test -x "$(which guniq)" && guniq=guniq || guniq=uniq
#test -x "$(which gsort)" && gsort=gsort || gsort=sort
#test -x "$(which greadlink)" && greadlink=greadlink || greadlink=readlink
#test -x "$(which grealpath)" && grealpath=grealpath || grealpath=realpath
