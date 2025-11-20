import os
import socket
import urwid
import selectors
import json

menu_top = None
#menu_top = menu(u'Main Menu', [
#    sub_menu(u'Applications', [
#        sub_menu(u'Accessories', [
#            menu_button(u'Text Editor', item_chosen),
#            menu_button(u'Terminal', item_chosen),
#        ]),
#    ]),
#    sub_menu(u'System', [
#        sub_menu(u'Preferences', [
#            menu_button(u'Appearance', item_chosen),
#        ]),
#        menu_button(u'Lock Screen', item_chosen),
#    ]),
#])

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

class CascadingBoxes(urwid.WidgetPlaceholder):
    max_box_levels = 4

    def __init__(self, box):
        super(CascadingBoxes, self).__init__(urwid.SolidFill(u'/'))
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

class JSONSocketReceiver:
    def __init__(self, socket_path, on_message):
        self.sock = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
        self.sock.bind(socket_path)
        self.sock.listen(1)
        self.sock.setblocking(False)
        self.selector = selectors.DefaultSelector()
        self.selector.register(self.sock, selectors.EVENT_READ, self._accept)
        self.on_message = on_message

    def _accept(self, sock):
        conn, _ = sock.accept()
        conn.setblocking(False)
        data = b""
        try:
            while True:
                chunk = conn.recv(4096)
                if not chunk:
                    break
                data += chunk
        except BlockingIOError:
            pass  # non-blocking: no more data yet
        finally:
            conn.close()
        if data:
            try:
                msg = json.loads(data.decode())
            except Exception as e:
                msg = {"text": f"JSON error: {e}"}
            self.on_message(msg)

    def process_events(self):
        for key, _ in self.selector.select(0):
            callback = key.data
            callback(key.fileobj)

def main():
    global menu_top, top, loop, receiver

    SOCKET_PATH = os.getenv('SOCKET_PATH', '/tmp/test-urwid.sock')

    # Remove socket file if it exists
    if os.path.exists(SOCKET_PATH):
        print("Cleaning stale socket...")
        os.unlink(SOCKET_PATH)

    def unhandled_input(key):
        if key in ('Q','q','esc'):
            raise urwid.ExitMainLoop()

    if not menu_top:
        text = urwid.Text("[No Data]")
        menu_top = urwid.ListBox([text])
    #top = CascadingBoxes(menu_top)
    #top = urwid.Filler(CrossHatch())
    top = CrossHatch()

    loop = urwid.MainLoop(top, palette=[('reversed', 'standout', '')],
                          unhandled_input=unhandled_input)

    def display_message(msg):
        txt.set_text(msg.get('text', str(msg)))

    receiver = JSONSocketReceiver(SOCKET_PATH, display_message)
    loop.watch_file(receiver.sock, receiver.process_events)
    loop.run()
    os.unlink(SOCKET_PATH)


if __name__ == '__main__':
    #os.getenv('US_PY_INIT')

    main()
