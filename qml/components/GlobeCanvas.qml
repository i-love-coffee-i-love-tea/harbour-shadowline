import QtQuick 2.6
import Sailfish.Silica 1.0
import Harbour.Shadowline 1.0
import "../js/projection.js" as Proj
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
    property bool _isDragging: false
    property real _spinFrom: 0
    property real spinProgress: isSpinning ? ((centerLongitude - _spinFrom) / 360 % 1 + 1) % 1 : 0

    property real _radius: Math.min(width, height) / 2 - Const.GLOBE_MARGIN
    property real _cx: width / 2
    property real _cy: height / 2

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

    // --- GLES globe (globe surface + day/night illumination + coastlines + borders + ring) ---
    GlobeItem {
        id: globeRenderer
        anchors.fill: parent
        centerLatitude: globe.centerLatitude
        centerLongitude: globe.centerLongitude
        oceanColor: Qt.tint(Qt.rgba(0.04, 0.08, 0.12, 1.0), Qt.rgba(Theme.highlightColor.r, Theme.highlightColor.g, Theme.highlightColor.b, 0.15))
        nightColor: Qt.rgba(0, 0, 0, Const.NIGHT_OPACITY)
        coastColor: Theme.highlightColor
        sunColor: Theme.highlightColor
        borderColor: Qt.rgba(Theme.secondaryHighlightColor.r,
                             Theme.secondaryHighlightColor.g,
                             Theme.secondaryHighlightColor.b,
                             Const.BORDER_ALPHA)
        ringColor: Qt.rgba(Theme.highlightColor.r,
                           Theme.highlightColor.g,
                           Theme.highlightColor.b,
                           Const.GLOBE_RING_ALPHA)
    }

    // --- Canvas overlay for sun, markers, pin ---
    Canvas {
        id: overlay
        anchors.fill: parent
        renderTarget: Canvas.FramebufferObject
        renderStrategy: Canvas.Cooperative

        property real _lon: globe.centerLongitude
        property real _lat: globe.centerLatitude
        property real _selLon: globe.selectedLon
        property int _tick: 0

        function _drawSun(ctx, sunP) {
            if (!sunP) return;
            ctx.beginPath();
            ctx.arc(sunP.x, sunP.y, Const.SUN_OUTER_RADIUS, 0, Math.PI * 2);
            ctx.fillStyle = Qt.rgba(Theme.highlightColor.r, Theme.highlightColor.g,
                                    Theme.highlightColor.b, Const.SUN_OUTER_ALPHA);
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
                ctx.beginPath();
                ctx.arc(lp.x, lp.y, Const.LOC_OUTER_GLOW_RADIUS, 0, Math.PI * 2);
                ctx.fillStyle = "rgba(255, 255, 255, " + Const.LOC_OUTER_GLOW_ALPHA + ")";
                ctx.fill();
                ctx.beginPath();
                ctx.arc(lp.x, lp.y, Const.LOC_INNER_GLOW_RADIUS, 0, Math.PI * 2);
                ctx.fillStyle = "rgba(255, 255, 255, " + Const.LOC_INNER_GLOW_ALPHA + ")";
                ctx.fill();
                ctx.beginPath();
                ctx.arc(lp.x + Const.LOC_SHADOW_OFFSET, lp.y + Const.LOC_SHADOW_OFFSET,
                        Const.LOC_SHADOW_RADIUS, 0, Math.PI * 2);
                ctx.fillStyle = "rgba(0, 0, 0, " + Const.LOC_SHADOW_ALPHA + ")";
                ctx.fill();
                ctx.beginPath();
                ctx.arc(lp.x, lp.y, Const.LOC_DOT_RADIUS, 0, Math.PI * 2);
                ctx.fillStyle = Theme.highlightColor;
                ctx.fill();
                ctx.lineWidth = Const.LOC_RING_LINE_WIDTH;
                ctx.strokeStyle = "rgba(255, 255, 255, " + Const.LOC_RING_ALPHA + ")";
                ctx.stroke();
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

            ctx.beginPath();
            ctx.moveTo(sp.x + Const.PIN_SHADOW_OFFSET, sp.y + Const.PIN_SHADOW_OFFSET);
            ctx.lineTo(tipX + Const.PIN_SHADOW_OFFSET, tipY + Const.PIN_SHADOW_OFFSET);
            ctx.strokeStyle = Qt.rgba(0, 0, 0, Const.PIN_SHADOW_ALPHA);
            ctx.lineWidth = Const.PIN_SHADOW_LINE_WIDTH;
            ctx.stroke();

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

            ctx.beginPath();
            ctx.arc(tipX, tipY, Const.PIN_TIP_RADIUS, 0, Math.PI * 2);
            ctx.fillStyle = Theme.highlightColor;
            ctx.fill();
            ctx.beginPath();
            ctx.arc(tipX - Const.PIN_TIP_SPECULAR_OFFSET, tipY - Const.PIN_TIP_SPECULAR_OFFSET,
                    Const.PIN_TIP_SPECULAR_RADIUS, 0, Math.PI * 2);
            ctx.fillStyle = Qt.rgba(1, 1, 1, Const.PIN_TIP_SPECULAR_ALPHA);
            ctx.fill();

            ctx.beginPath();
            ctx.arc(sp.x, sp.y, Const.PIN_ANCHOR_RADIUS, 0, Math.PI * 2);
            ctx.fillStyle = Theme.highlightColor;
            ctx.fill();
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
            var ss = Solar.subsolarPoint(new Date());

            ctx.save();
            ctx.beginPath();
            ctx.arc(cx, cy, R, 0, Math.PI * 2);
            ctx.clip();

            _drawSun(ctx, Proj.project(ss.lat, ss.lon, cLat, cLon, R, cx, cy));
            _drawLocationMarkers(ctx, globe.locations, cLat, cLon, R, cx, cy);
            _drawSelectedPin(ctx, cLat, cLon, R, cx, cy);

            ctx.restore();
        }

        Timer {
            interval: Const.AUTO_REFRESH_INTERVAL
            running: true
            repeat: true
            onTriggered: overlay._tick++
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
            var dx = mouse.x - globe._cx;
            var dy = mouse.y - globe._cy;
            if (dx * dx + dy * dy > globe._radius * globe._radius) {
                mouse.accepted = false;
                return;
            }
            globe._isDragging = true;
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
        onReleased: { _dragging = false; globe._isDragging = false; }
        onCanceled: { _dragging = false; globe._isDragging = false; }
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
        overlay.requestPaint();
    }

    function spin() {
        var cur = centerLongitude;
        spinAnim.from = cur;
        spinAnim.to = cur + 360;
        _spinFrom = cur;
        spinAnim.start();
    }

    function repaint() { overlay.requestPaint(); }
}