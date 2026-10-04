class_name TablePlayerBuilder
extends RefCounted
## Draws one table player as a stack of PlayerLayer nodes, in the paint order of buildPlayer()
## in reference/table-des-joueurs.html (cel-shading look). Shapes keep the reference's coordinates:
## a figure is 200 wide, x = 100 is the centre line, the table edge sits at y = 192.
## Path strings are ported as-is; "{expr}" stands for the JS "${expr}" (see _d).
## Each G() animation group of the reference becomes a PlayerLayer in `groups`, positioned at its
## pivot, so animFor poses are plain Node2D transforms.

const INK := Color("#17151c")
const STROKE := 3.2
const FW := 2.4
const SHADE_OP := 0.22
const HI_OP := 0.14
const SHADE_DARKEN := 0.24
const HIGHLIGHT_LIGHTEN := 0.32
const FOLD_MIX := 0.35
const PLAID_CELL := 18
const PLAID_TEXELS := 4
const ELLIPSE_STEPS := 28
const CORNER_STEPS := 4
const STACK_X := 86.0
const BUILD_WIDTH := {"mince": 0.84, "moyen": 1.0, "large": 1.22}
const RACE_WIDTH := {"nain": 1.15, "orc": 1.14, "halfelin": 0.92, "gnome": 0.88}
## How far smaller races sink behind the table.
const RACE_DROP := {"nain": 12.0, "halfelin": 22.0, "gnome": 26.0}

const TUNIC := Color("#4a4038")
const STEEL := Color("#9aa3ad")
const ROBE := Color("#3b3a8a")
const GOLD := Color("#d9a93a")
const LEATHER := Color("#6b4428")
const CREAM := Color("#f0ece2")
const GREEN := Color("#3f5f3a")
const HOOD := Color("#2e2b38")
const DARK := Color("#262233")
const LENS := Color(0.745, 0.863, 1.0, 0.28)

static var _exprs: Dictionary = {}
static var _plaids: Dictionary = {}
static var _leading_dot: RegEx = RegEx.create_from_string("(?<![\\d])\\.(\\d)")

## Animation groups by key (the G() keys of the reference), for pose_at().
var groups: Dictionary = {}
var geo: Dictionary = {}
## Multiplies every outline and line width; Pixel mode thickens strokes so they survive the downscale.
var stroke_mult := 1.0

var _p: PlayerAppearance
var _skin: Color
var _skin_s: Color
var _hc: Color
var _hc_s: Color
var _tc: Color
var _ac: Color
var _torso_base: Color
var _cuff_fill: Color
var _cuff_o: Dictionary = {}
var _cuff_base: Color
var _vars: Dictionary = {}
var _root: Node2D
var _origin := Vector2.ZERO
var _seg: PlayerLayer
var _next_name := "Layer"
var _stack: Array = []


static func geo_of(a: PlayerAppearance) -> Dictionary:
	var w: float = BUILD_WIDTH[a.build] * RACE_WIDTH.get(a.race, 1.0)
	return {"w": w, "dy": RACE_DROP.get(a.race, 0.0), "hxl": 100.0 - 44.0 * w, "hxr": 100.0 + 44.0 * w}


## `back` holds everything behind the table (sinks by geo.dy); `front` the hands and the prop.
func build(a: PlayerAppearance, back: Node2D, front: Node2D) -> void:
	_p = a
	geo = geo_of(a)
	var w: float = geo.w
	_vars = {"w": w, "Lx": 100.0 - 46.0 * w, "Rx": 100.0 + 46.0 * w, "L2": 100.0 - 58.0 * w,
			"R2": 100.0 + 58.0 * w, "hxL": geo.hxl, "hxR": geo.hxr}
	_skin = a.skin
	_skin_s = _shade(a.skin)
	_hc = a.hair_color
	_hc_s = _shade(a.hair_color)
	_tc = a.top_color
	_ac = a.acc
	_torso_base = _torso_base_color()
	back.position = Vector2(0.0, geo.dy)
	_begin(back)
	group("breath", Vector2.ZERO)
	_build_back()
	end_group()
	_begin(front)
	_build_front()


# ---------------------------------------------------------------- back of the table

func _torso_base_color() -> Color:
	if _p.cls == "magicien":
		return ROBE
	if _p.top == "cape":
		return TUNIC
	return _p.top_color


