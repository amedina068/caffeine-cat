"""Slice the cat sprite sheet into animation frames and build the app icon.

Usage: python3 tools/slice_sprites.py <sprite-sheet.png> <output-dir>
"""
import sys
from collections import deque
from pathlib import Path

from PIL import Image, ImageDraw, ImageFilter

ALPHA_CUTOFF = 100
MIN_PIXELS = 30
MAIN_SPRITE_PIXELS = 10000
PAD = 6


def find_components(alpha, width, height):
    seen = bytearray(width * height)
    comps = []
    for y in range(height):
        for x in range(width):
            if seen[y * width + x] or alpha[x, y] < ALPHA_CUTOFF:
                continue
            queue = deque([(x, y)])
            seen[y * width + x] = 1
            x0 = x1 = x
            y0 = y1 = y
            count = 0
            while queue:
                cx, cy = queue.popleft()
                count += 1
                x0, x1, y0, y1 = min(x0, cx), max(x1, cx), min(y0, cy), max(y1, cy)
                for nx, ny in ((cx + 1, cy), (cx - 1, cy), (cx, cy + 1), (cx, cy - 1)):
                    if 0 <= nx < width and 0 <= ny < height:
                        j = ny * width + nx
                        if not seen[j] and alpha[nx, ny] >= ALPHA_CUTOFF:
                            seen[j] = 1
                            queue.append((nx, ny))
            if count > MIN_PIXELS:
                comps.append({"box": (x0, y0, x1 + 1, y1 + 1), "n": count})
    return comps


def clean_crop(sheet, box):
    """Crop a region and make the alpha binary so the glow halo disappears."""
    crop = sheet.crop(box)
    alpha = crop.getchannel("A").point(lambda v: 255 if v >= 128 else 0)
    crop.putalpha(alpha)
    return crop


def union(boxes):
    return (min(b[0] for b in boxes), min(b[1] for b in boxes),
            max(b[2] for b in boxes), max(b[3] for b in boxes))


def attach_extras(mains, extras):
    """Give each small part (steam, heart, zZ) to the nearest main sprite."""
    groups = [{"main": m["box"], "parts": [m["box"]]} for m in mains]
    for extra in extras:
        ex = (extra["box"][0] + extra["box"][2]) / 2
        best = min(groups, key=lambda g: abs((g["main"][0] + g["main"][2]) / 2 - ex))
        best["parts"].append(extra["box"])
    return groups


def render_row(sheet, groups, names, out_dir):
    """Paste each frame on a shared canvas: bottom aligned, centered on the main sprite."""
    left = max((g["main"][0] + g["main"][2]) / 2 - union(g["parts"])[0] for g in groups)
    right = max(union(g["parts"])[2] - (g["main"][0] + g["main"][2]) / 2 for g in groups)
    above = max(g["main"][3] - union(g["parts"])[1] for g in groups)
    half = int(max(left, right)) + PAD
    canvas_w, canvas_h = half * 2, int(above) + PAD * 2
    for group, name in zip(groups, names):
        center_x = (group["main"][0] + group["main"][2]) / 2
        canvas = Image.new("RGBA", (canvas_w, canvas_h), (0, 0, 0, 0))
        for part in group["parts"]:
            crop = clean_crop(sheet, part)
            dx = int(half + part[0] - center_x)
            dy = int(canvas_h - PAD - (group["main"][3] - part[1]))
            canvas.alpha_composite(crop, (dx, dy))
        canvas.save(out_dir / f"{name}.png")
    return canvas_w, canvas_h


def build_icon(frame_path, out_path):
    size = 1024
    icon = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    bg = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    draw = ImageDraw.Draw(bg)
    draw.rounded_rectangle((100, 100, 924, 924), radius=185, fill=(44, 33, 29, 255))
    glow = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    ImageDraw.Draw(glow).ellipse((220, 380, 804, 900), fill=(214, 128, 64, 170))
    glow = glow.filter(ImageFilter.GaussianBlur(90))
    mask = bg.getchannel("A")
    glow.putalpha(Image.composite(glow.getchannel("A"), Image.new("L", (size, size), 0), mask))
    icon.alpha_composite(bg)
    icon.alpha_composite(glow)
    cat = Image.open(frame_path)
    scale = 640 / cat.height
    cat = cat.resize((int(cat.width * scale), int(cat.height * scale)), Image.NEAREST)
    icon.alpha_composite(cat, ((size - cat.width) // 2, 860 - cat.height))
    icon.save(out_path)


def main():
    sheet_path, out_dir = Path(sys.argv[1]), Path(sys.argv[2])
    out_dir.mkdir(parents=True, exist_ok=True)
    sheet = Image.open(sheet_path).convert("RGBA")
    comps = find_components(sheet.getchannel("A").load(), *sheet.size)

    def row(lo, hi):
        items = [c for c in comps if lo <= c["box"][1] < hi]
        mains = sorted((c for c in items if c["n"] >= MAIN_SPRITE_PIXELS), key=lambda c: c["box"][0])
        extras = [c for c in items if c["n"] < MAIN_SPRITE_PIXELS]
        return mains, extras

    mains, extras = row(0, 440)
    coffee = attach_extras(mains, extras)
    print("coffee", render_row(sheet, coffee, [f"coffee_{i}" for i in range(1, 7)], out_dir))

    mains, extras = row(440, 740)
    spin = attach_extras(mains, extras)
    print("spin", render_row(sheet, spin, [f"spin_{i}" for i in range(1, 8)], out_dir))

    mains, extras = row(740, 1024)
    floor = [{"main": m["box"], "parts": [m["box"]]} for m in mains]
    zs = sorted(extras, key=lambda c: c["box"][0])
    names = ["walk_1", "walk_2", "walk_3", "walk_4", "stretch_1", "stretch_2", "sleep_body"]
    # The zZ parts go on the sleeping frame so the canvas leaves room for them.
    floor[-1]["parts"] += [z["box"] for z in zs]
    print("floor", render_row(sheet, floor, names, out_dir))
    # Split the sleeping frame into the body and each Z on identical canvases,
    # so the app can float the Zs on their own.
    sleep = floor[-1]
    w, h = Image.open(out_dir / "sleep_body.png").size
    center_x = (sleep["main"][0] + sleep["main"][2]) / 2
    layers = [("sleep_body", sleep["main"])] + [(f"sleep_z{i}", z["box"]) for i, z in enumerate(zs, 1)]
    for name, part in layers:
        canvas = Image.new("RGBA", (w, h), (0, 0, 0, 0))
        dx = int(w // 2 + part[0] - center_x)
        dy = int(h - PAD - (sleep["main"][3] - part[1]))
        canvas.alpha_composite(clean_crop(sheet, part), (dx, dy))
        canvas.save(out_dir / f"{name}.png")

    build_icon(out_dir / "coffee_1.png", out_dir.parent / "icon_1024.png")


if __name__ == "__main__":
    main()
