#!/bin/sh

### Nerd font definitions

# This file provides definitions for each symbol to use in scripts.
# The Nerdfonts project ships several fonts patched for various symbol sets.
# To print the 4-digit hex as characters a terminal we need GNU printf, as
# it can easily interpretate the UTF-16.
# However in '/bin/sh'-mode I get no access to that, even with env.
# So I build the scripts to generate the definitions and not deal with the
# escapes at all.

# This does add over 200k of source to load however. Over 7k lines for two
# sets of declarations.
# And there is a lot I am not interested in.
# So I modified the script to take a list of grep-names to include.

#shellcheck disable=SC2034 # X appears unused. Verify use (or export if used externally).

nerdfonts_lib__load ()
{
  : "${NF_CT_SRC="https://github.com/ryanoasis/nerd-fonts/raw/gh-pages/_posts/2017-01-04-icon-cheat-sheet.md"}"
  : "${NF_FP_SRC="https://github.com/ryanoasis/nerd-fonts/raw/master/font-patcher"}"
  . "$US_BIN"/nerdfonts-selection.lib.sh
}

nerdfonts_lib__init ()
{
  test "$IS_BASH" -eq 1 && {
    nerdfonts_lib_load_gnuprintf || return
  } || {
    nerdfonts_lib_load_rawbe || return
  }
  nf_mdi_plug=$nf_mdi_power_plug
  ! sys_debug -dev -debug -init ||
    $LOG notice "" "Initialized nerdfonts.lib" "$(sys_debug_tag)"
}

# Generate selection for local script-repository.
nerdfonts_lib_build () # ~ # (Re)build selection
{
  test $# -gt 0 || set -- nerdfonts-selection.lib.sh
  test $# -gt 1 || set -- "$@" nf-incl.txt
  test -e "$2" || {
      nerdfonts_repo_selection >"$2" || return
  }
  nerdfonts_lib_buildfull "$1" "$2"
}

nerdfonts_repo_selection () # ~ [<Exclude-File-Glob>] #
{
   test $# -gt 0 || set -- nerdfonts-decl.lib.sh

   for name in $(
       git grep --no-line-number -ho '\<nf_[a-zA-Z0-9:\${}_-]*' -- ':!'"$1" |
           remove_dupes )
              do
                  case "$name" in
                      ( *"\$"* )
                          echo "$name" | sed 's/${[^}]*}/.*/'
                          continue ;;
                      ( "nf_" ) continue ;;
                  esac
                  echo "$name"
              done
   unset name
}

nerdfonts_lib_buildfull () # ~ [<Output-Scriptfile>] [<Grep-Include>] # (Re)build declarations
{
  test $# -gt 0 || set -- $PWD/nerdfonts-decl.lib.sh
  test -e "${2-}" && {
    grep_opt="-f $2"
  } || {
    test -n "${2-}" && grep_opt="-e $2" || grep_opt="-e '.*'"
  }

  test ${v:-4} -le 5 ||
      echo "Building <$1>..." >&2
  { cat <<EOM
#!/bin/sh

# Variables for use with Nerdfonts, generated $(date --iso=min)

nerdfonts_lib_load_rawbe ()
{
$(nerdfonts_lib_build_decl raw-be | grep $grep_opt | sed 's/^\w/  &/')
}

nerdfonts_lib_load_gnuprintf ()
{
$(nerdfonts_lib_build_decl gnu-printf | grep $grep_opt | sed 's/^\w/  &/')
}
EOM
  } >> "$1"
  unset grep_opt

  test ${v:-4} -le 5 ||
    echo "Appended generated shell-script to $1" >&2
}

nerdfonts_lib_build_decl () # ~ [<Format>] # Generate declarations
{
  nerdfonts_symbols | {
      case "${1:-}" in

          ( "raw-be" )
                current_group=
                while read name hex
                do
                    # Insert some blank lines to group lines, make nav easier
                    group=$( echo "$name" | cut -d '_' -f 2 )
                    test "$group" = "$current_group" || {
                        test -z "$current_group" || echo
                        current_group="$group"
                    }

                    # Print declaration in a convoluted way
                    printf "%s='" "$name"
                    printf $(printf '\\%o' $(printf %08x 0x$hex | sed 's/../0x& /g')) |
                        iconv -f UTF-32BE -t UTF-8
                    printf "'\n"
                done
                unset current_group name hex group
              ;;

          ( "" | "gnu-printf" )
                sed " s/^\\(.*\\) \\(.*\\)$/\1='\\\u\2'/ "
              ;;

          ( * ) echo "nerdfonts.lib.sh:build-decl: Unknown format '$1'" >&2; return 3
              ;;
      esac
  }
}

nerdfonts_symbols () # ~ # List symbol names with UTF-16 hexadecimal code.
{
  curl -L ${NF_CT_SRC?} | grep 'class="class-name"' | sed '
      s/^.*\(nf-[^<]*\)<[^>]*>[^>]*>\([0-9a-f]*\).*$/\1 \2/
      s/-/_/g
    '
}

nerdfonts_patchtab_csv ()
{
  echo "# Enabled Name Filename Exact SymStart SymEnd SrcStart SrcEnd ScaleGlyph Attr"
  curl -L ${NF_FP_SRC?} | grep '{.Enabled.: ' | sed '
        s/^ *{/ /
        s/},\?\( * #.*\)\?$//
        s/ * '\''\([A-Za-z]*\)'\'': //g
    '
}

nerdfonts_patchtab ()
{
  test $# -gt 0 || set -- nerdfont-codemap.csv
  test -e "$1" || {
    nerdfonts_lib_patchtab_csv >"$1"
  }

  read_nix_style_file "$1" |
      tr -d '"' |
      while IFS=, read en name filename exact syms syme srcs srce sg attr
        do
            # Default or optional?
            test "$en" = "True" &&
                enabled="*" || enabled=" "
            echo "$enabled\t$name\t$filename\t$syms-$syme\t$srcs-$srce"
        done | column  -c5 -s"$(printf '\t')" -t
}

#
