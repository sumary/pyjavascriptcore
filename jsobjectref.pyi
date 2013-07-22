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

cdef extern from "JavaScriptCore/JSObjectRef.h":

    enum :
        kJSPropertyAttributeNone, kJSPropertyAttributeReadOnly, 
        kJSPropertyAttributeDontEnum, kJSPropertyAttributeDontDelete

    ctypedef unsigned JSPropertyAttributes

    ctypedef struct JSClassDefinition

    ctypedef unsigned JSClassAttributes

    ctypedef void (*JSObjectInitializeCallback) (
        JSContextRef ctx, JSObjectRef object)

    ctypedef void (*JSObjectFinalizeCallback) (JSObjectRef object)

    ctypedef bool (*JSObjectHasPropertyCallback) (
        JSContextRef ctx, JSObjectRef object, JSStringRef propertyName)

    ctypedef JSValueRef (*JSObjectGetPropertyCallback) (
        JSContextRef ctx, JSObjectRef object, JSStringRef propertyName,
        JSValueRef* exception)

    ctypedef bool (*JSObjectSetPropertyCallback) (
        JSContextRef ctx, JSObjectRef object, JSStringRef propertyName,
        JSValueRef value, JSValueRef* exception)

    ctypedef bool (*JSObjectDeletePropertyCallback) (
        JSContextRef ctx, JSObjectRef object, JSStringRef propertyName,
        JSValueRef* exception)

    ctypedef void (*JSObjectGetPropertyNamesCallback) (
        JSContextRef ctx, JSObjectRef object,
        JSPropertyNameAccumulatorRef propertyNames)

    ctypedef JSValueRef (*JSObjectCallAsFunctionCallback) (
        JSContextRef ctx, JSObjectRef function, JSObjectRef thisObject,
        size_t argumentCount, JSValueRef arguments[], JSValueRef* exception)

    ctypedef JSObjectRef (*JSObjectCallAsConstructorCallback) (
        JSContextRef ctx, JSObjectRef constructor, size_t argumentCount,
        JSValueRef arguments[], JSValueRef* exception)

    ctypedef bool (*JSObjectHasInstanceCallback)  (
        JSContextRef ctx, JSObjectRef constructor,
        JSValueRef possibleInstance, JSValueRef* exception)

    ctypedef JSValueRef (*JSObjectConvertToTypeCallback) (
        JSContextRef ctx, JSObjectRef object, JSType type,
        JSValueRef* exception)

    # If this ever changes, JSStaticFunctionNC below must be changed
    # as well.
    ctypedef struct JSStaticFunction:
        char* name
        JSObjectCallAsFunctionCallback callAsFunction
        JSPropertyAttributes attributes

    # If this ever changes, JSStaticValueNC below must be changed
    # as well.
    ctypedef struct JSStaticValue:
        char* name
        JSObjectGetPropertyCallback getProperty
        JSObjectSetPropertyCallback setProperty
        JSPropertyAttributes attributes

    ctypedef struct JSClassDefinition:
        int version # current (and only) version is 0
        JSClassAttributes attributes

        char* className
        JSClassRef parentClass
 
        JSStaticValue* staticValues
        JSStaticFunction* staticFunctions
 
        JSObjectInitializeCallback initialize
        JSObjectFinalizeCallback finalize
        JSObjectHasPropertyCallback hasProperty
        JSObjectGetPropertyCallback getProperty
        JSObjectSetPropertyCallback setProperty
        JSObjectDeletePropertyCallback deleteProperty
        JSObjectGetPropertyNamesCallback getPropertyNames
        JSObjectCallAsFunctionCallback callAsFunction
        JSObjectCallAsConstructorCallback callAsConstructor
        JSObjectHasInstanceCallback hasInstance
        JSObjectConvertToTypeCallback convertToType

    JSClassRef JSClassCreate(JSClassDefinition* definition)

    JSValueRef JSObjectCallAsFunction(JSContextRef ctx, JSObjectRef object,
                                      JSObjectRef thisObject,
                                      size_t argumentCount,
                                      JSValueRef arguments[],
                                      JSValueRef* exception)

    JSPropertyNameArrayRef JSObjectCopyPropertyNames(JSContextRef ctx,
                                                     JSObjectRef object)

    bool JSObjectDeleteProperty(JSContextRef ctx, JSObjectRef object,
                                JSStringRef propertyName,
                                JSValueRef* exception)

    void* JSObjectGetPrivate(JSObjectRef object)

    JSValueRef JSObjectGetProperty(JSContextRef ctx, JSObjectRef object,
                                   JSStringRef propertyName,
                                   JSValueRef* exception)

    JSValueRef JSObjectGetPropertyAtIndex(JSContextRef ctx,
                                          JSObjectRef object,
                                          unsigned propertyIndex,
                                          JSValueRef* exception)

    bool JSObjectHasProperty(JSContextRef ctx, JSObjectRef object,
                             JSStringRef propertyName)

    JSObjectIsConstructor(JSContextRef ctx, JSObjectRef object)

    bool JSObjectIsFunction(JSContextRef ctx, JSObjectRef object)

    JSObjectRef JSObjectMake(JSContextRef ctx, JSClassRef jsClass,
                             void *data)

    JSObjectRef JSObjectMakeError(JSContextRef ctx, size_t argumentCount,
                                  JSValueRef arguments[],
                                  JSValueRef* exception)

    JSObjectRef JSObjectMakeFunctionWithCallback(
        JSContextRef ctx, JSStringRef name,
        JSObjectCallAsFunctionCallback callAsFunction)

    bool JSObjectSetPrivate(JSObjectRef object, void* data)

    void JSObjectSetProperty(JSContextRef ctx, JSObjectRef object,
                             JSStringRef propertyName, JSValueRef value,
                             JSPropertyAttributes attributes,
                             JSValueRef* exception)

    void JSObjectSetPropertyAtIndex(JSContextRef ctx, JSObjectRef object,
                                    unsigned propertyIndex,
                                    JSValueRef value, JSValueRef* exception)

    void JSPropertyNameAccumulatorAddName(
        JSPropertyNameAccumulatorRef accumulator, JSStringRef propertyName)

    size_t JSPropertyNameArrayGetCount(JSPropertyNameArrayRef array)

    JSStringRef JSPropertyNameArrayGetNameAtIndex(
        JSPropertyNameArrayRef array, size_t index)

    void JSPropertyNameArrayRelease(JSPropertyNameArrayRef array)

    JSPropertyNameArrayRef JSPropertyNameArrayRetain(
        JSPropertyNameArrayRef array)


    # Variables

    JSClassDefinition kJSClassDefinitionEmpty


# No const (NC) declarations. They are necessary because Cython lacks
# array and struct initializers as well as support for the const
# keyword. This makes it impossible to initialize certain structure
# and union fields.

ctypedef struct JSStaticFunctionNC:
    char* name
    JSObjectCallAsFunctionCallback callAsFunction
    JSPropertyAttributes attributes

ctypedef struct JSStaticValueNC:
    char* name
    JSObjectGetPropertyCallback getProperty
    JSObjectSetPropertyCallback setProperty
    JSPropertyAttributes attributes

