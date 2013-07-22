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

import sys
import os

baseDir = os.path.dirname(os.path.dirname(os.path.abspath(sys.argv[0])))
sys.path.insert(0, baseDir)

import unittest

import javascriptcore as jscore

import jsfrompy
import pyfromjs


_moduleSuites = [
    unittest.defaultTestLoader.loadTestsFromModule(jsfrompy),
    unittest.defaultTestLoader.loadTestsFromModule(pyfromjs),
    ]

mainSuite = unittest.TestSuite(_moduleSuites)
unittest.TextTestRunner(verbosity=2).run(mainSuite)

# These objects store intances of the test cases, we must delete them
# before...
del mainSuite
del _moduleSuites

# ... we can check that nothing is still hanging around in the cache.
assert jscore._cachedStats()['wrappedJSObjsCount'] == 0
assert jscore._cachedStats()['wrappedPyObjsCount'] == 0
