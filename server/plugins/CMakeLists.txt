if(NOT NO_LIBSNDFILE)
	find_package(Sndfile)
else()
	add_definitions("-DNO_LIBSNDFILE")
endif()

include_directories(
	${CMAKE_SOURCE_DIR}/include/common
	${CMAKE_SOURCE_DIR}/common
	${CMAKE_SOURCE_DIR}/include/plugin_interface
)

# large file support
if (CMAKE_SIZEOF_VOID_P MATCHES "4")
	execute_process(COMMAND getconf LFS_CFLAGS
		OUTPUT_VARIABLE LFS_CFLAGS
		ERROR_QUIET
		OUTPUT_STRIP_TRAILING_WHITESPACE)
elseif(CMAKE_SIZEOF_VOID_P MATCHES "8")
	execute_process(COMMAND getconf LFS64_CFLAGS
		OUTPUT_VARIABLE LFS_CFLAGS
		ERROR_QUIET
		OUTPUT_STRIP_TRAILING_WHITESPACE)
endif()

set(CMAKE_CXX_FLAGS "${CMAKE_CXX_FLAGS} ${LFS_CFLAGS}")

set(plugin_sources
	BinaryOpUGens.cpp
	ChaosUGens.cpp
	DelayUGens.cpp
	DemandUGens.cpp
	DemoUGens.cpp
	DynNoiseUGens.cpp
	FilterUGens.cpp
	GendynUGens.cpp
	GrainUGens.cpp
	IOUGens.cpp
	LFUGens.cpp
	MulAddUGens.cpp
	NoiseUGens.cpp
	OscUGens.cpp
	PanUGens.cpp
	PhysicalModelingUGens.cpp
	ReverbUGens.cpp
	TestUGens.cpp
	TriggerUGens.cpp
	UnaryOpUGens.cpp
	UnpackFFTUGens.cpp
)

# Map from source file name to PluginLoad() name used in the source code
set(PLUGIN_LOAD_NAMES
	BinaryOpUGens:BinaryOp
	ChaosUGens:Chaos
	DelayUGens:Delay
	DemandUGens:Demand
	DemoUGens:DemoUGens
	DynNoiseUGens:DynNoise
	FilterUGens:Filter
	GendynUGens:Gendyn
	GrainUGens:Grain
	IOUGens:IO
	LFUGens:LF
	MulAddUGens:MulAdd
	NoiseUGens:Noise
	OscUGens:Osc
	PanUGens:Pan
	PhysicalModelingUGens:PhysicalModeling
	ReverbUGens:Reverb
	TestUGens:Test
	TriggerUGens:Trigger
	UnaryOpUGens:UnaryOp
	UnpackFFTUGens:UnpackFFTUGens
)

set(plugins "")
set(supernova_plugins "")

