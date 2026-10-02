#include "globeitem.h"
#include "globerenderer.h"
#include <QtMath>
#include <QDateTime>
#include <QTimer>

GlobeItem::GlobeItem(QQuickItem *parent)
    : QQuickFramebufferObject(parent)
{
    setFlag(ItemHasContents, true);
    m_oceanColor = QColor(15, 20, 35, 180); // semi-transparent ocean
    m_nightColor = QColor(0, 0, 0, 115); // ~0.45 alpha
    m_coastColor = QColor(80, 140, 200);
    m_borderColor = QColor(80, 140, 200, 89); // ~0.35 alpha
    m_ringColor = QColor(80, 140, 200, 102);  // ~0.4 alpha
    updateSunPosition();

    // Refresh timer to keep FBO alive and sun position current
    QTimer *refreshTimer = new QTimer(this);
    connect(refreshTimer, &QTimer::timeout, this, [this]() {
        updateSunPosition();
        update();
    });
    refreshTimer->start(60000);
}

QQuickFramebufferObject::Renderer *GlobeItem::createRenderer() const
{
    return new GlobeRenderer();
}

double GlobeItem::radius() const
{
    return qMin(width(), height()) / 2.0 - 4.0; // GLOBE_MARGIN = 4
}

void GlobeItem::setCenterLatitude(double lat)
{
    lat = qBound(-90.0, lat, 90.0);
    if (qFuzzyCompare(m_centerLat, lat)) return;
    m_centerLat = lat;
    emit centerLatitudeChanged();
    update();
}

void GlobeItem::setCenterLongitude(double lon)
{
    while (lon > 180) lon -= 360;
    while (lon < -180) lon += 360;
    if (qFuzzyCompare(m_centerLon, lon)) return;
    m_centerLon = lon;
    emit centerLongitudeChanged();
    update();
}

void GlobeItem::setOceanColor(const QColor &c)
{
    if (m_oceanColor == c) return;
    m_oceanColor = c;
    emit oceanColorChanged();
    update();
}

void GlobeItem::setNightColor(const QColor &c)
{
    if (m_nightColor == c) return;
    m_nightColor = c;
    emit nightColorChanged();
    update();
}

void GlobeItem::setCoastColor(const QColor &c)
{
    if (m_coastColor == c) return;
    m_coastColor = c;
    emit coastColorChanged();
    update();
}

void GlobeItem::setBorderColor(const QColor &c)
{
    if (m_borderColor == c) return;
    m_borderColor = c;
    emit borderColorChanged();
    update();
}

void GlobeItem::setRingColor(const QColor &c)
{
    if (m_ringColor == c) return;
    m_ringColor = c;
    emit ringColorChanged();
    update();
}

void GlobeItem::geometryChanged(const QRectF &newGeom, const QRectF &oldGeom)
{
    QQuickFramebufferObject::geometryChanged(newGeom, oldGeom);
    emit radiusChanged();
    update();
}

void GlobeItem::updateSunPosition()
{
    // NOAA subsolar point approximation
    QDateTime now = QDateTime::currentDateTimeUtc();
    QDate date = now.date();
    QTime time = now.time();
    int dayOfYear = date.dayOfYear();
    double hour = time.hour() + time.minute() / 60.0 + time.second() / 3600.0;

    // Solar declination
    double gamma = 2.0 * M_PI / 365.0 * (dayOfYear - 1);
    double decl = 0.006918 - 0.399912 * cos(gamma) + 0.070257 * sin(gamma)
                - 0.006758 * cos(2 * gamma) + 0.000907 * sin(2 * gamma)
                - 0.002697 * cos(3 * gamma) + 0.00148 * sin(3 * gamma);

    // Equation of time (minutes)
    double eqTime = 229.18 * (0.000075 + 0.001868 * cos(gamma) - 0.032077 * sin(gamma)
                   - 0.014615 * cos(2 * gamma) - 0.04089 * sin(2 * gamma));

    double newLon = -((hour - 12.0) * 15.0 + eqTime / 4.0);
    while (newLon > 180) newLon -= 360;
    while (newLon < -180) newLon += 360;

    double newLat = decl * 180.0 / M_PI;

    if (!qFuzzyCompare(m_sunLat, newLat) || !qFuzzyCompare(m_sunLon, newLon)) {
        m_sunLat = newLat;
        m_sunLon = newLon;
        emit sunChanged();
        update();
    }

    // Refresh sun position every 60 seconds
    QTimer::singleShot(60000, this, &GlobeItem::updateSunPosition);
}