func _build_back() -> void:
	var p := _p
	var w: float = geo.w
	var is_drake := p.race == "drakeide"
	var hooded := p.cls == "roublard"
	var show_top := p.cls != "magicien"
	var torso_o := {}
	var torso_fill := _tc
	if p.cls == "magicien":
		torso_fill = ROBE
	elif p.top == "carreaux":
		torso_fill = Color.WHITE
		torso_o = {"tex": _plaid(p.top_color)}
	elif p.top == "cape":
		torso_fill = TUNIC
	_cuff_fill = torso_fill
	_cuff_o = torso_o
	_cuff_base = _torso_base

	# behind the body
	if p.cls == "rodeur":
		layer("Quiver")
		var quiver := group("", Vector2(100.0 + 40.0 * w, 120.0))
		quiver.rotation_degrees = 24.0
		rect(100.0 + 32.0 * w, 82, 16, 52, 3, LEATHER)
		ln("M{100+34*w},96 L{100+46*w},96", _shade(LEATHER), 2.0)
		for k in 3:
			poly("M{100+34*w+k*5},84 L{100+36*w+k*5},68 L{100+38*w+k*5},84Z",
					Color("#c23b3b") if k == 1 else CREAM, {"w": 0.5}, {"k": k})
		end_group()
	if hooded:
		layer("HoodBack")
		poly("M58,100 Q54,28 100,24 Q146,28 142,100 L152,152 Q100,162 48,152Z", HOOD)
	if not is_drake and not hooded:
		layer("BackHair")
		_back_hair()
	if show_top and p.top == "cape":
		layer("Cape")
		poly("M{L2-14},252 L{L2-8},182 Q{100-50*w},136 100,134 Q{100+50*w},136 {R2+8},182 L{R2+14},252Z", _tc)
		ln("M{L2-6},200 L{L2-10},250", _fold(p.top_color), 1.4)
		ln("M{R2+6},200 L{R2+10},250", _fold(p.top_color), 1.4)

	# torso, neck, arms
	layer("Torso")
	poly("M{L2},252 L{L2},200 Q{Lx},150 {100-24*w},140 L{100+24*w},140 Q{Rx},150 {R2},200 L{R2},252Z", torso_fill, torso_o)
	poly("M{100+28*w},146 Q{Rx},152 {R2},200 L{R2},252 L{100+38*w},252 Q{100+42*w},190 {100+28*w},146Z",
			Color("#1a1030"), {"ns": true, "op": SHADE_OP})
	poly("M{L2+3},198 Q{Lx+2},154 {100-24*w},144 Q{Lx+12},162 {L2+12},198Z", Color.WHITE, {"ns": true, "op": HI_OP})
	if show_top and p.top == "hoodie":
		ell(100, 141, 34, 12, _shade(p.top_color))
		ln("M72,141 Q100,152 128,141", _fold(p.top_color), 1.2)
	if p.cls == "magicien":
		poly("M78,146 Q58,116 64,82 Q78,112 96,140Z", ROBE)
		poly("M122,146 Q142,116 136,82 Q122,112 104,140Z", ROBE)
		ln("M68,90 Q74,116 90,140", GOLD, 2.0)
		ln("M132,90 Q126,116 110,140", GOLD, 2.0)
	rect(89, 100, 22, 46, 4, _skin)
	poly("M89,118 Q100,130 111,118 L111,128 Q100,136 89,128Z", _skin_s, {"ns": true})
	# arm creases separate the arms from the torso block
	var crease := _fold(_torso_base)
	ln("M{100-31*w},164 Q{100-35*w},204 {100-34*w},252", crease, FW * 0.8)
	ln("M{100+31*w},164 Q{100+35*w},204 {100+34*w},252", crease, FW * 0.8)
	ln("M{100-46*w},214 Q{100-50*w},224 {100-47*w},236", crease, 1.3)
	ln("M{100+44*w},208 Q{100+48*w},220 {100+45*w},232", crease, 1.3)
	ln("M{100-12*w},226 Q{100-4*w},232 {100+6*w},228", crease, 1.2)
	if show_top:
		layer("Top")
		_top_details()

	layer("ClassCostume")
	_class_costume()

	# race traits behind the head
	layer("RaceBack")
	if is_drake:
		var horn := Color("#e8dcc0")
		poly("M78,60 Q64,36 54,28 Q68,46 86,56Z", horn)
		poly("M122,60 Q136,36 146,28 Q132,46 114,56Z", horn)
		ln("M66,44 L70,48", _shade(horn), 1.4)
		ln("M134,44 L130,48", _shade(horn), 1.4)
	if p.race == "tieffelin":
		group("tail", Vector2(100.0 + 52.0 * w, 210.0))
		band("M{100+52*w},210 Q{100+70*w},150 {100+50*w},126 Q{100+44*w},116 {100+52*w},106", p.skin, 6.0)
		poly("M{100+52*w},106 L{100+44*w},96 L{100+58*w},96Z", _skin)
		end_group()

	group("head", Vector2(100, 126))
	_build_head()
	end_group()
	if p.cls == "magicien":
		layer("Orb")
		group("float", Vector2.ZERO)
		circ(160, 132, 16, Color("#8fe1ff"), {"ns": true, "op": 0.25})
		circ(160, 132, 9, Color("#8fe1ff"))
		poly("M155,128 Q160,124 165,128", Color.WHITE, {"ns": true, "op": 0.8})
		circ(157, 129, 2.4, Color.WHITE, {"ns": true})
		end_group()


func _back_hair() -> void:
	match _p.hair:
		"long":
			poly("M63,82 Q58,36 100,36 Q142,36 137,82 L142,152 L134,146 L128,160 L118,150 L108,162 L100,152 L92,162 L82,150 L72,160 L66,146 L58,152Z", _hc)
			ln("M70,110 L68,146", _hc_s, 1.6)
			ln("M130,110 L132,146", _hc_s, 1.6)
		"chignon":
			circ(100, 38, 15, _hc)
			ln("M90,34 Q100,28 110,36", _hc_s, 1.6)
			ln("M92,44 Q100,48 108,42", _hc_s, 1.6)
		"queue":
			poly("M116,50 Q154,46 150,96 Q150,118 144,132 L140,124 L138,142 Q132,110 122,80Z", _hc)
			ln("M128,62 Q144,80 140,118", _hc_s, 1.6)
		"boucles":
			for c in [[70, 74, 15], [76, 54, 16], [92, 42, 16], [110, 42, 16], [124, 54, 16],
					[130, 74, 15], [68, 96, 12], [132, 96, 12], [72, 114, 10], [128, 114, 10]]:
				circ(c[0], c[1], c[2], _hc)

func _top_details() -> void:
	var p := _p
	var w: float = geo.w
	match p.top:
		"hoodie":
			ln("M92,150 L90,178", CREAM, 2.6)
			ln("M108,150 L110,178", CREAM, 2.6)
			circ(90, 180, 2, CREAM, {"ns": true})
			circ(110, 180, 2, CREAM, {"ns": true})
			poly("M{100-22*w},214 L{100+22*w},214 L{100+26*w},240 L{100-26*w},240Z", _shade(p.top_color), {"w": 0.6})
		"tshirt":
			ln("M86,141 Q100,156 114,141")
			var hexagon := PackedVector2Array()
			for k in 6:
				var a := PI / 3.0 * k - PI / 2.0
				hexagon.append(Vector2(100.0 + 14.0 * cos(a), 186.0 + 14.0 * sin(a)))
			poly_pts(hexagon, Color("#f2efe8"), {"w": 0.6})
			ln_pts(PackedVector2Array([hexagon[0], hexagon[2], hexagon[4]]), INK, 1.4, true)
			text("20", Vector2(100, 190), 7, Color("#c23b3b"))
		"carreaux":
			var collar := p.top_color.lerp(Color.WHITE, 0.25)
			poly("M84,140 L100,156 L92,166 L80,146Z", collar)
			poly("M116,140 L100,156 L108,166 L120,146Z", collar)
			ln("M100,158 L100,252", _fold(p.top_color), 1.2)
			for y in [176, 198, 220]:
				circ(100, y, 2.2, CREAM, {"ns": true})
			rect(100.0 - 30.0 * w, 172, 16, 14, 2, Color.BLACK, {"ns": true, "op": 0.15})
		"cardigan":
			poly("M86,141 L100,180 L114,141Z", CREAM)
			ln("M100,180 L100,252", INK, 2.0)
			for y in [194, 214, 234]:
				circ(95, y, 2.4, _ac, {"ns": true})
			ln("M{100-28*w},150 L{100-26*w},252", _fold(p.top_color), 1.0)
			ln("M{100+28*w},150 L{100+26*w},252", _fold(p.top_color), 1.0)
		"cape":
			poly("M{100-30*w},142 Q100,160 {100+30*w},142 Q100,150 {100-30*w},142Z", _shade(p.top_color))
			circ(100, 150, 6, GOLD)
			circ(98, 148, 1.8, Color.WHITE, {"ns": true, "op": 0.7})


