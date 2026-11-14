extends Node2D
## 30 s unskippable dance break (opened from the pause menu): the pufferfish cashier as a stick
## figure on a disco floor, dancing to the game's music stems at 95 BPM. Fully procedural.
## Poses are keyframes on the beat; the figure is grounded automatically (lowest foot on the floor).

signal finished

const Toon := preload("res://scripts/toon_ui.gd")
const FONT_FILE := preload("res://assets/fonts/Fredoka.ttf")
const MUSIC_STEMS := ["res://assets/music/bass.wav", "res://assets/music/drums.wav", "res://assets/music/mullet.wav", "res://assets/music/keys.wav"]
const BPM := 95.0
const LOOP_BEATS := 8
const STEM_IN_BEAT := [0.0, 0.0, 8.0, 16.0]  # bass + drums from the start, then the rest join in
const DURATION := 30.0
const FADE_IN := 0.4
const FADE_OUT := 0.7

# bone lengths (scaled by k)
const UPPER_ARM := 56.0
const FOREARM := 50.0
const THIGH := 54.0
const SHIN := 54.0
const HIP_W := 20.0  # legs attach left/right of the body's bottom
const BODY_SCALE := 0.9  # the pufferfish body (radius 64 * this)
const LIMB := Color(0.51, 0.44, 0.3)  # cashier body colour, darkened

# Pose angles in radians. Limbs: 0 = pointing down, +PI/2 = pointing right (screen), PI = up.
# Arms are relative to the body, forearms/shins relative to their upper bone, thighs absolute.
# torso = body lean around the hips. face: 0 grumpy, 1 happy, 2 wild.
const DEFAULT := {"torso": 0.0, "head": 0.0, "lua": -0.25, "lla": 0.0, "rua": 0.25, "rla": 0.0,
	"lth": -0.1, "lsh": 0.0, "rth": 0.1, "rsh": 0.0, "hx": 0.0, "lift": 0.0, "face": 1.0}
