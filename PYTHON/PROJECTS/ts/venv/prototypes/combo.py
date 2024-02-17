#!/usr/bin/env python
import gi

gi.require_version("Gtk", "3.0")
from gi.repository import Gtk, Gdk

class ComboBoxWindow(Gtk.Window):
    def __init__(self):
        super().__init__(title="ComboBox Example")

        # Window setup
        self.set_border_width(10)
        self.set_position(Gtk.WindowPosition.CENTER_ALWAYS)
        self.set_keep_above(True)
        self.set_resizable(False)
        self.set_default_size(400, 100)

        vbox = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=6)

        model = Gtk.ListStore(int, str)
        renderer = Gtk.CellRendererText()

        combo = Gtk.ComboBox.new_with_model(model)
        combo.set_active(0)
        combo.pack_start(renderer, True)
        combo.add_attribute(renderer, 'text', 1)
        combo.connect("changed", self.on_combo_changed)

        entry = Gtk.Entry()

        self.connect("key-release-event", self.on_key_release, entry, model, combo)  # intercept enter key
        combo.connect("button-press-event", self.on_button_press_event)

        vbox.pack_start(entry, False, False, 0)
        vbox.pack_start(combo, False, False, 0)

        self.add(vbox)

    def on_button_press_event(self, widget, event):
        print("Click")

    def on_combo_changed(self, combo):
        print("Combo changed")

    def on_key_release(self, widget, event, entry, model, combo):
        if event.string == '\r': # Enter key
            search_term = entry.get_text()
            if len(search_term) > 0:
                ndx = len(model)
                model.append([ndx,search_term])
                combo.set_active(ndx)
                entry.set_text("")

win = ComboBoxWindow()

win.connect("destroy", Gtk.main_quit)
win.show_all()
Gtk.main()
