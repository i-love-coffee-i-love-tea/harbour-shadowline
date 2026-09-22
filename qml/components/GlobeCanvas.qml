import QtQuick 2.6
import Sailfish.Silica 1.0
import "../js/projection.js" as Proj
import "../js/coastlines.js" as Coast
import "../js/borders.js" as Borders
import "../js/solar.js" as Solar

Item {
    id: globe

    property real centerLatitude: 25.0
    property real centerLongitude: 30.0
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

    property real _radius: Math.min(canvas.width, canvas.height) / 2 - 4
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

        onPaint: {
            var ctx = getContext("2d");
            ctx.reset();
            ctx.clearRect(0, 0, width, height);

            var R = globe._radius;
            var cx = globe._cx;
            var cy = globe._cy;
            var cLat = globe.centerLatitude;
            var cLon = globe.centerLongitude;
            var cLatR = cLat * Proj.DEG;
            var cLonR = cLon * Proj.DEG;

            // --- 1. Ocean ---
            ctx.beginPath();
            ctx.arc(cx, cy, R, 0, Math.PI * 2);
            ctx.fillStyle = Qt.darker(Theme.highlightBackgroundColor, 3);
            ctx.fill();

            ctx.save();
            ctx.beginPath();
            ctx.arc(cx, cy, R, 0, Math.PI * 2);
            ctx.clip();

            // --- 2. Night side (scanline, step=6) ---
            var now = new Date();
            var ss = Solar.subsolarPoint(now);
            var ssLatR = ss.lat * Proj.DEG;
            var ssLonR = ss.lon * Proj.DEG;
            var step = 6;
            ctx.fillStyle = Qt.rgba(0, 0, 0, 0.45);

            for (var py = Math.floor(cy - R); py <= Math.ceil(cy + R); py += step) {
                for (var px = Math.floor(cx - R); px <= Math.ceil(cx + R); px += step) {
                    var dx = px - cx;
                    var dy = py - cy;
                    if (dx * dx + dy * dy > R * R) continue;
                    var xn = dx / R;
                    var yn = -dy / R;
                    var rho = Math.sqrt(xn * xn + yn * yn);
                    if (rho > 1) continue;
                    var c = rho < 1e-10 ? 0 : Math.asin(rho);
                    var cosC = Math.cos(c);
                    var sinC = Math.sin(c);
                    var lat, lon;
                    if (rho < 1e-10) {
                        lat = cLat; lon = cLon;
                    } else {
                        lat = Math.asin(cosC * Math.sin(cLatR) + yn * sinC * Math.cos(cLatR) / rho) / Proj.DEG;
                        lon = (cLonR + Math.atan2(xn * sinC, rho * Math.cos(cLatR) * cosC - yn * sinC * Math.sin(cLatR))) / Proj.DEG;
                    }
                    var cosA = Math.sin(ssLatR) * Math.sin(lat * Proj.DEG)
                             + Math.cos(ssLatR) * Math.cos(lat * Proj.DEG) * Math.cos(lon * Proj.DEG - ssLonR);
                    if (cosA < 0) ctx.fillRect(px, py, step, step);
                }
            }

            // --- 3. Coastlines ---
            ctx.strokeStyle = Theme.highlightColor;
            ctx.lineWidth = 1.2;
            ctx.lineJoin = "round";
            var segments = Coast.segments;
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

            // --- 3b. Borders ---
            ctx.strokeStyle = Qt.rgba(Theme.secondaryHighlightColor.r, Theme.secondaryHighlightColor.g, Theme.secondaryHighlightColor.b, 0.35);
            ctx.lineWidth = 0.7;
            ctx.lineJoin = "round";
            var borderSegs = Borders.segments;
            for (var bs = 0; bs < borderSegs.length; bs++) {
                var bseg = borderSegs[bs];
                var bstarted = false;
                ctx.beginPath();
                for (var bi = 0; bi < bseg.length; bi++) {
                    var bp = Proj.project(bseg[bi][1], bseg[bi][0], cLat, cLon, R, cx, cy);
                    if (bp) {
                        if (!bstarted) { ctx.moveTo(bp.x, bp.y); bstarted = true; }
                        else ctx.lineTo(bp.x, bp.y);
                    } else {
                        if (bstarted) { ctx.stroke(); ctx.beginPath(); bstarted = false; }
                    }
                }
                if (bstarted) ctx.stroke();
            }

            // --- 4. Sun ---
            var sunP = Proj.project(ss.lat, ss.lon, cLat, cLon, R, cx, cy);
            if (sunP) {
                ctx.beginPath();
                ctx.arc(sunP.x, sunP.y, 9, 0, Math.PI * 2);
                ctx.fillStyle = Qt.rgba(Theme.highlightColor.r, Theme.highlightColor.g, Theme.highlightColor.b, 0.3);
                ctx.fill();
                ctx.beginPath();
                ctx.arc(sunP.x, sunP.y, 5, 0, Math.PI * 2);
                ctx.fillStyle = Qt.lighter(Theme.highlightColor, 1.5);
                ctx.fill();
            }

            // --- 5. Location dots ---
            var locs = globe.locations;
            for (var li = 0; li < locs.length; li++) {
                var loc = locs[li];
                var lp = Proj.project(loc.lat, loc.lon, cLat, cLon, R, cx, cy);
                if (lp) {
                    ctx.beginPath();
                    ctx.arc(lp.x, lp.y, 3.5, 0, Math.PI * 2);
                    ctx.fillStyle = Theme.primaryColor;
                    ctx.fill();
                    ctx.strokeStyle = Theme.highlightColor;
                    ctx.lineWidth = 1;
                    ctx.stroke();
                }
            }

            // --- 6. Selected pin ---
            if (globe.hasSelection) {
                var sp = Proj.project(globe.selectedLat, globe.selectedLon, cLat, cLon, R, cx, cy);
                if (sp) {
                    var rdx = sp.x - cx;
                    var rdy = sp.y - cy;
                    var rdLen = Math.sqrt(rdx * rdx + rdy * rdy);
                    if (rdLen < 1e-6) { rdx = 0; rdy = -1; rdLen = 1; }
                    var rnx = rdx / rdLen;
                    var rny = rdy / rdLen;
                    var pinLen = R * 0.25;
                    var tipX = sp.x + rnx * pinLen;
                    var tipY = sp.y + rny * pinLen;

                    ctx.beginPath();
                    ctx.moveTo(sp.x + 1, sp.y + 1);
                    ctx.lineTo(tipX + 1, tipY + 1);
                    ctx.strokeStyle = Qt.rgba(0, 0, 0, 0.3);
                    ctx.lineWidth = 2.5;
                    ctx.stroke();

                    var grad = ctx.createLinearGradient(sp.x, sp.y, tipX, tipY);
                    var hc = Theme.highlightColor;
                    grad.addColorStop(0, Qt.rgba(hc.r, hc.g, hc.b, 0.9));
                    grad.addColorStop(1, Qt.rgba(hc.r, hc.g, hc.b, 0.2));
                    ctx.beginPath();
                    ctx.moveTo(sp.x, sp.y);
                    ctx.lineTo(tipX, tipY);
                    ctx.strokeStyle = grad;
                    ctx.lineWidth = 2;
                    ctx.stroke();

                    ctx.beginPath();
                    ctx.arc(tipX, tipY, 5, 0, Math.PI * 2);
                    ctx.fillStyle = Theme.highlightColor;
                    ctx.fill();
                    ctx.beginPath();
                    ctx.arc(tipX - 1.5, tipY - 1.5, 2, 0, Math.PI * 2);
                    ctx.fillStyle = Qt.rgba(1, 1, 1, 0.4);
                    ctx.fill();

                    ctx.beginPath();
                    ctx.arc(sp.x, sp.y, 4, 0, Math.PI * 2);
                    ctx.fillStyle = Theme.highlightColor;
                    ctx.fill();
                }
            }

            // --- 7. Globe ring ---
            ctx.restore();
            ctx.beginPath();
            ctx.arc(cx, cy, R, 0, Math.PI * 2);
            ctx.strokeStyle = Qt.rgba(Theme.highlightColor.r, Theme.highlightColor.g, Theme.highlightColor.b, 0.4);
            ctx.lineWidth = 1.5;
            ctx.stroke();
        }

        Timer {
            interval: 60000
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
            globe.centerLongitude -= dx * 0.3;
            globe.centerLatitude += dy * 0.3;
            // Clamp latitude
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
