"""Pixel-art pass, step 1: body template candidates."""
import os
import subprocess
import sys
import time
import urllib.request

import comfy_client as cc

HERE = os.path.dirname(os.path.abspath(__file__))
PIXEL = ("16-bit pixel art sprite, crisp square pixels, limited colour palette, dark pixel outline, "
         "retro JRPG character sprite, front view, full body, standing straight, arms slightly away from the body, "
         "centered, plain flat pure white background, no shadow on the ground, no text")
BODY = ("a blank featureless mannequin doll used as a character base, completely bald, no hair, no face, no eyes, "
        "no mouth, no clothes, plain smooth light grey body in greyscale, chibi proportions with a large round head "
        "and a short sturdy body, ")

if __name__ == "__main__":
    for _ in range(80):
        try:
            urllib.request.urlopen(cc.HOST + "/system_stats", timeout=3)
            break
        except Exception:
            time.sleep(3)
    else:
        raise SystemExit("server did not start")

    paths = []
    for seed in (511, 512, 513):
        out, seconds = cc.txt2img(BODY + PIXEL, seed, "px/body_%d" % seed)
        print("body %d: %.0fs" % (seed, seconds), flush=True)
        paths.append(out[0])
    subprocess.run([sys.executable, os.path.join(HERE, "sheet.py"), os.path.join(HERE, "sheet_px_bodies.png")] + paths, check=True)
