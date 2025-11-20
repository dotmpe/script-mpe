import sys
import urwid

fills={
    'crosshatch': "╳",
    'crosshatch-negative': '🮽',
    'checkerboard': '🮖',
    'shade-tl': '🮜',
    'shade-tr': '🮝',
    'shade-bl': '🮟',
    'shade-br': '🮞',
    'quadrants-ul+lr': '▚',
    'quadrants-ur+ll': '▞',
    'half-shaded-top': '🮎',
    'half-shaded-bottom': '🮏',

# FIXME: write fill for multi-char glyphs
#    '2-char-circle': ' 🯣'
#  [U+2591]='░	(Light shade)'
#  [U+2592]='▒	(Medium shade)'
#  [U+2593]='▓	(Dark shade)'
#  [U+259A]='▚	(Quadrant upper left + lower right)'
#  [U+259E]='▞	(Quadrant upper right + lower left)'
#  [U+2588]='█	(Full block)'
#  [U+2580]='▀	(Upper half)'
#  [U+2584]='▄	(Lower half)'
#  [U+25E2]='◢	(Lower left triangle)'
#  [U+25E3]='◣	(Lower right triangle)'
#  [U+25E4]='◤	(Upper left triangle)'
#  [U+25E5]='◥	(Upper right triangle)'
#  [U+2581]='▁	(Lower 1/8 block)'
#  [U+2582]='▂	(Lower 1/4 block)'
#  [U+2583]='▃	(Lower 3/8 block)'
#  [U+2585]='▅	(Lower 5/8 block)'
#  [U+2586]='▆	(Lower 3/4 block)'
#  [U+2587]='▇	(Lower 7/8 block)'
#  [U+2589]='▉	(Left 7/8 block)'
#  [U+258A]='▊	(Left 3/4 block)'
#  [U+258B]='▋	(Left 5/8 block)'
#  [U+258C]='▌	(Left half block)'
#  [U+258D]='▍	(Left 3/8 block)'
#  [U+258E]='▎	(Left 1/4 block)'
#  [U+258F]='▏	(Left 1/8 block)'
}

class CharFill(urwid.Widget):
    # Use U+2573
    def __init__(self, char="╳"):
        super().__init__()
        self.char = char
        self.height = None

    def render(self, size, focus=False):
        width = size[0]
        self.height = size[1] if len(size) > 1 else 1
        lines = [(self.char * width).encode('utf-8') for _ in range(self.height)]
        return urwid.TextCanvas(lines)

    #def rows(self, maxcol, focus):
    #    return self.height or 1

    def process_input(self, keys):
        pass
        #return True
        # super(CharFill, self).process_input(keys)


def unhandled_input(key):
    if key in ('Q','q','esc'):
        raise urwid.ExitMainLoop()

if __name__ == '__main__':
    args = sys.argv[1:]
    top = None
    if not args:
        args = [
            '--simple', 'crosshatch',
            '--frame',
            '--pane', '20x10'
        ]
    while args and args[0].startswith('-'):
        if args[0] == '--simple':
            top = CharFill(fills[args[1]])
            args=args[2:]
        elif args[0] == '--char':
            top = CharFill(args[1])
            args=args[2:]
        elif args[0] == '--pane':
            size = tuple(map(int, args[1].split('x')))
            top = urwid.Filler(urwid.Padding(top, 'center', size[0]), 'middle',
                               size[1])
            args=args[2:]
        elif args[0] == '--frame':
            top = urwid.LineBox(top)
            args=args[1:]

    loop = urwid.MainLoop(top, palette=[('reversed', 'standout', '')],
                          unhandled_input=unhandled_input)
    loop.run()