const POSES := {
	"stand": {"face": 0.0},
	"look_l": {"head": -0.3, "torso": -0.04, "face": 0.0},
	"look_r": {"head": 0.3, "torso": 0.04, "face": 0.0},
	"shrug": {"lua": -1.0, "lla": -0.8, "rua": 1.0, "rla": 0.8, "head": 0.15, "face": 0.0},
	# groove: one arm folded across the belly, the other out with the forearm up, knees popping
	"groove_a": {"torso": -0.12, "head": 0.15, "lua": -0.6, "lla": 2.1, "rua": 1.45, "rla": 0.8, "lth": -0.12, "rth": 0.15, "hx": -14.0},
	"groove_b": {"torso": 0.14, "head": -0.12, "lua": -0.5, "lla": 2.2, "rua": 1.2, "rla": 1.3, "lth": -0.45, "lsh": 0.75, "rth": 0.35, "rsh": -0.6, "hx": 14.0},
	# arms swinging over the head
	"wave_l": {"torso": 0.25, "head": 0.25, "lua": -2.5, "lla": -0.3, "rua": 0.5, "rla": 0.3, "lth": -0.08, "rth": 0.3, "rsh": -0.45, "hx": -22.0},
	"wave_r": {"torso": -0.25, "head": -0.25, "lua": -0.5, "lla": -0.3, "rua": 2.5, "rla": 0.3, "lth": -0.3, "lsh": 0.45, "rth": 0.08, "hx": 22.0},
	# deep forward bend, head banging, arms dangling
	"bang_a": {"torso": 0.85, "head": 0.2, "lua": -1.0, "lla": 0.3, "rua": -0.7, "rla": 0.4, "hx": -26.0, "lth": -0.3, "lsh": 0.5, "rth": 0.2, "rsh": -0.1, "face": 2.0},
	"bang_b": {"torso": 1.35, "head": 0.6, "lua": -1.5, "lla": 0.6, "rua": -1.2, "rla": 0.7, "hx": -34.0, "lth": -0.45, "lsh": 0.8, "rth": 0.3, "rsh": -0.3, "face": 2.0},
	# side shuffle: elbows out, alternating kicks, travelling left and right
	"shuf_l": {"torso": -0.18, "head": 0.2, "lua": -1.5, "lla": 1.3, "rua": 1.5, "rla": -1.3, "lth": -1.0, "lsh": 0.45, "rth": 0.1, "hx": 40.0, "lift": 12.0},
	"shuf_mid": {"lua": -1.4, "lla": 1.5, "rua": 1.4, "rla": -1.5, "lth": -0.35, "lsh": 0.6, "rth": 0.35, "rsh": -0.6},
	"shuf_r": {"torso": 0.18, "head": -0.2, "lua": -1.5, "lla": 1.3, "rua": 1.5, "rla": -1.3, "lth": -0.1, "rth": 1.0, "rsh": -0.45, "hx": -40.0, "lift": 12.0},
	# disco point: hand on the hip, point up, point down
	"point_up": {"torso": -0.2, "head": -0.35, "rua": 2.55, "rla": 0.1, "lua": -0.9, "lla": 2.3, "lth": -0.25, "rth": 0.15, "hx": 18.0},
	"point_down": {"torso": 0.18, "head": 0.3, "rua": -0.5, "rla": -0.1, "lua": -0.9, "lla": 2.3, "lth": -0.4, "lsh": 0.55, "rth": 0.2, "rsh": -0.2, "hx": -12.0},
	# going wild: arms flailing everywhere
	"flail_a": {"torso": -0.3, "head": 0.4, "lua": -2.7, "lla": 1.6, "rua": 0.6, "rla": -1.9, "lth": -0.5, "lsh": 0.3, "rth": 0.2, "hx": -18.0, "lift": 14.0, "face": 2.0},
	"flail_b": {"torso": 0.3, "head": -0.4, "lua": -0.6, "lla": 1.9, "rua": 2.7, "rla": -1.6, "lth": -0.2, "rth": 0.5, "rsh": -0.3, "hx": 18.0, "face": 2.0},
	"flail_c": {"torso": -0.1, "head": 0.2, "lua": -1.9, "lla": -1.2, "rua": 1.1, "rla": 1.8, "lth": -0.6, "lsh": 0.9, "rth": 0.6, "rsh": -0.9, "lift": 4.0, "face": 2.0},
	"flail_d": {"torso": 0.1, "head": -0.2, "lua": -1.1, "lla": -1.8, "rua": 1.9, "rla": 1.2, "lth": -0.15, "rth": 0.15, "lift": 22.0, "face": 2.0},
	# full spin in the air (torso goes 0 -> TAU; a reset key snaps it back to 0 invisibly)
	"spin_a": {"lua": -0.5, "lla": 0.4, "rua": 0.5, "rla": -0.4, "lth": -0.6, "lsh": 1.1, "rth": 0.6, "rsh": -1.1, "face": 2.0},
	"spin_b": {"torso": PI, "lua": -1.6, "rua": 1.6, "lth": -0.3, "lsh": 0.6, "rth": 0.3, "rsh": -0.6, "lift": 55.0, "face": 2.0},
	"spin_c": {"torso": TAU, "lua": -2.3, "lla": -0.3, "rua": 2.3, "rla": 0.3, "lth": -0.4, "lsh": 0.5, "rth": 0.4, "rsh": -0.5, "face": 2.0},
	"spin_reset": {"lua": -2.3, "lla": -0.3, "rua": 2.3, "rla": 0.3, "lth": -0.4, "lsh": 0.5, "rth": 0.4, "rsh": -0.5, "face": 2.0},
	# split jump
	"split_air": {"lua": -2.2, "lla": -0.3, "rua": 2.2, "rla": 0.3, "lth": -1.45, "rth": 1.45, "lift": 80.0, "face": 2.0},
	# finale
	"crouch": {"torso": 0.1, "head": 0.2, "lua": -0.5, "lla": 0.3, "rua": 0.5, "rla": -0.3, "lth": -0.7, "lsh": 1.2, "rth": 0.7, "rsh": -1.2},
	"tada_air": {"lua": -2.2, "lla": -0.35, "rua": 2.2, "rla": 0.35, "lth": -0.35, "rth": 0.35, "lift": 70.0, "head": -0.1, "face": 2.0},
	"tada": {"lua": -2.2, "lla": -0.35, "rua": 2.2, "rla": 0.35, "lth": -0.4, "rth": 0.4},
}
const SPIN := ["spin_a", "spin_b", "spin_c"]
const SHUF := ["shuf_l", "shuf_mid", "shuf_r", "shuf_mid"]
const FLAIL := ["flail_a", "flail_c", "flail_b", "flail_d"]
# [start beat, beats per pose, pose names (cycled), number of keys] - 47.5 beats = 30 s at 95 BPM
const ROUTINE := [
	[0.0, 1.0, ["stand", "look_l", "look_r", "shrug"], 4],
	[4.0, 0.5, ["groove_a", "groove_b"], 8],
	[8.0, 0.5, ["wave_l", "wave_r"], 8],
	[12.0, 0.5, SPIN, 3], [13.001, 1.0, ["spin_reset"], 1],
	[13.5, 0.25, FLAIL, 10],
	[16.0, 0.25, ["bang_a", "bang_b"], 16],
	[20.0, 0.25, SHUF, 16],
	[24.0, 0.5, ["crouch", "split_air", "crouch"], 3],
	[25.5, 0.5, ["point_up", "point_down"], 8],
	[29.5, 0.5, SPIN, 3], [30.501, 1.0, ["spin_reset"], 1],
	[31.0, 0.25, FLAIL, 12],
	[34.0, 0.25, ["bang_a", "bang_b"], 12],
	[37.0, 0.5, ["groove_a", "groove_b"], 4],
	[39.0, 0.5, ["wave_l", "wave_r"], 4],
	[41.0, 0.25, SHUF, 8],
	[43.0, 0.5, SPIN, 3], [44.001, 1.0, ["spin_reset"], 1],
	[44.5, 0.75, ["crouch", "tada_air"], 2],
	[46.0, 1.0, ["tada"], 1],
]

