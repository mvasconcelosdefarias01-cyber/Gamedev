#!/usr/bin/env python3
"""Reproducible inventory and phase contact sheets for visual review."""
from __future__ import annotations

import argparse
import json
import math
from pathlib import Path
from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / "docs" / "art"
ASSETS = ROOT / "assets"
GROUPS = {
    "a_palette_ground": ("terrain/",),
    "b_crops": ("crops/",),
    "c_characters_portraits": ("characters/", "portraits/"),
    "d_structures_decorations": ("structures/", "decoration/"),
    "e_machines_water_effects": ("machines/", "effects/", "terrain/water", "terrain/wet"),
    "f_ui": ("ui/", "ui16/", "narrative/"),
}


def sheet(items: list[tuple[str, dict]], dest: Path) -> None:
    width, height, columns = 180, 170, 8
    rows = math.ceil(len(items) / columns)
    result = Image.new("RGBA", (columns * width, max(1, rows) * height), "#f7f4eb")
    draw = ImageDraw.Draw(result)
    for i, (aid, meta) in enumerate(items):
        relative = meta["path"].removeprefix("res://assets/")
        source = Image.open(ASSETS / relative).convert("RGBA")
        fw, fh = meta["frame_size"]
        # Include the whole animation strip, plus the first frame at a usable scale.
        frame = source.crop((0, 0, fw, fh))
        factor = min(4, 160 // fw, 126 // fh)
        if factor > 1:
            frame = frame.resize((fw * factor, fh * factor), Image.Resampling.NEAREST)
        frame.thumbnail((160, 126), Image.Resampling.NEAREST)
        x, y = i % columns * width, i // columns * height
        result.alpha_composite(frame, (x + (width - frame.width) // 2, y + 4))
        if source.width > fw or source.height > fh:
            strip = source.copy()
            strip.thumbnail((162, 16), Image.Resampling.NEAREST)
            result.alpha_composite(strip, (x + (width - strip.width) // 2, y + 130))
        draw.text((x + 5, y + 150), aid[:27], fill="#243c47")
    dest.parent.mkdir(parents=True, exist_ok=True)
    result.save(dest, optimize=True)


def crop_stages(assets: dict, dest: Path) -> None:
    im = Image.new("RGBA", (1020, 810), "#f7f4eb")
    d = ImageDraw.Draw(im)
    names = ("Nabo", "Feijão", "Milho", "Abóbora", "Linho", "Flor de sino")
    for j, name in enumerate(("Semente", "Broto", "Crescimento", "Maduro A", "Maduro B")):
        d.text((135 + j * 164, 22), name, fill="#243c47")
    for row in range(6):
        cid = f"C{row + 1}"
        meta = assets[f"crop_{cid}"]
        path = ASSETS / meta["path"].removeprefix("res://assets/")
        source = Image.open(path).convert("RGBA")
        d.text((20, 97 + row * 125), f"{cid} · {names[row]}", fill="#243c47")
        for stage in range(5):
            frame = source.crop((stage * 32, 0, (stage + 1) * 32, 40))
            frame = frame.resize((96, 120), Image.Resampling.NEAREST)
            im.alpha_composite(frame, (145 + stage * 164, 57 + row * 125))
    im.save(dest, optimize=True)


def palette_ground(dest: Path, palette: dict) -> None:
    ground = Image.open(dest).convert("RGBA")
    top = 192
    result = Image.new("RGBA", (ground.width, ground.height + top), "#f7f4eb")
    d = ImageDraw.Draw(result)
    for i, (name, color) in enumerate(palette.items()):
        x, y = i % 12 * 120, i // 12 * 46
        d.rectangle((x + 3, y + 3, x + 38, y + 34), fill=color)
        d.text((x + 43, y + 8), name[:12], fill="#243c47")
    result.alpha_composite(ground, (0, top))
    result.save(dest, optimize=True)


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("phase", choices=["before", "after", *GROUPS])
    args = parser.parse_args()
    manifest = json.loads((ASSETS / "manifest.json").read_text())
    items = sorted(((aid, meta) for aid, meta in manifest["assets"].items()
                    if meta.get("frame_size")), key=lambda value: value[1]["path"])
    if args.phase in GROUPS:
        items = [(aid, meta) for aid, meta in items if
                 meta["path"].removeprefix("res://assets/").startswith(GROUPS[args.phase])]
    dest = OUT / ("contact_sheet_" + args.phase + ".png")
    sheet(items, dest)
    if args.phase == "a_palette_ground":
        palette_ground(dest, manifest["palette"])
    elif args.phase == "b_crops":
        crop_stages(manifest["assets"], dest)


if __name__ == "__main__":
    main()
