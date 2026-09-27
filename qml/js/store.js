var _db = null;

function openDb() {
    if (_db) return _db;
    _db = LocalStorage.openDatabaseSync(
        "harbour-shadowline", "1.0", "Shadow Line locations", 1000000);
    _db.transaction(function(tx) {
        tx.executeSql("CREATE TABLE IF NOT EXISTS locations("
            + "id INTEGER PRIMARY KEY AUTOINCREMENT,"
            + "name TEXT NOT NULL,"
            + "lat REAL NOT NULL,"
            + "lon REAL NOT NULL,"
            + "sort_order INTEGER DEFAULT 0)");
        tx.executeSql("CREATE TABLE IF NOT EXISTS settings("
            + "key TEXT PRIMARY KEY, value TEXT)");
        try {
            tx.executeSql("ALTER TABLE locations ADD COLUMN tz TEXT DEFAULT ''");
        } catch (e) {
            console.warn("store.js: tz column migration skipped (" + e.message + ")");
        }
    });
    return _db;
}

function loadLocations() {
    var db = openDb();
    var result = [];
    db.readTransaction(function(tx) {
        var rs = tx.executeSql(
            "SELECT id, name, lat, lon, tz FROM locations ORDER BY sort_order, id");
        for (var i = 0; i < rs.rows.length; i++) {
            result.push({
                id:   rs.rows.item(i).id,
                name: rs.rows.item(i).name,
                lat:  rs.rows.item(i).lat,
                lon:  rs.rows.item(i).lon,
                tz:   rs.rows.item(i).tz || ""
            });
        }
    });
    return result;
}

function addLocation(name, lat, lon, tz) {
    var db = openDb();
    var newId = -1;
    tz = tz || "";
    try {
        db.transaction(function(tx) {
            var maxOrder = tx.executeSql(
                "SELECT COALESCE(MAX(sort_order),0) as mo FROM locations");
            var order = maxOrder.rows.item(0).mo + 1;
            var rs = tx.executeSql(
                "INSERT INTO locations (name, lat, lon, sort_order, tz) VALUES (?, ?, ?, ?, ?)",
                [name, lat, lon, order, tz]);
            newId = rs.insertId;
        });
    } catch (e) {
        console.warn("store.js: addLocation failed (" + e.message + ")");
    }
    return newId;
}

function removeLocation(id) {
    var db = openDb();
    try {
        db.transaction(function(tx) {
            tx.executeSql("DELETE FROM locations WHERE id = ?", [id]);
        });
    } catch (e) {
        console.warn("store.js: removeLocation failed (" + e.message + ")");
    }
}

function loadSetting(key, defaultValue) {
    var db = openDb();
    var value = defaultValue;
    db.readTransaction(function(tx) {
        var rs = tx.executeSql("SELECT value FROM settings WHERE key=?", [key]);
        if (rs.rows.length > 0) value = parseFloat(rs.rows.item(0).value);
    });
    return value;
}

function saveSetting(key, value) {
    var db = openDb();
    try {
        db.transaction(function(tx) {
            tx.executeSql(
                "INSERT OR REPLACE INTO settings (key, value) VALUES (?, ?)",
                [key, value.toString()]);
        });
    } catch (e) {
        console.warn("store.js: saveSetting('" + key + "') failed (" + e.message + ")");
    }
}

function loadCenterLon() {
    return loadSetting('centerLon', 30.0);
}

function loadCenterLat() {
    return loadSetting('centerLat', 25.0);
}

function saveCenterLon(lon) {
    saveSetting('centerLon', lon);
}

function saveCenterLat(lat) {
    saveSetting('centerLat', lat);
}