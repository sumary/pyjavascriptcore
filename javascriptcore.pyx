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

"""
Two-way binding between CPython and WebKit's JavaScriptCore.
"""

import sys
import types
import collections
import weakref

cdef:
    ctypedef unsigned short bool

include "stdlib.pyi"
include "python.pyi"
include "jsbase.pyi"
include "jscontextref.pyi"
include "jsstringref.pyi"
include "jsvalueref.pyi"
include "jsobjectref.pyi"


#
# Null Singleton
#

class NullType(object):
    """A singleton type to represent JavaScript's `null` value in
    Python."""

    def __init__(self):
        # Make this a singleton class.
        if Null is not None:
            raise TypeError("cannot create '%s' instances"
                            % self.__class__.__name__)

    def __nonzero__(self):
        # As in javascript, the Null value has a false boolean value.
        return False

# Create the actual Null singleton.
Null = None
Null = NullType()


#
# Value conversion
#

# Wrapper cache. All attempts at wrapping a single object should
# return the same wrapper. This way, there is a one-to-one
# relationship between wrappers and their wrapped objects. The
# following dictionaries maintain this relationship:

# A dictionary associating wrapped JavaScript objects to their Python
# wrappers.  Keys are pointers to JavaScript objects cast to long int
# (and converted to Python integers to store them in the
# dictionary). Values are (weak references to) the corresponding
# wrappers. Notice that casting to the long type is necessary because
# pointers are larger than plain ints in 64-bit platforms.
cdef object _pyWrappedJSObjs = weakref.WeakValueDictionary()

# A dictionary associating wrapped Python objects to their JavaScript
# wrappers. Keys are ids of Python objects, as returned by the id()
# function. Values are pointers to the corresponding JavaScript
# wrappers enclosed in PyCObject instances. Wrappers are deleted from
# this dictionary when they get garbage collected (see pyObjFinalize).
cdef object _pyWrappedPyObjs = {}


cdef object wrapJSObject(JSContextRef jsCtx, JSValueRef jsValue):
    cdef object wrapper

    try:
        return _pyWrappedJSObjs[<long>jsValue]
    except KeyError:
        pass

    if JSObjectIsFunction(jsCtx, jsValue):
        wrapper = makeJSFunction(jsCtx, jsValue)
    else:
        wrapper = makeJSObject(jsCtx, jsValue)

    _pyWrappedJSObjs[<long>jsValue] = wrapper
    return wrapper

cdef object jsToPython(JSContextRef jsCtx, JSValueRef jsValue):
    """Convert a JavaScript value into a Python value."""

    cdef int jsType = JSValueGetType(jsCtx, jsValue)
    cdef JSStringRef jsStr
    cdef double doubleVal
    cdef long intVal

    if jsType == kJSTypeUndefined:
        return None
    if jsType == kJSTypeNull:
        return Null
    elif jsType == kJSTypeBoolean:
        return types.BooleanType(JSValueToBoolean(jsCtx, jsValue))
    elif jsType == kJSTypeNumber:
        # If the value is actually an integer, return it is an
        # instance of Python's int type.
        doubleVal = JSValueToNumber(jsCtx, jsValue, NULL)
        intVal = <long>doubleVal
        if intVal == doubleVal:
            return intVal
        else:
            return doubleVal
    elif jsType == kJSTypeString:
        jsStr = JSValueToStringCopy(jsCtx, jsValue, NULL)
        try:
            return PyUnicode_DecodeUTF16(<Py_UNICODE*>JSStringGetCharactersPtr(jsStr),
                                         JSStringGetLength(jsStr) * 2,
                                         NULL, 0)
        finally:
            JSStringRelease(jsStr)
    elif JSValueIsObjectOfClass(jsCtx, jsValue, pyObjectClass):
        # This is a wrapped Python object. Just unwrap it.
        return <object>JSObjectGetPrivate(jsValue)
    else:
        return wrapJSObject(jsCtx, jsValue)

    return None


class JSException(Exception):
    """Python exception class to encapsulate JavaScript exceptions."""

    def __init__(self, pyWrapped):
        """Create a JavaScript exception object.#

        The parameter is the original exception object thrown by the
        JavaScript code, wrapped as a Python object."""
        self.pyWrapped = pyWrapped
        try:
            self.name = pyWrapped.name
        except AttributeError:
            self.name = '<Unknown error>'
        try:
            self.message = pyWrapped.message
        except AttributeError:
            self.message = '<no message>'

    def __str__(self):
        return self.message

cdef object jsExceptionToPython(JSContextRef jsCtx, JSValueRef jsException):
    """Factory function for creating exception objects."""
    return JSException(jsToPython(jsCtx, jsException))


cdef object pyStringFromJS(JSStringRef jsString):
    return PyUnicode_DecodeUTF16(<Py_UNICODE *>JSStringGetCharactersPtr(jsString),
                                 JSStringGetLength(jsString) * 2,
                                 NULL, 0)

cdef JSStringRef createJSStringFromPython(object pyStr):
    """Create a ``JSString`` from a Python object.

    This is a create function. Ownership of the result is transferred
    to the caller."""
    pyStr = unicode(pyStr).encode('utf-8')
    return JSStringCreateWithUTF8CString(pyStr)

cdef JSObjectRef wrapPyObject(JSContextRef jsCtx, object pyValue):
    cdef JSObjectRef wrapper

    try:
        return <JSObjectRef>PyCObject_AsVoidPtr(_pyWrappedPyObjs[id(pyValue)])
    except KeyError:
        pass

    wrapper = makePyObject(jsCtx, pyValue)
    _pyWrappedPyObjs[id(pyValue)] = PyCObject_FromVoidPtr(wrapper, NULL)
    return wrapper

