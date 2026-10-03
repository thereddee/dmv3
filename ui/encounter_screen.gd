class_name EncounterScreen
extends Control
## The table: party always on top, and below it the draft, the monster pick,
## the fight or the loot depending on the campaign phase.
## Calls Campaign intents and plays back the ordered event list of each round.

## `seed_text` is what the player typed: empty for a random seed.
signal new_campaign_requested(seed_text: String)
signal playback_finished

const SEAT_SCENE := preload("res://ui/player_seat.tscn")
const MONSTER_SCENE := preload("res://ui/monster_card.tscn")
enum OverlayMode { SUMMARY, CAMPAIGN_OVER, MENU }

const EVENT_DELAY := 0.34
const QUICK_DELAY := 0.05
const FEED_MAX_LINES := 60
const FEED_SLIDE := 36

var campaign: Campaign
var _seats: Dictionary[PlayerState, PlayerSeat] = {}
var _cards: Dictionary[MonsterState, MonsterCard] = {}
var _busy := false
var _resolving := false
var _pending: Array[Dictionary] = []
var _card_awaiting_target: DmCardData = null
var _verdicts := PackedStringArray()
var _end_title := ""
var _loot_pick: LootData = null
var _overlay_mode := OverlayMode.SUMMARY

@onready var _header: Label = $Root/Columns/Left/TopBar/HeaderLabel
@onready var _clock: Label = $Root/Columns/Left/TopBar/ClockLabel
@onready var _score: Label = $Root/Columns/Left/TopBar/ScoreLabel
@onready var _party_title: Label = $Root/Columns/Left/PartyTitle
@onready var _party_row: HBoxContainer = $Root/Columns/Left/PartyRow
@onready var _monsters_title: Label = $Root/Columns/Left/MonstersTitle
@onready var _monsters_row: HFlowContainer = $Root/Columns/Left/MonstersRow
@onready var _hint: Label = $Root/Columns/Left/HintLabel
@onready var _error: Label = $Root/Columns/Left/ErrorLabel
@onready var _hand_title: Label = $Root/Columns/Left/HandTitle
@onready var _choice: ChoicePanel = $Root/Columns/Left/ChoicePanel
@onready var _bottom: HBoxContainer = $Root/Columns/Left/Bottom
@onready var _hand_row: HBoxContainer = $Root/Columns/Left/Bottom/HandRow
@onready var _resolve_button: Button = $Root/Columns/Left/Bottom/Actions/ResolveButton
@onready var _flee_button: Button = $Root/Columns/Left/Bottom/Actions/FleeButton
@onready var _feed_panel: PanelContainer = $Root/Columns/Right
@onready var _feed_title: Label = $Root/Columns/Right/FeedMargin/FeedBox/FeedTitle
@onready var _feed: VBoxContainer = $Root/Columns/Right/FeedMargin/FeedBox/Scroll/Feed
@onready var _overlay: ColorRect = $Overlay
@onready var _summary_panel: PanelContainer = $Overlay/Center/SummaryPanel
@onready var _summary_title: Label = $Overlay/Center/SummaryPanel/SummaryMargin/SummaryBox/SummaryTitle
@onready var _summary_body: Label = $Overlay/Center/SummaryPanel/SummaryMargin/SummaryBox/SummaryBody
@onready var _continue_button: Button = $Overlay/Center/SummaryPanel/SummaryMargin/SummaryBox/ContinueButton
@onready var _recap_scroll: ScrollContainer = $Overlay/Center/SummaryPanel/SummaryMargin/SummaryBox/RecapScroll
@onready var _recap_label: Label = $Overlay/Center/SummaryPanel/SummaryMargin/SummaryBox/RecapScroll/RecapLabel
@onready var _seed_row: HBoxContainer = $Overlay/Center/SummaryPanel/SummaryMargin/SummaryBox/SeedRow
@onready var _seed_label: Label = $Overlay/Center/SummaryPanel/SummaryMargin/SummaryBox/SeedRow/SeedLabel
@onready var _seed_edit: LineEdit = $Overlay/Center/SummaryPanel/SummaryMargin/SummaryBox/SeedRow/SeedEdit
@onready var _replay_button: Button = $Overlay/Center/SummaryPanel/SummaryMargin/SummaryBox/ReplayButton
@onready var _cancel_button: Button = $Overlay/Center/SummaryPanel/SummaryMargin/SummaryBox/CancelButton
@onready var _menu_button: Button = $Root/Columns/Left/TopBar/MenuButton


