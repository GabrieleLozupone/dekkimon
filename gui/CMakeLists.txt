
set(CMAKE_INCLUDE_CURRENT_DIR ON)
set(CMAKE_AUTOMOC ON)
set(CMAKE_AUTORCC ON)

find_package(Qt6 REQUIRED COMPONENTS Core Gui Concurrent Svg Qml Quick Widgets Network)
if(Qt6_VERSION VERSION_GREATER_EQUAL "6.10.0")
	find_package(Qt6 REQUIRED COMPONENTS GuiPrivate)
endif()

find_package(Qt6 COMPONENTS WebEngineQuick)
find_package(Qt6 COMPONENTS DBus)

set(SOURCE_FILES
	include/exception.h
	src/main.cpp
	include/discoverymanager.h
	src/discoverymanager.cpp
	include/streamsession.h
	src/streamsession.cpp
	include/sessionlog.h
	src/sessionlog.cpp
	include/settings.h
	src/settings.cpp
	include/host.h
	src/host.cpp
	res/resources.qrc
	include/controllermanager.h
	src/controllermanager.cpp
	include/psnaccountid.h
	src/psnaccountid.cpp
	include/psntoken.h
	src/psntoken.cpp
	include/jsonrequester.h
	src/jsonrequester.cpp
	src/qml/qml.qrc
	include/qmlmainwindow.h
	src/qmlmainwindow.cpp
	include/qmlbackend.h
	src/qmlbackend.cpp
	include/qmlcontroller.h
	src/qmlcontroller.cpp
	include/qmlsettings.h
	src/qmlsettings.cpp
	include/qmlsvgprovider.h
	src/qmlsvgprovider.cpp
	include/systemdinhibit.h
	src/systemdinhibit.cpp
	include/streambenchmark.h
	src/streambenchmark.cpp
	include/psnphonelogin.h
	src/psnphonelogin.cpp
	include/wifimonitor.h
	src/wifimonitor.cpp
	include/qrimageprovider.h
	src/qrimageprovider.cpp
	${CMAKE_CURRENT_SOURCE_DIR}/../third-party/qrcodegen/qrcodegen.cpp
	)
if(CHIAKI_ENABLE_STEAMDECK_NATIVE AND LINUX)
	list(APPEND SOURCE_FILES
		include/sdinputcontext.h
		src/sdinputcontext.cpp
	)
endif()

add_executable(chiaki
		${SOURCE_FILES}
)
target_include_directories(chiaki PRIVATE include ${CMAKE_CURRENT_SOURCE_DIR}/../third-party/qrcodegen)

add_library(placebo-libav-impl src/libav_impl.c)
target_link_libraries(placebo-libav-impl PkgConfig::LIBPLACEBO FFMPEG::avcodec FFMPEG::avutil FFMPEG::avformat)
# Portal-style particle globe (gui/src/qml/shaders). Optional: without Qt ShaderTools the
# QML falls back to a static globe.
find_package(Qt6 COMPONENTS ShaderTools)
if(Qt6ShaderTools_FOUND)
	qt_add_shaders(chiaki "chiaki_portal_shaders"
		PREFIX "/portal"
		BASE "src/qml/shaders"
		FILES "src/qml/shaders/portalglobe.frag")
else()
	message(STATUS "Qt6 ShaderTools not found: the animated home globe uses its static fallback")
endif()

target_link_libraries(chiaki PkgConfig::LIBPLACEBO placebo-libav-impl)

target_link_libraries(chiaki chiaki-lib)
if(CHIAKI_ENABLE_CLI)
	add_definitions(-DCHIAKI_ENABLE_CLI)
	target_link_libraries(chiaki chiaki-cli-lib)
endif()

target_link_libraries(chiaki Qt::Core Qt::Gui Qt::GuiPrivate Qt::Concurrent Qt::Svg Qt::Qml Qt::Quick Qt::Widgets Qt::Network)
if (${Qt6DBus_FOUND})
	target_link_libraries(chiaki Qt::DBus)
	target_compile_definitions(chiaki PRIVATE CHIAKI_HAVE_DBUS)
endif()
if (${Qt6WebEngineQuick_FOUND})
	target_link_libraries(chiaki Qt::WebEngineQuick)
	target_compile_definitions(chiaki PRIVATE CHIAKI_HAVE_WEBENGINE)
endif()
target_link_libraries(chiaki SDL2::SDL2)
if(CHIAKI_ENABLE_SPEEX)
  target_link_libraries(chiaki PkgConfig::SpeexDSP)
  target_compile_definitions(chiaki PRIVATE CHIAKI_GUI_ENABLE_SPEEX)
endif()
if(CHIAKI_GUI_ENABLE_SDL_GAMECONTROLLER)
	target_compile_definitions(chiaki PRIVATE CHIAKI_GUI_ENABLE_SDL_GAMECONTROLLER)
endif()
if(CHIAKI_ENABLE_SETSU)
	target_link_libraries(chiaki setsu)
	target_compile_definitions(chiaki PRIVATE CHIAKI_GUI_ENABLE_SETSU)
endif()
if(CHIAKI_ENABLE_STEAMDECK_NATIVE)
	target_link_libraries(chiaki sdeck)
	target_compile_definitions(chiaki PRIVATE QT_STATICPLUGIN CHIAKI_GUI_ENABLE_STEAMDECK_NATIVE)
endif()
if(CHIAKI_ENABLE_STEAM_SHORTCUT)
	target_link_libraries(chiaki cpp-steam-tools)
	target_compile_definitions(chiaki PRIVATE CHIAKI_GUI_ENABLE_STEAM_SHORTCUT)
endif()
if(NOT CHIAKI_ENABLE_FFMPEG_DECODER)
	message(FATAL_ERROR "Chiaki GUI requires CHIAKI_ENABLE_FFMPEG_DECODER=ON")
endif()
# Dekkimon: the target keeps its upstream name (chiaki) so merges stay small; only the file is renamed.
set_target_properties(chiaki PROPERTIES OUTPUT_NAME dekkimon)
file(STRINGS "${PROJECT_SOURCE_DIR}/dekkimon.version" DEKKIMON_VERSION LIMIT_COUNT 1)
target_compile_definitions(chiaki PRIVATE DEKKIMON_VERSION="${DEKKIMON_VERSION}")

install(TARGETS chiaki
		RUNTIME DESTINATION bin)
install(FILES dekkimon.desktop DESTINATION share/applications)
install(FILES res/dekkimon-icon.png DESTINATION share/icons/hicolor/512x512/apps RENAME dekkimon.png)

