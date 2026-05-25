cmake_minimum_required(VERSION 3.21)
project(QuickCut VERSION 0.1.0 LANGUAGES CXX)

set(PROJECT_DESCRIPTION "Lightweight video cutter powered by ffmpeg")
set(PROJECT_AUTHOR "Nathan")
set(PROJECT_LICENSE "MIT")

set(CMAKE_CXX_STANDARD 20)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_AUTOMOC ON)
set(CMAKE_EXPORT_COMPILE_COMMANDS ON)

find_package(Qt6 REQUIRED COMPONENTS Quick QuickControls2 Multimedia)

qt_policy(SET QTP0001 NEW)
qt_policy(SET QTP0004 NEW)

qt_add_executable(quickcut
    src/main.cc
    src/dir_lister.cc
    src/video_processor.cc
)

qt_add_qml_module(quickcut
    URI QuickCut
    VERSION 1.0
    QML_FILES
        Qml/Main.qml
        Qml/Components/Timeline.qml
        Qml/Components/TimeDisplay.qml
        Qml/Components/IconButton.qml
        Qml/Components/FileBrowser.qml
)

target_link_libraries(quickcut PRIVATE
    Qt6::Quick
    Qt6::QuickControls2
    Qt6::Multimedia
)

install(TARGETS quickcut RUNTIME DESTINATION bin)
install(FILES res/quickcut.desktop DESTINATION share/applications)
install(FILES res/quickcut.metainfo.xml DESTINATION share/metainfo)
