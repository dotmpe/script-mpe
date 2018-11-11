#!/bin/sh

scrtab_tpl_a__1__name='test-script.sh'
scrtab_tpl_a__1__mtime=1539038880
scrtab_tpl_a__1__contents='#!/bin/sh
set -e
hostname && whoami'

scrtab_tpl_a__2__name='scrtab.list'
scrtab_tpl_a__2__contents='# status ctime     mtime            script-id         label         @ctx        <src>
'

scrtab_tpl_a__3__name='package.yml'
scrtab_tpl_a__3__contents='
- type: application/vnd.org.wtwta.project
  main: scrtab-tpl-1
  id: scrtab-tpl-1
'

scrtab_tpl_a__4__name='.htd/package.json'
scrtab_tpl_a__4__contents='[{"main": "scrtab-tpl-1", "type": "application/vnd.org.wtwta.project", "id": "scrtab-tpl-1"}]'

scrtab_tpl_a__5__name='.htd/package.sh'
scrtab_tpl_a__5__contents='#!/bin/sh
package_id=scrtab-tpl-1
package_main=scrtab-tpl-1
package_type=application/vnd.org.wtwta.project'
