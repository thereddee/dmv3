class_name RandomBot
extends SimBot
## Uniformly random decisions. Baseline for the other two.

const ARM_CHANCE := 0.3
const CARD_CHANCE := 0.5
const TARGET_CHANCE := 0.5
const FLEE_CHANCE := 0.03


func label() -> String:
	return "random"


func recruit(c: Campaign) -> void:
	var bag := c.candidates.duplicate()
	var picks: Array[PlayerData] = []
	while picks.size() < c.tuning.party_size and not bag.is_empty():
		picks.append(bag.pop_at(rng.randi_range(0, bag.size() - 1)))
	c.recruit(picks)


func draft(c: Campaign) -> void:
	var bag := c.offer.duplicate()
	var picks: Array[MonsterData] = []
	while picks.size() < c.tuning.draft_keep and not bag.is_empty():
		picks.append(bag.pop_at(rng.randi_range(0, bag.size() - 1)))
	c.draft_pick(picks)


func pick(c: Campaign) -> void:
	var bag := c.unused_cards()
	var cards: Array[DeckCard] = []
	var cost := 0
	while not bag.is_empty():
		var card: DeckCard = bag.pop_at(rng.randi_range(0, bag.size() - 1))
		if cost + card.data.cost > c.budget:
			continue
		if cards.is_empty() or rng.randf() < 0.5:
			cards.append(card)
			cost += card.data.cost
	c.start_encounter(cards)


func play_round(c: Campaign) -> void:
	if rng.randf() < FLEE_CHANCE:
		c.flee()
		return
	var alive := c.alive_players()
	if rng.randf() < TARGET_CHANCE:
		c.set_target(alive[rng.randi_range(0, alive.size() - 1)])
	for m in c.alive_monsters():
		if rng.randf() < ARM_CHANCE:
			c.arm_special(m)
	if not c.hand.is_empty() and rng.randf() < CARD_CHANCE:
		var card := c.hand[rng.randi_range(0, c.hand.size() - 1)]
		c.play_dm_card(card, alive[rng.randi_range(0, alive.size() - 1)])
	c.resolve_round()


func loot(c: Campaign) -> void:
	var alive: Array[PlayerState] = []
	for p in c.party:
		if p.alive:
			alive.append(p)
	c.give_loot(c.loot_offer[rng.randi_range(0, c.loot_offer.size() - 1)], alive[rng.randi_range(0, alive.size() - 1)])
