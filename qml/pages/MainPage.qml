import QtQuick 2.6
import Sailfish.Silica 1.0
import QtQuick.LocalStorage 2.0
import "../components"
import "../js/solar.js" as Solar

Page {
    id: mainPage

    property var db: null
    property var locationList: []
    property int _refreshTick: 0

    // --- Database ---
    function openDb() {
        if (db) return db;
        db = LocalStorage.openDatabaseSync("harbour-shadowline", "1.0", "Shadow Line locations", 1000000);
        db.transaction(function(tx) {
            tx.executeSql("CREATE TABLE IF NOT EXISTS locations("
                + "id INTEGER PRIMARY KEY AUTOINCREMENT,"
                + "name TEXT NOT NULL,"
                + "lat REAL NOT NULL,"
                + "lon REAL NOT NULL,"
                + "sort_order INTEGER DEFAULT 0)");
            tx.executeSql("CREATE TABLE IF NOT EXISTS settings("
                + "key TEXT PRIMARY KEY, value TEXT)");
        });
        return db;
    }

    function loadLocations() {
        openDb();
        var result = [];
        db.readTransaction(function(tx) {
            var rs = tx.executeSql("SELECT id, name, lat, lon FROM locations ORDER BY sort_order, id");
            for (var i = 0; i < rs.rows.length; i++) {
                result.push({
                    id: rs.rows.item(i).id,
                    name: rs.rows.item(i).name,
                    lat: rs.rows.item(i).lat,
                    lon: rs.rows.item(i).lon
                });
            }
        });
        locationList = result;
        _updateGlobeLocations();
    }

    function addLocation(name, lat, lon) {
        openDb();
        var newId = -1;
        db.transaction(function(tx) {
            var maxOrder = tx.executeSql("SELECT COALESCE(MAX(sort_order),0) as mo FROM locations");
            var order = maxOrder.rows.item(0).mo + 1;
            var rs = tx.executeSql("INSERT INTO locations (name, lat, lon, sort_order) VALUES (?, ?, ?, ?)",
                                   [name, lat, lon, order]);
            newId = rs.insertId;
        });
        if (newId >= 0) {
            locationList.push({ id: newId, name: name, lat: lat, lon: lon });
            locationListChanged();
            _updateGlobeLocations();
        }
    }

    function removeLocation(index) {
        if (index < 0 || index >= locationList.length) return;
        var loc = locationList[index];
        openDb();
        db.transaction(function(tx) {
            tx.executeSql("DELETE FROM locations WHERE id = ?", [loc.id]);
        });
        locationList.splice(index, 1);
        locationListChanged();
        _updateGlobeLocations();
    }

    function loadCenterLongitude() {
        openDb();
        var lon = 30.0; // default: roughly Europe-centered
        db.readTransaction(function(tx) {
            var rs = tx.executeSql("SELECT value FROM settings WHERE key='centerLon'");
            if (rs.rows.length > 0) {
                lon = parseFloat(rs.rows.item(0).value);
            }
        });
        return lon;
    }

    function saveCenterLongitude(lon) {
        openDb();
        db.transaction(function(tx) {
            tx.executeSql("INSERT OR REPLACE INTO settings (key, value) VALUES ('centerLon', ?)",
                          [lon.toString()]);
        });
    }

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
                        mainPage.addLocation(loc.name, loc.lat, loc.lon);
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
                height: Math.min(parent.width, Screen.height * 0.45)

                GlobeCanvas {
                    id: globe
                    anchors.fill: parent
                    centerLongitude: mainPage.loadCenterLongitude()

                    onCenterLongitudeChanged: {
                        // Debounced save
                        saveTimer.restart()
                    }
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
                interval: 1000
                onTriggered: mainPage.saveCenterLongitude(globe.centerLongitude)
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

                    property int _refresh: _refreshTick
                    on_RefreshChanged: refresh()

                    onClicked: globe.flyTo(locationLat, locationLon)

                    menu: Component {
                        ContextMenu {
                            MenuItem {
                                text: qsTr("Delete")
                                onClicked: {
                                    var idx = index;
                                    if (globe.hasSelection &&
                                        globe.selectedLat === locationLat &&
                                        globe.selectedLon === locationLon) {
                                        globe.clearSelection();
                                    }
                                    removeLocation(idx);
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
        interval: 60000
        running: true
        repeat: true
        onTriggered: _refreshTick++
    }

    Component.onCompleted: {
        loadLocations();
    }
}
