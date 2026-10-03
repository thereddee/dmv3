extends SceneTree
## Headless balance sim.
## Usage: godot --headless --script res://sim/run_sim.gd -- [--n=1000] [--seed=1] [--fixed-party]
## --fixed-party plays the v0 table from data/party instead of generated candidates.

const DEFAULT_RUNS := 1000
const DEFAULT_SEED := 1
## greedy-safe scoring within this share of greedy-risky means risk is not rewarded.
const RISK_REWARD_MARGIN := 0.15


func _init() -> void:
	var runs := DEFAULT_RUNS
	var base_seed := DEFAULT_SEED
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--n="):
			runs = int(arg.trim_prefix("--n="))
		elif arg.begins_with("--seed="):
			base_seed = int(arg.trim_prefix("--seed="))

	var content := ContentDB.load_default()
	if OS.get_cmdline_user_args().has("--fixed-party"):
		content.tuning = content.tuning.duplicate()
		content.tuning.party_candidates = 0
	var bots: Array[SimBot] = [RandomBot.new(), GreedySafeBot.new(), GreedyRiskyBot.new()]
	var results: Array[Dictionary] = []
	for bot in bots:
		results.append(_run_bot(content, bot, runs, base_seed))

	print("=== Sim: %d campaigns per bot, seeds %d..%d, %s party ===" % [runs, base_seed, base_seed + runs - 1,
		"generated" if content.tuning.party_candidates > 0 else "fixed"])
	_print_red_flags(results)
	for r in results:
		_print_result(content, r)
	quit()


func _run_bot(content: ContentDB, bot: SimBot, runs: int, base_seed: int) -> Dictionary:
	var scores: Array[int] = []
	var tpks := 0
	var skipped_midnight := 0
	var skipped_empty := 0
	# Per class: [seats played, alive at the end, satisfaction of those alive].
	var by_class: Dictionary[String, Array] = {}
	for key in content.classes:
		by_class[key] = [0, 0, 0]
	for i in runs:
		var c := Campaign.new(content, base_seed + i)
		bot.play(c)
		scores.append(0 if c.tpk else c.final_score())
		tpks += 1 if c.tpk else 0
		skipped_midnight += c.skipped_at_midnight
		skipped_empty += c.skipped_no_monsters
		for p in c.party:
			var tally := by_class[p.class_key]
			tally[0] += 1
			if p.alive:
				tally[1] += 1
				tally[2] += p.satisfaction
	scores.sort()
	return {
		"label": bot.label(),
		"runs": runs,
		"tpk_rate": float(tpks) / runs,
		"median": scores[floori(scores.size() / 2.0)],
		"mean": float(scores.reduce(func(a: int, b: int) -> int: return a + b, 0)) / runs,
		"skipped_midnight": float(skipped_midnight) / runs,
		"skipped_empty": float(skipped_empty) / runs,
		"by_class": by_class,
	}


func _print_red_flags(results: Array[Dictionary]) -> void:
	var flags := PackedStringArray()
	var safe := {}
	var risky := {}
	for r in results:
		if r["tpk_rate"] == 0.0:
			flags.append("%s never TPKs: the red line is unreachable." % r["label"])
		if r["label"] == "greedy-safe":
			safe = r
		elif r["label"] == "greedy-risky":
			risky = r
	var safe_median: int = safe["median"]
	var risky_median: int = risky["median"]
	if safe_median >= risky_median * (1.0 - RISK_REWARD_MARGIN):
		flags.append("greedy-safe median (%d) is within %d%% of greedy-risky (%d) or above: risk is not rewarded." % [
			safe_median, roundi(RISK_REWARD_MARGIN * 100), risky_median])
	print("--- RED FLAGS ---")
	if flags.is_empty():
		print("none")
	for f in flags:
		print("!! " + f)


func _print_result(content: ContentDB, r: Dictionary) -> void:
	var runs: int = r["runs"]
	print("--- %s ---" % r["label"])
	print("TPK rate: %.1f%%   median score: %d   mean score: %.0f" % [r["tpk_rate"] * 100.0, r["median"], r["mean"]])
	print("encounters skipped per campaign: %.2f at midnight, %.2f out of monsters" % [r["skipped_midnight"], r["skipped_empty"]])
	var by_class: Dictionary[String, Array] = r["by_class"]
	for key in by_class:
		var tally := by_class[key]
		var seats: int = tally[0]
		var alive: int = tally[1]
		var avg := float(tally[2]) / alive if alive > 0 else 0.0
		print("  %-14s satisfaction %5.1f (when alive at the end)   survives %5.1f%%   seats/campaign %.2f" % [
			content.classes[key].display_name, avg, 100.0 * alive / maxi(1, seats), float(seats) / runs])
