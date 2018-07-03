"""Test available screen area in curses.
"""
import curses
import traceback


class x_curses_screen_area(object):
	@staticmethod
	def start():
		try:
			app = x_curses_screen_area()
			return app.run()
		except:
			if app:
				app.restore()
			return traceback.print_exc()

	def run(self):
		print "Starting Crossbow..."
		self.prepare()

		while True:
			self.update()

			c = self.stdscr.getch() # wait for keystroke
			if 0<c<256: # process ascii
				c = chr(c)
				if c == 'q':
					break # exit main loop

		self.restore()

	def update(self):
		self.stdscr.clear()
		ymax, xmax = self.stdscr.getmaxyx()

		for y in range(0, ymax):
			self.stdscr.insstr(y, 0, `y`, curses.color_pair(2))
			self.stdscr.insstr(y, 2, '-'*(xmax-2), curses.color_pair(2))

		self.stdscr.insstr(0, 4, "y,x:%s,%s" % (ymax, xmax))

	def prepare(self):
		self.stdscr = curses.initscr()

		curses.noecho()
		curses.cbreak()
		curses.start_color()

		curses.use_default_colors()
		curses.init_pair(1, -1, -1)
		curses.init_pair(2, curses.COLOR_YELLOW, -1)

	def restore(self):
		curses.nocbreak()
		curses.echo()
		curses.endwin()

if __name__ == '__main__':
	import sys
	sys.exit(x_curses_screen_area.start())
