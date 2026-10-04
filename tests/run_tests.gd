extends SceneTree
## Minimal unit tests on core/.
## Usage: godot --headless --script res://tests/run_tests.gd

var _failed := 0
var _content: ContentDB


func _init() -> void:
	_content = ContentDB.load_default()
	_test_recruit_and_recap()
	# Everything below plays the fixed v0 table.
	_content.tuning = _content.tuning.duplicate()
	_content.tuning.party_candidates = 0
	_test_content_loaded()
	_test_same_seed_same_run()
	_test_draft_and_budget()
	_test_fudge_prevents_death()
	_test_flee_costs_time_and_trust()
	_test_flee_still_resolves_the_round()
	_test_death_stops_the_fight()
	_test_bored_players_pull_out_their_phone()
	_test_loot_off_class()
	_test_score_formula()
	_test_svg_path()
	_test_player_appearance()
	_test_pose()
	_test_pixel_palette()
	_test_mood_follows_satisfaction()
	print("tests: %s" % ("ALL PASSED" if _failed == 0 else "%d FAILED" % _failed))
	quit(1 if _failed > 0 else 0)


func _test_svg_path() -> void:
	var subs := SvgPath.parse("M0,0 L10,0 L10,10Z M20,20 L30,20")
	_check(subs.size() == 2, "svg path: two subpaths")
	_check(subs[0].closed and not subs[1].closed, "svg path: only Z closes")
	_check(subs[0].pts.size() == 3, "svg path: M + 2 L = 3 points")
	var curve := SvgPath.parse("M0,0 Q5,10 10,0")
	_check(curve[0].pts.size() == 1 + SvgPath.CURVE_STEPS, "svg path: a curve is flattened")
	_check(curve[0].pts[-1].is_equal_approx(Vector2(10, 0)), "svg path: curve ends on its last point")
	_check(SvgPath.parse("M-4.5,.5 L1e-05,3")[0].pts[0] == Vector2(-4.5, 0.5), "svg path: negatives and bare decimals")


func _test_player_appearance() -> void:
	var a := PlayerAppearance.new()
	var b := PlayerAppearance.new()
	var rng_a := RandomNumberGenerator.new()
	var rng_b := RandomNumberGenerator.new()
	rng_a.seed = 77
	rng_b.seed = 77
	a.randomize_with(rng_a)
	b.randomize_with(rng_b)
	_check(a.race == b.race and a.cls == b.cls and a.skin == b.skin and a.prop == b.prop, "appearance: same seed, same look")
	_check(a.skin in PlayerAppearance.skins_for(a.race), "appearance: skin comes from the race palette")
	_check(a.cls != "aucune", "appearance: generated players always have a class")
	# every combination of race, class and prop must build without errors
	var back := Node2D.new()
	var front := Node2D.new()
	var look := PlayerAppearance.new()
	for race in PlayerAppearance.RACES:
		look.race = race
		for cls in PlayerAppearance.CLASSES:
			look.cls = cls
			for prop in PlayerAppearance.PROPS:
				look.prop = prop
				TablePlayerBuilder.new().build(look, back, front)
	_check(back.get_child_count() > 0 and front.get_child_count() > 0, "appearance: builds layers")
	back.free()
	front.free()

func _test_pose() -> void:
	var look := PlayerAppearance.new()
	look.prop = "pile"
	var geo := TablePlayerBuilder.geo_of(look)
	var first := TablePlayerPose.pose_at(2, look, 3.7, geo)
	_check(first == TablePlayerPose.pose_at(2, look, 3.7, geo), "pose: pure function of seat, look and time")
	_check(first["breath"]["ty"] >= 0.0 and first["breath"]["ty"] <= 1.8, "pose: breathing stays within 1.8 units")
	var dice_seen := {}
	for i in 840:
		var pose := TablePlayerPose.pose_at(0, look, i * 0.01, geo)
		dice_seen[pose["die5"]["op"]] = true
	_check(dice_seen.size() == 2, "pose: the last die is placed and later knocked away")
	var phone := PlayerAppearance.new()
	phone.prop = "cell"
	_check(TablePlayerPose.pose_at(0, phone, 1.0, geo).has("thumb"), "pose: a cell phone gets a scrolling thumb")
	var shifted := TablePlayerPose.pose_at(1, look, 1.0, geo)
	_check(shifted["breath"] != TablePlayerPose.pose_at(0, look, 1.0, geo)["breath"], "pose: seats are out of phase")

