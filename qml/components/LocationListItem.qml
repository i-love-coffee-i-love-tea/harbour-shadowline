import QtQuick 2.6
import Sailfish.Silica 1.0
import "../js/solar.js" as Solar
import "../js/timezone.js" as Timezone

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
                text: _currentTime + "  \u2022  " + locationLat.toFixed(1) + "\u00B0" + (locationLat >= 0 ? "N" : "S") + "  "
                      + Math.abs(locationLon).toFixed(1) + "\u00B0" + (locationLon >= 0 ? "E" : "W")
                color: Theme.highlightColor
                font.pixelSize: Theme.fontSizeExtraSmall
            }

            Label {
                text: _timeUntilChange !== ""
                      ? qsTr("in %1: %2 (%3)").arg(_timeUntilChange).arg(_isNight ? qsTr("day") : qsTr("night")).arg(_dayLength)
                      : (_dayLength !== "" ? qsTr("day %1").arg(_dayLength) : "")
                color: Theme.secondaryColor
                font.pixelSize: Theme.fontSizeExtraSmall
            }
        }

        // Sunrise / Solar noon / Sunset
        Column {
            id: timesColumn
            anchors.verticalCenter: parent.verticalCenter
            width: Theme.itemSizeLarge

            Row {
                spacing: Theme.paddingSmall
                anchors.right: parent.right

                Label {
                    text: "\u2191"
                    color: Theme.highlightColor
                    font.pixelSize: Theme.fontSizeSmall
                }
                Label {
                    id: sunriseLabel
                    color: Theme.primaryColor
                    font.pixelSize: Theme.fontSizeSmall
                }
            }

            Row {
                spacing: Theme.paddingSmall
                anchors.right: parent.right

                Label {
                    text: "\u2299"
                    color: Theme.secondaryHighlightColor
                    font.pixelSize: Theme.fontSizeSmall
                }
                Label {
                    id: solarNoonLabel
                    color: Theme.primaryColor
                    font.pixelSize: Theme.fontSizeSmall
                }
            }

            Row {
                spacing: Theme.paddingSmall
                anchors.right: parent.right

                Label {
                    text: "\u2193"
                    color: Theme.secondaryHighlightColor
                    font.pixelSize: Theme.fontSizeSmall
                }
                Label {
                    id: sunsetLabel
                    color: Theme.primaryColor
                    font.pixelSize: Theme.fontSizeSmall
                }
            }
        }
    }

    function _formatDuration(minutes) {
        var h = Math.floor(minutes / 60);
        var m = Math.round(minutes % 60);
        return h + "h " + m + "m";
    }

    function _formatCountdown(ms) {
        if (ms <= 0) return qsTr("now");
        var totalMin = Math.floor(ms / 60000);
        var h = Math.floor(totalMin / 60);
        var m = totalMin % 60;
        if (h > 0) return h + "h " + m + "m";
        return m + "m";
    }

    function _computeNextChangeTime(now, data) {
        if (_isNight) {
            if (now > data.sunset) {
                var tomorrow = new Date(now.getTime() + 86400000);
                var tomorrowData = Solar.solarData(tomorrow, locationLat, locationLon);
                return tomorrowData.sunrise ? tomorrowData.sunrise.getTime() : null;
            }
            return data.sunrise ? data.sunrise.getTime() : null;
        }
        return data.sunset ? data.sunset.getTime() : null;
    }

    function updateTimes() {
        try {
        var now = new Date();
        var data = Solar.solarData(now, locationLat, locationLon);
        _currentTime = Timezone.getLocalTime(locationOff, locationLat, locationLon);

        if (data.polarDay) {
            sunriseLabel.text = qsTr("Polar day");
            sunsetLabel.text = "";
            solarNoonLabel.text = "--:--";
            _isNight = false;
            _dayLength = "24h 0m";
            _timeUntilChange = "";
            return;
        }

        if (data.polarNight) {
            sunriseLabel.text = qsTr("Polar night");
            sunsetLabel.text = "";
            solarNoonLabel.text = "--:--";
            _isNight = true;
            _dayLength = "0h 0m";
            _timeUntilChange = "";
            return;
        }

        // Normal case
        sunriseLabel.text = Timezone.formatLocationTime(data.sunrise, locationOff, locationLat, locationLon);
        sunsetLabel.text = Timezone.formatLocationTime(data.sunset, locationOff, locationLat, locationLon);
        solarNoonLabel.text = Timezone.formatLocationTime(data.solarNoon, locationOff, locationLat, locationLon);
        _isNight = (now < data.sunrise || now > data.sunset);

        var diffMs = data.sunset.getTime() - data.sunrise.getTime();
        _dayLength = _formatDuration(diffMs / 60000);

        var nextChangeMs = _computeNextChangeTime(now, data);
        if (nextChangeMs !== null) {
            _timeUntilChange = _formatCountdown(nextChangeMs - now.getTime());
        } else {
            _timeUntilChange = "";
        }
        } catch (e) {
            console.warn("LocationListItem: updateTimes failed for " + locationName + " (" + e.message + ")");
            sunriseLabel.text = "--:--";
            sunsetLabel.text = "--:--";
            solarNoonLabel.text = "--:--";
        }
    }

    function refresh() { updateTimes(); }

    Component.onCompleted: { updateTimes(); }
}