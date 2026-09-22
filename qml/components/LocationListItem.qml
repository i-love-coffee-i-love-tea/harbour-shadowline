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

    contentHeight: Theme.itemSizeMedium

    Row {
        anchors {
            left: parent.left
            leftMargin: Theme.horizontalPageMargin
            right: parent.right
            rightMargin: Theme.horizontalPageMargin
            verticalCenter: parent.verticalCenter
        }
        spacing: Theme.paddingMedium

        // Day/night icon
        Image {
            id: dayNightIcon
            width: Theme.iconSizeMedium
            height: Theme.iconSizeMedium
            anchors.verticalCenter: parent.verticalCenter
            source: _isNight ? "image://theme/icon-m-night" : "image://theme/icon-m-day"
        }

        // Location name + coordinates
        Column {
            width: parent.width - dayNightIcon.width - timesColumn.width - 2 * Theme.paddingMedium
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

    function updateTimes() {
        var now = new Date();
        var data = Solar.solarData(now, locationLat, locationLon);
        if (data.polarDay) {
            sunriseLabel.text = qsTr("Polar day");
            sunsetLabel.text = "";
            _isNight = false;
        } else if (data.polarNight) {
            sunriseLabel.text = qsTr("Polar night");
            sunsetLabel.text = "";
            _isNight = true;
        } else {
            sunriseLabel.text = Solar.formatTime(data.sunrise);
            sunsetLabel.text = Solar.formatTime(data.sunset);
            // Check if current time is between sunrise and sunset
            _isNight = (now < data.sunrise || now > data.sunset);
        }
    }

    Component.onCompleted: updateTimes()
    function refresh() { updateTimes(); }
}
