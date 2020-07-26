#!/bin/sh

htd_man_1__grp_main=''


htd_man_1__output_formats='List output formats for sub-command. The format is a
tag that refers to the formatting on stdout of data or responses to invocations
of the subcommand::

    out_fmt=<fmt> htd <subcmd> <args>...

For each output format a quality factor may be specified, to indicate levels of
*increased* or *degraded* representation. The application of this value is
similar to the source-quality attribute in HTTP TCN (RFC 2295), except that this
raw value is not normalized to =<1.0.

In general, the value is used to weigh rendering quality and should not take
into account delay or load. Here, default values of 0.9 are used, because the
shell scripts at themselves make too little guarantee of encoding and other
precision. Values above 1.0 are permitted to indicate preferred, enhanced or
richer representations.

No current But no effort is made to

htd_output_format_q

the `ofq` attribute
'
htd_spc__output_formats='output-formats|OF [SUBCMD]'
htd_als___OF=output-formats
htd_of__output_formats='list csv tab json'
htd_f__output_formats='fmt q'
htd_ofq__output_formats='htd_output_formats_q'
htd__output_formats()
{
  test -n "$1" || set -- table-reformat
  # First resolve real command name if given an alias
  als="$(try_value "$1" als htd )"
  test -z "$als" || { shift; set -- "$als" "$@" ; }
  {
    upper= mkvid "$*"
    # XXX: Retrieve and test for output-formats and quality factor
    #try_func $(echo_local "$vid" "" htd) &&

      # Print output format attribute value for field $*
      output_formats="$(try_value "$vid" of htd )" &&
        test -n "$output_formats"
  } && {
    echo $output_formats | tr ' ' '\n'
  } || {
    stderr error "No sub-command or output formats for '$*'" 1
  }
}


htd_libs__info=package\ htd-package
htd_flags__info=lp
htd__info()
{
  test -n "$1" || set -- $(pwd -P)
  test -z "$2" || error "unexpected args '$2'" 1

  echo "package:"
  vc_getscm "$1" || return $?
  cd "$1"
  vc_info
}


htd_man_1__expand='Expand arguments or lines on stdin to existing paths.

Default is to expand names with dir. set expand-dir to false to get names.
Provide `dir` to use instead of CWD. With no arguments stdin is default.
'
htd_spc__expand='expand [--dir=] [--(,no-)expand-dir] [GLOBS | -]'
htd_env__expand="dir="
htd_flags__expand=eiAO
htd__expand()
{
  htd_expand "$@"
}


htd_man_1__edit_main="Edit the main script file(s), and add arguments"
htd_spc__edit_main="-E|edit-main [ -SREGEX | --search REGEX ] [ID-or-PATHS]"
htd__edit_main()
{
  htd_edit_main "$@"
}
htd_flags__edit_main=piAO
htd_als___XE=edit-main


htd_man_1__composure='Composure: dont fear the Unix chainsaw

A set of 7 shell functions, to rule all the others:

cite KEYWORD.. - create keyword function
draft NAME [HIST] - create shell routine function of last command or history index
glossary - list all composure functions
metafor - retrieve string from typeset output
reference FUNC - print usage
revise FUNC - edit shell routine function
write FUNC.. - print composed function(s)

The benefit of using shell functions is free auto-complete without any fus.

Composure includes private functions under the "_" prefix. Its main techniques
are:

1. empty (no-op) functions for keeping strings (iso. vars or comments), for
   better performance having typeset access function bodies and metafor grep
