.pragma library

// NOAA Solar Calculator — public domain algorithm
// Reference: https://gml.noaa.gov/grad/solcalc/

var DEG = Math.PI / 180;

function julianDay(date) {
    var y = date.getUTCFullYear();
    var m = date.getUTCMonth() + 1;
    if (m <= 2) { y -= 1; m += 12; }
    var A = Math.floor(y / 100);
    var B = 2 - A + Math.floor(A / 4);
    return Math.floor(365.25 * (y + 4716)) + Math.floor(30.6001 * (m + 1))
           + date.getUTCDate() + date.getUTCHours() / 24.0
           + date.getUTCMinutes() / 1440.0 + date.getUTCSeconds() / 86400.0
           + B - 1524.5;
}

function solarData(date, lat, lon) {
    var jd = julianDay(date);
    var T = (jd - 2451545.0) / 36525.0;

    // Geometric mean longitude of the sun (degrees)
    var L0 = (280.46646 + T * (36000.76983 + 0.0003032 * T)) % 360;

    // Geometric mean anomaly of the sun (degrees)
    var M = (357.52911 + T * (35999.05029 - 0.0001537 * T)) % 360;
    var Mrad = M * DEG;

    // Eccentricity of earth's orbit
    var e = 0.016708634 - T * (0.000042037 + 0.0000001267 * T);

    // Sun's equation of center
    var C = (Math.sin(Mrad) * (1.9146 - T * (0.004817 + 0.000014 * T))
           + Math.sin(2 * Mrad) * (0.019993 - 0.000101 * T)
           + Math.sin(3 * Mrad) * 0.00029) ;

    // Sun's true longitude
    var sunLon = L0 + C;

    // Sun's apparent longitude
    var omega = 125.04 - 1934.136 * T;
    var lambda = sunLon - 0.00569 - 0.00478 * Math.sin(omega * DEG);

    // Obliquity of the ecliptic
    var epsilon0 = 23.0 + (26.0 + (21.448 - T * (46.815 + T * (0.00059 - T * 0.001813))) / 60.0) / 60.0;
    var epsilon = epsilon0 + 0.00256 * Math.cos(omega * DEG);

    // Solar declination
    var sinDec = Math.sin(epsilon * DEG) * Math.sin(lambda * DEG);
    var declination = Math.asin(sinDec) / DEG;

    // Equation of time (minutes)
    var y2 = Math.tan((epsilon / 2) * DEG);
    y2 = y2 * y2;
    var L0rad = L0 * DEG;
    var eqTime = 4 * (y2 * Math.sin(2 * L0rad)
                      - 2 * e * Math.sin(Mrad)
                      + 4 * e * y2 * Math.sin(Mrad) * Math.cos(2 * L0rad)
                      - 0.5 * y2 * y2 * Math.sin(4 * L0rad)
                      - 1.25 * e * e * Math.sin(2 * Mrad)) / DEG;

    // Hour angle of sunrise/sunset (degrees)
    var latRad = lat * DEG;
    var cosHA = (Math.cos(90.833 * DEG) / (Math.cos(latRad) * Math.cos(declination * DEG))
                 - Math.tan(latRad) * Math.tan(declination * DEG));

    var sunrise = null;
    var sunset = null;
    var solarNoon = null;

    if (cosHA > 1) {
        // Polar night — sun never rises
        return { sunrise: null, sunset: null, solarNoon: null,
                 declination: declination, eqTime: eqTime, polarNight: true, polarDay: false };
    } else if (cosHA < -1) {
        // Polar day — sun never sets
        return { sunrise: null, sunset: null, solarNoon: null,
                 declination: declination, eqTime: eqTime, polarNight: false, polarDay: true };
    }

    var HA = Math.acos(cosHA) / DEG;

    // Solar noon in minutes from midnight UTC
    var solarNoonMin = 720 - 4 * lon - eqTime;

    var sunriseMin = solarNoonMin - HA * 4;
    var sunsetMin = solarNoonMin + HA * 4;

    // Convert to Date objects (UTC)
    function minutesToDate(baseDate, mins) {
        var d = new Date(Date.UTC(baseDate.getUTCFullYear(), baseDate.getUTCMonth(),
                                  baseDate.getUTCDate(), 0, 0, 0));
        d.setUTCSeconds(mins * 60);
        return d;
    }

    sunrise = minutesToDate(date, sunriseMin);
    sunset = minutesToDate(date, sunsetMin);
    solarNoon = minutesToDate(date, solarNoonMin);

    return {
        sunrise: sunrise,
        sunset: sunset,
        solarNoon: solarNoon,
        declination: declination,
        eqTime: eqTime,
        polarNight: false,
        polarDay: false
    };
}

// Get subsolar point (latitude where sun is directly overhead)
function subsolarPoint(date) {
    var jd = julianDay(date);
    var T = (jd - 2451545.0) / 36525.0;
    var L0 = (280.46646 + T * (36000.76983 + 0.0003032 * T)) % 360;
    var M = (357.52911 + T * (35999.05029 - 0.0001537 * T)) % 360;
    var Mrad = M * DEG;
    var C = (Math.sin(Mrad) * (1.9146 - T * (0.004817 + 0.000014 * T))
           + Math.sin(2 * Mrad) * (0.019993 - 0.000101 * T)
           + Math.sin(3 * Mrad) * 0.00029);
    var sunLon = (L0 + C) % 360;
    var omega = 125.04 - 1934.136 * T;
    var lambda = sunLon - 0.00569 - 0.00478 * Math.sin(omega * DEG);
    var epsilon0 = 23.0 + (26.0 + (21.448 - T * (46.815 + T * (0.00059 - T * 0.001813))) / 60.0) / 60.0;
    var epsilon = epsilon0 + 0.00256 * Math.cos(omega * DEG);

    var declination = Math.asin(Math.sin(epsilon * DEG) * Math.sin(lambda * DEG)) / DEG;

    // Equation of time (minutes) — same formula as in solarData
    var y2 = Math.tan((epsilon / 2) * DEG);
    y2 = y2 * y2;
    var L0rad = L0 * DEG;
    var e = 0.016708634 - T * (0.000042037 + 0.0000001267 * T);
    var eqTime = 4 * (y2 * Math.sin(2 * L0rad)
                      - 2 * e * Math.sin(Mrad)
                      + 4 * e * y2 * Math.sin(Mrad) * Math.cos(2 * L0rad)
                      - 0.5 * y2 * y2 * Math.sin(4 * L0rad)
                      - 1.25 * e * e * Math.sin(2 * Mrad)) / DEG;

    // Subsolar longitude: where the sun is directly overhead at this UTC time
    // Solar noon at lon=0 occurs at 12:00 UTC minus equation of time
    var utcMinutes = date.getUTCHours() * 60 + date.getUTCMinutes() + date.getUTCSeconds() / 60;
    var subsolarLon = -(utcMinutes - 720 + eqTime) / 4.0; // positive east

    // Wrap to [-180, 180]
    while (subsolarLon > 180) subsolarLon -= 360;
    while (subsolarLon < -180) subsolarLon += 360;

    return { lat: declination, lon: subsolarLon };
}

// Format a Date as HH:MM in local time
function formatTime(d) {
    if (!d) return "--:--";
    var h = d.getHours();
    var m = d.getMinutes();
    return (h < 10 ? "0" : "") + h + ":" + (m < 10 ? "0" : "") + m;
}
