import QtQuick 2.6
import Sailfish.Silica 1.0
import "../js/projection.js" as Proj
import "../js/coastlines.js" as Coast
import "../js/borders.js" as Borders
import "../js/solar.js" as Solar
import "../js/constants.js" as Const

Item {
    id: globe

    property real centerLatitude: Const.DEFAULT_CENTER_LAT
    property real centerLongitude: Const.DEFAULT_CENTER_LON
    property var locations: []

    property real selectedLat: NaN
    property real selectedLon: NaN
    property bool hasSelection: !isNaN(selectedLat) && !isNaN(selectedLon)
    property bool isSpinning: spinAnim.running
    property real _spinFrom: 0
    property real spinProgress: isSpinning ? ((centerLongitude - _spinFrom) / 360 % 1 + 1) % 1 : 0

    NumberAnimation {
        id: flyAnim
        target: globe
        property: "centerLongitude"
        duration: 600
        easing.type: Easing.InOutQuad
    }

    NumberAnimation {
        id: flyLatAnim
        target: globe
        property: "centerLatitude"
        duration: 600
        easing.type: Easing.InOutQuad
    }

    NumberAnimation {
        id: spinAnim
        target: globe
        property: "centerLongitude"
        duration: 20000
        easing.type: Easing.Linear
        onStopped: {
            _fastMode = false;
            spinTimer.stop();
            canvas.requestPaint();
        }
    }

    Timer {
        id: spinTimer
        interval: 33
        repeat: true
        onTriggered: canvas.requestPaint()
    }

    // Pre-computed lookup tables for fast spin rendering
    property var _geomLut: null   // [{sinLat, cosLat, x, y}, ...] per geometry point
    property var _screenLut: null // [{y, latR}, ...] per scanline
    property real _lutCenterLat: NaN
    property bool _fastMode: false

    function _buildGeomLut(segments, R, cLatR) {
        var sinCLat = Math.sin(cLatR);
        var cosCLat = Math.cos(cLatR);
        var lut = [];
        for (var s = 0; s < segments.length; s++) {
            var seg = segments[s];
            var segLut = [];
            for (var i = 0; i < seg.length; i++) {
                var latR = seg[i][1] * Const.DEG;
                var lonR = seg[i][0] * Const.DEG;
                var sinLat = Math.sin(latR);
                var cosLat = Math.cos(latR);
                var sinLon = Math.sin(lonR);
                var cosLon = Math.cos(lonR);
                // Pre-computed products (no cLon dependency)
                var rCosLatSinLon = R * cosLat * sinLon;
                var rCosLatCosLon = R * cosLat * cosLon;
                var rSinLat = R * sinLat;
                // z = sin(cLat)*sin(lat) + cos(cLat)*cos(lat)*cos(lon-cLon)
                // At cLonR=0: z0 = sinCLat*sinLat + cosCLat*cosLat*cosLon
                var z = sinCLat * sinLat + cosCLat * cosLat * cosLon;
                segLut.push({
                    rSinLat: rSinLat,
                    rCosLatSinLon: rCosLatSinLon,
                    rCosLatCosLon: rCosLatCosLon,
                    z: z
                });
            }
            lut.push(segLut);
        }
        return lut;
    }

    function _buildScreenLut(cx, cy, R, cLatR) {
        var sinCLat = Math.sin(cLatR);
        var cosCLat = Math.cos(cLatR);
        var yMin = Math.floor(cy - R);
        var yMax = Math.ceil(cy + R);
        var table = [];
        for (var py = yMin; py <= yMax; py++) {
            var dy = py - cy;
            var maxDx = Math.sqrt(R * R - dy * dy);
            var yn = -dy / R;
            var yn2 = yn * yn;
            var rho0 = Math.abs(yn);
            var c = rho0 < 1e-10 ? 0 : Math.asin(rho0);
            var cosC0 = Math.cos(c);
            var sinC0 = Math.sin(c);
            var latR = Math.asin(cosC0 * sinCLat + yn * sinC0 * cosCLat);
            table.push({
                py: py,
                yn: yn,
                latR: latR,
                sinLatR: Math.sin(latR),
                cosLatR: Math.cos(latR),
                maxDx: maxDx,
                yn2: yn2,
                // Pre-computed for inverse projection: dLonR = atan2(xn * rho, rho * (rho * a - yn * b))
                // where a = cosCLat * sqrt(1-rho²), b = sinCLat * rho ... still per-pixel
                // Instead store: a = cosCLat, b = yn * sinCLat for use in per-pixel formula
                cosCLat: cosCLat,
                sinCLat: sinCLat
            });
        }
        return table;
    }

    function _buildLuts(R, cx, cy) {
        var cLatR = globe.centerLatitude * Const.DEG;
        _geomLut = {
            coast: _buildGeomLut(Coast.segments, R, cLatR),
            borders: _buildGeomLut(Borders.segments, R, cLatR)
        };
        _screenLut = _buildScreenLut(cx, cy, R, cLatR);
        _lutCenterLat = globe.centerLatitude;
    }

    function _drawSegmentsFast(ctx, lut, lineWidth, strokeStyle, cLonR, cLatR) {
        ctx.strokeStyle = strokeStyle;
        ctx.lineWidth = lineWidth;
        ctx.lineJoin = Const.COASTLINE_LINE_JOIN;
        var cosCLon = Math.cos(cLonR);
        var sinCLon = Math.sin(cLonR);
        var sinCLat = Math.sin(cLatR);
        var cosCLat = Math.cos(cLatR);
        var cx = globe._cx;
        var cy = globe._cy;
        for (var s = 0; s < lut.length; s++) {
            var seg = lut[s];
            var started = false;
            ctx.beginPath();
            for (var i = 0; i < seg.length; i++) {
                var pt = seg[i];
                // x = R*cos(lat)*sin(lon-cLon)
                var x = pt.rCosLatSinLon * cosCLon - pt.rCosLatCosLon * sinCLon;
                // cos(lat)*cos(lon-cLon) — shared by y and z
                var cosLonC = pt.rCosLatCosLon * cosCLon + pt.rCosLatSinLon * sinCLon;
                var y = cosCLat * pt.rSinLat - sinCLat * cosLonC;
                var z = sinCLat * pt.rSinLat + cosCLat * cosLonC;
                if (z >= 0) {
                    var sx = cx + x;
                    var sy = cy - y;
                    if (!started) { ctx.moveTo(sx, sy); started = true; }
                    else ctx.lineTo(sx, sy);
                } else {
                    if (started) { ctx.stroke(); ctx.beginPath(); started = false; }
                }
            }
            if (started) ctx.stroke();
        }
    }

    function _drawNightSideFast(ctx, screenLut, cLonR, R, cx, cy) {
        var now = new Date();
        var ss = Solar.subsolarPoint(now);
        var ssLatR = ss.lat * Const.DEG;
        var ssLonR = ss.lon * Const.DEG;
        var sunSinLat = Math.sin(ssLatR);
        var sunCosLat = Math.cos(ssLatR);
        var sunCosLon = Math.cos(ssLonR);
        var sunSinLon = Math.sin(ssLonR);
        var step = Const.NIGHT_SCANLINE_STEP;
        ctx.fillStyle = Qt.rgba(0, 0, 0, Const.NIGHT_OPACITY);
        for (var row = 0; row < screenLut.length; row++) {
            var r = screenLut[row];
            if (r.maxDx < 1) continue;
            var sinLat = r.sinLatR;
            var cosLat = r.cosLatR;
            var cosLatSun = sunCosLat * cosLat;
            var sinLatSun = sunSinLat * sinLat;
            var ynB = r.yn * r.sinCLat;  // yn * sinCLat
            for (var px = Math.floor(cx - r.maxDx); px <= Math.ceil(cx + r.maxDx); px += step) {
                var xn = (px - cx) / R;
                var rho2 = xn * xn + r.yn2;
                // Inverse projection: dLonR = atan2(xn, cosCLat * sqrt(1-rho²) - yn * sinCLat)
                var dLonR = Math.atan2(xn, r.cosCLat * Math.sqrt(1 - rho2) - ynB);
                var lonR = cLonR + dLonR;
                var cosA = sinLatSun + cosLatSun * (sunCosLon * Math.cos(lonR) + sunSinLon * Math.sin(lonR));
                if (cosA < 0) ctx.fillRect(px, r.py, step, step);
            }
        }
    }

    function flyTo(lat, lon) {
        selectedLat = lat;
        selectedLon = lon;
        var curLon = centerLongitude;
        var diff = lon - curLon;
        while (diff > 180) diff -= 360;
        while (diff < -180) diff += 360;
        flyAnim.from = curLon;
        flyAnim.to = curLon + diff;
        flyAnim.start();
        flyLatAnim.from = centerLatitude;
        flyLatAnim.to = lat;
        flyLatAnim.start();
    }

    function clearSelection() {
        selectedLat = NaN;
        selectedLon = NaN;
        canvas.requestPaint();
    }

    function spin() {
        var cur = centerLongitude;
        spinAnim.from = cur;
        spinAnim.to = cur + 360;
        _spinFrom = cur;
        if (!_fastMode || _lutCenterLat !== centerLatitude) {
            _buildLuts(_radius, _cx, _cy);
        }
        _fastMode = true;
        spinAnim.start();
        spinTimer.start();
    }

    property real _radius: Math.min(canvas.width, canvas.height) / 2 - Const.GLOBE_MARGIN
    property real _cx: canvas.width / 2
    property real _cy: canvas.height / 2

    Canvas {
        id: canvas
        anchors.fill: parent
        renderTarget: Canvas.FramebufferObject
        renderStrategy: Canvas.Cooperative

        property real _lon: globe.centerLongitude
        property real _lat: globe.centerLatitude
        property real _selLon: globe.selectedLon
        property int _tick: 0

        // --- Rendering helpers ---

        function _drawOcean(ctx, cx, cy, R) {
            ctx.beginPath();
            ctx.arc(cx, cy, R, 0, Math.PI * 2);
            ctx.fillStyle = Qt.darker(Theme.highlightBackgroundColor, 3);
            ctx.fill();
        }

        function _inverseProject(px, py, cx, cy, R, cLatR, cLonR) {
            var dx = px - cx;
            var dy = py - cy;
            if (dx * dx + dy * dy > R * R) return null;
            var xn = dx / R;
            var yn = -dy / R;
            var rho = Math.sqrt(xn * xn + yn * yn);
            if (rho > 1) return null;
            var c = rho < 1e-10 ? 0 : Math.asin(rho);
            var cosC = Math.cos(c);
            var sinC = Math.sin(c);
            var lat, lon;
            if (rho < 1e-10) {
                lat = cLatR / Const.DEG;
                lon = cLonR / Const.DEG;
            } else {
                lat = Math.asin(cosC * Math.sin(cLatR) + yn * sinC * Math.cos(cLatR) / rho) / Const.DEG;
                lon = (cLonR + Math.atan2(xn * sinC, rho * Math.cos(cLatR) * cosC - yn * sinC * Math.sin(cLatR))) / Const.DEG;
            }
            return { lat: lat, lon: lon };
        }

        function _drawNightSide(ctx, cx, cy, R, cLat, cLon) {
            var cLatR = cLat * Const.DEG;
            var cLonR = cLon * Const.DEG;
            var now = new Date();
            var ss = Solar.subsolarPoint(now);
            var ssLatR = ss.lat * Const.DEG;
            var ssLonR = ss.lon * Const.DEG;
            var step = Const.NIGHT_SCANLINE_STEP;
            ctx.fillStyle = Qt.rgba(0, 0, 0, Const.NIGHT_OPACITY);

            for (var py = Math.floor(cy - R); py <= Math.ceil(cy + R); py += step) {
                for (var px = Math.floor(cx - R); px <= Math.ceil(cx + R); px += step) {
                    var pos = _inverseProject(px, py, cx, cy, R, cLatR, cLonR);
                    if (!pos) continue;
                    var cosA = Math.sin(ssLatR) * Math.sin(pos.lat * Const.DEG)
                             + Math.cos(ssLatR) * Math.cos(pos.lat * Const.DEG)
                             * Math.cos(pos.lon * Const.DEG - ssLonR);
                    if (cosA < 0) ctx.fillRect(px, py, step, step);
                }
            }
        }

        function _drawSegments(ctx, segments, cLat, cLon, R, cx, cy, lineWidth, strokeStyle) {
            ctx.strokeStyle = strokeStyle;
            ctx.lineWidth = lineWidth;
            ctx.lineJoin = Const.COASTLINE_LINE_JOIN;
            for (var s = 0; s < segments.length; s++) {
                var seg = segments[s];
                var started = false;
                ctx.beginPath();
                for (var i = 0; i < seg.length; i++) {
                    var p = Proj.project(seg[i][1], seg[i][0], cLat, cLon, R, cx, cy);
                    if (p) {
                        if (!started) { ctx.moveTo(p.x, p.y); started = true; }
                        else ctx.lineTo(p.x, p.y);
                    } else {
                        if (started) { ctx.stroke(); ctx.beginPath(); started = false; }
                    }
                }
                if (started) ctx.stroke();
            }
        }

        function _drawSun(ctx, sunP) {
            if (!sunP) return;
            ctx.beginPath();
            ctx.arc(sunP.x, sunP.y, Const.SUN_OUTER_RADIUS, 0, Math.PI * 2);
            ctx.fillStyle = Qt.rgba(Theme.highlightColor.r, Theme.highlightColor.g, Theme.highlightColor.b, Const.SUN_OUTER_ALPHA);
            ctx.fill();
            ctx.beginPath();
            ctx.arc(sunP.x, sunP.y, Const.SUN_INNER_RADIUS, 0, Math.PI * 2);
            ctx.fillStyle = Qt.lighter(Theme.highlightColor, 1.5);
            ctx.fill();
        }

        function _drawLocationMarkers(ctx, locs, cLat, cLon, R, cx, cy) {
            for (var li = 0; li < locs.length; li++) {
                var lp = Proj.project(locs[li].lat, locs[li].lon, cLat, cLon, R, cx, cy);
                if (!lp) continue;
                // Outer glow
                ctx.beginPath();
                ctx.arc(lp.x, lp.y, Const.LOC_OUTER_GLOW_RADIUS, 0, Math.PI * 2);
                ctx.fillStyle = "rgba(255, 255, 255, " + Const.LOC_OUTER_GLOW_ALPHA + ")";
                ctx.fill();
                // Inner glow
                ctx.beginPath();
                ctx.arc(lp.x, lp.y, Const.LOC_INNER_GLOW_RADIUS, 0, Math.PI * 2);
                ctx.fillStyle = "rgba(255, 255, 255, " + Const.LOC_INNER_GLOW_ALPHA + ")";
                ctx.fill();
                // Shadow
                ctx.beginPath();
                ctx.arc(lp.x + Const.LOC_SHADOW_OFFSET, lp.y + Const.LOC_SHADOW_OFFSET,
                        Const.LOC_SHADOW_RADIUS, 0, Math.PI * 2);
                ctx.fillStyle = "rgba(0, 0, 0, " + Const.LOC_SHADOW_ALPHA + ")";
                ctx.fill();
                // Main dot
                ctx.beginPath();
                ctx.arc(lp.x, lp.y, Const.LOC_DOT_RADIUS, 0, Math.PI * 2);
                ctx.fillStyle = Theme.highlightColor;
                ctx.fill();
                // White ring
                ctx.lineWidth = Const.LOC_RING_LINE_WIDTH;
                ctx.strokeStyle = "rgba(255, 255, 255, " + Const.LOC_RING_ALPHA + ")";
                ctx.stroke();
                // Specular
                ctx.beginPath();
                ctx.arc(lp.x - Const.LOC_SPECULAR_OFFSET, lp.y - Const.LOC_SPECULAR_OFFSET,
                        Const.LOC_SPECULAR_RADIUS, 0, Math.PI * 2);
                ctx.fillStyle = "rgba(255, 255, 255, " + Const.LOC_SPECULAR_ALPHA + ")";
                ctx.fill();
            }
        }

        function _drawSelectedPin(ctx, cLat, cLon, R, cx, cy) {
            if (!globe.hasSelection) return;
            var sp = Proj.project(globe.selectedLat, globe.selectedLon, cLat, cLon, R, cx, cy);
            if (!sp) return;
            var rdx = sp.x - cx;
            var rdy = sp.y - cy;
            var rdLen = Math.sqrt(rdx * rdx + rdy * rdy);
            if (rdLen < 1e-6) { rdx = 0; rdy = -1; rdLen = 1; }
            var rnx = rdx / rdLen;
            var rny = rdy / rdLen;
            var pinLen = R * Const.PIN_LENGTH_RATIO;
            var tipX = sp.x + rnx * pinLen;
            var tipY = sp.y + rny * pinLen;

            // Shadow
            ctx.beginPath();
            ctx.moveTo(sp.x + Const.PIN_SHADOW_OFFSET, sp.y + Const.PIN_SHADOW_OFFSET);
            ctx.lineTo(tipX + Const.PIN_SHADOW_OFFSET, tipY + Const.PIN_SHADOW_OFFSET);
            ctx.strokeStyle = Qt.rgba(0, 0, 0, Const.PIN_SHADOW_ALPHA);
            ctx.lineWidth = Const.PIN_SHADOW_LINE_WIDTH;
            ctx.stroke();

            // Gradient pin
            var grad = ctx.createLinearGradient(sp.x, sp.y, tipX, tipY);
            var hc = Theme.highlightColor;
            grad.addColorStop(0, Qt.rgba(hc.r, hc.g, hc.b, 0.9));
            grad.addColorStop(1, Qt.rgba(hc.r, hc.g, hc.b, 0.2));
            ctx.beginPath();
            ctx.moveTo(sp.x, sp.y);
            ctx.lineTo(tipX, tipY);
            ctx.strokeStyle = grad;
            ctx.lineWidth = Const.PIN_LINE_WIDTH;
            ctx.stroke();

            // Tip dot
            ctx.beginPath();
            ctx.arc(tipX, tipY, Const.PIN_TIP_RADIUS, 0, Math.PI * 2);
            ctx.fillStyle = Theme.highlightColor;
            ctx.fill();
            ctx.beginPath();
            ctx.arc(tipX - Const.PIN_TIP_SPECULAR_OFFSET, tipY - Const.PIN_TIP_SPECULAR_OFFSET,
                    Const.PIN_TIP_SPECULAR_RADIUS, 0, Math.PI * 2);
            ctx.fillStyle = Qt.rgba(1, 1, 1, Const.PIN_TIP_SPECULAR_ALPHA);
            ctx.fill();

            // Anchor dot
            ctx.beginPath();
            ctx.arc(sp.x, sp.y, Const.PIN_ANCHOR_RADIUS, 0, Math.PI * 2);
            ctx.fillStyle = Theme.highlightColor;
            ctx.fill();
        }

        function _drawGlobeRing(ctx, cx, cy, R) {
            ctx.beginPath();
            ctx.arc(cx, cy, R, 0, Math.PI * 2);
            ctx.strokeStyle = Qt.rgba(Theme.highlightColor.r, Theme.highlightColor.g,
                                      Theme.highlightColor.b, Const.GLOBE_RING_ALPHA);
            ctx.lineWidth = Const.GLOBE_RING_LINE_WIDTH;
            ctx.stroke();
        }

        onPaint: {
            var ctx = getContext("2d");
            ctx.reset();
            ctx.clearRect(0, 0, width, height);

            var R = globe._radius;
            var cx = globe._cx;
            var cy = globe._cy;
            var cLat = globe.centerLatitude;
            var cLon = globe.centerLongitude;

            _drawOcean(ctx, cx, cy, R);

            ctx.save();
            ctx.beginPath();
            ctx.arc(cx, cy, R, 0, Math.PI * 2);
            ctx.clip();

            if (globe._fastMode && _geomLut && _lutCenterLat === cLat) {
                var cLonR = cLon * Const.DEG;
                var cLatR = cLat * Const.DEG;
                _drawNightSide(ctx, cx, cy, R, cLat, cLon);
                _drawSegmentsFast(ctx, _geomLut.coast, Const.COASTLINE_LINE_WIDTH, Theme.highlightColor, cLonR, cLatR);
                _drawSegmentsFast(ctx, _geomLut.borders, Const.BORDER_LINE_WIDTH,
                    Qt.rgba(Theme.secondaryHighlightColor.r,
                            Theme.secondaryHighlightColor.g,
                            Theme.secondaryHighlightColor.b,
                            Const.BORDER_ALPHA), cLonR, cLatR);
                var ss = Solar.subsolarPoint(new Date());
                _drawSun(ctx, Proj.project(ss.lat, ss.lon, cLat, cLon, R, cx, cy));
            } else {
                _fastMode = false;
                _drawNightSide(ctx, cx, cy, R, cLat, cLon);
                _drawSegments(ctx, Coast.segments, cLat, cLon, R, cx, cy,
                              Const.COASTLINE_LINE_WIDTH, Theme.highlightColor);
                _drawSegments(ctx, Borders.segments, cLat, cLon, R, cx, cy,
                              Const.BORDER_LINE_WIDTH,
                              Qt.rgba(Theme.secondaryHighlightColor.r,
                                      Theme.secondaryHighlightColor.g,
                                      Theme.secondaryHighlightColor.b,
                                      Const.BORDER_ALPHA));
                var ss = Solar.subsolarPoint(new Date());
                _drawSun(ctx, Proj.project(ss.lat, ss.lon, cLat, cLon, R, cx, cy));
            }

            _drawLocationMarkers(ctx, globe.locations, cLat, cLon, R, cx, cy);
            _drawSelectedPin(ctx, cLat, cLon, R, cx, cy);

            ctx.restore();
            _drawGlobeRing(ctx, cx, cy, R);
        }

        Timer {
            interval: Const.AUTO_REFRESH_INTERVAL
            running: true
            repeat: true
            onTriggered: canvas._tick++
        }

        on_TickChanged: requestPaint()
        on_LonChanged: { if (!globe._fastMode) requestPaint(); }
        on_LatChanged: {
            if (globe._fastMode) {
                _buildLuts(globe._radius, globe._cx, globe._cy);
            }
            requestPaint();
        }
        on_SelLonChanged: requestPaint()
    }

    MouseArea {
        anchors.fill: parent
        property real _lastX: 0
        property real _lastY: 0
        property bool _dragging: false
        preventStealing: true

        onPressed: {
            // Only handle touches inside the globe circle;
            // let touches outside pass through for pull-down menu
            var dx = mouse.x - globe._cx;
            var dy = mouse.y - globe._cy;
            if (dx * dx + dy * dy > globe._radius * globe._radius) {
                mouse.accepted = false;
                return;
            }
            spinAnim.stop();
            spinTimer.stop();
            globe._fastMode = false;
            flyAnim.stop();
            _lastX = mouse.x;
            _lastY = mouse.y;
            _dragging = true;
        }
        onPositionChanged: {
            if (!_dragging) return;
            var dx = mouse.x - _lastX;
            var dy = mouse.y - _lastY;
            globe.centerLongitude -= dx * Const.DRAG_SENSITIVITY;
            globe.centerLatitude += dy * Const.DRAG_SENSITIVITY;
            if (globe.centerLatitude > 90) globe.centerLatitude = 90;
            if (globe.centerLatitude < -90) globe.centerLatitude = -90;
            while (globe.centerLongitude > 180) globe.centerLongitude -= 360;
            while (globe.centerLongitude < -180) globe.centerLongitude += 360;
            _lastX = mouse.x;
            _lastY = mouse.y;
        }
        onReleased: _dragging = false
        onCanceled: _dragging = false
    }

    function repaint() { canvas.requestPaint(); }
}