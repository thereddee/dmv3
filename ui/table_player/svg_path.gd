class_name SvgPath
extends RefCounted
## Minimal SVG path reader: absolute M, L, Q and Z only, which is all the table players use.
## Lets the shapes in reference/table-des-joueurs.html be ported as the same path strings.

const CURVE_STEPS := 8

static var _tokens: RegEx = RegEx.create_from_string("[MLQZ]|-?\\d*\\.?\\d+(?:e-?\\d+)?")


## Returns one {"pts": PackedVector2Array, "closed": bool} per subpath. Curves are flattened.
static func parse(d: String) -> Array[Dictionary]:
	var subpaths: Array[Dictionary] = []
	var pts := PackedVector2Array()
	var closed := false
	var cmd := ""
	var nums: Array[float] = []
	var tokens: Array[String] = []
	for m in _tokens.search_all(d):
		tokens.append(m.get_string())
	tokens.append("")  # sentinel flushes the last command
	for token in tokens:
		if token != "" and not token in ["M", "L", "Q", "Z"]:
			nums.append(token.to_float())
			continue
		match cmd:
			"M":
				if pts.size() > 0:
					subpaths.append({"pts": pts, "closed": closed})
				pts = PackedVector2Array()
				closed = false
				_line_to(pts, nums)
			"L":
				_line_to(pts, nums)
			"Q":
				_curve_to(pts, nums)
			"Z":
				closed = true
		nums = []
		cmd = token
	if pts.size() > 0:
		subpaths.append({"pts": pts, "closed": closed})
	return subpaths


static func _line_to(pts: PackedVector2Array, nums: Array[float]) -> void:
	for i in range(0, nums.size() - 1, 2):
		pts.append(Vector2(nums[i], nums[i + 1]))


static func _curve_to(pts: PackedVector2Array, nums: Array[float]) -> void:
	for i in range(0, nums.size() - 3, 4):
		var from: Vector2 = pts[pts.size() - 1] if pts.size() > 0 else Vector2.ZERO
		var control := Vector2(nums[i], nums[i + 1])
		var to := Vector2(nums[i + 2], nums[i + 3])
		for s in range(1, CURVE_STEPS + 1):
			var t := float(s) / CURVE_STEPS
			pts.append(from.lerp(control, t).lerp(control.lerp(to, t), t))