func _ready() -> void:
	_hand_title.text = Strings.UI_HAND
	_feed_title.text = Strings.UI_FEED
	_resolve_button.text = Strings.UI_RESOLVE
	for title: Label in [_party_title, _monsters_title, _hand_title, _feed_title, _clock]:
		title.add_theme_color_override("font_color", Palette.MUTED)
	_hint.add_theme_color_override("font_color", Palette.ACCENT)
	_error.add_theme_color_override("font_color", Palette.DANGER)
	_feed_panel.add_theme_stylebox_override("panel", Palette.panel())
	_summary_panel.add_theme_stylebox_override("panel", Palette.panel(Palette.ACCENT, 2))
	Palette.style_button(_resolve_button, true)
	Palette.style_button(_flee_button)
	Palette.style_button(_continue_button, true)
	_resolve_button.pressed.connect(_on_resolve_pressed)
	_flee_button.pressed.connect(_on_flee_pressed)
	_continue_button.pressed.connect(_on_continue_pressed)
	_menu_button.text = Strings.UI_MENU
	_seed_label.text = Strings.UI_SEED_LABEL
	_seed_edit.placeholder_text = Strings.UI_SEED_HINT
	_cancel_button.text = Strings.UI_CANCEL
	for button: Button in [_menu_button, _replay_button, _cancel_button]:
		Palette.style_button(button)
	_menu_button.pressed.connect(_on_menu_pressed)
	_replay_button.pressed.connect(func() -> void: new_campaign_requested.emit(str(campaign.seed_value)))
	_cancel_button.pressed.connect(func() -> void: _overlay.visible = false)
	_seed_edit.text_submitted.connect(func(_text: String) -> void: _on_continue_pressed())
	_choice.selection_changed.connect(_on_choice_changed)
	_choice.confirmed.connect(_on_choice_confirmed)
	_choice.limit_hit.connect(func() -> void:
		_error.text = Strings.UI_ERR_DRAFT_FULL % _choice.max_select)
	_recap_label.add_theme_color_override("font_color", Palette.MUTED)


## Attach to a campaign. Call before Campaign.start().
func bind(c: Campaign) -> void:
	campaign = c
	_flee_button.text = Strings.UI_FLEE % c.tuning.flee_round_cost
	c.log_line.connect(_on_log_line)
	c.satisfaction_changed.connect(_on_satisfaction_changed)
	c.round_resolved.connect(_on_round_resolved)
	_clear(_feed)
	_sync_seats()
	_overlay.visible = false


## One seat per party member; rebuilt when the table changes (new campaign, recruit).
func _sync_seats() -> void:
	var same := _seats.size() == campaign.party.size()
	for p in campaign.party:
		same = same and _seats.has(p)
	if same:
		return
	_clear(_party_row)
	_seats.clear()
	for p in campaign.party:
		var seat: PlayerSeat = SEAT_SCENE.instantiate()
		_party_row.add_child(seat)
		seat.setup(p, campaign.content)
		seat.pressed.connect(_on_seat_pressed)
		_seats[p] = seat


