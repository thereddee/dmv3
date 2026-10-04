"""Extracts the hair and outfit layers, tints them and assembles test characters + a review sheet."""
import os

from PIL import Image, ImageDraw

import artlib
import comfy_client as cc

HERE = os.path.dirname(os.path.abspath(__file__))
WORK = os.path.join(HERE, "pass1")
LAYERS = os.path.join(WORK, "layers")
GAME = os.path.join(WORK, "layers_128x192")
for d in (LAYERS, GAME):
    os.makedirs(d, exist_ok=True)

GAME_SIZE = (128, 192)
BACKDROP = (58, 62, 74, 255)


def export(name, layer):
    layer.save(os.path.join(LAYERS, name + ".png"))
    layer.resize(GAME_SIZE, Image.LANCZOS).save(os.path.join(GAME, name + ".png"))
    return layer


raw = {}
layers = {}
for key in ("a", "b"):
    layers["body_" + key] = export("body_" + key, artlib.to_greyscale(Image.open(os.path.join(WORK, "body_%s.png" % key))))
body_a = Image.open(os.path.join(WORK, "body_a.png"))
template = artlib.on_white(body_a)
neck = artlib.neck_row(body_a)
for name in ("hair_spiky", "hair_braid", "outfit_robe", "outfit_armor"):
    raw[name] = Image.open(os.path.join(cc.OUT_DIR, "pass1", name + "_00001_.png")).convert("RGB")
    if name.startswith("outfit"):
        piece = artlib.extract_changed(raw[name], template, neck - 6)
    else:
        piece = artlib.extract_coloured(raw[name])
    layers[name] = export(name, artlib.to_greyscale(piece))

SKIN = {"pale": (244, 208, 180), "brown": (160, 110, 78), "orc": (130, 170, 110)}
HAIR = {"red": (200, 70, 50), "black": (70, 62, 70), "blond": (235, 200, 110), "white": (235, 235, 240)}
ACCENT = {"blue": (80, 120, 220), "purple": (150, 90, 200), "steel": (170, 180, 195), "green": (80, 160, 100)}

characters = [
    ("a", "outfit_robe", "hair_spiky", "pale", "red", "purple"),
    ("a", "outfit_armor", "hair_braid", "brown", "black", "steel"),
    ("a", "outfit_armor", "hair_spiky", "orc", "white", "green"),
    ("a", "outfit_robe", "hair_braid", "pale", "blond", "blue"),
    ("b", "outfit_robe", "hair_braid", "brown", "white", "green"),
    ("b", "outfit_armor", "hair_spiky", "pale", "red", "steel"),
]
composites = []
for body, outfit, hair, skin, hair_colour, accent in characters:
    doll = artlib.stack([
        artlib.tint(layers["body_" + body], SKIN[skin]),
        artlib.tint(layers[outfit], ACCENT[accent]),
        artlib.tint(layers[hair], HAIR[hair_colour]),
    ])
    label = "body %s + %s + %s" % (body.upper(), outfit.split("_")[1], hair.split("_")[1])
    composites.append((label, doll))
    doll.save(os.path.join(WORK, "char_%d.png" % len(composites)))


def on_backdrop(rgba, size):
    bg = Image.new("RGBA", rgba.size, BACKDROP)
    bg.alpha_composite(rgba)
    return bg.convert("RGB").resize(size, Image.LANCZOS)


TILE = (256, 384)
rows = [
    ("1. Sortie brute de ComfyUI (inpainting par-dessus le corps A)", [(n, raw[n].resize(TILE, Image.LANCZOS)) for n in raw]),
    ("2. Couches extraites, en niveaux de gris (ce que le jeu chargerait)",
     [(n, on_backdrop(layers[n], TILE)) for n in layers]),
    ("3. Assemblage teinté (corps = peau, tenue = accent, cheveux = cheveux)",
     [(label, on_backdrop(doll, TILE)) for label, doll in composites]),
    ("4. Les mêmes à la taille du jeu, 128x192 (agrandi x2 sans lissage)",
     [(label, on_backdrop(doll.resize(GAME_SIZE, Image.LANCZOS).convert("RGBA"), GAME_SIZE).resize(TILE, Image.NEAREST))
      for label, doll in composites]),
]
width = 20 + max(len(tiles) for _, tiles in rows) * (TILE[0] + 12)
sheet = Image.new("RGB", (width, len(rows) * (TILE[1] + 64) + 10), (24, 24, 26))
draw = ImageDraw.Draw(sheet)
y = 10
for title, tiles in rows:
    draw.text((14, y), title, fill=(245, 200, 90))
    x = 14
    for label, tile in tiles:
        sheet.paste(tile, (x, y + 20))
        draw.text((x, y + 24 + TILE[1]), label, fill=(220, 220, 220))
        x += TILE[0] + 12
    y += TILE[1] + 64
sheet.save(os.path.join(WORK, "sheet_pass1.png"))
print("sheet", sheet.size)
