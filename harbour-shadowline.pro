TARGET = harbour-shadowline

CONFIG += sailfishapp
QT += quick qml positioning

SOURCES += \
    src/main.cpp \
    src/globeitem.cpp

HEADERS += \
    src/globeitem.h \
    src/geomdata.h

OTHER_FILES += \
    qml/harbour-shadowline.qml \
    qml/pages/*.qml \
    qml/components/*.qml \
    qml/cover/*.qml \
    qml/js/*.js
