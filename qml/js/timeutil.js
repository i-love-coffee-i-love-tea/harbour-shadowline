.pragma library

// Threshold in milliseconds below which a transition is considered imminent (1 minute).
var IMMINENT_THRESHOLD_MS = 60000;

// Returns true if the remaining time until a solar event is within the imminent transition window.
function isTransitionImminent(ms) {
    return ms !== null && ms !== undefined && ms <= IMMINENT_THRESHOLD_MS && ms >= -IMMINENT_THRESHOLD_MS;
}

// Format a countdown duration in milliseconds as "2h 15m".
// Returns null if ms < IMMINENT_THRESHOLD_MS (caller should handle immediate transition).
function formatCountdown(ms) {
    if (ms < IMMINENT_THRESHOLD_MS) return null;
    var totalMin = Math.floor(ms / 60000);
    var h = Math.floor(totalMin / 60);
    var m = totalMin % 60;
    if (h > 0) return h + "h " + m + "m";
    return m + "m";
}