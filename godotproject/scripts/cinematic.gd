extends RefCounted
## Opening cinematic (before the start screen), 21:9 letterboxed.
## 2D shots: sunset horizon -> helicopter squadron -> crew close-ups -> the cashier jumps.
## The final 3D shot (parachute landing at the shop) is driven by game.gd.

const Toon := preload("res://scripts/toon_ui.gd")
const FISHSTICKS := preload("res://assets/fishsticks.jpeg")

# Timeline (seconds)
const T_MUSIC := 2.0          # Valkyries begin
const MUSIC_OFFSET := 10.0    # skip the very quiet opening seconds of the track
const T_HELIS := 3.0          # squadron appears on the horizon
const T_CU_COMMANDER := 11.0
const T_CU_SURFER := 15.6
const T_CU_SOLDIER := 20.2
const T_CU_CASHIER := 24.8
const CASHIER_JUMP := 5.2     # seconds into the cashier shot when he jumps
const T_WIDE_JUMP := 30.6
const T_CABIN := 33.4         # the crew, alone... who's flying?
const T_CRASH := 41.2         # helicopter spirals into a giant deep fryer
const CRASH_IMPACT := 2.3     # seconds into the crash shot
const T_STICKS := 44.8        # the result
const T_3D := 49.6            # cut underwater: parachute landing
const T_LAND := 54.1
const T_END := 56.7

# Crew small talk: [time, speaker, line]. Spoken in Animalese with subtitles.
const DIALOGUE := [
	[11.7, "BARNACLE", "Listen up! Today we deliver ONE burger. Hot."],
	[13.7, "WAVES", "Sir, is there any surf at the drop zone?"],
	[16.1, "BARNACLE", "Son, there's a whole ocean down there."],
	[18.0, "WAVES", "Gnarly. I brought my board, just in case."],
	[20.7, "GULP", "Is it bad that I can't swim?"],
	[22.4, "WAVES", "Bro... you're a fish."],
	[23.6, "GULP", "...oh. Right."],
	[25.3, "CASHIER", "Can we land? My shift started ten minutes ago."],
	[27.4, "BARNACLE", "Negative. We don't land. You jump."],
	[29.2, "CASHIER", "...I hate this job."],
	[33.9, "GULP", "Is he gonna be okay?"],
	[35.4, "BARNACLE", "He's a professional. Mostly."],
	[37.1, "WAVES", "Uh, sir... who's flying this thing?"],
	[38.8, "BARNACLE", "...I thought YOU were."],
	[40.2, "GULP", "MOOOOOM!"],
	[41.5, "WAVES", "Dude! Is that a FRYER?!"],
	[46.9, "WAVES", "(surfing away) ...Gnarly."],
]
const SPEAKER_COLORS := {
	"BARNACLE": Color(1.0, 0.7, 0.3), "WAVES": Color(0.4, 0.9, 1.0),
	"GULP": Color(1.0, 0.9, 0.3), "CASHIER": Color(1.0, 0.5, 0.45),
}
const SPEAKER_PITCH := {"BARNACLE": 0.95, "WAVES": 1.35, "GULP": 1.9, "CASHIER": 1.1}

const HELI_COUNT := 7
const SKY_TOP := Color(0.16, 0.02, 0.09)
const SKY_MID := Color(0.72, 0.14, 0.07)
const SKY_LOW := Color(1.0, 0.5, 0.12)
const HORIZON := Color(1.0, 0.8, 0.45)
const SILHOUETTE := Color(0.06, 0.02, 0.03)


static func draw(ci: CanvasItem, font: Font, g, W: float, H: float) -> void:
	var t: float = g.cine_t
	if t < T_3D:
		if t < T_CU_COMMANDER:
			shot_horizon(ci, W, H, t)
		elif t < T_CU_SURFER:
			shot_closeup(ci, font, W, H, t - T_CU_COMMANDER, "commander", g)
		elif t < T_CU_SOLDIER:
			shot_closeup(ci, font, W, H, t - T_CU_SURFER, "surfer", g)
		elif t < T_CU_CASHIER:
			shot_closeup(ci, font, W, H, t - T_CU_SOLDIER, "soldier", g)
		elif t < T_WIDE_JUMP:
			shot_closeup(ci, font, W, H, t - T_CU_CASHIER, "cashier", g)
		elif t < T_CABIN:
			shot_jump(ci, W, H, t - T_WIDE_JUMP)
		elif t < T_CRASH:
			shot_cabin(ci, W, H, t - T_CABIN, g)
		elif t < T_STICKS:
			shot_crash(ci, W, H, t - T_CRASH)
		else:
			shot_sticks(ci, W, H, t - T_STICKS)
	letterbox(ci, W, H)
	for k in [["commander", T_CU_COMMANDER], ["surfer", T_CU_SURFER], ["soldier", T_CU_SOLDIER], ["cashier", T_CU_CASHIER], ["sticks", card_start("sticks")]]:
		var lt: float = t - k[1]
		if lt >= 0.0 and lt < 5.0:
			name_card(ci, font, W, H, lt, k[0])
	subtitles(ci, font, W, H, g)
	# fades: from black at the start, dip to black before the underwater cut, fade out at the end
	var black := 0.0
	if t < 2.2:
		black = 1.0 - clampf((t - 0.4) / 1.8, 0.0, 1.0)
	elif t > T_3D - 0.5 and t < T_3D:
		black = (t - (T_3D - 0.5)) / 0.5
	elif t >= T_3D and t < T_3D + 0.8:
		black = 1.0 - (t - T_3D) / 0.8
	elif t > T_END - 1.0:
		black = clampf((t - (T_END - 1.0)) / 0.9, 0.0, 1.0)
	if black > 0.0:
		ci.draw_rect(Rect2(0, 0, W, H), Color(0, 0, 0, black))
	# white flash: the fryer explosion -> photo
	var white := 0.0
	if t > T_STICKS - 0.6 and t < T_STICKS:
		white = (t - (T_STICKS - 0.6)) / 0.6
	elif t >= T_STICKS and t < T_STICKS + 0.6:
		white = 1.0 - (t - T_STICKS) / 0.6
	if white > 0.0:
		ci.draw_rect(Rect2(0, 0, W, H), Color(1, 1, 0.95, white))
	if t > 3.0 and t < T_END - 1.0:
		Toon.toon_text(ci, font, Vector2(0, H - 14), "Press C or S to skip", 14, Color(1, 1, 1, 0.35), HORIZONTAL_ALIGNMENT_RIGHT, W - 18, 3, false)


