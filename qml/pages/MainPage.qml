import QtQuick 2.6
import Sailfish.Silica 1.0
import QtQuick.LocalStorage 2.0
import "../components"
import "../js/store.js" as Store
import "../js/cities.js" as Cities
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

    function editLocation(loc, idx) {
        var picker = pageStack.push(Qt.resolvedUrl("LocationPicker.qml"), {
            editName: loc.name,
            editLat: loc.lat,
            editLon: loc.lon,
            editOff: loc.off
        });
        picker.locationSelected.connect(function(updated) {
            Store.updateLocation(loc.id, updated.name, updated.lat, updated.lon, updated.off);
            var newList = locationList.slice();
            newList[idx] = {
                id: loc.id,
                name: updated.name,
                lat: updated.lat,
                lon: updated.lon,
                off: updated.off
            };
            locationList = newList;
            locationListChanged();
            if (globe.hasSelection &&
                globe.selectedLat === loc.lat &&
                globe.selectedLon === loc.lon) {
                globe.selectedLat = updated.lat;
                globe.selectedLon = updated.lon;
            }
            _updateGlobeLocations();
            _refreshTick++;
        });
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
                        var newId = Store.addLocation(loc.name, loc.lat, loc.lon, loc.off);
                        if (newId >= 0) {
                            locationList.push({ id: newId, name: loc.name, lat: loc.lat, lon: loc.lon, off: loc.off || null });
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
                width: parent.width - 2 * Theme.horizontalPageMargin
                height: Math.min(width, Screen.height * Const.GLOBE_HEIGHT_FRACTION)
                anchors.horizontalCenter: parent.horizontalCenter

                GlobeCanvas {
                    id: globe
                    anchors.fill: parent
                    centerLongitude: Store.loadCenterLon()
                    centerLatitude: Store.loadCenterLat()

                    onCenterLongitudeChanged: saveTimer.restart()
                    onCenterLatitudeChanged: saveTimer.restart()
                }

                // Spin button / progress circle — bottom-right of globe
                Item {
                    id: spinArea
                    width: Theme.iconSizeMedium
                    height: Theme.iconSizeMedium
                    anchors {
                        right: parent.right
                        rightMargin: Theme.paddingSmall
                        bottom: parent.bottom
                        bottomMargin: Theme.paddingSmall
                    }

                    IconButton {
                        anchors.centerIn: parent
                        icon.source: "image://theme/icon-m-sync"
                        visible: !globe.isSpinning
                        opacity: 0.7
                        onClicked: globe.spin()
                    }

                    Canvas {
                        id: spinProgressCanvas
                        anchors.fill: parent
                        visible: globe.isSpinning

                        property real progress: globe.spinProgress

                        onProgressChanged: requestPaint()
                        onVisibleChanged: if (visible) requestPaint()

                        onPaint: {
                            var ctx = getContext("2d");
                            ctx.reset();
                            var cx = width / 2;
                            var cy = height / 2;
                            var r = cx - 2;
                            var lw = 2;

                            // Background ring
                            ctx.beginPath();
                            ctx.arc(cx, cy, r, 0, 2 * Math.PI);
                            ctx.strokeStyle = Qt.rgba(Theme.highlightColor.r, Theme.highlightColor.g,
                                                       Theme.highlightColor.b, 0.2);
                            ctx.lineWidth = lw;
                            ctx.stroke();

                            // Progress arc
                            var startAngle = -Math.PI / 2;
                            var endAngle = startAngle + progress * 2 * Math.PI;
                            ctx.beginPath();
                            ctx.arc(cx, cy, r, startAngle, endAngle);
                            ctx.strokeStyle = Theme.highlightColor;
                            ctx.lineWidth = lw;
                            ctx.lineCap = "round";
                            ctx.stroke();
                        }
                    }
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
                    locationOff: modelData.off || null

                    property int _refresh: _refreshTick
                    on_RefreshChanged: refresh()

                    onClicked: globe.flyTo(locationLat, locationLon)

                    menu: Component {
                        ContextMenu {
                            MenuItem {
                                text: qsTr("Pin to cover")
                                onClicked: {
                                    Store.saveCoverLocationId(locationList[index].id);
                                }
                            }
                            MenuItem {
                                text: qsTr("Edit")
                                onClicked: {
                                    var idx = index;
                                    var loc = locationList[idx];
                                    mainPage.editLocation(loc, idx);
                                }
                            }
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
        Store.migrateOffsets(Cities.cityOff);
        locationList = Store.loadLocations();
        _updateGlobeLocations();
    }
}