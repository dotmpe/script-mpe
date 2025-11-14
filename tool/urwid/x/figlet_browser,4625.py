import os
import sys

import urwid
import pyfiglet
from pyfiglet import Figlet


def exit_on_q(key):
    if key in ('q', 'Q'):
        raise urwid.ExitMainLoop()
    else:
        pass

palette = [
  ('body',              'black',       'light gray',   'standout'),
  ('header',            'white',       'dark cyan',    'bold'),
  ('headerbg',           'white',      'black',   'bold'),
  ('button normal',     'light gray',  'dark blue',    'standout'),
  ('button select',     'white',       'dark green'),
  ('button disabled',   'dark gray',   'dark blue'),
  ('edit',              'light gray',  'dark blue'),
  ('backpane',          'brown',       'black',        ''),
  ('bigtext',           'yellow',      'black',        'bold'),
  ('chars',             'light cyan',  'black',        ''),
  ('fontname',          'default',        'black'),
  ('index',             'light cyan',     'black'),
  ('meta',              'light cyan',     'default'),
  ('metatag',           'dark green',     'default'),
  ('footer',            'light gray',     'default'),


  ('exit',              'white',       'dark cyan',    ''),
]

palette2 = [
('header', 'black,underline', 'light gray', 'standout,underline',
            'black,underline', '#88a'),
('panel', 'light gray', 'dark blue', '',
            '#ffd', '#00a'),
('focus', 'light gray', 'dark cyan', 'standout',
            '#ff8', '#806'),
]


args = sys.argv[1:]
if len(args) and not args[0].startswith('--'):
    pyfiglet.SHARED_DIRECTORY = args.pop(0)
else:
    flf_dir = os.getenv('FIGLET_DIRECTORY')
    pyfiglet.SHARED_DIRECTORY = flf_dir

max_fonts = os.getenv('FV_MAX_FONTS', 100)

#app_title_flf = Figlet('Banner3-D', width=200)
#app_title_flf = Figlet('miniwi', width=200)
#app_title_flf = Figlet('kompaktblk', width=200)
#app_title_flf = Figlet('Stronger Than All', width=200)
#app_title_flf = Figlet('cosmic', width=200)
#app_title_flf = Figlet('DOS Rebel', width=200)
app_title_flf = Figlet('ANSI Shadow', width=200)

fontfiles = []
fonts = {}

examples_maxwidth = 0
for fp in os.listdir(pyfiglet.SHARED_DIRECTORY):

    if not fp.endswith('.flf'): continue
    fontfiles.append(fp)

    flfn = os.path.splitext(fp)[0]
    try:
        flf = Figlet(font=flfn, width=160, justify='left')
    except:
        continue

    fontinfo = dict(figlet=flf)
    fonts[flfn] = fontinfo

    if ord('A') in flf.Font.chars and flf.Font.chars[ord('A')]:
        fontinfo['alpha'] = True
        # XXX: not sure about this detect, but it works for some cases
        if ord('a') in flf.Font.chars and flf.Font.chars[ord('a')] != flf.Font.chars[ord('A')]:
            fontinfo['allcaps'] = False
        else:
            fontinfo['allcaps'] = True
    else:
        fontinfo['alpha'] = False

    if ord('1') in flf.Font.chars and flf.Font.chars[ord('1')]:
        fontinfo['numeric'] = True
    else:
        fontinfo['numeric'] = False

    text1 = flf.renderText("M")
    m_width = 0
    m_height = 0
    # Not sure if we need to check all lines for length
    for line in text1.split('\n'):
        m_width = max(m_width, len(line))
        examples_maxwidth = max(examples_maxwidth, len(line))
        m_height += 1

    fontinfo['m-height'] = m_height
    fontinfo['m-width'] = m_width

    if fontinfo['alpha']:
        if fontinfo['allcaps']:
            teststr = "AF"
        else:
            teststr = "AaFf"
    else:
        teststr = ''
    if fontinfo['numeric']:
        teststr += ' 123'

    text2 = flf.renderText(teststr)
    fontinfo['shortexample']=text2

    #print(flfn, "M: %ix%i" % ( m_width, m_height ),
    #      fontinfo['alpha'] and ( fontinfo['allcaps'] and 'block' or 'regular' ) or 'non-alpha')
    #print(flf.Font.infoFont())

    if max_fonts:
        if len(fonts) == max_fonts:
            print('Maximum %i fonts read (adjust FV_MAX_FONTS)' % max_fonts)
            break