cdef JSValueRef pythonToJS(JSContextRef jsCtx, object pyValue):
    """Convert a Python value into a JavaScript value.

    The returned value belongs to the specified context, and must be
    protected if it is going to be permanently stored (e.g., inside an
    object)."""

    if isinstance(pyValue, types.NoneType):
        return JSValueMakeUndefined(jsCtx)
    elif isinstance(pyValue, NullType):
        return JSValueMakeNull(jsCtx)
    elif isinstance(pyValue, types.BooleanType):
        return JSValueMakeBoolean(jsCtx, pyValue)
    elif isinstance(pyValue, (types.IntType, types.FloatType)):
        return JSValueMakeNumber(jsCtx, pyValue)
    elif isinstance(pyValue, types.StringTypes):
        return JSValueMakeString(jsCtx, createJSStringFromPython(pyValue))
    elif isinstance(pyValue, _JSBaseObject):
        # This is a wrapped JavaScript object, just unwrap it.
        return (<_JSObject>pyValue).jsObject
    else:
        # Wrap all other Python objects into a generic wrapper.
        return wrapPyObject(jsCtx, pyValue)


#
# Python Wrappers for JavaScript objects
#

# The name of the length array property.
cdef JSStringRef jsLengthName = JSStringCreateWithUTF8CString("length")


cdef class _JSBaseObject:
    """Base class for all Python wrappers for JavaScript objects.

    This class only manages object allocation and deallocation.
    """

    # Make it possible to have weak references to this object.
    cdef object __weakref__

    cdef JSContextRef jsCtx
    cdef JSObjectRef jsObject

    def __init__(self):
        self.jsCtx = NULL
        self.jsObject = NULL

    cdef setup(self, JSContextRef jsCtx, JSObjectRef jsObject):
        # We claim ownership of objects here and release them in
        # __dealloc__. Notice that we also need to own a reference to
        # the context, because it may otherwise disappear while this
        # object still exists.
        self.jsCtx = jsCtx
        JSGlobalContextRetain(self.jsCtx)
        self.jsObject = jsObject
        JSValueProtect(self.jsCtx, self.jsObject)

    def __dealloc__(self):
        JSValueUnprotect(self.jsCtx, self.jsObject)
        JSGlobalContextRelease(self.jsCtx)


