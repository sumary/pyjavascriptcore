cdef extern from "JavaScriptCore/JSContextRef.h":
    JSObjectRef JSContextGetGlobalObject(JSContextRef ctx)

    JSContextGroupRef JSContextGroupCreate()

    void JSContextGroupRelease(JSContextGroupRef group)

    JSContextGroupRef JSContextGroupRetain(
        JSContextGroupRef group)

    JSGlobalContextRef JSGlobalContextCreate(
        JSClassRef globalObjectClass)

    JSGlobalContextRef JSGlobalContextCreateInGroup(
        JSContextGroupRef group,
        JSClassRef globalObjectClass)

    void JSGlobalContextRelease(
        JSGlobalContextRef ctx)

    JSGlobalContextRef JSGlobalContextRetain(
        JSGlobalContextRef ctx)
