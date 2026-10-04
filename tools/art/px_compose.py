"""Pixel-art pass, step 3: extract layers, snap them to the 128x192 game grid, tint, assemble, review sheet."""
import glob
import os

import numpy as np
from PIL import Image, ImageDraw, ImageFilter

import artlib
import comfy_client as cc

HERE = os.path.dirname(os.path.abspath(__file__))
WORK = os.path.join(HERE, "px")
GAME_DIR = os.path.join(WORK, "layers_128x192")
os.makedirs(GAME_DIR, exist_ok=True)

GAME = (128, 192)
GREY_STEPS = 5
BACKDROP = (58, 62, 74, 255)


def to_game(rgba, grey=True, smooth=9):
    """Nearest-neighbour snap to the game canvas, hard alpha, a few grey levels: real pixels."""
    if grey:
        # Smooth the model's faint noise first, or the grey steps come out speckled.
        alpha = rgba.getchannel("A")
        rgba = rgba.convert("RGB").filter(ImageFilter.MedianFilter(smooth)).convert("RGBA")
        rgba.putalpha(alpha)
    small = rgba.resize(GAME, Image.NEAREST)
    arr = np.asarray(small).copy()
    arr[..., 3] = np.where(arr[..., 3] > 127, 255, 0)
    if grey:
        step = 255.0 / (GREY_STEPS - 1)
        arr[..., :3] = (np.round(arr[..., :3] / step) * step).astype(np.uint8)
    arr[arr[..., 3] == 0] = 0
    return Image.fromarray(arr, "RGBA")


def extract_face(result, template, mask_box):
    """Dark pixels the inpainting added inside the face box."""
    new = np.asarray(result.convert("RGB")).astype(np.int32)
    old = np.asarray(template.convert("RGB")).astype(np.int32)
    dark = (new.max(axis=-1) < 110) & (np.abs(new - old).max(axis=-1) > 50)
    keep = np.zeros_like(dark)
    x0, y0, x1, y1 = mask_box
    keep[y0:y1, x0:x1] = True
    out = result.convert("RGBA")
    out.putalpha(Image.fromarray(((dark & keep) * 255).astype(np.uint8)))
    return out


body_full = Image.open(os.path.join(WORK, "body.png"))
template = artlib.on_white(body_full)
face_box = Image.open(os.path.join(WORK, "dmv3_px_mask_face.png")).convert("L").getbbox()

raw = {}
# A lighter smoothing on the body keeps the arm and leg lines.
layers = {"body": to_game(artlib.to_greyscale(body_full), smooth=5)}
for path in sorted(glob.glob(os.path.join(cc.OUT_DIR, "px", "*_00001_.png"))):
    name = os.path.basename(path).replace("_00001_.png", "")
    if name.startswith("body"):
        continue
    raw[name] = Image.open(path).convert("RGB")
    if name.startswith("face"):
        layers[name] = to_game(extract_face(raw[name], template, face_box), grey=False)
    elif name.startswith("outfit"):
        layers[name] = to_game(artlib.to_greyscale(artlib.extract_outfit(raw[name], template)))
    else:
        layers[name] = to_game(artlib.to_greyscale(artlib.extract_coloured(raw[name])))
for name, layer in layers.items():
    layer.save(os.path.join(GAME_DIR, name + ".png"))

SKIN = {"pale": (244, 208, 180), "brown": (160, 110, 78), "orc": (130, 170, 110), "tan": (215, 165, 125)}
HAIR = {"red": (205, 75, 50), "black": (80, 70, 80), "blond": (240, 205, 110), "white": (240, 240, 245), "brown": (130, 85, 50)}
ACCENT = {"blue": (80, 120, 225), "purple": (155, 95, 205), "steel": (175, 185, 200), "green": (85, 165, 100),
          "leather": (165, 115, 70), "red": (200, 70, 70)}

hairs = [n for n in layers if n.startswith("hair")]
outfits = [n for n in layers if n.startswith("outfit")]
faces = [n for n in layers if n.startswith("face")]
recipes = [
    (0, 0, "pale", "red", "purple"), (1, 1, "brown", "black", "steel"), (2, 2, "tan", "brown", "leather"),
    (3, 0, "pale", "blond", "blue"), (1, 1, "orc", "white", "green"), (2, 2, "brown", "white", "red"),
    (3, 1, "tan", "black", "purple"),
]
composites = []
for outfit_i, hair_i, skin, hair_colour, accent in recipes:
    if not outfits or not hairs:
        break
    outfit = outfits[outfit_i % len(outfits)]
    hair = hairs[hair_i % len(hairs)]
    stack = Image.new("RGBA", GAME, (0, 0, 0, 0))
    stack.alpha_composite(artlib.tint(layers["body"], SKIN[skin]))
    stack.alpha_composite(layers[faces[len(composites) % len(faces)]])
    stack.alpha_composite(artlib.tint(layers[outfit], ACCENT[accent]))
    stack.alpha_composite(artlib.tint(layers[hair], HAIR[hair_colour]))
    composites.append(("%s + %s" % (outfit.split("_", 1)[1], hair.split("_", 1)[1]), stack))
    stack.save(os.path.join(WORK, "char_%d.png" % len(composites)))

TILE = (256, 384)


def show(rgba):
    bg = Image.new("RGBA", rgba.size, BACKDROP)
    bg.alpha_composite(rgba)
    return bg.convert("RGB").resize(TILE, Image.NEAREST)


rows = [
    ("1. Sortie brute de ComfyUI (inpainting par-dessus le gabarit)", [(n, raw[n].resize(TILE, Image.LANCZOS)) for n in raw]),
    ("2. Couches du jeu, 128x192, niveaux de gris", [(n, show(layers[n])) for n in layers]),
    ("3. Personnages assembles et teintes, 128x192 (agrandi x2)", [(label, show(doll)) for label, doll in composites]),
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
sheet.save(os.path.join(WORK, "sheet_px.png"))
print("sheet", sheet.size, "layers", list(layers))
