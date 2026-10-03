class_name Campaign
extends RefCounted
## Rules engine for one campaign run. Port of prototype/battler.html.
## The UI (or a sim bot) calls intents and listens to signals; nothing here touches a Node.

signal round_resolved(events: Array[Dictionary])
signal player_hit(player: PlayerState, amount: int)
signal player_died(player: PlayerState)
signal monster_died(monster: MonsterState)
signal satisfaction_changed(player: PlayerState, delta: int)
signal log_line(text: String)
signal phase_changed(phase: int)

enum Phase { DRAFT, PICK, FIGHT, LOOT, OVER, RECRUIT }

var content: ContentDB
var tuning: Tuning
var rng := RandomNumberGenerator.new()
var seed_value: int

var phase: Phase = Phase.DRAFT
var night := 1
var encounter := 1
var budget := 0
var time_left := 0
var tpk := false
var skipped_at_midnight := 0
var skipped_no_monsters := 0

var chronicle := Chronicle.new()
var candidates: Array[PlayerData] = []
var party: Array[PlayerState] = []
var offer: Array[MonsterData] = []
var deck: Array[DeckCard] = []
var hand: Array[DmCardData] = []
var loot_offer: Array[LootData] = []

# Encounter state.
var monsters: Array[MonsterState] = []
var round_num := 0
var target: PlayerState = null
var cards_played_this_round := 0
var fudge_active := false
var crit_active := false
var narration_active := false
var fudge_triggered := false
var timed_out := false
var retreated := false
var retreating := false

var _events: Array[Dictionary] = []
var _death_this_round := false


func _init(p_content: ContentDB, p_seed: int) -> void:
	content = p_content
	tuning = p_content.tuning
	seed_value = p_seed
	rng.seed = p_seed
	if tuning.party_candidates <= 0:
		for d in content.party:
			party.append(PlayerState.new(d, tuning.start_satisfaction))


## Call once after connecting signals.
func start() -> void:
	if not party.is_empty():
		_start_night()
		return
	candidates.assign(_generate_candidates())
	_set_phase(Phase.RECRUIT)
	emit_event("recruit_start", Strings.RECRUIT_START)


# ===== Intents =====

## Seats the chosen candidates, in the order they were offered.
func recruit(picks: Array[PlayerData]) -> bool:
	if phase != Phase.RECRUIT or picks.size() != mini(tuning.party_size, candidates.size()):
		return false
	for i in picks.size():
		if not candidates.has(picks[i]) or picks.find(picks[i]) != i:
			return false
	var names := PackedStringArray()
	for d in candidates:
		if picks.has(d):
			party.append(PlayerState.new(d, tuning.start_satisfaction))
			names.append(d.display_name)
	emit_event("recruited", Strings.RECRUITED % ", ".join(names))
	_start_night()
	return true


func draft_pick(picks: Array[MonsterData]) -> bool:
	if phase != Phase.DRAFT or picks.size() != mini(tuning.draft_keep, offer.size()):
		return false
	for i in picks.size():
		if not offer.has(picks[i]) or picks.find(picks[i]) != i:
			return false
	deck.clear()
	for m in picks:
		deck.append(DeckCard.new(m))
	_start_encounter()
	return true


func start_encounter(cards: Array[DeckCard]) -> bool:
	if phase != Phase.PICK or cards.is_empty() or cards_cost(cards) > budget:
		return false
	for i in cards.size():
		if cards[i].used or not deck.has(cards[i]) or cards.find(cards[i]) != i:
			return false
	_events = []
	monsters.clear()
	var names := PackedStringArray()
	for card in cards:
		card.used = true
		monsters.append(MonsterState.new(card.data))
		names.append(card.data.display_name)
	chronicle.encounters += 1
	for p in party:
		p.reset_encounter_counters()
		if p.alive and p.status == Keys.STATUS_PHONE:
			chronicle.count(chronicle.phone_encounters, p.display_name)
	round_num = 0
	target = null
	cards_played_this_round = 0
	fudge_active = false
	crit_active = false
	narration_active = false
	fudge_triggered = false
	timed_out = false
	retreated = false
	_set_phase(Phase.FIGHT)
	emit_event("encounter_start", Strings.ENCOUNTER_START % [encounter, ", ".join(names)])
	return true


