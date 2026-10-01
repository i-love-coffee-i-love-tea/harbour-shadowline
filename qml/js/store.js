var _db = null;

var DB_NAME = "harbour-shadowline";
var DB_VERSION = "1.0";
var DB_DESCRIPTION = "Shadow Line locations";
var DB_SIZE = 1000000;
var DEFAULT_CENTER_LON = 30.0;
var DEFAULT_CENTER_LAT = 25.0;

function openDb() {
    if (_db) return _db;
    _db = LocalStorage.openDatabaseSync(DB_NAME, DB_VERSION, DB_DESCRIPTION, DB_SIZE);
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
            // column already exists
        }
        try {
            tx.executeSql("ALTER TABLE locations ADD COLUMN off_o REAL");
        } catch (e) {
            // column already exists
        }
        try {
            tx.executeSql("ALTER TABLE locations ADD COLUMN off_d INTEGER DEFAULT 0");
        } catch (e) {
            // column already exists
        }
    });
    return _db;
}

function loadLocations() {
    var db = openDb();
    var result = [];
    try {
        db.readTransaction(function(tx) {
            var rs = tx.executeSql(
                "SELECT id, name, lat, lon, tz, off_o, off_d FROM locations ORDER BY sort_order, id");
            for (var i = 0; i < rs.rows.length; i++) {
                var offO = rs.rows.item(i).off_o;
                result.push({
                    id:   rs.rows.item(i).id,
                    name: rs.rows.item(i).name,
                    lat:  rs.rows.item(i).lat,
                    lon:  rs.rows.item(i).lon,
                    off:  (offO !== null && offO !== undefined) ? {o: offO, d: rs.rows.item(i).off_d || 0} : null
                });
            }
        });
    } catch (e) {
        console.warn("store.js: loadLocations failed, trying fallback (" + e.message + ")");
        db.readTransaction(function(tx) {
            var rs = tx.executeSql(
                "SELECT id, name, lat, lon, tz FROM locations ORDER BY sort_order, id");
            for (var i = 0; i < rs.rows.length; i++) {
                result.push({
                    id:   rs.rows.item(i).id,
                    name: rs.rows.item(i).name,
                    lat:  rs.rows.item(i).lat,
                    lon:  rs.rows.item(i).lon,
                    off:  null
                });
            }
        });
    }
    return result;
}

function addLocation(name, lat, lon, off) {
    var db = openDb();
    var newId = -1;
    var offO = (off && off.o !== undefined) ? off.o : null;
    var offD = (off && off.d !== undefined) ? off.d : 0;
    try {
        db.transaction(function(tx) {
            var maxOrder = tx.executeSql(
                "SELECT COALESCE(MAX(sort_order),0) as mo FROM locations");
            var order = maxOrder.rows.item(0).mo + 1;
            try {
                var rs = tx.executeSql(
                    "INSERT INTO locations (name, lat, lon, sort_order, off_o, off_d) VALUES (?, ?, ?, ?, ?, ?)",
                    [name, lat, lon, order, offO, offD]);
                newId = rs.insertId;
            } catch (e2) {
                // Fallback: old schema without off_o/off_d
                var rs = tx.executeSql(
                    "INSERT INTO locations (name, lat, lon, sort_order, tz) VALUES (?, ?, ?, ?, ?)",
                    [name, lat, lon, order, ""]);
                newId = rs.insertId;
            }
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
    return loadSetting('centerLon', DEFAULT_CENTER_LON);
}

function loadCenterLat() {
    return loadSetting('centerLat', DEFAULT_CENTER_LAT);
}

function saveCenterLon(lon) {
    saveSetting('centerLon', lon);
}

function saveCenterLat(lat) {
    saveSetting('centerLat', lat);
}