var el := 0.0  # seconds since start
var W := 1152.0
var H := 648.0
var font: Font
var keys: Array = []  # [{beat, pose}]
var player: AudioStreamPlayer
var stream: AudioStreamSynchronized
var done := false
var cam := Transform2D.IDENTITY


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	var fv := FontVariation.new()
	fv.base_font = FONT_FILE
	var ts := TextServerManager.get_primary_interface()
	fv.variation_opentype = {ts.name_to_tag("wght"): 650}
	font = fv
	for seg in ROUTINE:
		var names: Array = seg[2]
		for i in int(seg[3]):
			var p := DEFAULT.duplicate()
			p.merge(POSES[names[i % names.size()]], true)
			keys.append({"beat": float(seg[0]) + i * float(seg[1]), "pose": p})
	stream = AudioStreamSynchronized.new()
	stream.stream_count = MUSIC_STEMS.size()
	var loop_samples := int(round(LOOP_BEATS * 60.0 / BPM * 44100.0))
	for i in MUSIC_STEMS.size():
		var w: AudioStreamWAV = load(MUSIC_STEMS[i]).duplicate()
		w.loop_mode = AudioStreamWAV.LOOP_FORWARD
		w.loop_begin = 0
		w.loop_end = loop_samples
		stream.set_sync_stream(i, w)
		stream.set_sync_stream_volume(i, 0.0 if STEM_IN_BEAT[i] <= 0.0 else -60.0)
	player = AudioStreamPlayer.new()
	player.stream = stream
	player.volume_db = -5.0
	add_child(player)
	player.play()


func beat() -> float:
	return el * BPM / 60.0


func _process(delta: float) -> void:
	el += delta
	var s := get_viewport_rect().size
	W = s.x
	H = s.y
	var b := beat()
	for i in MUSIC_STEMS.size():
		if STEM_IN_BEAT[i] > 0.0 and b >= STEM_IN_BEAT[i]:
			var v := clampf((b - STEM_IN_BEAT[i]) / 1.0, 0.0, 1.0)
			stream.set_sync_stream_volume(i, lerpf(-40.0, 0.0, v))
	var out_k := clampf((el - (DURATION - FADE_OUT)) / FADE_OUT, 0.0, 1.0)
	player.volume_db = -5.0 - 40.0 * out_k * out_k
	if el >= DURATION and not done:
		done = true
		player.stop()
		finished.emit()
	queue_redraw()


# ---------------------------------------------------------------- pose

