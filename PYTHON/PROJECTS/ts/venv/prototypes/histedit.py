#!/usr/bin/env python3
import gi

gi.require_version("Gtk", "3.0")
from gi.repository import Gtk, Gdk

import sys

class HistWindow(Gtk.Window):
    def __init__(self):
        super().__init__(title="Torrent Query")

        # HistWindow setup
        self.set_border_width(10)
        self.set_position(Gtk.WindowPosition.CENTER_ALWAYS)
        self.set_keep_above(True)
        self.set_resizable(True)
        self.set_default_size(380, 200)
        self.at_top = True
        self.at_bottom = False

        vbox = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=6)
        hbox = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=6)

        self.entry = Gtk.Entry()
        self.entry_label = Gtk.Label(label="Enter a new query...")
        self.submit_label = Gtk.Label(label="Press Enter to submit query or Esc to exit...")

        self.model = Gtk.ListStore(str)
        self.model.append(["The Godfather"])
        self.model.append(["Casablanca"])
        self.model.append(["Alien"])
        self.model.append(["The Good, The Bad, and The Ugly"])

        self.treeview = Gtk.TreeView(model=self.model)

        self.renderer = Gtk.CellRendererText()
        self.renderer.set_property("editable", True)

        column = Gtk.TreeViewColumn(
            "Previous Queries (Ctrl-X to Delete)", self.renderer, text=0
        )
        self.treeview.append_column(column)
        self.selection = self.treeview.get_selection()
        self.selection.unselect_all() # initially nothing is selected


        self.button1 = Gtk.Button(label="Search")
        self.button1.connect("clicked", self.on_search)

        self.button2 = Gtk.Button(label="Engine")
        self.button2.connect("clicked", self.on_engine)

        self.button3 = Gtk.Button(label="Clear History")
        self.button3.connect("clicked", self.on_clear_hist)

        self.button4 = Gtk.Button(label="Quit")
        self.button4.connect("clicked", self.on_quit)

        # Signals
        self.connect("key-release-event", self.on_key_release)  # intercept key press
        self.connect("window-state-event", self.on_startup)
        self.entry.connect("activate", self.entry_activated)
        self.renderer.connect("edited", self.text_edited)
        self.connect("key-press-event", self.on_key_press)  # intercept Ctrl-X key

        vbox.pack_start(self.entry_label, False, False, 0)
        vbox.pack_start(self.entry, False, False, 0)
        vbox.pack_start(self.submit_label, False, False, 0)
        vbox.pack_start(self.treeview, False, False, 0)
        hbox.pack_start(self.button1, False, False, 0)
        hbox.pack_start(self.button2, False, False, 0)
        hbox.pack_start(self.button3, False, False, 0)
        hbox.pack_start(self.button4, False, False, 0)
        vbox.pack_start(hbox, False, False, 0)
        self.add(vbox)

    def on_search(self, event):
        pass

    def on_engine(self, event):
        pass

    def on_clear_hist(self, event):
        pass

    def on_quit(self, event):
        sys.exit()

    def on_startup(self, widget, event):
        self.submit_label.hide()

    def entry_activated(self, widget):
        text = self.entry.get_text()
        found = False
        if len(text) and not text.isspace():
            for ndx, row in enumerate(self.model):
                if text.lower() == self.model[ndx][0].lower():
                    found = True

            if not found:
                self.model.append([text])

            self.entry.set_text("")
            self.treeview.show()
            selection = self.treeview.get_selection()
            selection.unselect_all()
            self.submit_label.hide()
        else:
            self.destroy()

    def text_edited(self, widget, path, text):
        self.model[path][0] = text
        self.entry.set_text(text)
        self.entry.grab_focus()
        self.submit_label.show()
        self.treeview.hide()

    def on_key_press(self, widget, event):
        if event.state & Gdk.ModifierType.CONTROL_MASK and event.keyval == 120:  # Ctrl-X - delete row
            selection = self.treeview.get_selection()
            model, t_iter = selection.get_selected()
            if t_iter is not None:
                model.remove(t_iter)

            self.treeview.set_cursor(0)  # highlight first row
            self.entry.grab_focus()

    def set_boundary(self):
        self.at_bottom = False
        self.at_top = False

        items = len(self.model); items -= 1
        index = self.selection.get_selected_rows()[1][0][0]

        if index == 0:
            self.at_top = True
            return

        if index == items:
            self.at_bottom = True
            return


    def manage_cursor(self, key):
        model, t_iter = self.selection.get_selected()
        if t_iter is None: # ensure something is selected
            self.treeview.set_cursor(0)
            self.selection.unselect_all()
            return

        if key == "down":
            self.treeview.show()
            self.treeview.grab_focus()
            self.submit_label.hide()
            if self.at_bottom == True:
                self.treeview.set_cursor(0)

            self.set_boundary()
            return

        if key == "up":
            self.treeview.show()
            self.treeview.grab_focus()
            self.submit_label.hide()
            if self.at_top == True:
                items = len(self.model); items -= 1
                self.treeview.set_cursor(items)

            self.set_boundary()
            return

        if key == "esc":
            self.selection.unselect_all()
            self.entry.set_text("")
            self.entry.grab_focus()
            self.submit_label.hide()
            self.treeview.show()
            return

    def on_key_release(self, widget, event):
        key = None

        match event.keyval:
            case Gdk.KEY_Up:
                key = "up"
            case Gdk.KEY_Down:
                key = "down"
            case Gdk.KEY_Escape:
                key = "esc"

        self.manage_cursor(key)


win = HistWindow()
win.connect("destroy", Gtk.main_quit)
win.show_all()

Gtk.main()
