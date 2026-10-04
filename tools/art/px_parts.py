"""Pixel-art pass, step 2: template from the chosen body, then inpaint hair, outfits and a face.
Usage: python px_parts.py <body seed>"""
import os
import sys

from PIL import Image, ImageDraw

import artlib
import time
import urllib.request

import comfy_client as cc
from px_bodies import PIXEL

for _ in range(80):
    try:
        urllib.request.urlopen(cc.HOST + "/system_stats", timeout=3)
        break
    except Exception:
        time.sleep(3)
else:
    raise SystemExit("server did not start")

HERE = os.path.dirname(os.path.abspath(__file__))
WORK = os.path.join(HERE, "px")
os.makedirs(WORK, exist_ok=True)

seed = sys.argv[1]
raw = Image.open(os.path.join(cc.OUT_DIR, "px", "body_%s_00001_.png" % seed))
body = artlib.anchor(artlib.remove_background(raw))
body.save(os.path.join(WORK, "body.png"))
artlib.on_white(body).save(os.path.join(cc.INPUT_DIR, "dmv3_px_body.png"))
neck = artlib.neck_row(body)
box = body.getchannel("A").getbbox()
print("neck row %d, body box %s" % (neck, box), flush=True)


def save_mask(name, rect, keep=None):
    """White = repaint. `keep` is a rectangle inside it that stays untouched."""
    mask = Image.new("RGB", artlib.CANVAS, (0, 0, 0))
    ImageDraw.Draw(mask).rectangle(rect, fill=(255, 255, 255))
    if keep is not None:
        ImageDraw.Draw(mask).rectangle(keep, fill=(0, 0, 0))
    mask.save(os.path.join(cc.INPUT_DIR, name))
    mask.save(os.path.join(WORK, name))


W, H = artlib.CANVAS
head_h = neck - box[1]
face_box = (box[0] + 40, box[1] + int(head_h * 0.38), box[2] - 40, neck - int(head_h * 0.10))
# Hair may fall onto the shoulders, but never over the face.
save_mask("dmv3_px_mask_hair.png", (0, 0, W, neck + 120), keep=face_box)
save_mask("dmv3_px_mask_outfit.png", (0, neck - 4, W, H))
save_mask("dmv3_px_mask_face.png", face_box)

DOLL = "a blank featureless light grey mannequin doll, bald, chibi proportions with a large round head, "
jobs = [
    ("hair_spiky", "dmv3_px_mask_hair.png", 611,
     DOLL + "no face, with big voluminous messy spiky hair covering the whole top and sides of the head, with bangs over the forehead, the hair is bright saturated red, the rest of the doll stays plain grey, "),
    ("hair_long", "dmv3_px_mask_hair.png", 612,
     DOLL + "no face, with thick long hair covering the whole top of the head, a fringe over the forehead, and falling in front of the shoulders on both sides of the face, the hair is bright saturated red, the rest of the doll stays plain grey, "),
    ("hair_short", "dmv3_px_mask_hair.png", 613,
     DOLL + "no face, with a short neat bowl haircut covering the top of the head, the hair is bright saturated red, the rest of the doll stays plain grey, "),
    ("outfit_tabard", "dmv3_px_mask_outfit.png", 714,
     DOLL + "no face, wearing a priest's knee-length bright saturated blue tunic with short sleeves, a bright blue hooded shoulder cape, a wide blue sash at the waist, blue trousers and blue boots, every piece of clothing is bright saturated blue, nothing is white or grey except the bare hands, "),
    ("face_serious", "dmv3_px_mask_face.png", 802,
     DOLL + "with a simple serious face: two black dot eyes, small angry eyebrows and a flat straight mouth, no hair, "),
    ("outfit_robe", "dmv3_px_mask_outfit.png", 701,
     DOLL + "no face, wearing a long wizard robe with a collar, long wide sleeves and a rope belt, the whole robe is bright saturated blue, bare grey hands, "),
    ("outfit_armor", "dmv3_px_mask_outfit.png", 702,
     DOLL + "no face, wearing a full suit of knight's plate armor with pauldrons, breastplate, leg plates and boots, the whole armor is painted bright saturated blue, bare grey hands, "),
    ("outfit_leather", "dmv3_px_mask_outfit.png", 703,
     DOLL + "no face, wearing a rogue's leather tunic with a belt, trousers and boots, the whole outfit is bright saturated blue, bare grey hands, "),
    ("face_smile", "dmv3_px_mask_face.png", 801,
     DOLL + "with a simple face: two black dot eyes and a small smiling mouth, no hair, "),
]
only = sys.argv[2:]
for name, mask, job_seed, text in jobs:
    if only and name not in only:
        continue
    paths, seconds = cc.inpaint(text + PIXEL, job_seed, "px/%s" % name, "dmv3_px_body.png", mask, denoise=1.0 if name.startswith("hair") else 0.9)
    print("%s: %.0fs" % (name, seconds), flush=True)