cdef class _JSSequence(_JSBaseObject):
    """A Python sequence view on a JavaScript object.

    See the ``asSeq`` function in this module and the
    ``_JSObject.__asSeq__`` method for more details.

    Since Cython extension classes cannot inherit from Python classes,
    we first define class ``_JSSequence`` and then define
    ``JSSequence`` as a standard Python class that mixes in
    ``MutableMapping`` from the ``collections`` module."""

    cdef int getLength(self) except -1:
        cdef JSValueRef jsException = NULL
        cdef JSValueRef jsResult
        cdef int result

        jsResult = JSObjectGetProperty(self.jsCtx, self.jsObject,
                                       jsLengthName, &jsException)
        if jsException != NULL or JSValueIsUndefined(self.jsCtx, jsResult):
            raise TypeError, "not an array or array-like JavaScript object"

        result = <int>JSValueToNumber(self.jsCtx, jsResult, &jsException)
        if jsException != NULL:
            raise TypeError, "not an array or array-like JavaScript object"

        return result

    cdef int setLength(self, int length) except -1:
        cdef JSValueRef jsException = NULL
        cdef JSValueRef jsLength = JSValueMakeNumber(self.jsCtx, length)

        JSObjectSetProperty(self.jsCtx, self.jsObject, jsLengthName,
                            jsLength, kJSPropertyAttributeNone, &jsException)
        if jsException != NULL:
            raise TypeError, "not a mutable array or array-like " \
                "JavaScript object"

        return 0

    cdef JSValueRef getItem(self, int index) except NULL:
        cdef JSValueRef jsException = NULL
        cdef JSValueRef jsResult

        jsResult = JSObjectGetPropertyAtIndex(self.jsCtx, self.jsObject,
                                              index, &jsException)
        if jsException != NULL:
            raise jsExceptionToPython(self.jsCtx, jsException)

        return jsResult

    cdef int setItem(self, int index, JSValueRef jsValue) except -1:
        cdef JSValueRef jsException = NULL

        JSObjectSetPropertyAtIndex(self.jsCtx, self.jsObject, index, jsValue,
                                   &jsException)
        if jsException != NULL:
            raise jsExceptionToPython(self.jsCtx, jsException)

        return 0

    cdef int copyBlock(self, int start, int end, int dest) except -1:
        """Copy the elements of ``[start, end]`` to position ``dest``.

        Both ``start`` and ``end`` must be non-negative and ``start
        must be lower than ``end``."""
        cdef int count = end - start
        cdef int i

        if start < dest:
            for i in range(count - 1, -1, -1):
                self.setItem(dest + i, self.getItem(start + i))
        elif start > dest:
            for i in range(count):
                self.setItem(dest + i, self.getItem(start + i))

        return 0

    def __contains__(self, pyItem):
        cdef JSValueRef jsItem = pythonToJS(self.jsCtx, pyItem)
        cdef JSValueRef jsElem

        for i in range(self.getLength()):
            jsElem = self.getItem(i)
            if JSValueIsObjectOfClass(self.jsCtx, jsElem, pyObjectClass):
                # This is a wrapped Python object, compare according
                # to Python rules.
                if <object>JSObjectGetPrivate(jsElem) == pyItem:
                    return True
            else:
                # Compare according to JavaScript rules.
                if JSValueIsStrictEqual(self.jsCtx, jsItem, jsElem):
                    return True
        return False

    def __len__(self):
        return self.getLength()

    def __iter__(self):
        return _JSSeqIterator(self)

    def __getitem__(self, pyIndex):
        cdef int index
        cdef int length = self.getLength()
        cdef int i

        if isinstance(pyIndex, int) or isinstance(pyIndex, long):
            index = pyIndex

            # Handle negative indexes.
            if index < 0:
                index += length

            # Exclude out-of-range indexes.
            if index < 0 or index >= length:
                raise IndexError, "list index out of range"

            return jsToPython(self.jsCtx, self.getItem(index))
        elif isinstance(pyIndex, slice):
            # Don't know how efficient this is, but it looks cool
            # anyway.
            return [jsToPython(self.jsCtx, self.getItem(i))
                    for i in xrange(*pyIndex.indices(length))]
        else:
            raise TypeError, "list indices must be integers, not %s" % \
                pyIndex.__class__.__name__

    def __setitem__(self, pyIndex, pyValue):
        cdef int index
        cdef int length = self.getLength()
        cdef int start, end, step
        cdef int valueLength
        cdef int sliceSize
        cdef int i

        if isinstance(pyIndex, int) or isinstance(pyIndex, long):
            index = pyIndex

            # Handle negative indexes.
            if index < 0:
                index += length

            # Exclude out-of-range indexes.
            if index < 0 or index >= length:
                raise IndexError, "list index out of range"

            self.setItem(index, pythonToJS(self.jsCtx, pyValue))
        elif isinstance(pyIndex, slice):
            start, end, step = pyIndex.indices(length)
            pyValueList = list(pyValue)
            valueLength = len(pyValueList)

            if step == 1:
                # Move the elements after the slice to their final
                # position.
                self.copyBlock(end, length, start + valueLength)

                if end - start > valueLength:
                    # Truncate the list to its new length.
                    self.setLength(length - (end - start) + valueLength)
            else:
                # Calculate the size of the extended slice.
                sliceSize = (end - start) / step
                if (end - start) % step > 0:
                    sliceSize += 1

                if sliceSize != valueLength:
                    raise ValueError, "attempt to assign sequence of size" \
                        " %d to extended slice of size %d" % \
                        (valueLength, sliceSize)

            # Copy the elements to their destination.
            i = start
            for pyElem in pyValueList:
                self.setItem(i, pythonToJS(self.jsCtx, pyElem))
                i += step
        else:
            raise TypeError, "list indices must be integers, not %s" % \
                pyIndex.__class__.__name__

    def __delitem__(self, pyIndex):
        cdef int index
        cdef int length = self.getLength()
        cdef int start, end, step
        cdef int frm, dest, nextDel

        if isinstance(pyIndex, int) or isinstance(pyIndex, long):
            index = pyIndex

            # Handle negative indexes.
            if index < 0:
                index += length

            # Exclude out-of-range indexes.
            if index < 0 or index >= length:
                raise IndexError, "list index out of range"

            self.copyBlock(index + 1, length, index)
            self.setLength(length - 1)
        elif isinstance(pyIndex, slice):
            start, end, step = pyIndex.indices(length)

            if step == 1:
                # Move the elements after the slice to their final
                # position.
                self.copyBlock(end, length, start)
                self.setLength(length - (end - start))
            else:
                # Copy the elements to their final positions. Elements
                # are copied from frm to dest. nextDel marks the
                # position of the next element that must be deleted
                # (-1 if no more elements have to be deleted).

                nextDel = start
                if nextDel >= end:
                    nextDel = -1

                dest = start
                for frm in range(start, length):
                    if frm == nextDel:
                        nextDel += step
                        if nextDel >= end:
                            nextDel = -1
                    else:
                        self.setItem(dest, self.getItem(frm))
                        dest += 1

                # Truncate the list.
                self.setLength(dest)
        else:
            raise TypeError, "list indices must be integers, not %s" % \
                pyIndex.__class__.__name__        

    def insert(self, pyIndex, pyValue):
        cdef int index
        cdef int length = self.getLength()

        if not isinstance(pyIndex, int) and not isinstance(pyIndex, long):
            raise TypeError, "list indices must be integers, not %s" % \
                pyIndex.__class__.__name__

        index = pyIndex

        # The insert method is special in how indexes are handled:

        # Handle negative indexes.
        if index < 0:
            index += length

        # Handle out-of-range indexes.
        if index < 0:
            index = 0
        elif index > length:
            index = length

        self.copyBlock(index, length, index + 1)
        self.setItem(index, pythonToJS(self.jsCtx, pyValue))


class JSSequence(_JSSequence, collections.MutableSequence):
    """Mix ``_JSSequence`` and ``collections.MutableSequence``."""
    __slots__ = ()


cdef class _JSSeqIterator:
    """Iterator class for JavaScript array-like objects."""

    cdef _JSSequence pySeq
    cdef int index

    def __init__(self, pySeq):
        self.pySeq = pySeq
        self.index = 0

    def __iter__(self):
        return self

    def __next__(self):
        if self.index < self.pySeq.getLength():
            value = self.pySeq[self.index]
            self.index += 1
            return value
        else:
            raise StopIteration

    def next(self):
        """Wrap the ``__next__`` method for backwards compatibility.
        """
        return self.__next__()


