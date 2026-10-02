#include "globeitem.h"
#include "geomdata.h"
#include <QPainter>
#include <QQuickWindow>
#include <QtMath>
#include <QDateTime>
#include <QTimer>
#include <QOpenGLFramebufferObject>

static const char *GLOBE_VERT =
    "#ifdef GL_ES\n"
    "precision mediump float;\n"
    "#endif\n"
    "attribute vec2 a_pos;\n"
    "void main() { gl_Position = vec4(a_pos, 0.0, 1.0); }\n";

static const char *GLOBE_FRAG =
    "#ifdef GL_ES\n"
    "precision mediump float;\n"
    "#endif\n"
    "uniform vec2 u_cx_cy;\n"
    "uniform float u_R;\n"
    "uniform float u_cLatR;\n"
    "uniform float u_cLonR;\n"
    "uniform float u_sunLatR;\n"
    "uniform float u_sunLonR;\n"
    "uniform vec4 u_oceanColor;\n"
    "uniform vec4 u_nightColor;\n"
    "uniform vec4 u_sunColor;\n"
    "void main() {\n"
    "    vec2 d = gl_FragCoord.xy - u_cx_cy;\n"
    "    float r = length(d);\n"
    "    float maxR = u_R + 8.0;\n"
    "    if (r > maxR) discard;\n"
    "\n"
    "    float sinCLat = sin(u_cLatR), cosCLat = cos(u_cLatR);\n"
    "    float sinSLat = sin(u_sunLatR), cosSLat = cos(u_sunLatR);\n"
    "    float dLonSun = u_sunLonR - u_cLonR;\n"
    "    vec2 sunDir = vec2(cosSLat * sin(dLonSun), cosCLat * sinSLat - sinCLat * cosSLat * cos(dLonSun));\n"
    "    float sunDirLen = length(sunDir);\n"
    "    float cosLimb = (sunDirLen > 0.001 && r > 0.001) ? dot(d / r, sunDir / sunDirLen) : 0.0;\n"
    "    float sunScatter = smoothstep(-0.14, 0.28, cosLimb);\n"
    "    sunScatter = sunScatter * sunScatter * (3.0 - 2.0 * sunScatter);\n"
    "    float limbIntensity = mix(0.18, 1.0, sunScatter);\n"
    "\n"
    "    vec3 sc = u_sunColor.rgb;\n"
    "    vec3 coronaCol = mix(sc, vec3(1.0), 0.20 * sunScatter);\n"
    "\n"
    "    if (r > u_R) {\n"
    "        float dr = r - u_R;\n"
    "        float glow = exp(-dr / 2.8) * (1.0 - dr / 8.0);\n"
    "        float coronaAlpha = glow * limbIntensity * 0.55 * u_sunColor.a;\n"
    "        gl_FragColor = vec4(coronaCol, coronaAlpha);\n"
    "        return;\n"
    "    }\n"
    "\n"
    "    float edgeAlpha = smoothstep(u_R, u_R - 1.0, r);\n"
    "    float xn = d.x / u_R;\n"
    "    float yn = d.y / u_R;\n"
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
    "uniform vec2 u_cx_cy;\n"
    "uniform vec2 u_resolution;\n"
    "uniform vec2 u_offset;\n"
    "varying float v_z;\n"
    "void main() {\n"
    "    float sinCLat = sin(u_cLatR), cosCLat = cos(u_cLatR);\n"
    "    float sinLat = sin(a_geo.y), cosLat = cos(a_geo.y);\n"
    "    float dLon = a_geo.x - u_cLonR;\n"
    "    float x = u_R * cosLat * sin(dLon);\n"
    "    float y = u_R * (cosCLat * sinLat - sinCLat * cosLat * cos(dLon));\n"
    "    float z = sinCLat * sinLat + cosCLat * cosLat * cos(dLon);\n"
    "    v_z = z;\n"
    "    gl_Position = vec4(\n"
    "        (u_cx_cy.x + x + u_offset.x) / u_resolution.x * 2.0 - 1.0,\n"
    "        1.0 - (u_cx_cy.y - y - u_offset.y) / u_resolution.y * 2.0,\n"
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
    "void main() {\n"
    "    gl_Position = vec4(a_pos, 0.0, 1.0);\n"
    "}\n";

static const char *RING_FRAG =
    "#ifdef GL_ES\n"
    "precision mediump float;\n"
    "#endif\n"
    "uniform vec2 u_cx_cy;\n"
    "uniform float u_R;\n"
    "uniform vec4 u_color;\n"
    "void main() {\n"
    "    vec2 d = gl_FragCoord.xy - u_cx_cy;\n"
    "    float r = length(d);\n"
    "    float dr = abs(r - u_R);\n"
    "    if (dr > 1.2) discard;\n"
    "    float a = (1.0 - dr / 1.2) * u_color.a;\n"
    "    gl_FragColor = vec4(u_color.rgb, a);\n"
    "}\n";


