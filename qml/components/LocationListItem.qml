import QtQuick 2.6
import Sailfish.Silica 1.0
import "../js/solar.js" as Solar
import "../js/projection.js" as Proj

ListItem {
    id: locationItem

    property string locationName: ""
    property real locationLat: 0
    property real locationLon: 0
    property bool _isNight: false
    property bool _expanded: false
    property string _dayLength: ""
    property string _solarNoon: ""
    property string _sunAltitude: ""

    contentHeight: _expanded ? Theme.itemSizeMedium + detailsColumn.height + Theme.paddingSmall : Theme.itemSizeMedium

    // onClicked handled by MainPage delegate for flyTo + expand

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

        // Location name + coordinates
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
                text: locationLat.toFixed(1) + "\u00B0" + (locationLat >= 0 ? "N" : "S") + "  "
                      + Math.abs(locationLon).toFixed(1) + "\u00B0" + (locationLon >= 0 ? "E" : "W")
                color: Theme.secondaryColor
                font.pixelSize: Theme.fontSizeExtraSmall
            }
        }

        // Sunrise / Sunset times
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

    // Expandable details
    Column {
        id: detailsColumn
        visible: _expanded
        anchors {
            left: parent.left
            leftMargin: Theme.horizontalPageMargin
            right: parent.right
            rightMargin: Theme.horizontalPageMargin
            top: mainRow.bottom
            topMargin: Theme.paddingSmall
        }
        spacing: Theme.paddingSmall

        Separator {
            width: parent.width
            color: Theme.highlightColor
            horizontalAlignment: Qt.AlignLeft
        }

        Row {
            width: parent.width
            spacing: Theme.paddingMedium

            Label {
                text: qsTr("Day length")
                color: Theme.secondaryColor
                font.pixelSize: Theme.fontSizeSmall
                width: parent.width * 0.5
            }
            Label {
                text: _dayLength
                color: Theme.primaryColor
                font.pixelSize: Theme.fontSizeSmall
            }
        }

        Row {
            width: parent.width
            spacing: Theme.paddingMedium

            Label {
                text: qsTr("Solar noon")
                color: Theme.secondaryColor
                font.pixelSize: Theme.fontSizeSmall
                width: parent.width * 0.5
            }
            Label {
                text: _solarNoon
                color: Theme.primaryColor
                font.pixelSize: Theme.fontSizeSmall
            }
        }

        Item { width: 1; height: Theme.paddingSmall }
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

    function updateTimes() {
        var now = new Date();
        var data = Solar.solarData(now, locationLat, locationLon);
        if (data.polarDay) {
            sunriseLabel.text = qsTr("Polar day");
            sunsetLabel.text = "";
            _isNight = false;
            _dayLength = "24h 0m";
            _solarNoon = "--:--";
        } else if (data.polarNight) {
            sunriseLabel.text = qsTr("Polar night");
            sunsetLabel.text = "";
            _isNight = true;
            _dayLength = "0h 0m";
            _solarNoon = "--:--";
        } else {
            sunriseLabel.text = Solar.formatTime(data.sunrise);
            sunsetLabel.text = Solar.formatTime(data.sunset);
            _isNight = (now < data.sunrise || now > data.sunset);

            var diffMs = data.sunset.getTime() - data.sunrise.getTime();
            _dayLength = _formatDuration(diffMs / 60000);
            _solarNoon = _formatHM(data.solarNoon);
        }
    }

    Component.onCompleted: updateTimes()
    function refresh() { updateTimes(); }
}