# ---------------------------------------------------------------- framing

static func content_rect(W: float, H: float) -> Rect2:
	var ch := minf(H, W * 9.0 / 21.0)
	return Rect2(0, (H - ch) / 2.0, W, ch)


static func letterbox(ci: CanvasItem, W: float, H: float) -> void:
	var r := content_rect(W, H)
	ci.draw_rect(Rect2(0, 0, W, r.position.y), Color.BLACK)
	ci.draw_rect(Rect2(0, r.end.y, W, H - r.end.y), Color.BLACK)


static func band(ci: CanvasItem, y0: float, y1: float, W: float, c0: Color, c1: Color) -> void:
	ci.draw_polygon(PackedVector2Array([Vector2(0, y0), Vector2(W, y0), Vector2(W, y1), Vector2(0, y1)]),
		PackedColorArray([c0, c0, c1, c1]))


# ---------------------------------------------------------------- sunset

static func sunset(ci: CanvasItem, W: float, H: float, t: float, zoom: float, sun_scale := 1.0, rot := 0.0) -> float:
	# Draws the sky, sun and sea; returns the horizon y. `zoom` pushes in around the sun.
	var r := content_rect(W, H)
	var hy := r.position.y + r.size.y * 0.64
	var c := Vector2(W / 2.0, hy)
	ci.draw_set_transform(c, rot, Vector2(zoom, zoom))
	var top := -hy - 40.0 - absf(rot) * W * 0.6
	band(ci, top, -r.size.y * 0.42, W * 2.0, SKY_TOP, SKY_MID)
	band(ci, -r.size.y * 0.42, -r.size.y * 0.1, W * 2.0, SKY_MID, SKY_LOW)
	band(ci, -r.size.y * 0.1, 0.0, W * 2.0, SKY_LOW, HORIZON)
	# the polygons above start at x=0; shift them to cover the full width
	ci.draw_set_transform(c + Vector2(-W * zoom, 0).rotated(rot), rot, Vector2(zoom, zoom))
	band(ci, top, -r.size.y * 0.42, W * 2.0, SKY_TOP, SKY_MID)
	band(ci, -r.size.y * 0.42, -r.size.y * 0.1, W * 2.0, SKY_MID, SKY_LOW)
	band(ci, -r.size.y * 0.1, 0.0, W * 2.0, SKY_LOW, HORIZON)
	ci.draw_set_transform(c, rot, Vector2(zoom, zoom))
	# sun with layered glow, sinking into the horizon
	var sr := r.size.y * 0.24 * sun_scale
	var sc := Vector2(0, -sr * 0.35)
	for k in 8:
		ci.draw_circle(sc, sr * (1.0 + 0.35 * (k + 1)), Color(1.0, 0.55, 0.2, 0.05))
	ci.draw_circle(sc, sr, Color(1.0, 0.72, 0.38))
	ci.draw_circle(sc + Vector2(0, -sr * 0.12), sr * 0.86, Color(1.0, 0.84, 0.55))
	# long thin clouds across the sun
	for k in 5:
		var cy := sc.y - sr * 0.6 + k * sr * 0.32 + sin(t * 0.2 + k) * 3.0
		var cx := sin(k * 2.3) * sr * 0.6 + t * (4.0 + k)
		var cl := PackedVector2Array()
		for i in 24:
			var a := TAU * i / 24.0
			cl.append(Vector2(cx + cos(a) * sr * (1.1 + 0.3 * k), cy + sin(a) * (3.0 + k)))
		ci.draw_colored_polygon(cl, Color(0.45, 0.06, 0.06, 0.55))
	# sea
	band(ci, 0.0, r.size.y * 0.5, W * 2.0, Color(0.42, 0.1, 0.06), Color(0.05, 0.01, 0.03))
	ci.draw_set_transform(c + Vector2(-W * zoom, 0).rotated(rot), rot, Vector2(zoom, zoom))
	band(ci, 0.0, r.size.y * 0.5, W * 2.0, Color(0.42, 0.1, 0.06), Color(0.05, 0.01, 0.03))
	ci.draw_set_transform(c, rot, Vector2(zoom, zoom))
	# sun reflection: shimmering streaks under the sun
	for i in 22:
		var y := 4.0 + i * i * 0.55
		var w := sr * (0.9 - i * 0.025) * (0.6 + 0.4 * sin(t * 3.0 + i * 1.7))
		var x := sin(t * 1.3 + i) * 6.0
		ci.draw_line(Vector2(x - w, y), Vector2(x + w, y), Color(1.0, 0.78, 0.45, 0.55 - i * 0.02), 2.0)
	# heat haze line on the horizon
	ci.draw_line(Vector2(-W, 0), Vector2(W, 0), Color(1.0, 0.9, 0.65, 0.8), 2.0)
	ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	return hy


