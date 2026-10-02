#include "globeitem.h"
#include "geomdata.h"
#include <QtMath>
#include <QDateTime>
#include <QTimer>
#include <QQuickWindow>
#include <QOpenGLFunctions>
#include <QOpenGLFramebufferObject>
#include <QOpenGLBuffer>
#include <QOpenGLShaderProgram>
#include <QScopedPointer>
#include <QScopedArrayPointer>

static void logDebug(const char *fmt, ...) {
    FILE *fp = fopen("/tmp/globe_debug.txt", "a");
    if (!fp) return;
    va_list args;
    va_start(args, fmt);
    vfprintf(fp, fmt, args);
    va_end(args);
    fclose(fp);
}
static const double DEG2RAD = M_PI / 180.0;
static const double RAD2DEG = 180.0 / M_PI;

// --- Shader sources (GLES 2.0 / GLSL 100) ---

static const char *GLOBE_VERT =
    "#ifdef GL_ES\n"
    "precision mediump float;\n"
    "#endif\n"
    "attribute vec2 a_pos;\n"
    "varying vec2 v_pos;\n"
    "void main() {\n"
    "    v_pos = a_pos;\n"
    "    gl_Position = vec4(a_pos, 0.0, 1.0);\n"
    "}\n";

static const char *GLOBE_FRAG =
    "#ifdef GL_ES\n"
    "precision mediump float;\n"
    "#endif\n"
    "varying vec2 v_pos;\n"
    "uniform vec2 u_normR;\n"
    "uniform vec2 u_fboHalf;\n"
    "uniform float u_dpr;\n"
    "uniform float u_cLatR;\n"
    "uniform float u_cLonR;\n"
    "uniform float u_sunLatR;\n"
    "uniform float u_sunLonR;\n"
    "uniform vec4 u_oceanColor;\n"
    "uniform vec4 u_nightColor;\n"
    "uniform vec4 u_sunColor;\n"
    "void main() {\n"
    "    vec2 posPix = v_pos * u_fboHalf;\n"
    "    float rPix = length(posPix);\n"
    "    float actualRPix = u_normR.x * u_fboHalf.x;\n"
    "    float dr = rPix - actualRPix;\n"
    "    float maxDr = 8.0 * u_dpr;\n"
    "    if (dr > maxDr) discard;\n"
    "\n"
    "    float sinCLat = sin(u_cLatR), cosCLat = cos(u_cLatR);\n"
    "    float sinSLat = sin(u_sunLatR), cosSLat = cos(u_sunLatR);\n"
    "    float dLonSun = u_sunLonR - u_cLonR;\n"
    "    vec2 sunDir = vec2(cosSLat * sin(dLonSun), cosCLat * sinSLat - sinCLat * cosSLat * cos(dLonSun));\n"
    "    float sunDirLen = length(sunDir);\n"
    "    float cosLimb = (sunDirLen > 0.001 && rPix > 0.001) ? dot(posPix / rPix, sunDir / sunDirLen) : 0.0;\n"
    "    float sunScatter = smoothstep(-0.14, 0.28, cosLimb);\n"
    "    sunScatter = sunScatter * sunScatter * (3.0 - 2.0 * sunScatter);\n"
    "    float limbIntensity = mix(0.18, 1.0, sunScatter);\n"
    "\n"
    "    vec3 sc = u_sunColor.rgb;\n"
    "    vec3 coronaCol = mix(sc, vec3(1.0), 0.20 * sunScatter);\n"
    "\n"
    "    if (dr > 0.0) {\n"
    "        float glow = exp(-dr / (2.8 * u_dpr)) * (1.0 - dr / maxDr);\n"
    "        float coronaAlpha = glow * limbIntensity * 0.55 * u_sunColor.a;\n"
    "        gl_FragColor = vec4(coronaCol, coronaAlpha);\n"
    "        return;\n"
    "    }\n"
    "\n"
    "    float edgeAlpha = clamp(-dr / max(0.001, u_dpr), 0.0, 1.0);\n"
    "    float xn = v_pos.x / u_normR.x;\n"
    "    float yn = v_pos.y / u_normR.y;\n"
    "    float z = sqrt(max(0.0, 1.0 - xn * xn - yn * yn));\n"
    "\n"
    "    float sinLat = yn * cosCLat + z * sinCLat;\n"
    "    float cosLat = sqrt(max(0.0, 1.0 - sinLat * sinLat));\n"
    "    float lon = u_cLonR + atan(xn, z * cosCLat - yn * sinCLat);\n"
    "    float cosA = sinSLat * sinLat + cosSLat * cosLat * cos(lon - u_sunLonR);\n"
    "\n"
    "    vec3 dayOcean = u_oceanColor.rgb;\n"
    "    vec3 nightOcean = mix(dayOcean, u_nightColor.rgb, u_nightColor.a);\n"
    "    float dayT = smoothstep(-0.12, 0.08, cosA);\n"
    "    vec3 col = mix(nightOcean, dayOcean, dayT);\n"
    "\n"
    "    float rim = 1.0 - z;\n"
    "    float limbIn = pow(rim, 3.0) * 0.32 * limbIntensity;\n"
    "    col = clamp(col + sc * limbIn, 0.0, 1.0);\n"
    "\n"
    "    gl_FragColor = vec4(col, edgeAlpha * u_oceanColor.a);\n"
    "}\n";

