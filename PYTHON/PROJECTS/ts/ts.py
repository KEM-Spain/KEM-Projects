#!/usr/bin/env python
import gi

gi.require_version('Gtk', '3.0')

from gi.repository import Gtk, Gdk, Gio, GLib
from gi.repository.Gtk import ListStore
from bs4 import BeautifulSoup as Soup
from bs4 import SoupStrainer as Strainer
from datetime import datetime
from logging import handlers
import getopt
import logging
import numpy as np
import os
import re
import requests
import subprocess
import sys
import threading
import time

# Constants
BOLD = "\033[1m"
DEFAULT_ENGINE = "pb"
ITALIC = "\033[3m"
RED = "\033[0;31m"
RESET = "\033[0m"
SCRIPT = os.path.basename(sys.argv[0])
TORRENT_CLIENT = "/usr/bin/deluge"
WHITE = "\033[0;37m"

SUPPORTED_ENGINES = {
    "pb": "The Pirate Bay",
    "lime": "Lime Torrents",
    "eztv": "Eztv Torrents"
}

ENGINE_URLS = {
    "pb": "https://thepiratebay10.info",
    "lime": "https://www.limetorrents.lol",
    "eztv": "https://eztv.re"
}

USAGE_TXT = """
Usage: {} [-h] [-e <ENGINE>] [<TITLE>]

Options:-h: help
        -e: <ENGINE>

DESC: Search engine for {}
      Enter <TITLE> via gui or on the command line

SUPPORTED ENGINES:
    pb   : The Pirate Bay (default)
    lime : Lime Torrents
    eztv : Eztv Torrents

""".format(SCRIPT, os.path.basename(TORRENT_CLIENT).title())

# Globals
return_val = None
torrent_list = []
listing_window_active = False


# Module Methods
def app_exit(exit_code=0):
    sys.exit(exit_code)


def ascii_only(string):
    return ''.join(char for char in string if ord(char) < 128)


def get_cmdline():
    opts, args = [], []
    set_opts = {"engine": DEFAULT_ENGINE}

    try:
        opts, args = getopt.getopt(sys.argv[1:], "he:", ["engine="])
    except getopt.GetoptError as err:
        print(err)  # option not recognized
        usage()

    for o, a in opts:
        if o in ("-h", "--help"):
            usage()
        elif o in ("-e", "--engine"):
            set_opts = {"engine": a}
        else:
            assert False, "unhandled option"

    return set_opts, args


def get_model(site):
    engine_models = {
        "pb": "PBModel",
        "lime": "LimeModel",
        "eztv": "EztvModel"
    }
    return engine_models[site]


def handle_exception(exc_type, exc_value, exc_traceback):
    if issubclass(exc_type, KeyboardInterrupt):
        sys.__excepthook__(exc_type, exc_value, exc_traceback)
        return

    logger.error("Uncaught exception", exc_info=(exc_type, exc_value, exc_traceback))


def init_logging():
    sys_logger = logging.getLogger(__name__)
    sys_logger.setLevel(logging.WARN)

    syslog = logging.handlers.SysLogHandler(address='/dev/log')
    sys_logger.addHandler(syslog)  # file
    sys_logger.addHandler(logging.StreamHandler())  # stderr

    return sys_logger


def is_number(str_int):
    try:
        float(str_int)
        return True
    except ValueError:
        return False


def query_thread(model, search_term, callback):
    global return_val
    global torrent_list

    return_val, torrent_list = model.get_list(search_term)

    GLib.idle_add(callback)


def run_query_thread(model, search_term, callback):
    thread = threading.Thread(target=query_thread, args=[model, search_term, callback])
    thread.daemon = True
    thread.start()


def set_gtk_theme(gtk_theme):
    settings = Gtk.Settings.get_default()
    settings.set_property("gtk-theme-name", gtk_theme)


def usage():
    print(USAGE_TXT)
    app_exit()