func _class_costume() -> void:
	var p := _p
	var w: float = geo.w
	var steel_s := _shade(STEEL)
	match p.cls:
		"guerrier":
			poly("M{100-34*w},162 Q100,150 {100+34*w},162 L{100+38*w},252 L{100-38*w},252Z", STEEL)
			poly("M{100+12*w},158 Q{100+34*w},160 {100+38*w},252 L{100+24*w},252 Q{100+22*w},200 {100+12*w},158Z",
					Color("#1a1030"), {"ns": true, "op": SHADE_OP})
			poly("M{100-28*w},166 Q{100-16*w},160 {100-8*w},162 L{100-12*w},200 Q{100-24*w},190 {100-28*w},166Z",
					Color.WHITE, {"ns": true, "op": 0.3})
			ln("M100,156 L100,252", steel_s, 2.4)
			ln("M{100-36*w},206 Q100,214 {100+36*w},206", steel_s, 1.6)
			for q in [[-24, 178], [24, 178], [-26, 212], [26, 212]]:
				circ(100.0 + q[0] * w, q[1], 2.2, steel_s, {"ns": true})
			poly("M84,136 Q100,148 116,136 L119,150 Q100,162 81,150Z", steel_s)
			var pw := minf(w, 1.05)
			for s in [-1, 1]:
				ell(100.0 + s * 44.0 * w, 156, 17.0 * pw, 13, STEEL)
				ell(100.0 + s * 44.0 * w - 4.0 * s, 151, 7.0 * pw, 3.6, Color.WHITE, {"ns": true, "op": 0.35})
				ln("M{100+s*62*w},162 Q{100+s*46*w},150 {100+s*30*w},162", steel_s, 2.2, {"s": s})
				ln("M{100+s*60*w},167 Q{100+s*46*w},158 {100+s*32*w},167", steel_s, 1.4, {"s": s})
		"clerc":
			poly("M{100-24*w},148 L{100+24*w},148 L{100+22*w},252 L{100-22*w},252Z", CREAM)
			ln("M{100-19*w},152 L{100-17*w},252", GOLD, 2.4)
			ln("M{100+19*w},152 L{100+17*w},252", GOLD, 2.4)
			ln("M{100+8*w},210 Q{100+12*w},230 {100+9*w},250", _shade(CREAM), 1.2)
			group("pulse", Vector2.ZERO)
			for k in 8:
				var a := PI / 4.0 * k
				ln_pts(PackedVector2Array([Vector2(100.0 + 11.0 * cos(a), 186.0 + 11.0 * sin(a)),
						Vector2(100.0 + 16.0 * cos(a), 186.0 + 16.0 * sin(a))]), GOLD, 2.4)
			circ(100, 186, 8, GOLD)
			circ(100, 186, 3.5, Color("#fff3c4"), {"ns": true})
			end_group()
		"roublard":
			band("M{100-40*w},152 L{100+34*w},244", LEATHER, 5.0)
			rect(100.0 + 2.0 * w, 192, 10, 8, 1, GOLD)
			for k in 3:
				rect(100.0 - 16.0 * w + k * 8.0 * w, 170 + k * 16, 5, 9, 1, STEEL, {"w": 0.5})
			poly("M83,128 Q100,142 117,128 L121,148 Q100,160 79,148Z", _ac)
			ln("M88,140 Q100,148 112,140", _shade(p.acc), 1.2)
		"rodeur":
			poly("M{L2-4},206 Q{Lx-6},150 {100-22*w},138 Q100,150 {100+22*w},138 Q{Rx+6},150 {R2+4},206 L{R2-10},210 Q{Rx-6},166 {100+18*w},152 Q100,160 {100-18*w},152 Q{Lx+6},166 {L2+10},210Z", GREEN)
			ln("M{100-40*w},170 Q{100-44*w},186 {100-42*w},200", _shade(GREEN), 1.4)
			ln("M{100+40*w},170 Q{100+44*w},186 {100+42*w},200", _shade(GREEN), 1.4)
			band("M{100-30*w},156 L{100+40*w},240", LEATHER, 4.0)
			circ(100.0 + 2.0 * w, 194, 3.5, GOLD)
		"magicien":
			ln("M86,142 L100,176 L114,142", GOLD, 3.0)
			for st in [[100.0 - 30.0 * w, 200.0, 1.0], [100.0 + 28.0 * w, 222.0, 1.0],
					[100.0 - 18.0 * w, 236.0, 0.7], [100.0 + 14.0 * w, 192.0, 0.6]]:
				poly("M{x},{y-6*s} L{x+1.6*s},{y-1.6*s} L{x+6*s},{y} L{x+1.6*s},{y+1.6*s} L{x},{y+6*s} L{x-1.6*s},{y+1.6*s} L{x-6*s},{y} L{x-1.6*s},{y-1.6*s}Z",
						GOLD, {"ns": true}, {"x": st[0], "y": st[1], "s": st[2]})
			circ(100.0 + 34.0 * w, 200, 1.6, GOLD, {"ns": true})
			circ(100.0 - 8.0 * w, 214, 1.4, GOLD, {"ns": true})
		"barde":
			band("M{100-34*w},250 L150,126", Color("#a8743f"), 6.0)
			poly("M146,130 L156,112 L163,116 L153,134Z", Color("#7a5236"))
			for k in 3:
				circ(152 + k * 3, 116 + k * 5, 1.6, GOLD, {"ns": true})
			ln("M{100-33*w},248 L149,128", CREAM, 0.8)
			for k in range(-3, 4):
				circ(100 + k * 7, 142.0 + absf(k) * 0.6, 6, CREAM)
			poly("M{100+20*w},200 Q{100+30*w},196 {100+34*w},206 L{100+24*w},214Z", _ac, {"w": 0.6})

# ---------------------------------------------------------------- head