cdef class _JSObject(_JSBaseObject):
    """Wrapper class to make JavaScript objects accessible from
    Python.

    Since JavaScript objects can be interchangeably used as objects
    and as associative data structures, wrapped JavaScript objects
    always implement Python's mapping protocol. For those JavaScript
    objects that behave like sequences, the ``asSeq`` function (or
    ``__asSeq__`` method ) can be invoked to obtain a view of the
    object that behaves as a Python sequence.

    Also, since Cython extension classes cannot inherit from Python
    classes, we first define class ``_JSObject`` and then define
    ``JSObject`` as a standard Python class that mixes in
    ``MutableSequence`` from the ``collections`` module."""

    # Sequence view of this object.
    cdef _JSSequence seqView

    def __init__(self):
        _JSBaseObject.__init__(self)
        self.seqView = None

    def __getattr__(self, pyName):
        cdef JSStringRef jsName
        cdef JSValueRef jsException = NULL
        cdef JSValueRef jsResult

        jsName = createJSStringFromPython(pyName)
        try:
            jsResult = JSObjectGetProperty(self.jsCtx, self.jsObject,
                                           jsName, &jsException)
            if jsException != NULL:
                raise jsExceptionToPython(self.jsCtx, jsException)

            if JSValueIsUndefined(self.jsCtx, jsResult):
                # This may be a property with an undefined value, or
                # no property at all.
                if JSObjectHasProperty(self.jsCtx, self.jsObject, jsName):
                    return jsToPython(self.jsCtx, jsResult)
                else:
                    # For inexisting properties, we use Python
                    # behavior.
                    raise AttributeError, \
                        "JavaScript object has no property '%s'" % pyName
            elif not JSValueIsObjectOfClass(self.jsCtx, jsResult,
                                          pyObjectClass) and \
                  JSValueIsObject(self.jsCtx, jsResult) and \
                  JSObjectIsFunction(self.jsCtx, jsResult):                  
                # This is a native JavaScript function, we mimic
                # Python's behavior and return it bound to this
                # object.
                return makeJSBoundMethod(self.jsCtx, jsResult,
                                         self.jsObject)
            else:
                return jsToPython(self.jsCtx, jsResult)
        finally:
            JSStringRelease(jsName)

    def __setattr__(self, pyName, pyValue):
        cdef JSStringRef jsName
        cdef JSValueRef jsException = NULL

        jsName = createJSStringFromPython(pyName)
        try:
            JSObjectSetProperty(self.jsCtx, self.jsObject, jsName,
                                pythonToJS(self.jsCtx, pyValue),
                                kJSPropertyAttributeNone, &jsException)
            if jsException != NULL:
                raise jsExceptionToPython(self.jsCtx, jsException)
        finally:
            JSStringRelease(jsName)

    def __delattr__(self, pyName):
        cdef JSStringRef jsName
        cdef JSValueRef jsException = NULL

        jsName = createJSStringFromPython(pyName)
        try:
            if not JSObjectHasProperty(self.jsCtx, self.jsObject, jsName):
                # Use Python behavior for inexisting properties.
                raise AttributeError, \
                    "JavaScript object has no property '%s'" % pyName

            if not JSObjectDeleteProperty(self.jsCtx, self.jsObject,
                                          jsName, &jsException):
                raise AttributeError, \
                    "property '%s' of JavaScript object cannot " \
                    "be deleted" % pyName
            if jsException != NULL:
                raise jsExceptionToPython(self.jsCtx, jsException)
        finally:
            JSStringRelease(jsName)

    def __asSeq__(self):
        """Return the sequence view of this object.

        Since it is impossible to reliably distinguish between
        JavaScript arrays and array-like objects and other types of
        objects, we cannot decide automatically when a Python wrapper
        should behave as a sequence.  This method retrieves a view of
        the current object (a proxy object) that implements the
        mutable sequence protocol.

        Some of the operations depend in the view depend on the
        presence of a 'length' property in the original object, and
        will fail with a ``TypeError`` when it isn't present.

        This method should normally be called through the ``asSeq``
        function in this module.
        """
        if self.seqView is None:
            self.seqView = JSSequence()
            self.seqView.setup(self.jsCtx, self.jsObject)
        return self.seqView


    #
    # Methods implementing the mutable mapping protocol
    #

    def __len__(self):
        cdef JSPropertyNameArrayRef nameArray

        nameArray = JSObjectCopyPropertyNames(self.jsCtx, self.jsObject)
        try:
            return JSPropertyNameArrayGetCount(nameArray)
        finally:
            JSPropertyNameArrayRelease(nameArray)

    def __iter__(self):
        return _JSObjectIterator(self)

    def __contains__(self, pyKey):
        cdef JSStringRef jsKey

        jsKey = createJSStringFromPython(pyKey)
        try:
            return JSObjectHasProperty(self.jsCtx, self.jsObject,
                                       jsKey) != 0
        finally:
            JSStringRelease(jsKey)

    def __getitem__(self, pyKey):
        cdef JSStringRef jsKey
        cdef JSValueRef jsException = NULL
        cdef JSValueRef jsResult

        jsKey = createJSStringFromPython(pyKey)
        try:
            jsResult = JSObjectGetProperty(self.jsCtx, self.jsObject,
                                           jsKey, &jsException)
            if jsException != NULL:
                raise jsExceptionToPython(self.jsCtx, jsException)

            if JSValueIsUndefined(self.jsCtx, jsResult):
                # This may be a property with an undefined value, or
                # no property at all.
                if JSObjectHasProperty(self.jsCtx, self.jsObject, jsKey):
                    return jsToPython(self.jsCtx, jsResult)
                else:
                    # For inexisting properties, we use Python
                    # behavior.
                    raise KeyError, \
                        "JavaScript object has no property '%s'" % pyKey
            else:
                return jsToPython(self.jsCtx, jsResult)
        finally:
            JSStringRelease(jsKey)

    def __setitem__(self, pyKey, pyValue):
        cdef JSStringRef jsKey
        cdef JSValueRef jsException = NULL

        jsKey = createJSStringFromPython(pyKey)
        try:
            JSObjectSetProperty(self.jsCtx, self.jsObject, jsKey,
                                pythonToJS(self.jsCtx, pyValue),
                                kJSPropertyAttributeNone, &jsException)
            if jsException != NULL:
                raise jsExceptionToPython(self.jsCtx, jsException)
        finally:
            JSStringRelease(jsKey)

    def __delitem__(self, pyKey):
        cdef JSStringRef jsKey
        cdef JSValueRef jsException = NULL

        jsKey = createJSStringFromPython(pyKey)
        try:
            if not JSObjectHasProperty(self.jsCtx, self.jsObject, jsKey):
                # Use Python behavior for inexisting properties.
                raise KeyError, \
                    "JavaScript object has no property '%s'" % pyKey

            if not JSObjectDeleteProperty(self.jsCtx, self.jsObject,
                                          jsKey, &jsException):
                raise KeyError, \
                    "property '%s' of JavaScript object cannot " \
                    "be deleted" % pyKey
            if jsException != NULL:
                raise jsExceptionToPython(self.jsCtx, jsException)
        finally:
            JSStringRelease(jsKey)