static const char *LINE_VERT =
    "#ifdef GL_ES\n"
    "precision mediump float;\n"
    "#endif\n"
    "attribute vec2 a_geo;\n"
    "uniform float u_cLatR;\n"
    "uniform float u_cLonR;\n"
    "uniform float u_R;\n"
    "uniform vec2 u_itemHalf;\n"
    "uniform vec2 u_offset;\n"
    "varying float v_z;\n"
    "void main() {\n"
    "    float lat = a_geo.y, lon = a_geo.x;\n"
    "    float dLon = lon - u_cLonR;\n"
    "    float cosCLat = cos(u_cLatR), sinCLat = sin(u_cLatR);\n"
    "    float cosLat = cos(lat), sinLat = sin(lat);\n"
    "    float x = u_R * cosLat * sin(dLon);\n"
    "    float y = u_R * (cosCLat * sinLat - sinCLat * cosLat * cos(dLon));\n"
    "    float z = sinCLat * sinLat + cosCLat * cosLat * cos(dLon);\n"
    "    v_z = z;\n"
    "    gl_Position = vec4(\n"
    "        (x + u_offset.x) / u_itemHalf.x,\n"
    "        (y + u_offset.y) / u_itemHalf.y,\n"
    "        0.0, 1.0\n"
    "    );\n"
    "}\n";

static const char *LINE_FRAG =
    "#ifdef GL_ES\n"
    "precision mediump float;\n"
    "#endif\n"
    "uniform vec4 u_color;\n"
    "varying float v_z;\n"
    "void main() {\n"
    "    if (v_z < 0.0) discard;\n"
    "    gl_FragColor = u_color;\n"
    "}\n";

static const char *RING_VERT =
    "#ifdef GL_ES\n"
    "precision mediump float;\n"
    "#endif\n"
    "attribute vec2 a_pos;\n"
    "varying vec2 v_pos;\n"
    "void main() {\n"
    "    v_pos = a_pos;\n"
    "    gl_Position = vec4(a_pos, 0.0, 1.0);\n"
    "}\n";

static const char *RING_FRAG =
    "#ifdef GL_ES\n"
    "precision mediump float;\n"
    "#endif\n"
    "varying vec2 v_pos;\n"
    "uniform vec2 u_normR;\n"
    "uniform vec2 u_fboHalf;\n"
    "uniform float u_dpr;\n"
    "uniform vec4 u_color;\n"
    "void main() {\n"
    "    vec2 posPix = v_pos * u_fboHalf;\n"
    "    float rPix = length(posPix);\n"
    "    float actualRPix = u_normR.x * u_fboHalf.x;\n"
    "    float dr = abs(rPix - actualRPix);\n"
    "    float maxDr = 1.2 * u_dpr;\n"
    "    if (dr > maxDr) discard;\n"
    "    float a = (1.0 - dr / maxDr) * u_color.a;\n"
    "    gl_FragColor = vec4(u_color.rgb, a);\n"
    "}\n";

class GlobeRenderer : public QQuickFramebufferObject::Renderer, protected QOpenGLFunctions {
public:
    GlobeRenderer() = default;
    ~GlobeRenderer() override;

    void render() override;
    QOpenGLFramebufferObject *createFramebufferObject(const QSize &size) override;
    void synchronize(QQuickFramebufferObject *item) override;

private:
    void initGl();
    void drawGlobe(int fboW, int fboH);
    void drawLines(QOpenGLBuffer &vbo, const int *offsets, int segCount, const QColor &color, float lw);
    void drawRing(int fboW, int fboH);

