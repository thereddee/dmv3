"""Builds the two body templates, then inpaints hair and outfits over body A."""
import os
import sys

from PIL import Image, ImageDraw

import artlib
import comfy_client as cc

HERE = os.path.dirname(os.path.abspath(__file__))
WORK = os.path.join(HERE, "pass1")
os.makedirs(WORK, exist_ok=True)

# ----- templates -----
sources = {"a": "body_a_102_00001_.png", "b": "body_b_202_00001_.png"}
templates = {}
for key, name in sources.items():
    raw = Image.open(os.path.join(cc.OUT_DIR, "pass1", name))
    body = artlib.anchor(artlib.remove_background(raw))
    body.save(os.path.join(WORK, "body_%s.png" % key))
    templates[key] = body
    print("body %s: neck row %d" % (key, artlib.neck_row(body)))

body = templates["a"]
neck = artlib.neck_row(body)
artlib.on_white(body).save(os.path.join(cc.INPUT_DIR, "dmv3_body_a.png"))


def save_mask(name, box):
    mask = Image.new("RGB", artlib.CANVAS, (0, 0, 0))
    ImageDraw.Draw(mask).rectangle(box, fill=(255, 255, 255))
    mask.save(os.path.join(cc.INPUT_DIR, name))
    mask.save(os.path.join(WORK, name))


save_mask("dmv3_mask_hair.png", (0, 0, artlib.CANVAS[0], neck + 30))
save_mask("dmv3_mask_outfit.png", (0, neck - 6, artlib.CANVAS[0], artlib.CANVAS[1]))

if "--templates-only" in sys.argv:
    raise SystemExit

MANNEQUIN = "a blank featureless light grey artist mannequin doll, no face details, "
jobs = [
    ("hair_spiky", "dmv3_mask_hair.png", 301,
     MANNEQUIN + "with a short messy spiky hairstyle, the hair is bright saturated red, the rest of the doll stays plain grey, "),
    ("hair_braid", "dmv3_mask_hair.png", 302,
     MANNEQUIN + "with long hair tied in a thick side braid falling over one shoulder, the hair is bright saturated red, the rest of the doll stays plain grey, "),
    ("outfit_robe", "dmv3_mask_outfit.png", 401,
     MANNEQUIN + "wearing a long wizard robe with a collar, long wide sleeves and a rope belt, the whole robe from the shoulders to the ankles is bright saturated blue, bare grey hands, bald grey head, "),
    ("outfit_armor", "dmv3_mask_outfit.png", 402,
     MANNEQUIN + "wearing a full suit of knight's plate armor with pauldrons, breastplate, gauntlets, leg plates and boots, every piece of the armor is painted bright saturated blue, no grey metal, bald grey head, "),
]
for name, mask, seed, text in jobs:
    if "--outfits-only" in sys.argv and not name.startswith("outfit"):
        continue
    paths, seconds = cc.inpaint(text + cc.STYLE, seed, "pass1/%s" % name, "dmv3_body_a.png", mask, denoise=0.9)
    print("%s: %.0fs -> %s" % (name, seconds, os.path.basename(paths[0])), flush=True)