class JSObject(_JSObject, collections.MutableMapping):
    """Mix ``_JSObject`` and ``collections.MutableMapping``."""
    __slots__ = ()


cdef class _JSObjectIterator:
    """Iterator class for JavaScript objects.

    This provides mapping-style iteration on JavaScript objects."""

    cdef JSPropertyNameArrayRef nameArray
    cdef int index

    def __init__(self, _JSObject pyObject):
        self.nameArray = JSObjectCopyPropertyNames(pyObject.jsCtx,
                                                   pyObject.jsObject)
        self.index = 0

    def __iter__(self):
        return self

    def __next__(self):
        if self.index < JSPropertyNameArrayGetCount(self.nameArray):
            pyPropName = pyStringFromJS(JSPropertyNameArrayGetNameAtIndex(
                    self.nameArray, self.index))
            self.index += 1
            return pyPropName
        else:
            raise StopIteration

    def next(self):
        """Wrap the ``__next__`` method for backwards compatibility.
        """
        return self.__next__()

    def __dealloc__(self):
        JSPropertyNameArrayRelease(self.nameArray)


def asSeq(pyObject):
    """Return the sequence view of ``pyObject``."""
    return pyObject.__asSeq__()


cdef makeJSObject(JSContextRef jsCtx, JSObjectRef jsObject):
    """Factory function for 'JSObject' instances."""
    cdef _JSObject obj = JSObject()
    obj.setup(jsCtx, jsObject)
    return obj


cdef class _JSFunction(_JSObject):
    """Specialized wrapper class to make JavaScript functions callable
    from Python.

    This class gets mixed with ``collections.MutableMapping in the
    ``JSFunction`` class."""

    def __call__(self, *args):
        cdef JSValueRef *jsArgs
        cdef JSValueRef result
        cdef JSObjectRef jsThisObject
        cdef JSValueRef jsError = NULL

        if len(args):
            jsArgs = <JSValueRef *>malloc(len(args) * sizeof(JSValueRef))
        else:
            jsArgs = NULL
        for i, arg in enumerate(args):
            jsArgs[i] = pythonToJS(self.jsCtx, arg)
        result = JSObjectCallAsFunction(self.jsCtx, self.jsObject,
                                        NULL, len(args), jsArgs,
                                        &jsError)
        free(jsArgs)
        if jsError != NULL:
            raise jsExceptionToPython(self.jsCtx, jsError)
        return jsToPython(self.jsCtx, result)


class JSFunction(_JSFunction, collections.MutableMapping):
    """Mix ``_JSFunction`` and ``collections.MutableMapping``."""
    __slots__ = ()


cdef makeJSFunction(JSContextRef jsCtx, JSObjectRef jsObject):
    """Factory function for 'JSFunction' instances."""
    cdef _JSFunction obj = JSFunction()
    obj.setup(jsCtx, jsObject)
    return obj


cdef class _JSBoundMethod(_JSObject):
    """A JavaScript bound method.

    Instances of this class operate in a similar way to Python bound
    methods, but they encapsulate a JavaScript object and
    function. When they are called, the function is called with the
    object as 'this' object.

    This class gets mixed with ``collections.MutableMapping in the
    ``JSBoundMethod`` class."""

    cdef JSObjectRef jsThisObj 

    cdef setup2(self, JSContextRef jsCtx, JSObjectRef jsObject,
                JSObjectRef jsThisObj):
        _JSObject.setup(self, jsCtx, jsObject)
        # __dealloc__ unprotects jsThisObj, so that it's guaranteed to
        # exist as long as this object exists.
        JSValueProtect(jsCtx, jsThisObj)
        self.jsThisObj = jsThisObj

    def __call__(self, *args):
        cdef JSValueRef *jsArgs
        cdef JSValueRef result
        cdef JSValueRef jsError = NULL

        if len(args):
            jsArgs = <JSValueRef *>malloc(len(args) * sizeof(JSValueRef))
        else:
            jsArgs = NULL
        for i, arg in enumerate(args):
            jsArgs[i] = pythonToJS(self.jsCtx, arg)
        result = JSObjectCallAsFunction(self.jsCtx, self.jsObject,
                                        self.jsThisObj, len(args), jsArgs,
                                        &jsError)
        free(jsArgs)
        if jsError != NULL:
            raise jsExceptionToPython(self.jsCtx, jsError)
        return jsToPython(self.jsCtx, result)

    def __dealloc__(self):
        JSValueUnprotect(self.jsCtx, self.jsThisObj)


