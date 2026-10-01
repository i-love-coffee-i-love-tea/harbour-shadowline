#!/usr/bin/env python3
"""Generate half-dark Earth app icons for harbour-shadowline.

Uses real Natural Earth coastline data (ne_110m_land.geojson) to render
accurate land masses on a sphere with a day/night terminator.

Input:  tools/ne_land.geojson  (or tools/land_mask.png if already rasterized)
Output: rpm/icons/{86x86,108x108,128x128,172x172}/harbour-shadowline.png

Usage:
    python3 tools/generate-icons.py
"""
import math
import os
import json

from PIL import Image, ImageDraw, ImageFilter

SIZES = [86, 108, 128, 172]
SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
PROJECT_DIR = os.path.dirname(SCRIPT_DIR)
OUTPUT_DIR = os.path.join(PROJECT_DIR, "rpm/icons/{size}x{size}/harbour-shadowline.png")
GEOJSON_PATH = os.path.join(SCRIPT_DIR, "ne_land.geojson")
LAND_MASK_PATH = os.path.join(SCRIPT_DIR, "land_mask.png")
LAND_MASK_SIZE = (4096, 2048)


def build_land_mask(force=False):
    """Rasterize GeoJSON coastlines into a grayscale land mask image."""
    if not force and os.path.exists(LAND_MASK_PATH):
        mask = Image.open(LAND_MASK_PATH).convert("L")
        if mask.size == LAND_MASK_SIZE:
            print(f"Reusing existing land mask: {LAND_MASK_PATH}")
            return mask

    print(f"Rasterizing land mask from {GEOJSON_PATH} ...")
    with open(GEOJSON_PATH) as f:
        data = json.load(f)

    W, H = LAND_MASK_SIZE
    mask = Image.new("L", (W, H), 0)
    draw = ImageDraw.Draw(mask)

    def lonlat_to_px(lon, lat):
        return (int((lon + 180) / 360 * W), int((90 - lat) / 180 * H))

    for feat in data["features"]:
        geom = feat["geometry"]
        if geom["type"] == "Polygon":
            rings = geom["coordinates"]
        elif geom["type"] == "MultiPolygon":
            rings = [ring for poly in geom["coordinates"] for ring in poly]
        else:
            continue
        for ring in rings:
            pts = [lonlat_to_px(lon, lat) for lon, lat in ring]
            if len(pts) >= 3:
                try:
                    draw.polygon(pts, fill=255)
                except Exception:
                    pass

    mask.save(LAND_MASK_PATH)
    print(f"Saved land mask: {LAND_MASK_PATH} ({W}x{H})")
    return mask


def is_land(lat_deg, lon_deg, mask, mask_pixels):
    u = int((lon_deg + 180) / 360 * mask.width) % mask.width
    v = max(0, min(mask.height - 1, int((90 - lat_deg) / 180 * mask.height)))
    return mask_pixels[u, v] > 128


def render_icon(size, mask, mask_pixels):
    """Render a half-dark Earth icon at the given pixel size."""
    s = size * 4  # 4x supersample
    img = Image.new("RGBA", (s, s), (0, 0, 0, 0))
    px = img.load()
    cx, cy = s / 2.0, s / 2.0
    R = s * 0.46
    rot = 15.0

    # Sun direction (from upper-right)
    sun_dx, sun_dy = 0.8, -0.2
    sun_len = math.sqrt(sun_dx ** 2 + sun_dy ** 2)
    sun_dx /= sun_len
    sun_dy /= sun_len

    for x in range(s):
        for y in range(s):
            dx, dy = x - cx, y - cy
            if dx * dx + dy * dy > R * R:
                continue
            nx, ny = dx / R, dy / R
            nz = math.sqrt(max(0, 1 - nx * nx - ny * ny))

            lat = math.degrees(math.asin(max(-1, min(1, -ny))))
            lon = math.degrees(math.atan2(nx, nz)) + rot
            lon = ((lon + 180) % 360) - 180

            land = is_land(lat, lon, mask, mask_pixels)

            sun_dz = math.sqrt(max(0, 1 - sun_dx ** 2 - sun_dy ** 2))
            sun_dot = nx * sun_dx + ny * sun_dy + nz * sun_dz

            # Smooth day/night transition (no hard line)
            day = max(0, min(1, (sun_dot + 0.15) / 0.30))

            # Day side colors
            if land:
                dr, dg, db = 60, 180, 70
            else:
                dr, dg, db = 35, 120, 240

            # Night side colors
            if land:
                nr, ng, nb = 38, 72, 38
            else:
                nr, ng, nb = 25, 42, 85

            # Blend
            r = int(dr * day + nr * (1 - day))
            g = int(dg * day + ng * (1 - day))
            b = int(db * day + nb * (1 - day))

            # Atmosphere rim
            if nz > 0.93:
                rim = (nz - 0.93) / 0.07
                if sun_dot > 0:
                    r = min(255, r + int(100 * rim * sun_dot))
                    g = min(255, g + int(160 * rim * sun_dot))
                    b = min(255, b + int(255 * rim * sun_dot))
                else:
                    r = min(255, r + int(25 * rim))
                    g = min(255, g + int(45 * rim))
                    b = min(255, b + int(100 * rim))

            px[x, y] = (max(0, min(255, r)), max(0, min(255, g)), max(0, min(255, b)), 255)

    # Downscale with high-quality resampling
    img = img.resize((size, size), Image.LANCZOS)

    # Outer atmosphere glow
    glow = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    gd = ImageDraw.Draw(glow)
    cx2, cy2 = size / 2.0, size / 2.0
    R2 = size * 0.46
    for i in range(5):
        ri = R2 + i * size * 0.016
        a = max(0, int(50 - i * 12))
        gd.ellipse(
            [cx2 - ri, cy2 - ri, cx2 + ri, cy2 + ri],
            outline=(60, 140, 255, a),
            width=max(1, int(size * 0.01)),
        )
    glow = glow.filter(ImageFilter.GaussianBlur(radius=max(1, size * 0.02)))

    result = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    result = Image.alpha_composite(result, glow)
    result = Image.alpha_composite(result, img)
    return result


def main():
    mask = build_land_mask()
    mask_pixels = mask.load()

    for size in SIZES:
        out = OUTPUT_DIR.format(size=size)
        print(f"Rendering {size}x{size} ...")
        render_icon(size, mask, mask_pixels).save(out, "PNG")
        print(f"  -> {out}")

    print("All icons generated.")


if __name__ == "__main__":
    main()