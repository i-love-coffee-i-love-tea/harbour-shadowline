import QtQuick 2.6
import Sailfish.Silica 1.0

Page {
    id: pickerPage

    // Signal emitted when a location is selected: {name, lat, lon}
    signal locationSelected(var location)

    // All existing location names for duplicate checking
    property var existingNames: []

    // Preset cities database
    readonly property var presetCities: [
        { name: "London",        lat: 51.5074,  lon:  -0.1278 },
        { name: "Paris",         lat: 48.8566,  lon:   2.3522 },
        { name: "Berlin",        lat: 52.5200,  lon:  13.4050 },
        { name: "Rome",          lat: 41.9028,  lon:  12.4964 },
        { name: "Madrid",        lat: 40.4168,  lon:  -3.7038 },
        { name: "Moscow",        lat: 55.7558,  lon:  37.6173 },
        { name: "Istanbul",      lat: 41.0082,  lon:  28.9784 },
        { name: "Stockholm",     lat: 59.3293,  lon:  18.0686 },
        { name: "Helsinki",      lat: 60.1699,  lon:  24.9384 },
        { name: "Reykjavik",     lat: 64.1466,  lon: -21.9426 },
        { name: "Tromsø",        lat: 69.6496,  lon:  18.9560 },
        { name: "Dubai",         lat: 25.2048,  lon:  55.2708 },
        { name: "Mumbai",        lat: 19.0760,  lon:  72.8777 },
        { name: "Bangkok",       lat: 13.7563,  lon: 100.5018 },
        { name: "Singapore",     lat:  1.3521,  lon: 103.8198 },
        { name: "Beijing",       lat: 39.9042,  lon: 116.4074 },
        { name: "Seoul",         lat: 37.5665,  lon: 126.9780 },
        { name: "Tokyo",         lat: 35.6762,  lon: 139.6503 },
        { name: "Cairo",         lat: 30.0444,  lon:  31.2357 },
        { name: "Nairobi",       lat: -1.2921,  lon:  36.8219 },
        { name: "Cape Town",     lat: -33.9249, lon:  18.4241 },
        { name: "New York",      lat: 40.7128,  lon: -74.0060 },
        { name: "Los Angeles",   lat: 34.0522,  lon: -118.2437 },
        { name: "Toronto",       lat: 43.6532,  lon: -79.3832 },
        { name: "Mexico City",   lat: 19.4326,  lon: -99.1332 },
        { name: "São Paulo",     lat: -23.5505, lon: -46.6333 },
        { name: "Buenos Aires",  lat: -34.6037, lon: -58.3816 },
        { name: "Honolulu",      lat: 21.3069,  lon: -157.8583 },
        { name: "Anchorage",     lat: 61.2181,  lon: -149.9003 },
        { name: "Sydney",        lat: -33.8688, lon: 151.2093 },
        { name: "Auckland",      lat: -36.8485, lon: 174.7633 }
    ]

    // Filtered list
    property var _filteredCities: presetCities
    property string _searchText: ""

    function _filterCities(query) {
        _searchText = query;
        if (!query || query.length === 0) {
            _filteredCities = presetCities;
            return;
        }
        var q = query.toLowerCase();
        var result = [];
        for (var i = 0; i < presetCities.length; i++) {
            if (presetCities[i].name.toLowerCase().indexOf(q) >= 0) {
                result.push(presetCities[i]);
            }
        }
        _filteredCities = result;
    }

    SilicaFlickable {
        anchors.fill: parent
        contentHeight: column.height

        PullDownMenu {
            MenuItem {
                text: qsTr("Custom Location")
                onClicked: customSection.visible = !customSection.visible
            }
        }

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
                onTextChanged: _filterCities(text)

                EnterKey.iconSource: "image://theme/icon-m-enter-close"
                EnterKey.onClicked: focus = false
            }

            // Preset cities list
            SectionHeader {
                text: qsTr("Preset Cities")
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
                            lon: modelData.lon
                        });
                        pageStack.pop();
                    }
                }
            }

            // Custom location section
            Item {
                id: customSection
                width: parent.width
                height: visible ? customColumn.height : 0
                visible: false

                Column {
                    id: customColumn
                    width: parent.width
                    spacing: Theme.paddingMedium

                    SectionHeader {
                        text: qsTr("Custom Location")
                    }

                    TextField {
                        id: nameField
                        width: parent.width
                        placeholderText: qsTr("Location name")
                        label: qsTr("Name")
                        EnterKey.iconSource: "image://theme/icon-m-enter-next"
                        EnterKey.onClicked: latField.focus = true
                    }

                    TextField {
                        id: latField
                        width: parent.width
                        placeholderText: qsTr("Latitude (-90 to 90)")
                        label: qsTr("Latitude")
                        inputMethodHints: Qt.ImhFormattedNumbersOnly
                        EnterKey.iconSource: "image://theme/icon-m-enter-next"
                        EnterKey.onClicked: lonField.focus = true
                    }

                    TextField {
                        id: lonField
                        width: parent.width
                        placeholderText: qsTr("Longitude (-180 to 180)")
                        label: qsTr("Longitude")
                        inputMethodHints: Qt.ImhFormattedNumbersOnly
                        EnterKey.iconSource: "image://theme/icon-m-enter-accept"
                        EnterKey.onClicked: addCustomBtn.clicked()
                    }

                    Button {
                        id: addCustomBtn
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: qsTr("Add")
                        enabled: nameField.text.length > 0
                                 && !isNaN(parseFloat(latField.text))
                                 && !isNaN(parseFloat(lonField.text))

                        onClicked: {
                            var lat = parseFloat(latField.text);
                            var lon = parseFloat(lonField.text);
                            if (lat < -90 || lat > 90 || lon < -180 || lon > 180) return;
                            pickerPage.locationSelected({
                                name: nameField.text,
                                lat: lat,
                                lon: lon
                            });
                            pageStack.pop();
                        }
                    }
                }
            }

            // Spacer
            Item { width: 1; height: Theme.paddingLarge }
        }
    }
}