static func dust(ci: CanvasItem, W: float, H: float, t: float) -> void:
	for i in 30:
		var x := fmod(i * 131.7 + t * (8.0 + i % 5), W)
		var y := fmod(i * 71.3 + sin(t * 0.4 + i) * 20.0, H)
		ci.draw_circle(Vector2(x, y), 1.2 + (i % 3) * 0.6, Color(1.0, 0.8, 0.5, 0.25))


# ---------------------------------------------------------------- helicopter silhouette

static func heli(ci: CanvasItem, c: Vector2, s: float, col: Color, t: float, tilt := -0.08, facing := 1.0) -> void:
	# Generic utility-helicopter silhouette, ~320 units long, nose pointing in `facing` direction.
	ci.draw_set_transform(c, tilt * facing, Vector2(s * facing, s))
	ci.draw_colored_polygon(ellipse(Vector2(-10, 0), 62, 28), col)  # cabin
	ci.draw_colored_polygon(ellipse(Vector2(-58, 4), 22, 20), col)  # nose
	ci.draw_colored_polygon(PackedVector2Array([Vector2(36, -12), Vector2(165, -6), Vector2(165, 1), Vector2(36, 12)]), col)  # tail boom
	ci.draw_colored_polygon(PackedVector2Array([Vector2(150, -4), Vector2(170, -38), Vector2(176, -36), Vector2(168, 2)]), col)  # fin
	ci.draw_rect(Rect2(-8, -40, 16, 14), col)  # mast
	ci.draw_line(Vector2(-48, 38), Vector2(36, 38), col, 5.0)  # skids
	ci.draw_line(Vector2(-30, 26), Vector2(-34, 38), col, 4.0)
	ci.draw_line(Vector2(18, 26), Vector2(22, 38), col, 4.0)
	# open side door (sunset light shining through)
	ci.draw_colored_polygon(PackedVector2Array([Vector2(-22, -14), Vector2(14, -14), Vector2(14, 14), Vector2(-22, 14)]), col.lerp(SKY_LOW, 0.35))
	# main rotor blur
	var ph := sin(t * 47.0)
	for k in 3:
		var len := 150.0 - k * 22.0 + ph * 10.0
		ci.draw_line(Vector2(-len, -42 + k), Vector2(len, -42 - k), Color(col, 0.75 - k * 0.22), 3.0 - k * 0.7)
	# tail rotor blur
	ci.draw_circle(Vector2(168, -8), 16, Color(col, 0.22))
	ci.draw_line(Vector2(168, -24 + ph * 4), Vector2(168, 8 - ph * 4), col, 2.0)
	ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


static func heli_front(ci: CanvasItem, c: Vector2, s: float, col: Color, t: float, bank := 0.0) -> void:
	# Head-on helicopter silhouette (flying straight at the camera).
	ci.draw_set_transform(c, bank, Vector2(s, s))
	# fuselage seen from the front: rounded, slightly wider at the bottom
	ci.draw_colored_polygon(PackedVector2Array([Vector2(-30, -26), Vector2(30, -26), Vector2(44, 0), Vector2(38, 26), Vector2(-38, 26), Vector2(-44, 0)]), col)
	ci.draw_colored_polygon(ellipse(Vector2(0, -24), 30, 14), col)
	# windscreen panes catching the sunset
	var glass := col.lerp(SKY_LOW, 0.5)
	ci.draw_colored_polygon(PackedVector2Array([Vector2(-26, -20), Vector2(-3, -20), Vector2(-4, 4), Vector2(-34, 4)]), glass)
	ci.draw_colored_polygon(PackedVector2Array([Vector2(3, -20), Vector2(26, -20), Vector2(34, 4), Vector2(4, 4)]), glass)
	# tail fin peeking out above/behind
	ci.draw_colored_polygon(PackedVector2Array([Vector2(-3, -36), Vector2(3, -36), Vector2(2, -62), Vector2(-2, -62)]), col)
	# mast + main rotor disc (seen edge-on as a wide blur)
	ci.draw_rect(Rect2(-6, -48, 12, 12), col)
	var ph := sin(t * 47.0)
	for k in 3:
		var len := 175.0 - k * 26.0 + ph * 12.0
		ci.draw_line(Vector2(-len, -49 + k), Vector2(len, -49 - k), Color(col, 0.8 - k * 0.24), 3.5 - k * 0.8)
	# skids: struts down to two short rails pointing at us
	for sx in [-1.0, 1.0]:
		ci.draw_line(Vector2(sx * 24, 24), Vector2(sx * 36, 42), col, 4.0)
		ci.draw_line(Vector2(sx * 30, 42), Vector2(sx * 42, 42), col, 5.0)
	# landing light
	ci.draw_circle(Vector2(0, 18), 4.0, Color(1.0, 0.95, 0.75, col.a * 0.9))
	ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


static func ellipse(c: Vector2, rx: float, ry: float, seg := 28) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in seg:
		var a := TAU * i / seg
		pts.append(c + Vector2(cos(a) * rx, sin(a) * ry))
	return pts


# ---------------------------------------------------------------- shot A: horizon + squadron approaching

