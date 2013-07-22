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
from javascriptcore import asSeq

from base import TestCaseWithContext


class WrapUnwrapTestCase(TestCaseWithContext):
    """Test object wrapping and unwrapping.
    """

    def setUp(self):
        TestCaseWithContext.setUp(self)
        self.obj = (1, 2, 3)

    def testWrapUnwrap1(self):
        s = self.ctx.evaluateScript('(function(o) { obj = o; })')
        s(self.obj)
        self.assertTrue(self.obj is self.ctx.globalObject.obj)

    def testWrapUnwrap2(self):
        self.ctx.globalObject.obj = self.obj
        self.assertTrue(self.obj is self.ctx.globalObject.obj)

    def testWrapUnwrap3(self):
        self.ctx.globalObject.obj = self.obj
        g = self.ctx.evaluateScript('(function() { return obj; })')
        self.assertTrue(self.obj is g())

    def testWrapUnwrap4(self):
        self.ctx.globalObject.obj = self.obj
        self.assertTrue(self.obj is self.ctx.evaluateScript('obj'))

    def testIdentity1(self):
        self.ctx.globalObject.obj = self.obj
        self.ctx.globalObject.obj2 = self.obj
        self.assertTrueJS('obj === obj2')

    def testIdentity2(self):
        self.ctx.globalObject.obj = self.obj
        self.ctx.globalObject.obj2 = (self.obj, 4)
        self.assertTrueJS('obj === obj2[0]')


class NullUndefTestCase(TestCaseWithContext):
    """Access JavaScript's null and undefined values."""

    def testUndef1(self):
         self.ctx.globalObject.ud = None
         self.assertEqualJS("ud === undefined", True)

    def testNull1(self):
         self.ctx.globalObject.n = jscore.Null
         self.assertEqualJS("n === null", True)


class AttributeAccessTestCase(TestCaseWithContext):
    """Access the attributes of Python objects from JavaScript
    """

    def setUp(self):
        TestCaseWithContext.setUp(self)
        class A: pass
        obj = A()
        obj.a, obj.b, obj.c, obj.d = 1, 'x', A(), None
        obj.c.d, obj.c.e = 2, 'yy'
        self.obj = obj
        self.ctx.globalObject.obj = obj

    def testIntAccess(self):
        self.assertEqualJS('obj.a', 1)

    def testStringAccess(self):
        self.assertEqualJS('obj.b', 'x')

    def testNestedObjectAccess(self):
        self.assertEqualJS('obj.c.d', 2)
        self.assertEqualJS('obj.c.e', 'yy')

    def testAccessInexistent(self):
        self.assertTrueJS('obj.abc === undefined')

    def testAccessNone(self):
        self.assertTrueJS('obj.d === undefined')

    def testAccessChanged(self):
        self.assertEqualJS('obj.a', 1)
        self.obj.a = 4
        self.assertEqualJS('obj.a', 4)

    def testAccessJSNew(self):
        self.obj.f = 4
        self.assertEqualJS('obj.f', 4)

    def testSet(self):
        self.assertEqual(self.obj.a, 1)
        self.ctx.evaluateScript('obj.a = 4')
        self.assertEqual(self.obj.a, 4)

    def testHasOwnProp(self):
        self.assertTrueJS("obj.hasOwnProperty('a')")
        self.assertTrueJS("obj.hasOwnProperty('d')")
        self.assertTrueJS("!obj.hasOwnProperty('abc')")

    def testDelete(self):
        self.assertTrue(hasattr(self.obj, 'a'))
        self.ctx.evaluateScript('delete obj.a')
        self.assertFalse(hasattr(self.obj, 'a'))

    def testDeleteInexistent(self):
        self.assertFalse(hasattr(self.obj, 'abc'))
        self.ctx.evaluateScript('delete obj.abc')
        self.assertFalse(hasattr(self.obj, 'abc'))


class MappingTestCase(TestCaseWithContext):
    """Test mapping behavior for wrapped JavaScript objects.

    Tests compare the effect of applying the same expression to a
    native Python dictionary and a wrapped JavaScript object.
    """

    def setUp(self):
        TestCaseWithContext.setUp(self)
        self.objPython = {'a': 11, 'b': 22, 'c': None, '1': 44, '2': 55}
        self.ctx.globalObject.objPython = self.objPython
        self.ctx.evaluateScript("""objJS = {a: 11, b: 22, c: undefined,
                                            1: 44, 2: 55}""")

    def evalJS(self, expr):
        self.ctx.evaluateScript('obj = objPython')
        self.ctx.evaluateScript(expr)
        self.ctx.evaluateScript('obj = objJS')
        self.ctx.evaluateScript(expr)

    def assertEqualExpr(self, expr, val='xyz'):
        self.ctx.evaluateScript('obj = objPython')
        val1 = self.ctx.evaluateScript(expr)
        self.ctx.evaluateScript('obj = objJS')
        val2 = self.ctx.evaluateScript(expr)

        self.assertEqual(val1, val2)
        if val != 'xyz':
            self.assertEqual(val1, val)

    def tearDown(self):
        if self.objPython != self.ctx.globalObject.objJS:
            self.fail("Python object %s differs from JavaScript object %s" % \
                          (repr(self.objPython),
                           repr(dict(self.ctx.globalObject.objJS))))

        TestCaseWithContext.tearDown(self)

    def testAccess1(self):
        self.assertEqualExpr("obj['a']")
        self.assertEqualExpr("obj['2']")

    def testAccess2(self):
        self.assertEqualExpr("obj['c']")

    def testAccess3(self):
        self.assertEqualExpr("obj['x']", None)

    def testModif1(self):
        self.evalJS("obj['a'] = 111")

    def testModif2(self):
        self.evalJS("obj['a'] = 111; obj['1'] = 444")

    def testExtend1(self):
        self.evalJS("obj['d'] = 666")

    def testExtend2(self):
        self.evalJS("obj['d'] = 666; obj['3'] = 777")

    def testDel1(self):
        self.evalJS("delete obj['a']")

    def testDel2(self):
        self.evalJS("delete obj['a']; delete obj['1']")

    def testDel3(self):
        self.evalJS("""delete obj['a']; delete obj['b']; delete obj['c'];
                    delete obj['1']; delete obj['2']""")

    def testDel4(self):
        self.evalJS("delete obj['x']")

    def testIter1(self):
        self.ctx.evaluateScript("""
            i = 0;
            props = [];
            for (prop in objPython) {
                if (objPython.hasOwnProperty(prop)) {
                    props[i] = prop;
                }
                i++;
            }""")
        self.assertEqual(sorted(self.objPython),
                         sorted(asSeq(self.ctx.globalObject.props)))


