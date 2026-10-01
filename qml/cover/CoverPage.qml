import QtQuick 2.6
import Sailfish.Silica 1.0
import "../js/solar.js" as Solar
import "../js/store.js" as Store
import "../js/constants.js" as Const
import "../js/timezone.js" as Timezone

CoverBackground {
    id: cover

    property string nextEvent: ""
    property string nextTime: ""
    property string locationName: ""

    Column {
        anchors.centerIn: parent
        spacing: Theme.paddingSmall

        // Sun icon
        Canvas {
            width: Const.COVER_CANVAS_SIZE
            height: Const.COVER_CANVAS_SIZE
            anchors.horizontalCenter: parent.horizontalCenter

            onPaint: {
                var ctx = getContext("2d");
                var size = Const.COVER_CANVAS_SIZE;
                ctx.clearRect(0, 0, size, size);
                var half = size / 2;

                // Sun circle
                ctx.beginPath();
                ctx.arc(half, half, Const.COVER_SUN_RADIUS, 0, Math.PI * 2);
                ctx.fillStyle = Theme.highlightColor;
                ctx.fill();

                // Rays
                ctx.strokeStyle = Theme.highlightColor;
                ctx.lineWidth = Const.COVER_RAY_LINE_WIDTH;
                for (var i = 0; i < Const.COVER_RAY_COUNT; i++) {
                    var angle = (i / Const.COVER_RAY_COUNT) * Math.PI * 2;
                    ctx.beginPath();
                    ctx.moveTo(half + Math.cos(angle) * Const.COVER_RAY_INNER,
                               half + Math.sin(angle) * Const.COVER_RAY_INNER);
                    ctx.lineTo(half + Math.cos(angle) * Const.COVER_RAY_OUTER,
                               half + Math.sin(angle) * Const.COVER_RAY_OUTER);
                    ctx.stroke();
                }
            }
        }

        Label {
            text: qsTr("Shadow Line")
            anchors.horizontalCenter: parent.horizontalCenter
            font.pixelSize: Theme.fontSizeMedium
            color: Theme.highlightColor
        }

        Label {
            visible: cover.locationName.length > 0
            text: cover.locationName
            anchors.horizontalCenter: parent.horizontalCenter
            font.pixelSize: Theme.fontSizeSmall
            color: Theme.primaryColor
        }

        Label {
            visible: cover.nextEvent.length > 0
            text: cover.nextEvent + " " + cover.nextTime
            anchors.horizontalCenter: parent.horizontalCenter
            font.pixelSize: Theme.fontSizeExtraSmall
            color: Theme.secondaryColor
        }
    }

    // Load first location from DB and compute next event
    function refreshCover() {
        try {
            var locs = Store.loadLocations();
            if (locs.length === 0) {
                cover.locationName = "";
                cover.nextEvent = "";
                cover.nextTime = "";
                return;
            }
            var loc = locs[0];
            cover.locationName = loc.name;

            // Compute offset for this location
            var offset = Timezone.totalOffset(loc.off, loc.lat);
            if (offset === null) offset = Timezone.longitudeFallbackOffset(loc.lon);

            var data = Solar.solarData(new Date(), loc.lat, loc.lon);
            if (data.polarDay) {
                cover.nextEvent = qsTr("Polar day");
                cover.nextTime = "";
            } else if (data.polarNight) {
                cover.nextEvent = qsTr("Polar night");
                cover.nextTime = "";
            } else {
                var now = new Date();
                if (data.sunrise && data.sunrise > now) {
                    cover.nextEvent = "\u2191"; // ↑
                    cover.nextTime = Solar.formatTimeInZone(data.sunrise, offset);
                } else if (data.sunset && data.sunset > now) {
                    cover.nextEvent = "\u2193"; // ↓
                    cover.nextTime = Solar.formatTimeInZone(data.sunset, offset);
                } else {
                    cover.nextEvent = "\u2191";
                    var tomorrow = new Date(now);
                    tomorrow.setDate(tomorrow.getDate() + 1);
                    var td = Solar.solarData(tomorrow, loc.lat, loc.lon);
                    cover.nextTime = Solar.formatTimeInZone(td.sunrise, offset);
                }
            }
        } catch (e) {
            console.warn("CoverPage: refreshCover failed (" + e.message + ")");
            cover.locationName = "";
            cover.nextEvent = "";
            cover.nextTime = "";
        }
    }

    Component.onCompleted: refreshCover()

    // Refresh cover every 5 minutes
    Timer {
        interval: Const.COVER_REFRESH_INTERVAL
        running: true
        repeat: true
        onTriggered: refreshCover()
    }

    // Also refresh when cover becomes visible
    onStatusChanged: {
        if (status === Cover.Active) {
            refreshCover();
        }
    }

    CoverActionList {
        id: coverActions
    }
}