# Classes and Methods
class SearchWin(Gtk.Window):
    def __init__(self, engine_key=None, search_term=None):
        super().__init__(title="Torrent Query")

        Gtk.Window.__init__(self)
        self.set_modal(True)

        # Arg inits
        self.engine_key = engine_key
        self.search_term = search_term

        if self.engine_key is None:
            self.engine_key = DEFAULT_ENGINE

        # SearchWin inits
        self.return_val = None
        self.torrent_list = None
        self.model_class = None
        self.spinner = Gtk.Spinner()
        self.prompt = Gtk.Label()
        self.set_query_model(self.engine_key)
        self.hist_model = Gtk.ListStore(str)
        self.hist_file = self.create_history()

        # Possible early exit; if search_term was passed, run query
        if self.search_term is not None:
            self.model_add_search(self.search_term.strip())
            self.do_query()
            if self.torrent_list is not None:
                self.destroy()
                return

        # Window setup
        self.set_border_width(10)
        self.set_position(Gtk.WindowPosition.CENTER_ALWAYS)
        self.set_resizable(True)
        self.set_default_size(400, 200)
        self.at_top = True
        self.at_bottom = False

        frame = Gtk.Frame()
        frame.set_shadow_type(Gtk.ShadowType.ETCHED_OUT)
        vbox = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=10)
        hbox = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=5)
        hbox.set_homogeneous(True)
        frame.add(hbox)

        self.entry = Gtk.Entry()
        self.set_prompt(True)
        self.submit_label = Gtk.Label(label="Press Enter to submit query or Esc to cancel...")

        self.treeview = Gtk.TreeView(model=self.hist_model)

        self.renderer = Gtk.CellRendererText()
        self.column = Gtk.TreeViewColumn("Unset", self.renderer, text=0)
        self.set_column_header(1)

        self.treeview.append_column(self.column)
        self.selection = self.treeview.get_selection()
        self.selection.unselect_all()  # initially nothing is selected

        self.button1 = Gtk.Button(label="Search")
        self.button1.connect("clicked", self.on_search)

        self.button2 = Gtk.Button(label="Engine")
        self.button2.connect("clicked", self.on_engine)

        self.button3 = Gtk.Button(label="Clear History")
        self.button3.connect("clicked", self.on_clear_hist)

        self.button4 = Gtk.Button(label="Quit")
        self.button4.connect("clicked", self.on_quit)

        # Signals
        self.connect("delete-event", self.on_destroy)
        self.connect("key-press-event", self.on_hist_row_delete)  # intercept Ctrl-X key
        self.connect("key-release-event", self.on_key_release)  # intercept key press
        self.connect("window-state-event", self.on_startup)
        self.entry.connect("activate", self.entry_activated)
        self.renderer.connect("edited", self.text_edited)
        self.treeview.connect("button-press-event", self.entry_activated)  # double click - submit row

        vbox.pack_start(self.spinner, False, False, 0)
        vbox.pack_start(self.prompt, False, False, 0)
        vbox.pack_start(self.entry, False, False, 0)
        vbox.pack_start(self.submit_label, False, False, 0)
        vbox.pack_start(self.treeview, False, False, 0)
        hbox.pack_start(self.button1, False, False, 0)
        hbox.pack_start(self.button2, False, False, 0)
        hbox.pack_start(self.button3, False, False, 0)
        hbox.pack_start(self.button4, False, False, 0)
        vbox.pack_start(frame, False, False, 0)
        self.add(vbox)

        self.show_all()
        Gtk.main()

    def on_destroy(self, widget, event):
        app_exit()

    def create_history(self):
        hist_path = os.environ['HOME'] + r'/.ts'

        try:
            if not os.path.exists(os.path.dirname(hist_path)):
                os.mkdir(os.path.dirname(hist_path))
        except OSError as err:
            print(err)

        hist_file = hist_path + '/hist.txt'

        os.umask(0)
        os.open(
            hist_file,
            flags=(os.O_RDWR | os.O_CREAT),
            mode=0o664
        )

        with open(hist_file, "r") as fh:
            for line in fh:
                self.hist_model.append([line.strip()])

        return hist_file

    def hist_save(self):
        os.remove(self.hist_file)
        self.hist_file = self.create_history()
        with open(self.hist_file, "a") as fh:
            for r in self.hist_model:
                r = list(r[:])
                line = r[0] + "\n"
                fh.write(line)

    def do_query(self):
        self.hist_save()
        self.spinner.start()
        run_query_thread(self.model_class, self.search_term, self.thread_complete)

    def thread_complete(self):
        global return_val
        global torrent_list

        self.spinner.stop()
        self.return_val = return_val
        self.torrent_list = torrent_list

        if self.return_val == 1:  # engine returned nothing
            self.set_prompt(False)
            return  # SearchWin remains visible
        else:
            self.destroy()  # SearchWin closes; ListingWin is displayed
            Gtk.main_quit()

    def do_search(self, event=None):
        entry_text = self.entry.get_text()

        search = False
        if len(entry_text) and event is None:
            search = True
            self.model_add_search(entry_text)
            self.selection.unselect_all()
            self.treeview.set_model(self.hist_model)
            self.treeview.show()
            self.submit_label.hide()
            self.submit_entry(entry_text)
            self.entry.set_text("")

        else:
            self.renderer.set_property("editable", False)
            if event is None:
                if search is False:
                    self.hist_save()
                    app_exit()

            elif event.type == Gdk.EventType.BUTTON_PRESS:
                self.renderer.set_property("editable", True)

            elif event.type == Gdk.EventType._2BUTTON_PRESS:
                if listing_window_active is True:  # limit ListingWin to one instance
                    return

                model, t_iter = self.selection.get_selected()

                if t_iter is not None:
                    t_view_highlight_text = model.get_value(t_iter, 0)
                    if len(t_view_highlight_text):
                        search = True
                        self.submit_entry(t_view_highlight_text)

    def model_add_search(self, search):
        if len(search) and not search.isspace():
            found = False
            for ndx, row in enumerate(self.hist_model):
                if search.lower() == self.hist_model[ndx][0].lower():
                    found = True

            if not found:
                self.hist_model.append([search])

    def engine_change_popup(self, menu, key):
        self.set_query_model(key)
        self.entry.grab_focus()

    def entry_activated(self, widget, event=None):
        self.do_search(event)

    def manage_cursor(self, key):
        model, t_iter = self.selection.get_selected()
        if t_iter is None:  # ensure something is selected
            self.treeview.set_cursor(0)
            return
        else:
            if key is None:
                self.set_column_header(2)

        if key == "down":
            self.set_prompt(True)
            self.submit_label.hide()

            if self.at_bottom:
                self.treeview.set_cursor(0)

            self.treeview.show()
            self.treeview.grab_focus()
            self.set_boundary()
            return

        if key == "up":
            self.submit_label.hide()

            if self.at_top:
                items = len(self.hist_model)
                items -= 1
                self.treeview.set_cursor(items)

            self.treeview.show()
            self.treeview.grab_focus()
            self.set_boundary()
            return

        if key == "esc":
            self.submit_label.hide()
            self.selection.unselect_all()
            self.treeview.show()

            if len(self.hist_model) != 0:
                self.set_column_header(1)

            self.entry.set_text("")
            self.entry.grab_focus()
            return

    def on_clear_hist(self, button):
        self.hist_model.clear()
        os.remove(self.hist_file)
        self.hist_file = self.create_history()
        self.treeview.set_model(self.hist_model)
        self.treeview.hide()
        self.resize(400, 200)
        self.set_column_header(1)
        self.entry.grab_focus()

    def on_engine(self, button):
        self.set_prompt(True)
        context_menu = Gtk.Menu()
        for key, value in SUPPORTED_ENGINES.items():
            if key == self.engine_key:
                continue
            cm_item = Gtk.MenuItem(label=value)
            cm_item.connect("activate", self.engine_change_popup, key)
            context_menu.add(cm_item)

        context_menu.show_all()
        context_menu.popup(None, None, None, None, 1, 1)

    def on_hist_row_delete(self, widget, event):
        if event.state & Gdk.ModifierType.CONTROL_MASK and event.keyval == 120:  # Ctrl-X - delete row
            if len(self.hist_model) == 0:
                return

            model, t_iter = self.selection.get_selected()

            if t_iter is not None:
                model.remove(t_iter)

            self.treeview.set_model(model)
            self.treeview.set_cursor(0)  # highlight first row
            self.resize(400, 200)
            self.set_column_header(1)
            self.entry.grab_focus()

    def on_key_release(self, widget, event):
        key = None

        if event.state & Gdk.ModifierType.SHIFT_MASK and event.keyval == 65056:
            key = "shift-tab"

        match event.keyval:
            case Gdk.KEY_Up:
                key = "up"
            case Gdk.KEY_Down:
                key = "down"
            case Gdk.KEY_Escape:
                key = "esc"
            case Gdk.KEY_Tab:
                key = "tab"

        if key == "up" and len(self.hist_model) == 0:  # Skip treeview if empty
            self.entry.grab_focus()
            return

        if (key == "down" or key == "tab" or key == "shift-tab") and len(
                self.hist_model) == 0:  # Skip treeview if empty

            if key == "tab":
                if self.treeview.has_focus():
                    self.button1.grab_focus()

            if key == "shift-tab":
                if self.treeview.has_focus():
                    self.entry.grab_focus()

            if key == "down":
                self.entry.grab_focus()

            return

        self.manage_cursor(key)

    def on_quit(self, button, event=None):
        self.hist_save()
        app_exit()

    def on_search(self, button):
        self.do_search()

    def on_startup(self, widget, event):
        self.submit_label.hide()

    def set_boundary(self):
        self.at_bottom = False
        self.at_top = False

        items = len(self.hist_model)
        items -= 1
        index = self.selection.get_selected_rows()[1][0][0]

        if index == 0:
            self.at_top = True
            return

        if index == items:
            self.at_bottom = True
            return

    def set_column_header(self, ndx):
        if len(self.hist_model) == 0:
            self.column.set_title("Previous Queries (None)")
        else:
            if ndx == 1:
                self.column.set_title("Previous Queries (Ctrl-X to Delete, Enter to Edit)")
            else:
                self.column.set_title("Right Arrow to Edit | Enter to select | Esc to Cancel")

    def set_prompt(self, state):
        if state is True:
            prompt_text = "Enter search phrase"
            self.prompt.set_label(prompt_text)
            self.prompt.set_markup('<span foreground="white">' + '<big>' + prompt_text + '</big></span>')
        else:
            prompt_text = "No results"
            self.prompt.set_label(prompt_text)
            self.prompt.set_markup('<span foreground="red">' + '<big>' + prompt_text + '</big></span>')

    def set_query_model(self, key):
        self.engine_key = key
        self.model_class = eval(get_model(key))
        self.set_title("Torrent Search - " + SUPPORTED_ENGINES[key])
        self.torrent_list = None

    def submit_entry(self, text):
        self.set_prompt(True)
        self.search_term = text

        if len(self.search_term) == 0:
            self.entry.grab_focus()
            return

        self.do_query()

    def text_edited(self, widget, path, text):
        self.hist_model[path][0] = text
        self.treeview.set_model(self.hist_model)
        self.entry.set_text(text)
        self.entry.grab_focus()
        self.submit_label.show()
        self.treeview.hide()


