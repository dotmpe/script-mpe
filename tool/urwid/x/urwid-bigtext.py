import os
import sys

import urwid
import pyfiglet
from pyfiglet import Figlet

flf_dir = os.getenv('FIGLET_DIRECTORY')
pyfiglet.SHARED_DIRECTORY = flf_dir

def exit_on_q(key):
    if key in ('q', 'Q'):
        raise urwid.ExitMainLoop()
    else:
        pass
        #print(key)
        #if key in ('window resize'):
        #print('resize')

palette = [
  ('body',              'black',       'light gray', 'standout'),
  ('header',            'white',       'dark red',   'bold'),
  ('button normal',     'light gray',  'dark blue', 'standout'),
  ('button select',     'white',       'dark green'),
  ('button disabled',   'dark gray',   'dark blue'),
  ('edit',              'light gray',  'dark blue'),
  ('bigtext',           'brown',       'black'),
  ('chars',             'light gray',  'black'),
  ('exit',              'white',       'dark cyan'),
]

class SwitchingPadding(urwid.Padding):
    def padding_values(self, size, focus):
        maxcol = size[0]
        width, ignore = self.original_widget.pack(size, focus=focus)
        if maxcol > width:
            self.align = "left"
        else:
            self.align = "right"
        return urwid.Padding.padding_values(self, size, focus)


fonts = dict(urwid.get_all_fonts())
print(fonts)

btw = urwid.BigText("Big text", None)
#btw.set_font(fonts['Half Block 5x4'])
#btw.set_font(fonts['Half Block 6x5'])
btw.set_font(fonts['Half Block Heavy 6x5']())
#btw.set_font(fonts['Half Block 7x7'])

#bt = SwitchingPadding(btw, 'left', None)
#
#bt = urwid.AttrWrap(bt, 'bigtext')
#bt = urwid.Filler(bt, 'bottom', None, 7)
#bt = urwid.BoxAdapter(bt, 7)

def runFunc(btn):
    pass


def menu_button(caption, callback):
    button = urwid.Button(caption)
    urwid.connect_signal(button, 'click', callback)
    return urwid.AttrMap(button, None, focus_map='reversed')

def sub_menu(caption, choices):
    contents = menu(caption, choices)
    def open_menu(button):
        return top.open_box(contents)
    return menu_button([caption, u'...'], open_menu)

def menu(title, choices):
    body = [urwid.Text(title), urwid.Divider()]
    body.extend(choices)
    return urwid.ListBox(urwid.SimpleFocusListWalker(body))

def item_chosen(button):
    response = urwid.Text([u'You chose ', button.label, u'\n'])
    done = menu_button(u'Ok', exit_program)
    top.open_box(urwid.Filler(urwid.Pile([response, done])))

def exit_program(button):
    raise urwid.ExitMainLoop()

menu_top = menu(u'Main Menu', [
    sub_menu(u'Applications', [
        sub_menu(u'Accessories', [
            menu_button(u'Text Editor', item_chosen),
            menu_button(u'Terminal', item_chosen),
        ]),
    ]),
    sub_menu(u'System', [
        sub_menu(u'Preferences', [
            menu_button(u'Appearance', item_chosen),
        ]),
        menu_button(u'Lock Screen', item_chosen),
    ]),
])

cmenu_chbg = u'\N{LIGHT SHADE}'
cmenu_chbg = u'\N{MEDIUM SHADE}'
cmenu_chbg = u'\N{DARK SHADE}'
cmenu_chbg = u'\N{QUADRANT UPPER RIGHT AND LOWER LEFT}'
cmenu_chbg = u'\N{QUADRANT UPPER LEFT AND UPPER RIGHT AND LOWER LEFT}'

cmenu_chbg = u'\N{BOX DRAWINGS LIGHT VERTICAL AND HORIZONTAL}'
cmenu_chbg = u'\N{BOX DRAWINGS DOUBLE VERTICAL AND HORIZONTAL}'
cmenu_chbg = u'\N{BOX DRAWINGS LIGHT DIAGONAL UPPER RIGHT TO LOWER LEFT}'
#cmenu_chbg = u'\N{BOX DRAWINGS LIGHT DIAGONAL CROSS}'
#cmenu_chbg = u'\N{BOX DRAWINGS HEAVY TRIPLE DASH HORIZONTAL}'
#cmenu_chbg = u'\N{SYMBOL FOR NULL}'
#cmenu_chbg = u'\N{TOP LEFT CORNER}'