    int m_fboW = 0;
    int m_fboH = 0;
    QQuickWindow *m_window = nullptr;
    double m_centerLat = 25.0;
    double m_centerLon = 30.0;
    double m_R = 100.0;
    double m_itemW = 0.0;
    double m_itemH = 0.0;
    QColor m_oceanColor;
    QColor m_nightColor;
    QColor m_coastColor;
    QColor m_borderColor;
    QColor m_ringColor;
    QColor m_sunColor;
    double m_sunLat = 0.0;
    double m_sunLon = 0.0;

    bool m_glReady = false;
    QScopedPointer<QOpenGLShaderProgram> m_globeProg;
    QScopedPointer<QOpenGLShaderProgram> m_lineProg;
    QScopedPointer<QOpenGLShaderProgram> m_ringProg;
    QOpenGLBuffer m_quadVbo;
    QOpenGLBuffer m_coastVbo;
    QOpenGLBuffer m_borderVbo;
    QScopedArrayPointer<int> m_coastOffsets;
    QScopedArrayPointer<int> m_borderOffsets;
    int m_coastSegCount = 0;
    int m_borderSegCount = 0;
};

GlobeRenderer::~GlobeRenderer() {
    m_globeProg.reset();
    m_lineProg.reset();
    m_ringProg.reset();
    if (m_quadVbo.isCreated()) m_quadVbo.destroy();
    if (m_coastVbo.isCreated()) m_coastVbo.destroy();
    if (m_borderVbo.isCreated()) m_borderVbo.destroy();
}

QOpenGLFramebufferObject *GlobeRenderer::createFramebufferObject(const QSize &size) {
    QSize fboSize = size;
    if (fboSize.width() <= 0 || fboSize.height() <= 0)
        fboSize = QSize(1, 1);
    m_fboW = fboSize.width();
    m_fboH = fboSize.height();
    logDebug("createFramebufferObject: req=%dx%d, fbo=%dx%d\n", size.width(), size.height(), m_fboW, m_fboH);
    QOpenGLFramebufferObjectFormat format;
    format.setAttachment(QOpenGLFramebufferObject::CombinedDepthStencil);
    format.setInternalTextureFormat(GL_RGBA);
    return new QOpenGLFramebufferObject(fboSize, format);
}

void GlobeRenderer::synchronize(QQuickFramebufferObject *item) {
    GlobeItem *globe = static_cast<GlobeItem *>(item);
    m_window = globe->window();
    m_centerLat = globe->centerLatitude();
    m_centerLon = globe->centerLongitude();
    m_R = globe->radius();
    m_itemW = globe->width();
    m_itemH = globe->height();
    m_oceanColor = globe->oceanColor();
    m_nightColor = globe->nightColor();
    m_coastColor = globe->coastColor();
    m_borderColor = globe->borderColor();
    m_ringColor = globe->ringColor();
    m_sunColor = globe->sunColor();
    m_sunLat = globe->sunLat();
    m_sunLon = globe->sunLon();
    logDebug("synchronize: item=%fx%f, R=%f, lat=%f, lon=%f\n", m_itemW, m_itemH, m_R, m_centerLat, m_centerLon);
    update();
}

