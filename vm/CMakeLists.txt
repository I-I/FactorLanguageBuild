# In addition to the BSD style license the rest of Factor ist licensed under,
# You can use, redistribute, or modify this software under the terms of the
# GNU General Public License as published by the Free Software Foundation,
# either version 3 of the License, or any later version.
# See <http://www.gnu.org/licenses/>.
# © 2012 : Nathan Johnson

Project ( FactorLanguage )
CMake_Minimum_Required ( VERSION 2.8 )
#Add_Definitions ( -pipe -fPIC -Wl,--export-dynamic -Wl,--no-as-needed )

Include(CheckTypeSize)
Check_Type_Size("int" WordToYourMotherboard BUILTIN_TYPES_ONLY)
If ( WordToYourMotherboard EQUAL 4 )
ElseIf ( WordToYourMotherboard EQUAL 8 )
Else ()
Message ( FATAL_ERROR "Big mama! Word size of "${WordToYourMotherboard}" is not supported." )
EndIf()

# What processor type?
# Are we x86 or AMD64?
Include ( CheckSymbolExists )
Check_Symbol_Exists ( i386 "" Q-Processor )
# on MS Windows, it's _M_IX86 or _M_X64
If ( Q-Processor )
	Set ( Processor-x86 1 )
Else ()
	Unset ( Q-Processor )
	Check_Symbol_Exists ( __x86_64 "" Q-Processor )
If ( Q-Processor )
	Set ( Processor-x86 1 )
Else()
	Unset ( Q-Processor )
	Check_Symbol_Exists ( _M_IX86 "" Q-Processor )
If ( Q-Processor )
# on MS Windows, it's _M_IX86 or _M_X64
	Set ( Processor-x86 1 )
Else()
	Unset ( Q-Processor )
	Check_Symbol_Exists ( _M_X64 "" Q-Processor )
If ( Q-Processor )
	Set ( Processor-x86 1 )
Else()
	Unset ( Q-Processor )
	Check_Symbol_Exists ( __ARMEL__ "" Q-Processor ) # otherwise __arm__
If ( Q-Processor )
	Set ( Processor-ARM 1 )
Else()
	Message ( WARNING "Unhandled processor type." )
EndIf()
EndIf()
EndIf()
EndIf()
EndIf()
Unset ( Q-Processor )
# End processor type check

If ( Processor-x86 )
	List ( APPEND PlatformLibrary cpu-x86.cpp )
ElseIf ( Processor-ARM )
	List ( APPEND PlatformLibrary os-linux-arm.cpp )
EndIf()


Set ( GUI 1 CACHE BOOL "GUI feature" )


If ( UNIX ) # including Apple OS X and CygWin
	List ( APPEND PlatformLibrary os-unix.cpp  )
	If ( APPLE )
		List ( APPEND PlatformLibrary os-macosx.cpp mach_signal.cpp mvm-unix.cpp )
#-framework Cocoa -L/opt/local/lib $(X11_UI_LIBS) -Wl,-dylib_file,/System/Library/Frameworks/OpenGL.framework/Versions/A/Libraries/libGL.dylib:/System/Library/Frameworks/OpenGL.framework/Versions/A/Libraries/libGL.dylib
	ElseIf ( ${CMAKE_SYSTEM_NAME} MATCHES "Linux" )
# Set Factor sources for platform
		List ( APPEND PlatformLibrary os-linux.cpp os-genunix.cpp mvm-unix.cpp )
		List ( APPEND PlatformExecutable main-unix.cpp )

# Set system sources for platform
		If ( GUI )
			find_package(PkgConfig) # Load the function
			pkg_check_modules ( Library REQUIRED
gtkglext-1.0 gtk+-2.0 pangox gdk-2.0 gio-2.0 pangoft2 gmodule-2.0 gthread-2.0 glib-2.0
				)
		List ( APPEND SystemLibraries ${Library_LIBRARIES} )
		EndIf()
		List ( APPEND SystemLibraries dl pthread )
		List ( SORT SystemLibraries ) # visual duplicate checking
	EndIf()
ElseIf ( WINDOWS ) #untested whether valid
Else ()
	Messsage ( FATAL_ERROR "Target OS is not supported." )
EndIf()

Add_Library ( FactorStack SHARED ${PlatformLibrary}
aging_collector.cpp
alien.cpp
arrays.cpp
bignum.cpp
booleans.cpp
byte_arrays.cpp
callbacks.cpp
callstack.cpp
code_blocks.cpp
code_heap.cpp
compaction.cpp
contexts.cpp
data_heap.cpp
data_heap_checker.cpp
debug.cpp
dispatch.cpp
entry_points.cpp
errors.cpp
factor.cpp
free_list.cpp
full_collector.cpp
gc.cpp
gc_info.cpp
image.cpp
inline_cache.cpp
instruction_operands.cpp
io.cpp
jit.cpp
math.cpp
mvm.cpp
nursery_collector.cpp
object_start_map.cpp
objects.cpp
primitives.cpp
quotations.cpp
run.cpp
safepoints.cpp
sampling_profiler.cpp
strings.cpp
to_tenured_collector.cpp
tuples.cpp
utilities.cpp
vm.cpp
words.cpp
)

Add_Executable ( factor ${PlatformExecutable} ${PlatformLibrary} )

Target_Link_Libraries ( factor FactorStack m rt ${SystemLibraries} )
