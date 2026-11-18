#!/usr/bin/env python3
"""
Validates authentic MapLibre Style Specification v8 font glyphs (SDF PBF) and
generates RGBA sprite atlases for offline rendering:
1. Verifies authentic SDF Font Glyphs Protobuf (Noto Sans Regular/0-255.pbf)
   adhering strictly to glyphs.proto with (width + 6) * (height + 6) SDF buffers.
   (Never overwrites real SDF glyphs with synthetic placeholder rectangles.)
2. Generates Sprite atlas PNG (sprite.png: 32x16 RGBA) and @2x (sprite@2x.png: 64x32 RGBA).
3. Generates Sprite metadata JSON (sprite.json and sprite@2x.json).
"""

import json
import os
import struct
import sys
import zlib


def _read_varint(buf, pos):
    val = 0
    shift = 0
    while True:
        if pos >= len(buf):
            raise ValueError("Unexpected EOF while reading protobuf varint")
        b = buf[pos]
        pos += 1
        val |= (b & 0x7F) << shift
        if not (b & 0x80):
            return val, pos
        shift += 7


def verify_font_pbf(font_path, expected_name="Noto Sans Regular", expected_range="0-255"):
    if not os.path.isfile(font_path):
        raise FileNotFoundError(f"Font PBF missing: {font_path}")

    with open(font_path, "rb") as f:
        data = f.read()

    if len(data) < 40000:
        raise ValueError(f"Font PBF too small ({len(data)} bytes); expected authentic SDF > 40 KB")

    pos = 0
    tag, pos = _read_varint(data, pos)
    if tag != 0x0A:
        raise ValueError(f"Invalid outer glyphs.proto tag: {hex(tag)}")

    fs_len, pos = _read_varint(data, pos)
    if pos + fs_len != len(data):
        raise ValueError("Outer fontstack length does not match file size")

    fs_body = data[pos : pos + fs_len]
    p = 0
    name = None
    font_range = None
    glyph_count = 0
    unique_bitmaps = set()

    while p < len(fs_body):
        t, p = _read_varint(fs_body, p)
        fnum, wtype = t >> 3, t & 7
        if wtype == 2:
            length, p = _read_varint(fs_body, p)
            val = fs_body[p : p + length]
            p += length
            if fnum == 1:
                name = val.decode("utf-8")
            elif fnum == 2:
                font_range = val.decode("utf-8")
            elif fnum == 3:
                glyph_count += 1
                gp = 0
                g = {}
                while gp < len(val):
                    gt, gp = _read_varint(val, gp)
                    gf, gw = gt >> 3, gt & 7
                    if gw == 0:
                        gv, gp = _read_varint(val, gp)
                        g[gf] = gv
                    elif gw == 2:
                        gl, gp = _read_varint(val, gp)
                        g[gf] = val[gp : gp + gl]
                        gp += gl
                w = g.get(3, 0)
                h = g.get(4, 0)
                bmp = g.get(2, b"")
                if w > 0 and h > 0:
                    expected_sdf_len = (w + 6) * (h + 6)
                    if len(bmp) != expected_sdf_len:
                        raise ValueError(
                            f"Glyph {g.get(1)} has invalid SDF length {len(bmp)} "
                            f"(expected (w+6)*(h+6)={expected_sdf_len})"
                        )
                    unique_bitmaps.add(bmp)
        elif wtype == 0:
            _, p = _read_varint(fs_body, p)
        else:
            raise ValueError(f"Unsupported protobuf wire type {wtype} in fontstack")

    if name != expected_name:
        raise ValueError(f"Fontstack name mismatch: got {name!r}, expected {expected_name!r}")
    if font_range != expected_range:
        raise ValueError(f"Fontstack range mismatch: got {font_range!r}, expected {expected_range!r}")
    if glyph_count < 180 or len(unique_bitmaps) < 150:
        raise ValueError(
            f"Font PBF lacks authentic glyph diversity: {glyph_count} glyphs, "
            f"{len(unique_bitmaps)} unique bitmaps"
        )

    print(
        f"Verified authentic SDF font PBF: {font_path} "
        f"({len(data)} bytes, {glyph_count} glyphs, {len(unique_bitmaps)} unique SDF bitmaps)"
    )


