#include "globerenderer.h"
#include "globeitem.h"
#include "geomdata.h"
#include <QtMath>
#include <QOpenGLFramebufferObject>

// --- Shader sources (GLES 2.0 / #version 100) ---

static const char *OCEAN_VERT =
    "attribute vec2 a_pos;\n"
    "void main() { gl_Position = vec4(a_pos, 0.0, 1.0); }\n";

static const char *OCEAN_FRAG =
    "precision mediump float;\n"
    "uniform vec2 u_cx_cy;\n"
    "uniform float u_R;\n"
    "uniform vec2 u_resolution;\n"
    "uniform vec4 u_oceanColor;\n"
    "void main() {\n"
    "    vec2 d = gl_FragCoord.xy - u_cx_cy;\n"
    "    if (dot(d, d) > u_R * u_R) discard;\n"
    "    gl_FragColor = u_oceanColor;\n"
    "}\n";

static const char *NIGHT_VERT =
    "attribute vec2 a_pos;\n"
    "void main() { gl_Position = vec4(a_pos, 0.0, 1.0); }\n";

static const char *NIGHT_FRAG =
    "precision mediump float;\n"
    "uniform vec2 u_cx_cy;\n"
    "uniform float u_R;\n"
    "uniform float u_cLatR;\n"
    "uniform float u_cLonR;\n"
    "uniform float u_sunLatR;\n"
    "uniform float u_sunLonR;\n"
    "uniform vec4 u_nightColor;\n"
    "uniform vec2 u_resolution;\n"
    "void main() {\n"
    "    vec2 d = gl_FragCoord.xy - u_cx_cy;\n"
    "    float r2 = dot(d, d);\n"
    "    if (r2 > u_R * u_R) discard;\n"
    "    float xn = d.x / u_R;\n"
    "    float yn = -d.y / u_R;\n"
    "    float rho2 = xn*xn + yn*yn;\n"
    "    if (rho2 > 1.0) discard;\n"
    "    float rho = sqrt(rho2);\n"
    "    float c = rho < 1e-6 ? 0.0 : asin(rho);\n"
    "    float cosC = cos(c), sinC = sin(c);\n"
    "    float cosLatR = cos(u_cLatR), sinLatR = sin(u_cLatR);\n"
    "    float cosLatCosC = cosLatR * cosC;\n"
    "    float rho_safe = max(rho, 1e-6);\n"
    "    float lat = asin(cosC * sinLatR + yn * sinC * cosLatR / rho_safe);\n"
    "    float lon = u_cLonR + atan(xn * sinC, rho * cosLatCosC - yn * sinC * sinLatR);\n"
    "    float cosA = sin(u_sunLatR) * sin(lat)\n"
    "               + cos(u_sunLatR) * cos(lat) * cos(lon - u_sunLonR);\n"
    "    if (cosA >= 0.0) discard;\n"
    "    gl_FragColor = u_nightColor;\n"
    "}\n";

static const char *LINE_VERT =
    "attribute vec2 a_geo;\n"
    "uniform float u_cLatR;\n"
    "uniform float u_cLonR;\n"
    "uniform float u_R;\n"
    "uniform vec2 u_cx_cy;\n"
    "uniform vec2 u_resolution;\n"
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
    "        (u_cx_cy.x + x) / u_resolution.x * 2.0 - 1.0,\n"
    "        (u_cx_cy.y - y) / u_resolution.y * 2.0 - 1.0,\n"
    "        0.0, 1.0\n"
    "    );\n"
    "}\n";

static const char *LINE_FRAG =
    "precision mediump float;\n"
    "uniform vec4 u_color;\n"
    "varying float v_z;\n"
    "void main() {\n"
    "    if (v_z < 0.0) discard;\n"
    "    gl_FragColor = u_color;\n"
    "}\n";

static const char *RING_VERT =
    "attribute vec2 a_pos;\n"
    "uniform vec2 u_cx_cy;\n"
    "uniform float u_R;\n"
    "uniform float u_ringWidth;\n"
    "uniform vec2 u_resolution;\n"
    "varying float v_dist;\n"
    "void main() {\n"
    "    float outerR = u_R + u_ringWidth * 0.5;\n"
    "    vec2 pos = u_cx_cy + a_pos * outerR;\n"
    "    v_dist = length(a_pos) * outerR;\n"
    "    gl_Position = vec4(\n"
    "        pos.x / u_resolution.x * 2.0 - 1.0,\n"
    "        1.0 - pos.y / u_resolution.y * 2.0,\n"
    "        0.0, 1.0\n"
    "    );\n"
    "}\n";