class FunctionMappingTestCase(MappingTestCase):
    """Test mapping behavior for wrapped JavaScript functions.

    JavaScript functions should behave as standard objects. Tests
    compare the effect of applying the same expression to a native
    Python dictionary and a wrapped JavaScript function.
    """

    def setUp(self):
        TestCaseWithContext.setUp(self)
        self.objPython = {'a': 11, 'b': 22, 'c': None, '1': 44, '2': 55}
        self.ctx.globalObject.objPython = self.objPython
        self.ctx.evaluateScript("""
            objJS = function () {};
            objJS['a'] = 11;
            objJS['b'] = 22;
            objJS['c'] = undefined;
            objJS['1'] = 44;
            objJS['2'] = 55;""")


class ListAccessTestCase(TestCaseWithContext):
    """Access Python list-style objects from JavaScript.

    Tests compare the effect of applying the same expression to a
    native JavaScript array and a wrapped Python list.
    """

    def setUp(self):
        TestCaseWithContext.setUp(self)
        self.objPython = [11, 22, 33, 44, 55]
        self.ctx.globalObject.objPython = self.objPython
        self.ctx.evaluateScript('objJS = [11, 22, 33, 44, 55]')

        # For the benefit of read-only test cases, the initial value
        # of obj is the Python object.
        self.ctx.globalObject.obj = self.objPython

    def evalJS(self, expr):
        self.ctx.evaluateScript('obj = objPython')
        self.ctx.evaluateScript(expr)
        self.ctx.evaluateScript('obj = objJS')
        self.ctx.evaluateScript(expr)

    def tearDown(self):
        if self.objPython != list(asSeq(self.ctx.globalObject.objJS)):
            self.fail("Python object %s differs from JavaScript object %s" % \
                          (repr(self.objPython),
                           repr(list(self.ctx.globalObject.objJS))))

        TestCaseWithContext.tearDown(self)

    def testAccess1(self):
        self.assertEqualJS('obj[1]', 22)
        self.assertEqualJS('obj[1.0]', 22)

    def testAccess2(self):
        self.assertEqualJS('obj[0]', 11)
        self.assertEqualJS('obj[4]', 55)

    def testAccess3(self):
        self.assertTrueJS('obj[-1] === undefined')
        self.assertTrueJS('obj[5] === undefined')

    def testSet(self):
        self.evalJS('obj[2] = 333')

    def testLength(self):
        self.assertTrueJS('obj.length === 5')

    def testTruncate(self):
        self.evalJS('obj.length = 3')

    def testExtend1(self):
        self.evalJS('obj[5] = 66')

    def testExtend2(self):
        self.evalJS('obj[10] = 66')

    def testExtend3(self):
        self.evalJS('obj.length = 10')

    def testDel1(self):
        self.evalJS('delete obj[3]')

    def testDel2(self):
        self.evalJS('delete obj[0]')

    def testDel3(self):
        self.evalJS('delete obj[4]')

    def testDel4(self):
        self.evalJS('delete obj[8]')


class FunctionCallTestCase(TestCaseWithContext):
    """Call Python functions from JavaScript."""

    def testCalculate(self):
        def f(x, y): return x + y
        self.ctx.globalObject.f = f
        self.assertEqualJS('f(7, 9)', 16)

    def testPassReturn(self):
        def f(x): return x
        self.ctx.globalObject.f = f
        self.assertEqualJS('f(34)', 34)
        self.assertAlmostEqualJS('f(3.456)', 3.456)
        self.assertEqualJS("f('xcdf')", 'xcdf')

    def testNumParams(self):
        def f(*args): return len(args)
        self.ctx.globalObject.f = f
        self.assertEqualJS("f()", 0)
        self.assertEqualJS("f('x')", 1)
        self.assertEqualJS("f('x', 'x')", 2)
        self.assertEqualJS("f('x', 'x', 'x')", 3)

    def testExceptionSimple(self):
        def f(): raise Exception('-*Message*-')
        self.ctx.globalObject.f = f
        msg = self.ctx.evaluateScript("""
            try {
                f();
                msg = '';
            } catch (e) {
                msg = e.message;
            }
            msg;
            """)
        self.assertEqual(msg, '-*Message*-')

    def testExceptionRoundTrip(self):
        def f(): raise Exception('-*Message*-')
        self.ctx.globalObject.f = f
        try:
            self.ctx.evaluateScript("f()")
            self.fail("No exception raised")
        except jscore.JSException as e:
            self.assertEqual(str(e), '-*Message*-')