## Pass null to let the monsters choose.
func set_target(player: PlayerState) -> bool:
	if phase != Phase.FIGHT or (player != null and not player.is_up()):
		return false
	target = player
	return true


func arm_special(monster: MonsterState, armed: bool = true) -> bool:
	if phase != Phase.FIGHT or not monster.is_up() or monster.special_used:
		return false
	monster.special_armed = armed
	return true


func play_dm_card(card: DmCardData, card_target: PlayerState = null) -> bool:
	if phase != Phase.FIGHT or cards_played_this_round >= tuning.dm_cards_per_round:
		return false
	var index := hand.find(card)
	if index < 0 or not DmEffects.apply(self, card, card_target):
		return false
	hand.remove_at(index)
	cards_played_this_round += 1
	return true


func resolve_round() -> bool:
	if phase != Phase.FIGHT:
		return false
	_death_this_round = false
	# The list covers this round only; intents played before it reported through signals.
	_events = []
	_player_phase()
	if not alive_monsters().is_empty() and not alive_players().is_empty():
		_monster_phase()
	crit_active = false
	fudge_active = false
	narration_active = false
	target = null
	cards_played_this_round = 0
	if hand.size() < tuning.dm_hand_size:
		hand.append(_draw_dm_card())
	if alive_players().is_empty():
		tpk = true
		emit_event("tpk", Strings.TPK)
		_set_phase(Phase.OVER)
	elif retreating and not alive_monsters().is_empty():
		retreated = true
		chronicle.flees += 1
		time_left = maxi(0, time_left - tuning.flee_round_cost)
		emit_event("flee", Strings.FLEE)
		_end_fight()
	elif _death_this_round and not alive_monsters().is_empty():
		# A character death stops the scene: no second kill in the same fight.
		emit_event("death_break", Strings.DEATH_BREAK)
		_end_fight()
	elif alive_monsters().is_empty() or round_num >= tuning.max_rounds_per_encounter or time_left <= 0:
		timed_out = not alive_monsters().is_empty()
		if timed_out:
			chronicle.timeouts += 1
		_end_fight()
	retreating = false
	var events := _events
	_events = []
	round_resolved.emit(events)
	return true


## The monsters pull out at the end of this round: it still resolves, parting blows included.
func flee() -> bool:
	if phase != Phase.FIGHT:
		return false
	retreating = true
	return resolve_round()


func give_loot(item: LootData, player: PlayerState) -> bool:
	if phase != Phase.LOOT or not loot_offer.has(item) or not party.has(player) or not player.alive:
		return false
	var fit := loot_fits(item, player)
	player.atk += item.atk
	player.max_hp += item.hp
	player.hp += item.hp
	if player.class_key == Keys.HEALER:
		player.heal_power += item.heal_bonus
	if player.class_key == Keys.CC and item.stun_bonus > 0.0:
		player.stun_chance = minf(tuning.stun_chance_cap, player.stun_chance + item.stun_bonus)
	var line := Strings.LOOT_GIVEN % [player.display_name, item.display_name]
	emit_event("loot", line if fit else line + Strings.LOOT_OFF_CLASS, {"player": player, "item": item})
	chronicle.count(chronicle.loot_received, player.display_name)
	add_satisfaction(player, loot_satisfaction(item, player))
	for q in party:
		if q != player and q.alive:
			add_satisfaction(q, -tuning.jealousy)
	_next_encounter()
	return true


# ===== Queries =====

func alive_players() -> Array[PlayerState]:
	var out: Array[PlayerState] = []
	for p in party:
		if p.is_up():
			out.append(p)
	return out


func alive_monsters() -> Array[MonsterState]:
	var out: Array[MonsterState] = []
	for m in monsters:
		if m.is_up():
			out.append(m)
	return out


func unused_cards() -> Array[DeckCard]:
	var out: Array[DeckCard] = []
	for card in deck:
		if not card.used:
			out.append(card)
	return out


