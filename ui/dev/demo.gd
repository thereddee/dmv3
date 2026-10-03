extends Node
## Dev tool: plays a whole campaign with real clicks at high speed, saves the
## first screenshot of each screen, restarts on a typed seed, then quits.
## Enabled from main.gd with `-- --demo=<output dir>`.

const LEFT := "Root/Columns/Left/"
const SUMMARY := "Overlay/Center/SummaryPanel/SummaryMargin/SummaryBox/"
const SPEED := 4.0

var screen: EncounterScreen
var out_dir := ""
var _seen := {}
var _shots := 0


func run() -> void:
	Engine.time_scale = SPEED
	var c := screen.campaign
	var choice: ChoicePanel = screen.get_node(LEFT + "ChoicePanel")
	await _wait(0.5)
	var guard := 0
	while c.phase != Campaign.Phase.OVER and guard < 80:
		guard += 1
		match c.phase:
			Campaign.Phase.RECRUIT:
				for i in c.tuning.party_size:
					await _click(choice.card(i + 1))
				await _shot("recruit")
				await _click(choice.confirm_button())
			Campaign.Phase.DRAFT:
				await _shot("draft")
				for i in c.tuning.draft_keep:
					await _click(choice.card(i))
				await _click(choice.confirm_button())
			Campaign.Phase.PICK:
				# Up to two cards that fit the budget, keeping one for each later encounter.
				var picked := 0
				var cost := 0
				var spare := c.unused_cards().size() - (c.tuning.encounters_per_night - c.encounter)
				for i in c.deck.size():
					var deck_card := c.deck[i]
					if not deck_card.used and picked < mini(2, spare) and cost + deck_card.data.cost <= c.budget:
						await _click(choice.card(i))
						picked += 1
						cost += deck_card.data.cost
				await _shot("pick")
				await _click(choice.confirm_button())
			Campaign.Phase.FIGHT:
				await _fight(c)
				if c.phase == Campaign.Phase.FIGHT:
					break
			Campaign.Phase.LOOT:
				await _wait(0.3)
				await _shot("summary")
				await _click(screen.get_node(SUMMARY + "ContinueButton"))
				await _click(choice.card(0))
				await _shot("loot")
				await _click(screen.get_node(LEFT + "PartyRow").get_child(c.party.find(c.alive_players()[0])))
		print("demo: night %d encounter %d phase %d time %d skipped %d" % [
			c.night, c.encounter, c.phase, c.time_left, c.skipped_at_midnight + c.skipped_no_monsters])
	print("demo campaign over: tpk=%s score=%d seed=%d" % [c.tpk, c.final_score(), c.seed_value])
	await _wait(0.5)
	await _shot("score")

	var seed_edit: LineEdit = screen.get_node(SUMMARY + "SeedRow/SeedEdit")
	seed_edit.text = "4242"
	await _click(screen.get_node(SUMMARY + "ContinueButton"))
	print("demo restart: seed=%d phase=%d night=%d" % [screen.campaign.seed_value, screen.campaign.phase, screen.campaign.night])
	await _click(screen.get_node(LEFT + "TopBar/MenuButton"))
	await _shot("menu")
	await _click(screen.get_node(SUMMARY + "ReplayButton"))
	print("demo replay: seed=%d phase=%d" % [screen.campaign.seed_value, screen.campaign.phase])
	await _shot("after_replay")
	get_tree().quit()


func _fight(c: Campaign) -> void:
	await _click(screen.get_node(LEFT + "PartyRow").get_child(c.party.find(c.alive_players()[-1])))
	await _click(screen.get_node(LEFT + "MonstersRow").get_child(0))
	await _click(screen.get_node(LEFT + "Bottom/HandRow").get_child(0))
	if c.cards_played_this_round == 0:
		# The card wants a player (Inspiration).
		await _click(screen.get_node(LEFT + "PartyRow").get_child(c.party.find(c.alive_players()[0])))
	await _shot("fight_choices")
	while c.phase == Campaign.Phase.FIGHT:
		var round_before := c.round_num
		screen.resolve()
		if c.round_num == round_before:
			print("demo: resolve refused")
			return
		await _wait(1.3)
		await _shot("fight_playing")
		if screen.is_busy():
			await screen.playback_finished


func _click(control: Control) -> void:
	var move := InputEventMouseMotion.new()
	move.position = control.get_global_rect().get_center()
	move.global_position = move.position
	get_viewport().push_input(move)
	await get_tree().process_frame
	for is_down: bool in [true, false]:
		var click := InputEventMouseButton.new()
		click.button_index = MOUSE_BUTTON_LEFT
		click.pressed = is_down
		click.position = control.get_global_rect().get_center()
		click.global_position = click.position
		get_viewport().push_input(click)
		await get_tree().process_frame


func _wait(seconds: float) -> void:
	await get_tree().create_timer(seconds).timeout


## Saves only the first screenshot for each name.
func _shot(shot_name: String) -> void:
	if _seen.has(shot_name):
		return
	_seen[shot_name] = true
	_shots += 1
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(out_dir.path_join("%02d_%s.png" % [_shots, shot_name]))
