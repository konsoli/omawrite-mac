QT += core gui widgets printsupport qml quick quickcontrols2 quickdialogs2

CONFIG += c++17 release app_bundle
TARGET = omawrite
TEMPLATE = app

ICON = macos/omawrite.icns
QMAKE_TARGET_BUNDLE_PREFIX = io.omacom
QMAKE_INFO_PLIST = macos/Info.plist.in

HEADERS += \
    src/backend.h \
    src/markdownhighlighter.h \
    src/systemtheme.h

SOURCES += \
    src/main.cpp \
    src/backend.cpp \
    src/markdownhighlighter.cpp \
    src/systemtheme.cpp

RESOURCES += src/resources.qrc
