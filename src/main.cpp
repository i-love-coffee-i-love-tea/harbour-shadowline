#include <sailfishapp.h>
#include <QGuiApplication>
#include <QQuickView>
#include <QQmlContext>
#include <QQmlEngine>
#include <QUrl>
#include <QString>
#include "globeitem.h"

int main(int argc, char *argv[])
{
    QScopedPointer<QGuiApplication> app(SailfishApp::application(argc, argv));

    qmlRegisterType<GlobeItem>("Harbour.Shadowline", 1, 0, "GlobeItem");

    // Parse geo: URL from command-line arguments
    QString geoUrl;
    for (int i = 1; i < argc; i++) {
        QString arg = QString::fromUtf8(argv[i]);
        if (arg.startsWith("geo:")) {
            geoUrl = arg;
            break;
        }
    }

    QScopedPointer<QQuickView> view(SailfishApp::createView());
    view->rootContext()->setContextProperty("launchGeoUrl", geoUrl);
    view->setSource(SailfishApp::pathToMainQml());
    view->showFullScreen();
    return app->exec();
}
