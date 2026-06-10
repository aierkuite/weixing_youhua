TEMPLATE = lib
CONFIG += staticlib
CONFIG -= qt

include(RTKLib.pri)

TARGET = RTKLib

RTKLIB_SRC = $$clean_path($$_PRO_FILE_PWD_/../../src)

CONFIG(debug, debug|release) {
    DESTDIR = $$RTKLIB_SRC/debug
} else {
    DESTDIR = $$RTKLIB_SRC/release
}

INCLUDEPATH += $$RTKLIB_SRC $$RTKLIB_SRC/rcv

SOURCES += \
    $$RTKLIB_SRC/convgpx.c \
    $$RTKLIB_SRC/convkml.c \
    $$RTKLIB_SRC/convrnx.c \
    $$RTKLIB_SRC/datum.c \
    $$RTKLIB_SRC/download.c \
    $$RTKLIB_SRC/ephemeris.c \
    $$RTKLIB_SRC/geoid.c \
    $$RTKLIB_SRC/gis.c \
    $$RTKLIB_SRC/ionex.c \
    $$RTKLIB_SRC/lambda.c \
    $$RTKLIB_SRC/options.c \
    $$RTKLIB_SRC/pntpos.c \
    $$RTKLIB_SRC/postpos.c \
    $$RTKLIB_SRC/ppp.c \
    $$RTKLIB_SRC/ppp_ar.c \
    $$RTKLIB_SRC/preceph.c \
    $$RTKLIB_SRC/rcvraw.c \
    $$RTKLIB_SRC/rinex.c \
    $$RTKLIB_SRC/rtcm.c \
    $$RTKLIB_SRC/rtcm2.c \
    $$RTKLIB_SRC/rtcm3.c \
    $$RTKLIB_SRC/rtcm3e.c \
    $$RTKLIB_SRC/rtkcmn.c \
    $$RTKLIB_SRC/rtkpos.c \
    $$RTKLIB_SRC/rtksvr.c \
    $$RTKLIB_SRC/sbas.c \
    $$RTKLIB_SRC/solution.c \
    $$RTKLIB_SRC/stream.c \
    $$RTKLIB_SRC/streamsvr.c \
    $$RTKLIB_SRC/tides.c \
    $$RTKLIB_SRC/tle.c \
    $$RTKLIB_SRC/rcv/binex.c \
    $$RTKLIB_SRC/rcv/crescent.c \
    $$RTKLIB_SRC/rcv/javad.c \
    $$RTKLIB_SRC/rcv/novatel.c \
    $$RTKLIB_SRC/rcv/nvs.c \
    $$RTKLIB_SRC/rcv/rt17.c \
    $$RTKLIB_SRC/rcv/septentrio.c \
    $$RTKLIB_SRC/rcv/skytraq.c \
    $$RTKLIB_SRC/rcv/ss2.c \
    $$RTKLIB_SRC/rcv/ublox.c

HEADERS += $$RTKLIB_SRC/rtklib.h
