#!/usr/bin/env python
import gi

gi.require_version("Gtk", "3.0")
from gi.repository import Gtk

class ComboRenderer:
    items = ("item 1", "item 2", "item 3", "item 4", "item 5")

    def __init__(self):
        # Create window and connect its destroy signal.
        window = Gtk.Window()
        window.connect("destroy", Gtk.main_quit)

        # Window setup
        window.set_border_width(10)
        window.set_position(Gtk.WindowPosition.CENTER_ALWAYS)
        window.set_keep_above(True)
        window.set_resizable(False)
        window.set_default_size(400, 200)

        # Create a combobox column
        model = Gtk.ListStore(str)

        for item in self.items:
            model.append([item])

        # Create and add a treeview widget to the window.
        self.treeview = Gtk.TreeView()
        window.add(self.treeview)

        renderer = Gtk.CellRendererCombo()
        renderer.set_property("text-column", 0)
        renderer.set_property("editable", True)
        renderer.set_property("has-entry", False)
        renderer.connect("edited", self.renderer_edited)
        renderer.set_property("model", model)

        # Create columns
        column_one = Gtk.TreeViewColumn("Text", Gtk.CellRendererText(), text=0)
        column_two = Gtk.TreeViewColumn("Combobox", renderer, text=1)

        self.treeview.append_column(column_one)
        self.treeview.append_column(column_two)

        # Create liststore.
        liststore = Gtk.ListStore(str, str)

        # Append a couple of rows.
        liststore.append(["Some text", "Click here to select an item."])
        liststore.append(["More text", "Click here to select an item."])
        liststore.append(["More text", "Click here to select an item."])
        liststore.append(["More text", "Click here to select an item."])
        liststore.append(["More text", "Click here to select an item."])

        # Set model.
        self.treeview.set_model(liststore)

        window.show_all()

    def renderer_edited(self, cellrenderertext, path, new_text):
        treeview_model = self.treeview.get_model()
        iter = treeview_model.get_iter(path)
        treeview_model.set_value(iter, 1, new_text)

    def main(self):
        Gtk.main()

if __name__ == "__main__":
    app = ComboRenderer()
    app.main()

