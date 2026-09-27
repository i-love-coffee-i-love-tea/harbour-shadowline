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