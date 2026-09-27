import QtQuick 2.6
import Sailfish.Silica 1.0
import QtQuick.LocalStorage 2.0
import "../components"
import "../js/store.js" as Store
import "../js/constants.js" as Const

Page {
    id: mainPage

    property var locationList: []
    property int _refreshTick: 0

    function _updateGlobeLocations() {
        var locs = [];
        for (var i = 0; i < locationList.length; i++) {
            locs.push({ lat: locationList[i].lat, lon: locationList[i].lon });
        }
        globe.locations = locs;
        globe.repaint();
    }

    // --- UI ---
    SilicaFlickable {
        anchors.fill: parent
        contentHeight: column.height

        PullDownMenu {
            MenuItem {
                text: qsTr("About")
                onClicked: pageStack.push(Qt.resolvedUrl("AboutPage.qml"))
            }
            MenuItem {
                text: qsTr("Refresh")
                onClicked: _refreshTick++
            }
            MenuItem {
                text: qsTr("Add Location")
                onClicked: {
                    var picker = pageStack.push(Qt.resolvedUrl("LocationPicker.qml"));
                    picker.locationSelected.connect(function(loc) {
                        var newId = Store.addLocation(loc.name, loc.lat, loc.lon, loc.tz);
                        if (newId >= 0) {
                            locationList.push({ id: newId, name: loc.name, lat: loc.lat, lon: loc.lon, tz: loc.tz || "" });
                            locationListChanged();
                            _updateGlobeLocations();
                        }
                        _refreshTick++;
                    });
                }
            }
        }

        Column {
            id: column
            width: parent.width

            PageHeader {
                title: qsTr("Shadow Line")
            }

            // Globe
            Item {
                width: parent.width
                height: Math.min(parent.width, Screen.height * Const.GLOBE_HEIGHT_FRACTION)

                GlobeCanvas {
                    id: globe
                    anchors.fill: parent
                    centerLongitude: Store.loadCenterLon()
                    centerLatitude: Store.loadCenterLat()

                    onCenterLongitudeChanged: saveTimer.restart()
                    onCenterLatitudeChanged: saveTimer.restart()
                }

                // Spin button — bottom-right of globe
                IconButton {
                    anchors {
                        right: parent.right
                        rightMargin: Theme.paddingSmall
                        bottom: parent.bottom
                        bottomMargin: Theme.paddingSmall
                    }
                    icon.source: "image://theme/icon-m-sync"
                    enabled: !globe.isSpinning
                    opacity: globe.isSpinning ? 0.3 : 0.7
                    Behavior on opacity { FadeAnimation {} }
                    onClicked: globe.spin()
                }
            }

            Timer {
                id: saveTimer
                interval: Const.SAVE_DEBOUNCE_INTERVAL
                onTriggered: {
                    Store.saveCenterLon(globe.centerLongitude);
                    Store.saveCenterLat(globe.centerLatitude);
                }
            }

            // Separator
            Item {
                width: parent.width
                height: Theme.paddingMedium
            }

            // Location list header
            SectionHeader {
                text: locationList.length > 0
                      ? qsTr("Locations") + " (" + locationList.length + ")"
                      : qsTr("Locations")
            }

            // Empty state
            Label {
                visible: locationList.length === 0
                width: parent.width - 2 * Theme.horizontalPageMargin
                anchors.horizontalCenter: parent.horizontalCenter
                text: qsTr("Pull down to add a location")
                color: Theme.secondaryColor
                font.pixelSize: Theme.fontSizeMedium
                horizontalAlignment: Text.AlignHCenter
                wrapMode: Text.WordWrap
            }

            // Location list items
            Repeater {
                id: locationRepeater
                model: locationList

                delegate: LocationListItem {
                    width: column.width
                    locationName: modelData.name
                    locationLat: modelData.lat
                    locationLon: modelData.lon
                    locationTz: modelData.tz || ""

                    property int _refresh: _refreshTick
                    on_RefreshChanged: refresh()

                    onClicked: globe.flyTo(locationLat, locationLon)

                    menu: Component {
                        ContextMenu {
                            MenuItem {
                                text: qsTr("Delete")
                                onClicked: {
                                    var idx = index;
                                    var loc = locationList[idx];
                                    if (globe.hasSelection &&
                                        globe.selectedLat === locationLat &&
                                        globe.selectedLon === locationLon) {
                                        globe.clearSelection();
                                    }
                                    Store.removeLocation(loc.id);
                                    locationList.splice(idx, 1);
                                    locationListChanged();
                                    _updateGlobeLocations();
                                }
                            }
                        }
                    }
                }
            }

            // Bottom spacer for pull-up menu
            Item { width: 1; height: Theme.paddingLarge * 2 }
        }
    }

    // Refresh times every minute
    Timer {
        interval: Const.AUTO_REFRESH_INTERVAL
        running: true
        repeat: true
        onTriggered: _refreshTick++
    }

    Component.onCompleted: {
        locationList = Store.loadLocations();
        _updateGlobeLocations();
    }
}