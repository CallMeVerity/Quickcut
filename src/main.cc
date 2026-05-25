#include <QGuiApplication>
#include <QQmlApplicationEngine>
#include <QQuickStyle>
#include <QProcess>
#include <QtQml>

#include "dir_lister.h"
#include "video_processor.h"

int main(int argc, char *argv[]) {
    qputenv("QT_LOGGING_RULES",
            "qt.multimedia*=false;"
            "qt.qpa*=false;"
            "qt.imageformats*=false");
    qputenv("LIBVA_MESSAGING_LEVEL", "0");
    qputenv("VDPAU_LOG", "0");

    QGuiApplication app(argc, argv);
    app.setApplicationName("QuickCut");
    app.setApplicationDisplayName("QuickCut");
    app.setOrganizationName("Nathan");

    if (QProcess::execute("ffmpeg", {"-version"}) != 0) {
        fprintf(stderr, "QuickCut requires ffmpeg. Install it with your package manager.\n");
        return 1;
    }

    QQuickStyle::setStyle("Basic");

    qmlRegisterType<VideoProcessor>("QuickCut", 1, 0, "VideoProcessor");
    qmlRegisterType<DirLister>("QuickCut", 1, 0, "DirLister");

    QQmlApplicationEngine engine;
    engine.loadFromModule("QuickCut", "Main");

    if (engine.rootObjects().isEmpty())
        return -1;

    return app.exec();
}