func _build_head() -> void:
	var p := _p
	var is_drake := p.race == "drakeide"
	var hooded := p.cls == "roublard"
	var special := p.race == "tieffelin" or is_drake
	var es := 1.15 if p.race == "gnome" else 1.0

	layer("HeadShape")
	var pointy: String = {"elfe": "long", "orc": "court", "tieffelin": "court", "gnome": "court", "halfelin": "court"}.get(p.race, "")
	if not is_drake:
		if pointy == "long":
			poly("M72,84 Q58,70 46,58 Q58,86 72,98Z", _skin)
			ln("M68,86 Q58,74 52,66", _skin_s, 1.4)
			poly("M128,84 Q142,70 154,58 Q142,86 128,98Z", _skin)
			ln("M132,86 Q142,74 148,66", _skin_s, 1.4)
		elif pointy == "court":
			poly("M72,84 Q62,78 58,68 Q60,90 72,98Z", _skin)
			ln("M68,86 Q63,80 62,74", _skin_s, 1.4)
			poly("M128,84 Q138,78 142,68 Q140,90 128,98Z", _skin)
			ln("M132,86 Q137,80 138,74", _skin_s, 1.4)
		else:
			ell(70, 90, 7, 9, _skin)
			ln("M71,86 Q67,90 71,95", _skin_s, 1.6)
			ell(130, 90, 7, 9, _skin)
			ln("M129,86 Q133,90 129,95", _skin_s, 1.6)
		poly("M70,82 Q70,50 100,50 Q130,50 130,82 Q130,112 112,121 Q100,126 88,121 Q70,112 70,82Z", _skin)
	else:
		poly("M72,92 L60,98 L72,104Z", _skin_s)
		poly("M128,92 L140,98 L128,104Z", _skin_s)
		poly("M72,88 Q68,52 100,50 Q132,52 128,88 Q129,104 121,112 L119,122 Q100,132 81,122 L79,112 Q71,104 72,88Z", _skin)
		poly("M84,112 Q100,120 116,112 L117,121 Q100,130 83,121Z", p.skin.lerp(Color("#f2e2b8"), 0.55), {"ns": true})
	poly("M116,56 Q131,68 129,90 Q126,112 106,123 Q122,104 121,82 Q120,66 116,56Z", _skin_s, {"ns": true})
	poly("M76,64 Q80,54 92,52 Q82,58 80,70Z", Color.WHITE, {"ns": true, "op": HI_OP})

	layer("FacialHair")
	if not is_drake:
		_facial_hair()
	else:
		ln("M90,62 Q95,67 100,62 Q105,67 110,62", _skin_s, 1.8)
		ln("M94,70 Q100,74 106,70", _skin_s, 1.6)
		ln("M78,96 Q82,100 80,106", _skin_s, 1.3)
		ln("M122,96 Q118,100 120,106", _skin_s, 1.3)

	# eyes: white, iris, pupil, glints and a thick BD lid
	var m := p.mood
	var h: float = {"content": 0.95, "concentre": 0.62, "blase": 0.48, "fache": 0.78, "surpris": 1.25}[m]
	var brow_color := _skin_s if (is_drake or p.hair == "chauve") else p.hair_color.lerp(Color.BLACK, 0.35)
	var ey := 86.0
	layer("Eyes")
	group("blink", Vector2(100, ey))
	for x in [88.0, 112.0]:
		_eye(x, ey, es, h, special, m)
	end_group()

	layer("Face")
	var br: Array = {"content": [75, 74], "concentre": [78, 74], "blase": [78, 78], "fache": [81, 71], "surpris": [69, 71]}[m]
	_brow(95, br[0], 79, br[1], brow_color)
	_brow(105, br[0], 121, br[1], brow_color)
	var mouth_in := Color("#5a2230")
	var tongue := Color("#d9667a")
	match m:
		"content":
			poly("M90,104 Q100,105 110,104 Q107,114 100,115 Q93,114 90,104Z", mouth_in, {"w": 0.5})
			poly("M92,104.6 Q100,105.6 108,104.6 L107,107 Q100,108 93,107Z", Color.WHITE, {"ns": true})
			ell(100, 112, 4, 2, tongue, {"ns": true})
		"concentre":
			ln("M93,108 Q100,106 107,107", INK, FW * 0.8)
			ell(105, 109.6, 2.4, 2, tongue, {"w": 0.4})
		"blase":
			ln("M93,109 Q100,107.5 107,110", INK, FW * 0.8)
			ln("M84,92 Q88,94 92,92", _skin_s, 1.0)
			ln("M108,92 Q112,94 116,92", _skin_s, 1.0)
		"fache":
			poly("M90,109 Q100,103 110,109 L108,114 Q100,111 92,114Z", Color.WHITE, {"w": 0.6})
			ln("M96,106 L96,112.5", _shade(Color.WHITE), 0.8)
			ln("M100,105 L100,111.5", _shade(Color.WHITE), 0.8)
			ln("M104,106 L104,112.5", _shade(Color.WHITE), 0.8)
		"surpris":
			ell(100, 110, 4.2, 5.8, mouth_in, {"w": 0.6})
			ell(100, 113, 2.4, 1.4, tongue, {"ns": true})
	if m == "content" or m == "surpris":
		ell(80, 99, 5, 2.6, Color("#ff6f86"), {"ns": true, "op": 0.32})
		ell(120, 99, 5, 2.6, Color("#ff6f86"), {"ns": true, "op": 0.32})
	if m == "fache":
		ln("M122,64 L126,60 M124,66 L130,64", Color("#c23b3b"), 1.6)

	layer("Nose")
	if is_drake:
		ell(94, 99, 2, 1.3, INK, {"ns": true})
		ell(106, 99, 2, 1.3, INK, {"ns": true})
	elif p.race == "gnome":
		ell(100, 96, 8, 7, p.skin.lerp(Color("#e07a6a"), 0.35))
		circ(97, 93, 2, Color.WHITE, {"ns": true, "op": 0.5})
	elif p.race == "nain":
		ell(100, 95, 6, 5.5, _skin)
		ell(103, 96, 3, 3, _skin_s, {"ns": true})
	else:
		poly("M100,90 Q97,96 99,99 Q102,100 104,98 Q101,98 100,96Z", _skin_s, {"ns": true})
		ln("M100,91 Q98,96 100,98.5", INK, FW * 0.6)
	if p.race == "orc":
		poly("M80,74 Q100,68 120,74 Q100,72 80,74Z", _skin_s, {"ns": true, "op": 0.9})
		poly("M91,111 L89,100 L95,108Z", CREAM, {"w": 0.5})
		poly("M109,111 L111,100 L105,108Z", CREAM, {"w": 0.5})

	layer("HairFront")
	if not is_drake:
		_front_hair(hooded)
	if p.race == "tieffelin":
		layer("Horns")
		var horn := Color("#3a2a35")
		poly("M80,58 Q68,30 84,14 Q80,34 91,54Z", horn)
		poly("M120,58 Q132,30 116,14 Q120,34 109,54Z", horn)
		var horn_hi := horn.lerp(Color.WHITE, HIGHLIGHT_LIGHTEN)
		ln("M78,46 L84,44 M78,38 L82,36", horn_hi, 1.2)
		ln("M122,46 L116,44 M122,38 L118,36", horn_hi, 1.2)

	layer("Glasses")
	_glasses(es)

	layer("Hat")
	if hooded:
		poly("M58,100 Q54,28 100,24 Q146,28 142,100 L136,124 Q134,66 100,58 Q66,66 64,124Z", HOOD)
		ln("M70,110 Q68,70 100,64 Q132,70 130,110", _shade(HOOD), 2.0)
		ln("M100,26 Q104,40 100,58", _shade(HOOD), 1.4)
	else:
		_hat()