func pose_at(b: float) -> Dictionary:
	if b <= keys[0]["beat"]:
		return keys[0]["pose"]
	for i in range(keys.size() - 1):
		var k0: Dictionary = keys[i]
		var k1: Dictionary = keys[i + 1]
		if b < k1["beat"]:
			var f: float = (b - k0["beat"]) / (k1["beat"] - k0["beat"])
			f = 1.0 - pow(1.0 - f, 2.6)  # snap into each pose, then hold
			var out := {}
			for key in k0["pose"]:
				out[key] = lerpf(k0["pose"][key], k1["pose"][key], f)
			return out
	return keys[-1]["pose"]


static func dirv(a: float) -> Vector2:
	return Vector2(sin(a), cos(a))


# ---------------------------------------------------------------- drawing

func _draw() -> void:
	var b := beat()
	var pulse := exp(-fmod(b, 1.0) * 6.0) if b >= 4.0 else 0.0
	var wild := float(pose_at(b)["face"]) > 1.5
	var zoom := 1.0 + (0.045 if wild else 0.02) * pulse
	var tilt := sin(el * 9.0) * 0.025 if wild else 0.0
	var jolt := Vector2(sin(el * 53.0), cos(el * 41.0)) * (5.0 * pulse if wild else 0.0)
	var c := Vector2(W, H) / 2.0
	cam = Transform2D(0.0, c + jolt) * Transform2D(tilt, Vector2(zoom, zoom), 0.0, Vector2.ZERO) * Transform2D(0.0, -c)
	draw_set_transform_matrix(cam)
	var floor_y := H * 0.78
	draw_stage(b, pulse, floor_y)
	draw_dancer(b, floor_y)
	draw_notes(b)
	draw_set_transform_matrix(Transform2D.IDENTITY)
	if wild:
		draw_rect(Rect2(0, 0, W, H), Color(1, 0.6, 0.95, 0.12 * pulse))
	# 21:9 letterbox, sliding in
	var bar := maxf(0.0, (H - W / 2.37) / 2.0) * clampf(el / 0.8, 0.0, 1.0)
	draw_rect(Rect2(0, 0, W, bar), Color.BLACK)
	draw_rect(Rect2(0, H - bar, W, bar), Color.BLACK)
	# title card
	if b < 4.0:
		var a := clampf(b / 0.3, 0.0, 1.0) * clampf((4.0 - b) / 0.5, 0.0, 1.0)
		var sc := 1.0 + 0.15 * exp(-b * 4.0)
		draw_set_transform(Vector2(W / 2, H - bar - 22), 0.0, Vector2(sc, sc))
		Toon.toon_text(self, font, Vector2(-W / 2, 0), "BREAK TIME!", 52, Color(Toon.GOLD, a), HORIZONTAL_ALIGNMENT_CENTER, W)
		draw_set_transform_matrix(Transform2D.IDENTITY)
	# fades
	var fade := 1.0 - clampf(el / FADE_IN, 0.0, 1.0)
	fade = maxf(fade, clampf((el - (DURATION - FADE_OUT)) / FADE_OUT, 0.0, 1.0))
	if fade > 0.0:
		draw_rect(Rect2(0, 0, W, H), Color(0, 0, 0, fade))