static func shot_horizon(ci: CanvasItem, W: float, H: float, t: float) -> void:
	var push := 1.0 + 0.07 * clampf(t / 11.0, 0.0, 1.0)
	var hy := sunset(ci, W, H, t, push)
	if t > T_HELIS:
		var k := clampf((t - T_HELIS) / (T_CU_COMMANDER - T_HELIS), 0.0, 1.0)
		var grow := 0.04 + 0.26 * k * k
		for i in HELI_COUNT:
			var appear := clampf((t - T_HELIS - i * 0.4) / 1.2, 0.0, 1.0)
			if appear <= 0.0:
				continue
			var off := float(i - 3)
			var x := W / 2.0 + off * W * (0.035 + 0.14 * k * k) + sin(t * 0.6 + i) * 4.0
			var y := hy - H * (0.04 + 0.22 * k) - absf(off) * H * 0.02 * (0.5 + k) + sin(t * 1.8 + i * 1.3) * 3.0
			var s := grow * (1.0 - absf(off) * 0.06)
			var col := HORIZON.lerp(SILHOUETTE, clampf(0.35 + k * 0.9, 0.0, 1.0))
			col.a = appear
			heli_front(ci, Vector2(x, y), s * 1.6, col, t + i, sin(t * 0.7 + i) * 0.05 + off * 0.02)
	dust(ci, W, H, t)


# ---------------------------------------------------------------- crew close-ups

static func shot_closeup(ci: CanvasItem, font: Font, W: float, H: float, lt: float, who: String, g) -> void:
	var r := content_rect(W, H)
	var t: float = g.cine_t
	# blurred-looking sunset seen through the open door, pushed in
	sunset(ci, W, H, t, 2.2, 1.4)
	# wind streaks
	for i in 16:
		var y := r.position.y + fmod(i * 53.7, r.size.y)
		var x := W - fmod(t * (900.0 + i * 37.0) + i * 211.0, W + 400.0)
		ci.draw_line(Vector2(x, y), Vector2(x + 160 + (i % 4) * 40, y), Color(1, 0.85, 0.65, 0.22), 2.0)
	# vibration
	var shake := Vector2(sin(t * 53.0), cos(t * 47.0)) * (5.0 if who == "soldier" else 2.5)
	var tex: Texture2D = g.cine_tex.get(who)
	var cx := W * (0.42 if who != "cashier" else 0.5)
	var size := r.size.y * 1.25
	var bottom := r.end.y + size * 0.18
	var jump := 0.0
	var spin := 0.0
	if who == "cashier":
		if lt > CASHIER_JUMP - 0.3 and lt < CASHIER_JUMP:
			bottom += (lt - (CASHIER_JUMP - 0.3)) / 0.3 * size * 0.06  # crouch
		elif lt >= CASHIER_JUMP:
			jump = (lt - CASHIER_JUMP) / 0.7
			spin = jump * 1.6
	var origin := Vector2(cx - size / 2.0, bottom - size) + shake
	var pt := func(px: float, py: float) -> Vector2: return origin + Vector2(px, py) * size / 320.0
	if who == "surfer":
		# surfboard behind him
		var board := ellipse(pt.call(262, 175), 30 * size / 320.0, 128 * size / 320.0)
		Toon.vgrad(ci, ellipse(pt.call(262, 175), 34 * size / 320.0, 132 * size / 320.0), Toon.INK, Toon.INK)
		Toon.vgrad(ci, board, Color(1.0, 0.85, 0.2), Color(1.0, 0.45, 0.15))
		ci.draw_line(pt.call(262, 55), pt.call(262, 295), Color(0.85, 0.1, 0.15), 6.0 * size / 320.0)
	if jump < 1.0:
		var o2: Vector2 = origin + Vector2(-jump * W * 0.5, jump * jump * r.size.y * 1.2)
		ci.draw_set_transform(o2 + Vector2(size, size) / 2.0, -spin, Vector2.ONE)
		ci.draw_texture_rect(tex, Rect2(-Vector2(size, size) / 2.0, Vector2(size, size)), false, Color(0.92, 0.72, 0.62))
		ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		if jump <= 0.0:
			props(ci, who, pt, size / 320.0, t)
	# helicopter door frame (dark interior on both sides, rim-lit by the sunset)
	var fl := PackedVector2Array([Vector2(0, r.position.y), Vector2(W * 0.13, r.position.y), Vector2(W * 0.1, r.end.y), Vector2(0, r.end.y)])
	var fr := PackedVector2Array([Vector2(W * 0.86, r.position.y), Vector2(W, r.position.y), Vector2(W, r.end.y), Vector2(W * 0.89, r.end.y)])
	ci.draw_colored_polygon(fl, Color(0.07, 0.06, 0.04))
	ci.draw_colored_polygon(fr, Color(0.07, 0.06, 0.04))
	ci.draw_line(Vector2(W * 0.13, r.position.y), Vector2(W * 0.1, r.end.y), Color(1, 0.55, 0.2, 0.8), 3.0)
	ci.draw_line(Vector2(W * 0.86, r.position.y), Vector2(W * 0.89, r.end.y), Color(1, 0.55, 0.2, 0.8), 3.0)
	ci.draw_rect(Rect2(0, r.position.y, W, r.size.y * 0.08), Color(0.07, 0.06, 0.04))
	# a strap swinging from the ceiling
	var sw := sin(t * 3.0) * 12.0
	ci.draw_line(Vector2(W * 0.78, r.position.y + r.size.y * 0.08), Vector2(W * 0.78 + sw, r.position.y + r.size.y * 0.42), Color(0.2, 0.18, 0.1), 5.0)
	ci.draw_arc(Vector2(W * 0.78 + sw, r.position.y + r.size.y * 0.47), 16, 0, TAU, 20, Color(0.2, 0.18, 0.1), 5.0)