func _eye(x: float, ey: float, es: float, h: float, special: bool, m: String) -> void:
	var rx := 6.4 * es
	var ry := 4.8 * h * es
	var ir := (2.6 if m == "surpris" else 3.7) * es
	if special:
		ell(x, ey, rx, ry, Color("#f5c542"), {"ns": true})
		ell(x, ey, 1.1 * es, minf(ry, 4.4 * es), Color("#1a0d10"), {"ns": true})
		circ(x + 1.8 * es, ey - 1.2 * es, 1.0 * es, Color.WHITE, {"ns": true})
	else:
		ell(x, ey, rx, ry, Color.WHITE, {"ns": true})
		ell(x + 0.4, ey + 0.4 * h, ir, minf(ir * 1.15, ry), _p.eyes, {"ns": true})
		ell(x + 0.4, ey + 0.6 * h, ir * 0.48, minf(ir * 0.58, ry * 0.7), Color("#120c14"), {"ns": true})
		circ(x + 1.9 * es, ey - 1.3 * es * h, 1.25 * es, Color.WHITE, {"ns": true})
		circ(x - 1.4 * es, ey + 1.6 * es * h, 0.6 * es, Color.WHITE, {"ns": true, "op": 0.8})
	var v := {"x": x, "rx": rx, "ry": ry, "ey": ey, "es": es}
	ln("M{x-rx-1},{ey+.5} Q{x},{ey-ry*1.6} {x+rx+1},{ey-.5}", INK, FW * 1.35, v)
	if x < 100.0:
		ln("M{x-rx-1},{ey+.5} L{x-rx-3},{ey-1.6}", INK, FW * 0.9, v)
	else:
		ln("M{x+rx+1},{ey-.5} L{x+rx+3},{ey-2.2}", INK, FW * 0.9, v)
	ln("M{x-3.5*es},{ey+ry+1.2} Q{x},{ey+ry+2} {x+3.5*es},{ey+ry+1.2}", _skin_s, 1.1, v)


func _brow(x_in: float, y_in: float, x_out: float, y_out: float, color: Color) -> void:
	var top := minf(y_in, y_out)
	poly("M{xi},{yi} Q{xm},{t1} {xo},{yo} Q{xm},{t2} {xi},{yi2}Z", color, {"ns": true},
			{"xi": x_in, "yi": y_in, "xo": x_out, "yo": y_out, "xm": (x_in + x_out) / 2.0,
			"t1": top - 3.2, "t2": top - 0.6, "yi2": y_in + 2.6})


func _facial_hair() -> void:
	match _p.facial:
		"trois":
			poly("M72,90 Q72,112 88,121 Q100,126 112,121 Q128,112 128,90 Q122,108 110,108 Q100,104 90,108 Q78,108 72,90Z",
					_hc, {"ns": true, "op": 0.38})
		"barbe":
			_beard_base()
			ln("M100,118 L100,132", _hc_s, 1.4)
		"moustache":
			poly("M86,103 Q94,96 100,100 Q106,96 114,103 Q110,108 104,105 Q100,103 96,105 Q90,108 86,103Z", _hc)
		"tresse":
			_beard_base()
			_braid(100, 132, 160, 0)
			_stache()
		"fourche":
			_beard_base()
			_braid(91, 128, 154, -4)
			_braid(109, 128, 154, 4)
			_stache()
		"longue":
			poly("M70,86 Q66,130 82,152 L86,146 L90,162 L96,150 L100,166 L104,150 L110,162 L114,146 L118,152 Q134,130 130,86 Q124,108 112,110 Q100,104 88,110 Q76,108 70,86Z", _hc)
			for d in ["M82,116 Q86,136 90,152", "M94,118 Q96,138 96,154", "M106,118 Q104,138 104,154", "M118,116 Q114,136 110,152"]:
				ln(d, _hc_s, 1.4)
			for c in [[86, 136], [100, 142], [114, 136]]:
				circ(c[0], c[1], 2.8, GOLD)
			_stache()


func _beard_base() -> void:
	poly("M71,86 Q69,126 100,138 Q131,126 129,86 Q124,108 112,110 Q100,104 88,110 Q76,108 71,86Z", _hc)
	ln("M80,112 Q84,124 92,130", _hc_s, 1.4)
	ln("M120,112 Q116,124 108,130", _hc_s, 1.4)


func _stache() -> void:
	poly("M84,103 Q93,95 100,100 Q107,95 116,103 Q111,109 104,105 Q100,103 96,105 Q89,109 84,103Z", _hc)


## Dwarf braid: rings of hair down to a gold clasp and a forked tip.
func _braid(x: float, y0: float, y1: float, sway: float) -> void:
	var y := y0
	while y <= y1:
		var xx := x + sway * (y - y0) / (y1 - y0)
		ell(xx, y, 4.8, 3.8, _hc)
		ln("M{a},{b} L{c},{d}", _hc_s, 1.1, {"a": xx - 3, "b": y - 1.5, "c": xx + 2.5, "d": y + 1.5})
		y += 6.0
	var xe := x + sway
	rect(xe - 4.5, y1 + 3, 9, 4.6, 1.2, GOLD)
	ln("M{a},{b} L{c},{b}", GOLD.lerp(Color.WHITE, HIGHLIGHT_LIGHTEN), 1.0, {"a": xe - 3, "b": y1 + 4.5, "c": xe + 3})
	poly("M{a},{y} L{b},{y} L{c},{t} L{e},{u} L{f},{t}Z", _hc, {},
			{"a": xe - 4, "b": xe + 4, "y": y1 + 7.5, "c": xe + 2.5, "t": y1 + 15, "e": xe, "u": y1 + 11, "f": xe - 2.5})


func _front_hair(hooded: bool) -> void:
	var hc := _hc
	match _p.hair:
		"court":
			poly("M66,88 Q60,46 100,40 Q142,46 134,88 L130,74 L125,80 L121,64 L113,72 L106,58 L98,70 L90,60 L85,72 L78,64 L73,80Z", hc)
			_strands(["M108,46 Q114,54 113,64", "M92,46 Q87,54 88,62", "M78,56 Q74,64 75,72", "M122,56 Q127,64 126,72"])
		"long":
			poly("M63,108 Q56,46 100,40 Q144,46 137,108 L133,126 L129,100 L127,80 L121,64 L113,72 L106,58 L98,70 L90,60 L85,72 L79,66 L73,80 L71,100 L67,126Z", hc)
			_strands(["M108,46 Q114,54 113,64", "M92,46 Q87,54 88,62", "M70,84 Q68,104 70,120", "M130,84 Q132,104 130,120"])
		"chignon":
			poly("M67,84 Q62,44 100,42 Q138,44 133,84 L128,70 Q118,56 100,58 Q90,58 84,64 L80,60 L76,72Z", hc)
			_strands(["M84,52 Q96,46 112,50", "M80,60 Q92,52 116,56"])
		"queue":
			poly("M67,84 Q62,44 100,42 Q138,44 133,84 L128,72 Q120,56 100,58 Q90,58 84,64 L80,60 L76,72Z", hc)
			_strands(["M84,52 Q100,46 120,52", "M80,62 Q98,52 126,62"])
		"boucles":
			for c in [[78, 60, 10], [90, 52, 11], [104, 50, 11], [117, 55, 10], [126, 66, 9], [72, 70, 9]]:
				circ(c[0], c[1], c[2], hc)
			for c in [[90, 52], [104, 50], [117, 55]]:
				ln("M{a},{b} Q{c},{d} {e},{f}", _hc_s, 1.4,
						{"a": c[0] - 4, "b": c[1], "c": c[0], "d": c[1] - 4, "e": c[0] + 3, "f": c[1] + 1})
		"rase":
			poly("M71,78 Q69,48 100,47 Q131,48 129,78 Q114,62 100,62 Q86,62 71,78Z", hc, {"ns": true, "op": 0.55})
		"crete":
			poly("M71,78 Q69,48 100,47 Q131,48 129,78 Q114,62 100,62 Q86,62 71,78Z", hc, {"ns": true, "op": 0.45})
			if not hooded:
				poly("M90,66 L84,40 L92,46 L92,20 L100,34 L106,14 L108,38 L116,30 L110,66Z", hc)
				_strands(["M100,62 L100,38", "M95,60 L92,44", "M105,60 L108,40"])
		"chauve":
			ell(112, 58, 7, 3, Color.WHITE, {"ns": true, "op": 0.35})
	if not hooded and _p.hair in ["court", "long", "chignon", "queue"]:
		poly("M80,54 Q92,46 106,48 L104,52 Q92,51 82,58Z", _p.hair_color.lerp(Color.WHITE, HIGHLIGHT_LIGHTEN), {"ns": true})


