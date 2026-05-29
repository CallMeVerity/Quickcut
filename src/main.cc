#include <QGuiApplication>
#include <QQmlApplicationEngine>
#include <QQuickStyle>
#include <QProcess>
#include <QIcon>
#include <QtQml>

#include "dir_lister.h"
#include "video_processor.h"

int main(int argc, char *argv[]) {
    qputenv("QT_LOGGING_RULES",
            "qt.multimedia*=false;"
            "qt.qpa*=false;"
            "qt.imageformats*=false");
    qputenv("QT_MEDIA_BACKEND", "ffmpeg");
    qputenv("LIBVA_MESSAGING_LEVEL", "0");
    qputenv("VDPAU_LOG", "0");

    QGuiApplication app(argc, argv);
    app.setApplicationName("E-Z Cut");
    app.setApplicationDisplayName("E-Z Cut");
    app.setOrganizationName("E-Z");
    app.setWindowIcon(QIcon(":/res/ezcut.png"));

    if (QProcess::execute("ffmpeg", {"-version"}) != 0) {
        fprintf(stderr, "E-Z Cut requires ffmpeg. Install it with your package manager.\n");
        return 1;
    }

    QQuickStyle::setStyle("Basic");

    qmlRegisterType<VideoProcessor>("ezcut", 1, 0, "VideoProcessor");
    qmlRegisterType<DirLister>("ezcut", 1, 0, "DirLister");

    QQmlApplicationEngine engine;
    engine.loadFromModule("ezcut", "Main");

    if (engine.rootObjects().isEmpty())
        return -1;

    return app.exec();
}