import QtQuick 2.6
import QtPositioning 5.2
import Sailfish.Silica 1.0
import "../js/cities.js" as Cities

Page {
    id: pickerPage

    // Signal emitted when a location is selected: {name, lat, lon}
    signal locationSelected(var location)

    property bool _nameManuallyEdited: false

    readonly property var presetCities: Cities.presetCities

    // Filtered list
    property var _filteredCities: presetCities
    property string _searchText: ""

    function _filterCities(query) {
        _searchText = query;
        _filteredCities = Cities.filterCities(query);
    }

    SilicaFlickable {
        anchors.fill: parent
        contentHeight: column.height

        Column {
            id: column
            width: parent.width

            PageHeader {
                title: qsTr("Add Location")
            }

            // Search field
            SearchField {
                id: searchField
                width: parent.width
                placeholderText: qsTr("Search cities")
                onTextChanged: {
                    _filterCities(text);
                    if (!_nameManuallyEdited)
                        nameField.text = text;
                }

                EnterKey.iconSource: "image://theme/icon-m-enter-close"
                EnterKey.onClicked: focus = false
            }

            // Custom location section
            SectionHeader {
                text: qsTr("Custom Location")
            }

            Column {
                width: parent.width
                spacing: Theme.paddingSmall

                TextField {
                    id: nameField
                    width: parent.width
                    placeholderText: qsTr("Location name")
                    label: qsTr("Name")
                    onTextChanged: {
                        if (activeFocus) _nameManuallyEdited = true;
                    }
                    EnterKey.iconSource: "image://theme/icon-m-enter-next"
                    EnterKey.onClicked: latField.focus = true
                }

                Row {
                    width: parent.width
                    spacing: Theme.paddingSmall

                    TextField {
                        id: latField
                        width: parent.width * 0.5 - Theme.paddingSmall
                        placeholderText: qsTr("Lat")
                        label: qsTr("Latitude")
                        inputMethodHints: Qt.ImhFormattedNumbersOnly
                        EnterKey.iconSource: "image://theme/icon-m-enter-next"
                        EnterKey.onClicked: lonField.focus = true
                    }

                    TextField {
                        id: lonField
                        width: parent.width * 0.5 - Theme.paddingSmall
                        placeholderText: qsTr("Lon")
                        label: qsTr("Longitude")
                        inputMethodHints: Qt.ImhFormattedNumbersOnly
                        EnterKey.iconSource: "image://theme/icon-m-enter-accept"
                        EnterKey.onClicked: addCustomBtn.clicked()
                    }
                }

                Row {
                    anchors.horizontalCenter: parent.horizontalCenter
                    spacing: Theme.paddingMedium

                    IconButton {
                        id: gpsBtn
                        icon.source: "image://theme/icon-m-whereami"
                        enabled: !gpsSource.active
                        onClicked: gpsSource.active = true
                    }

                    Button {
                        id: addCustomBtn
                        text: qsTr("Add")
                        enabled: nameField.text.length > 0
                                 && !isNaN(parseFloat(latField.text))
                                 && !isNaN(parseFloat(lonField.text))

                        onClicked: {
                            var lat = parseFloat(latField.text);
                            var lon = parseFloat(lonField.text);
                            if (lat < -90 || lat > 90 || lon < -180 || lon > 180) {
                                latField.errorHighlight = (lat < -90 || lat > 90);
                                lonField.errorHighlight = (lon < -180 || lon > 180);
                                return;
                            }
                            latField.errorHighlight = false;
                            lonField.errorHighlight = false;
                            pickerPage.locationSelected({
                                name: nameField.text,
                                lat: lat,
                                lon: lon
                            });
                            pageStack.pop();
                        }
                    }
                }

                Label {
                    visible: gpsSource.active
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: qsTr("Locating...")
                    color: Theme.highlightColor
                    font.pixelSize: Theme.fontSizeSmall
                }

                PositionSource {
                    id: gpsSource
                    active: false
                    updateInterval: 1000
                    onPositionChanged: {
                        if (position.latitudeValid && position.longitudeValid) {
                            latField.text = position.coordinate.latitude.toFixed(4);
                            lonField.text = position.coordinate.longitude.toFixed(4);
                            active = false;
                        }
                    }
                }
            }

            // Preset cities list
            SectionHeader {
                text: qsTr("World Capitals")
            }

            Repeater {
                model: _filteredCities

                BackgroundItem {
                    width: column.width

                    Label {
                        anchors {
                            left: parent.left
                            leftMargin: Theme.horizontalPageMargin
                            right: parent.right
                            rightMargin: Theme.horizontalPageMargin
                            verticalCenter: parent.verticalCenter
                        }
                        text: modelData.name
                        color: parent.highlighted ? Theme.highlightColor : Theme.primaryColor
                        font.pixelSize: Theme.fontSizeMedium
                    }

                    onClicked: {
                        pickerPage.locationSelected({
                            name: modelData.name,
                            lat: modelData.lat,
                            lon: modelData.lon,
                            tz: Cities.getTimezone(modelData.name)
                        });
                        pageStack.pop();
                    }
                }
            }

            // Spacer
            Item { width: 1; height: Theme.paddingLarge }
        }
    }
}