func _strands(paths: Array) -> void:
	for d in paths:
		ln(d, _hc_s, 1.5)


func _glasses(es: float) -> void:
	var ey := 86.0
	if _p.glasses == "rondes":
		for x in [88.0, 112.0]:
			ell(x, ey, 9.0 * es, 9.0 * es, LENS, {"w": FW / STROKE})
			ln("M{a},{b} L{c},{d}", Color.WHITE, 1.4, {"a": x - 4 * es, "b": ey - 5 * es, "c": x - 1 * es, "d": ey - 7 * es})
		ln("M97,85 Q100,82 103,85", INK, FW)
		ln("M79,84 L71,82", INK, FW)
		ln("M121,84 L129,82", INK, FW)
	elif _p.glasses == "carrees":
		for x in [88.0, 112.0]:
			rect(x - 10.0 * es, ey - 7.0 * es, 20.0 * es, 14.0 * es, 2, LENS, {"w": FW / STROKE})
			ln("M{a},{b} L{c},{d}", Color.WHITE, 1.4, {"a": x - 6 * es, "b": ey - 4 * es, "c": x - 3 * es, "d": ey - 6 * es})
		ln("M98,84 L102,84", INK, FW)
		ln("M78,83 L71,82", INK, FW)
		ln("M122,83 L129,82", INK, FW)


func _hat() -> void:
	var p := _p
	var ac_s := _shade(p.acc)
	match p.head:
		"casquette":
			poly("M68,72 Q66,38 100,38 Q134,38 132,72 Q100,64 68,72Z", _ac)
			ln("M100,38 L100,66", ac_s, 1.3)
			poly("M60,72 Q100,88 140,72 Q100,62 60,72Z", ac_s)
			circ(100, 38, 3, ac_s, {"ns": true})
			poly("M78,52 Q86,44 96,42 Q88,48 84,58Z", Color.WHITE, {"ns": true, "op": HI_OP})
		"tuque":
			circ(100, 26, 10, p.acc.lerp(Color.WHITE, 0.6))
			poly("M66,74 Q64,30 100,30 Q136,30 134,74Z", _ac)
			poly("M64,64 Q100,58 136,64 L137,80 Q100,73 63,80Z", ac_s)
			for x in [74, 86, 100, 114, 126]:
				ln("M{x},{a} L{x},{b}", ac_s.lerp(Color.BLACK, 0.2), 1.4,
						{"x": x, "a": 60 if x == 100 else 62, "b": 74 if x == 100 else 76})
			ln("M84,36 L84,58 M100,32 L100,58 M116,36 L116,58", ac_s, 1.0)
		"sorcier":
			ell(100, 60, 54, 11, ac_s)
			poly("M70,60 Q84,36 90,12 Q96,-8 120,-4 Q106,8 110,30 Q118,48 130,60 Q100,66 70,60Z", _ac)
			poly("M72,56 Q100,62 128,56 L129,62 Q100,68 71,62Z", GOLD, {"ns": true})
			circ(108, 30, 3, Color("#f6e27a"), {"ns": true})
			circ(92, 40, 2, Color("#f6e27a"), {"ns": true})
			ln("M86,48 Q92,30 100,10", p.acc.lerp(Color.WHITE, HIGHLIGHT_LIGHTEN), 1.6)
		"ecouteurs":
			band("M64,86 Q62,32 100,30 Q138,32 136,86", p.acc, 5.0)
			rect(56, 74, 14, 26, 6, _ac)
			rect(130, 74, 14, 26, 6, _ac)
			rect(59, 79, 4, 16, 2, ac_s, {"ns": true})
			rect(137, 79, 4, 16, 2, ac_s, {"ns": true})

# ---------------------------------------------------------------- front of the table

