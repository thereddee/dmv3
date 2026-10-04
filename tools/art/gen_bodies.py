import comfy_client as cc

BODY = ("a blank featureless artist mannequin doll, {build}, completely bald, no hair, no face details, "
        "no clothes, smooth plain body like a base mesh, light grey skin in greyscale, monochrome, ")

jobs = [
    ("body_a", BODY.format(build="broad shoulders, stocky sturdy build"), 101),
    ("body_a", BODY.format(build="broad shoulders, stocky sturdy build"), 102),
    ("body_b", BODY.format(build="narrower shoulders, slimmer build, wider hips"), 201),
    ("body_b", BODY.format(build="narrower shoulders, slimmer build, wider hips"), 202),
]
for name, text, seed in jobs:
    paths, seconds = cc.txt2img(text + cc.STYLE, seed, "pass1/%s_%d" % (name, seed))
    print("%s seed %d: %.0fs -> %s" % (name, seed, seconds, paths))