## Shows whatever the current campaign phase needs. Call after Campaign.start()
## and after every intent that can change the phase.
func enter_phase() -> void:
	_error.text = " "
	_overlay.visible = false
	_loot_pick = null
	_card_awaiting_target = null
	_sync_seats()
	var fighting := campaign.phase == Campaign.Phase.FIGHT
	for node: Control in [_monsters_row, _hand_title, _bottom]:
		node.visible = fighting
	_choice.visible = not fighting and campaign.phase != Campaign.Phase.OVER
	_monsters_title.visible = campaign.phase != Campaign.Phase.OVER
	match campaign.phase:
		Campaign.Phase.RECRUIT:
			_open_recruit()
		Campaign.Phase.DRAFT:
			_open_draft()
		Campaign.Phase.PICK:
			_open_pick()
		Campaign.Phase.FIGHT:
			_clear(_monsters_row)
			_cards.clear()
			_verdicts.clear()
			_end_title = ""
		Campaign.Phase.LOOT:
			_open_loot()
	refresh()
	if campaign.phase == Campaign.Phase.OVER:
		_show_campaign_over()


## Score screen: one line per player, the total, and the seed to replay or change.
func _show_campaign_over() -> void:
	var lines := PackedStringArray()
	if campaign.tpk:
		lines.append(Strings.TPK)
	for p in campaign.party:
		if p.alive and not campaign.tpk:
			var power := campaign.power(p)
			lines.append(Strings.UI_SCORE_LINE % [p.display_name, power, p.satisfaction, power * p.satisfaction])
		else:
			lines.append(Strings.UI_SCORE_DEAD % p.display_name)
	var score := 0 if campaign.tpk else campaign.final_score()
	lines.append("")
	lines.append(Strings.UI_SCORE_TOTAL % [score, campaign.alive_players().size(), campaign.seed_value])
	_summary_title.text = Strings.UI_END_TPK if campaign.tpk else Strings.UI_END_CAMPAIGN
	_summary_body.text = "\n".join(lines)
	_recap_label.text = Recap.build(campaign)
	_open_overlay(OverlayMode.CAMPAIGN_OVER)


func _on_menu_pressed() -> void:
	if _busy or _overlay.visible:
		return
	_summary_title.text = Strings.UI_MENU_TITLE
	_summary_body.text = Strings.UI_MENU_BODY % campaign.seed_value
	_open_overlay(OverlayMode.MENU)


func _open_overlay(mode: OverlayMode) -> void:
	_overlay_mode = mode
	var restarting := mode != OverlayMode.SUMMARY
	_seed_row.visible = restarting
	_recap_scroll.visible = mode == OverlayMode.CAMPAIGN_OVER
	_recap_scroll.scroll_vertical = 0
	_replay_button.visible = restarting
	_cancel_button.visible = mode == OverlayMode.MENU
	_seed_edit.text = ""
	_replay_button.text = Strings.UI_REPLAY % campaign.seed_value
	_continue_button.text = Strings.UI_NEW_CAMPAIGN if restarting else Strings.UI_NEXT
	_overlay.visible = true


## Snap every widget to the model.
func refresh() -> void:
	var t := campaign.tuning
	var where := [mini(campaign.night, t.nights), t.nights,
		mini(campaign.encounter, t.encounters_per_night), t.encounters_per_night]
	if _monsters_row.visible:
		_header.text = Strings.UI_HEADER % (where + [campaign.round_num + 1])
	else:
		_header.text = Strings.UI_HEADER_IDLE % where
	_clock.text = Strings.UI_CLOCK % [campaign.time_left, campaign.budget, campaign.seed_value]
	if campaign.phase == Campaign.Phase.RECRUIT:
		_clock.text = Strings.UI_CLOCK_IDLE % campaign.seed_value
	_score.text = Strings.UI_SCORE % campaign.final_score()
	var late := campaign.time_left < t.max_rounds_per_encounter and campaign.phase != Campaign.Phase.RECRUIT
	_clock.add_theme_color_override("font_color", Palette.DANGER if late else Palette.MUTED)
	var fighting := campaign.phase == Campaign.Phase.FIGHT
	var picking := _card_awaiting_target != null or _loot_pick != null
	for p in campaign.party:
		_seats[p].refresh(fighting and campaign.target == p, picking and p.alive)
	if campaign.phase == Campaign.Phase.LOOT:
		_party_title.text = Strings.UI_PARTY_LOOT
	else:
		_party_title.text = Strings.UI_PARTY if fighting else Strings.UI_PARTY_IDLE
	_hint.visible = _monsters_row.visible
	if not _monsters_row.visible:
		return
	_monsters_title.text = Strings.UI_MONSTERS
	for m in campaign.monsters:
		_card_for(m).refresh()
	_rebuild_hand()
	if _card_awaiting_target != null:
		_hint.text = Strings.UI_HINT_PICK
	elif campaign.target != null:
		_hint.text = Strings.UI_HINT_TARGET % campaign.target.display_name
	else:
		_hint.text = Strings.UI_HINT_DEFAULT
	var in_fight := campaign.phase == Campaign.Phase.FIGHT and not _busy
	_resolve_button.disabled = not in_fight
	_flee_button.disabled = not in_fight