def create_png(width, height, get_pixel_rgba):
    raw_scanlines = bytearray()
    for y in range(height):
        raw_scanlines.append(0)  # Filter type None
        for x in range(width):
            r, g, b, a = get_pixel_rgba(x, y)
            raw_scanlines.extend([r, g, b, a])

    def png_chunk(chunk_type, data):
        return (
            struct.pack(">I", len(data))
            + chunk_type
            + data
            + struct.pack(">I", zlib.crc32(chunk_type + data) & 0xFFFFFFFF)
        )

    sig = b"\x89PNG\r\n\x1a\n"
    ihdr_data = struct.pack(">IIBBBBB", width, height, 8, 6, 0, 0, 0)
    ihdr = png_chunk(b"IHDR", ihdr_data)
    idat = png_chunk(b"IDAT", zlib.compress(bytes(raw_scanlines), 9))
    iend = png_chunk(b"IEND", b"")
    return sig + ihdr + idat + iend


def generate_sprites(sprites_dir):
    os.makedirs(sprites_dir, exist_ok=True)

    # 1. 1x Sprite (32x16)
    # [0..14] = marker-15 (pin icon: red teardrop with white dot)
    # [16..30] = landmark-15 (landmark cross icon: blue square with white cross)
    def pixel_1x(x, y):
        if 0 <= x < 15 and 0 <= y < 15:
            dx = x - 7
            dy = y - 6
            dist_sq = dx * dx + dy * dy
            if dist_sq <= 3:
                return (255, 255, 255, 255)
            elif dist_sq <= 28 or (y >= 6 and abs(dx) <= (14 - y) * 0.7):
                return (220, 38, 38, 255)
            return (0, 0, 0, 0)
        elif 16 <= x < 31 and 0 <= y < 15:
            lx = x - 16
            ly = y
            if 1 <= lx <= 13 and 1 <= ly <= 13:
                if (5 <= lx <= 9 and 3 <= ly <= 11) or (3 <= lx <= 11 and 5 <= ly <= 9):
                    return (255, 255, 255, 255)
                return (37, 99, 235, 255)
            return (0, 0, 0, 0)
        return (0, 0, 0, 0)

    png_1x = create_png(32, 16, pixel_1x)
    png_1x_path = os.path.join(sprites_dir, "sprite.png")
    with open(png_1x_path, "wb") as f:
        f.write(png_1x)
    print(f"Generated sprite 1x: {png_1x_path} ({len(png_1x)} bytes)")

    json_1x = {
        "marker-15": {"width": 15, "height": 15, "x": 0, "y": 0, "pixelRatio": 1},
        "landmark-15": {"width": 15, "height": 15, "x": 16, "y": 0, "pixelRatio": 1},
    }
    json_1x_path = os.path.join(sprites_dir, "sprite.json")
    with open(json_1x_path, "w", encoding="utf-8") as f:
        json.dump(json_1x, f, indent=2)
    print(f"Generated sprite JSON 1x: {json_1x_path}")

    # 2. 2x Sprite (64x32)
    def pixel_2x(x, y):
        return pixel_1x(x // 2, y // 2)

    png_2x = create_png(64, 32, pixel_2x)
    png_2x_path = os.path.join(sprites_dir, "sprite@2x.png")
    with open(png_2x_path, "wb") as f:
        f.write(png_2x)
    print(f"Generated sprite 2x: {png_2x_path} ({len(png_2x)} bytes)")

    json_2x = {
        "marker-15": {"width": 30, "height": 30, "x": 0, "y": 0, "pixelRatio": 2},
        "landmark-15": {"width": 30, "height": 30, "x": 32, "y": 0, "pixelRatio": 2},
    }
    json_2x_path = os.path.join(sprites_dir, "sprite@2x.json")
    with open(json_2x_path, "w", encoding="utf-8") as f:
        json.dump(json_2x, f, indent=2)
    print(f"Generated sprite JSON 2x: {json_2x_path}")


if __name__ == "__main__":
    base_dir = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
    font_file = os.path.join(
        base_dir, "assets", "map", "fonts", "Noto Sans Regular", "0-255.pbf"
    )
    sprites_folder = os.path.join(base_dir, "assets", "map", "sprites")

    verify_font_pbf(font_file)
    if "--verify-only" not in sys.argv:
        generate_sprites(sprites_folder)
    print("All authentic cartographic assets verified successfully.")
