import QtQuick 2.6
import Sailfish.Silica 1.0
import "../js/solar.js" as Solar
import "../js/timezone.js" as Timezone
import "../js/timeutil.js" as TimeUtil

ListItem {
    id: locationItem

    property string locationName: ""
    property real locationLat: 0
    property real locationLon: 0
    property var locationOff: null  // {o: utcOffsetHours, d: dstFlag} or null
    property bool _isNight: false
    property string _dayLength: ""
    property string _currentTime: ""
    property string _timeUntilChange: ""
    property bool _isPolarDay: false
    property bool _isPolarNight: false
    property bool _transitionNow: false

    property string _statusText: {
        if (_isPolarDay) return qsTr("Polar day • 24h daylight");
        if (_isPolarNight) return qsTr("Polar night • No daylight");
        if (_transitionNow) {
            return _isNight ? (_dayLength !== "" ? qsTr("Sunrise now • %1 daylight").arg(_dayLength) : qsTr("Sunrise now"))
                            : (_dayLength !== "" ? qsTr("Sunset now • %1 daylight").arg(_dayLength) : qsTr("Sunset now"));
        }
        if (_timeUntilChange !== "") {
            return _isNight ? (_dayLength !== "" ? qsTr("Sunrise in %1 • %2 daylight").arg(_timeUntilChange).arg(_dayLength) : qsTr("Sunrise in %1").arg(_timeUntilChange))
                            : (_dayLength !== "" ? qsTr("Sunset in %1 • %2 daylight").arg(_timeUntilChange).arg(_dayLength) : qsTr("Sunset in %1").arg(_timeUntilChange));
        }
        return _dayLength !== "" ? qsTr("%1 daylight").arg(_dayLength) : "";
    }

    contentHeight: mainRow.height + 2 * Theme.paddingSmall

    Row {
        id: mainRow
        anchors {
            left: parent.left
            leftMargin: Theme.horizontalPageMargin
            right: parent.right
            rightMargin: Theme.horizontalPageMargin
            top: parent.top
            topMargin: Theme.paddingSmall
        }
        spacing: Theme.paddingMedium

        // Day/night icon
        Image {
            width: Theme.iconSizeMedium
            height: Theme.iconSizeMedium
            anchors.verticalCenter: parent.verticalCenter
            source: _isNight ? "image://theme/icon-m-night" : "image://theme/icon-m-day"
        }

        // Location name + current time + day length + countdown
        Column {
            width: parent.width - Theme.iconSizeMedium - timesColumn.width - 2 * Theme.paddingMedium
            anchors.verticalCenter: parent.verticalCenter

            Label {
                width: parent.width
                text: locationName
                color: locationItem.highlighted ? Theme.highlightColor : Theme.primaryColor
                font.pixelSize: Theme.fontSizeMedium
                truncationMode: TruncationMode.Fade
            }

            Label {
                width: parent.width
                text: _currentTime + "  \u2022  " + locationLat.toFixed(1) + "\u00B0" + (locationLat >= 0 ? "N" : "S") + "  "
                      + Math.abs(locationLon).toFixed(1) + "\u00B0" + (locationLon >= 0 ? "E" : "W")
                color: Theme.highlightColor
                font.pixelSize: Theme.fontSizeExtraSmall
                truncationMode: TruncationMode.Fade
            }

            Label {
                width: parent.width
                text: _statusText
                color: Theme.secondaryColor
                font.pixelSize: Theme.fontSizeExtraSmall
                truncationMode: TruncationMode.Fade
            }
        }

        // Sunrise / Solar noon / Sunset
        Column {
            id: timesColumn
            anchors.verticalCenter: parent.verticalCenter
            width: Theme.itemSizeLarge

            Row {
                visible: !_isPolarDay && !_isPolarNight
                spacing: Theme.paddingSmall
                anchors.right: parent.right

                Label {
                    text: "\u2191"
                    color: Theme.highlightColor
                    font.pixelSize: Theme.fontSizeSmall
                    anchors.verticalCenter: parent.verticalCenter
                }
                Label {
                    id: sunriseLabel
                    color: Theme.primaryColor
                    font.pixelSize: Theme.fontSizeSmall
                    anchors.verticalCenter: parent.verticalCenter
                }
            }

            Row {
                visible: !_isPolarDay && !_isPolarNight
                spacing: Theme.paddingSmall
                anchors.right: parent.right

                Label {
                    text: qsTr("noon")
                    color: Theme.secondaryHighlightColor
                    font.pixelSize: Theme.fontSizeExtraSmall
                    anchors.verticalCenter: parent.verticalCenter
                }
                Label {
                    id: solarNoonLabel
                    color: Theme.primaryColor
                    font.pixelSize: Theme.fontSizeSmall
                    anchors.verticalCenter: parent.verticalCenter
                }
            }

            Row {
                visible: !_isPolarDay && !_isPolarNight
                spacing: Theme.paddingSmall
                anchors.right: parent.right

                Label {
                    text: "\u2193"
                    color: Theme.secondaryHighlightColor
                    font.pixelSize: Theme.fontSizeSmall
                    anchors.verticalCenter: parent.verticalCenter
                }
                Label {
                    id: sunsetLabel
                    color: Theme.primaryColor
                    font.pixelSize: Theme.fontSizeSmall
                    anchors.verticalCenter: parent.verticalCenter
                }
            }

            Label {
                anchors.right: parent.right
                visible: _isPolarDay || _isPolarNight
                text: _isPolarDay ? qsTr("Polar day") : qsTr("Polar night")
                color: Theme.secondaryHighlightColor
                font.pixelSize: Theme.fontSizeSmall
            }
        }
    }

    function _formatDuration(minutes) {
        var h = Math.floor(minutes / 60);
        var m = Math.round(minutes % 60);
        return h + "h " + m + "m";
    }

    function updateTimes() {
        try {
        var now = new Date();
        var data = Solar.solarData(now, locationLat, locationLon);
        _currentTime = Timezone.getLocalTime(locationOff, locationLat, locationLon);

        if (data.polarDay) {
            _isPolarDay = true;
            _isPolarNight = false;
            _transitionNow = false;
            _isNight = false;
            _dayLength = "24h 0m";
            _timeUntilChange = "";
            sunriseLabel.text = "";
            sunsetLabel.text = "";
            solarNoonLabel.text = "";
            return;
        }

        if (data.polarNight) {
            _isPolarDay = false;
            _isPolarNight = true;
            _transitionNow = false;
            _isNight = true;
            _dayLength = "0h 0m";
            _timeUntilChange = "";
            sunriseLabel.text = "";
            sunsetLabel.text = "";
            solarNoonLabel.text = "";
            return;
        }

        // Normal case
        _isPolarDay = false;
        _isPolarNight = false;
        sunriseLabel.text = Timezone.formatLocationTime(data.sunrise, locationOff, locationLat, locationLon);
        sunsetLabel.text = Timezone.formatLocationTime(data.sunset, locationOff, locationLat, locationLon);
        solarNoonLabel.text = Timezone.formatLocationTime(data.solarNoon, locationOff, locationLat, locationLon);
        _isNight = (now < data.sunrise || now > data.sunset);

        var diffMs = data.sunset.getTime() - data.sunrise.getTime();
        _dayLength = _formatDuration(diffMs / 60000);

        var nextMs = Solar.nextChangeMs(now, data, _isNight, locationLat, locationLon);
        if (nextMs !== null) {
            var remainingMs = nextMs - now.getTime();
            if (TimeUtil.isTransitionImminent(remainingMs)) {
                _transitionNow = true;
                _timeUntilChange = "";
            } else {
                _transitionNow = false;
                _timeUntilChange = TimeUtil.formatCountdown(remainingMs) || "";
            }
        } else {
            _transitionNow = false;
            _timeUntilChange = "";
        }
        } catch (e) {
            console.warn("LocationListItem: updateTimes failed for " + locationName + " (" + e.message + ")");
            _isPolarDay = false;
            _isPolarNight = false;
            _transitionNow = false;
            _timeUntilChange = "";
            sunriseLabel.text = "--:--";
            sunsetLabel.text = "--:--";
            solarNoonLabel.text = "--:--";
        }
    }

    function refresh() { updateTimes(); }

    Component.onCompleted: { updateTimes(); }
}