func draw_stage(b: float, pulse: float, floor_y: float) -> void:
	# back wall
	var full := PackedVector2Array([Vector2(-40, -40), Vector2(W + 40, -40), Vector2(W + 40, H + 40), Vector2(-40, H + 40)])
	Toon.vgrad(self, full, Color(0.12, 0.05, 0.3), Color(0.02, 0.02, 0.1))
	for k in 6:
		draw_circle(Vector2(W * 0.5, floor_y - 120), 120.0 + k * 70.0, Color(0.6, 0.3, 1.0, 0.03 + 0.02 * pulse))
	# swinging spotlights
	var cols := [Color(1, 0.3, 0.7), Color(0.3, 0.9, 1.0), Color(1, 0.85, 0.3)]
	for i in 3:
		var top := Vector2(W * (0.2 + 0.3 * i), -20)
		var ang := sin(el * (0.9 + i * 0.3) + i * 2.0) * 0.45
		var tip := top + Vector2(sin(ang), cos(ang)) * (floor_y + 40)
		var side := Vector2(cos(ang), -sin(ang)) * 110.0
		var col: Color = cols[(i + int(b)) % 3] if b >= 4.0 else cols[i]
		draw_colored_polygon(PackedVector2Array([top - side * 0.1, top + side * 0.1, tip + side, tip - side]), Color(col, 0.10 + 0.05 * pulse))
		draw_colored_polygon(Toon.ellipse(tip, 110, 22), Color(col, 0.12 + 0.08 * pulse))
	# dance floor tiles (perspective)
	var rows := 4
	var cols_n := 9
	var depth := H - floor_y + 40
	for r in rows:
		var y0 := floor_y - 8 + depth * pow(float(r) / rows, 1.4)
		var y1 := floor_y - 8 + depth * pow(float(r + 1) / rows, 1.4)
		var spread0 := 1.0 + r * 0.25
		var spread1 := 1.0 + (r + 1) * 0.25
		for c in cols_n:
			var u0 := (c / float(cols_n) - 0.5) * W
			var u1 := ((c + 1) / float(cols_n) - 0.5) * W
			var quad := PackedVector2Array([
				Vector2(W / 2 + u0 * spread0, y0), Vector2(W / 2 + u1 * spread0, y0),
				Vector2(W / 2 + u1 * spread1, y1), Vector2(W / 2 + u0 * spread1, y1)])
			var lit := ((c + r + int(b)) % 3 == 0) and b >= 4.0
			var tc: Color = cols[(c + r) % 3]
			var base := Color(0.08, 0.06, 0.2)
			draw_colored_polygon(quad, base.lerp(tc, 0.55 + 0.3 * pulse) if lit else base.lerp(tc, 0.12))
			draw_polyline(PackedVector2Array([quad[0], quad[1], quad[2], quad[3], quad[0]]), Color(0, 0, 0, 0.5), 2.0)
	# disco ball
	var bar := maxf(0.0, (H - W / 2.37) / 2.0)  # keep the ball below the letterbox
	var bc := Vector2(W / 2, bar + 40)
	draw_line(Vector2(bc.x, -40), bc, Color(0.6, 0.6, 0.7), 3)
	draw_circle(bc, 34, Color(0.75, 0.78, 0.85))
	for i in 7:
		for j in 7:
			var fx := (i - 3) * 9.0 + fmod(el * 14.0, 9.0)
			var fy := (j - 3) * 9.0
			if Vector2(fx, fy).length() < 30.0:
				var shade := 0.6 + 0.4 * sin(i * 1.7 + j * 2.3 + el * 3.0)
				draw_rect(Rect2(bc + Vector2(fx - 3.5, fy - 3.5), Vector2(7, 7)), Color(shade, shade, shade + 0.1))
	for i in 10:
		var a := el * 0.8 + i * TAU / 10.0
		var p := bc + Vector2(cos(a) * (200 + (i % 3) * 140), 120 + sin(a * 1.3 + i) * 90 + (i % 4) * 70)
		draw_circle(p, 3.0 + 2.0 * pulse, Color(1, 1, 1, 0.5))