func is_busy() -> bool:
	return _busy


func resolve() -> void:
	_on_resolve_pressed()


# ===== Input =====

func _on_seat_pressed(p: PlayerState) -> void:
	if campaign.phase == Campaign.Phase.LOOT and _loot_pick != null and not _overlay.visible:
		if not p.alive:
			_error.text = Strings.UI_ERR_LOOT_DEAD
		elif campaign.give_loot(_loot_pick, p):
			enter_phase()
		return
	if _busy or campaign.phase != Campaign.Phase.FIGHT:
		return
	_error.text = " "
	if not p.is_up():
		_error.text = Strings.UI_ERR_DEAD_PLAYER
	elif _card_awaiting_target != null:
		if campaign.play_dm_card(_card_awaiting_target, p):
			_card_awaiting_target = null
	else:
		campaign.set_target(null if campaign.target == p else p)
	refresh()


func _on_monster_pressed(m: MonsterState) -> void:
	if _busy or campaign.phase != Campaign.Phase.FIGHT:
		return
	_error.text = " "
	if not m.is_up():
		_error.text = Strings.UI_ERR_DEAD_MONSTER
	elif m.special_used:
		_error.text = Strings.UI_ERR_SPECIAL_USED
	else:
		campaign.arm_special(m, not m.special_armed)
	refresh()


func _on_card_pressed(card: DmCardData) -> void:
	if _busy or campaign.phase != Campaign.Phase.FIGHT:
		return
	_error.text = " "
	if campaign.cards_played_this_round >= campaign.tuning.dm_cards_per_round:
		_error.text = Strings.UI_ERR_ONE_CARD
	elif card.needs_target:
		_card_awaiting_target = null if _card_awaiting_target == card else card
	else:
		_card_awaiting_target = null
		campaign.play_dm_card(card)
	refresh()


func _on_resolve_pressed() -> void:
	if _card_awaiting_target != null:
		_error.text = Strings.UI_ERR_PICK_FIRST
		return
	_run_round(false)


func _on_flee_pressed() -> void:
	_card_awaiting_target = null
	_run_round(true)


func _run_round(flee: bool) -> void:
	if _busy or campaign.phase != Campaign.Phase.FIGHT:
		return
	_error.text = " "
	_resolving = true
	_pending = []
	if flee:
		campaign.flee()
	else:
		campaign.resolve_round()
	_resolving = false
	_play(_pending)


func _on_continue_pressed() -> void:
	if _overlay_mode == OverlayMode.SUMMARY:
		enter_phase()
	else:
		new_campaign_requested.emit(_seed_edit.text.strip_edges())


# ===== Draft, monster pick, loot =====

