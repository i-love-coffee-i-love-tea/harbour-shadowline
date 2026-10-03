import QtQuick 2.6
import QtPositioning 5.2
import Sailfish.Silica 1.0
import "../js/cities.js" as Cities
import "../js/timezone_grid.js" as TzGrid

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

    function _tryUpdateTimezone() {
        var lat = parseFloat(latField.text);
        var lon = parseFloat(lonField.text);
        if (!isNaN(lat) && !isNaN(lon) && lat >= -90 && lat <= 90 && lon >= -180 && lon <= 180)
            offsetCombo.setTimezone(lat, lon);
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
                        onTextChanged: _tryUpdateTimezone()
                    }

                    TextField {
                        id: lonField
                        width: parent.width * 0.5 - Theme.paddingSmall
                        placeholderText: qsTr("Lon")
                        label: qsTr("Longitude")
                        inputMethodHints: Qt.ImhFormattedNumbersOnly
                        EnterKey.iconSource: "image://theme/icon-m-enter-accept"
                        EnterKey.onClicked: addCustomBtn.clicked()
                        onTextChanged: _tryUpdateTimezone()
                    }
                }

                ComboBox {
                    id: offsetCombo
                    width: parent.width
                    label: qsTr("UTC offset")
                    property var offsets: [
                        -12, -11.5, -11, -10.5, -10, -9.5, -9, -8.5, -8, -7.5,
                        -7, -6.5, -6, -5.5, -5, -4.5, -4, -3.5, -3, -2.5,
                        -2, -1.5, -1, -0.5, 0, 0.5, 1, 1.5, 2, 2.5,
                        3, 3.5, 4, 4.5, 5, 5.5, 5.75, 6, 6.5, 7,
                        7.5, 8, 8.5, 8.75, 9, 9.5, 10, 10.5, 11, 11.5,
                        12, 12.75, 13, 13.75, 14
                    ]
                    property real selectedOffset: offsets[currentIndex]

                    menu: ContextMenu {
                        Repeater {
                            model: offsetCombo.offsets
                            MenuItem {
                                text: (modelData >= 0 ? "+" : "") + modelData
                            }
                        }
                    }

                    function _setOffsetValue(off) {
                        var best = 0;
                        for (var i = 0; i < offsets.length; i++) {
                            if (Math.abs(offsets[i] - off) < Math.abs(offsets[best] - off))
                                best = i;
                        }
                        currentIndex = best;
                    }

                    // Auto-detect timezone from coordinates using grid lookup
                    function setTimezone(lat, lon) {
                        var tz = TzGrid.lookup(lat, lon);
                        if (tz) {
                            _setOffsetValue(tz.o);
                            dstSwitch.checked = (tz.d === 1);
                        }
                    }

                    Component.onCompleted: setTimezone(0, 0)
                }

                TextSwitch {
                    id: dstSwitch
                    text: qsTr("Daylight saving time")
                    description: qsTr("Enable if this location observes DST")
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
                                lon: lon,
                                off: { o: offsetCombo.selectedOffset, d: dstSwitch.checked ? 1 : 0 }
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
                            // offset auto-detected via latField/lonField onTextChanged
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
                            off: Cities.getOffset(modelData.name)
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