class JSBoundMethod(_JSBoundMethod, collections.MutableMapping):
    """Mix ``_JSBoundMethod`` and ``collections.MutableMapping``."""
    __slots__ = ()


cdef makeJSBoundMethod(JSContextRef jsCtx, JSObjectRef jsObject,
                       JSObjectRef thisObj):
    """Factory function for 'JSBoundMethod' instances."""
    cdef _JSBoundMethod obj = JSBoundMethod()
    obj.setup2(jsCtx, jsObject, thisObj)
    return obj


cdef class JSContext:
    """Wrapper class for JavaScriptCore context objects.

    Call the constructor without arguments to obtain a new default
    context that can be used to execute JavaScript but that will not
    provide any access to a DOM or any other browser-specific objects.

    A context obtained from another object (e.g. a WebKit browser
    component can also be passed to the constructor in order to gain
    full access to it from Python.
    """

    cdef JSContextRef jsCtx
    cdef object pyCtxExtern

    def __cinit__(self, pyCtxExtern=None):
        if pyCtxExtern is None:
            # Create a new context.
            self.jsCtx = JSGlobalContextCreate(NULL)
            self.pyCtxExtern = None
        else:
            # Extract the actual context object.
            self.jsCtx = <JSContextRef>PyCObject_AsVoidPtr(pyCtxExtern)
            JSGlobalContextRetain(self.jsCtx)
            self.pyCtxExtern = pyCtxExtern

    def __init__(self, pyCtxExtern=None):
        pass

    property globalObject:
        """Global object for this context."""

        def __get__(self):
            return jsToPython(self.jsCtx,
                              JSContextGetGlobalObject(self.jsCtx))

    def evaluateScript(self, script, thisObject=None, sourceURL=None,
                       startingLineNumber=1):
        cdef JSValueRef jsException = NULL
        cdef JSValueRef jsValue

        cdef JSStringRef jsScript = createJSStringFromPython(script)
        try:
            jsValue = JSEvaluateScript(self.jsCtx, jsScript,
                                       <JSObjectRef>NULL,
                                       <JSStringRef>NULL,
                                       startingLineNumber,
                                       &jsException)
            if jsException != NULL:
                raise jsExceptionToPython(self.jsCtx, jsException)
        finally:
            JSStringRelease(jsScript)

        return jsToPython(self.jsCtx, jsValue)

    def getCtx(self):
        return self.pyCtxExtern

    def __dealloc__(self):
        JSGlobalContextRelease(self.jsCtx)


#
# JavaScript Wrappers for Python Objects
#

# Helper functions:

cdef JSValueRef pyExceptionToJS(JSContextRef jsCtx, object exc):
    """Make a JavaScript exception object from a Python exception
    object."""
    cdef JSStringRef jsMsgStr
    cdef JSValueRef jsMsg

    # Make a string from the exception object (the unicode conversion
    # in createJSStringFromPython takes care of extracting the
    # message).
    jsMsgStr = createJSStringFromPython(exc)
    jsMsg = JSValueMakeString(jsCtx, jsMsgStr)
    JSStringRelease(jsMsgStr)

    return JSObjectMakeError(jsCtx, 1, &jsMsg, NULL)


# PythonObject: Generic JavaScript wrapper for Python objects.

cdef void pyObjInitialize(JSContextRef ctx,
                          JSObjectRef jsObj) with gil:
    cdef object pyObj = <object>JSObjectGetPrivate(jsObj)

    # Keep a reference to the wrapped Python object during the
    # lifetime of the JavaScript wrapper. This reference is released
    # in the finalize method.
    Py_INCREF(pyObj)

cdef JSValueRef pyObjGetProperty(JSContextRef jsCtx,
                                 JSObjectRef jsObj,
                                 JSStringRef jsPropertyName,
                                 JSValueRef* jsExc) with gil:
    cdef object pyObj = <object>JSObjectGetPrivate(jsObj)
    cdef object pyPropertyName = pyStringFromJS(jsPropertyName)

    try:
        return pythonToJS(jsCtx, getattr(pyObj, pyPropertyName))
    except AttributeError:
        # Use the standard JavaScript attribute behavior when
        # attributes can't be found.
        return NULL
    except BaseException, e:
        jsExc[0] = pyExceptionToJS(jsCtx, e)

cdef bool pyObjSetProperty(JSContextRef jsCtx,
                           JSObjectRef jsObj,
                           JSStringRef jsPropertyName,
                           JSValueRef jsValue,
                           JSValueRef* jsExc) with gil:
    cdef object pyObj = <object>JSObjectGetPrivate(jsObj)
    cdef object pyPropertyName = pyStringFromJS(jsPropertyName)
    cdef object pyValue = jsToPython(jsCtx, jsValue)

    try:
        setattr(pyObj, pyPropertyName, pyValue)
        return True
    except BaseException, e:
        jsExc[0] = pyExceptionToJS(jsCtx, e)