class ListingWin(Gtk.Window):
    torrent_list_store: ListStore

    def __init__(self, torrent_list, engine_key):
        # Arg inits
        self.torrent_list = torrent_list
        self.engine = engine_key

        Gtk.Window.__init__(self, title="Torrent Listing - " + SUPPORTED_ENGINES[self.engine])

        # Return value inits
        self.cancel = False
        self.new_engine = False
        self.download = False

        # Win inits
        self.popup_entry = None
        self.selected_titles = None

        # Window setup
        self.set_border_width(10)
        self.set_default_size(1000, 400)
        self.set_position(Gtk.WindowPosition.CENTER_ALWAYS)
        self.set_keep_above(True)

        # Post-process torrent_list: Create dictionary (fields 1,5) for magnet[title] lookup
        titles, magnets = [], []

        for L in self.torrent_list:
            titles.append(L[0])
            magnets.append(L[-1])

        # Stash the magnets
        self.magnet_dict = dict(zip(titles, magnets))

        # Post-process torrent_list: Create listStore (fields 1-5) without magnets
        post_list = np.array(self.torrent_list)
        store_data = post_list[:, :5].tolist()  # numpy syntax for grabbing fields 1-5 from each row

        # Create the ListStore model: "Title", "Date", "Seeds", "Leeches", "Size"
        self.torrent_list_store = Gtk.ListStore(str, str, int, int, str, float)

        for torrent_ref in store_data:
            f1 = torrent_ref[0]  # title
            f2 = torrent_ref[1]  # Date
            f3 = int(torrent_ref[2])  # Seeds
            f4 = int(torrent_ref[3])  # Leeches
            f5 = torrent_ref[4]  # Size
            #  sort MB, GB, and KiB
            if "N/A" in f5:
                s5 = 0
            elif "G" in f5:
                c5 = f5.replace('G', '')
                if is_number(c5):
                    n1 = float(c5)
                    n2 = float(1024)
                    s5 = n1 * n2
                else:
                    s5 = 0
            elif "M" in f5:
                c5 = f5.replace('M', '')
                if is_number(c5):
                    s5 = float(c5)
                else:
                    s5 = 0
            elif "K" in f5:
                c5 = f5.replace('KiB', '')
                if is_number(c5):
                    s5 = float(c5)
                else:
                    s5 = 0
            else:
                s5 = re.sub('[^0-9\.]', '', f5)
                if not is_number(s5):
                    s5 = 0

            row = [f1, f2, f3, f4, f5, s5]
            self.torrent_list_store.append(row)

        # Create the treeview
        self.treeview = Gtk.TreeView()
        self.treeview.set_model(self.torrent_list_store)  # pass the model
        self.treeview.get_selection().set_mode(Gtk.SelectionMode.MULTIPLE)  # multiple row selection
        self.treeview.set_cursor(0)  # highlight first row
        self.treeview.connect("button_press_event", self.show_context_menu)  # right click - context menu
        self.entry = Gtk.Entry()

        # Signals
        self.connect("delete-event", self.on_destroy)
        self.connect("delete-event", Gtk.main_quit)
        self.treeview.connect("row-activated", self.row_active)  # double click - submit row
        self.entry.connect("activate", self.on_download)  # enables enter key

        # Add columns & headers
        renderer_1 = Gtk.CellRendererText()
        renderer_2 = Gtk.CellRendererText()
        renderer_2.set_property("xalign", 1)

        column = Gtk.TreeViewColumn("Title", renderer_1, text=0)
        column.set_sort_column_id(0)
        self.treeview.append_column(column)

        column = Gtk.TreeViewColumn("Date", renderer_2, text=1)
        column.set_sort_column_id(1)
        self.treeview.append_column(column)

        column = Gtk.TreeViewColumn("Seeds", renderer_2, text=2)
        column.set_sort_column_id(2)
        self.treeview.append_column(column)

        column = Gtk.TreeViewColumn("Leeches", renderer_2, text=3)
        column.set_sort_column_id(3)
        self.treeview.append_column(column)

        #  Display field for Size (f4), sort field for Size (s5)
        column = Gtk.TreeViewColumn("Size", renderer_2, text=4)
        column.set_sort_column_id(5)
        self.treeview.append_column(column)

        # Define the buttons and handlers
        self.buttons = list()

        button = Gtk.Button(label="Download")
        button.connect("clicked", self.on_download)  # Signal
        self.buttons.append(button)

        button = Gtk.Button(label="Cancel")
        button.connect("clicked", self.on_cancel)  # Signal
        self.buttons.append(button)

        # Create a scrollable window
        self.scrollable_treeList = Gtk.ScrolledWindow()
        self.scrollable_treeList.set_vexpand(True)

        # Add the treeview to the scrollable window
        self.scrollable_treeList.add(self.treeview)

        # Create a grid container
        self.grid = Gtk.Grid()
        self.grid.set_column_homogeneous(True)
        self.grid.set_row_homogeneous(True)
        self.add(self.grid)  # add the grid to the window

        # Add the scrollable window to the grid
        self.grid.attach(self.scrollable_treeList, 0, 0, 8, 10)  # row,col,(h,w cells)

        # Add the buttons to the grid
        self.grid.attach_next_to(self.buttons[0], self.scrollable_treeList, Gtk.PositionType.BOTTOM, 1, 1)
        for i, button in enumerate(self.buttons[1:]):
            self.grid.attach_next_to(button, self.buttons[i], Gtk.PositionType.RIGHT, 1, 1)

        self.show_all()

        listing_window_active = True

        Gtk.main()

    def on_destroy(self, widget, event):
        app_exit()

    def on_download(self, button):
        # Retrieve selected titles from ListStore
        self.selected_titles = []

        selection = self.treeview.get_selection()
        (self.torrent_list_store, t_iter) = selection.get_selected_rows()

        for path in t_iter:
            p_iter = self.torrent_list_store.get_iter(path)
            if p_iter is not None:
                self.selected_titles.append(
                    self.torrent_list_store.get_value(p_iter, 0))

            self.download = True

        listing_window_active = False

        self.destroy()
        Gtk.main_quit()

    def engine_change_popup(self, popup):
        entry = popup.get_child()
        text = entry.get_text()
        for key, value in SUPPORTED_ENGINES.items():
            if value == text:
                self.popup_entry = key
                self.new_engine = True
                break

        Gtk.main_quit()

    def show_context_menu(self, widget, event):  # Context menu to select another engine
        if event.type == Gdk.EventType.BUTTON_PRESS and event.button == 3:
            context_menu = Gtk.Menu()
            for key, value in SUPPORTED_ENGINES.items():
                if key == self.engine:
                    continue
                cm_item = Gtk.MenuItem(label=value)
                cm_item.connect("activate", self.engine_change_popup)
                context_menu.add(cm_item)

            context_menu.attach_to_widget(self, None)
            context_menu.show_all()
            context_menu.popup(None, None, None, None, event.button, event.time)

    def on_cancel(self, button, event=None):
        self.cancel = True

        listing_window_active = False

        self.destroy()
        Gtk.main_quit()

    def row_active(self, tv, col, tv_col):  # If double-click on row, download and exit
        self.on_download(self)


