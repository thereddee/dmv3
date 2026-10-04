"""Helpers for the paper-doll first pass: background removal, anchoring, layer extraction, tint."""
import numpy as np
from PIL import Image, ImageDraw, ImageFilter

CANVAS = (512, 768)   # 4x the game canvas (128x192)
FEET_Y = 752          # feet anchor: bottom centre
BODY_HEIGHT = 690


def remove_background(image, thresh=38):
    """Flood-fills the flat background from the four corners. Returns RGBA."""
    rgb = image.convert("RGB")
    marker = (255, 0, 255)
    work = rgb.copy()
    w, h = work.size
    for corner in [(0, 0), (w - 1, 0), (0, h - 1), (w - 1, h - 1)]:
        ImageDraw.floodfill(work, corner, marker, thresh=thresh)
    background = np.all(np.asarray(work) == marker, axis=-1)
    alpha = Image.fromarray(np.where(background, 0, 255).astype(np.uint8))
    # Pull the edge in by a pixel to drop the white antialiasing fringe.
    alpha = alpha.filter(ImageFilter.MinFilter(3))
    out = rgb.convert("RGBA")
    out.putalpha(alpha)
    return out


def anchor(rgba, height=BODY_HEIGHT):
    """Scales the figure to a fixed height and puts its feet on the shared anchor."""
    box = rgba.getchannel("A").getbbox()
    figure = rgba.crop(box)
    scale = height / figure.height
    figure = figure.resize((round(figure.width * scale), height), Image.LANCZOS)
    canvas = Image.new("RGBA", CANVAS, (0, 0, 0, 0))
    canvas.alpha_composite(figure, ((CANVAS[0] - figure.width) // 2, FEET_Y - height))
    return canvas


def on_white(rgba):
    bg = Image.new("RGBA", rgba.size, (255, 255, 255, 255))
    bg.alpha_composite(rgba)
    return bg.convert("RGB")


def neck_row(rgba):
    """First pinch of the silhouette below the widest row of the head."""
    alpha = np.asarray(rgba.getchannel("A")) > 0
    widths = alpha.sum(axis=1)
    rows = np.nonzero(widths)[0]
    top, bottom = rows[0], rows[-1]
    head_widest = max(range(top, top + (bottom - top) // 3), key=lambda y: widths[y])
    best = head_widest
    for y in range(head_widest, bottom):
        if widths[y] < widths[best]:
            best = y
        elif widths[y] > widths[best] * 1.25:
            break
    return best


def extract_coloured(result, min_saturation=70, grow=5):
    """Keeps the saturated pixels (the tinted piece) plus the dark outline hugging them. Returns RGBA."""
    rgb = result.convert("RGB")
    hsv = np.asarray(rgb.convert("HSV")).astype(np.int32)
    luma = np.asarray(rgb.convert("L")).astype(np.int32)
    coloured = (hsv[..., 1] > min_saturation) & (hsv[..., 2] > 40)
    dark = luma < 90
    mask = coloured.copy()
    for _ in range(grow):
        grown = np.asarray(Image.fromarray((mask * 255).astype(np.uint8)).filter(ImageFilter.MaxFilter(3))) > 0
        mask = mask | (grown & dark)
    # Drop specks: keep only what survives a small open.
    img = Image.fromarray((mask * 255).astype(np.uint8))
    img = img.filter(ImageFilter.MinFilter(3)).filter(ImageFilter.MaxFilter(3))
    mask = (np.asarray(img) > 0) | (mask & coloured)
    out = rgb.convert("RGBA")
    out.putalpha(Image.fromarray((mask * 255).astype(np.uint8)))
    return out


def extract_changed(result, template, top, diff=26):
    """Keeps what the inpainting changed below row `top` (the outfit), holes filled. Returns RGBA.
    `template` is the bare body on white, same size as `result`."""
    rgb = result.convert("RGB")
    new = np.asarray(rgb).astype(np.int32)
    old = np.asarray(template.convert("RGB")).astype(np.int32)
    changed = np.abs(new - old).max(axis=-1) > diff
    changed[:top, :] = False
    img = Image.fromarray((changed * 255).astype(np.uint8))
    img = img.filter(ImageFilter.MaxFilter(7)).filter(ImageFilter.MinFilter(7))
    # Fill what the changed pixels enclose: anything the outside cannot reach.
    padded = Image.new("L", (img.width + 2, img.height + 2), 0)
    padded.paste(img, (1, 1))
    ImageDraw.floodfill(padded, (0, 0), 128)
    filled = np.asarray(padded)[1:-1, 1:-1] != 128
    filled[:top, :] = False
    # Never keep the flat white background (gaps between sleeves and body).
    white = (new.min(axis=-1) > 238)
    mask = filled & ~white
    out = rgb.convert("RGBA")
    out.putalpha(Image.fromarray((mask * 255).astype(np.uint8)).filter(ImageFilter.MinFilter(3)))
    return out


def extract_outfit(result, template, diff=26, skin_tolerance=22):
    """Coloured pixels, plus anything the inpainting changed that is not bare skin or background. Returns RGBA."""
    rgb = result.convert("RGB")
    new = np.asarray(rgb).astype(np.int32)
    old = np.asarray(template.convert("RGB")).astype(np.int32)
    body = old.max(axis=-1) < 238
    light = body & (old.min(axis=-1) > 120)
    skin_grey = np.median(old[light], axis=0)
    changed = np.abs(new - old).max(axis=-1) > diff
    skin_like = np.abs(new - skin_grey).max(axis=-1) < skin_tolerance
    white = new.min(axis=-1) > 238
    mask = changed & ~skin_like & ~white
    mask |= np.asarray(extract_coloured(result).getchannel("A")) > 0
    img = Image.fromarray((mask * 255).astype(np.uint8))
    img = img.filter(ImageFilter.MaxFilter(5)).filter(ImageFilter.MinFilter(5))
    mask = (np.asarray(img) > 0) & ~white & ~(skin_like & ~changed)
    out = rgb.convert("RGBA")
    out.putalpha(Image.fromarray((mask * 255).astype(np.uint8)))
    return out


def to_greyscale(rgba):
    """Greyscale for tinting: the piece's own lightness, stretched so the lit areas are near white."""
    alpha = rgba.getchannel("A")
    value = np.asarray(rgba.convert("RGB").convert("HSV"))[..., 2].astype(np.float32)
    inside = np.asarray(alpha) > 0
    if inside.any():
        high = np.percentile(value[inside], 95)
        value = np.clip(value * (235.0 / max(high, 1.0)), 0, 255)
    grey = Image.fromarray(value.astype(np.uint8)).convert("RGBA")
    grey.putalpha(alpha)
    return grey


def tint(rgba, colour):
    """Same as Godot's modulate: multiply."""
    arr = np.asarray(rgba).astype(np.float32)
    arr[..., :3] *= np.array(colour, dtype=np.float32) / 255.0
    return Image.fromarray(arr.astype(np.uint8), "RGBA")


def stack(layers):
    canvas = Image.new("RGBA", CANVAS, (0, 0, 0, 0))
    for layer in layers:
        canvas.alpha_composite(layer)
    return canvas