if(SC_IOS)
	# iOS: build plugins as OBJECT libraries, statically linked into libscsynth
	set(sc_ios_static_plugins "")
	set(sc_ios_plugin_load_names "")

	foreach(plugin ${plugin_sources})
		string(REPLACE .cpp "" plugin_name ${plugin})
		add_library(${plugin_name} OBJECT ${plugin})
		target_compile_definitions(${plugin_name} PRIVATE STATIC_PLUGINS)
		target_link_libraries(${plugin_name} PRIVATE Boost::headers)
		if(NOVA_SIMD)
			target_include_directories(${plugin_name} PUBLIC ${CMAKE_SOURCE_DIR}/external_libraries/nova-simd)
			target_compile_definitions(${plugin_name} PUBLIC NOVA_SIMD)
		endif()
		list(APPEND sc_ios_static_plugins ${plugin_name})

		# Find the load name for this plugin
		foreach(mapping ${PLUGIN_LOAD_NAMES})
			string(REPLACE ":" ";" mapping_list ${mapping})
			list(GET mapping_list 0 map_source)
			list(GET mapping_list 1 map_load_name)
			if(map_source STREQUAL plugin_name)
				list(APPEND sc_ios_plugin_load_names ${map_load_name})
			endif()
		endforeach()
	endforeach()

	# FFT plugins as OBJECT libraries
	add_library(FFT_UGens OBJECT
		FFTInterfaceTable.cpp FFT_UGens.cpp PV_UGens.cpp PartitionedConvolution.cpp
		${scplugin_common_sources}
	)
	target_compile_definitions(FFT_UGens PRIVATE STATIC_PLUGINS)
	target_link_libraries(FFT_UGens PRIVATE ${PTHREADS_LIBRARY} ${MATH_LIBRARY} Boost::headers)
	if(APPLE)
		target_link_libraries(FFT_UGens PRIVATE "-framework Accelerate")
	endif()
	if(NOVA_SIMD)
		target_include_directories(FFT_UGens PUBLIC ${CMAKE_SOURCE_DIR}/external_libraries/nova-simd)
		target_compile_definitions(FFT_UGens PUBLIC NOVA_SIMD)
	endif()
	list(APPEND sc_ios_static_plugins FFT_UGens)
	list(APPEND sc_ios_plugin_load_names FFT_UGens)

	add_library(PV_ThirdParty OBJECT
		Convolution.cpp FFT2InterfaceTable.cpp FeatureDetection.cpp PV_ThirdParty.cpp
		${scplugin_common_sources}
	)
	target_compile_definitions(PV_ThirdParty PRIVATE STATIC_PLUGINS)
	target_link_libraries(PV_ThirdParty PRIVATE ${PTHREADS_LIBRARY} ${MATH_LIBRARY} Boost::headers)
	if(APPLE)
		target_link_libraries(PV_ThirdParty PRIVATE "-framework Accelerate")
	endif()
	if(NOVA_SIMD)
		target_include_directories(PV_ThirdParty PUBLIC ${CMAKE_SOURCE_DIR}/external_libraries/nova-simd)
		target_compile_definitions(PV_ThirdParty PUBLIC NOVA_SIMD)
	endif()
	list(APPEND sc_ios_static_plugins PV_ThirdParty)
	list(APPEND sc_ios_plugin_load_names PV_ThirdParty)

	add_library(ML_UGens OBJECT
		ML.cpp Loudness.cpp BeatTrack.cpp Onsets.cpp onsetsds.c
		KeyTrack.cpp MFCC.cpp BeatTrack2.cpp ML_SpecStats.cpp
		${scplugin_common_sources}
	)
	target_compile_definitions(ML_UGens PRIVATE STATIC_PLUGINS)
	target_link_libraries(ML_UGens PRIVATE ${PTHREADS_LIBRARY} ${MATH_LIBRARY} Boost::headers)
	if(APPLE)
		target_link_libraries(ML_UGens PRIVATE "-framework Accelerate")
	endif()
	if(NOVA_SIMD)
		target_include_directories(ML_UGens PUBLIC ${CMAKE_SOURCE_DIR}/external_libraries/nova-simd)
		target_compile_definitions(ML_UGens PUBLIC NOVA_SIMD)
	endif()
	list(APPEND sc_ios_static_plugins ML_UGens)
	list(APPEND sc_ios_plugin_load_names ML_UGens)

	# UIUGens for iOS: MouseX/Y/Button via touch, KeyState stub
	add_library(UIUGens_iOS OBJECT UIUGens_iOS.cpp)
	target_compile_definitions(UIUGens_iOS PRIVATE STATIC_PLUGINS)
	list(APPEND sc_ios_static_plugins UIUGens_iOS)
	list(APPEND sc_ios_plugin_load_names UIUGens)

	# DiskIO if sndfile available
	if(NOT NO_LIBSNDFILE AND SNDFILE_FOUND)
		add_library(DiskIO_UGens OBJECT DiskIO_UGens.cpp)
		target_compile_definitions(DiskIO_UGens PRIVATE STATIC_PLUGINS)
		target_link_libraries(DiskIO_UGens PRIVATE Boost::headers)
		target_include_directories(DiskIO_UGens PUBLIC ${SNDFILE_INCLUDE_DIR})
		if(NOVA_SIMD)
			target_include_directories(DiskIO_UGens PUBLIC ${CMAKE_SOURCE_DIR}/external_libraries/nova-simd)
			target_compile_definitions(DiskIO_UGens PUBLIC NOVA_SIMD)
		endif()
		list(APPEND sc_ios_static_plugins DiskIO_UGens)
		list(APPEND sc_ios_plugin_load_names DiskIO)
	endif()

	# Generate static plugin registry
	set(SC_STATIC_PLUGIN_DECLARATIONS "")
	set(SC_STATIC_PLUGIN_CALLS "")
	foreach(load_name ${sc_ios_plugin_load_names})
		string(APPEND SC_STATIC_PLUGIN_DECLARATIONS "extern void ${load_name}_Load(InterfaceTable* inTable);\n")
		string(APPEND SC_STATIC_PLUGIN_CALLS "    ${load_name}_Load(inTable);\n")
	endforeach()

	configure_file(
		${CMAKE_SOURCE_DIR}/server/scsynth/SC_StaticPluginRegistry.cpp.in
		${CMAKE_BINARY_DIR}/server/scsynth/SC_StaticPluginRegistry.cpp
		@ONLY
	)

	# Export for libscsynth to link
	set(SC_IOS_STATIC_PLUGIN_OBJECTS ${sc_ios_static_plugins} PARENT_SCOPE)
	set(SC_IOS_STATIC_PLUGIN_REGISTRY ${CMAKE_BINARY_DIR}/server/scsynth/SC_StaticPluginRegistry.cpp PARENT_SCOPE)

	message(STATUS "iOS static plugins: ${sc_ios_plugin_load_names}")
	return() # Skip all desktop plugin logic below
