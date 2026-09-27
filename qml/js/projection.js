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

// Interpolate between two lat/lon points along a great circle arc.
// Returns an array of [lon, lat] pairs (including endpoints).
// maxDeg: maximum angular spacing between interpolated points.
function greatCircleInterpolate(lat1, lon1, lat2, lon2, maxDeg) {
    // Cheap early exit: if bounding box is small, skip trig entirely
    var dLat = Math.abs(lat2 - lat1);
    var dLon = Math.abs(lon2 - lon1);
    if (dLon > 180) dLon = 360 - dLon;
    if (dLat < maxDeg && dLon < maxDeg)
        return [[lon1, lat1], [lon2, lat2]];

    var r1 = lat1 * DEG, r2 = lat2 * DEG;
    var l1 = lon1 * DEG, l2 = lon2 * DEG;
    var x1 = Math.cos(r1) * Math.cos(l1), y1 = Math.cos(r1) * Math.sin(l1), z1 = Math.sin(r1);
    var x2 = Math.cos(r2) * Math.cos(l2), y2 = Math.cos(r2) * Math.sin(l2), z2 = Math.sin(r2);
    var dot = x1*x2 + y1*y2 + z1*z2;
    if (dot > 1) dot = 1; if (dot < -1) dot = -1;
    var omega = Math.acos(dot);
    var dist = omega / DEG;
    var steps = Math.max(1, Math.ceil(dist / maxDeg));
    var sinOmega = Math.sin(omega);
    var result = [];
    for (var i = 0; i <= steps; i++) {
        var t = i / steps;
        var s1, s2;
        if (sinOmega < 1e-10) {
            s1 = 1 - t; s2 = t;
        } else {
            s1 = Math.sin((1 - t) * omega) / sinOmega;
            s2 = Math.sin(t * omega) / sinOmega;
        }
        var xi = s1 * x1 + s2 * x2;
        var yi = s1 * y1 + s2 * y2;
        var zi = s1 * z1 + s2 * z2;
        result.push([Math.atan2(yi, xi) / DEG, Math.atan2(zi, Math.sqrt(xi*xi + yi*yi)) / DEG]);
    }
    return result;
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
