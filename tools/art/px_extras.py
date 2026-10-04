"""Pixel-art pass, extras: weapons, accessories and race traits inpainted over the body template.
Weapons and accessories keep their own colours, so they are painted over a GREEN copy of the body
(anything not green and not white is the piece). Race traits are skin, so they go over the grey body.
Usage: python px_extras.py [gen] [names...]   (without "gen": only extraction and the sheet)"""
import os
import sys
import time
import urllib.request

import numpy as np
from PIL import Image, ImageDraw, ImageFilter

import artlib
import comfy_client as cc
from px_bodies import PIXEL

HERE = os.path.dirname(os.path.abspath(__file__))
WORK = os.path.join(HERE, "px")
OUT = os.path.join(WORK, "extras_128x192")
os.makedirs(OUT, exist_ok=True)
GAME = (128, 192)
W, H = artlib.CANVAS
GREEN = (90, 200, 110)

body = Image.open(os.path.join(WORK, "body.png"))
grey_template = artlib.on_white(body)
green_template = artlib.on_white(artlib.tint(artlib.to_greyscale(body), GREEN))
neck = artlib.neck_row(body)
x0, top, x1, _bottom = body.getchannel("A").getbbox()
head_h = neck - top

GREEN_DOLL = "a blank featureless bright green mannequin doll, bald, chibi proportions with a large round head, no face, "
GREY_DOLL = "a blank featureless light grey mannequin doll, bald, chibi proportions with a large round head, no eyes, no mouth, "
SIDE = (x1 - 62, top + 60, W, H)
# name, layer, template, mask rectangles, kept rectangle, seed, prompt
JOBS = [
    ("acc_glasses", "accessory", "green", [(x0 + 40, top + int(head_h * 0.38), x1 - 40, neck - int(head_h * 0.10))], None, 911,
     GREEN_DOLL + "wearing big round glasses with a thick black frame, "),
    ("acc_scarf", "accessory", "green", [(0, neck - 34, W, neck + 84)], None, 912,
     GREEN_DOLL + "wearing a thick red knitted scarf wrapped around the neck, "),
    ("acc_hat", "accessory", "green", [(0, 0, W, top + int(head_h * 0.42))], None, 913,
     GREEN_DOLL + "wearing a tall pointed purple wizard hat with a wide brim, "),
    ("acc_circlet", "accessory", "green", [(0, top + int(head_h * 0.14), W, top + int(head_h * 0.40))], None, 914,
     GREEN_DOLL + "wearing a thin golden circlet crown with a red gem across the forehead, "),
    ("race_elf", "race_traits", "grey", [(0, top + 70, W, neck - 10)], (x0 + 52, 0, x1 - 52, H), 921,
     GREY_DOLL + "with very long pointed elf ears sticking out on both sides of the head, "),
    ("race_orc", "race_traits", "grey", [(0, top + 70, W, neck - 10), (x0 + 90, neck - 95, x1 - 90, neck - 20)], (x0 + 52, 0, x1 - 52, neck - 96), 922,
     GREY_DOLL + "an orc with large pointed ears and two big tusks rising from the lower jaw, "),
    ("race_dwarf", "race_traits", "grey", [((x0 + x1) // 2 - 46, top + int(head_h * 0.52), (x0 + x1) // 2 + 46, neck - 40)], None, 923,
     GREY_DOLL + "with a very big round bulbous nose in the middle of the face, "),
    ("race_halfling", "race_traits", "grey", [(0, H - 96, W, H)], None, 924,
     GREY_DOLL + "with very large wide bare feet covered in tufts of fur on top, "),
]


ITEM = ("16-bit pixel art item sprite, crisp square pixels, limited colour palette, dark pixel outline, retro JRPG "
        "inventory item, a single object alone, perfectly vertical, centered, plain flat pure white background, "
        "no shadow, no hand, no character, no text")
# name, seed, prompt, height on the 512x768 canvas, where the hand grips it (0 = bottom, 1 = top)
WEAPONS = [
    ("weapon_sword", 931, "a steel longsword with a golden crossguard and a brown grip, blade pointing straight up, ", 330, 0.14),
    ("weapon_mace", 932, "a short mace with a round spiked golden head on top and a brown wooden handle, head up, ", 250, 0.16),
    ("weapon_bow", 933, "a tall curved brown wooden longbow with its string, standing upright, ", 400, 0.50),
    ("weapon_staff", 934, "a tall brown wooden wizard staff with a glowing blue crystal on top, standing upright, ", 520, 0.42),
]


def hand_point():
    """Centre of the doll's hand on the right of the image."""
    alpha = np.asarray(body.getchannel("A")) > 0
    columns = alpha[:, x1 - 44:x1]
    rows = np.nonzero(columns.any(axis=1))[0]
    return x1 - 26, int(rows[-1]) - 22


def place_weapon(item, height, grip):
    box = item.getchannel("A").getbbox()
    piece = item.crop(box)
    scale = height / piece.height
    piece = piece.resize((max(1, round(piece.width * scale)), height), Image.LANCZOS)
    hx, hy = hand_point()
    canvas = Image.new("RGBA", artlib.CANVAS, (0, 0, 0, 0))
    canvas.alpha_composite(piece, (hx - piece.width // 2, hy - round(height * (1.0 - grip))))
    return canvas


# Pieces that must stay on the doll itself: clipped to the body silhouette grown by this many pixels.
CLIP_TO_BODY = {"race_halfling": 6}


def clip_to_body(piece, grow):
    """Drops whatever the model painted away from the body (ground shadows)."""
    near = body.getchannel("A").filter(ImageFilter.MaxFilter(2 * grow + 1))
    alpha = np.minimum(np.asarray(piece.getchannel("A")), np.asarray(near))
    piece.putalpha(Image.fromarray(alpha))
    return piece


def drop_white(rgba):
    """Item sprites have no white: also clear the white the flood fill could not reach (inside a bow)."""
    arr = np.asarray(rgba).copy()
    arr[arr[..., :3].min(axis=-1) > 232, 3] = 0
    return Image.fromarray(arr, "RGBA")


def build_mask(rects, keep):
    mask = Image.new("RGB", artlib.CANVAS, (0, 0, 0))
    draw = ImageDraw.Draw(mask)
    for rect in rects:
        draw.rectangle(rect, fill=(255, 255, 255))
    if keep is not None:
        # Re-black the kept area, but only where the first rectangle is (later rectangles stay white).
        first = Image.new("L", artlib.CANVAS, 0)
        ImageDraw.Draw(first).rectangle(rects[0], fill=255)
        kept = Image.new("L", artlib.CANVAS, 0)
        ImageDraw.Draw(kept).rectangle(keep, fill=255)
        hole = np.minimum(np.asarray(first), np.asarray(kept))
        arr = np.asarray(mask).copy()
        arr[hole > 0] = 0
        for rect in rects[1:]:
            arr[rect[1]:rect[3], rect[0]:rect[2]] = 255
        mask = Image.fromarray(arr)
    return mask


def extract(result, template, mask, green):
    """What the inpainting added inside the mask: changed, not background, not the doll's own colour."""
    new = np.asarray(result.convert("RGB")).astype(np.int32)
    old = np.asarray(template.convert("RGB")).astype(np.int32)
    inside = np.asarray(mask.convert("L")) > 0
    changed = np.abs(new - old).max(axis=-1) > 30
    white = new.min(axis=-1) > 236
    keep = changed & inside & ~white
    if green:
        # Only bright green is the doll; dark greenish pixels are outlines and frames.
        r, g, b = new[..., 0], new[..., 1], new[..., 2]
        keep &= ~((g > r + 25) & (g > b + 25) & (g > 110))
    img = Image.fromarray((keep * 255).astype(np.uint8))
    img = img.filter(ImageFilter.MaxFilter(3)).filter(ImageFilter.MinFilter(3))
    img = img.filter(ImageFilter.MinFilter(3)).filter(ImageFilter.MaxFilter(3))
    out = result.convert("RGBA")
    out.putalpha(Image.fromarray(((np.asarray(img) > 0) & inside & ~white).astype(np.uint8) * 255))
    return out


def to_game(rgba, grey):
    if grey:
        alpha = rgba.getchannel("A")
        rgba = artlib.to_greyscale(rgba)
        smooth = rgba.convert("RGB").filter(ImageFilter.MedianFilter(5)).convert("RGBA")
        smooth.putalpha(alpha)
        rgba = smooth
    small = rgba.resize(GAME, Image.NEAREST)
    arr = np.asarray(small).copy()
    arr[..., 3] = np.where(arr[..., 3] > 127, 255, 0)
    if grey:
        arr[..., :3] = (np.round(arr[..., :3] / 63.75) * 63.75).astype(np.uint8)
    else:
        # A small fixed palette per piece keeps it looking like pixel art.
        opaque = arr[..., 3] > 0
        if opaque.any():
            strip = Image.fromarray(arr[..., :3][opaque].reshape(1, -1, 3), "RGB")
            flat = strip.quantize(colors=10, method=Image.Quantize.MEDIANCUT).convert("RGB")
            arr[..., :3][opaque] = np.asarray(flat).reshape(-1, 3)
    arr[arr[..., 3] == 0] = 0
    return Image.fromarray(arr, "RGBA")


args = sys.argv[1:]
generate = "gen" in args
only = [a for a in args if a != "gen"]
if generate:
    for _ in range(80):
        try:
            urllib.request.urlopen(cc.HOST + "/system_stats", timeout=3)
            break
        except Exception:
            time.sleep(3)
    else:
        raise SystemExit("server did not start")
    grey_template.save(os.path.join(cc.INPUT_DIR, "dmv3_px_grey.png"))
    green_template.save(os.path.join(cc.INPUT_DIR, "dmv3_px_green.png"))

tiles = []
for name, layer, template_key, rects, keep, seed, text in JOBS:
    mask = build_mask(rects, keep)
    mask.save(os.path.join(WORK, "mask_%s.png" % name))
    raw_path = os.path.join(cc.OUT_DIR, "px", name + "_00001_.png")
    if generate and (not only or name in only):
        if os.path.exists(raw_path):
            os.remove(raw_path)
        mask.save(os.path.join(cc.INPUT_DIR, "dmv3_px_mask_extra.png"))
        _paths, seconds = cc.inpaint(text + PIXEL, seed, "px/%s" % name, "dmv3_px_%s.png" % template_key,
                                     "dmv3_px_mask_extra.png", denoise=1.0)
        print("%s: %.0fs" % (name, seconds), flush=True)
    if not os.path.exists(raw_path):
        continue
    raw = Image.open(raw_path).convert("RGB")
    green = template_key == "green"
    extracted = extract(raw, green_template if green else grey_template, mask, green)
    if name in CLIP_TO_BODY:
        extracted = clip_to_body(extracted, CLIP_TO_BODY[name])
    piece = to_game(extracted, grey=not green)
    piece.save(os.path.join(OUT, name + ".png"))
    tiles.append((name, raw, piece))

for name, seed, text, height, grip in WEAPONS:
    raw_path = os.path.join(cc.OUT_DIR, "px", name + "_00001_.png")
    if generate and (not only or name in only):
        if os.path.exists(raw_path):
            os.remove(raw_path)
        _paths, seconds = cc.txt2img(text + ITEM, seed, "px/%s" % name, width=384, height=768)
        print("%s: %.0fs" % (name, seconds), flush=True)
    if not os.path.exists(raw_path):
        continue
    raw = Image.open(raw_path).convert("RGB")
    piece = to_game(place_weapon(drop_white(artlib.remove_background(raw)), height, grip), grey=False)
    piece.save(os.path.join(OUT, name + ".png"))
    tiles.append((name, raw, piece))

TILE = (192, 288)
if tiles:
    base = Image.open(os.path.join(WORK, "layers_128x192", "body.png"))
    sheet = Image.new("RGB", (12 + len(tiles) * (TILE[0] + 10), 3 * (TILE[1] + 26) + 12), (24, 24, 26))
    draw = ImageDraw.Draw(sheet)
    for i, (name, raw, piece) in enumerate(tiles):
        x = 12 + i * (TILE[0] + 10)
        shown = raw.copy()
        shown.thumbnail(TILE, Image.LANCZOS)
        sheet.paste(shown, (x, 12))
        alone = Image.new("RGBA", GAME, (58, 62, 74, 255))
        alone.alpha_composite(piece)
        sheet.paste(alone.convert("RGB").resize(TILE, Image.NEAREST), (x, 12 + TILE[1] + 26))
        worn = Image.new("RGBA", GAME, (58, 62, 74, 255))
        skin = (130, 170, 110) if "orc" in name else (235, 195, 165)
        worn.alpha_composite(artlib.tint(base, skin))
        worn.alpha_composite(artlib.tint(piece, skin) if name.startswith("race") else piece)
        sheet.paste(worn.convert("RGB").resize(TILE, Image.NEAREST), (x, 12 + 2 * (TILE[1] + 26)))
        draw.text((x, 12 + TILE[1] + 4), name, fill=(230, 230, 230))
    sheet.save(os.path.join(WORK, "sheet_extras.png"))
    print("sheet", sheet.size, len(tiles), "pieces")
