"""
An Unicode block shaded "loader" or bar spinner reminiscent of win95,
but in ncurses.
"""

import urwid

fuzz = "░░░░░░░░░░░░░░░▒▒▒▒▒▒▒▒▒▒▒▒▒▒▓▓▓▓▓▓▓▓▓▓███████████████████████████▓▓▓▓▓▓▓▓▓▓▒▒▒▒▒▒▒▒▒▒▒▒▒▒░░░░░░░░░░░░░░░"

class WinLoadingMarquee(urwid.Widget):
    def __init__(self, fuzz, step=1, speed=0.1):
        super().__init__()
        self.fuzz = fuzz
        self.offset = 0
        self.step = step
        self.speed = speed
        self._invalidate_callback = None

    def selectable(self):
        return False

    def render(self, size, focus=False):
        # size[0]: (columns,) – the available width to draw
        width = size[0]
        # Pad or repeat text to always have something to fill
        padd = len(fuzz)
        long_text = 2 * (self.fuzz + padd*" ")
        display_text = long_text[self.offset:self.offset + width]
        if (self.offset >= 2*padd):
            self.offset = 0
        # Defensive in case of short long_text
        display_text = display_text.ljust(width)
        return urwid.Text(('marquee', display_text)).render((width,), focus)

    def rows(self, maxcol, focus):
        return 1

    def marquee_step(self, loop, user_data):
        #width = loop.screen.get_cols_rows()[0]
        #long_text = 2 * (self.fuzz + ((width // 2))*" "))
        #self.offset = (self.offset + self.step) % len(long_text)
        self.offset += 1
        self._invalidate()
        loop.set_alarm_in(self.speed, self.marquee_step)

def unhandled_input(key):
    if key in ('q', 'Q'):
        raise urwid.ExitMainLoop()

palette = [
        ('marquee', 'light blue', 'black')
]

if __name__ == "__main__":
    marquee = WinLoadingMarquee(fuzz)
    fill = urwid.Filler(marquee)
    loop = urwid.MainLoop(fill, palette=palette, unhandled_input=unhandled_input)
    # Kick off the scrolling
    loop.set_alarm_in(0.1, marquee.marquee_step)
    loop.run()
