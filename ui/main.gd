extends Control
## Entry scene: owns the campaign and hands it to the table screen.
## Usage: godot -- [--seed=123] [--demo=<screenshot dir>]
## A seed can be a number or any text (hashed), so "pizza" is a valid seed.

const SEED_RANGE := 1000000

var _content: ContentDB
var _campaign: Campaign

@onready var _screen: EncounterScreen = $EncounterScreen


func _ready() -> void:
	_content = ContentDB.load_default()
	_screen.new_campaign_requested.connect(_new_campaign)
	var seed_text := ""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--seed="):
			seed_text = arg.trim_prefix("--seed=")
	_new_campaign(seed_text)
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--demo="):
			var demo: Node = preload("res://ui/dev/demo.gd").new()
			demo.set("screen", _screen)
			demo.set("out_dir", arg.trim_prefix("--demo="))
			add_child(demo)
			demo.call("run")


func _new_campaign(seed_text: String) -> void:
	var seed_value := randi() % SEED_RANGE
	if seed_text.is_valid_int() and int(seed_text) >= 0:
		seed_value = int(seed_text)
	elif seed_text != "":
		seed_value = seed_text.hash() % SEED_RANGE
	_campaign = Campaign.new(_content, seed_value)
	_screen.bind(_campaign)
	_campaign.start()
	_screen.enter_phase()
