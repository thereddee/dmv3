"""Contact sheet: python sheet.py out.png img1 img2 ... (labels = file names)."""
import os
import sys

from PIL import Image, ImageDraw

out, paths = sys.argv[1], sys.argv[2:]
cell_h = 420
tiles = []
for p in paths:
    im = Image.open(p).convert("RGBA")
    bg = Image.new("RGBA", im.size, (90, 110, 140, 255))
    bg.alpha_composite(im)
    w = round(im.width * cell_h / im.height)
    tiles.append((os.path.basename(p), bg.convert("RGB").resize((w, cell_h), Image.LANCZOS)))
sheet = Image.new("RGB", (sum(t.width for _, t in tiles) + 10 * (len(tiles) + 1), cell_h + 40), (30, 30, 30))
x = 10
draw = ImageDraw.Draw(sheet)
for name, tile in tiles:
    sheet.paste(tile, (x, 10))
    draw.text((x, cell_h + 16), name[:34], fill=(230, 230, 230))
    x += tile.width + 10
sheet.save(out)
print(out, sheet.size)