void GlobeRenderer::initGl() {
    if (m_glReady) return;
    initializeOpenGLFunctions();

    static const float q[] = {-1, -1, 1, -1, -1, 1, 1, -1, 1, 1, -1, 1};
    m_quadVbo.create();
    m_quadVbo.bind();
    m_quadVbo.allocate(q, sizeof(q));
    m_quadVbo.release();

    m_globeProg.reset(new QOpenGLShaderProgram);
    if (!m_globeProg->addShaderFromSourceCode(QOpenGLShader::Vertex, GLOBE_VERT)
        || !m_globeProg->addShaderFromSourceCode(QOpenGLShader::Fragment, GLOBE_FRAG)
        || !m_globeProg->link()) {
        logDebug("GlobeRenderer: globe shader failed: %s\n", qPrintable(m_globeProg->log()));
        return;
    }

    m_lineProg.reset(new QOpenGLShaderProgram);
    if (!m_lineProg->addShaderFromSourceCode(QOpenGLShader::Vertex, LINE_VERT)
        || !m_lineProg->addShaderFromSourceCode(QOpenGLShader::Fragment, LINE_FRAG)
        || !m_lineProg->link()) {
        logDebug("GlobeRenderer: line shader failed: %s\n", qPrintable(m_lineProg->log()));
        return;
    }

    m_ringProg.reset(new QOpenGLShaderProgram);
    if (!m_ringProg->addShaderFromSourceCode(QOpenGLShader::Vertex, RING_VERT)
        || !m_ringProg->addShaderFromSourceCode(QOpenGLShader::Fragment, RING_FRAG)
        || !m_ringProg->link()) {
        logDebug("GlobeRenderer: ring shader failed: %s\n", qPrintable(m_ringProg->log()));
        return;
    }

    using namespace GeomData;
    m_coastSegCount = COAST_SEGMENT_COUNT;
    m_coastOffsets.reset(new int[m_coastSegCount + 1]);
    for (int i = 0; i <= m_coastSegCount; i++) m_coastOffsets[i] = COAST_OFFSETS[i];
    int cf = m_coastOffsets[m_coastSegCount] * 2;
    float *cr = new float[cf];
    for (int i = 0; i < cf; i += 2) {
        cr[i] = COAST_DATA[i] * float(DEG2RAD);
        cr[i + 1] = COAST_DATA[i + 1] * float(DEG2RAD);
    }
    m_coastVbo.create();
    m_coastVbo.bind();
    m_coastVbo.allocate(cr, cf * sizeof(float));
    m_coastVbo.release();
    delete[] cr;

    m_borderSegCount = BORDER_SEGMENT_COUNT;
    m_borderOffsets.reset(new int[m_borderSegCount + 1]);
    for (int i = 0; i <= m_borderSegCount; i++) m_borderOffsets[i] = BORDER_OFFSETS[i];
    int bf = m_borderOffsets[m_borderSegCount] * 2;
    float *br = new float[bf];
    for (int i = 0; i < bf; i += 2) {
        br[i] = BORDER_DATA[i] * float(DEG2RAD);
        br[i + 1] = BORDER_DATA[i + 1] * float(DEG2RAD);
    }
    m_borderVbo.create();
    m_borderVbo.bind();
    m_borderVbo.allocate(br, bf * sizeof(float));
    m_borderVbo.release();
    delete[] br;

    m_glReady = true;
    logDebug("GlobeRenderer: initGl complete\n");
}

void GlobeRenderer::render() {
    QOpenGLFramebufferObject *fbo = framebufferObject();
    int curW = fbo ? fbo->width() : m_fboW;
    int curH = fbo ? fbo->height() : m_fboH;
    logDebug("GlobeRenderer::render: cur=%dx%d, R=%f, item=%fx%f\n", curW, curH, m_R, m_itemW, m_itemH);
    if (curW <= 1 || curH <= 1 || m_R <= 1.0 || m_itemW <= 1.0 || m_itemH <= 1.0) {
        logDebug("GlobeRenderer::render: skip render (dimensions invalid)\n");
        glClearColor(0.0f, 0.0f, 0.0f, 0.0f);
        glClear(GL_COLOR_BUFFER_BIT);
        return;
    }
    if (!m_glReady) initGl();
    if (!m_glReady) {
        logDebug("GlobeRenderer::render: initGl failed\n");
        return;
    }

    glViewport(0, 0, curW, curH);
    glClearColor(0.0f, 0.0f, 0.0f, 0.0f);
    glClear(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT);

    glDisable(GL_DEPTH_TEST);
    glDisable(GL_CULL_FACE);
    glEnable(GL_BLEND);
    glBlendFunc(GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA);

    drawGlobe(curW, curH);
    drawLines(m_borderVbo, m_borderOffsets.data(), m_borderSegCount, m_borderColor, 0.8f);
    drawLines(m_coastVbo, m_coastOffsets.data(), m_coastSegCount, m_coastColor, 1.2f);
    drawRing(curW, curH);

    if (m_window) {
        m_window->resetOpenGLState();
    }
}