class EztvModel:
    # Broken 
    myUrl = ENGINE_URLS["eztv"]

    def filter_sz_age(tag):
        if tag.find('a') is not None:  # eliminate <td> containing <a> tags
            return False
        return tag.name == 'td' and len(tag.attrs) == 2 and (
                tag.attrs["class"] == ["forum_thread_post"] and tag.attrs["align"] == 'center')

    def get_list(search_term):
        # Prep the url
        current_search = EztvModel.myUrl + '/search/' + search_term.replace(' ', '%20')

        # Pull the page
        page = requests.get(current_search)

        # Isolate the relevant data
        detail = Strainer('tr', {'class': 'forum_header_border'})
        soup = Soup(page.content.decode('ISO-8859-1'), features="html.parser", parse_only=detail)

        tds = soup.find_all("td", attrs={"class": "forum_thread_post", "align": "center"})

        #  Eliminate doubled magnet links; only take the first
        a_tags = []
        for td in tds:
            tags = td.find_all("a", attrs={"class": "magnet"})
            if len(tags) == 0:
                continue

            a_tags.append(tags[0])

        links = [a["href"] for a in a_tags]
        raw_titles = [a["title"] for a in a_tags]

        # Non result; early exit
        # Eztv will always return a list even for non matches
        bad_query = True
        for raw_title in raw_titles:
            if search_term.lower() in raw_title.lower():
                bad_query = False
                break

        if bad_query:
            return 1, None

        titles = []
        for raw_title in raw_titles:
            raw_title = raw_title.replace('Magnet Link', '')  # kill link desc in title
            raw_title = re.sub('\[eztv\]', '', raw_title)  # kill eztv tag in title
            raw_title = re.sub('\(.*\)', '', raw_title)  # kill size in title
            titles.append(ascii_only(raw_title))

        sz_age = []
        for size_age in soup.find_all(EztvModel.filter_sz_age):
            sz_age.append(str(size_age.get_text()).strip())

        # Assign alternating rows
        ages, raw_sizes = [], []
        for age in range(len(sz_age)):
            if (age % 2) == 0:
                raw_sizes.append(sz_age[age])
            else:
                ages.append(sz_age[age])

        # Normalize size info
        sizes = []
        for size in raw_sizes:
            file_size = size
            file_size = file_size.replace('GB', 'G')
            file_size = file_size.replace('MB', 'M')
            file_size = file_size.replace('KB', 'K')
            sizes.append(file_size)

        seeds_raw = soup.find_all("td", attrs={"align": "center", "class": "forum_thread_post_end"})
        seeds_raw = [str(sd.get_text()).strip() for sd in seeds_raw]

        # Filter non integer data
        seeds = []
        for seed_raw in seeds_raw:
            if seed_raw.isdigit():
                seed = seed_raw
            else:
                seed = 0
            seeds.append(seed)

        # No leech info provided in this model
        leeches = ["0" for sd in seeds_raw]

        # Return listStore data and provide an extra payload of link data
        torrent_list = []
        for ndx in range(0, len(titles)):
            torrent_list.append((titles[ndx], ages[ndx], seeds[ndx], leeches[ndx], sizes[ndx], links[ndx]))

        return 0, torrent_list