func _open_recruit() -> void:
	var t := campaign.tuning
	var entries: Array[String] = []
	var locked: Array[bool] = []
	for d in campaign.candidates:
		var cls: ClassData = campaign.content.classes[d.class_key]
		var arch: ArchetypeData = campaign.content.archetypes[d.archetype_key]
		entries.append(Strings.UI_RECRUIT_CARD % [d.display_name, cls.display_name, d.hp, d.atk, cls.blurb,
			arch.display_name, arch.blurb])
		locked.append(false)
	_choice.open(entries, locked, t.party_size, Strings.UI_RECRUIT_CONFIRM)
	_choice.set_info(Strings.UI_RECRUIT_INFO)
	_on_choice_changed()


func _open_draft() -> void:
	var t := campaign.tuning
	var entries: Array[String] = []
	var locked: Array[bool] = []
	for m in campaign.offer:
		entries.append(Strings.UI_DRAFT_CARD % [m.display_name, m.cost, m.hp, m.atk, m.special_name, m.special_desc, m.quip])
		locked.append(false)
	_choice.open(entries, locked, t.draft_keep, Strings.UI_DRAFT_CONFIRM)
	_choice.set_info(Strings.UI_DRAFT_INFO % [t.encounters_per_night, campaign.budget])
	_on_choice_changed()


func _open_pick() -> void:
	var t := campaign.tuning
	var entries: Array[String] = []
	var locked: Array[bool] = []
	for deck_card in campaign.deck:
		var m := deck_card.data
		if deck_card.used:
			entries.append(Strings.UI_PICK_CARD_USED % m.display_name)
		else:
			entries.append(Strings.UI_PICK_CARD % [m.display_name, m.cost, m.hp, m.atk, m.special_name, m.special_desc])
		locked.append(deck_card.used)
	_choice.open(entries, locked, campaign.deck.size(), Strings.UI_PICK_CONFIRM)
	_choice.set_info(Strings.UI_PICK_INFO % [campaign.unused_cards().size(),
		t.encounters_per_night - campaign.encounter + 1, campaign.time_left])
	_on_choice_changed()


func _open_loot() -> void:
	var entries: Array[String] = []
	var locked: Array[bool] = []
	for item in campaign.loot_offer:
		var stats := PackedStringArray()
		if item.atk > 0:
			stats.append(Strings.UI_LOOT_ATK % item.atk)
		if item.hp > 0:
			stats.append(Strings.UI_LOOT_HP % item.hp)
		if item.heal_bonus > 0:
			stats.append(Strings.UI_LOOT_HEAL % item.heal_bonus)
		if item.stun_bonus > 0.0:
			stats.append(Strings.UI_LOOT_STUN % roundi(item.stun_bonus * 100.0))
		var fits := Strings.UI_LOOT_ANY_CLASS
		if item.class_key != "":
			fits = campaign.content.classes[item.class_key].display_name
		var title := item.display_name + (Strings.UI_LOOT_LEGENDARY if item.legendary else "")
		entries.append(Strings.UI_LOOT_CARD % [title, fits, " · ".join(stats), item.satisfaction])
		locked.append(false)
	_choice.open(entries, locked, 1, "")
	_on_choice_changed()


func _picked_cards() -> Array[DeckCard]:
	var cards: Array[DeckCard] = []
	for i in _choice.selected():
		cards.append(campaign.deck[i])
	return cards


func _on_choice_changed() -> void:
	_error.text = " "
	var t := campaign.tuning
	match campaign.phase:
		Campaign.Phase.RECRUIT:
			_monsters_title.text = Strings.UI_RECRUIT_TITLE % [t.party_size, _choice.selected().size(), t.party_size]
		Campaign.Phase.DRAFT:
			_monsters_title.text = Strings.UI_DRAFT_TITLE % [t.draft_keep, _choice.selected().size(), t.draft_keep]
		Campaign.Phase.PICK:
			_monsters_title.text = Strings.UI_PICK_TITLE % [campaign.cards_cost(_picked_cards()), campaign.budget]
		Campaign.Phase.LOOT:
			_monsters_title.text = Strings.UI_LOOT_TITLE
			var picks := _choice.selected()
			_loot_pick = campaign.loot_offer[picks[0]] if not picks.is_empty() else null
			if _loot_pick != null:
				_choice.set_info(Strings.UI_LOOT_INFO_PICKED % _loot_pick.display_name)
			else:
				_choice.set_info(Strings.UI_LOOT_INFO)
			refresh()


