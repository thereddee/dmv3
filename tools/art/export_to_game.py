"""Copies the 128x192 layers into the Godot project and writes one CharacterPart .tres per drawing.
Usage: python export_to_game.py <project dir>"""
import io
import os
import shutil
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
SOURCE = os.path.join(HERE, "px", "layers_128x192")
project = sys.argv[1]

# source file, part id, layer, class, race, body types
PARTS = [
    ("body", "body_base", "body", "", "", []),
    ("face_smile", "face_smile", "face", "", "", []),
    ("face_serious", "face_serious", "face", "", "", []),
    ("hair_spiky", "hair_spiky", "hair_front", "", "", ["a"]),
    ("hair_long", "hair_long", "hair_front", "", "", ["b"]),
    ("hair_short", "hair_short", "hair_front", "", "", []),
    ("outfit_armor", "outfit_armor", "outfit", "tank", "", []),
    ("outfit_tabard", "outfit_tabard", "outfit", "healer", "", []),
    ("outfit_leather", "outfit_leather", "outfit", "dps", "", []),
    ("outfit_robe", "outfit_robe", "outfit", "cc", "", []),
]
for source, part_id, layer, class_key, race_key, body_types in PARTS:
    asset_dir = os.path.join(project, "assets", "characters", layer)
    os.makedirs(asset_dir, exist_ok=True)
    shutil.copyfile(os.path.join(SOURCE, source + ".png"), os.path.join(asset_dir, part_id + ".png"))
    lines = [
        '[gd_resource type="Resource" script_class="CharacterPart" format=3]',
        '',
        '[ext_resource type="Script" path="res://data/character_part.gd" id="1"]',
        '[ext_resource type="Texture2D" path="res://assets/characters/%s/%s.png" id="2"]' % (layer, part_id),
        '',
        '[resource]',
        'script = ExtResource("1")',
        'id = "%s"' % part_id,
        'layer = "%s"' % layer,
        'texture = ExtResource("2")',
    ]
    if class_key:
        lines.append('class_key = "%s"' % class_key)
    if race_key:
        lines.append('race_key = "%s"' % race_key)
    if body_types:
        lines.append('body_types = Array[String]([%s])' % ", ".join('"%s"' % b for b in body_types))
    parts_dir = os.path.join(project, "data", "character_parts")
    os.makedirs(parts_dir, exist_ok=True)
    io.open(os.path.join(parts_dir, part_id + ".tres"), "w", encoding="utf-8", newline="\n").write("\n".join(lines) + "\n")
    print("exported", part_id)
