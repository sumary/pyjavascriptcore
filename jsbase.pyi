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

cdef extern from "JavaScriptCore/JSBase.h":
    struct OpaqueJSContextGroup:
        pass
    ctypedef OpaqueJSContextGroup* JSContextGroupRef

    struct OpaqueJSContext:
        pass
    ctypedef OpaqueJSContext* JSContextRef
    ctypedef OpaqueJSContext* JSGlobalContextRef
    
    struct OpaqueJSString:
        pass
    ctypedef OpaqueJSString* JSStringRef
    
    struct OpaqueJSClass:
        pass
    ctypedef OpaqueJSClass* JSClassRef
    
    struct OpaqueJSPropertyNameArray:
        pass
    ctypedef OpaqueJSPropertyNameArray* JSPropertyNameArrayRef
    
    struct OpaqueJSPropertyNameAccumulator:
        pass
    ctypedef OpaqueJSPropertyNameAccumulator* JSPropertyNameAccumulatorRef
    
    struct OpaqueJSValue:
        pass
    ctypedef OpaqueJSValue* JSValueRef
    ctypedef OpaqueJSValue* JSObjectRef
    
    JSValueRef JSEvaluateScript(JSContextRef ctx, JSStringRef script, JSObjectRef thisObject, JSStringRef sourceURL, int startingLineNumber, JSValueRef* exception)
    bool JSCheckScriptSyntax(JSContextRef ctx, JSStringRef script, JSStringRef sourceURL, int startingLineNumber, JSValueRef* exception)
    void JSGarbageCollect(JSContextRef ctx)
