# This file is part of PyJavaScriptCore, a binding between CPython and
# WebKit's JavaScriptCore.
#
# Copyright (C) 2009, Martin Soto <soto@freedesktop.org>
# Copyright (C) 2009, john paul janecek (see README file)
#
# PyJavaScriptCore is free software; you can redistribute it and/or
# modify it under the terms of the GNU Lesser General Public License
# as published by the Free Software Foundation; either version 2 of
# the License, or (at your option) any later version.
#
# This library is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU
# Lesser General Public License for more details.
#
# You should have received a copy of the GNU Lesser General Public
# License along with this library; if not, write to the
# Free Software Foundation, Inc., 59 Temple Place - Suite 330,
# Boston, MA 02111-1307, USA. 

import gobject
import gtk
import pango
import webkit

import javascriptcore as jscore


class WebView(object):
    def __init__(self):
        self.mainWindow = gtk.Window(gtk.WINDOW_TOPLEVEL)
        self.mainWindow.connect("delete_event", lambda *x: gtk.main_quit ())
        self.mainWindow.set_size_request(800, 600)

        self.scrolledWindow = gtk.ScrolledWindow()
        self.mainWindow.add(self.scrolledWindow)

        self.webView = webkit.WebView()
        self.webView.connect("load-finished", self.load_finished_cb)
        self.scrolledWindow.add(self.webView)

        settings = self.webView.get_settings()
        settings.set_property("auto-load-images", False)
        settings.set_property("enable-plugins", False)

    def show(self):
        self.mainWindow.show_all()

    def start(self):
        self.webView.open("http://www.google.com")

    def load_finished_cb(self, view, frame):
        print "load_finished"

        # Retrieve the JavaScript context from the browser widget.
        ctx = jscore.JSContext(self.webView.get_main_frame().get_global_context())

        # Retrieve the JavaScript window object.
        window = ctx.globalObject.window

        # Alert works!
        #window.alert("This is an alert")

        # We can change properties in the window object.
        window.foo = 'bar'
        assert ctx.evaluateScript("window.foo") == 'bar'

        # Retrieve the DOM document object.
        document = ctx.globalObject.document

        # Document title.
        print "Title:", document.title
        form = document.forms[0]

        # List all A (anchor) tags.
        atags = document.getElementsByTagName("a")
        print atags.__class__.__name__
        print list(atags.iterkeys())
        for a in jscore.asSeq(atags):
            print a.href


if __name__ == '__main__':
    gobject.threads_init()

    view = WebView()
    view.show()

    try:
        view.start()
        gtk.main()
    except KeyboardInterrupt:
        gtk.main_quit()
