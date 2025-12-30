#!/usr/bin/env python
#
# Urwid terminal emulation widget example app
#    Copyright (C) 2010  aszlig
#
#    This library is free software; you can redistribute it and/or
#    modify it under the terms of the GNU Lesser General Public
#    License as published by the Free Software Foundation; either
#    version 2.1 of the License, or (at your option) any later version.
#
#    This library is distributed in the hope that it will be useful,
#    but WITHOUT ANY WARRANTY; without even the implied warranty of
#    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
#    Lesser General Public License for more details.
#
#    You should have received a copy of the GNU Lesser General Public
#    License along with this library; if not, write to the Free Software
#    Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA
#
# Urwid web site: http://excess.org/urwid/

import urwid
import os

def main(command):
    urwid.set_encoding('utf8')
    #cmd = None
    #cmd = [ 'bash' ] + command
    term = urwid.Terminal(command, encoding='utf-8')
    env = dict(os.environ)
    title = env['TITLE']
    #env['TERM'] = 'xterm-16color'
    #env['US_TERM'] = 'xterm-16color'
    mainframe = urwid.LineBox(
        term
        #urwid.Pile([
        #    #('fixed', 1, urwid.Filler(urwid.Text('Title'))),
        #    ('weight', 70, term),
        #    #('fixed', 1, urwid.Filler(urwid.Edit('focus test edit: '))),
        #]),
    )

    def set_title(widget, title):
        mainframe.set_title(title)

    def quit(*args, **kwargs):
        raise urwid.ExitMainLoop()

    def handle_key(key):
        if key in ('q', 'Q'):
            quit()

    urwid.connect_signal(term, 'title', set_title)
    urwid.connect_signal(term, 'closed', quit)

    # Not sure what the signal above is supposed to pick up on
    mainframe.set_title(title)

    loop = urwid.MainLoop(
        mainframe,
        handle_mouse=False,
        unhandled_input=handle_key)

    term.main_loop = loop
    loop.run()


if __name__ == '__main__':
    import sys
    main(sys.argv[1:])
