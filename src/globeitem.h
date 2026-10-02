#pragma once

#include <QQuickPaintedItem>
#include <QOpenGLShaderProgram>
#include <QOpenGLFunctions>
#include <QOpenGLBuffer>
#include <QOpenGLFramebufferObject>
#include <QOffscreenSurface>
#include <QOpenGLContext>

class GlobeItem : public QQuickPaintedItem, protected QOpenGLFunctions {
    Q_OBJECT
    Q_PROPERTY(double centerLatitude READ centerLatitude WRITE setCenterLatitude NOTIFY centerLatitudeChanged)
    Q_PROPERTY(double centerLongitude READ centerLongitude WRITE setCenterLongitude NOTIFY centerLongitudeChanged)
    Q_PROPERTY(double radius READ radius NOTIFY radiusChanged)
    Q_PROPERTY(QColor oceanColor READ oceanColor WRITE setOceanColor NOTIFY oceanColorChanged)
    Q_PROPERTY(QColor nightColor READ nightColor WRITE setNightColor NOTIFY nightColorChanged)
    Q_PROPERTY(QColor coastColor READ coastColor WRITE setCoastColor NOTIFY coastColorChanged)
    Q_PROPERTY(QColor borderColor READ borderColor WRITE setBorderColor NOTIFY borderColorChanged)
    Q_PROPERTY(QColor ringColor READ ringColor WRITE setRingColor NOTIFY ringColorChanged)
    Q_PROPERTY(QColor sunColor READ sunColor WRITE setSunColor NOTIFY sunColorChanged)
    Q_PROPERTY(double sunLat READ sunLat NOTIFY sunChanged)
    Q_PROPERTY(double sunLon READ sunLon NOTIFY sunChanged)

public:
    explicit GlobeItem(QQuickItem *parent = nullptr);
    ~GlobeItem();
    void paint(QPainter *painter) override;

    double centerLatitude() const { return m_centerLat; }
    double centerLongitude() const { return m_centerLon; }
    double radius() const;
    QColor oceanColor() const { return m_oceanColor; }
    QColor nightColor() const { return m_nightColor; }
    QColor coastColor() const { return m_coastColor; }
    QColor borderColor() const { return m_borderColor; }
    QColor ringColor() const { return m_ringColor; }
    QColor sunColor() const { return m_sunColor; }
    double sunLat() const { return m_sunLat; }
    double sunLon() const { return m_sunLon; }

    void setCenterLatitude(double lat);
    void setCenterLongitude(double lon);
    void setOceanColor(const QColor &c);
    void setNightColor(const QColor &c);
    void setCoastColor(const QColor &c);
    void setBorderColor(const QColor &c);
    void setRingColor(const QColor &c);
    void setSunColor(const QColor &c);

signals:
    void centerLatitudeChanged();
    void centerLongitudeChanged();
    void radiusChanged();
    void oceanColorChanged();
    void nightColorChanged();
    void coastColorChanged();
    void borderColorChanged();
    void ringColorChanged();
    void sunColorChanged();
    void sunChanged();

protected:
    void geometryChanged(const QRectF &newGeom, const QRectF &oldGeom) override;

private:
    void initGl();
    void initShaders();
    void initGeomData();
    void renderGlobe(int w, int h);
    void drawGlobe(int w, int h);
    void drawLines(QOpenGLBuffer &vbo, int *offsets, int segCount,
                   const QColor &color, float lineWidth, int w, int h, bool isHalo = false);
    void drawRing(int w, int h);
    void updateSunPosition();

    QOffscreenSurface *m_surface = nullptr;
    QOpenGLContext *m_glCtx = nullptr;
    QOpenGLFramebufferObject *m_fbo = nullptr;

    QOpenGLShaderProgram *m_globeProg = nullptr;
    QOpenGLShaderProgram *m_lineProg = nullptr;
    QOpenGLShaderProgram *m_ringProg = nullptr;

    QOpenGLBuffer m_coastVbo;
    QOpenGLBuffer m_borderVbo;
    QOpenGLBuffer m_quadVbo;
    QOpenGLBuffer m_ringVbo;

    int *m_coastOffsets = nullptr;
    int m_coastSegCount = 0;
    int *m_borderOffsets = nullptr;
    int m_borderSegCount = 0;
    int m_ringVertexCount = 0;

    bool m_glReady = false;

    double m_centerLat = 25.0;
    double m_centerLon = 30.0;
    QColor m_oceanColor;
    QColor m_nightColor;
    QColor m_coastColor;
    QColor m_borderColor;
    QColor m_ringColor;
    QColor m_sunColor;
    double m_sunLat = 0.0;
    double m_sunLon = 0.0;
};