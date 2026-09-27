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
        spinAnim.start();
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
        on_LonChanged: requestPaint()
        on_LatChanged: requestPaint()
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