func _on_choice_confirmed() -> void:
	var t := campaign.tuning
	match campaign.phase:
		Campaign.Phase.RECRUIT:
			var players: Array[PlayerData] = []
			for i in _choice.selected():
				players.append(campaign.candidates[i])
			if not campaign.recruit(players):
				_error.text = Strings.UI_ERR_RECRUIT_COUNT % t.party_size
				return
		Campaign.Phase.DRAFT:
			var picks: Array[MonsterData] = []
			for i in _choice.selected():
				picks.append(campaign.offer[i])
			if not campaign.draft_pick(picks):
				_error.text = Strings.UI_ERR_DRAFT_COUNT % t.draft_keep
				return
		Campaign.Phase.PICK:
			var cards := _picked_cards()
			if cards.is_empty():
				_error.text = Strings.UI_ERR_PICK_EMPTY
				return
			if not campaign.start_encounter(cards):
				_error.text = Strings.UI_ERR_PICK_BUDGET
				return
	enter_phase()


# ===== Campaign signals =====

func _on_log_line(text: String) -> void:
	# During a round the lines come back through the event list, in sync with the animation.
	if not _resolving:
		_add_feed_line(text)


func _on_satisfaction_changed(p: PlayerState, delta: int) -> void:
	if not _resolving and _seats.has(p):
		_seats[p].show_satisfaction(delta)


func _on_round_resolved(events: Array[Dictionary]) -> void:
	_pending = events


# ===== Event playback =====

func _play(events: Array[Dictionary]) -> void:
	_busy = true
	_resolve_button.disabled = true
	_flee_button.disabled = true
	for button in _hand_row.get_children():
		if button is Button:
			(button as Button).disabled = true
	for ev in events:
		var wait := _show_event(ev)
		var text: String = ev["text"]
		if text != "":
			_add_feed_line(text)
		await get_tree().create_timer(wait).timeout
	_busy = false
	refresh()
	if campaign.phase != Campaign.Phase.FIGHT:
		_show_summary()
	playback_finished.emit()


## Animates one event and returns how long to wait before the next one.
func _show_event(ev: Dictionary) -> float:
	var seat: PlayerSeat = _seats.get(ev.get("player"))
	var card: MonsterCard = _cards.get(ev.get("monster"))
	match ev["type"]:
		"poison_tick":
			seat.show_damage(ev["amount"], Palette.POISON)
		"player_hit":
			card.show_acting()
			seat.show_damage(ev["amount"])
		"monster_hit":
			seat.show_acting()
			card.show_damage(ev["amount"])
		"heal":
			seat.show_acting()
			_seats[ev["target"]].show_heal(ev["amount"])
		"stun":
			seat.show_acting()
			card.show_note(Strings.UI_POP_STUN)
		"player_idle":
			seat.show_note(Strings.UI_POP_IDLE, Palette.MUTED)
		"skip_turn":
			seat.show_note(Strings.UI_POP_SKIP, Palette.MUTED)
		"monster_idle":
			card.show_note(Strings.UI_STUNNED if ev["stunned"] else Strings.UI_HESITATES, Palette.MUTED)
		"crit":
			seat.show_note(Strings.UI_POP_CRIT)
			return QUICK_DELAY
		"inspired":
			seat.show_note(Strings.UI_POP_INSPIRED)
			return QUICK_DELAY
		"fudge":
			seat.show_note(Strings.UI_POP_FUDGE, Palette.ACCENT)
			return QUICK_DELAY
		"special":
			card.show_special()
		"monster_healed":
			card.show_heal(ev["amount"])
		"monsters_buffed":
			for m: MonsterState in _cards:
				if m.is_up():
					_cards[m].show_note(Strings.UI_POP_ATK % ev["amount"], Palette.DANGER)
					_cards[m].show_atk(m.atk)
		"monster_added":
			var added := _card_for(ev["monster"])
			added.refresh()
			added.show_note(Strings.UI_POP_NEW, Palette.DANGER)
		"webbed":
			seat.show_note(Strings.UI_POP_WEB)
		"poisoned":
			seat.show_note(Strings.UI_POP_POISON, Palette.POISON)
		"player_died":
			seat.show_death()
			_verdicts.append(ev["text"])
			return EVENT_DELAY * 2.0
		"monster_died":
			card.show_death()
		"satisfaction":
			seat.show_satisfaction(ev["delta"])
			return QUICK_DELAY
		"encounter_verdict":
			_verdicts.append(ev["text"])
			return QUICK_DELAY
		"toxic":
			_verdicts.append(ev["text"])
			seat.show_note(Strings.UI_STATUS[Keys.STATUS_TOXIC])
		"tpk":
			_end_title = Strings.UI_END_TPK
		"flee":
			_end_title = Strings.UI_END_FLEE
		"timeout":
			_end_title = Strings.UI_END_TIMEOUT
		"death_break":
			_end_title = Strings.UI_END_DEATH
	return EVENT_DELAY