func cards_cost(cards: Array[DeckCard]) -> int:
	var total := 0
	for card in cards:
		total += card.data.cost
	return total


func loot_fits(item: LootData, player: PlayerState) -> bool:
	return item.class_key == "" or item.class_key == player.class_key


func loot_satisfaction(item: LootData, player: PlayerState) -> int:
	if loot_fits(item, player):
		return item.satisfaction
	return floori(item.satisfaction * tuning.off_class_factor)


func power(player: PlayerState) -> int:
	return player.atk * tuning.power_atk_weight + roundi(player.max_hp / tuning.power_hp_divisor)


func final_score() -> int:
	var total := 0
	for p in party:
		if p.alive:
			total += power(p) * p.satisfaction
	return total


# ===== Helpers shared with the registries (Behaviours, Specials, DmEffects) =====

## Who the flavour lines tease: the Murder Hobo if there is one, else the first player up.
func flavour_name() -> String:
	var alive := alive_players()
	for p in alive:
		if p.archetype_key == Keys.MURDER_HOBO:
			return p.display_name
	return alive[0].display_name if not alive.is_empty() else ""


func chance(probability: float) -> bool:
	return rng.randf() < probability


func pick_player(from: Array[PlayerState]) -> PlayerState:
	return from[rng.randi_range(0, from.size() - 1)]


## Appends to the current round's event list; non-empty text is also a log line.
func emit_event(type: String, text: String = "", data: Dictionary = {}) -> void:
	var ev := {"type": type, "text": text}
	ev.merge(data)
	_events.append(ev)
	if text != "":
		log_line.emit(text)


func add_satisfaction(player: PlayerState, delta: int) -> void:
	var before := player.satisfaction
	player.satisfaction = clampi(before + delta, 0, tuning.max_satisfaction)
	if player.satisfaction != before:
		emit_event("satisfaction", "", {"player": player, "delta": player.satisfaction - before})
		satisfaction_changed.emit(player, player.satisfaction - before)


func add_monster(data: MonsterData, special_used: bool) -> MonsterState:
	var m := MonsterState.new(data, special_used)
	monsters.append(m)
	emit_event("monster_added", "", {"monster": m})
	return m


func poison(player: PlayerState) -> void:
	if player.poisoned:
		return
	player.poisoned = true
	emit_event("poisoned", Strings.POISONED % player.display_name, {"player": player})


## Monster damage on a player, with Fudge protection.
func hit(m: MonsterState, t: PlayerState, damage: int) -> void:
	if t.hp - damage <= 0 and fudge_active:
		damage = t.hp - tuning.fudge_survive_hp
		fudge_triggered = true
		chronicle.fudges += 1
		emit_event("fudge", Strings.FUDGE_SAVE % [t.display_name, tuning.fudge_survive_hp], {"player": t})
	t.hp -= damage
	t.enc_taken += damage
	emit_event("player_hit", Strings.MONSTER_ATTACK % [m.display_name, t.display_name, damage],
		{"monster": m, "player": t, "amount": damage})
	player_hit.emit(t, damage)
	if m.data.has_flag(Keys.FLAG_POISON):
		poison(t)
	if t.hp <= 0:
		_die(t, Strings.DIES, m.display_name)


# ===== Night / encounter flow =====

func _set_phase(p: Phase) -> void:
	phase = p
	phase_changed.emit(p)


func _start_night() -> void:
	encounter = 1
	# Whoever lost a character last night is back with a new one.
	for p in party:
		if not p.alive:
			p.reroll(tuning.reroll_stat_ratio)
			emit_event("reroll", Strings.REROLL % p.display_name, {"player": p})
	time_left = tuning.rounds_before_midnight
	budget = tuning.budget_base + tuning.budget_per_night * night
	var pool: Array[MonsterData] = []
	for m in content.monsters:
		if m.cost <= budget:
			pool.append(m)
	offer.assign(_sample(pool, tuning.draft_offer))
	deck.clear()
	_set_phase(Phase.DRAFT)
	emit_event("night_start", Strings.NIGHT_START % [night, tuning.draft_keep])


