class_name ContentDB
extends RefCounted
## Loads every content Resource under res://data/. Adding a monster, card or
## loot item is dropping a .tres in the right folder.

const ROOT := "res://data/"

var tuning: Tuning
var monsters: Array[MonsterData] = []
var dm_cards: Array[DmCardData] = []
var loot: Array[LootData] = []
var party: Array[PlayerData] = []
var classes: Dictionary[String, ClassData] = {}
var archetypes: Dictionary[String, ArchetypeData] = {}


static func load_default() -> ContentDB:
	var db := ContentDB.new()
	db.tuning = load(ROOT + "tuning.tres")
	db.monsters.assign(_load_dir(ROOT + "monsters"))
	db.monsters.sort_custom(func(a: MonsterData, b: MonsterData) -> bool:
		return a.cost < b.cost if a.cost != b.cost else a.id < b.id)
	db.dm_cards.assign(_load_dir(ROOT + "dm_cards"))
	db.loot.assign(_load_dir(ROOT + "loot"))
	db.party.assign(_load_dir(ROOT + "party"))
	db.party.sort_custom(func(a: PlayerData, b: PlayerData) -> bool: return a.seat < b.seat)
	for res in _load_dir(ROOT + "classes"):
		var cls: ClassData = res
		db.classes[cls.key] = cls
	for res in _load_dir(ROOT + "archetypes"):
		var arch: ArchetypeData = res
		db.archetypes[arch.key] = arch
	return db


func monster_by_id(id: String) -> MonsterData:
	for m in monsters:
		if m.id == id:
			return m
	push_error("Unknown monster id: %s" % id)
	return null


## Sorted by file name so content order (and thus seeded runs) is stable.
static func _load_dir(path: String) -> Array[Resource]:
	var names: Array[String] = []
	for f in DirAccess.get_files_at(path):
		var file := f.trim_suffix(".remap")
		if file.ends_with(".tres") and not names.has(file):
			names.append(file)
	names.sort()
	var out: Array[Resource] = []
	for file in names:
		out.append(load(path + "/" + file))
	return out