endif() # SC_IOS

set(CMAKE_SHARED_MODULE_PREFIX "")
set(CMAKE_SHARED_MODULE_SUFFIX ".scx")

foreach(plugin ${plugin_sources})
	string(REPLACE .cpp "" plugin_name ${plugin} )
	add_library(${plugin_name} MODULE ${plugin})
	target_link_libraries(${plugin_name} PRIVATE Boost::headers)
	list(APPEND plugins ${plugin_name})
endforeach(plugin)

if(AUDIOAPI STREQUAL bela)
    # The Bela lib will have its own set of libraries and includes
    # However, the Bela audio backend for SC has some direct calls to Xenomai
    # Therefore we need to get flags for those as well
    find_package(Xenomai REQUIRED)
    find_package(Bela REQUIRED)
    message(STATUS "Found Bela libraries: ${BELA_LIBRARIES}")
    if(CMAKE_CXX_COMPILER_ID MATCHES "GNU|Clang")
        # recommended compile flags for beaglebone etc; set here because bela api flag directly implies the architecture
        set(CMAKE_C_FLAGS "${CMAKE_C_FLAGS} ${BELA_C_FLAGS}")
        set(CMAKE_CXX_FLAGS "${CMAKE_CXX_FLAGS} ${BELA_CXX_FLAGS}")
    endif()
endif()

if(BELA_FOUND)
    add_library(BelaUGens MODULE
        BelaUGens.cpp
    )
    add_definitions("-DSC_BELA" ${XENOMAI_DEFINITIONS} ${BELA_DEFINITIONS})
    include_directories(${XENOMAI_INCLUDE_DIRS} ${BELA_INCLUDE_DIRS})
    target_link_libraries(BelaUGens PRIVATE ${XENOMAI_LIBRARIES} ${BELA_LIBRARIES})

    list(APPEND plugins BelaUGens)
endif()

if(NOT NO_X11)
	if (APPLE)
		add_library(UIUGens MODULE UIUGens.mm)
	else()
		add_library(UIUGens MODULE UIUGens.cpp)
		target_link_libraries(UIUGens PRIVATE ${PTHREADS_LIBRARY})
	endif()

	set(uiugens UIUGens)

	list(APPEND plugins UIUGens)
endif()

add_library(FFT_UGens MODULE
	FFTInterfaceTable.cpp
	FFT_UGens.cpp
	PV_UGens.cpp
	PartitionedConvolution.cpp
	${scplugin_common_sources}
)

add_library(PV_ThirdParty MODULE
	Convolution.cpp
	FFT2InterfaceTable.cpp
	FeatureDetection.cpp
	PV_ThirdParty.cpp
	${scplugin_common_sources}
)

add_library(ML_UGens MODULE
	ML.cpp
	Loudness.cpp
	BeatTrack.cpp
	Onsets.cpp
	onsetsds.c
	KeyTrack.cpp
	MFCC.cpp
	BeatTrack2.cpp
	ML_SpecStats.cpp
	BeatTrack.h
	BeatTrack2.h
	ML.h
	Onsets.h
	onsetsds.h
	${scplugin_common_sources}
)

if(SC_ABLETON_LINK)
	add_library(Link_UGen MODULE
		LinkUGen.cpp
	)
	# bug-fix for undefined reference to `GetAdaptersAddresses'
	if (MINGW)
		target_link_libraries(Link_UGen PRIVATE iphlpapi)
	endif()
	include(../../external_libraries/link/AbletonLinkConfig.cmake)
	target_link_libraries(Link_UGen PRIVATE Ableton::Link)
	list(APPEND plugins Link_UGen)
endif()

