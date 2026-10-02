#pragma once

#include <QQuickFramebufferObject>

class GlobeItem : public QQuickFramebufferObject {
    Q_OBJECT
    Q_PROPERTY(double centerLatitude READ centerLatitude WRITE setCenterLatitude NOTIFY centerLatitudeChanged)
    Q_PROPERTY(double centerLongitude READ centerLongitude WRITE setCenterLongitude NOTIFY centerLongitudeChanged)
    Q_PROPERTY(double radius READ radius NOTIFY radiusChanged)
    Q_PROPERTY(QColor oceanColor READ oceanColor WRITE setOceanColor NOTIFY oceanColorChanged)
    Q_PROPERTY(QColor nightColor READ nightColor WRITE setNightColor NOTIFY nightColorChanged)
    Q_PROPERTY(QColor coastColor READ coastColor WRITE setCoastColor NOTIFY coastColorChanged)
    Q_PROPERTY(QColor borderColor READ borderColor WRITE setBorderColor NOTIFY borderColorChanged)
    Q_PROPERTY(QColor ringColor READ ringColor WRITE setRingColor NOTIFY ringColorChanged)
    Q_PROPERTY(double sunLat READ sunLat NOTIFY sunChanged)
    Q_PROPERTY(double sunLon READ sunLon NOTIFY sunChanged)

public:
    explicit GlobeItem(QQuickItem *parent = nullptr);
    Renderer *createRenderer() const override;

    double centerLatitude() const { return m_centerLat; }
    double centerLongitude() const { return m_centerLon; }
    double radius() const;
    QColor oceanColor() const { return m_oceanColor; }
    QColor nightColor() const { return m_nightColor; }
    QColor coastColor() const { return m_coastColor; }
    QColor borderColor() const { return m_borderColor; }
    QColor ringColor() const { return m_ringColor; }
    double sunLat() const { return m_sunLat; }
    double sunLon() const { return m_sunLon; }

    void setCenterLatitude(double lat);
    void setCenterLongitude(double lon);
    void setOceanColor(const QColor &c);
    void setNightColor(const QColor &c);
    void setCoastColor(const QColor &c);
    void setBorderColor(const QColor &c);
    void setRingColor(const QColor &c);

signals:
    void centerLatitudeChanged();
    void centerLongitudeChanged();
    void radiusChanged();
    void oceanColorChanged();
    void nightColorChanged();
    void coastColorChanged();
    void borderColorChanged();
    void ringColorChanged();
    void sunChanged();

protected:
    void geometryChanged(const QRectF &newGeom, const QRectF &oldGeom) override;

private:
    void updateSunPosition();

    double m_centerLat = 25.0;
    double m_centerLon = 30.0;
    QColor m_oceanColor;
    QColor m_nightColor;
    QColor m_coastColor;
    QColor m_borderColor;
    QColor m_ringColor;
    double m_sunLat = 0.0;
    double m_sunLon = 0.0;
};