void GlobeRenderer::drawGlobe(int fboW, int fboH) {
    m_globeProg->bind();
    m_quadVbo.bind();
    int loc = m_globeProg->attributeLocation("a_pos");
    m_globeProg->enableAttributeArray(loc);
    m_globeProg->setAttributeBuffer(loc, GL_FLOAT, 0, 2, 2 * sizeof(float));

    float normRx = float(m_R / (m_itemW * 0.5));
    float normRy = float(m_R / (m_itemH * 0.5));
    float fboHalfX = float(fboW) * 0.5f;
    float fboHalfY = float(fboH) * 0.5f;
    float dpr = float(fboW) / float(m_itemW);

    m_globeProg->setUniformValue("u_normR", normRx, normRy);
    m_globeProg->setUniformValue("u_fboHalf", fboHalfX, fboHalfY);
    m_globeProg->setUniformValue("u_dpr", dpr);
    m_globeProg->setUniformValue("u_cLatR", float(m_centerLat * DEG2RAD));
    m_globeProg->setUniformValue("u_cLonR", float(m_centerLon * DEG2RAD));
    m_globeProg->setUniformValue("u_sunLatR", float(m_sunLat * DEG2RAD));
    m_globeProg->setUniformValue("u_sunLonR", float(m_sunLon * DEG2RAD));
    m_globeProg->setUniformValue("u_oceanColor", float(m_oceanColor.redF()), float(m_oceanColor.greenF()), float(m_oceanColor.blueF()), float(m_oceanColor.alphaF()));
    m_globeProg->setUniformValue("u_nightColor", float(m_nightColor.redF()), float(m_nightColor.greenF()), float(m_nightColor.blueF()), float(m_nightColor.alphaF()));
    QColor sc = m_sunColor.isValid() ? m_sunColor : m_coastColor;
    m_globeProg->setUniformValue("u_sunColor", float(sc.redF()), float(sc.greenF()), float(sc.blueF()), float(sc.alphaF()));

    glDrawArrays(GL_TRIANGLES, 0, 6);
    m_globeProg->disableAttributeArray(loc);
    m_quadVbo.release();
    m_globeProg->release();
}

void GlobeRenderer::drawLines(QOpenGLBuffer &vbo, const int *offsets, int segCount,
                              const QColor &color, float lw) {
    if (color.alphaF() <= 0.0f || !offsets || segCount <= 0 || m_R <= 1.0) return;

    m_lineProg->bind();
    vbo.bind();
    int loc = m_lineProg->attributeLocation("a_geo");
    m_lineProg->enableAttributeArray(loc);
    m_lineProg->setAttributeBuffer(loc, GL_FLOAT, 0, 2, 2 * sizeof(float));

    float itemHalfX = float(m_itemW) * 0.5f;
    float itemHalfY = float(m_itemH) * 0.5f;

    m_lineProg->setUniformValue("u_cLatR", float(m_centerLat * DEG2RAD));
    m_lineProg->setUniformValue("u_cLonR", float(m_centerLon * DEG2RAD));
    m_lineProg->setUniformValue("u_R", float(m_R));
    m_lineProg->setUniformValue("u_itemHalf", itemHalfX, itemHalfY);
    m_lineProg->setUniformValue("u_color", float(color.redF()), float(color.greenF()), float(color.blueF()), float(color.alphaF()));
    glLineWidth(lw);

    static const float lineOffsetsX[] = {
         0.0f,  0.55f, -0.55f,  0.0f,   0.0f
    };
    static const float lineOffsetsY[] = {
         0.0f,  0.0f,   0.0f,   0.55f, -0.55f
    };
    int passes = (lw > 1.0f) ? 5 : 1;
    for (int p = 0; p < passes; p++) {
        m_lineProg->setUniformValue("u_offset", lineOffsetsX[p], lineOffsetsY[p]);
        for (int s = 0; s < segCount; s++) {
            int start = offsets[s], count = offsets[s + 1] - start;
            if (count >= 2) glDrawArrays(GL_LINE_STRIP, start, count);
        }
    }

    m_lineProg->disableAttributeArray(loc);
    vbo.release();
    m_lineProg->release();
}

void GlobeRenderer::drawRing(int fboW, int fboH) {
    if (m_ringColor.alpha() <= 0) return;
    m_ringProg->bind();
    m_quadVbo.bind();
    int loc = m_ringProg->attributeLocation("a_pos");
    m_ringProg->enableAttributeArray(loc);
    m_ringProg->setAttributeBuffer(loc, GL_FLOAT, 0, 2, 2 * sizeof(float));

    float normRx = float(m_R / (m_itemW * 0.5));
    float normRy = float(m_R / (m_itemH * 0.5));
    float fboHalfX = float(fboW) * 0.5f;
    float fboHalfY = float(fboH) * 0.5f;
    float dpr = float(fboW) / float(m_itemW);

    m_ringProg->setUniformValue("u_normR", normRx, normRy);
    m_ringProg->setUniformValue("u_fboHalf", fboHalfX, fboHalfY);
    m_ringProg->setUniformValue("u_dpr", dpr);
    m_ringProg->setUniformValue("u_color", float(m_ringColor.redF()), float(m_ringColor.greenF()), float(m_ringColor.blueF()), float(m_ringColor.alphaF()));

    glDrawArrays(GL_TRIANGLES, 0, 6);
    m_ringProg->disableAttributeArray(loc);
    m_quadVbo.release();
    m_ringProg->release();
}