static func props(ci: CanvasItem, who: String, pt: Callable, f: float, t: float) -> void:
	# Costume props drawn over the crew sprites (coordinates are in 320px art space, measured on
	# customer_round_front_3 / customer_tall_front_3 / customer_wide_front_1 / cashier_front).
	match who:
		"commander":
			# wide-brim cavalry hat with gold cord, sitting over his sweatband
			Toon.vgrad(ci, ellipse(pt.call(162, 184), 84 * f, 16 * f), Color(0.15, 0.12, 0.07), Color(0.08, 0.06, 0.03))
			ci.draw_colored_polygon(PackedVector2Array([pt.call(118, 184), pt.call(206, 184), pt.call(196, 136), pt.call(162, 146), pt.call(128, 136)]), Color(0.16, 0.13, 0.08))
			ci.draw_line(pt.call(120, 175), pt.call(204, 175), Color(0.95, 0.75, 0.2), 5 * f)
			ci.draw_line(pt.call(152, 152), pt.call(172, 168), Color(0.95, 0.75, 0.2), 3 * f)
			ci.draw_line(pt.call(172, 152), pt.call(152, 168), Color(0.95, 0.75, 0.2), 3 * f)
			# aviator sunglasses reflecting the sunset
			for ex in [140.0, 180.0]:
				var lens := ellipse(pt.call(ex, 211), 19 * f, 14 * f)
				Toon.vgrad(ci, lens, Color(0.95, 0.55, 0.2), Color(0.08, 0.04, 0.06))
				Toon.outline(ci, lens, Color(0.9, 0.75, 0.3), 2.5 * f)
			ci.draw_line(pt.call(158, 207), pt.call(162, 207), Color(0.9, 0.75, 0.3), 3 * f)
			# megaphone at his mouth, pointed out of the door, blaring
			ci.draw_colored_polygon(PackedVector2Array([pt.call(146, 230), pt.call(146, 252), pt.call(62, 282), pt.call(62, 200)]), Color(0.75, 0.75, 0.7))
			ci.draw_colored_polygon(ellipse(pt.call(62, 241), 10 * f, 41 * f), Color(0.3, 0.3, 0.32))
			for k in 3:
				var rr := (30.0 + k * 26.0 + fmod(t * 120.0, 26.0)) * f
				ci.draw_arc(pt.call(54, 241), rr, PI * 0.75, PI * 1.25, 12, Color(1, 0.9, 0.7, 0.6 - k * 0.18), 4 * f)
		"surfer":
			# red bandana under the cap, tails flapping in the wind
			ci.draw_line(pt.call(124, 137), pt.call(198, 137), Color(0.9, 0.15, 0.2), 8 * f)
			ci.draw_line(pt.call(198, 137), pt.call(220, 146 + sin(t * 20.0) * 6.0), Color(0.9, 0.15, 0.2), 6 * f)
			ci.draw_line(pt.call(198, 139), pt.call(216, 156 + sin(t * 23.0 + 1.0) * 6.0), Color(0.8, 0.1, 0.15), 5 * f)
		"soldier":
			# oversized army helmet jammed over his straw hat, netting and a dangling strap
			Toon.vgrad(ci, half_dome(pt.call(160, 196), 82 * f, 54 * f), Color(0.36, 0.42, 0.22), Color(0.2, 0.24, 0.12))
			for k in 6:
				ci.draw_line(pt.call(96 + k * 26, 152), pt.call(106 + k * 22, 194), Color(0.12, 0.14, 0.06), 2 * f)
			ci.draw_line(pt.call(76, 196), pt.call(244, 196), Color(0.14, 0.16, 0.08), 7 * f)
			ci.draw_line(pt.call(88, 198), pt.call(102, 256), Color(0.25, 0.2, 0.1), 3 * f)
			# nervous sweat
			for k in 2:
				var sy := 196.0 + fmod(t * 60.0 + k * 30.0, 50.0)
				ci.draw_colored_polygon(ellipse(pt.call(236 + k * 10, sy), 4 * f, 7 * f), Color(0.7, 0.9, 1.0, 0.85))
		"cashier":
			# flight goggles pushed up under the cap and parachute harness straps
			ci.draw_line(pt.call(112, 146), pt.call(208, 146), Color(0.2, 0.15, 0.1), 7 * f)
			for gx in [142.0, 178.0]:
				ci.draw_circle(pt.call(gx, 143), 14 * f, Color(0.25, 0.2, 0.15))
				ci.draw_circle(pt.call(gx, 143), 10 * f, Color(1.0, 0.7, 0.4, 0.85))
				ci.draw_circle(pt.call(gx - 4, 139), 3.5 * f, Color(1, 1, 0.9))
			ci.draw_line(pt.call(112, 176), pt.call(146, 262), Color(0.25, 0.3, 0.15), 9 * f)
			ci.draw_line(pt.call(208, 176), pt.call(174, 262), Color(0.25, 0.3, 0.15), 9 * f)
			ci.draw_rect(Rect2(pt.call(150, 244), Vector2(20, 16) * f), Color(0.7, 0.7, 0.72))