GlobeItem::GlobeItem(QQuickItem *parent)
    : QQuickPaintedItem(parent)
    , m_coastVbo(QOpenGLBuffer::VertexBuffer)
    , m_borderVbo(QOpenGLBuffer::VertexBuffer)
    , m_quadVbo(QOpenGLBuffer::VertexBuffer)
    , m_ringVbo(QOpenGLBuffer::VertexBuffer)
{
    setFlag(ItemHasContents, true);
    setFillColor(Qt::transparent);
    m_oceanColor = QColor(15, 20, 35);
    m_nightColor = QColor(0, 0, 0, 115);
    m_coastColor = QColor(80, 140, 200);
    m_borderColor = QColor(80, 140, 200, 89);
    m_ringColor = QColor(80, 140, 200, 102);
    m_sunColor = QColor();
    updateSunPosition();
    QTimer *t = new QTimer(this);
    connect(t, &QTimer::timeout, this, [this]() { updateSunPosition(); update(); });
    t->start(60000);
}

GlobeItem::~GlobeItem()
{
    delete m_globeProg; delete m_lineProg; delete m_ringProg;
    delete[] m_coastOffsets; delete[] m_borderOffsets;
    delete m_fbo; delete m_glCtx; delete m_surface;
}

double GlobeItem::radius() const { return qMin(width(), height()) / 2.0 - 8.0; }

void GlobeItem::setCenterLatitude(double lat) {
    lat = qBound(-90.0, lat, 90.0);
    if (qFuzzyCompare(m_centerLat, lat)) return;
    m_centerLat = lat; emit centerLatitudeChanged(); update();
}
void GlobeItem::setCenterLongitude(double lon) {
    while (lon > 180) { lon -= 360; }
    while (lon < -180) { lon += 360; }
    if (qFuzzyCompare(m_centerLon, lon)) return;
    m_centerLon = lon; emit centerLongitudeChanged(); update();
}
void GlobeItem::setOceanColor(const QColor &c)   { if (m_oceanColor != c)  { m_oceanColor = c;  emit oceanColorChanged();  update(); } }
void GlobeItem::setNightColor(const QColor &c)    { if (m_nightColor != c)  { m_nightColor = c;  emit nightColorChanged();  update(); } }
void GlobeItem::setCoastColor(const QColor &c)    { if (m_coastColor != c)  { m_coastColor = c;  emit coastColorChanged();  update(); } }
void GlobeItem::setBorderColor(const QColor &c)   { if (m_borderColor != c) { m_borderColor = c; emit borderColorChanged(); update(); } }
void GlobeItem::setRingColor(const QColor &c)     { if (m_ringColor != c)   { m_ringColor = c;   emit ringColorChanged();   update(); } }
void GlobeItem::setSunColor(const QColor &c)      { if (m_sunColor != c)    { m_sunColor = c;    emit sunColorChanged();    update(); } }

void GlobeItem::geometryChanged(const QRectF &n, const QRectF &o) {
    QQuickPaintedItem::geometryChanged(n, o); emit radiusChanged(); update();
}

void GlobeItem::updateSunPosition() {
    QDateTime now = QDateTime::currentDateTimeUtc();
    int doy = now.date().dayOfYear();
    double hour = now.time().hour() + now.time().minute() / 60.0 + now.time().second() / 3600.0;
    double g = 2.0 * M_PI / 365.0 * (doy - 1);
    double decl = 0.006918 - 0.399912*cos(g) + 0.070257*sin(g) - 0.006758*cos(2*g) + 0.000907*sin(2*g) - 0.002697*cos(3*g) + 0.00148*sin(3*g);
    double eq = 229.18 * (0.000075 + 0.001868*cos(g) - 0.032077*sin(g) - 0.014615*cos(2*g) - 0.04089*sin(2*g));
    double nlon = -((hour - 12.0) * 15.0 + eq / 4.0);
    while (nlon > 180) { nlon -= 360; }
    while (nlon < -180) { nlon += 360; }
    double nlat = decl * 180.0 / M_PI;
    if (!qFuzzyCompare(m_sunLat, nlat) || !qFuzzyCompare(m_sunLon, nlon)) {
        m_sunLat = nlat; m_sunLon = nlon; emit sunChanged(); update();
    }
}