2. draft/revise/write and other helper functions to create new functions,
   stored at ~/.local/composure/*.inc

reference accesses all the interesting metadata keywords for a function. The
short help string is called "about".

XXX: it would be interesting to "overload" functions, or rewrite compsure
entirely using composure functions. all the files need some organization,
have metadata for lib or cmd groups. ie. let it generate itself, or
customizations.

the interesting bit is overriding of functions. like when does a app decide
to use the global, host, vendor provided scripts or when does it let a local
user provided script take over.
'


# TODO move foreach to htd str
htd_man_1__foreach='Execute based on match for each argument or line

Executes "$act" and "$no_act" for each arg or line based on glob, regex, etc.
These can be function or command names that accept exactly one argument.
Without arguments (or "-") all input is read from standard-input.

This can be used to reuse a simple function that accepts one argument, into one
that accepts multiple arguments and/or reads from stdin and provides a way to
add filters. The defaults are "htd foreach * echo /dev/null -", but three
arguments are required. Ie. this simply echoes all lines on stdin:

  htd foreach "" "" ""

EXPR may be a glob, regex, command or function, or shell expression.
To prevent ambiguity, EXPR prefixes set the type ("g:", "r:", "x:" or "e:").
The default is glob, and no further effort is made ie. to detect existing
functions or commands. The signatures are:

  g:<glob>
  r:<regex>
     Test each arg/line S
  x:<callback>
     Invoke <callback> with each S as argument
  e:<shell-expression>
     Evaluate for each S, without any further arguments

For example scripts see `htd help filter`.
'
htd_spc__foreach='foreach EXPR ACT NO_ACT [ - | Subject... ]'
htd__foreach()
{
  local type_= expr_= act="$2" no_act="$3" s= p=
  foreach_match_setexpr "$@" ; shift 3
  foreach_match "$@"
}


htd_man_1__filter='Return matching paths from args or stdin

See `htd foreach` for EXPR and argument handling. Example to get "./*.lib.sh"
files:

   htd filter "*.lib.sh" *.sh
   htd filter "r:.*\.lib\.sh$" *.sh

These are just examples, instead of a new command some simple shell glob expansion
could give the same result. The real power of this routine is that it implements
the same wether input is arguments or lines on standard input, and can call
other functions to perform the actual testing. It is not restricted to testing
on filename/pathname only, and can work on any provided list directly.

List all executable or symlinks in tracked in GIT repository:

   git ls-files | htd filter e:"test -x \"./\$S\""
   git ls-files | htd filter x:"test -x"
   git ls-files | htd filter x:"test -h"

As another example emulate GNU `find` selectors based on file descriptor. Using
functions loaded by `htd`, similar actions are easier to write:

   git ls-files | htd filter-out x:"test -s" # find . -empty -type f
   git ls-files | htd filter "e:test \$(filesize \"./\$S\") -gt 1024" # +size
   git ls-files | htd filter "e:older_than \"\$S\" \$_1YEAR" # +time?

NOTE: that because the examples are single-quoted, it prevents any single quote
in the documentation. While it would make the above examples a bit more readable
with less escaping.
'
htd_spc__filter='filter EXPR [ - | PATH... ]'
htd__filter()
{
  local type_= expr_= mode_=
  foreach_match_setexpr "$1" ; shift
  mode_=1 htd_filter "$@"
}


htd_man_1__filter_out='Return non-matches for glob, regex or other expression

See `htd help filter`.
'
htd_spc__filter_out='filter EXPR [ - | PATH... ]'
htd__filter_out()
{
  local type_= expr_= mode_=
  foreach_match_setexpr "$1" ; shift
  mode_=0 htd_filter "$@"
}


htd_main_lib_load()
{
  default_env UCONF "$HOME/.conf/" || debug "Using UCONF '$UCONF'"
  default_env TMPDIR "/tmp/" || debug "Using TMPDIR '$TMPDIR'"
  default_env HTDIR "$HOME/public_html" || debug "Using HTDIR '$HTDIR'"

  default_env Htd-ToolsFile "$CWD/tools.yml"
  #test -n "$HTD_TOOLSFILE" || HTD_TOOLSFILE="$CWD"/tools.yml
  default_env Htd-ToolsDir "$HOME/.htd-tools"
  # test -n "$HTD_TOOLSDIR" || export HTD_TOOLSDIR=$HOME/.htd-tools
  default_env Htd-GIT-Remote "$HTD_GIT_REMOTE" ||
    debug "Using Htd-GIT-Remote name '$HTD_GIT_REMOTE'"
  default_env Htd-Ext ~/htdocs:~/bin ||
    debug "Using Htd-Ext dirs '$HTD_EXT'"
  default_env Htd-ServTab $UCONF/htd-services.tab ||
    debug "Using Htd-ServTab table file '$HTD_SERVTAB'"
  test -d "$HTD_TOOLSDIR/bin" || mkdir -p "$HTD_TOOLSDIR/bin"
  test -d "$HTD_TOOLSDIR/cellar" || mkdir -p "$HTD_TOOLSDIR/cellar"
  default_env Htd-BuildDir .build
  test -n "$HTD_BUILDDIR" || exit 121
  #test -d "$HTD_BUILDDIR" || mkdir -p $HTD_BUILDDIR
  export B=$HTD_BUILDDIR

  #default_env Couch-URL "http://localhost:5984"
}

#