GlobeItem::GlobeItem(QQuickItem *parent)
    : QQuickFramebufferObject(parent)
{
    setFlag(ItemHasContents, true);
    setMirrorVertically(true);
    m_oceanColor = QColor(15, 20, 35, 180);
    m_nightColor = QColor(0, 0, 0, 115);
    m_coastColor = QColor(80, 140, 200);
    m_borderColor = QColor(80, 140, 200, 89);
    m_ringColor = QColor(80, 140, 200, 102);
    m_sunColor = QColor(80, 140, 200);
    updateSunPosition();

    QTimer *t = new QTimer(this);
    connect(t, &QTimer::timeout, this, [this]() {
        updateSunPosition();
        update();
    });
    t->start(60000);
}

QQuickFramebufferObject::Renderer *GlobeItem::createRenderer() const {
    return new GlobeRenderer();
}

double GlobeItem::radius() const {
    double r = qMin(width(), height()) / 2.0 - 8.0;
    return qMax(0.0, r);
}

void GlobeItem::setCenterLatitude(double lat) {
    lat = qBound(-90.0, lat, 90.0);
    if (qFuzzyCompare(m_centerLat, lat)) return;
    m_centerLat = lat;
    logDebug("GlobeItem::setCenterLatitude: %f\n", lat);
    emit centerLatitudeChanged();
    update();
}

void GlobeItem::setCenterLongitude(double lon) {
    while (lon > 180.0) { lon -= 360.0; }
    while (lon < -180.0) { lon += 360.0; }
    if (qFuzzyCompare(m_centerLon, lon)) return;
    m_centerLon = lon;
    logDebug("GlobeItem::setCenterLongitude: %f\n", lon);
    emit centerLongitudeChanged();
    update();
}

void GlobeItem::setOceanColor(const QColor &c) {
    if (m_oceanColor != c) { m_oceanColor = c; emit oceanColorChanged(); update(); }
}

void GlobeItem::setNightColor(const QColor &c) {
    if (m_nightColor != c) { m_nightColor = c; emit nightColorChanged(); update(); }
}

void GlobeItem::setCoastColor(const QColor &c) {
    if (m_coastColor != c) { m_coastColor = c; emit coastColorChanged(); update(); }
}

void GlobeItem::setBorderColor(const QColor &c) {
    if (m_borderColor != c) { m_borderColor = c; emit borderColorChanged(); update(); }
}

void GlobeItem::setRingColor(const QColor &c) {
    if (m_ringColor != c) { m_ringColor = c; emit ringColorChanged(); update(); }
}

void GlobeItem::setSunColor(const QColor &c) {
    if (m_sunColor != c) { m_sunColor = c; emit sunColorChanged(); update(); }
}

void GlobeItem::geometryChanged(const QRectF &n, const QRectF &o) {
    QQuickFramebufferObject::geometryChanged(n, o);
    emit radiusChanged();
    update();
}

void GlobeItem::updateSunPosition() {
    QDateTime now = QDateTime::currentDateTimeUtc();
    int doy = now.date().dayOfYear();
    double hour = now.time().hour() + now.time().minute() / 60.0 + now.time().second() / 3600.0;
    double g = 2.0 * M_PI / 365.0 * (doy - 1);
    double decl = 0.006918 - 0.399912 * cos(g) + 0.070257 * sin(g) - 0.006758 * cos(2 * g) + 0.000907 * sin(2 * g) - 0.002697 * cos(3 * g) + 0.00148 * sin(3 * g);
    double eq = 229.18 * (0.000075 + 0.001868 * cos(g) - 0.032077 * sin(g) - 0.014615 * cos(2 * g) - 0.04089 * sin(2 * g));
    double nlon = -((hour - 12.0) * 15.0 + eq / 4.0);
    while (nlon > 180) { nlon -= 360; }
    while (nlon < -180) { nlon += 360; }
    double nlat = decl * RAD2DEG;
    if (!qFuzzyCompare(m_sunLat, nlat) || !qFuzzyCompare(m_sunLon, nlon)) {
        m_sunLat = nlat;
        m_sunLon = nlon;
        emit sunChanged();
        update();
    }
}
