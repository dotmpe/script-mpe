#!/bin/sh

scrtab_tpl_b__1__name='test-script.sh'
scrtab_tpl_b__1__mtime=1539038880
scrtab_tpl_b__1__contents='#!/bin/sh
set -e
hostname && whoami'

scrtab_tpl_b__2__name='scrtab.list'
scrtab_tpl_b__2__contents='# status ctime     mtime            script-id         label         @ctx        <src>
- 20181009-0047+02 20181009-0048+02 test-script-1 Some script @Std <HOME:.local/scr.d/test-script-1.sh>
- 20181009-0047+02 20181009-0048+02 test-script-2 Same script again @Std <HOME:.local/scr.d/test-script-2.sh>'

scrtab_tpl_b__3__name='package.yml'
scrtab_tpl_b__3__contents='
- type: application/vnd.org.wtwta.project
  main: scrtab-tpl-2
  id: scrtab-tpl-2
'

scrtab_tpl_b__4__name='.htd/package.json'
scrtab_tpl_b__4__contents='[{"main": "scrtab-tpl-2", "type": "application/vnd.org.wtwta.project", "id": "scrtab-tpl-2"}]'

scrtab_tpl_b__5__name='.htd/package.sh'
scrtab_tpl_b__5__contents='#!/bin/sh
package_id=scrtab-tpl-2
package_main=scrtab-tpl-2
package_type=application/vnd.org.wtwta.project'