static const char *RING_FRAG =
    "precision mediump float;\n"
    "uniform float u_R;\n"
    "uniform float u_ringWidth;\n"
    "uniform vec4 u_color;\n"
    "varying float v_dist;\n"
    "void main() {\n"
    "    float inner = u_R - u_ringWidth * 0.5;\n"
    "    float outer = u_R + u_ringWidth * 0.5;\n"
    "    if (v_dist < inner || v_dist > outer) discard;\n"
    "    gl_FragColor = u_color;\n"
    "}\n";


GlobeRenderer::GlobeRenderer()
    : m_coastVbo(QOpenGLBuffer::VertexBuffer)
    , m_borderVbo(QOpenGLBuffer::VertexBuffer)
    , m_quadVbo(QOpenGLBuffer::VertexBuffer)
    , m_ringVbo(QOpenGLBuffer::VertexBuffer)
{
}

GlobeRenderer::~GlobeRenderer()
{
    delete m_oceanProg;
    delete m_nightProg;
    delete m_lineProg;
    delete m_ringProg;
    delete[] m_coastOffsets;
    delete[] m_borderOffsets;
}

void GlobeRenderer::initShaders()
{
    if (m_shadersReady) return;
    initializeOpenGLFunctions();

    m_oceanProg = new QOpenGLShaderProgram;
    m_oceanProg->addShaderFromSourceCode(QOpenGLShader::Vertex, OCEAN_VERT);
    m_oceanProg->addShaderFromSourceCode(QOpenGLShader::Fragment, OCEAN_FRAG);
    m_oceanProg->link();

    m_nightProg = new QOpenGLShaderProgram;
    m_nightProg->addShaderFromSourceCode(QOpenGLShader::Vertex, NIGHT_VERT);
    m_nightProg->addShaderFromSourceCode(QOpenGLShader::Fragment, NIGHT_FRAG);
    m_nightProg->link();

    m_lineProg = new QOpenGLShaderProgram;
    m_lineProg->addShaderFromSourceCode(QOpenGLShader::Vertex, LINE_VERT);
    m_lineProg->addShaderFromSourceCode(QOpenGLShader::Fragment, LINE_FRAG);
    m_lineProg->link();

    m_ringProg = new QOpenGLShaderProgram;
    m_ringProg->addShaderFromSourceCode(QOpenGLShader::Vertex, RING_VERT);
    m_ringProg->addShaderFromSourceCode(QOpenGLShader::Fragment, RING_FRAG);
    m_ringProg->link();

    m_shadersReady = true;
}

void GlobeRenderer::initGeomData()
{
    if (m_geomReady) return;

    using namespace GeomData;

    // Convert deg → rad in-place for coast data
    m_coastSegCount = COAST_SEGMENT_COUNT;
    m_coastOffsets = new int[m_coastSegCount + 1];
    for (int i = 0; i <= m_coastSegCount; i++)
        m_coastOffsets[i] = COAST_OFFSETS[i];

    int coastFloats = m_coastOffsets[m_coastSegCount] * 2;
    float *coastRad = new float[coastFloats];
    for (int i = 0; i < coastFloats; i += 2) {
        coastRad[i]     = COAST_DATA[i]     * float(M_PI / 180.0); // lon
        coastRad[i + 1] = COAST_DATA[i + 1] * float(M_PI / 180.0); // lat
    }

    m_coastVbo.create();
    m_coastVbo.bind();
    m_coastVbo.allocate(coastRad, coastFloats * sizeof(float));
    m_coastVbo.release();
    delete[] coastRad;

    // Convert deg → rad for border data
    m_borderSegCount = BORDER_SEGMENT_COUNT;
    m_borderOffsets = new int[m_borderSegCount + 1];
    for (int i = 0; i <= m_borderSegCount; i++)
        m_borderOffsets[i] = BORDER_OFFSETS[i];

    int borderFloats = m_borderOffsets[m_borderSegCount] * 2;
    float *borderRad = new float[borderFloats];
    for (int i = 0; i < borderFloats; i += 2) {
        borderRad[i]     = BORDER_DATA[i]     * float(M_PI / 180.0);
        borderRad[i + 1] = BORDER_DATA[i + 1] * float(M_PI / 180.0);
    }

    m_borderVbo.create();
    m_borderVbo.bind();
    m_borderVbo.allocate(borderRad, borderFloats * sizeof(float));
    m_borderVbo.release();
    delete[] borderRad;

    m_geomReady = true;
}

