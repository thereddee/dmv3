class_name TablePlayerPose
extends RefCounted
## Idle poses of the table players: a pure function of time, ported from animFor() in
## reference/table-des-joueurs.html. No keyframes are baked; everything is sin/ease on `t`.
## A pose maps a group key (TablePlayerBuilder.groups) to {tx, ty, r (degrees), sx, sy, op}.
## Missing fields mean "rest": no offset, no rotation, scale 1, opacity 1.

const SEAT_PHASE := 1.37
const SEAT_PHASE_WRAP := 3.0


static func pose_at(seat: int, a: PlayerAppearance, t: float, geo: Dictionary) -> Dictionary:
	var breath_period := 3.0 + seat * 0.35
	var blink_period := 4.2 + seat * 0.9
	var tt := t + fposmod(seat * SEAT_PHASE, SEAT_PHASE_WRAP)
	var pose := {}
	pose["breath"] = {"ty": 1.8 * (0.5 - 0.5 * cos(PI * tt / breath_period))}

	# head sway, reshaped by mood and by the cell phone
	var r := 1.8 * sin(PI * tt / (1.7 * breath_period))
	var hy := 0.0
	match a.mood:
		"fache":
			r = 1.2 * sin(TAU * tt / 0.9)
			hy = 0.3
		"blase":
			r = -2.5 + 1.5 * sin(PI * tt / 5.0)
			hy = 1.0 + sin(PI * tt / 5.0)
		"surpris":
			var q := _phase(tt, 2.6)
			hy = -5.0 * sin((q - 0.68) / 0.16 * PI) if q > 0.68 and q < 0.84 else 0.0
			r = hy * 0.4
		"concentre":
			var q := _phase(tt, 3.2)
			r = 3.0 * sin((q - 0.6) / 0.22 * PI) if q > 0.6 and q < 0.82 else 0.0
			hy = r * 0.6
	if a.prop == "cell":
		r = r * 0.4 + 3.0
		hy += 2.0
	pose["head"] = {"r": r, "ty": hy}
	var qb := _phase(tt, blink_period)
	pose["blink"] = {"sy": 0.12 if qb > 0.92 and qb < 0.97 else 1.0}

	# props that animate on their own
	var q_roll := _phase(tt, 3.4)
	var roll := sin((q_roll - 0.64) / 0.16 * PI * 3.0) if q_roll > 0.64 and q_roll < 0.8 else 0.0
	pose["roll"] = {"r": 35.0 * roll, "tx": 3.0 * roll, "ty": -absf(roll) * 5.0}
	var q_bounce := _phase(tt, 2.8)
	if q_bounce > 0.58:
		var s := minf(1.0, (q_bounce - 0.58) / 0.22)
		pose["bounce"] = {"tx": -13.0 * s, "ty": -10.0 * sin(s * PI) * (1.0 - s * 0.5), "r": -180.0 * s}
	var q_sip := _phase(tt, 6.0)
	var sip := sin((q_sip - 0.7) / 0.2 * PI) if q_sip > 0.7 and q_sip < 0.9 else 0.0
	pose["sip"] = {"ty": -14.0 * sip, "r": -12.0 * sip}
	pose["glow"] = {"op": 0.82 + 0.18 * roundf(1.0 + sin(PI * tt * 1.6)) / 2.0}
	pose["scribble"] = {"r": 4.0 * sin(TAU * tt / 0.7)}
	pose["float"] = {"ty": -1.0 - 4.0 * sin(PI * tt / 2.4)}
	pose["pulse"] = {"op": 0.85 + 0.15 * sin(PI * tt / 2.2)}
	pose["tail"] = {"r": 6.5 * sin(PI * tt / 2.6)}

	# hands: the left one drums when angry, otherwise they barely move
	if a.mood == "fache":
		pose["handL"] = {"ty": -absf(sin(TAU * tt * 2.2)) * 2.4}
	else:
		pose["handL"] = {"ty": 0.6 * sin(PI * tt / 2.3)}
	pose["handR"] = {"ty": 0.6 * sin(PI * tt / 2.7 + 1.0)}
	match a.prop:
		"cell":
			_cell(pose, tt)
		"chips":
			_chips(pose, tt, geo)
		"pile":
			_pile(pose, tt, geo)
	return pose


