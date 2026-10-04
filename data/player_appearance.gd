class_name PlayerAppearance
extends Resource
## Look of a table player, ported from reference/table-des-joueurs.html (randomPlayer + OPTS).
## Option ids are the reference's French keys so every shape and pose stays 1:1 with the HTML.

const SKINS: Array[Color] = [
	Color("#f6d9c6"), Color("#ecc1a0"), Color("#d49b74"), Color("#b5764d"), Color("#8a5434"), Color("#5b3623"),
]
const HAIR_COLORS: Array[Color] = [
	Color("#1f1a17"), Color("#4a2f1e"), Color("#8b5a2b"), Color("#d1aa62"),
	Color("#b5452f"), Color("#d8d3cb"), Color("#5a4bd1"), Color("#2e8b7a"),
]
const TOP_COLORS: Array[Color] = [
	Color("#34466d"), Color("#7d2f3c"), Color("#2f6b4f"), Color("#c98a2b"),
	Color("#45454d"), Color("#e6e0d3"), Color("#6a3d8f"), Color("#2f7fa8"),
]
const ACC_COLORS: Array[Color] = [
	Color("#c23b3b"), Color("#e0a53a"), Color("#2f8f6e"), Color("#3a6fc4"),
	Color("#7a4fc2"), Color("#2b2b33"), Color("#e86fa0"), Color("#f0ece2"),
]
const EYE_COLORS: Array[Color] = [
	Color("#5a3a22"), Color("#2f5d8a"), Color("#3f7a3f"), Color("#8a6a2a"),
	Color("#55555f"), Color("#8a2f5a"), Color("#2a8a8a"), Color("#b03a2e"),
]
## Races that replace the human skin tones.
const RACE_SKINS := {
	"orc": [Color("#8fae6b"), Color("#6f9455"), Color("#a3b88a"), Color("#5e7a4a"), Color("#7d8f6a"), Color("#4f6a3e")],
	"tieffelin": [Color("#c4544a"), Color("#9b3b52"), Color("#7a4a9e"), Color("#d07a5e"), Color("#5b5fa8"), Color("#b8b2c8")],
	"drakeide": [Color("#b33a2e"), Color("#2f6fa8"), Color("#2f8a52"), Color("#c9a13a"), Color("#a8a8b4"), Color("#3a3440")],
}

const RACES: Array[String] = ["humain", "elfe", "nain", "halfelin", "gnome", "orc", "tieffelin", "drakeide"]
## "aucune" is the IRL look (no costume); the generator never rolls it.
const CLASSES: Array[String] = ["aucune", "guerrier", "clerc", "roublard", "rodeur", "magicien", "barde"]
const BUILDS: Array[String] = ["mince", "moyen", "large"]
const HAIRS: Array[String] = ["court", "long", "chignon", "queue", "boucles", "rase", "crete", "chauve"]
const FACIALS: Array[String] = ["aucune", "trois", "moustache", "barbe", "tresse", "fourche", "longue"]
const TOPS: Array[String] = ["hoodie", "tshirt", "carreaux", "cardigan", "cape"]
const HEADS: Array[String] = ["aucun", "casquette", "tuque", "sorcier", "ecouteurs"]
const GLASSES: Array[String] = ["aucune", "rondes", "carrees"]
const MOODS: Array[String] = ["content", "concentre", "blase", "fache", "surpris"]
const PROPS: Array[String] = ["des", "pile", "cell", "tour", "canette", "chips", "fiche"]

@export var race: String = "humain"
## Class id; named cls because `class` is a GDScript keyword.
@export var cls: String = "aucune"
@export var build: String = "moyen"
@export var skin: Color = SKINS[1]
@export var hair: String = "court"
@export var hair_color: Color = HAIR_COLORS[1]
@export var eyes: Color = EYE_COLORS[0]
@export var facial: String = "aucune"
@export var top: String = "hoodie"
@export var top_color: Color = TOP_COLORS[0]
@export var head: String = "aucun"
@export var glasses: String = "aucune"
## Accent colour: hats, headphones, bandana, buttons, dice.
@export var acc: Color = ACC_COLORS[0]
@export var mood: String = "content"
@export var prop: String = "des"


static func skins_for(race_id: String) -> Array:
	return RACE_SKINS.get(race_id, SKINS)


## Same distribution as randomPlayer() in the reference. Named randomize_with because Resource
## would shadow the global randomize(). A non-empty ace_id / class_id replaces that roll, and\n## everything that depends on it (skin tones, dwarf beards) follows.
func randomize_with(rng: RandomNumberGenerator, race_id: String = "", class_id: String = "") -> void:
	hair = _pick(rng, ["court", "court", "long", "long", "chignon", "queue", "boucles", "rase", "crete", "chauve"])
	race = _pick(rng, ["humain", "humain", "elfe", "nain", "halfelin", "gnome", "orc", "tieffelin", "drakeide"])
	cls = _pick(rng, CLASSES.slice(1))
	if race_id != "":
		race = race_id
	if class_id != "":
		cls = class_id
	eyes = _pick(rng, EYE_COLORS)
	build = _pick(rng, ["mince", "moyen", "moyen", "large"])
	skin = _pick(rng, skins_for(race))
	var hair_colors: Array = HAIR_COLORS.slice(0, 6)
	hair_colors.append(_pick(rng, HAIR_COLORS))
	hair_color = _pick(rng, hair_colors)
	if race == "nain":
		facial = _pick(rng, ["barbe", "tresse", "fourche", "longue"])
	else:
		facial = _pick(rng, ["aucune", "aucune", "aucune", "trois", "moustache", "barbe"])
	top = _pick(rng, TOPS)
	top_color = _pick(rng, TOP_COLORS)
	head = _pick(rng, ["aucun", "aucun", "casquette", "tuque", "sorcier", "ecouteurs"])
	glasses = _pick(rng, ["aucune", "aucune", "rondes", "carrees"])
	acc = _pick(rng, ACC_COLORS)
	mood = _pick(rng, MOODS)
	prop = _pick(rng, PROPS)


static func _pick(rng: RandomNumberGenerator, options: Array) -> Variant:
	return options[rng.randi_range(0, options.size() - 1)]