func _start_encounter() -> void:
	hand.clear()
	for _i in tuning.dm_start_hand:
		hand.append(_draw_dm_card())
	for p in party:
		p.status = Keys.STATUS_NONE
		p.poisoned = false
		p.inspired = false
		p.skip_turn = false
		if p.alive:
			p.hp = mini(p.max_hp, p.hp + roundi(p.max_hp * tuning.recover_ratio))
	var alive := alive_players()
	if not alive.is_empty() and chance(tuning.status_chance):
		var p := pick_player(alive)
		p.status = Keys.STATUSES[rng.randi_range(0, Keys.STATUSES.size() - 1)]
		emit_event("status", Strings.STATUS[p.status] % p.display_name, {"player": p})
	# Bored players tune out, which makes the next fight more dangerous for everyone.
	for q in alive:
		if q.satisfaction < tuning.bored_threshold and q.status == Keys.STATUS_NONE:
			q.status = Keys.STATUS_PHONE
			emit_event("status", Strings.BORED_PHONE % q.display_name, {"player": q})
	if unused_cards().is_empty():
		# Not in the prototype (it soft-locks). See DESIGN_QUESTIONS.md.
		skipped_no_monsters += 1
		chronicle.skipped += 1
		emit_event("skip", Strings.NO_MONSTERS_LEFT)
		for q in party:
			if q.alive:
				add_satisfaction(q, -tuning.skip_satisfaction_penalty)
		_next_encounter()
		return
	_set_phase(Phase.PICK)


func _next_encounter() -> void:
	encounter += 1
	var remaining := tuning.encounters_per_night - encounter + 1
	if remaining > 0 and time_left > 0:
		_start_encounter()
		return
	if remaining > 0:
		skipped_at_midnight += remaining
		chronicle.skipped += remaining
		emit_event("midnight", Strings.MIDNIGHT)
		for p in party:
			if p.alive:
				add_satisfaction(p, -tuning.skip_satisfaction_penalty)
	night += 1
	if night > tuning.nights:
		emit_event("campaign_end", Strings.CAMPAIGN_END % final_score())
		_set_phase(Phase.OVER)
	else:
		_start_night()


# ===== Round resolution: poison -> players -> monsters =====

func _player_phase() -> void:
	round_num += 1
	time_left -= 1
	for m in monsters:
		m.stunned = false
	for p in alive_players():
		if p.poisoned:
			p.hp -= tuning.poison_damage
			p.enc_taken += tuning.poison_damage
			emit_event("poison_tick", Strings.POISON_TICK % [p.display_name, tuning.poison_damage],
				{"player": p, "amount": tuning.poison_damage})
			if p.hp <= 0:
				_die(p, Strings.DIES_POISON)
	for p in alive_players():
		if p.skip_turn:
			p.skip_turn = false
			emit_event("skip_turn", Strings.SKIPS_TURN % p.display_name, {"player": p})
			continue
		if p.status == Keys.STATUS_PHONE and round_num <= tuning.phone_skip_rounds:
			emit_event("player_idle", "", {"player": p})
			continue
		var live := alive_monsters()
		if live.is_empty():
			break
		if p.class_key == Keys.HEALER and _try_heal(p):
			continue
		if p.class_key == Keys.CC:
			_try_stun(p, live)
		_player_attack(p, live)


func _try_heal(healer: PlayerState) -> bool:
	var low: PlayerState = null
	for q in alive_players():
		if q.hp < q.max_hp * tuning.heal_threshold:
			if low == null or float(q.hp) / q.max_hp < float(low.hp) / low.max_hp:
				low = q
	if low == null:
		return false
	var amount := mini(healer.heal_power + rng.randi_range(0, tuning.heal_die - 1), low.max_hp - low.hp)
	low.hp += amount
	healer.enc_healed += amount
	emit_event("heal", Strings.HEALS % [healer.display_name, low.display_name, amount],
		{"player": healer, "target": low, "amount": amount})
	return true


func _try_stun(p: PlayerState, live: Array[MonsterState]) -> void:
	var big: MonsterState = null
	for m in live:
		if not m.data.has_flag(Keys.FLAG_NO_STUN) and (big == null or m.atk > big.atk):
			big = m
	if big != null and chance(p.stun_chance):
		big.stunned = true
		p.enc_stuns += 1
		emit_event("stun", Strings.STUNS % [p.display_name, big.display_name], {"player": p, "monster": big})


