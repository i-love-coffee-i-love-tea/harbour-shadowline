.pragma library

var DEG = Math.PI / 180;

// Project lat/lon to screen coordinates using orthographic projection
// Returns { x, y, visible } or null if on back hemisphere
//   centerLat, centerLon: viewpoint center in degrees
//   radius: globe radius in pixels
//   cx, cy: screen center of the globe
function project(lat, lon, centerLat, centerLon, radius, cx, cy) {
    var latR = lat * DEG;
    var lonR = lon * DEG;
    var cLatR = centerLat * DEG;
    var cLonR = centerLon * DEG;

    var dLon = lonR - cLonR;

    var cosc = Math.sin(cLatR) * Math.sin(latR)
             + Math.cos(cLatR) * Math.cos(latR) * Math.cos(dLon);

    // Back hemisphere — not visible
    if (cosc < 0) return null;

    var x = radius * Math.cos(latR) * Math.sin(dLon);
    var y = radius * (Math.cos(cLatR) * Math.sin(latR)
                    - Math.sin(cLatR) * Math.cos(latR) * Math.cos(dLon));

    return { x: cx + x, y: cy - y, visible: true };
}

// Compute the terminator path as an array of {x,y} points
// For a given date, returns night-side polygon points in screen coords
function terminatorPoints(date, centerLat, centerLon, radius, cx, cy) {
    // Use solar.js for declination
    var solar = Qt.include("solar.js");
    var jd = julianDayApprox(date);
    var T = (jd - 2451545.0) / 36525.0;
    var L0 = (280.46646 + T * (36000.76983 + 0.0003032 * T)) % 360;
    var M = (357.52911 + T * (35999.05029 - 0.0001537 * T)) % 360;
    var Mrad = M * DEG;
    var C = Math.sin(Mrad) * (1.9146 - T * (0.004817 + 0.000014 * T))
          + Math.sin(2 * Mrad) * (0.019993 - 0.000101 * T)
          + Math.sin(3 * Mrad) * 0.00029;
    var sunLon = (L0 + C) % 360;
    var omega = 125.04 - 1934.136 * T;
    var lambda = sunLon - 0.00569 - 0.00478 * Math.sin(omega * DEG);
    var epsilon0 = 23.0 + (26.0 + (21.448 - T * (46.815 + T * (0.00059 - T * 0.001813))) / 60.0) / 60.0;
    var epsilon = epsilon0 + 0.00256 * Math.cos(omega * DEG);
    var declination = Math.asin(Math.sin(epsilon * DEG) * Math.sin(lambda * DEG));

    // Subsolar longitude
    var utcMin = date.getUTCHours() * 60 + date.getUTCMinutes();
    var subsolarLon = (-(utcMin - 720) / 4.0) * DEG;

    // Generate terminator as a great circle perpendicular to the subsolar point
    // The terminator is the set of points where the sun's elevation = -0.833° (refraction)
    // Simplified: circle with center at the antisolar point
    var points = [];
    var steps = 180;

    for (var i = 0; i <= steps; i++) {
        var azimuth = (i / steps) * 2 * Math.PI;
        // Point on the terminator great circle
        // The terminator is 90° from the subsolar point
        var tLat = Math.asin(Math.cos(azimuth) * Math.cos(declination));
        var tLon = subsolarLon + Math.atan2(
            Math.sin(azimuth) * Math.cos(declination),
            -Math.sin(declination) * Math.cos(azimuth)
        );

        var tLatDeg = tLat / DEG;
        var tLonDeg = tLon / DEG;

        var p = project(tLatDeg, tLonDeg, centerLat, centerLon, radius, cx, cy);
        if (p) {
            points.push(p);
        }
    }

    return points;
}

function julianDayApprox(date) {
    var y = date.getUTCFullYear();
    var m = date.getUTCMonth() + 1;
    if (m <= 2) { y -= 1; m += 12; }
    var A = Math.floor(y / 100);
    var B = 2 - A + Math.floor(A / 4);
    return Math.floor(365.25 * (y + 4716)) + Math.floor(30.6001 * (m + 1))
           + date.getUTCDate() + date.getUTCHours() / 24.0
           + date.getUTCMinutes() / 1440.0 + B - 1524.5;
}
