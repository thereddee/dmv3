class_name Recap
extends RefCounted
## Builds the end-of-campaign story from the Chronicle: a forum post written by
## one of the players about their DM. Deterministic: no dice involved.

const MANY_DEATHS := 3
const MANY_FLEES := 3
const MANY_PHONE := 3
const MANY_LOOT := 4
const HAPPY := 60
const BORED := 30


static func build(c: Campaign) -> String:
	var story := c.chronicle
	var average := _average_satisfaction(c)
	var lines := PackedStringArray()
	lines.append(_title(c, average))
	lines.append("")
	lines.append(_intro(c, average))

	var facts := PackedStringArray()
	for death in story.deaths:
		if death["killer"] == "":
			facts.append(Strings.RECAP_DEATH_POISON % [death["night"], death["name"]])
		else:
			facts.append(Strings.RECAP_DEATH % [death["night"], death["name"], death["killer"]])
	if not story.deaths.is_empty() and not c.tpk:
		facts.append(Strings.RECAP_REROLL)
	if story.fudges > 0:
		facts.append(Strings.RECAP_FUDGE % story.fudges)
	if story.flees > 0:
		facts.append(Strings.RECAP_FLEES % story.flees)
	if story.timeouts > 0:
		facts.append(Strings.RECAP_TIMEOUT % story.timeouts)
	if story.narrations > 0:
		facts.append(Strings.RECAP_NARRATION % story.narrations)
	if story.monologues > 0:
		facts.append(Strings.RECAP_MONOLOGUE % story.monologues)
	if story.skipped > 0:
		facts.append(Strings.RECAP_SKIPPED % story.skipped)
	var phone := story.top(story.phone_encounters)
	if phone != "" and story.phone_encounters[phone] >= MANY_PHONE:
		facts.append(Strings.RECAP_PHONE % [phone, story.phone_encounters[phone]])
	var spoiled := story.top(story.loot_received)
	if spoiled != "" and story.loot_received[spoiled] >= MANY_LOOT:
		facts.append(Strings.RECAP_LOOT % [spoiled, story.loot_received[spoiled]])
	if facts.is_empty():
		facts.append(Strings.RECAP_QUIET)
	for fact in facts:
		lines.append("• " + fact)

	lines.append("")
	if c.tpk:
		lines.append(Strings.RECAP_END_TPK)
	elif average >= HAPPY:
		lines.append(Strings.RECAP_END_GOOD)
	elif average >= BORED:
		lines.append(Strings.RECAP_END_MEH)
	else:
		lines.append(Strings.RECAP_END_BAD)
	lines.append(Strings.RECAP_TLDR % [c.alive_players().size(), average, 0 if c.tpk else c.final_score()])
	lines.append(Strings.RECAP_EDIT)
	return "\n".join(lines)


static func _title(c: Campaign, average: int) -> String:
	var story := c.chronicle
	if c.tpk:
		return Strings.RECAP_TITLE_TPK % mini(c.night, c.tuning.nights)
	if story.deaths.size() >= MANY_DEATHS:
		return Strings.RECAP_TITLE_DEATHS % story.deaths.size()
	if story.flees >= MANY_FLEES:
		return Strings.RECAP_TITLE_FLEES
	if average >= HAPPY:
		return Strings.RECAP_TITLE_GOOD
	if average < BORED:
		return Strings.RECAP_TITLE_BORING
	return Strings.RECAP_TITLE_MEH


static func _intro(c: Campaign, average: int) -> String:
	# The happiest player writes the good reviews, the grumpiest writes the rest.
	var narrator := c.party[0]
	for p in c.party:
		var better := p.satisfaction > narrator.satisfaction if average >= HAPPY else p.satisfaction < narrator.satisfaction
		if better:
			narrator = p
	var others := PackedStringArray()
	for p in c.party:
		if p != narrator:
			others.append(p.display_name)
	var class_label: String = c.content.classes[narrator.class_key].display_name
	return Strings.RECAP_INTRO % [narrator.display_name, class_label, ", ".join(others),
		mini(c.night, c.tuning.nights), c.chronicle.encounters]


static func _average_satisfaction(c: Campaign) -> int:
	var total := 0
	for p in c.party:
		total += p.satisfaction
	return roundi(float(total) / maxi(1, c.party.size()))