EztvModel.get_list = staticmethod(EztvModel.get_list)


class LimeModel:
    myUrl = ENGINE_URLS["lime"]

    def get_list(search_term):
        # Prep the url
        current_search = LimeModel.myUrl + '/search/all/' + search_term.replace(' ', '%20')

        # Pull the page
        page = requests.get(current_search)

        # Isolate the relevant data
        detail = Strainer('table', {'class': 'table2'})
        soup = Soup(page.content.decode('ISO-8859-1'), features="html.parser", parse_only=detail)

        # Extract raw html
        divs = soup.find_all("div", attrs={"class": "tt-name"})
        age_size_td = soup.find_all("td", attrs={"class": "tdnormal"})
        leech_td = soup.find_all("td", attrs={"class": "tdleech"})
        seed_td = soup.find_all("td", attrs={"class": "tdseed"})

        # Non result; early exit
        if not len(divs) > 0:
            return 1, None

        # Extract text from html
        titles = [str(div.get_text()).strip() for div in divs]
        age_size = [str(td.get_text()).strip() for td in age_size_td]
        leeches_raw = [str(td.get_text()).strip() for td in leech_td]
        seeds_raw = [str(td.get_text()).strip() for td in seed_td]

        # Filter non integer data
        leeches = []
        for leech_raw in leeches_raw:
            if leech_raw.isdigit():
                leech = leech_raw
            else:
                leech = 0
            leeches.append(leech)

        # Filter non integer data
        seeds = []
        for seed_raw in seeds_raw:
            if seed_raw.isdigit():
                seed = seed_raw
            else:
                seed = 0
            seeds.append(seed)

        # Extract links
        link_tags = [div.a for div in divs]
        links = [link['href'] for link in link_tags]

        # Post-process age_size: Parse alternating pairs of age and size into separate lists: ages and sizes
        raw_ages, raw_sizes = [], []

        for ndx in range(len(age_size)):
            if (ndx % 2) == 0:
                raw_ages.append(age_size[ndx])
            else:
                raw_sizes.append(age_size[ndx])

        # Scrub age text
        ages = []
        for raw_age in raw_ages:
            age_trim = re.sub('\s[-]\s.*$', '', raw_age)
            ages.append(age_trim)

        # Normalize size info
        sizes = []
        for raw_size in raw_sizes:
            file_size = raw_size
            file_size = file_size.replace('GB', 'G')
            file_size = file_size.replace('MB', 'M')
            file_size = file_size.replace('KB', 'K')
            sizes.append(file_size)

        # Return listStore data and provide an extra payload of link data
        torrent_list = []
        for ndx in range(0, len(titles)):
            torrent_list.append(
                (ascii_only(titles[ndx]), ages[ndx], seeds[ndx], leeches[ndx], sizes[ndx], links[ndx]))

        return 0, torrent_list