func draw_dancer(b: float, floor_y: float) -> void:
	var p := pose_at(b)
	var k := H / 560.0
	var tl: float = p["torso"]
	var rot: float = tl + float(p["head"]) * 0.6
	var face := int(round(float(p["face"])))
	var side := Vector2(cos(tl), sin(tl))  # the hip line turns with the body
	# legs first, to find out how high the hips must be so the lowest foot touches the floor
	var lhip := -side * HIP_W * k
	var rhip := side * HIP_W * k
	# legs normally stay planted (absolute angles), but turn with the body during a spin
	var spin := smoothstep(1.4, 2.2, tl) * tl
	var lth: float = float(p["lth"]) + spin
	var rth: float = float(p["rth"]) + spin
	var lk := lhip + dirv(lth) * THIGH * k
	var lf := lk + dirv(lth + float(p["lsh"])) * SHIN * k
	var rk := rhip + dirv(rth) * THIGH * k
	var rf := rk + dirv(rth + float(p["rsh"])) * SHIN * k
	var hx: float = p["hx"]
	var lift: float = p["lift"]
	# lowest point: a foot, or the body itself when he's upside down
	var body_low := -cos(tl) * 56.0 * BODY_SCALE * k + 70.0 * BODY_SCALE * k
	var hip := Vector2(W / 2 + hx * k, floor_y - maxf(maxf(lf.y, rf.y), body_low) - lift * k)
	if face == 2:
		hip += Vector2(sin(el * 61.0), cos(el * 47.0)) * 2.5 * k  # vibrating with excitement
	# shadow
	var sh_w := 80.0 * k * (1.0 - clampf(lift / 120.0, 0.0, 0.6))
	draw_colored_polygon(Toon.ellipse(Vector2(hip.x, floor_y + 4), sh_w, 12 * k), Color(0, 0, 0, 0.35))
	var bs := BODY_SCALE * k
	var up := Vector2(sin(tl), -cos(tl))
	var centre := hip + up * 56.0 * bs
	var body_x := Vector2(cos(rot), sin(rot))
	var body_y := Vector2(-sin(rot), cos(rot))
	var lsh_pt := centre - body_x * 60.0 * bs + body_y * 10.0 * bs
	var rsh_pt := centre + body_x * 60.0 * bs + body_y * 10.0 * bs
	var la: float = rot + float(p["lua"])
	var ra: float = rot + float(p["rua"])
	var le := lsh_pt + dirv(la) * UPPER_ARM * k
	var lh := le + dirv(la + float(p["lla"])) * FOREARM * k
	var re := rsh_pt + dirv(ra) * UPPER_ARM * k
	var rh := re + dirv(ra + float(p["rla"])) * FOREARM * k
	var legs := [[hip + lhip, hip + lk, hip + lf], [hip + rhip, hip + rk, hip + rf]]
	var arms := [[lsh_pt, le, lh], [rsh_pt, re, rh]]
	stick(legs, k)
	for f in [[hip + lf, -1.0], [hip + rf, 1.0]]:
		var fp: Vector2 = f[0]
		draw_colored_polygon(Toon.ellipse(fp + Vector2(f[1] * 8 * k, 2 * k), 16 * k, 9 * k), Toon.INK)
		draw_colored_polygon(Toon.ellipse(fp + Vector2(f[1] * 8 * k, 1 * k), 12 * k, 6 * k), Color(0.85, 0.2, 0.2))
	# body = the pufferfish cashier
	draw_set_transform_matrix(cam * Transform2D(rot, Vector2(bs, bs), 0.0, centre))
	draw_puffer(face)
	draw_set_transform_matrix(cam)
	# arms on the left and right of the body, in front of it
	stick(arms, k)
	for h in [lh, rh]:
		draw_circle(h, 10 * k, Toon.INK)
		draw_circle(h, 7 * k, Color(1, 1, 1))


func stick(limbs: Array, k: float) -> void:
	var w := 9.0 * k
	for pass_ in 2:
		var width := w + (6.0 * k if pass_ == 0 else 0.0)
		var col := Toon.INK if pass_ == 0 else LIMB
		for l in limbs:
			var pts := PackedVector2Array(l)
			draw_polyline(pts, col, width, false)
			for q in pts:
				draw_circle(q, width / 2.0, col)