func _build_front() -> void:
	var p := _p
	var hxl: float = geo.hxl
	var hxr: float = geo.hxr
	if p.cls == "roublard":
		layer("Dagger")
		poly("M54,226 L80,212 L83,216 L57,230Z", STEEL)
		ln("M58,226 L80,214", STEEL.lerp(Color.WHITE, HIGHLIGHT_LIGHTEN), 1.0)
		rect(80, 207, 6, 11, 1, LEATHER)
	layer("Prop")
	match p.prop:
		"des":
			var hexagon := PackedVector2Array()
			for k in 6:
				var a := PI / 3.0 * k - PI / 2.0
				hexagon.append(Vector2(90.0 + 9.0 * cos(a), 214.0 + 9.0 * sin(a)))
			group("roll", Vector2(98, 214))
			poly_pts(hexagon, _ac)
			ln_pts(PackedVector2Array([hexagon[0], hexagon[2], hexagon[4]]), _shade(p.acc), 1.0, true)
			rect(104, 207, 13, 13, 2, CREAM)
			circ(110.5, 213.5, 1.6, DARK, {"ns": true})
			circ(107, 210, 1.2, DARK, {"ns": true})
			circ(114, 217, 1.2, DARK, {"ns": true})
			end_group()
		"pile":
			var cols := [_ac, CREAM, Color("#c23b3b"), Color("#3a6fc4"), _ac, CREAM]
			group("stack", Vector2(STACK_X, 216))
			for k in 6:
				group("die%d" % k, Vector2(STACK_X, 216.0 - 11.0 * k - 5.5))
				_d6(STACK_X - 5.5, 216.0 - 11.0 * (k + 1), cols[k], 2 if k % 2 == 1 else 1)
				end_group()
			end_group()
		"tour":
			rect(104, 150, 28, 64, 2, Color("#7a5236"))
			ln("M110,160 L126,160 M110,170 L126,170", Color("#5a3924"), 1.2)
			rect(109, 192, 18, 14, 1, Color("#3a2618"), {"ns": true})
			rect(104, 150, 28, 8, 2, Color("#93653f"))
			group("bounce", Vector2(95, 211))
			rect(90, 206, 10, 10, 2, _ac)
			circ(95, 211, 1.4, Color.WHITE, {"ns": true})
			end_group()
		"canette":
			group("sip", Vector2(99, 214))
			rect(90, 184, 18, 30, 4, _ac)
			ell(99, 184, 9, 2.6, Color("#c9ccd3"))
			rect(90, 195, 18, 6, 0, CREAM, {"ns": true})
			rect(93, 186, 3, 26, 1.5, Color.WHITE, {"ns": true, "op": 0.35})
			end_group()
		"chips":
			var bag := Color("#e8b23a")
			poly("M83,190 L117,188 L121,222 L79,224Z", bag)
			ln("M84,194 L116,192", _shade(bag), 1.2)
			circ(100, 206, 8, Color("#c23b3b"))
			for c in [[124, 224], [130, 220], [76, 226]]:
				ell(c[0], c[1], 3.2, 2, Color("#f2c94c"), {"w": 0.5})
		"fiche":
			poly("M78,206 L122,206 L128,230 L72,230Z", Color("#f4f0e6"))
			rect(84, 208, 10, 6, 1, Color("#9a9488"), {"ns": true, "op": 0.6})
			for y in [212.0, 218.0, 224.0]:
				var x0: float = 84.0 - (y - 206.0) * 0.2 + (12.0 if y == 212.0 else 0.0)
				var x1: float = 116.0 + (y - 206.0) * 0.2
				ln("M{a},{y} L{b},{y}", Color("#9a9488"), 1.2, {"a": x0, "b": x1, "y": y})
			group("scribble", Vector2(118, 224))
			ln("M118,224 L134,206", Color("#e0a53a"), 4.0)
			ln("M118,224 L120,222", Color("#3a2a35"), 2.0)
			end_group()
	# the left hand always rests on the table
	layer("Hands")
	group("handL", Vector2(hxl, 208))
	_cuff_at(hxl)
	_hand(hxl, false)
	end_group()
	if p.prop == "cell":
		# the phone is held in the right hand and the thumb scrolls the feed
		group("handR", Vector2(110, 214))
		_cuff_at(112, 206)
		_hand(110, true, 214)
		end_group()
		_phone()
	else:
		group("handR", Vector2(hxr, 208))
		_cuff_at(hxr)
		if p.prop == "pile":
			group("held", Vector2(hxr, 196), 0.0)
			_d6(hxr - 5.5, 190, _ac, 1)
			end_group()
		elif p.prop == "chips":
			group("chip", Vector2(hxr, 198), 0.0)
			ell(hxr, 198, 4.5, 3, Color("#f2c94c"), {"w": 0.6})
			end_group()
		_hand(hxr, true)
		end_group()


func _phone() -> void:
	group("phone", Vector2(100, 199))
	rect(89, 180, 22, 36, 4, Color("#222228"))
	rect(92, 184, 16, 28, 2, Color("#8fd8ff"), {"ns": true})
	# the feed scrolls inside the screen, so its parent clips it
	var clip := group("", Vector2.ZERO)
	clip.clip_children = CanvasItem.CLIP_CHILDREN_ONLY
	clip.ops.append({"kind": "fill", "pts": _rect_pts(92, 184, 16, 28, 2), "closed": true,
			"fill": Color.WHITE, "line": Color.WHITE, "width": 0.0})
	group("feed", Vector2.ZERO)
	for k in 6:
		var y := 188.0 + k * 9.0
		rect(94, y, 12, 6, 1, Color.WHITE, {"ns": true, "op": 0.85})
		rect(95, y + 1, 4, 4, 1, Color("#e86fa0") if k % 2 == 1 else Color("#3a6fc4"), {"ns": true})
		rect(100, y + 1.5, 5, 1.2, 0.5, STEEL, {"ns": true})
	end_group()
	end_group()
	ell(100, 198, 26, 20, Color("#8fd8ff"), {"ns": true, "op": 0.12})
	group("thumb", Vector2(104, 208))
	poly("M101,212 Q99,203 104,200 Q109,201 109,208 Q109,214 104,216Z", _skin)
	ln("M103,203 Q106,202 107,205", _skin_s, 1.0)
	end_group()
	end_group()


func _hand(x: float, flip: bool, y: float = 208.0) -> void:
	var v := {"x": x, "s": -1 if flip else 1, "o": y - 208.0}
	poly("M{x-12*s},{207+o} Q{x-13*s},{199+o} {x-4*s},{199.5+o} L{x+8*s},{199+o} Q{x+14*s},{200+o} {x+13*s},{207+o} Q{x+12*s},{215+o} {x},{215+o} Q{x-11*s},{215+o} {x-12*s},{207+o}Z", _skin, {}, v)
	for k in [-2, 3, 8]:
		var vk := v.duplicate()
		vk["k"] = k
		ln("M{x+k*s},{200+o} L{x+k*s+.5*s},{205+o}", _skin_s, 1.2, vk)
	poly("M{x-12*s},{207+o} Q{x-8*s},{212+o} {x-2*s},{210+o} Q{x-8*s},{215+o} {x-11*s},{211+o}Z", _skin_s, {"ns": true, "op": 0.8}, v)


func _cuff_at(x: float, y: float = 201.0) -> void:
	var fill := _cuff_fill
	var o := _cuff_o
	if _p.cls != "magicien" and _p.top == "tshirt":
		fill = _skin
		o = {}
	ell(x, y, 15, 8, fill, o)
	ln("M{a},{b} Q{x},{c} {d},{b}", _fold(_cuff_base), 1.1, {"a": x - 10, "b": y - 2, "c": y + 3, "d": x + 10, "x": x})


func _d6(x: float, y: float, color: Color, dots: int) -> void:
	rect(x, y, 11, 11, 2, color)
	rect(x + 1.5, y + 1.2, 8, 2, 1, Color.WHITE, {"ns": true, "op": 0.35})
	if dots == 1:
		circ(x + 5.5, y + 5.5, 1.4, DARK, {"ns": true})
	else:
		circ(x + 3.2, y + 3.4, 1.1, DARK, {"ns": true})
		circ(x + 7.8, y + 7.8, 1.1, DARK, {"ns": true})


# ---------------------------------------------------------------- drawing helpers

## Starts a new draw layer inside the current container.
func layer(layer_name: String) -> void:
	_seg = null
	_next_name = layer_name


## Opens an animation group pivoting at `pivot` (figure coordinates). Everything drawn until
## end_group() lives under it, so a pose is just a transform of the node.
func group(key: String, pivot: Vector2, opacity: float = 1.0) -> PlayerLayer:
	var node := PlayerLayer.new()
	node.name = key if key != "" else "Static"
	node.position = pivot - _origin
	node.rest_position = node.position
	node.modulate.a = opacity
	_root.add_child(node)
	_stack.append([_root, _origin])
	_root = node
	_origin = pivot
	_seg = null
	if key != "":
		groups[key] = node
	return node


func end_group() -> void:
	var saved: Array = _stack.pop_back()
	_root = saved[0]
	_origin = saved[1]
	_seg = null


func _begin(container: Node2D) -> void:
	_root = container
	_origin = Vector2.ZERO
	_seg = null
	_stack.clear()