LimeModel.get_list = staticmethod(LimeModel.get_list)


class PBModel:
    myUrl = ENGINE_URLS["pb"]

    def size_cleaner(sz):
        sz = sz.replace(u'\xa0', ' ')
        sz = sz.replace('GiB', 'G')
        sz = sz.replace('MiB', 'M')
        return sz

    def date_cleaner(dt):
        today = datetime.now()
        dt = ascii_only(dt.text.strip())
        date_sects = re.search('(\d\d-\d\d)(.*)', dt)
        if date_sects is not None:
            d_year = date_sects.group(2)
            d_year = today.year if ":" in d_year else d_year
            dt = str(d_year) + "-" + date_sects.group(1)
        else:
            dt = None
        return dt

    def get_list(search_term):
        # Prep the url
        current_search = PBModel.myUrl + '/search/' + search_term.replace(' ', '%20') + '/1/99/0'

        # Pull the page
        page = requests.get(current_search)

        # Extract SearchResult table
        detail = Strainer('table', {'id': 'searchResult'})
        soup = Soup(page.content.decode('ISO-8859-1'), features="html.parser", parse_only=detail)

        # Gather the sections containing pertinent info
        trs = soup.find_all("tr")

        # Separate info into lists
        titles, dates = [], []
        for t in trs:
            td = t.find("td", attrs={"class": "vertTh"})
            if td is not None:
                t_list = t.find_all()
                titles.append(ascii_only(t_list[2].text.strip()))
                dates.append(PBModel.date_cleaner(t_list[4]))

        if not len(titles) > 0:  # Unsuccessful query
            return 1, None

        links = soup.find_all("a", attrs={"title": re.compile('^Download')})
        tds = soup.find_all("td", attrs={"align": "right"})

        sizes, seeds, leeches = [], [], []
        a, b, c = 0, 1, 2
        while a < len(tds):
            sizes.append(PBModel.size_cleaner(tds[a].text))
            seeds.append(tds[b].text)
            leeches.append(tds[c].text)
            a, b, c = a + 3, b + 3, c + 3

        magnets = [link['href'] for link in links]

        # Return listStore data and provide an extra payload of magnet data
        torrent_list = []
        for ndx in range(0, len(titles)):
            torrent_list.append((titles[ndx], dates[ndx], seeds[ndx], leeches[ndx], sizes[ndx], magnets[ndx]))

        return 0, torrent_list