void GlobeRenderer::initBuffers()
{
    if (m_quadVbo.isCreated()) return;

    // Fullscreen quad: two triangles covering [-1,1]
    static const float quad[] = {
        -1.f, -1.f,  1.f, -1.f,  -1.f, 1.f,
         1.f, -1.f,  1.f,  1.f,  -1.f, 1.f
    };
    m_quadVbo.create();
    m_quadVbo.bind();
    m_quadVbo.allocate(quad, sizeof(quad));
    m_quadVbo.release();

    // Ring: circle approximated by triangle strip
    m_ringVertexCount = 128;
    // Inner and outer vertices as triangle strip
    QVector<float> ringData;
    for (int i = 0; i <= m_ringVertexCount; i++) {
        float angle = 2.0f * float(M_PI) * i / m_ringVertexCount;
        float c = cosf(angle), s = sinf(angle);
        ringData << c << s; // normalized direction, shader scales by radius
    }
    m_ringVbo.create();
    m_ringVbo.bind();
    m_ringVbo.allocate(ringData.constData(), ringData.size() * sizeof(float));
    m_ringVbo.release();
}

void GlobeRenderer::synchronize(QQuickFramebufferObject *item)
{
    auto *g = static_cast<GlobeItem *>(item);
    m_cLat = g->centerLatitude();
    m_cLon = g->centerLongitude();
    m_R = g->radius();
    m_fboW = float(g->width());
    m_fboH = float(g->height());
    m_oceanColor = g->oceanColor();
    m_nightColor = g->nightColor();
    m_coastColor = g->coastColor();
    m_borderColor = g->borderColor();
    m_ringColor = g->ringColor();
    m_sunLat = g->sunLat();
    m_sunLon = g->sunLon();
}

QOpenGLFramebufferObject *GlobeRenderer::createFramebufferObject(const QSize &size)
{
    QOpenGLFramebufferObjectFormat fmt;
    fmt.setAttachment(QOpenGLFramebufferObject::CombinedDepthStencil);
    fmt.setSamples(0);
    fmt.setInternalTextureFormat(GL_RGBA8);
    return new QOpenGLFramebufferObject(size, fmt);
}

void GlobeRenderer::render()
{
    initShaders();
    initBuffers();
    initGeomData();

    glViewport(0, 0, int(m_fboW), int(m_fboH));
    glClearColor(0, 0, 0, 0);
    glClear(GL_COLOR_BUFFER_BIT);
    glEnable(GL_BLEND);
    glBlendFunc(GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA);

    // 1. Ocean disc
    drawOcean();

    // 2. Night shading
    drawNight();

    // 3. Coastlines
    m_coastColor.setAlphaF(1.0);
    drawLines(m_coastVbo, m_coastOffsets, m_coastSegCount, m_coastColor, 1.2f);

    // 4. Borders
    drawLines(m_borderVbo, m_borderOffsets, m_borderSegCount, m_borderColor, 0.7f);

    // 5. Globe ring
    drawRing();
}

void GlobeRenderer::drawOcean()
{
    m_oceanProg->bind();
    m_quadVbo.bind();

    int posLoc = m_oceanProg->attributeLocation("a_pos");
    m_oceanProg->enableAttributeArray(posLoc);
    m_oceanProg->setAttributeBuffer(posLoc, GL_FLOAT, 0, 2, 2 * sizeof(float));

    // Fragment shaders use gl_FragCoord (GL Y-up), so center Y must be flipped
    float cx = m_fboW / 2.0f, cy = m_fboH / 2.0f;
    float R = float(m_R);
    float res[2] = { m_fboW, m_fboH };
    m_oceanProg->setUniformValue("u_cx_cy", cx, m_fboH - cy);
    m_oceanProg->setUniformValue("u_R", R);
    m_oceanProg->setUniformValueArray("u_resolution", res, 1, 2);

    QColor c = m_oceanColor;
    m_oceanProg->setUniformValue("u_oceanColor",
        float(c.redF()), float(c.greenF()), float(c.blueF()), float(c.alphaF()));

    glDrawArrays(GL_TRIANGLES, 0, 6);

    m_oceanProg->disableAttributeArray(posLoc);
    m_quadVbo.release();
    m_oceanProg->release();
}