static func half_dome(c: Vector2, rx: float, ry: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in 17:
		var a := PI + PI * i / 16.0
		pts.append(c + Vector2(cos(a) * rx, sin(a) * ry))
	return pts


# ---------------------------------------------------------------- shot F: squadron overhead, the jump

static func shot_jump(ci: CanvasItem, W: float, H: float, lt: float) -> void:
	var hy := sunset(ci, W, H, 20.0 + lt, 1.18, 1.25)
	var r := content_rect(W, H)
	# squadron roaring past, big and dark
	for i in 4:
		var sp := 0.16 + i * 0.03
		var x := -W * 0.25 + (lt * sp + i * 0.22) * W
		var y := r.position.y + r.size.y * (0.18 + i * 0.09) + sin(lt * 2.0 + i) * 4.0
		heli(ci, Vector2(x, y), 0.7 + i * 0.18, SILHOUETTE, lt + i * 3.0, -0.12)
	# the paratrooper: falls from the door, chute pops open, drifts down in front of the sun
	var drop := 0.4
	if lt > drop:
		var k := lt - drop
		var px := W * 0.42 + k * 22.0 + sin(k * 1.8) * 14.0
		var py := r.position.y + r.size.y * 0.3 + (k * k * 160.0 if k < 0.55 else 0.55 * 0.55 * 160.0 + (k - 0.55) * 45.0)
		var p := Vector2(px, py)
		if k > 0.55:
			var open := clampf((k - 0.55) / 0.2, 0.0, 1.0)
			var cw := 46.0 * open
			var cc := p + Vector2(0, -60)
			ci.draw_colored_polygon(half_dome(cc, cw, 28.0 * open), SILHOUETTE)
			for sx in [-1.0, -0.4, 0.4, 1.0]:
				ci.draw_line(cc + Vector2(cw * sx, 0), p + Vector2(0, -8), Color(SILHOUETTE, 0.9), 1.4)
		# the squid cashier's silhouette: long head with side fins, cap, dangling tentacles
		var sway := sin(k * 3.0) * 0.15
		ci.draw_set_transform(p + Vector2(0, 12), sway, Vector2.ONE * 1.9)
		ci.draw_colored_polygon(ellipse(Vector2(0, -2), 6.5, 11.0), SILHOUETTE)
		ci.draw_colored_polygon(PackedVector2Array([Vector2(-5, -8), Vector2(-11, -10), Vector2(-5, -2)]), SILHOUETTE)
		ci.draw_colored_polygon(PackedVector2Array([Vector2(5, -8), Vector2(11, -10), Vector2(5, -2)]), SILHOUETTE)
		ci.draw_colored_polygon(half_dome(Vector2(0, -12), 5.5, 4.0), SILHOUETTE)  # cap
		ci.draw_line(Vector2(0, -13), Vector2(7, -12), SILHOUETTE, 1.6)  # cap brim
		for i in 4:  # tentacles flapping in the wind
			var x0 := -3.6 + i * 2.4
			var wig := sin(k * 9.0 + i * 1.3) * 2.0
			ci.draw_polyline(PackedVector2Array([Vector2(x0, 7), Vector2(x0 + wig, 12), Vector2(x0 - wig * 0.6, 16)]), SILHOUETTE, 1.8)
		ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	dust(ci, W, H, 20.0 + lt)


const CARDS := {
	"commander": ["LT. COL. BARNACLE", "Air Cavalry, Fish Division"],
	"surfer": ["PVT. WAVES", "Only signed up for the surf"],
	"soldier": ["PVT. GULP", "First day. Misses his mom."],
	"cashier": ["THE CASHIER", "Late for his shift. Again."],
	"sticks": ["BARNACLE & GULP", "Golden brown. Extra crispy."],
}
const TYPE_START := 0.12   # seconds into the shot when typing begins
const TYPE_RATE := 34.0    # characters per second


static func card_start(who: String) -> float:
	return {"commander": T_CU_COMMANDER, "surfer": T_CU_SURFER, "soldier": T_CU_SOLDIER, "cashier": T_CU_CASHIER, "sticks": T_STICKS + 0.6}[who]


static func typed_count(lt: float) -> int:
	# How many characters of "name + subtitle" are visible lt seconds into the shot.
	return maxi(0, int((lt - TYPE_START) * TYPE_RATE))


static func name_card(ci: CanvasItem, font: Font, W: float, H: float, lt: float, who: String) -> void:
	var r := content_rect(W, H)
	var cards := CARDS
	var hold := 3.2
	var a := clampf((hold - lt) / 0.3, 0.0, 1.0)  # appears instantly (typed), fades out at the end
	var n := typed_count(lt)
	if a <= 0.0 or n <= 0:
		return
	var y := r.end.y + (H - r.end.y) * 0.5 + 10.0 if H - r.end.y > 50.0 else r.end.y - 30.0
	var name_: String = cards[who][0]
	var sub: String = "— " + cards[who][1]
	var shown_name := name_.substr(0, mini(n, name_.length()))
	var shown_sub := sub.substr(0, maxi(0, n - name_.length()))
	Toon.toon_text(ci, font, Vector2(W * 0.07, y), shown_name, 30, Color(1, 0.95, 0.85, a), HORIZONTAL_ALIGNMENT_LEFT, -1, 5, false)
	var nx := W * 0.07 + font.get_string_size(name_, HORIZONTAL_ALIGNMENT_LEFT, -1, 30).x + 22.0
	if shown_sub != "":
		Toon.toon_text(ci, font, Vector2(nx, y), shown_sub, 18, Color(1, 0.65, 0.35, a), HORIZONTAL_ALIGNMENT_LEFT, -1, 4, false)
	# blinking typing cursor
	if n < name_.length() + sub.length() or fmod(lt * 3.0, 1.0) < 0.5:
		var cx := W * 0.07 + font.get_string_size(shown_name, HORIZONTAL_ALIGNMENT_LEFT, -1, 30).x + 3.0
		var ch := 30.0
		if shown_sub != "":
			cx = nx + font.get_string_size(shown_sub, HORIZONTAL_ALIGNMENT_LEFT, -1, 18).x + 3.0
			ch = 18.0
		ci.draw_rect(Rect2(cx, y - ch * 0.78, ch * 0.45, ch * 0.85), Color(1, 0.95, 0.85, a * 0.85))


static func current_line(t: float) -> Array:
	# The dialogue line being spoken at time t (shown until the next line, max 2.6 s).
	var cur := []
	for i in DIALOGUE.size():
		var d: Array = DIALOGUE[i]
		var end: float = d[0] + 2.6
		if i + 1 < DIALOGUE.size():
			end = minf(end, DIALOGUE[i + 1][0] - 0.05)
		if t >= d[0] and t < end:
			cur = d
	return cur


static func subtitles(ci: CanvasItem, font: Font, W: float, H: float, g) -> void:
	var d := current_line(g.cine_t)
	if d.is_empty():
		return
	var r := content_rect(W, H)
	var speaker: String = d[1]
	var line: String = d[2]
	var shown: String = g.voice.shown_text() if g.voice.is_saying(line) else line
	var fs := 24
	var full := speaker + ":  " + line
	var w := font.get_string_size(full, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	var x := W / 2.0 - w / 2.0
	var y := r.end.y - 26.0
	Toon.toon_text(ci, font, Vector2(x, y), speaker + ":", fs, SPEAKER_COLORS.get(speaker, Color.WHITE), HORIZONTAL_ALIGNMENT_LEFT, -1, 5, false)
	var sx := x + font.get_string_size(speaker + ":  ", HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	Toon.toon_text(ci, font, Vector2(sx, y), shown, fs, Color(1, 0.97, 0.9), HORIZONTAL_ALIGNMENT_LEFT, -1, 5, false)


# ---------------------------------------------------------------- the crew alone in the cabin

static func draw_fish(ci: CanvasItem, who: String, tex: Texture2D, cx: float, bottom: float, size: float, t: float) -> void:
	var origin := Vector2(cx - size / 2.0, bottom - size)
	var pt := func(px: float, py: float) -> Vector2: return origin + Vector2(px, py) * size / 320.0
	var f := size / 320.0
	if who == "surfer":
		Toon.vgrad(ci, ellipse(pt.call(262, 175), 34 * f, 132 * f), Toon.INK, Toon.INK)
		Toon.vgrad(ci, ellipse(pt.call(262, 175), 30 * f, 128 * f), Color(1.0, 0.85, 0.2), Color(1.0, 0.45, 0.15))
		ci.draw_line(pt.call(262, 55), pt.call(262, 295), Color(0.85, 0.1, 0.15), 6.0 * f)
	ci.draw_texture_rect(tex, Rect2(origin, Vector2(size, size)), false, Color(0.92, 0.72, 0.62))
	props(ci, who, pt, f, t)


static func shot_cabin(ci: CanvasItem, W: float, H: float, lt: float, g) -> void:
	var r := content_rect(W, H)
	var t: float = g.cine_t
	var tilt := 0.0
	if t > 38.8:
		tilt = minf((t - 38.8) * 0.18, 0.32) * sin(minf((t - 38.8) * 2.0, PI * 0.5))
	sunset(ci, W, H, t, 1.9, 1.3, tilt)
	for i in 14:
		var y := r.position.y + fmod(i * 61.7, r.size.y)
		var x := W - fmod(t * (900.0 + i * 41.0) + i * 173.0, W + 400.0)
		ci.draw_line(Vector2(x, y), Vector2(x + 150 + (i % 3) * 50, y + tilt * 120.0), Color(1, 0.85, 0.65, 0.2), 2.0)
	var panic := 1.0 if t > 40.2 else 0.0
	var shake := Vector2(sin(t * 53.0), cos(t * 47.0)) * (3.0 + panic * 10.0 + (4.0 if t > 38.8 else 0.0))
	var size := r.size.y * 0.95
	var bottom := r.end.y + size * 0.16
	# Gulp (left), Barnacle (middle), Waves (right)
	draw_fish(ci, "soldier", g.cine_tex["soldier"], W * 0.27 + shake.x, bottom + shake.y + sin(t * 30.0) * 3.0, size * 0.9, t)
	draw_fish(ci, "commander", g.cine_tex["commander"], W * 0.5 + shake.x * 0.8, bottom + shake.y, size, t)
	draw_fish(ci, "surfer", g.cine_tex["surfer"], W * 0.72 + shake.x, bottom + shake.y, size * 0.95, t)
	# door frames
	ci.draw_colored_polygon(PackedVector2Array([Vector2(0, r.position.y), Vector2(W * 0.1, r.position.y), Vector2(W * 0.08, r.end.y), Vector2(0, r.end.y)]), Color(0.07, 0.06, 0.04))
	ci.draw_colored_polygon(PackedVector2Array([Vector2(W * 0.9, r.position.y), Vector2(W, r.position.y), Vector2(W, r.end.y), Vector2(W * 0.92, r.end.y)]), Color(0.07, 0.06, 0.04))
	ci.draw_rect(Rect2(0, r.position.y, W, r.size.y * 0.08), Color(0.07, 0.06, 0.04))
	# red alarm light once they realise nobody is flying
	if t > 37.1:
		var on := fmod(t * 2.5, 1.0) < 0.5
		ci.draw_circle(Vector2(W * 0.5, r.position.y + r.size.y * 0.05), 14.0, Color(1, 0.1, 0.05) if on else Color(0.35, 0.05, 0.03))
		if on:
			ci.draw_rect(Rect2(0, 0, W, H), Color(1, 0.05, 0.0, 0.16))


# ---------------------------------------------------------------- crash into the giant fryer

static func crash_path(lt: float, W: float, r: Rect2, fryer_top: Vector2) -> Vector2:
	var k := clampf(lt / CRASH_IMPACT, 0.0, 1.0)
	var start := Vector2(W * 0.12, r.position.y + r.size.y * 0.2)
	var p := start.lerp(fryer_top, k * k)
	p += Vector2(sin(k * 9.0) * 40.0, cos(k * 9.0) * 25.0) * (1.0 - k)  # spiralling
	return p


static func shot_crash(ci: CanvasItem, W: float, H: float, lt: float) -> void:
	var r := content_rect(W, H)
	var t := T_CRASH + lt
	var hy := sunset(ci, W, H, t, 1.25, 1.1)
	# giant deep fryer on a little platform out at sea
	var fx := W * 0.66
	var fw := W * 0.17
	var fh := r.size.y * 0.2
	ci.draw_colored_polygon(PackedVector2Array([Vector2(fx - fw * 0.9, hy + 6), Vector2(fx + fw * 0.9, hy + 6), Vector2(fx + fw * 0.7, hy - 10), Vector2(fx - fw * 0.7, hy - 10)]), SILHOUETTE)
	var body := Rect2(fx - fw / 2.0, hy - 10 - fh, fw, fh)
	ci.draw_rect(body, Color(0.2, 0.12, 0.12))
	ci.draw_rect(Rect2(body.position, Vector2(fw * 0.12, fh)), Color(0.5, 0.25, 0.15))  # sunset glint
	ci.draw_rect(Rect2(body.position + Vector2(fw * 0.2, fh * 0.35), Vector2(fw * 0.6, fh * 0.18)), Color(0.12, 0.07, 0.07))
	var oil_c := Vector2(fx, body.position.y)
	ci.draw_colored_polygon(ellipse(oil_c, fw * 0.48, 10.0), Color(1.0, 0.72, 0.15))
	for i in 7:
		var bx := oil_c.x + sin(t * 3.0 + i * 2.1) * fw * 0.38
		ci.draw_circle(Vector2(bx, oil_c.y - 2 - fmod(t * 20.0 + i * 7.0, 6.0)), 3.0, Color(1, 0.9, 0.5, 0.8))
	# basket handle sticking out
	ci.draw_line(Vector2(fx + fw * 0.4, oil_c.y - 4), Vector2(fx + fw * 0.85, oil_c.y - fh * 0.45), Color(0.15, 0.12, 0.12), 6.0)
	# steam
	for i in 6:
		var sy := fmod(t * 30.0 + i * 22.0, 90.0)
		ci.draw_circle(oil_c + Vector2(sin(t + i) * 30.0 - 40.0 + i * 16.0, -sy), 10.0 + sy * 0.25, Color(1, 0.95, 0.9, 0.18 * (1.0 - sy / 90.0)))
	var top := oil_c + Vector2(0, -6)
	if lt < CRASH_IMPACT:
		# black smoke trail behind the falling helicopter
		for k in range(14, 0, -1):
			var tau := lt - k * 0.07
			if tau < 0.0:
				continue
			var sp := crash_path(tau, W, r, top) + Vector2(sin(k * 1.7) * 6.0, -k * 2.0)
			ci.draw_circle(sp, 6.0 + k * 2.2, Color(0.1, 0.08, 0.08, 0.6 - k * 0.035))
		var p := crash_path(lt, W, r, top)
		heli(ci, p, 0.32 + lt * 0.05, SILHOUETTE, t, lt * 3.2, 1.0)
		# sputtering engine sparks
		if fmod(lt * 7.0, 1.0) < 0.4:
			ci.draw_circle(p + Vector2(20, -10), 6.0, Color(1, 0.6, 0.1, 0.9))
	else:
		var e := lt - CRASH_IMPACT
		# fireball
		for k in 5:
			var rr := (40.0 + k * 34.0) * minf(e * 3.0, 1.0)
			ci.draw_circle(top + Vector2(0, -rr * 0.4), rr, Color([Color(1, 0.95, 0.6), Color(1, 0.7, 0.2), Color(1, 0.45, 0.1), Color(0.8, 0.2, 0.05), Color(0.3, 0.1, 0.05)][k], clampf(0.9 - e * 0.8, 0.0, 0.9) * (1.0 - k * 0.12)))
		# golden oil splash
		for i in 40:
			var a := -PI * (0.1 + 0.8 * fmod(i * 0.618, 1.0))
			var v := 220.0 + fmod(i * 37.0, 200.0)
			var d := top + Vector2(cos(a), sin(a)) * v * e + Vector2(0, 420.0 * e * e)
			ci.draw_circle(d, 3.0 + (i % 4), Color(1.0, 0.8, 0.25, clampf(1.0 - e * 0.7, 0.0, 1.0)))
	dust(ci, W, H, t)


# ---------------------------------------------------------------- the result

static func shot_sticks(ci: CanvasItem, W: float, H: float, lt: float) -> void:
	var r := content_rect(W, H)
	ci.draw_rect(r, Color(0.97, 0.97, 0.96))
	var z := 1.0 + 0.06 * clampf(lt / (T_3D - T_STICKS), 0.0, 1.0)  # slow push-in
	var aspect := float(FISHSTICKS.get_width()) / FISHSTICKS.get_height()
	var h := r.size.y * z
	var w := h * aspect
	var c := r.get_center()
	ci.draw_texture_rect(FISHSTICKS, Rect2(c - Vector2(w, h) / 2.0, Vector2(w, h)), false)
	# fresh-out-of-the-fryer steam
	for i in 9:
		var sy := fmod(lt * 45.0 + i * 37.0, 160.0)
		var sx := c.x - w * 0.35 + i * w * 0.09 + sin(lt * 1.5 + i) * 12.0
		ci.draw_circle(Vector2(sx, c.y - sy * 1.2), 14.0 + sy * 0.25, Color(1, 1, 1, 0.22 * (1.0 - sy / 160.0)))
