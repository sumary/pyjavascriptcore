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

cdef extern from "JavaScriptCore/JSStringRef.h":
    ctypedef unsigned short JSChar
    void JSStringRelease(JSStringRef string)
    JSStringRef JSStringCreateWithUTF8CString(char* string)
    JSStringRef JSStringCreateWithCharacters(JSChar* chars, size_t numChars)
    size_t JSStringGetLength(JSStringRef string)
    JSChar* JSStringGetCharactersPtr(JSStringRef string)
    size_t JSStringGetMaximumUTF8CStringSize(JSStringRef string)
    size_t JSStringGetUTF8CString(JSStringRef string, char* buffer,
                                  size_t bufferSize)