void GlobeRenderer::drawNight()
{
    m_nightProg->bind();
    m_quadVbo.bind();

    int posLoc = m_nightProg->attributeLocation("a_pos");
    m_nightProg->enableAttributeArray(posLoc);
    m_nightProg->setAttributeBuffer(posLoc, GL_FLOAT, 0, 2, 2 * sizeof(float));

    float cx = m_fboW / 2.0f, cy = m_fboH / 2.0f;
    float R = float(m_R);
    float cLatR = float(m_cLat * M_PI / 180.0);
    float cLonR = float(m_cLon * M_PI / 180.0);
    float sunLatR = float(m_sunLat * M_PI / 180.0);
    float sunLonR = float(m_sunLon * M_PI / 180.0);
    float res[2] = { m_fboW, m_fboH };

    m_nightProg->setUniformValue("u_cx_cy", cx, m_fboH - cy);
    m_nightProg->setUniformValue("u_R", R);
    m_nightProg->setUniformValue("u_cLatR", cLatR);
    m_nightProg->setUniformValue("u_cLonR", cLonR);
    m_nightProg->setUniformValue("u_sunLatR", sunLatR);
    m_nightProg->setUniformValue("u_sunLonR", sunLonR);
    m_nightProg->setUniformValueArray("u_resolution", res, 1, 2);

    QColor nc = m_nightColor;
    m_nightProg->setUniformValue("u_nightColor",
        float(nc.redF()), float(nc.greenF()), float(nc.blueF()), float(nc.alphaF()));

    glDrawArrays(GL_TRIANGLES, 0, 6);

    m_nightProg->disableAttributeArray(posLoc);
    m_quadVbo.release();
    m_nightProg->release();
}

void GlobeRenderer::drawLines(QOpenGLBuffer &vbo, int *offsets, int segCount,
                               const QColor &color, float lineWidth)
{
    m_lineProg->bind();
    vbo.bind();

    int geoLoc = m_lineProg->attributeLocation("a_geo");
    m_lineProg->enableAttributeArray(geoLoc);
    m_lineProg->setAttributeBuffer(geoLoc, GL_FLOAT, 0, 2, 2 * sizeof(float));

    float cLatR = float(m_cLat * M_PI / 180.0);
    float cLonR = float(m_cLon * M_PI / 180.0);
    float R = float(m_R);
    float cx = m_fboW / 2.0f, cy = m_fboH / 2.0f;
    float res[2] = { m_fboW, m_fboH };

    m_lineProg->setUniformValue("u_cLatR", cLatR);
    m_lineProg->setUniformValue("u_cLonR", cLonR);
    m_lineProg->setUniformValue("u_R", R);
    m_lineProg->setUniformValue("u_cx_cy", cx, cy);
    m_lineProg->setUniformValueArray("u_resolution", res, 1, 2);
    m_lineProg->setUniformValue("u_color",
        float(color.redF()), float(color.greenF()),
        float(color.blueF()), float(color.alphaF()));

    glLineWidth(lineWidth);

    for (int s = 0; s < segCount; s++) {
        int start = offsets[s];
        int count = offsets[s + 1] - start;
        if (count < 2) continue;
        glDrawArrays(GL_LINE_STRIP, start, count);
    }

    m_lineProg->disableAttributeArray(geoLoc);
    vbo.release();
    m_lineProg->release();
}

void GlobeRenderer::drawRing()
{
    m_ringProg->bind();
    m_ringVbo.bind();

    int posLoc = m_ringProg->attributeLocation("a_pos");
    m_ringProg->enableAttributeArray(posLoc);
    m_ringProg->setAttributeBuffer(posLoc, GL_FLOAT, 0, 2, 2 * sizeof(float));

    float cx = m_fboW / 2.0f, cy = m_fboH / 2.0f;
    float R = float(m_R);
    float res[2] = { m_fboW, m_fboH };
    float ringW = 1.5f;

    m_ringProg->setUniformValue("u_cx_cy", cx, cy);
    m_ringProg->setUniformValue("u_R", R);
    m_ringProg->setUniformValue("u_ringWidth", ringW);
    m_ringProg->setUniformValueArray("u_resolution", res, 1, 2);

    QColor rc = m_ringColor;
    m_ringProg->setUniformValue("u_color",
        float(rc.redF()), float(rc.greenF()),
        float(rc.blueF()), float(rc.alphaF()));

    glDrawArrays(GL_LINE_STRIP, 0, m_ringVertexCount + 1);

    m_ringProg->disableAttributeArray(posLoc);
    m_ringVbo.release();
    m_ringProg->release();
}