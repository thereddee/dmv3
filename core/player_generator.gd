class_name PlayerGenerator
extends RefCounted
## Rolls a candidate player: race, class, archetype, body type, name, quirk and looks.
## Everything comes from content Resources, so new races, names, quirks or drawings need no code.

const BODY_TYPES: Array[String] = ["a", "b"]


## `taken_names` avoids two candidates with the same name; the new name is appended to it.
static func generate(rng: RandomNumberGenerator, content: ContentDB, taken_names: Array[String]) -> PlayerData:
	var d := PlayerData.new()
	var race: RaceData = _pick(rng, content.races)
	var cls: ClassData = content.classes[_pick(rng, content.classes.keys())]
	d.race_key = race.key
	d.class_key = cls.key
	d.archetype_key = _pick(rng, content.archetypes.keys())
	d.body_type = _pick(rng, BODY_TYPES)
	d.hp = cls.hp
	d.atk = cls.atk
	d.heal_power = cls.heal_power
	d.stun_chance = cls.stun_chance

	var free_names: Array[String] = []
	for candidate in content.names.for_body_type(d.body_type):
		if not taken_names.has(candidate):
			free_names.append(candidate)
	d.display_name = _pick(rng, free_names) if not free_names.is_empty() else _pick(rng, content.names.names_a)
	taken_names.append(d.display_name)
	if not content.quirks.quirks.is_empty():
		d.quirk = _pick(rng, content.quirks.quirks)

	var look := CharacterAppearance.new()
	look.scale = race.scale
	look.skin = _pick(rng, race.skin_tones) if not race.skin_tones.is_empty() else Color.WHITE
	look.hair = _pick(rng, race.hair_colours) if not race.hair_colours.is_empty() else Color.WHITE
	look.accent = _pick(rng, cls.accent_colours) if not cls.accent_colours.is_empty() else Color.WHITE
	for layer in CharacterAppearance.LAYERS:
		var pool: Array[CharacterPart] = []
		for part in content.parts:
			if part.layer == layer and part.fits(d.class_key, d.race_key, d.body_type):
				pool.append(part)
		var skip := CharacterAppearance.OPTIONAL_LAYERS.has(layer) and rng.randf() < content.tuning.optional_layer_empty_chance
		if pool.is_empty() or skip:
			look.parts[layer] = ""
		else:
			var part: CharacterPart = _pick(rng, pool)
			look.parts[layer] = part.id
	d.appearance = look
	return d


static func _pick(rng: RandomNumberGenerator, from: Array) -> Variant:
	return from[rng.randi_range(0, from.size() - 1)]