func _test_pixel_palette() -> void:
	var img := Image.create(8, 8, false, Image.FORMAT_RGBA8)
	img.fill(Color8(200, 40, 40))
	for x in 3:
		img.set_pixel(x, 0, Color8(40, 40, 200))
	img.set_pixel(7, 7, Color8(202, 42, 42))  # near-duplicate of the main colour
	var palette := PixelTable.build_palette(img, 48)
	_check(palette.size() == 2, "pixel palette: near-duplicates merge, got %d colours" % palette.size())
	_check(palette[0].x > 0.7 and palette[0].z < 0.3, "pixel palette: most frequent colour comes first")
	_check(PixelTable.build_palette(img, 1).size() == PixelTable.MIN_COLORS or PixelTable.build_palette(img, 1).size() == 2,
			"pixel palette: count is clamped to the minimum")

func _test_mood_follows_satisfaction() -> void:
	var t := _content.tuning
	_check(t.mood_for(100) == PlayerAppearance.MOOD_CONTENT, "mood: happy table, happy face")
	_check(t.mood_for(t.mood_focused_min) == PlayerAppearance.MOOD_FOCUSED, "mood: starting satisfaction reads focused")
	_check(t.mood_for(t.mood_bored_min) == PlayerAppearance.MOOD_BORED, "mood: low satisfaction reads bored")
	_check(t.mood_for(0) == PlayerAppearance.MOOD_ANGRY, "mood: zero satisfaction reads angry")

func _check(cond: bool, what: String) -> void:
	if not cond:
		_failed += 1
		print("FAIL: " + what)


func _in_fight(seed_value: int) -> Campaign:
	var c := Campaign.new(_content, seed_value)
	c.start()
	var picks: Array[MonsterData] = []
	picks.assign(c.offer.slice(0, c.tuning.draft_keep))
	c.draft_pick(picks)
	var cards: Array[DeckCard] = [c.deck[0]]
	c.start_encounter(cards)
	return c


func _card(effect: String) -> DmCardData:
	for card in _content.dm_cards:
		if card.effect == effect:
			return card
	return null


func _test_content_loaded() -> void:
	_check(_content.monsters.size() == 12, "12 monsters")
	_check(_content.dm_cards.size() == 6, "6 DM cards")
	_check(_content.loot.size() == 9, "9 loot items")
	_check(_content.party.size() == 4 and _content.party[0].display_name == "Max", "party of 4 in seat order")
	_check(_content.classes.size() == 4 and _content.archetypes.size() == 4, "4 classes, 4 archetypes")


func _test_same_seed_same_run() -> void:
	var scores: Array[int] = []
	var logs: Array[int] = []
	for _i in 2:
		var c := Campaign.new(_content, 4242)
		var lines: Array[String] = []
		c.log_line.connect(func(t: String) -> void: lines.append(t))
		GreedyRiskyBot.new().play(c)
		scores.append(c.final_score())
		logs.append(hash(lines))
	_check(scores[0] == scores[1] and logs[0] == logs[1], "same seed gives the same campaign")


func _test_draft_and_budget() -> void:
	var c := Campaign.new(_content, 1)
	c.start()
	_check(c.offer.size() == c.tuning.draft_offer, "draft offers 7")
	_check(c.budget == 7, "night 1 budget is 5 + 2")
	var too_few: Array[MonsterData] = [c.offer[0]]
	_check(not c.draft_pick(too_few), "draft needs exactly 5")
	var picks: Array[MonsterData] = []
	picks.assign(c.offer.slice(0, 5))
	_check(c.draft_pick(picks) and c.phase == Campaign.Phase.PICK, "draft moves to pick phase")
	_check(not c.start_encounter(c.deck) or c.cards_cost(c.deck) <= c.budget, "budget enforced")


func _test_fudge_prevents_death() -> void:
	var c := _in_fight(7)
	for p in c.party:
		p.hp = 1
	c.hand.append(_card(DmEffects.FUDGE))
	_check(c.play_dm_card(c.hand[-1]), "fudge playable")
	_check(not c.play_dm_card(c.hand[0]), "one DM card per round")
	c.monsters[0].hp = 999
	c.monsters[0].max_hp = 999
	c.resolve_round()
	_check(c.alive_players().size() == 4, "nobody dies under Fudge")


