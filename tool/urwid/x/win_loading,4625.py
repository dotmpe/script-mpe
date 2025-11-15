import os
#import subprocess
import urwid

#subprocess.run(['clear'])
#subprocess.run(['tput'], input=b"sgr0\nsetaf 12")

cols = int(os.getenv('COLUMNS', 79))

fuzz = "░░░░░░░░░░░░░░░▒▒▒▒▒▒▒▒▒▒▒▒▒▒▓▓▓▓▓▓▓▓▓▓███████████████████████████▓▓▓▓▓▓▓▓▓▓▒▒▒▒▒▒▒▒▒▒▒▒▒▒░░░░░░░░░░░░░░░"

class Marquee(urwid.WidgetWrap):
    def __init__(self, fuzz):
        self.fuzz = fuzz
        self.offset = 0
        self.update()
        self.txt = urwid.Text(('marquee', self.text), wrap='clip')
        super().__init__(self.txt)

    def scroll(self, loop=None, user_data=None):
        self.offset += 1
        if self.offset > len(self.text) - self.width:
            self.offset = 0
        display = self.text[self.offset:self.offset+self.width]
        self.txt.set_text(display)
        if loop:
            loop.set_alarm_in(0.1, self.scroll)

    def update(self):
        global ui, cols
        if ui.s:
            cols = ui.get_cols_rows()[0]
        self.width = cols
        #    #cols = ui.get_cols_rows()[0]
        #padd = "".join(round(cols/2) * " ")
        padd = "".join(round(200/2) * " ")
        self.text = padd+self.fuzz+padd+self.fuzz

def unhandled_input(e):
    global marquee
    marquee.update()

palette = [
        ('marquee', 'light blue', 'black')
]

if __name__ == "__main__":
    ui = urwid.curses_display.Screen()
    #ui.register_palette(palette)
    marquee = Marquee(fuzz)
    fill = urwid.Filler(marquee)
    loop = urwid.MainLoop(fill, palette=palette, unhandled_input=unhandled_input)
    # Kick off the scrolling
    loop.set_alarm_in(0.1, marquee.scroll)
    loop.run()


