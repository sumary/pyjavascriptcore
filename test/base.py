# This file is part of PyJavaScriptCore, a binding between CPython and
# WebKit's JavaScriptCore.
#
# Copyright (C) 2009, Martin Soto <soto@freedesktop.org>
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

import unittest

import javascriptcore as jscore


class TestCaseWithContext(unittest.TestCase):
    """A fixture that creates a JavaScript global context for each
    test method."""

    def setUp(self):
        self.ctx = jscore.JSContext()

    def tearDown(self):
        del self.ctx

    def assertTrueJS(self, jsExpr):
        self.assertTrue(self.ctx.evaluateScript(jsExpr))

    def assertEqualJS(self, jsExpr, value):
        self.assertEqual(self.ctx.evaluateScript(jsExpr), value)

    def assertAlmostEqualJS(self, jsExpr, value):
        self.assertAlmostEqual(self.ctx.evaluateScript(jsExpr), value)

    def assertRaisesJS(self, jsExpr):
        def evalExpr():
            self.ctx.evaluateScript(jsExpr)

        self.assertRaises(jscore.JSException, evalExpr)