void GlobeItem::initGl() {
    if (m_glReady) return;
    m_surface = new QOffscreenSurface; m_surface->create();
    m_glCtx = new QOpenGLContext;
    if (window() && window()->openglContext()) m_glCtx->setShareContext(window()->openglContext());
    m_glCtx->setFormat(m_surface->requestedFormat()); m_glCtx->create();
    m_glCtx->makeCurrent(m_surface); initializeOpenGLFunctions();

    static const float q[] = {-1,-1, 1,-1, -1,1, 1,-1, 1,1, -1,1};
    m_quadVbo.create(); m_quadVbo.bind(); m_quadVbo.allocate(q, sizeof(q)); m_quadVbo.release();

    m_ringVertexCount = 128;
    QVector<float> rd;
    for (int i = 0; i <= m_ringVertexCount; i++) {
        float a = 2.0f * float(M_PI) * i / m_ringVertexCount;
        rd << cosf(a) << sinf(a);
    }
    m_ringVbo.create(); m_ringVbo.bind(); m_ringVbo.allocate(rd.constData(), rd.size()*sizeof(float)); m_ringVbo.release();

    m_globeProg = new QOpenGLShaderProgram;
    m_globeProg->addShaderFromSourceCode(QOpenGLShader::Vertex, GLOBE_VERT);
    m_globeProg->addShaderFromSourceCode(QOpenGLShader::Fragment, GLOBE_FRAG);
    m_globeProg->link();

    m_lineProg = new QOpenGLShaderProgram;
    m_lineProg->addShaderFromSourceCode(QOpenGLShader::Vertex, LINE_VERT);
    m_lineProg->addShaderFromSourceCode(QOpenGLShader::Fragment, LINE_FRAG);
    m_lineProg->link();

    m_ringProg = new QOpenGLShaderProgram;
    m_ringProg->addShaderFromSourceCode(QOpenGLShader::Vertex, RING_VERT);
    m_ringProg->addShaderFromSourceCode(QOpenGLShader::Fragment, RING_FRAG);
    m_ringProg->link();

    using namespace GeomData;
    m_coastSegCount = COAST_SEGMENT_COUNT;
    m_coastOffsets = new int[m_coastSegCount + 1];
    for (int i = 0; i <= m_coastSegCount; i++) m_coastOffsets[i] = COAST_OFFSETS[i];
    int cf = m_coastOffsets[m_coastSegCount] * 2;
    float *cr = new float[cf];
    for (int i = 0; i < cf; i += 2) { cr[i] = COAST_DATA[i] * float(M_PI/180.0); cr[i+1] = COAST_DATA[i+1] * float(M_PI/180.0); }
    m_coastVbo.create(); m_coastVbo.bind(); m_coastVbo.allocate(cr, cf*sizeof(float)); m_coastVbo.release(); delete[] cr;

    m_borderSegCount = BORDER_SEGMENT_COUNT;
    m_borderOffsets = new int[m_borderSegCount + 1];
    for (int i = 0; i <= m_borderSegCount; i++) m_borderOffsets[i] = BORDER_OFFSETS[i];
    int bf = m_borderOffsets[m_borderSegCount] * 2;
    float *br = new float[bf];
    for (int i = 0; i < bf; i += 2) { br[i] = BORDER_DATA[i] * float(M_PI/180.0); br[i+1] = BORDER_DATA[i+1] * float(M_PI/180.0); }
    m_borderVbo.create(); m_borderVbo.bind(); m_borderVbo.allocate(br, bf*sizeof(float)); m_borderVbo.release(); delete[] br;

    m_glReady = true;
}

void GlobeItem::paint(QPainter *painter) {
    int w = int(width()), h = int(height());
    if (w <= 0 || h <= 0) return;
    initGl();
    m_glCtx->makeCurrent(m_surface);
    if (!m_fbo || m_fbo->size() != QSize(w, h)) {
        delete m_fbo;
        QOpenGLFramebufferObjectFormat fmt;
        fmt.setAttachment(QOpenGLFramebufferObject::CombinedDepthStencil);
        fmt.setInternalTextureFormat(GL_RGBA);
        m_fbo = new QOpenGLFramebufferObject(QSize(w, h), fmt);
    }
    renderGlobe(w, h);

    m_fbo->bind();
    int bpl = w * 4;
    QByteArray raw(bpl * h, Qt::Uninitialized);
    glReadPixels(0, 0, w, h, GL_RGBA, GL_UNSIGNED_BYTE, raw.data());
    m_fbo->release();

    QImage img(w, h, QImage::Format_ARGB32);
    for (int sy = 0; sy < h; sy++) {
        int gy = h - 1 - sy;
        const uchar *src = reinterpret_cast<const uchar*>(raw.constData()) + gy * bpl;
        uchar *dst = img.scanLine(sy);
        memcpy(dst, src, bpl);
        for (int x = 0; x < w; x++) { uchar *px = dst + x * 4; qSwap(px[0], px[2]); }
    }

    painter->setCompositionMode(QPainter::CompositionMode_Source);
    painter->drawImage(0, 0, img);
    if (window() && window()->openglContext())
        window()->openglContext()->makeCurrent(window());
}

