.pragma library

// Format a countdown duration in milliseconds as "2h 15m".
// Returns null if ms <= 0 (caller should use qsTr("now") for display).
function formatCountdown(ms) {
    if (ms <= 0) return null;
    var totalMin = Math.floor(ms / 60000);
    var h = Math.floor(totalMin / 60);
    var m = totalMin % 60;
    if (h > 0) return h + "h " + m + "m";
    return m + "m";
}