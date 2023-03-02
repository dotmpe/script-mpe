#!/usr/bin/env python3

import yaml, json


format_item = {
  'run': lambda item: "\"%(label)s:$0 run %(command)s\"" % item,
  'card': lambda item: "\"%(label)s:$0 run echo '%(card)s' -- main_menu ${LAST:-$1}\"" % item,
  'submenu': lambda item: "\"%(label)s:$0 menu %(id)s\"" % item
}

def menu_sh(doc, menu_id):
    menu = get_menu(doc, menu_id)
    print("label=\"%s\"" % menu['label'])
    print("tmenu=(")
    for item in menu['items']:
        if isinstance(item, str):
            print(" ", format_item['run'](dict(
                label=item, command=item)))
        else:
            if 'menu-ref' in item:
                item = get_menu(doc, item['menu-ref'])
            if 'class' not in item:
                if 'items' in item:
                    iclass = 'submenu'
                elif 'command' in item:
                    iclass = 'run'
                elif 'card' in item:
                    iclass = 'card'
                else:
                    iclass = 'run'
            else:
                iclass = item['class']
            print(" ", format_item[iclass](item))
    print(")")

def get_menu(doc, menu_id):
    doc['menus'][menu_id]['id'] = menu_id
    return doc['menus'][menu_id]

def main():
    import sys, argparse
    parser = argparse.ArgumentParser(
            prog='tmenu.py',
            description='',
            epilog='Use the source')
    parser.add_argument('menu', metavar='<PATH>',
            help='path to menu [%(default)s]',
            default='root')
    args = parser.parse_args()
    data = yaml.load(sys.stdin, yaml.Loader)
    menu_sh(data, *args.menu.split(':'))

if __name__ == '__main__':
    main()