class CascadingBoxes(urwid.WidgetPlaceholder):
    max_box_levels = 4

    def __init__(self, box):
        super(CascadingBoxes, self).__init__(urwid.SolidFill(cmenu_chbg))
        self.box_level = 0
        self.open_box(box)

    def open_box(self, box):
        self.original_widget = urwid.Overlay(urwid.LineBox(box),
            self.original_widget,
            align='center', width=('relative', 80),
            valign='middle', height=('relative', 80),
            min_width=24, min_height=8,
            left=self.box_level * 3,
            right=(self.max_box_levels - self.box_level - 1) * 3,
            top=self.box_level * 2,
            bottom=(self.max_box_levels - self.box_level - 1) * 2)
        self.box_level += 1

    def keypress(self, size, key):
        if key == 'esc' and self.box_level > 1:
            self.original_widget = self.original_widget[0]
            self.box_level -= 1
        else:
            return super(CascadingBoxes, self).keypress(size, key)

cmenu = CascadingBoxes(menu_top)

#ba, bb = urwid.Button('This is button A', on_press=runFunc), urwid.Button('This is button B')

#lb = urwid.LineBox(ba, title='Linebox title')

#pile.contents.append(
#        urwid.BigText(('bigtext', "SYS 914"), urwid.HalfBlock5x4Font())
#    )

fl_1 = Figlet(font='miniwi', justify='center')#, width=120)
fl_2 = Figlet(font='cybersmall', justify='center')#, width=120)
fl_3 = Figlet(font='cybermedium', justify='center')#, width=120)
fl_4 = Figlet(font='cyberlarge', justify='center')#, width=120)
fl_5 = Figlet(font='graffiti', justify='center')#, width=120)

lb = urwid.ListBox(urwid.SimpleFocusListWalker([

    urwid.Padding(
        urwid.Text(fl_1.renderText('Connected....'))
    ),
    urwid.Padding(
        urwid.Text(fl_3.renderText('Welcome traveler'))
    ),
    urwid.Padding(
        urwid.Text(fl_2.renderText('Planetary Information Center'))
    ),
    urwid.Padding(
        urwid.Text(fl_5.renderText('Flodder BBS'))
    ),

    urwid.Padding(
        urwid.Text(u'\u2605 is text \N{SQUARE WITH RIGHT HALF BLACK}')
    ),
    urwid.Padding(
        urwid.Text(u'Alternative Key Symbol \N{Alternative Key Symbol}')
    ),
    urwid.Padding(
        urwid.Text(u'Combining Comma Above Right \N{Combining Comma Above Right}')
    ),
    urwid.Padding(
        urwid.Text(u'Helm Symbol \N{Helm Symbol}')
    ),
    urwid.Padding(
        urwid.Text(u'Superscript \N{Superscript One}\N{Superscript Left Parenthesis}\N{Superscript Five}\N{Superscript Nine}\N{Superscript Right Parenthesis}')
    ),
    urwid.Padding(
        urwid.Text(u'Leftwards Arrow from Bar \N{Leftwards Arrow from Bar}')
    ),
    urwid.Padding(
        urwid.BigText(('bigtext', "SYS 914"), urwid.HalfBlock5x4Font()),
        width='clip'),

    urwid.Padding(
        urwid.BigText(('bigtext', "CTL 813"), urwid.HalfBlock5x4Font()),
        width='clip'),

    urwid.Padding(
        urwid.BigText(('bigtext', "ENV 721"), urwid.HalfBlock5x4Font()),
        width='clip'),

    urwid.Padding(
        urwid.BigText(('bigtext', "Hello world 2"), urwid.HalfBlock6x5Font()),
        width='clip'),

    urwid.Padding(
        urwid.BigText(('bigtext', "Hello world 3"), fonts['Half Block Heavy 6x5']()),
        width='clip'),

    urwid.Padding(
        urwid.BigText(('bigtext', "Hello world 4"), urwid.HalfBlock7x7Font()),
        width='clip')

]))

#pile = urwid.Pile([ cmenu, ba, bb, lb ])
#filler = urwid.Filler(pile)

cols = urwid.Columns([ lb, cmenu ])

main = cols

loop = urwid.MainLoop(main, palette, unhandled_input=exit_on_q)

loop.run()
