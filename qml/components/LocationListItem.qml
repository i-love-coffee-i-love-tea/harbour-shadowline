import QtQuick 2.6
import Sailfish.Silica 1.0
import "../js/solar.js" as Solar
import "../js/projection.js" as Proj

ListItem {
    id: locationItem

    property string locationName: ""
    property real locationLat: 0
    property real locationLon: 0
    property string locationTz: ""
    property bool _isNight: false
    property string _dayLength: ""
    property string _solarNoon: ""
    property string _currentTime: ""
    property string _nextChangeEvent: ""
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

    function _formatHM(date) {
        if (!date) return "--:--";
        var h = date.getHours();
        var m = date.getMinutes();
        return (h < 10 ? "0" : "") + h + ":" + (m < 10 ? "0" : "") + m;
    }

    function _getLocalTime(tz, lon) {
        var now = new Date();
        if (tz) {
            try {
                var parts = new Intl.DateTimeFormat('en-GB', {
                    timeZone: tz,
                    hour: 'numeric', minute: 'numeric', hour12: false, hourCycle: 'h23'
                }).formatToParts(now);
                var h = 0, m = 0;
                for (var i = 0; i < parts.length; i++) {
                    if (parts[i].type === 'hour') h = parseInt(parts[i].value);
                    else if (parts[i].type === 'minute') m = parseInt(parts[i].value);
                }
                return (h < 10 ? "0" : "") + h + ":" + (m < 10 ? "0" : "") + m;
            } catch (e) {}
        }
        var utcMs = now.getTime() + now.getTimezoneOffset() * 60000;
        var offsetH = Math.round(lon / 15);
        var local = new Date(utcMs + offsetH * 3600000);
        var lh = local.getHours(), lm = local.getMinutes();
        return (lh < 10 ? "0" : "") + lh + ":" + (lm < 10 ? "0" : "") + lm;
    }

    function _formatCountdown(ms) {
        if (ms <= 0) return qsTr("now");
        var totalMin = Math.floor(ms / 60000);
        var h = Math.floor(totalMin / 60);
        var m = totalMin % 60;
        if (h > 0) return h + "h " + m + "m";
        return m + "m";
    }

    function updateTimes() {
        var now = new Date();
        var data = Solar.solarData(now, locationLat, locationLon);

        _currentTime = _getLocalTime(locationTz, locationLon);

        if (data.polarDay) {
            sunriseLabel.text = qsTr("Polar day");
            sunsetLabel.text = "";
            solarNoonLabel.text = "--:--";
            _isNight = false;
            _dayLength = "24h 0m";
            _nextChangeEvent = "";
            _timeUntilChange = "";
        } else if (data.polarNight) {
            sunriseLabel.text = qsTr("Polar night");
            sunsetLabel.text = "";
            solarNoonLabel.text = "--:--";
            _isNight = true;
            _dayLength = "0h 0m";
            _nextChangeEvent = "";
            _timeUntilChange = "";
        } else {
            sunriseLabel.text = Solar.formatTime(data.sunrise);
            sunsetLabel.text = Solar.formatTime(data.sunset);
            solarNoonLabel.text = _formatHM(data.solarNoon);
            _isNight = (now < data.sunrise || now > data.sunset);

            var diffMs = data.sunset.getTime() - data.sunrise.getTime();
            _dayLength = _formatDuration(diffMs / 60000);

            // Time until next day/night change
            if (_isNight) {
                var nextSunrise;
                if (now > data.sunset) {
                    var tomorrow = new Date(now.getTime() + 86400000);
                    var tomorrowData = Solar.solarData(tomorrow, locationLat, locationLon);
                    nextSunrise = tomorrowData.sunrise;
                } else {
                    nextSunrise = data.sunrise;
                }
                if (nextSunrise) {
                    _timeUntilChange = _formatCountdown(nextSunrise.getTime() - now.getTime());
                }
            } else {
                _timeUntilChange = _formatCountdown(data.sunset.getTime() - now.getTime());
            }
        }
    }

    Component.onCompleted: updateTimes()
    function refresh() { updateTimes(); }
}