func poly(template: String, fill: Color, o: Dictionary = {}, vars: Dictionary = {}) -> void:
	for sub in SvgPath.parse(_d(template, vars)):
		_fill(sub.pts, sub.closed, fill, o)


func poly_pts(pts: PackedVector2Array, fill: Color, o: Dictionary = {}) -> void:
	_fill(pts, true, fill, o)


func ln(template: String, color: Color = INK, width: float = FW, vars: Dictionary = {}) -> void:
	for sub in SvgPath.parse(_d(template, vars)):
		_add({"kind": "line", "pts": _local(sub.pts), "closed": sub.closed, "line": color, "width": width * stroke_mult})


func ln_pts(pts: PackedVector2Array, color: Color = INK, width: float = FW, closed: bool = false) -> void:
	_add({"kind": "line", "pts": _local(pts), "closed": closed, "line": color, "width": width * stroke_mult})


## Thick line with an outline, the reference's Band().
func band(template: String, color: Color, width: float, vars: Dictionary = {}) -> void:
	ln(template, INK, width + 3.0, vars)
	ln(template, color, width, vars)


func ell(cx: float, cy: float, rx: float, ry: float, fill: Color, o: Dictionary = {}) -> void:
	var pts := PackedVector2Array()
	for i in ELLIPSE_STEPS:
		var a := TAU * i / ELLIPSE_STEPS
		pts.append(Vector2(cx + rx * cos(a), cy + ry * sin(a)))
	_fill(pts, true, fill, o)


func circ(cx: float, cy: float, r: float, fill: Color, o: Dictionary = {}) -> void:
	ell(cx, cy, r, r, fill, o)


func rect(x: float, y: float, w: float, h: float, r: float, fill: Color, o: Dictionary = {}) -> void:
	_fill(_rect_pts(x, y, w, h, r), true, fill, o)


static func _rect_pts(x: float, y: float, w: float, h: float, r: float) -> PackedVector2Array:
	var rad := minf(r, minf(w, h) / 2.0)
	if rad <= 0.0:
		return PackedVector2Array([Vector2(x, y), Vector2(x + w, y), Vector2(x + w, y + h), Vector2(x, y + h)])
	var pts := PackedVector2Array()
	var corners := [Vector2(x + w - rad, y + rad), Vector2(x + w - rad, y + h - rad),
			Vector2(x + rad, y + h - rad), Vector2(x + rad, y + rad)]
	for c in 4:
		for i in CORNER_STEPS + 1:
			var a := (c - 1) * PI / 2.0 + PI / 2.0 * i / CORNER_STEPS
			pts.append(corners[c] + Vector2(cos(a), sin(a)) * rad)
	return pts

func text(value: String, pos: Vector2, size: int, color: Color) -> void:
	var span := 20.0
	_add({"kind": "text", "pts": _local(PackedVector2Array([pos - Vector2(span / 2.0, 0.0)])),
			"text": value, "size": size, "line": color, "span": span})


func _fill(pts: PackedVector2Array, closed: bool, fill: Color, o: Dictionary) -> void:
	var alpha: float = o.get("op", 1.0)
	var width := 0.0 if o.get("ns", false) else float(o.get("w", 1.0)) * STROKE * stroke_mult
	var op := {"kind": "fill", "pts": _local(pts), "closed": closed, "fill": _fade(fill, alpha),
			"line": _fade(INK, alpha), "width": width}
	var tex: Texture2D = o.get("tex")
	if tex != null:
		var uvs := PackedVector2Array()
		for pt in pts:
			uvs.append(pt / float(PLAID_CELL))
		op["tex"] = tex
		op["uvs"] = uvs
	_add(op)


func _add(op: Dictionary) -> void:
	if _seg == null:
		_seg = PlayerLayer.new()
		var layer_name := _next_name
		if _root.has_node(layer_name):
			layer_name += str(_root.get_child_count())
		_seg.name = layer_name
		_root.add_child(_seg)
		_next_name = "Layer"
	if op.has("tex"):
		_seg.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	_seg.ops.append(op)


func _local(pts: PackedVector2Array) -> PackedVector2Array:
	var out := PackedVector2Array()
	for pt in pts:
		out.append(pt - _origin)
	return out


static func _fade(color: Color, alpha: float) -> Color:
	return Color(color, color.a * alpha)


static func _shade(color: Color) -> Color:
	return color.lerp(Color.BLACK, SHADE_DARKEN)


static func _fold(color: Color) -> Color:
	return INK.lerp(color, FOLD_MIX)


## Gingham tile, drawn once per colour at PLAID_TEXELS texels per unit.
static func _plaid(color: Color) -> ImageTexture:
	var key := color.to_html()
	if _plaids.has(key):
		return _plaids[key]
	var dark := color.lerp(Color.BLACK, 0.3)
	var light := color.lerp(Color.WHITE, 0.45)
	var size := PLAID_CELL * PLAID_TEXELS
	var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
	for py in size:
		for px in size:
			var u := float(px) / PLAID_TEXELS
			var v := float(py) / PLAID_TEXELS
			var c := color
			if u < 7.0:
				c = c.lerp(dark, 0.55)
			if v < 7.0:
				c = c.lerp(dark, 0.55)
			if u >= 12.0 and u < 13.5:
				c = light
			if v >= 12.0 and v < 13.5:
				c = light
			img.set_pixel(px, py, c)
	var tex := ImageTexture.create_from_image(img)
	_plaids[key] = tex
	return tex


# ---------------------------------------------------------------- path templates

## Fills "{expr}" slots with GDScript expressions over the geometry variables (w, Lx, Rx, L2, R2,
## hxL, hxR) and `extra`. This is how the reference's JS template strings port nearly verbatim.
func _d(template: String, extra: Dictionary = {}) -> String:
	if not "{" in template:
		return template
	var names := PackedStringArray(_vars.keys())
	var values: Array = _vars.values()
	for k in extra:
		names.append(k)
		values.append(extra[k])
	var out := ""
	var i := 0
	while true:
		var open := template.find("{", i)
		if open < 0:
			out += template.substr(i)
			break
		var close := template.find("}", open)
		out += template.substr(i, open - i) + str(_eval(template.substr(open + 1, close - open - 1), names, values))
		i = close + 1
	return out


static func _eval(expr_text: String, names: PackedStringArray, values: Array) -> Variant:
	var key := expr_text + "|" + ",".join(names)
	var expr: Expression = _exprs.get(key)
	if expr == null:
		expr = Expression.new()
		if expr.parse(_leading_dot.sub(expr_text, "0.$1", true), names) != OK:
			push_error("TablePlayerBuilder: cannot parse '%s': %s" % [expr_text, expr.get_error_text()])
		_exprs[key] = expr
	var result: Variant = expr.execute(values, null, false)
	if expr.has_execute_failed():
		push_error("TablePlayerBuilder: cannot evaluate '%s'" % expr_text)
	return result