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

cdef extern from "JavaScriptCore/JSValueRef.h":

    cdef enum JSType :
         kJSTypeUndefined, kJSTypeNull, kJSTypeBoolean, kJSTypeNumber,
         kJSTypeString, kJSTypeObject

    JSType JSValueGetType(JSContextRef ctx, JSValueRef value)

    bool JSValueIsObjectOfClass(JSContextRef ctx, JSValueRef value,
                                JSClassRef jsClass)
    
    bool JSValueIsObject(JSContextRef ctx, JSValueRef value)

    bool JSValueIsStrictEqual(JSContextRef ctx, JSValueRef a, JSValueRef b)

    bool JSValueIsUndefined(JSContextRef ctx, JSValueRef value)

    JSValueRef JSValueMakeBoolean(JSContextRef ctx, bool boolean)

    JSValueRef JSValueMakeNull(JSContextRef ctx)

    JSValueRef JSValueMakeNumber(JSContextRef ctx, double number)

    JSValueRef JSValueMakeString(JSContextRef ctx, JSStringRef string)

    JSValueRef JSValueMakeUndefined(JSContextRef ctx)

    bool JSValueToBoolean(JSContextRef ctx, JSValueRef value)

    void JSValueProtect(JSContextRef ctx, JSValueRef value)

    double JSValueToNumber(JSContextRef ctx, JSValueRef value,
                           JSValueRef* exception)

    JSObjectRef JSValueToObject(JSContextRef ctx, JSValueRef value,
                                JSValueRef* exception)

    JSStringRef JSValueToStringCopy(JSContextRef ctx, JSValueRef value,
                                    JSValueRef* exception)

    void JSValueUnprotect(JSContextRef ctx, JSValueRef value)
