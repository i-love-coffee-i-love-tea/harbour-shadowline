import QtQuick 2.6
import Sailfish.Silica 1.0

Page {
    SilicaFlickable {
        anchors.fill: parent
        contentHeight: column.height

        Column {
            id: column
            width: parent.width
            spacing: Theme.paddingLarge

            PageHeader {
                title: qsTr("About")
            }

            Label {
                x: Theme.horizontalPageMargin
                width: parent.width - 2 * Theme.horizontalPageMargin
                text: qsTr("Shadow Line")
                font.pixelSize: Theme.fontSizeExtraLarge
                color: Theme.highlightColor
            }

            Label {
                x: Theme.horizontalPageMargin
                width: parent.width - 2 * Theme.horizontalPageMargin
                text: qsTr("Version 1.2.1")
                color: Theme.secondaryColor
                font.pixelSize: Theme.fontSizeSmall
            }

            Label {
                x: Theme.horizontalPageMargin
                width: parent.width - 2 * Theme.horizontalPageMargin
                text: qsTr("An interactive globe showing real-time daylight across Earth. "
                          + "Spin the globe to explore, add locations to see their sunrise and sunset times. "
                          + "Solar calculations use the NOAA Solar Calculator algorithm.")
                wrapMode: Text.WordWrap
                color: Theme.primaryColor
                font.pixelSize: Theme.fontSizeSmall
            }

            Label {
                x: Theme.horizontalPageMargin
                width: parent.width - 2 * Theme.horizontalPageMargin
                text: qsTr("Sunrise/sunset accuracy is approximately ±1 minute. "
                          + "Times are shown in your device's local timezone.")
                wrapMode: Text.WordWrap
                color: Theme.secondaryColor
                font.pixelSize: Theme.fontSizeExtraSmall
            }
        }
    }
}