def main():
    def handle_click(button):
        pass
        #loop.widget
        #urwid.Overlay(urwid.Text('notes here'), main_widget, align='center', width=('relative', 80), valign='middle', height=('relative', 80))

    screen = urwid.raw_display.Screen()
    screen.register_palette(palette)
    lb = urwid.SimpleListWalker([])
    names = list(fonts.keys())
    names.sort()
    for i, name in enumerate(names):
        fontinfo = fonts[name]
        example = fontinfo['shortexample']

        nametext = urwid.Text( ('chars', [
            ('index', "%i." % (i+1)), " ",
            ('fontname', name),]))

        metatext = urwid.Text( ('meta', [
            "M-size: %ix%i" % ( fontinfo['m-width'],
                                fontinfo['m-height']), ", ",
            '%i glyphs' % len(fontinfo['figlet'].Font.chars), ", ",
            ('metatag', fontinfo['alpha'] and (
                                    fontinfo['allcaps'] and 'allcaps' or 'regular'
                                ) or 'non-alpha'), " ",
        ]))

        # TODO: rewrite main to setup for dialogs, write widget with parameterized popup
        infob = urwid.Button('', handle_click)

        lb.extend([
            urwid.Columns([
                ('weight', 1, urwid.AttrWrap( urwid.Padding( urwid.Pile([
                    urwid.Padding( nametext, align='left', left=1, right=0),
                    urwid.AttrWrap(
                        urwid.Padding( metatext, align='right', width='pack',
                                      left=2, right=1), 'meta'),
                    urwid.AttrWrap( urwid.Padding( infob, align='right', width=5,
                                                  right=1), 'meta')
                ]), left=0, right=0), 'chars')),
                ('weight', 4, urwid.AttrWrap( urwid.Padding( urwid.Text(example),
                                                           align='center',
                                                           #width='pack',
                                                            width='clip',
                                                           min_width=examples_maxwidth,
                                                           left=2, right=2), 'bigtext')),
            ])
        ])

    def unhandled_input(key):
        if key in ('Q','q','esc'):
            raise urwid.ExitMainLoop()

    #title = urwid.BigText("Figlet Browser", urwid.HalfBlock5x4Font())
    title = urwid.Text(app_title_flf.renderText(" FIGLet LV").rstrip())

    status = "%i fonts loaded" % len(fonts)
    if len(fonts) != len(fontfiles):
        status += " (%i found)" % len(fontfiles)
    if max_fonts and len(fonts) == max_fonts:
        status += " (max)"

    urwid.MainLoop( urwid.Frame(
        urwid.ListBox(lb),

        header=urwid.AttrWrap( urwid.Filler( urwid.AttrWrap( urwid.Filler(
            urwid.Padding(
                         urwid.Columns([(72, title), urwid.Padding(
                urwid.Text(('meta', '▓▒░     ./\/\p3 \'25  ░▒▓')),
                align='right', width='pack')]), width='pack'),
                top=1, bottom=1), 'header'), top=1, bottom=1), 'headerbg'),

        footer=urwid.AttrWrap( urwid.Padding(
                        urwid.Text(status),
                        width='pack',
                        align='center'), 'footer')
    ), screen=screen, unhandled_input=unhandled_input).run()