func draw_puffer(face: int) -> void:
	# Same look as the in-game cashier (character_art.gd), centred on the body. No fins: arms instead.
	var body := Color(0.93, 0.8, 0.55)
	var puff := 1.0 + (0.06 * sin(el * 30.0) if face == 2 else 0.0)  # puffs up when he goes wild
	for i in 16:
		var ang := TAU * i / 16.0
		var d := Vector2(cos(ang), sin(ang))
		var perp := Vector2(-d.y, d.x)
		var sp := 80.0 * puff + (8.0 if face == 2 else 0.0)
		draw_colored_polygon(PackedVector2Array([d * 57 + perp * 9, d * 57 - perp * 9, d * sp]), body.darkened(0.3))
	draw_colored_polygon(Toon.ellipse(Vector2(0, 0), 68 * puff, 66 * puff), Toon.INK)
	draw_colored_polygon(Toon.ellipse(Vector2(0, 0), 64 * puff, 62 * puff), body)
	draw_colored_polygon(Toon.ellipse(Vector2(0, 26), 42, 26), body.lightened(0.35))
	# apron + name tag
	draw_colored_polygon(PackedVector2Array([Vector2(-34, 20), Vector2(34, 20), Vector2(40, 52), Vector2(-40, 52)]), Color(0.96, 0.96, 0.96))
	draw_rect(Rect2(10, 26, 18, 9), Color(0.35, 0.6, 0.95))
	for ex in [-22.0, 22.0]:
		var e := Vector2(ex, -14)
		match face:
			0:  # grumpy: heavy eyelids
				draw_colored_polygon(Toon.ellipse(e, 14, 15), Color.WHITE)
				draw_colored_polygon(Toon.ellipse(e + Vector2(sin(el * 2.0) * 3.0, 5.0), 5.5, 5.5), Color(0.05, 0.05, 0.1))
				var lid := PackedVector2Array()
				for i in 13:
					var a := PI + PI * i / 12.0
					lid.append(e + Vector2(0, 2) + Vector2(cos(a) * 15.5, sin(a) * 16.5))
				draw_colored_polygon(lid, body.darkened(0.12))
				draw_line(e + Vector2(-15, 2), e + Vector2(15, 2), body.darkened(0.5), 3)
			1:  # happy closed eyes
				draw_arc(e + Vector2(0, 6), 11, PI + 0.3, TAU - 0.3, 12, Color(0.05, 0.05, 0.1), 4)
			_:  # wild: huge eyes, tiny spinning pupils
				draw_colored_polygon(Toon.ellipse(e, 18, 19), Color.WHITE)
				draw_arc(e, 18, 0, TAU, 24, Toon.INK, 2.5)
				var sp := Vector2(cos(el * 14.0 * signf(ex)), sin(el * 14.0 * signf(ex))) * 8.0
				draw_colored_polygon(Toon.ellipse(e + sp, 4.5, 4.5), Color(0.05, 0.05, 0.1))
	match face:
		0:
			draw_arc(Vector2(0, 18), 15, PI + 0.45, TAU - 0.45, 14, Color(0.35, 0.1, 0.1), 4)
		1:
			draw_arc(Vector2(0, 10), 16, 0.35, PI - 0.35, 14, Color(0.35, 0.1, 0.1), 4)
		_:
			# wide open screaming grin with a tongue
			var m := PackedVector2Array()
			for i in 15:
				var a := PI * i / 14.0
				m.append(Vector2(cos(a) * 22.0, 4.0 + sin(a) * 22.0))
			draw_colored_polygon(m, Color(0.35, 0.05, 0.08))
			draw_colored_polygon(Toon.ellipse(Vector2(0, 19), 10, 6), Color(1.0, 0.45, 0.5))
			draw_polyline(m + PackedVector2Array([m[0]]), Toon.INK, 3.0)
	# cap (flies up a little when he's wild)
	var red := Color(0.85, 0.2, 0.2)
	var cap_y := -60.0 - (6.0 + 4.0 * sin(el * 25.0) if face == 2 else 0.0)
	draw_colored_polygon(Toon.ellipse(Vector2(0, cap_y), 42, 16), red)
	draw_colored_polygon(Toon.ellipse(Vector2(0, cap_y + 11), 46, 7), red.darkened(0.3))


func draw_notes(b: float) -> void:
	if b < 4.0:
		return
	for i in 6:
		var life := fmod(el * 0.5 + i / 6.0, 1.0)
		var x := W * (0.15 + 0.7 * fmod(i * 0.37, 1.0)) + sin(el * 2.0 + i) * 20.0
		var y := H * 0.75 - life * H * 0.55
		var a := sin(life * PI)
		var nc: Color = [Toon.GOLD, Toon.CYAN, Color(1, 0.4, 0.8)][i % 3]
		var col := Color(nc, a)
		draw_circle(Vector2(x, y), 9, Color(Toon.INK, a))
		draw_circle(Vector2(x, y), 6.5, col)
		draw_line(Vector2(x + 6, y), Vector2(x + 6, y - 30), Color(Toon.INK, a), 5)
		draw_line(Vector2(x + 6, y), Vector2(x + 6, y - 30), col, 2.5)
		draw_line(Vector2(x + 6, y - 30), Vector2(x + 16, y - 20), col, 3)