func _player_attack(p: PlayerState, live: Array[MonsterState]) -> void:
	# Murder Hobo goes for the biggest pile of HP, everyone else finishes the weakest.
	var t := live[0]
	for m in live:
		if (m.hp > t.hp) if p.archetype_key == Keys.MURDER_HOBO else (m.hp < t.hp):
			t = m
	var damage := p.atk + _damage_roll()
	if p.status == Keys.STATUS_DICE_TOWER and chance(tuning.dice_tower_crit_chance):
		damage *= tuning.dice_tower_crit_mult
		emit_event("crit", Strings.DICE_TOWER_CRIT % p.display_name, {"player": p})
	if p.inspired:
		damage *= tuning.inspiration_mult
		p.inspired = false
		emit_event("inspired", Strings.INSPIRED_HIT % p.display_name, {"player": p})
	t.hp -= damage
	p.enc_dealt += damage
	emit_event("monster_hit", Strings.PLAYER_ATTACK % [p.display_name, t.display_name, damage],
		{"player": p, "monster": t, "amount": damage})
	if t.hp <= 0:
		p.enc_kills += 1
		emit_event("monster_died", Strings.KILLS % [p.display_name, t.display_name], {"player": p, "monster": t})
		monster_died.emit(t)


func _monster_phase() -> void:
	if narration_active:
		emit_event("narration", Strings.NARRATION_RESOLVE)
		return
	# Snapshot: monsters summoned this round act next round.
	for m in alive_monsters():
		var alive := alive_players()
		if alive.is_empty():
			break
		var mult := tuning.crit_mult if crit_active else 1.0
		var times := 1
		if m.special_armed:
			m.special_armed = false
			m.special_used = true
			emit_event("special", Strings.SPECIAL % [m.display_name, m.data.special_name], {"monster": m})
			var outcome := Specials.resolve(self, m, alive, mult)
			if outcome.skip_attack:
				continue
			mult *= outcome.mult
			times = outcome.times
		if m.stunned or m.hesitating:
			emit_event("monster_idle", "", {"monster": m, "stunned": m.stunned})
			m.hesitating = false
			continue
		var split := Behaviours.is_split(m.data.behaviour)
		for _attack in times:
			var standing := alive_players()
			if standing.is_empty():
				break
			for t in Behaviours.targets(self, m, standing):
				var damage := m.atk + _damage_roll()
				if split:
					damage = ceili(damage * tuning.multi_damage_factor)
				hit(m, t, ceili(damage * mult))


## `killer` is the monster's name, or "" for poison.
func _die(p: PlayerState, how: String, killer: String = "") -> void:
	p.hp = 0
	p.alive = false
	chronicle.deaths.append({"name": p.display_name, "night": night, "killer": killer})
	_death_this_round = true
	emit_event("player_died", Strings.DEATH % [p.display_name, how], {"player": p})
	player_died.emit(p)
	for q in party:
		if q.alive:
			add_satisfaction(q, -tuning.death_grief)


# ===== Satisfaction at encounter end =====