class PassePartou(urwid.WidgetPlaceholder):

    def __init__(self, box, backpane):
        super(PassePartou, self).__init__(backpane)

        self.open_box(box)

    def open_box(self, box):
        self.original_widget = urwid.Overlay(urwid.LineBox(box),
            self.original_widget,
            align='center', width=('relative', 80),
            valign='middle', height=('relative', 80),
            min_width=32, min_height=8)

    def keypress(self, size, key):
        if key in ('Q','q'):
            raise urwid.ExitMainLoop()
        #if key == 'esc' and self.box_level > 1:
        #    self.original_widget = self.original_widget[0]
        #else:
        #    return super(CascadingBoxes, self).keypress(size, key)

Powerline_Extra_crosshatch_leftdiag_1_2_sprite =(
    u'  ',
    u'  ',
    u'  ')

Powerline_Extra_crosshatch_leftdiag_1_3_sprite =(
    u' █ █',
    u'█ █ ',
    u'█ █ ',
    u' █ █')

Powerline_Extra_crosshatch_leftdiag_1_4_sprite =(
    u' ██ ██',
    u' ██ ██',
    u'██ ██ ',
    u'██ ██ ',
    u'█ ██ █')

Powerline_Extra_crosshatch_leftdiag_2_5_sprite = (
    u'  ███  ███',
    u'  ███  ███',
    u' ███  ███ ',
    u'███  ███  ',
    u'███  ███  ',
    u'██  ███  █',
    u'█  ███  ██')

Powerline_Extra_crosshatch_leftdiag_3_12_sprite = (
    u'   ██████████   ██████████',
    u'  ██████████   ██████████ ',
    u' ██████████   ██████████  ',
    u'██████████   ██████████   ',
    u'██████████   ██████████   ',
    u'█████████   ██████████   █',
    u'████████   ██████████   ██',
    u'███████   ██████████   ███',
    u'██████   ██████████   ████',
    u'█████   ██████████   █████',
    u'████   ██████████   ██████',
    u'███   ██████████   ███████',
    u'██   ██████████   ████████',
    u'█   ██████████   █████████',
    u'   ██████████   ██████████')

def make_fill_from_pattern(sprite):
    # XXX: This should easily cover 1920x1200 at medium 12pt font size
    width = 250
    height = 80
    #
    out = []
    l = 0
    for lineseg in sprite:
        out.append(lineseg * round(width / len(lineseg)))
    x=0
    for r in range(len(out)-1, height - len(out)):
        out.append(out[x])
        x+=1
        if x == len(sprite): x=0
    return '\n'.join(out)

def main2():
    #back = urwid.SolidFill(u'/')
    back = urwid.AttrMap(
            urwid.Filler(
                urwid.Text(
                    make_fill_from_pattern(Powerline_Extra_crosshatch_leftdiag_3_12_sprite),
                    wrap='clip'),
                height='pack'),
            'backpane'
        )


    lb = urwid.SimpleListWalker([])
    for name, fontinfo in fonts.items():
        example = fontinfo['shortexample']
        t = name +'  '+ "M: %ix%i" % ( fontinfo['m-height'], fontinfo['m-width'] )
        #t += fontinfo['alpha'] and ( fontinfo['allcaps'] and 'block' or 'regular' ) or 'non-alpha'

        lb.extend([urwid.Columns([
            #urwid.Padding( urwid.Text(name), align='right', width='pack', left=2, right=2),
            #urwid.Padding( urwid.Text(example), align='center', width='pack', left=2, right=2),
            #urwid.Padding( urwid.Text(""), width='pack' )
            ('weight', 1, urwid.AttrMap( urwid.Padding( urwid.Text(t),
                                                       align='right',
                                                       left=2, right=2), 'chars')),
            ('weight', 4, urwid.AttrMap( urwid.Padding( urwid.Text(example),
                                                       align='center',
                                                       width='pack',
                                                       left=2, right=2), 'bigtext')),
        ])])
    box = urwid.ListBox(lb)
    top = PassePartou(box, back)
    urwid.MainLoop(top, palette=palette).run()

if __name__ == "__main__":
    if '--framed' in args:
        main2()
    else:
        main()
#
