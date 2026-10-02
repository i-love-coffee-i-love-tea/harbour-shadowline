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
    R = s * 0.43
    max_dr = scale * 2.5

    cLat = GAZA_LAT * math.pi / 180.0
    cLon = GAZA_LON * math.pi / 180.0

    sunLat = sun_lat * math.pi / 180.0
    sunLon = (GAZA_LON + sun_lon_offset) * math.pi / 180.0

    dLon_sun = sunLon - cLon
    sunX_view = math.cos(sunLat) * math.sin(dLon_sun)
    sunY_view = math.cos(cLat) * math.sin(sunLat) - math.sin(cLat) * math.cos(sunLat) * math.cos(dLon_sun)

    sc = (36 / 255.0, 195 / 255.0, 181 / 255.0)

    img = Image.new("RGBA", (s, s), (0, 0, 0, 0))
    pixels = img.load()

    for y in range(s):
        for x in range(s):
            dx = x - cx
            dy = y - cy
            r = math.hypot(dx, dy)
            if r > R + max_dr:
                continue

            dr = r - R
            yn_gl = -dy / R
            xn = dx / R
            nx = dx / max(0.001, r)
            ny = -dy / max(0.001, r)

            cosA_limb = nx * sunX_view + ny * sunY_view
            sun_scatter = max(0.0, min(1.0, (cosA_limb - (-0.14)) / (0.28 - (-0.14))))
            sun_scatter = sun_scatter * sun_scatter * (3.0 - 2.0 * sun_scatter)
            limb_intensity = 0.18 + 0.82 * (sun_scatter ** 1.3)

            if r > R:
                glow = math.exp(-dr / (scale * 0.9)) * (1.0 - dr / max_dr)
                corona_a = glow * limb_intensity * 0.55
                whitening = 0.20 * sun_scatter
                corona_col = [sc[i] * (1.0 - whitening) + whitening for i in range(3)]
                pixels[x, y] = (int(corona_col[0] * 255), int(corona_col[1] * 255), int(corona_col[2] * 255), int(corona_a * 255))
                continue

            edge_alpha = min(1.0, max(0.0, R - r))
            z = math.sqrt(max(0.0, 1.0 - xn * xn - yn_gl * yn_gl))

            sinLat = yn_gl * math.cos(cLat) + z * math.sin(cLat)
            cosLat = math.sqrt(max(0.0, 1.0 - sinLat * sinLat))
            lon = cLon + math.atan2(xn, z * math.cos(cLat) - yn_gl * math.sin(cLat))
            cosA = math.sin(sunLat) * sinLat + math.cos(sunLat) * cosLat * math.cos(lon - sunLon)

            nightOcean = [0.0, 42.0 / 255.0, 42.0 / 255.0]
            dayOcean = [0.0, 77.0 / 255.0, 77.0 / 255.0]

            dayT = max(0.0, min(1.0, (cosA - (-0.12)) / (0.08 - (-0.12))))
            dayT = dayT * dayT * (3.0 - 2.0 * dayT)

            col = [nightOcean[i] + (dayOcean[i] - nightOcean[i]) * dayT for i in range(3)]
            rim = 1.0 - z
            limb_in = (rim ** 3.0) * 0.32 * limb_intensity
            col = [min(1.0, col[i] + sc[i] * limb_in) for i in range(3)]

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

                if is_coast:
                    alpha = 255
                    lw = max(1, int(scale * 1.2))
                    draw.line([(p1[0], p1[1]), (p2[0], p2[1])], fill=(36, 195, 181, alpha), width=lw)
                else:
                    alpha = int(255 * 0.35)
                    lw = max(1, int(scale * 0.8))
                    draw.line([(p1[0], p1[1]), (p2[0], p2[1])], fill=(36, 195, 181, alpha), width=lw)

    draw_vector_layer(border_data, border_offsets, False)
    draw_vector_layer(coast_data, coast_offsets, True)

    rw = max(1, int(scale * 1.4))
    draw.ellipse([cx - R, cy - R, cx + R, cy + R], outline=(36, 195, 181, 150), width=rw)

    final_img = img.resize((size, size), Image.LANCZOS)
    return final_img


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