if(NOT NO_LIBSNDFILE)
	set(diskio_sources DiskIO_UGens.cpp)

	if (XENOMAI_FOUND)
		list(APPEND diskio_sources ../../common/XenomaiLock.cpp)
	endif()
	add_library(DiskIO_UGens MODULE ${diskio_sources})

	if(SNDFILE_FOUND)
		if(SNDFILE_HAS_VORBIS)
			target_compile_definitions(DiskIO_UGens PUBLIC SNDFILE_HAS_VORBIS)
		endif()
		if(SNDFILE_HAS_OPUS)
			target_compile_definitions(DiskIO_UGens PUBLIC SNDFILE_HAS_OPUS)
		endif()
		if(SNDFILE_HAS_MPEG)
			target_compile_definitions(DiskIO_UGens PUBLIC SNDFILE_HAS_MPEG)
		endif()
		target_include_directories(DiskIO_UGens PUBLIC ${SNDFILE_INCLUDE_DIR})
		target_link_libraries(DiskIO_UGens PRIVATE ${PTHREADS_LIBRARY} ${SNDFILE_LIBRARIES})
		list(APPEND plugins DiskIO_UGens)
	else()
		message(SEND_ERROR "Cannot find libsndfile")
	endif(SNDFILE_FOUND)
endif()

set(fft_ugens FFT_UGens PV_ThirdParty ML_UGens)
list(APPEND plugins FFT_UGens PV_ThirdParty ML_UGens)

if (FFTW3F_FOUND)
	include_directories (${FFTW3F_INCLUDE_DIR})
endif()

if (SUPERNOVA)
	foreach(plugin ${plugin_sources})
		string(REPLACE .cpp "_supernova" plugin_name ${plugin} )
		add_library(${plugin_name} MODULE ${plugin})
		target_link_libraries(${plugin_name} PRIVATE Boost::headers)
		list(APPEND supernova_plugins ${plugin_name})
	endforeach(plugin)

	add_library(FFT_UGens_supernova MODULE
		FFTInterfaceTable.cpp
		FFT_UGens.cpp
		PV_UGens.cpp
		PartitionedConvolution.cpp
		${scplugin_common_sources}
	)

	add_library(PV_ThirdParty_supernova MODULE
		Convolution.cpp
		FFT2InterfaceTable.cpp
		FeatureDetection.cpp
		PV_ThirdParty.cpp
		${scplugin_common_sources}
	)

	add_library(ML_UGens_supernova MODULE
		ML.cpp
		Loudness.cpp
		BeatTrack.cpp
		Onsets.cpp
		onsetsds.c
		KeyTrack.cpp
		MFCC.cpp
		BeatTrack2.cpp
		ML_SpecStats.cpp
		${scplugin_common_sources}
	)

	list(APPEND fft_ugens FFT_UGens_supernova PV_ThirdParty_supernova ML_UGens_supernova)
	list(APPEND supernova_plugins FFT_UGens_supernova PV_ThirdParty_supernova ML_UGens_supernova)

	if(NOT NO_X11)
		list(APPEND supernova_plugins UIUGens_supernova)

		if (APPLE)
			add_library(UIUGens_supernova MODULE UIUGens.mm)
		else()
			add_library(UIUGens_supernova MODULE UIUGens.cpp)
			target_link_libraries(UIUGens_supernova PRIVATE ${PTHREADS_LIBRARY})
		endif()
		list(APPEND uiugens UIUGens_supernova)
	endif()

	if(NOT NO_LIBSNDFILE)
		add_library(DiskIO_UGens_supernova MODULE DiskIO_UGens.cpp)

		if(SNDFILE_FOUND)
			target_include_directories(DiskIO_UGens_supernova PUBLIC ${SNDFILE_INCLUDE_DIR})
      target_link_libraries(DiskIO_UGens_supernova PRIVATE ${SNDFILE_LIBRARIES} ${PTHREADS_LIBRARY} ${MATH_LIBRARY} Boost::thread)
			list(APPEND supernova_plugins DiskIO_UGens_supernova)
		else()
			message(SEND_ERROR "Cannot find libsndfile")
		endif(SNDFILE_FOUND)
	endif()
endif(SUPERNOVA)

foreach(ugen ${fft_ugens})
	target_link_libraries(${ugen} PRIVATE ${PTHREADS_LIBRARY} ${MATH_LIBRARY})

	if(APPLE)
		target_link_libraries(${ugen} PRIVATE "-framework Accelerate")
	endif()
endforeach()

if(NOT NO_X11)
	foreach(ugen ${uiugens})
    target_link_libraries(${ugen} PRIVATE Boost::thread)
	endforeach()
endif()

foreach(plugin ${plugins})
	target_link_libraries(${plugin} PRIVATE Boost::headers)
	if(WIN32)
		target_link_libraries(${plugin} PRIVATE wsock32 ws2_32)
	endif()
endforeach()