## The thumb swipes up and the feed scrolls one row.
static func _cell(pose: Dictionary, tt: float) -> void:
	var period := 1.5
	var q := _phase(tt, period)
	var n := floorf(tt / period)
	var up := _ease(q / 0.25) if q < 0.25 else (1.0 - (q - 0.25) / 0.15 if q < 0.4 else 0.0)
	pose["thumb"] = {"ty": -9.0 * up, "tx": -1.0 * up}
	pose["feed"] = {"ty": -fposmod((n + (_ease(q / 0.25) if q < 0.25 else 1.0)) * 9.0, 27.0)}
	var hold := 1.2 * sin(PI * tt / 1.3)
	pose["phone"] = {"ty": hold, "r": -3.0}
	pose["handR"] = {"ty": hold}


## The hand dips into the bag, goes up to the mouth with a chip, then comes back.
static func _chips(pose: Dictionary, tt: float, geo: Dictionary) -> void:
	var q := _phase(tt, 4.6)
	var bag := Vector2(100.0 - geo.hxr, -8.0)
	var mouth := Vector2(100.0 - geo.hxr + 4.0, (108.0 + geo.dy) - 208.0 + 6.0)
	var pos := Vector2.ZERO
	var chip := 0.0
	if q >= 0.3 and q < 0.42:
		pos = Vector2.ZERO.lerp(bag, _ease((q - 0.3) / 0.12))
	elif q >= 0.42 and q < 0.62:
		pos = bag.lerp(mouth, _ease((q - 0.42) / 0.2))
		chip = 1.0
	elif q >= 0.62 and q < 0.72:
		pos = mouth + Vector2(0.0, sin((q - 0.62) * 80.0) * 1.2)
		chip = 1.0 if q < 0.66 else 0.0
	elif q >= 0.72 and q < 0.9:
		pos = mouth.lerp(Vector2.ZERO, _ease((q - 0.72) / 0.18))
	pose["handR"] = {"tx": pos.x, "ty": pos.y, "r": -10.0 if pos.x != 0.0 else 0.0}
	pose["chip"] = {"op": chip}


## Six dice are stacked one by one, the tower wobbles, then collapses.
static func _pile(pose: Dictionary, tt: float, geo: Dictionary) -> void:
	var stack_x := TablePlayerBuilder.STACK_X
	var period := 8.4
	var c := _phase(tt, period) * period
	for k in 6:
		pose["die%d" % k] = {"op": 1.0 if c >= k * 0.9 + 0.45 and c < 7.8 else 0.0}
	pose["held"] = {"op": 0.0}
	if c < 5.4:
		var j := floorf(c / 0.9)
		var u := (c - j * 0.9) / 0.9
		var tx: float = stack_x - geo.hxr + 1.0
		var ty := (216.0 - 11.0 * (j + 1.0)) - 208.0 + 8.0
		var s := _ease(u / 0.5) if u < 0.5 else 1.0 - _ease((u - 0.5) / 0.5)
		pose["handR"] = {"tx": tx * s, "ty": ty * s - 8.0 * sin(s * PI), "r": -8.0 * s}
		pose["held"] = {"op": 1.0 if u < 0.5 else 0.0}
	if c >= 5.4 and c < 6.6:
		var s := (c - 5.4) / 1.2
		pose["stack"] = {"r": (1.5 + 5.0 * s) * sin((c - 5.4) * 16.0)}
	if c >= 6.6 and c < 7.8:
		var s := clampf((c - 6.6) / 0.55, 0.0, 1.0)
		for k in 6:
			var dir := 1.0 if k % 2 == 1 else -1.0
			var die: Dictionary = pose["die%d" % k]
			die["tx"] = dir * (6.0 + k * 5.0) * s
			die["ty"] = 11.0 * k * s - 6.0 * sin(s * PI)
			die["r"] = dir * (80.0 + k * 20.0) * s
		pose["stack"] = {"r": 6.0 * (1.0 - s)}


## Position in [0, 1) within a repeating period.
static func _phase(tt: float, period: float) -> float:
	return fposmod(tt, period) / period


static func _ease(s: float) -> float:
	return 2.0 * s * s if s < 0.5 else 1.0 - 2.0 * (1.0 - s) * (1.0 - s)