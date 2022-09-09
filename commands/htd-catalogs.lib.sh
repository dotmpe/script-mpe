#!/bin/sh

### Htd/Catalog/lists @Dev


htd_man_1__catalogs='Build file manifests.

XXX:
  [global=1] list
  [global=0|1] list [PATH=.]
    List catalog names below

    There can be many catalogs, yet most operations work on a single catalog
    file. There are two ways to detect the primary catalog for a given PATH:
    - Look for ``catalog.y{,a}ml`` in PATH or each direct parent
    - Look for entry in ``$HTD_CONF/catalogs.tab``
'

htd__catalogs ()
{
  test -n "${1-}" || set -- list
  subcmd_prefs=${base}_catalogs__ try_subcmd_prefixes "$@"
}
htd_flags__catalogs=ilIAO
htd_libs__catalogs='match str-htd date-htd schema list ignores htd-catalog'\
' catalog'

htd_catalogs__list () # List catalog names ~
{
  trueish "${choice_global:-}" && {
      htd_catalog__req_global || return
    } || {
      htd_catalog__req_local || return
    }
}

# Id: BIN:
