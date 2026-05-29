cmake_minimum_required(VERSION 3.21)
project(ezcut VERSION 0.1.3 LANGUAGES CXX)

set(PROJECT_DESCRIPTION "Lightweight video cutter powered by ffmpeg")
set(PROJECT_AUTHOR "E-Z")
set(PROJECT_LICENSE "MIT")

set(CMAKE_CXX_STANDARD 20)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_AUTOMOC ON)
set(CMAKE_EXPORT_COMPILE_COMMANDS ON)

find_package(Qt6 REQUIRED COMPONENTS Quick QuickControls2 Multimedia)

qt_policy(SET QTP0001 NEW)
qt_policy(SET QTP0004 NEW)

qt_add_executable(ezcut
    src/main.cc
    src/dir_lister.cc
    src/video_processor.cc
)

qt_add_qml_module(ezcut
    URI ezcut
    VERSION 1.0
    OUTPUT_DIRECTORY ${CMAKE_CURRENT_BINARY_DIR}/qml/ezcut
    QML_FILES
        Qml/Main.qml
        Qml/Components/Timeline.qml
        Qml/Components/TimeDisplay.qml
        Qml/Components/IconButton.qml
        Qml/Components/FileBrowser.qml
)

qt_add_resources(ezcut "appicon"
    PREFIX "/"
    FILES res/ezcut.png
)

target_link_libraries(ezcut PRIVATE
    Qt6::Quick
    Qt6::QuickControls2
    Qt6::Multimedia
)

install(TARGETS ezcut RUNTIME DESTINATION bin)
install(FILES res/ezcut.desktop DESTINATION share/applications)
install(FILES res/ezcut.metainfo.xml DESTINATION share/metainfo)
install(FILES res/ezcut.png DESTINATION share/pixmaps RENAME ezcut.png)