PBModel.get_list = staticmethod(PBModel.get_list)


class TorrentRequest:
    # Manages search and listing windows
    def __init__(self, engine_key=None, search_term=None):
        self.engine_key = engine_key
        self.search_term = search_term

        search_win = SearchWin(self.engine_key, self.search_term)  # launch search window
        self.engine_key = search_win.engine_key  # last engine key
        self.search_term = search_win.search_term  # last search term

        while True:
            listing_win = None  # no active listing

            if search_win.torrent_list:  # successful search; a list was produced
                listing_win = ListingWin(search_win.torrent_list, self.engine_key)  # display the search result

            if listing_win is not None:  # display listing
                if listing_win.cancel is True:  # kill listing - return to search
                    search_win = SearchWin(self.engine_key, None)
                    self.engine_key = search_win.engine_key  # last engine key
                    self.search_term = search_win.search_term  # last search term

                if listing_win.new_engine is True:  # employ engine change
                    self.engine_key = listing_win.popup_entry
                    listing_win.destroy()
                    search_win = SearchWin(self.engine_key, self.search_term)
                    self.engine_key = search_win.engine_key  # last engine key
                    self.search_term = search_win.search_term  # last search term

                if listing_win.download is True:  # download and exit
                    for selected_title in listing_win.selected_titles:  # Pass selected magnets to torrent client
                        subprocess.Popen([TORRENT_CLIENT, listing_win.magnet_dict[selected_title]],
                                         stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
                        time.sleep(1.2)

                    app_exit()


# Execute
if __name__ == "__main__":
    logger = init_logging()
    sys.excepthook = handle_exception  # uncaught exceptions to syslog

    if not os.path.exists(TORRENT_CLIENT):
        t_client = str.title(os.path.basename(TORRENT_CLIENT))
        app = os.path.basename(__file__)
        app = os.path.splitext(app)[0]
        print(
            f"{BOLD}{RED}Error{RESET}:{WHITE}{t_client} {RED}{ITALIC}not found{RESET}. Please install: {WHITE}{TORRENT_CLIENT}{RESET}")
        app_exit(1)

    option_dict, CmdLineSearch = get_cmdline()

    if len(CmdLineSearch):
        CmdLineSearch = ' '.join(CmdLineSearch)
    else:
        CmdLineSearch = None

    CmdLineEngine = option_dict["engine"]

    if CmdLineEngine not in SUPPORTED_ENGINES:
        print(f"{BOLD}{RED}Error{RESET}: engine {engineKey} is not a supported engine")
        app_exit(1)

    set_gtk_theme("Yaru-viridian-dark")  # see: gtk-common-themes
    TorrentRequest(CmdLineEngine, CmdLineSearch)
