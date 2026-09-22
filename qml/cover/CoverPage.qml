import QtQuick 2.6
import Sailfish.Silica 1.0
import QtQuick.LocalStorage 2.0
import "../js/solar.js" as Solar

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
            width: 80
            height: 80
            anchors.horizontalCenter: parent.horizontalCenter

            onPaint: {
                var ctx = getContext("2d");
                ctx.clearRect(0, 0, 80, 80);

                // Sun circle
                ctx.beginPath();
                ctx.arc(40, 40, 12, 0, Math.PI * 2);
                ctx.fillStyle = Theme.highlightColor;
                ctx.fill();

                // Rays
                ctx.strokeStyle = Theme.highlightColor;
                ctx.lineWidth = 2;
                for (var i = 0; i < 8; i++) {
                    var angle = (i / 8) * Math.PI * 2;
                    ctx.beginPath();
                    ctx.moveTo(40 + Math.cos(angle) * 18, 40 + Math.sin(angle) * 18);
                    ctx.lineTo(40 + Math.cos(angle) * 26, 40 + Math.sin(angle) * 26);
                    ctx.stroke();
                }
            }
        }

        Label {
            text: "Shadow Line"
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
            var db = LocalStorage.openDatabaseSync("harbour-shadowline", "1.0",
                                                    "Shadow Line locations", 1000000);
            db.readTransaction(function(tx) {
                var rs = tx.executeSql("SELECT name, lat, lon FROM locations ORDER BY sort_order, id LIMIT 1");
                if (rs.rows.length === 0) {
                    cover.locationName = "";
                    cover.nextEvent = "";
                    cover.nextTime = "";
                    return;
                }
                var loc = rs.rows.item(0);
                cover.locationName = loc.name;

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
                        cover.nextTime = Solar.formatTime(data.sunrise);
                    } else if (data.sunset && data.sunset > now) {
                        cover.nextEvent = "\u2193"; // ↓
                        cover.nextTime = Solar.formatTime(data.sunset);
                    } else {
                        cover.nextEvent = "\u2191";
                        var tomorrow = new Date(now);
                        tomorrow.setDate(tomorrow.getDate() + 1);
                        var td = Solar.solarData(tomorrow, loc.lat, loc.lon);
                        cover.nextTime = Solar.formatTime(td.sunrise);
                    }
                }
            });
        } catch (e) {
            cover.locationName = "";
            cover.nextEvent = "";
            cover.nextTime = "";
        }
    }

    Component.onCompleted: refreshCover()

    // Refresh cover every 5 minutes
    Timer {
        interval: 300000
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
