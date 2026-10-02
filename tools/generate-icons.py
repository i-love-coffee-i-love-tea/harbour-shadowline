#!/usr/bin/env python3
"""Generate Earth app icons for harbour-shadowline matching the in-app globe centered on Gaza.

Uses vector coastline and border geometry from src/geomdata.h to render
the interactive globe with realistic solar shading, twilight scattering, and atmosphere rim.

Output: rpm/icons/{86x86,108x108,128x128,172x172}/harbour-shadowline.png

Usage:
    python3 tools/generate-icons.py
"""
import math
import os
import re

from PIL import Image, ImageDraw, ImageFilter

SIZES = [86, 108, 128, 172]
SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
PROJECT_DIR = os.path.dirname(SCRIPT_DIR)
GEOMDATA_PATH = os.path.join(PROJECT_DIR, "src/geomdata.h")
OUTPUT_DIR = os.path.join(PROJECT_DIR, "rpm/icons/{size}x{size}/harbour-shadowline.png")

GAZA_LAT = 31.5017
GAZA_LON = 34.4668


def load_geomdata():
    with open(GEOMDATA_PATH, "r") as f:
        text = f.read()

    def parse_float_array(name):
        m = re.search(r'const float ' + name + r'\[\]\s*=\s*\{([^}]+)\};', text)
        return [float(x.strip()) for x in m.group(1).split(',') if x.strip()]

    def parse_int_array(name):
        m = re.search(r'const int ' + name + r'\[\]\s*=\s*\{([^}]+)\};', text)
        return [int(x.strip()) for x in m.group(1).split(',') if x.strip()]

    coast_data = parse_float_array('COAST_DATA')
    coast_offsets = parse_int_array('COAST_OFFSETS')
    border_data = parse_float_array('BORDER_DATA')
    border_offsets = parse_int_array('BORDER_OFFSETS')
    return coast_data, coast_offsets, border_data, border_offsets