cdef bool pyObjDeleteProperty(JSContextRef jsCtx,
                              JSObjectRef jsObj,
                              JSStringRef jsPropertyName,
                              JSValueRef* jsExc) with gil:
    cdef object pyObj = <object>JSObjectGetPrivate(jsObj)
    cdef object pyPropertyName = pyStringFromJS(jsPropertyName)

    try:
        delattr(pyObj, pyPropertyName)
        return True
    except AttributeError:
        # Use the standard JavaScript attribute behavior when
        # attributes can't be found.
        return False
    except BaseException, e:
        jsExc[0] = pyExceptionToJS(jsCtx, e)    

cdef JSValueRef pyObjCallAsFunction(JSContextRef jsCtx,
                                    JSObjectRef jsObj,
                                    JSObjectRef jsThisObj,
                                    size_t argumentCount,
                                    JSValueRef jsArgs[],
                                    JSValueRef* jsExc) with gil:
    """Invoked when a wrapped object is called as a function."""
    cdef object pyObj = <object>JSObjectGetPrivate(jsObj)
    cdef int i

    args = [jsToPython(jsCtx, jsArgs[i])
            for i in range(argumentCount)]
    try:
        return pythonToJS(jsCtx, pyObj(*args))
    except BaseException, e:
        jsExc[0] = pyExceptionToJS(jsCtx, e)

cdef void pyObjFinalize(JSObjectRef jsObj) with gil:
    cdef object pyObj = <object>JSObjectGetPrivate(jsObj)

    # Remove this wrapper from the wrapper cache.
    del _pyWrappedPyObjs[id(pyObj)]

    Py_DECREF(pyObj)

# Class definition structure for PythonObject.
cdef JSClassDefinition pyObjectClassDef = kJSClassDefinitionEmpty
pyObjectClassDef.className = 'PythonObject'
pyObjectClassDef.initialize = pyObjInitialize
pyObjectClassDef.getProperty = pyObjGetProperty
pyObjectClassDef.setProperty = pyObjSetProperty
pyObjectClassDef.deleteProperty = pyObjDeleteProperty
pyObjectClassDef.callAsFunction = pyObjCallAsFunction
pyObjectClassDef.finalize = pyObjFinalize

# PythonObject class.
cdef JSClassRef pyObjectClass = JSClassCreate(&pyObjectClassDef)


# PythonSequence: Specialized JavaScript wrapper for Python objects
# implementing the sequence protocol.

cdef object makePyIndex(pyPropertyName):
    """Convert a JavaScript property name into a positive Python
    integer index."""
    cdef object pyIndex

    pyIndex = int(pyPropertyName)
    if pyIndex < 0:
        raise ValueError

    return pyIndex

cdef bool pySeqHasProperty(JSContextRef jsCtx,
                           JSObjectRef jsSeq,
                           JSStringRef jsPropertyName) with gil:
    cdef object pySeq = <object>JSObjectGetPrivate(jsSeq)
    cdef object pyPropertyName = pyStringFromJS(jsPropertyName)

    try:
        return 0 <= makePyIndex(pyPropertyName) < len(pySeq)
    except:
        return False

cdef JSValueRef pySeqGetProperty(JSContextRef jsCtx,
                                 JSObjectRef jsSeq,
                                 JSStringRef jsPropertyName,
                                 JSValueRef* jsExc) with gil:
    cdef object pySeq = <object>JSObjectGetPrivate(jsSeq)
    cdef object pyPropertyName = pyStringFromJS(jsPropertyName)

    try:
        return pythonToJS(jsCtx, pySeq[makePyIndex(pyPropertyName)])
    except:
        return NULL

cdef bool pySeqSetProperty(JSContextRef jsCtx,
                           JSObjectRef jsSeq,
                           JSStringRef jsPropertyName,
                           JSValueRef jsValue,
                           JSValueRef* jsExc) with gil:
    cdef object pySeq = <object>JSObjectGetPrivate(jsSeq)
    cdef object pyPropertyName = pyStringFromJS(jsPropertyName)
    cdef object pyValue = jsToPython(jsCtx, jsValue)
    cdef object pyIndex

    try:
        pyIndex = makePyIndex(pyPropertyName)

        # Simulate JavaScript behavior when the positions beyond the
        # length are assigned to.
        if pyIndex >= len(pySeq):
            pySeq.extend([None] * (1 + pyIndex - len(pySeq)))

        pySeq[pyIndex] = pyValue
        return True
    except:
        return False

cdef bool pySeqDeleteProperty(JSContextRef jsCtx,
                              JSObjectRef jsSeq,
                              JSStringRef jsPropertyName,
                              JSValueRef* jsExc) with gil:
    cdef object pySeq = <object>JSObjectGetPrivate(jsSeq)
    cdef object pyPropertyName = pyStringFromJS(jsPropertyName)

    try:
        # Delete behaves differently in JavaScript.
        pySeq[makePyIndex(pyPropertyName)] = None
        return True
    except:
        return False

# Static properties.

cdef JSStaticValueNC pySeqStaticProps[2]

cdef JSValueRef pySeqGetLength(JSContextRef jsCtx,
                               JSObjectRef jsSeq,
                               JSStringRef jsPropertyName,
                               JSValueRef* jsExc) with gil:
    cdef object pySeq = <object>JSObjectGetPrivate(jsSeq)

    try:
        return pythonToJS(jsCtx, len(pySeq))
    except BaseException, e:
        jsExc[0] = pyExceptionToJS(jsCtx, e)