func _test_flee_costs_time_and_trust() -> void:
	var c := _in_fight(9)
	for p in c.party:
		p.status = Keys.STATUS_NONE
	c.monsters[0].hp = 999
	c.hand.append(_card(DmEffects.NARRATION))
	c.play_dm_card(c.hand[-1])
	var time_before := c.time_left
	c.flee()
	_check(c.time_left == time_before - 1 - c.tuning.flee_round_cost, "flee plays the round, then costs 2 more")
	_check(c.phase == Campaign.Phase.LOOT and c.retreated, "flee ends the encounter")
	# Narration (+6), then bored (-15), fled (-8), tank untouched (-6), Main Character not hit (-6).
	_check(c.party[0].satisfaction == 50 + 6 - 15 - 8 - 6 - 6, "flee verdict for the tank")


func _test_flee_still_resolves_the_round() -> void:
	var c := _in_fight(10)
	c.party[2].stun_chance = 0.0
	c.monsters[0].hp = 999
	c.monsters[0].atk = 500
	c.flee()
	_check(c.alive_players().size() == 3, "the parting blow can kill")
	_check(c.phase == Campaign.Phase.LOOT, "the survivors still get out")


func _test_death_stops_the_fight() -> void:
	var c := _in_fight(12)
	c.party[2].stun_chance = 0.0
	c.monsters[0].hp = 999
	c.monsters[0].atk = 500
	c.resolve_round()
	_check(c.alive_players().size() == 3 and c.phase == Campaign.Phase.LOOT, "a death ends the encounter")
	_check(not c.timed_out and not c.retreated, "a death break is neither a timeout nor a flee")
	for p in c.party:
		if not p.alive:
			_check(p.satisfaction == 0, "the dead player is at 0 satisfaction")
			p.atk += 5
			p.reroll()
			_check(p.alive and p.atk == p.data.atk and p.hp == p.data.hp, "reroll brings back a fresh character")


func _test_bored_players_pull_out_their_phone() -> void:
	var c := Campaign.new(_content, 13)
	c.start()
	c.party[2].satisfaction = c.tuning.bored_threshold - 1
	var picks: Array[MonsterData] = []
	picks.assign(c.offer.slice(0, c.tuning.draft_keep))
	c.draft_pick(picks)
	_check(c.party[2].status != Keys.STATUS_NONE, "a bored player starts the encounter with a status")


func _test_loot_off_class() -> void:
	var c := _in_fight(11)
	c.monsters[0].hp = 999
	c.hand.append(_card(DmEffects.NARRATION))
	c.play_dm_card(c.hand[-1])
	c.flee()
	var sword: LootData = null
	for item in _content.loot:
		if item.id == "epee_plus_1":
			sword = item
	c.loot_offer.assign([sword])
	var tank := c.party[0]
	var dps := c.party[1]
	var tank_sat := tank.satisfaction
	var dps_sat := dps.satisfaction
	var atk := tank.atk
	c.give_loot(sword, tank)
	_check(tank.atk == atk + 2, "off-class stats still apply")
	_check(tank.satisfaction == tank_sat + 5, "off-class gift is half satisfaction")
	_check(dps.satisfaction == dps_sat - 4, "others are jealous")


func _test_score_formula() -> void:
	var c := Campaign.new(_content, 3)
	# Max: 4*2 + round(32/5) = 14 ; Kevin: 16 + 4 ; Sophie: 8 + 4 ; Mathieu: 6 + 4. All at 50.
	_check(c.final_score() == (14 + 20 + 12 + 10) * 50, "score = sum of power x satisfaction")


func _test_recruit_and_recap() -> void:
	var c := Campaign.new(_content, 21)
	c.start()
	_check(c.phase == Campaign.Phase.RECRUIT and c.candidates.size() == c.tuning.party_candidates, "campaign opens on 6 candidates")
	var names := {}
	for d in c.candidates:
		names[d.display_name] = true
	_check(names.size() == c.candidates.size(), "candidates have distinct names")
	var too_few: Array[PlayerData] = [c.candidates[0]]
	_check(not c.recruit(too_few), "recruit needs exactly 4")
	var picks: Array[PlayerData] = []
	picks.assign(c.candidates.slice(0, c.tuning.party_size))
	_check(c.recruit(picks) and c.party.size() == 4 and c.phase == Campaign.Phase.DRAFT, "recruit seats the party and opens the draft")
	var again := Campaign.new(_content, 21)
	again.start()
	_check(again.candidates[0].display_name == c.candidates[0].display_name
		and again.candidates[0].class_key == c.candidates[0].class_key, "same seed, same candidates")
	var played := Campaign.new(_content, 22)
	GreedyRiskyBot.new().play(played)
	var story := Recap.build(played)
	_check(story.contains("TL;DR") and played.chronicle.encounters > 0, "a finished campaign has a recap")