if(NOVA_SIMD)
	foreach(plugin ${plugins} ${supernova_plugins})
		target_include_directories(${plugin} PUBLIC ${CMAKE_SOURCE_DIR}/external_libraries/nova-simd)
		target_compile_definitions(${plugin} PUBLIC NOVA_SIMD)
	endforeach()
endif()

foreach(plugin ${supernova_plugins})
	target_compile_definitions(${plugin} PUBLIC SUPERNOVA)

	if (WIN32)
		target_link_libraries(${plugin} PRIVATE ws2_32)
	endif()
endforeach()

if(NOT NO_X11)
	if (LINUX_OR_BSD)
		find_package(X11 REQUIRED)

		if (NOT X11_Xt_FOUND)
			message(FATAL_ERROR "libxt not found")
		endif()

		include_directories(${X11_Xt_INCLUDE_PATH})

		foreach (ugen ${uiugens})
			target_link_libraries(${ugen} PRIVATE ${X11_X11_LIB})
		endforeach()
	elseif (APPLE)
		foreach (ugen ${uiugens})
			target_link_libraries(${ugen} PRIVATE "-framework CoreServices -framework AppKit")
		endforeach()
	endif()
endif()

if (APPLE)
	if(NOT NO_LIBSNDFILE)
		target_link_libraries(DiskIO_UGens PRIVATE "-framework CoreServices")
	endif()
endif()

if (WIN32)
	foreach(plugin ${plugins} ${supernova_plugins})
		add_custom_command(TARGET ${plugin}
			POST_BUILD
			COMMAND ${CMAKE_COMMAND} -E make_directory $<TARGET_FILE_DIR:scsynth>/plugins
			COMMAND ${CMAKE_COMMAND} -E copy_if_different $<TARGET_FILE:${plugin}> $<TARGET_FILE_DIR:scsynth>/plugins
			COMMAND ${CMAKE_COMMAND} -E make_directory $<TARGET_FILE_DIR:sclang>/plugins
			COMMAND ${CMAKE_COMMAND} -E copy_if_different $<TARGET_FILE:${plugin}> $<TARGET_FILE_DIR:sclang>/plugins
		)
	endforeach()

	if(SC_IDE)
		foreach(plugin ${plugins} ${supernova_plugins})
			add_custom_command(TARGET ${plugin}
				POST_BUILD
				COMMAND ${CMAKE_COMMAND} -E make_directory $<TARGET_FILE_DIR:SuperCollider>/plugins
				COMMAND ${CMAKE_COMMAND} -E copy_if_different $<TARGET_FILE:${plugin}> $<TARGET_FILE_DIR:SuperCollider>/plugins
			)
		endforeach()
	endif(SC_IDE)

	if(SUPERNOVA)
		foreach(plugin ${supernova_plugins})
			add_custom_command(TARGET ${plugin}
				POST_BUILD
				COMMAND ${CMAKE_COMMAND} -E make_directory $<TARGET_FILE_DIR:supernova>/plugins
				COMMAND ${CMAKE_COMMAND} -E copy_if_different $<TARGET_FILE:${plugin}> $<TARGET_FILE_DIR:supernova>/plugins
			)
		endforeach()
	endif(SUPERNOVA)

	install(TARGETS ${plugins} ${supernova_plugins}
		PERMISSIONS OWNER_READ OWNER_WRITE OWNER_EXECUTE GROUP_READ GROUP_EXECUTE WORLD_READ WORLD_EXECUTE
		DESTINATION "${SC_WIN_BUNDLE_NAME}/plugins"
	)

elseif(APPLE)
	if(scappauxresourcesdir)
		foreach(plugin ${plugins} ${supernova_plugins})
			add_custom_command(TARGET ${plugin} POST_BUILD
				COMMAND ${CMAKE_COMMAND} -E make_directory ${CMAKE_INSTALL_PREFIX}/${scappauxresourcesdir}/plugins
				COMMAND ${CMAKE_COMMAND} -E copy_if_different $<TARGET_FILE:${plugin}> ${CMAKE_INSTALL_PREFIX}/${scappauxresourcesdir}/plugins)
		endforeach()
	endif()

else()
	install(TARGETS ${plugins} ${supernova_plugins}
			DESTINATION "lib${LIB_SUFFIX}/SuperCollider/plugins"
			PERMISSIONS OWNER_READ OWNER_WRITE OWNER_EXECUTE GROUP_READ GROUP_EXECUTE WORLD_READ WORLD_EXECUTE)
endif()

set_property(TARGET ${plugins} ${supernova_plugins} PROPERTY FOLDER UnitGenerators)

set(plugins "${plugins}" PARENT_SCOPE)
set(supernova_plugins "${supernova_plugins}" PARENT_SCOPE)
