import QtQuick 2.6
import QtQuick.LocalStorage 2.0
import Sailfish.Silica 1.0
import "../components"
import "../js/solar.js" as Solar
import "../js/store.js" as Store
import "../js/constants.js" as Const
import "../js/timezone.js" as Timezone
import "../js/timeutil.js" as TimeUtil

CoverBackground {
    id: cover

    property string locationName: ""
    property string _countdownText: ""
    property bool _isNight: false
    property real _globeLon: Const.DEFAULT_CENTER_LON
    property real _globeLat: Const.DEFAULT_CENTER_LAT
    property var _locations: []

    // Mini wire globe at top
    GlobeCanvas {
        id: coverGlobe
        anchors {
            top: parent.top
            topMargin: Theme.horizontalPageMargin
            left: parent.left
            leftMargin: Theme.horizontalPageMargin
            right: parent.right
            rightMargin: Theme.horizontalPageMargin
        }
        height: width
        z: 0
        centerLongitude: cover._globeLon
        centerLatitude: cover._globeLat
        locations: cover._locations
    }

    // Labels below globe
    Column {
        id: labelsColumn
        anchors {
            top: coverGlobe.bottom
            topMargin: Theme.paddingSmall
            horizontalCenter: parent.horizontalCenter
        }
        z: 1
        spacing: 2

        Label {
            visible: cover.locationName.length > 0
            text: cover.locationName
            anchors.horizontalCenter: parent.horizontalCenter
            font.pixelSize: Theme.fontSizeSmall
            color: Theme.highlightColor
        }

        Label {
            visible: cover._countdownText.length > 0
            text: cover._countdownText
            anchors.horizontalCenter: parent.horizontalCenter
            font.pixelSize: Theme.fontSizeExtraSmall
            color: Theme.primaryColor
        }
    }

    function refreshCover() {
        try {
            var locs = Store.loadLocations();
            if (locs.length > 0) {
                var gLocs = [];
                for (var i = 0; i < locs.length; i++)
                    gLocs.push({ lat: locs[i].lat, lon: locs[i].lon });
                cover._locations = gLocs;
            }
            if (locs.length === 0) {
                cover.locationName = "";
                cover._countdownText = "";
                cover._globeLon = Const.DEFAULT_CENTER_LON;
                cover._globeLat = Const.DEFAULT_CENTER_LAT;
                coverGlobe.repaint();
                return;
            }
            var coverId = Store.loadCoverLocationId();
            var loc = locs[0];
            for (var i = 0; i < locs.length; i++) {
                if (locs[i].id === coverId) { loc = locs[i]; break; }
            }
            cover._globeLon = loc.lon;
            cover._globeLat = loc.lat;
            coverGlobe.repaint();
            cover.locationName = loc.name;

            var now = new Date();
            var data = Solar.solarData(now, loc.lat, loc.lon);

            if (data.polarDay) {
                cover._isNight = false;
                cover._countdownText = qsTr("Polar day");
                return;
            }
            if (data.polarNight) {
                cover._isNight = true;
                cover._countdownText = qsTr("Polar night");
                return;
            }

            var isNight = (now < data.sunrise || now > data.sunset);
            cover._isNight = isNight;

            var nextMs = Solar.nextChangeMs(now, data, isNight, loc.lat, loc.lon);
            if (nextMs !== null) {
                var cd = TimeUtil.formatCountdown(nextMs - now.getTime());
                var label = isNight ? qsTr("day") : qsTr("night");
                cover._countdownText = label + " \u2192 " + (cd || qsTr("now"));
            } else {
                cover._countdownText = "";
            }
        } catch (e) {
            console.warn("CoverPage: refreshCover failed (" + e.message + ")");
            cover.locationName = "";
            cover._countdownText = "";
        }
    }

    Component.onCompleted: refreshCover()

    // Refresh every minute for accurate countdown
    Timer {
        interval: Const.AUTO_REFRESH_INTERVAL
        running: true
        repeat: true
        onTriggered: refreshCover()
    }

    onStatusChanged: {
        if (status === Cover.Active) {
            refreshCover();
        }
    }

    CoverActionList {
        id: coverActions
    }
}