func _end_fight() -> void:
	var max_taken := 0
	var max_dealt := 0
	for p in party:
		max_taken = maxi(max_taken, p.enc_taken)
		max_dealt = maxi(max_dealt, p.enc_dealt)
	if timed_out:
		emit_event("timeout", Strings.TIMEOUT)
	for p in party:
		if not p.alive:
			if p.enc_start_hp > 0:
				add_satisfaction(p, -p.satisfaction)
			continue
		var thrill := float(p.enc_taken) / p.max_hp
		var delta := 0
		var why := ""
		if thrill < tuning.thrill_low:
			delta = tuning.satisfaction_bored
			why = Strings.SAT_BORED
		elif thrill < tuning.thrill_high:
			delta = tuning.satisfaction_good
			why = Strings.SAT_GOOD
		else:
			delta = tuning.satisfaction_great
			why = Strings.SAT_GREAT
		if timed_out:
			delta -= tuning.timeout_penalty
		if retreated:
			delta -= tuning.flee_satisfaction_penalty
			why += Strings.SAT_FLED

		var took_most := p.enc_taken == max_taken and max_taken > 0
		var cls: ClassData = content.classes[p.class_key]
		var class_hit := true
		match p.class_key:
			Keys.TANK:
				class_hit = took_most
				if not class_hit:
					why += Strings.SAT_TANK_IGNORED
			Keys.DPS:
				class_hit = p.enc_dealt == max_dealt
				if not class_hit:
					why += Strings.SAT_DPS_OUTDONE
			Keys.HEALER:
				class_hit = p.enc_healed > 0
				why += Strings.SAT_HEALER_USEFUL if class_hit else Strings.SAT_HEALER_IDLE
			Keys.CC:
				class_hit = p.enc_stuns > 0
				if not class_hit:
					why += Strings.SAT_CC_NO_STUN
		delta += cls.satisfaction_bonus if class_hit else -cls.satisfaction_malus

		var arch: ArchetypeData = content.archetypes[p.archetype_key]
		match p.archetype_key:
			Keys.MURDER_HOBO:
				if p.enc_kills > 0:
					delta += arch.satisfaction_bonus
				else:
					delta -= arch.satisfaction_malus
					why += Strings.SAT_HOBO_NO_KILL
			Keys.MAIN_CHARACTER:
				delta += arch.satisfaction_bonus if took_most else -arch.satisfaction_malus
			Keys.RULE_LAWYER:
				if fudge_triggered:
					delta -= arch.satisfaction_malus
				if monsters.size() <= tuning.rule_lawyer_max_monsters:
					delta += arch.satisfaction_bonus
			Keys.QUIET:
				if thrill >= tuning.thrill_low and thrill < tuning.thrill_high:
					delta += arch.satisfaction_bonus
		emit_event("encounter_verdict", Strings.SAT_LINE % [p.display_name, why, delta], {"player": p, "delta": delta})
		add_satisfaction(p, delta)

	for i in party.size():
		var p := party[i]
		if p.alive and p.status == Keys.STATUS_TOXIC:
			for j: int in [i - 1, i + 1]:
				var neighbour := party[posmod(j, party.size())]
				if neighbour.alive:
					add_satisfaction(neighbour, -tuning.toxic_penalty)
			emit_event("toxic", Strings.TOXIC % p.display_name, {"player": p})

	var pool: Array[LootData] = []
	for item in content.loot:
		if not item.legendary or night >= tuning.legendary_min_night:
			pool.append(item)
	loot_offer.assign(_sample(pool, tuning.loot_offer))
	_set_phase(Phase.LOOT)


# ===== RNG =====

## Random class x archetype combos with distinct names.
func _generate_candidates() -> Array[PlayerData]:
	var class_keys := content.classes.keys()
	var archetype_keys := content.archetypes.keys()
	var names := _sample(Strings.PLAYER_NAMES, tuning.party_candidates)
	var out: Array[PlayerData] = []
	for i in names.size():
		var cls: ClassData = content.classes[class_keys[rng.randi_range(0, class_keys.size() - 1)]]
		var d := PlayerData.new()
		d.display_name = names[i]
		d.seat = i
		d.class_key = cls.key
		d.archetype_key = archetype_keys[rng.randi_range(0, archetype_keys.size() - 1)]
		d.hp = cls.hp
		d.atk = cls.atk
		d.heal_power = cls.heal_power
		d.stun_chance = cls.stun_chance
		out.append(d)
	return out


func _damage_roll() -> int:
	return rng.randi_range(0, tuning.damage_die - 1) + tuning.damage_offset


func _draw_dm_card() -> DmCardData:
	return content.dm_cards[rng.randi_range(0, content.dm_cards.size() - 1)]


## Up to `count` distinct elements, drawn without replacement.
func _sample(pool: Array, count: int) -> Array:
	var bag := pool.duplicate()
	var out := []
	while out.size() < count and not bag.is_empty():
		out.append(bag.pop_at(rng.randi_range(0, bag.size() - 1)))
	return out
