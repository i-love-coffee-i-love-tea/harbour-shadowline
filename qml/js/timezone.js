.pragma library
.import "constants.js" as Const

// Check if DST is active for a location using calendar-based rules.
// Europe/US rule approximation: last Sunday of March to last Sunday of October (NH),
// last Sunday of October to last Sunday of March (SH).
function isDstActive(off, lat) {
    if (!off || off.d !== 1) return false;
    var now = new Date();
    var m = now.getMonth();
    var isNH = lat > 0;

    if (isNH) {
        if (m < 2 || m > 9) return false;
        if (m > 2 && m < 9) return true;
        if (m === 2) {
            var lastDay = new Date(now.getFullYear(), 3, 0).getDate();
            for (var d = lastDay; d >= 1; d--) {
                if (new Date(now.getFullYear(), 2, d).getDay() === 0)
                    return now.getDate() >= d;
            }
        }
        if (m === 9) {
            var lastDay = new Date(now.getFullYear(), 10, 0).getDate();
            for (var d = lastDay; d >= 1; d--) {
                if (new Date(now.getFullYear(), 9, d).getDay() === 0)
                    return now.getDate() < d;
            }
        }
    } else {
        if (m > 2 && m < 9) return false;
        if (m > 9 || m < 2) return true;
        if (m === 9) {
            var lastDay = new Date(now.getFullYear(), 10, 0).getDate();
            for (var d = lastDay; d >= 1; d--) {
                if (new Date(now.getFullYear(), 9, d).getDay() === 0)
                    return now.getDate() >= d;
            }
        }
        if (m === 2) {
            var lastDay = new Date(now.getFullYear(), 3, 0).getDate();
            for (var d = lastDay; d >= 1; d--) {
                if (new Date(now.getFullYear(), 2, d).getDay() === 0)
                    return now.getDate() < d;
            }
        }
    }
    return false;
}

// Get total UTC offset in hours (standard + DST if active).
// Returns null if off is null (no offset data for this location).
function totalOffset(off, lat) {
    if (!off) return null;
    return off.o + (isDstActive(off, lat) ? 1 : 0);
}

// Fallback offset when no timezone data is available: 1 hour per 15 degrees longitude.
function longitudeFallbackOffset(lon) {
    return Math.round(lon / Const.DEGREES_PER_HOUR);
}

// Convert a UTC hour:minute to local HH:MM string given an offset in hours.
function formatLocalFromUtc(utcH, utcM, offsetHours) {
    var totalMin = utcH * 60 + utcM + Math.round(offsetHours * 60);
    while (totalMin < 0) totalMin += 1440;
    while (totalMin >= 1440) totalMin -= 1440;
    var h = Math.floor(totalMin / 60);
    var m = totalMin % 60;
    return (h < 10 ? "0" : "") + h + ":" + (m < 10 ? "0" : "") + m;
}

// Format a UTC Date as location-local HH:MM.
// Uses offset data if available, otherwise falls back to longitude-based estimate.
function formatLocationTime(utcDate, off, lat, lon) {
    if (!utcDate) return "--:--";
    var offset = totalOffset(off, lat);
    if (offset === null) offset = longitudeFallbackOffset(lon);
    return formatLocalFromUtc(utcDate.getUTCHours(), utcDate.getUTCMinutes(), offset);
}

// Get current local time string for a location.
function getLocalTime(off, lat, lon) {
    var now = new Date();
    var utcH = now.getUTCHours();
    var utcM = now.getUTCMinutes();
    var offset = totalOffset(off, lat);
    if (offset !== null) {
        return formatLocalFromUtc(utcH, utcM, offset);
    }
    return formatLocalFromUtc(utcH, utcM, longitudeFallbackOffset(lon));
}