func _show_summary() -> void:
	if campaign.phase == Campaign.Phase.OVER:
		_show_campaign_over()
		return
	_summary_title.text = _end_title if _end_title != "" else Strings.UI_END_WIN
	_summary_body.text = "\n".join(_verdicts)
	_open_overlay(OverlayMode.SUMMARY)


# ===== Widgets =====

func _card_for(m: MonsterState) -> MonsterCard:
	if _cards.has(m):
		return _cards[m]
	var card: MonsterCard = MONSTER_SCENE.instantiate()
	_monsters_row.add_child(card)
	card.setup(m)
	card.pressed.connect(_on_monster_pressed)
	_cards[m] = card
	return card


func _clear(container: Node) -> void:
	for child in container.get_children():
		container.remove_child(child)
		child.queue_free()


func _rebuild_hand() -> void:
	_clear(_hand_row)
	var locked := _busy or campaign.phase != Campaign.Phase.FIGHT \
			or campaign.cards_played_this_round >= campaign.tuning.dm_cards_per_round
	if campaign.hand.is_empty():
		var empty := Label.new()
		empty.text = Strings.UI_HAND_EMPTY
		empty.add_theme_color_override("font_color", Palette.MUTED)
		_hand_row.add_child(empty)
	for dm_card in campaign.hand:
		var button := Button.new()
		button.text = "%s\n%s" % [dm_card.display_name, dm_card.description]
		button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.add_theme_font_size_override("font_size", 13)
		button.disabled = locked
		Palette.style_button(button, false, dm_card == _card_awaiting_target)
		button.pressed.connect(_on_card_pressed.bind(dm_card))
		_hand_row.add_child(button)


func _add_feed_line(text: String) -> void:
	var holder := MarginContainer.new()
	var label := Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.custom_minimum_size = Vector2(280, 0)
	label.add_theme_font_size_override("font_size", 13)
	holder.add_child(label)
	_feed.add_child(holder)
	_feed.move_child(holder, 0)
	while _feed.get_child_count() > FEED_MAX_LINES:
		var last := _feed.get_child(_feed.get_child_count() - 1)
		_feed.remove_child(last)
		last.queue_free()
	# Slide in from the right, bright, then settle to the muted log colour.
	holder.add_theme_constant_override("margin_left", FEED_SLIDE)
	label.modulate = Palette.GOLD
	var tween := holder.create_tween().set_parallel()
	tween.tween_method(func(v: int) -> void: holder.add_theme_constant_override("margin_left", v), FEED_SLIDE, 0, 0.25)
	tween.tween_property(label, "modulate", Palette.MUTED, 1.6).set_delay(0.6)