def render_gaza_globe(size, coast_data, coast_offsets, border_data, border_offsets,
                      sun_lon_offset=-40.0, sun_lat=5.0):
    scale = 4
    s = size * scale
    cx = s / 2.0
    cy = s / 2.0
    R = s * 0.45

    cLat = GAZA_LAT * math.pi / 180.0
    cLon = GAZA_LON * math.pi / 180.0

    sunLat = sun_lat * math.pi / 180.0
    sunLon = (GAZA_LON + sun_lon_offset) * math.pi / 180.0

    sc = (36 / 255.0, 195 / 255.0, 181 / 255.0)

    img = Image.new("RGBA", (s, s), (0, 0, 0, 0))
    pixels = img.load()

    for y in range(s):
        for x in range(s):
            dx = x - cx
            dy = y - cy
            r = math.hypot(dx, dy)
            if r > R:
                continue
            edge_alpha = min(1.0, max(0.0, R - r))
            xn = dx / R
            yn = dy / R
            z = math.sqrt(max(0.0, 1.0 - xn * xn - yn * yn))
            yn_gl = -yn

            sinLat = yn_gl * math.cos(cLat) + z * math.sin(cLat)
            cosLat = math.sqrt(max(0.0, 1.0 - sinLat * sinLat))
            lon = cLon + math.atan2(xn, z * math.cos(cLat) - yn_gl * math.sin(cLat))
            cosA = math.sin(sunLat) * sinLat + math.cos(sunLat) * cosLat * math.cos(lon - sunLon)

            nightOcean = [0.035 + sc[0] * 0.04, 0.065 + sc[1] * 0.04, 0.10 + sc[2] * 0.04]
            dayOcean = [0.05 + sc[0] * 0.14, 0.08 + sc[1] * 0.14, 0.12 + sc[2] * 0.14]

            dayT = max(0.0, min(1.0, (cosA - (-0.16)) / (0.08 - (-0.16))))
            dayT = dayT * dayT * (3.0 - 2.0 * dayT)

            col = [nightOcean[i] + (dayOcean[i] - nightOcean[i]) * dayT for i in range(3)]

            if cosA > 0.0:
                sunDiff = (cosA ** 0.80) * 0.22
                col[0] += sunDiff * 0.85
                col[1] += sunDiff * 0.95
                col[2] += sunDiff * 0.98

            twilight = math.exp(-((cosA + 0.02) / 0.09) ** 2) * 0.08
            col[0] += twilight * 0.20
            col[1] += twilight * 0.50
            col[2] += twilight * 0.80

            rim = 1.0 - z
            atmo = (rim ** 2.8) * 0.38
            atmoSun = max(0.18, min(1.0, (cosA + 0.20) / 0.50))
            col[0] += sc[0] * atmo * atmoSun
            col[1] += sc[1] * atmo * atmoSun
            col[2] += sc[2] * atmo * atmoSun

            r_c = int(min(255, max(0, col[0] * 255)))
            g_c = int(min(255, max(0, col[1] * 255)))
            b_c = int(min(255, max(0, col[2] * 255)))
            a_c = int(edge_alpha * 255)
            pixels[x, y] = (r_c, g_c, b_c, a_c)

    draw = ImageDraw.Draw(img)

    def proj(glon_deg, glat_deg):
        geo_lon = glon_deg * math.pi / 180.0
        geo_lat = glat_deg * math.pi / 180.0
        sinCLat = math.sin(cLat)
        cosCLat = math.cos(cLat)
        sinLat = math.sin(geo_lat)
        cosLat = math.cos(geo_lat)
        dLon = geo_lon - cLon
        x = R * cosLat * math.sin(dLon)
        y = R * (cosCLat * sinLat - sinCLat * cosLat * math.cos(dLon))
        z = sinCLat * sinLat + cosCLat * cosLat * math.cos(dLon)
        cosA = math.sin(sunLat) * sinLat + math.cos(sunLat) * cosLat * math.cos(geo_lon - sunLon)
        return (cx + x, cy - y, z, cosA)

    def draw_vector_layer(data, offsets, is_coast):
        for s_idx in range(len(offsets) - 1):
            start = offsets[s_idx]
            count = offsets[s_idx + 1] - start
            if count < 2:
                continue

            pts = []
            for i in range(count):
                glon = data[(start + i) * 2]
                glat = data[(start + i) * 2 + 1]
                pts.append(proj(glon, glat))

            for i in range(len(pts) - 1):
                p1, p2 = pts[i], pts[i + 1]
                if p1[2] < 0.0 and p2[2] < 0.0:
                    continue
                cosA_avg = (p1[3] + p2[3]) * 0.5
                dayFactor = max(0.0, min(1.0, (cosA_avg + 0.10) / 0.18))
                if dayFactor > 0.05:
                    halo_a = int(215 * dayFactor)
                    hw = int(scale * (2.4 if is_coast else 1.6))
                    draw.line([(p1[0], p1[1]), (p2[0], p2[1])], fill=(0, 8, 14, halo_a), width=hw)

        for s_idx in range(len(offsets) - 1):
            start = offsets[s_idx]
            count = offsets[s_idx + 1] - start
            if count < 2:
                continue

            pts = []
            for i in range(count):
                glon = data[(start + i) * 2]
                glat = data[(start + i) * 2 + 1]
                pts.append(proj(glon, glat))

            for i in range(len(pts) - 1):
                p1, p2 = pts[i], pts[i + 1]
                if p1[2] < 0.0 and p2[2] < 0.0:
                    continue
                cosA_avg = (p1[3] + p2[3]) * 0.5
                dayFactor = max(0.0, min(1.0, (cosA_avg + 0.08) / 0.16))

                if is_coast:
                    alpha = 255
                    lw = max(1, int(scale * 1.3))
                    draw.line([(p1[0], p1[1]), (p2[0], p2[1])], fill=(36, 195, 181, alpha), width=lw)
                else:
                    base_a = 0.55
                    alpha = int(255 * (base_a + (0.85 - base_a) * dayFactor))
                    lw = max(1, int(scale * 0.9))
                    draw.line([(p1[0], p1[1]), (p2[0], p2[1])], fill=(36, 195, 181, alpha), width=lw)

    draw_vector_layer(border_data, border_offsets, False)
    draw_vector_layer(coast_data, coast_offsets, True)

    rw = max(1, int(scale * 1.4))
    draw.ellipse([cx - R, cy - R, cx + R, cy + R], outline=(36, 195, 181, 150), width=rw)

    final_img = img.resize((size, size), Image.LANCZOS)

    glow = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    gd = ImageDraw.Draw(glow)
    R_icon = size * 0.45
    for i in range(4):
        ri = R_icon + i * (size * 0.012)
        a = max(0, int(45 - i * 11))
        gd.ellipse([size / 2 - ri, size / 2 - ri, size / 2 + ri, size / 2 + ri],
                   outline=(36, 195, 181, a), width=max(1, int(size * 0.01)))
    glow = glow.filter(ImageFilter.GaussianBlur(radius=max(1, size * 0.02)))

    result = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    result = Image.alpha_composite(result, glow)
    result = Image.alpha_composite(result, final_img)
    return result


def main():
    print("Loading vector data from src/geomdata.h ...")
    coast_data, coast_offsets, border_data, border_offsets = load_geomdata()

    for size in SIZES:
        out = OUTPUT_DIR.format(size=size)
        print(f"Rendering {size}x{size} centered on Gaza ...")
        icon = render_gaza_globe(size, coast_data, coast_offsets, border_data, border_offsets)
        os.makedirs(os.path.dirname(out), exist_ok=True)
        icon.save(out, "PNG")
        print(f"  -> {out}")

    print("All icons generated successfully.")


if __name__ == "__main__":
    main()
