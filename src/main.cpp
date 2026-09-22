#include <sailfishapp.h>
#include <QGuiApplication>
#include <QQuickView>

int main(int argc, char *argv[])
{
    QScopedPointer<QGuiApplication> app(SailfishApp::application(argc, argv));
    QScopedPointer<QQuickView> view(SailfishApp::createView());
    view->setSource(SailfishApp::pathToMainQml());
    view->showFullScreen();
    return app->exec();
}
