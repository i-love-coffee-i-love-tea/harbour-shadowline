#pragma once

#include <QQuickFramebufferObject>
#include <QOpenGLShaderProgram>
#include <QOpenGLFunctions>
#include <QOpenGLBuffer>

class GlobeItem;

class GlobeRenderer : public QQuickFramebufferObject::Renderer, protected QOpenGLFunctions {
public:
    GlobeRenderer();
    ~GlobeRenderer();

    void render() override;
    QOpenGLFramebufferObject *createFramebufferObject(const QSize &size) override;
    void synchronize(QQuickFramebufferObject *item) override;

private:
    void initShaders();
    void initBuffers();
    void initGeomData();
    void drawOcean();
    void drawNight();
    void drawLines(QOpenGLBuffer &vbo, int *offsets, int segCount,
                   const QColor &color, float lineWidth);
    void drawRing();

    QOpenGLShaderProgram *m_oceanProg = nullptr;
    QOpenGLShaderProgram *m_nightProg = nullptr;
    QOpenGLShaderProgram *m_lineProg = nullptr;
    QOpenGLShaderProgram *m_ringProg = nullptr;

    QOpenGLBuffer m_coastVbo;
    QOpenGLBuffer m_borderVbo;
    QOpenGLBuffer m_quadVbo;     // for ocean/night fullscreen quad
    QOpenGLBuffer m_ringVbo;

    int *m_coastOffsets = nullptr;
    int m_coastSegCount = 0;
    int *m_borderOffsets = nullptr;
    int m_borderSegCount = 0;
    int m_ringVertexCount = 0;

    bool m_shadersReady = false;
    bool m_geomReady = false;

    // Synced from GlobeItem
    double m_cLat = 25.0;
    double m_cLon = 30.0;
    double m_R = 100.0;
    float m_fboW = 1.0f;
    float m_fboH = 1.0f;
    QColor m_oceanColor;
    QColor m_nightColor;
    QColor m_coastColor;
    QColor m_borderColor;
    QColor m_ringColor;
    double m_sunLat = 0.0;
    double m_sunLon = 0.0;
};