void GlobeItem::renderGlobe(int w, int h) {
    m_fbo->bind();
    glViewport(0, 0, w, h);
    glClearColor(0, 0, 0, 0);
    glClear(GL_COLOR_BUFFER_BIT);
    glEnable(GL_BLEND);
    glBlendFunc(GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA);

    drawGlobe(w, h);

    drawLines(m_borderVbo, m_borderOffsets, m_borderSegCount, m_borderColor, 0.8f, w, h);
    drawLines(m_coastVbo, m_coastOffsets, m_coastSegCount, m_coastColor, 1.2f, w, h);

    drawRing(w, h);

    m_fbo->release();
}

void GlobeItem::drawGlobe(int w, int h) {
    m_globeProg->bind();
    m_quadVbo.bind();
    int loc = m_globeProg->attributeLocation("a_pos");
    m_globeProg->enableAttributeArray(loc);
    m_globeProg->setAttributeBuffer(loc, GL_FLOAT, 0, 2, 2 * sizeof(float));

    float cx = float(w) / 2.0f;
    float glCy = float(h) - float(h) / 2.0f;
    m_globeProg->setUniformValue("u_cx_cy", cx, glCy);
    m_globeProg->setUniformValue("u_R", float(radius()));
    m_globeProg->setUniformValue("u_cLatR", float(m_centerLat * M_PI / 180.0));
    m_globeProg->setUniformValue("u_cLonR", float(m_centerLon * M_PI / 180.0));
    m_globeProg->setUniformValue("u_sunLatR", float(m_sunLat * M_PI / 180.0));
    m_globeProg->setUniformValue("u_sunLonR", float(m_sunLon * M_PI / 180.0));
    m_globeProg->setUniformValue("u_oceanColor", float(m_oceanColor.redF()), float(m_oceanColor.greenF()), float(m_oceanColor.blueF()), float(m_oceanColor.alphaF()));
    m_globeProg->setUniformValue("u_nightColor", float(m_nightColor.redF()), float(m_nightColor.greenF()), float(m_nightColor.blueF()), float(m_nightColor.alphaF()));
    QColor sc = m_sunColor.isValid() ? m_sunColor : m_coastColor;
    m_globeProg->setUniformValue("u_sunColor", float(sc.redF()), float(sc.greenF()), float(sc.blueF()), float(sc.alphaF()));

    glDrawArrays(GL_TRIANGLES, 0, 6);
    m_globeProg->disableAttributeArray(loc);
    m_quadVbo.release();
    m_globeProg->release();
}

void GlobeItem::drawLines(QOpenGLBuffer &vbo, int *offsets, int segCount,
                          const QColor &color, float lw, int w, int h) {
    m_lineProg->bind(); vbo.bind();
    int loc = m_lineProg->attributeLocation("a_geo");
    m_lineProg->enableAttributeArray(loc);
    m_lineProg->setAttributeBuffer(loc, GL_FLOAT, 0, 2, 2 * sizeof(float));
    float cx = float(w)/2.0f, cy = float(h)/2.0f, res[2] = {float(w), float(h)};
    m_lineProg->setUniformValue("u_cLatR", float(m_centerLat * M_PI / 180.0));
    m_lineProg->setUniformValue("u_cLonR", float(m_centerLon * M_PI / 180.0));
    m_lineProg->setUniformValue("u_R", float(radius()));
    m_lineProg->setUniformValue("u_cx_cy", cx, cy);
    m_lineProg->setUniformValueArray("u_resolution", res, 1, 2);
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
            int start = offsets[s], count = offsets[s+1] - start;
            if (count >= 2) glDrawArrays(GL_LINE_STRIP, start, count);
        }
    }

    m_lineProg->disableAttributeArray(loc); vbo.release(); m_lineProg->release();
}

void GlobeItem::drawRing(int w, int h) {
    if (m_ringColor.alpha() <= 0) return;
    m_ringProg->bind();
    m_quadVbo.bind();
    int loc = m_ringProg->attributeLocation("a_pos");
    m_ringProg->enableAttributeArray(loc);
    m_ringProg->setAttributeBuffer(loc, GL_FLOAT, 0, 2, 2 * sizeof(float));
    float cx = float(w)/2.0f;
    float glCy = float(h) - float(h)/2.0f;
    m_ringProg->setUniformValue("u_cx_cy", cx, glCy);
    m_ringProg->setUniformValue("u_R", float(radius()));
    m_ringProg->setUniformValue("u_color", float(m_ringColor.redF()), float(m_ringColor.greenF()), float(m_ringColor.blueF()), float(m_ringColor.alphaF()));
    glDrawArrays(GL_TRIANGLES, 0, 6);
    m_ringProg->disableAttributeArray(loc);
    m_quadVbo.release();
    m_ringProg->release();
}