cdef bool pySeqSetLength(JSContextRef jsCtx,
                         JSObjectRef jsSeq,
                         JSStringRef jsPropertyName,
                         JSValueRef jsValue,
                         JSValueRef* jsExc) with gil:
    cdef object pySeq = <object>JSObjectGetPrivate(jsSeq)
    cdef object pyLength

    try:
        pyLength = int(jsToPython(jsCtx, jsValue))
        if pyLength < 0:
            raise ValueError, 'Invalid length %d' % pyLength

        if pyLength < len(pySeq):
            pySeq[pyLength:] = ()
        elif pyLength > len(pySeq):
            pySeq.extend([None] * (pyLength - len(pySeq)))

        return True
    except BaseException, e:
        jsExc[0] = pyExceptionToJS(jsCtx, e)
        return False
    

pySeqStaticProps[0].name = "length"
pySeqStaticProps[0].getProperty = pySeqGetLength
pySeqStaticProps[0].setProperty = pySeqSetLength
pySeqStaticProps[0].attributes = \
    kJSPropertyAttributeDontEnum | kJSPropertyAttributeDontDelete

# Terminator entry.
pySeqStaticProps[1].name = NULL
pySeqStaticProps[1].getProperty = NULL
pySeqStaticProps[1].setProperty = NULL
pySeqStaticProps[1].attributes = 0

# Class definition structure for PythonSequence.
cdef JSClassDefinition pySeqClassDef = kJSClassDefinitionEmpty
pySeqClassDef.className = 'PythonSequence'
pySeqClassDef.staticValues = <JSStaticValue*>pySeqStaticProps
pySeqClassDef.parentClass = pyObjectClass
pySeqClassDef.hasProperty = pySeqHasProperty
pySeqClassDef.getProperty = pySeqGetProperty
pySeqClassDef.setProperty = pySeqSetProperty
pySeqClassDef.deleteProperty = pySeqDeleteProperty

# PythonSequence class.
cdef JSClassRef pySeqClass = JSClassCreate(&pySeqClassDef)


# PythonMapping: Specialized JavaScript wrapper for Python objects
# implementing the mapping protocol.

cdef void pyMapGetPropertyNames(JSContextRef jsCtx,
                                JSObjectRef jsMap,
                                JSPropertyNameAccumulatorRef
                                  jsPropertyNames) with gil:
    cdef object pyMap = <object>JSObjectGetPrivate(jsMap)
    cdef JSStringRef jsName

    for pyName in pyMap:
        jsName = createJSStringFromPython(pyName)
        try:
            JSPropertyNameAccumulatorAddName(jsPropertyNames, jsName)
        finally:
            JSStringRelease(jsName)

cdef JSValueRef pyMapGetProperty(JSContextRef jsCtx,
                                 JSObjectRef jsMap,
                                 JSStringRef jsPropertyName,
                                 JSValueRef* jsExc) with gil:
    cdef object pyMap = <object>JSObjectGetPrivate(jsMap)
    cdef object pyPropertyName = pyStringFromJS(jsPropertyName)

    try:
        return pythonToJS(jsCtx, pyMap[pyPropertyName])
    except:
        return NULL

cdef bool pyMapSetProperty(JSContextRef jsCtx,
                           JSObjectRef jsMap,
                           JSStringRef jsPropertyName,
                           JSValueRef jsValue,
                           JSValueRef* jsExc) with gil:
    cdef object pyMap = <object>JSObjectGetPrivate(jsMap)
    cdef object pyPropertyName = pyStringFromJS(jsPropertyName)
    cdef object pyValue = jsToPython(jsCtx, jsValue)

    try:
        pyMap[pyPropertyName] = pyValue
        return True
    except:
        return False

cdef bool pyMapDeleteProperty(JSContextRef jsCtx,
                              JSObjectRef jsMap,
                              JSStringRef jsPropertyName,
                              JSValueRef* jsExc) with gil:
    cdef object pyMap = <object>JSObjectGetPrivate(jsMap)
    cdef object pyPropertyName = pyStringFromJS(jsPropertyName)

    try:
        del pyMap[pyPropertyName]
        return True
    except:
        return False

# Class definition structure for PythonMapping.
cdef JSClassDefinition pyMapClassDef = kJSClassDefinitionEmpty
pyMapClassDef.className = 'PythonMapping'
pyMapClassDef.parentClass = pyObjectClass
pyMapClassDef.getProperty = pyMapGetProperty
pyMapClassDef.setProperty = pyMapSetProperty
pyMapClassDef.deleteProperty = pyMapDeleteProperty
pyMapClassDef.getPropertyNames = pyMapGetPropertyNames

# PythonMapping class.
cdef JSClassRef pyMapClass = JSClassCreate(&pyMapClassDef)


# Wrap a Python object into the appropriate JavaScript class instance.
cdef JSObjectRef makePyObject(JSContextRef jsCtx, object pyObj):
    """Wrap a Python object for use in JavaScript."""
    if isinstance(pyObj, collections.Sequence):
        return JSObjectMake(jsCtx, pySeqClass, <void *>pyObj)
    elif isinstance(pyObj, collections.Mapping):
        return JSObjectMake(jsCtx, pyMapClass, <void *>pyObj)
    else:
        return JSObjectMake(jsCtx, pyObjectClass, <void *>pyObj)


#
# Debugging and testing operations
#

def _cachedStats():
    """Returns statistics about the wrappers cached in this moduel."""
    return {'wrappedJSObjsCount': len(_pyWrappedJSObjs),
            'wrappedPyObjsCount': len(_pyWrappedPyObjs),
            }
