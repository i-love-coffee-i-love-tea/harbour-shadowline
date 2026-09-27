#include <sailfishapp.h>
#include <QGuiApplication>
#include <QQuickView>
#include <QQmlContext>
#include <QUrl>
#include <QString>

int main(int argc, char *argv[])
{
    QScopedPointer<QGuiApplication> app(SailfishApp::application(argc, argv));

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
