extends Node2D
## 2D overlay on top of the 3D restaurant, in a glossy underwater 3D-cartoon style (all procedural).
## HUD, speech/thought bubbles, minigame UIs, popups, title, countdown, game over window.

const Toon := preload("res://scripts/toon_ui.gd")
const Cine := preload("res://scripts/cinematic.gd")
const FONT_FILE := preload("res://assets/fonts/Fredoka.ttf")
const LOGO := preload("res://assets/logo.png")

# Mirrors game.gd's State enum
const S_TALK := 0
const S_DECIDE := 1
const S_ATTACK := 2
const S_FLIP := 3
const S_DANCE := 4
const S_PRAY := 5
const S_GAME_OVER := 8
const S_TITLE := 9
const S_BLACKOUT := 10
const S_INTRO := 11
const S_COUNTDOWN := 12
const S_CINEMA := 13

const STAR_SCORES := [100, 600, 2000]  # game over rating: 1 / 2 / 3 stars

var game  # the 3D game root (game.gd)
var W := 1152.0
var H := 648.0
var font: Font

# game over buttons: {label, action, color, rect, hover, press, vel}
var buttons: Array = []
var selected := 0
var mouse_was_down := false
var pressed_idx := -1
var activating := false


func _ready() -> void:
	var fv := FontVariation.new()
	fv.base_font = FONT_FILE
	var ts := TextServerManager.get_primary_interface()
	fv.variation_opentype = {ts.name_to_tag("wght"): 650}
	font = fv
	buttons = [
		{"label": "TRY AGAIN", "action": "retry", "color": Color(0.3, 0.85, 0.2)},
		{"label": "MENU", "action": "menu", "color": Color(0.2, 0.6, 1.0)},
	]
	for b in buttons:
		b["rect"] = Rect2()
		b["hover"] = 0.0
		b["press"] = 0.0
		b["vel"] = 0.0


func _process(delta: float) -> void:
	var s := get_viewport_rect().size
	W = s.x
	H = s.y
	if game != null and game.state == S_GAME_OVER:
		update_buttons(delta)
	queue_redraw()


# ---------------------------------------------------------------- game over buttons

func update_buttons(delta: float) -> void:
	var mp := get_viewport().get_mouse_position()
	var down := Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT)
	if not activating:
		if Input.is_action_just_pressed("ui_left"):
			selected = posmod(selected - 1, buttons.size())
		if Input.is_action_just_pressed("ui_right"):
			selected = posmod(selected + 1, buttons.size())
	for i in buttons.size():
		var b: Dictionary = buttons[i]
		var over: bool = b["rect"].has_point(mp)
		if over and not activating:
			selected = i
		if over and down and not mouse_was_down and not activating:
			pressed_idx = i
		# hover glow
		var target_hover := 1.0 if i == selected else 0.0
		b["hover"] = lerpf(b["hover"], target_hover, 1.0 - exp(-14.0 * delta))
		# press: held -> sink in, released -> spring back with a little overshoot
		var target_press := 1.0 if (pressed_idx == i and down and over) else 0.0
		b["vel"] = (b["vel"] + (target_press - b["press"]) * 900.0 * delta) * exp(-22.0 * delta)
		b["press"] += b["vel"] * delta
	if pressed_idx >= 0 and not down and mouse_was_down:
		if buttons[pressed_idx]["rect"].has_point(mp):
			activate(pressed_idx)
		pressed_idx = -1
	if not activating and Input.is_action_just_pressed("ui_accept"):
		buttons[selected]["press"] = 1.0
		activate(selected)
	mouse_was_down = down


func activate(i: int) -> void:
	if activating:
		return
	activating = true
	var action: String = buttons[i]["action"]
	get_tree().create_timer(0.18).timeout.connect(func(): game.restart(action == "menu"))


# ---------------------------------------------------------------- main draw

func _draw() -> void:
	var g = game
	if g == null:
		return
	var st: int = g.state
	match st:
		S_CINEMA:
			Cine.draw(self, font, g, W, H)
			return
		S_TITLE:
			draw_title()
			return
		S_BLACKOUT:
			draw_rect(Rect2(0, 0, W, H), Color.BLACK)
			return
		S_INTRO:
			draw_rect(Rect2(0, 0, W, H), Color(0, 0, 0, g.black_alpha))
			text(Vector2(0, H - 22), "Press any key to skip", 16, Color(Toon.CREAM, 0.7 * (1.0 - g.black_alpha)), HORIZONTAL_ALIGNMENT_RIGHT, W - 20)
			return
		S_COUNTDOWN:
			draw_hud()
			draw_countdown()
			return
	draw_screen_bubbles()
	if st == S_TALK and not g.queue.is_empty():
		var line: String = g.queue[0].data["line"]
		actor_bubble(g.queue[0], line, 380.0, g.voice.shown_text() if g.voice.is_saying(line) else line)
	elif st == S_DECIDE or st == S_ATTACK:
		draw_thought(g.head_screen_pos(g.cashier), g.think_line if st == S_DECIDE else "GRRR!")
		draw_subtitle(g.queue[0].data["line"], 160.0 if st == S_DECIDE else 215.0)
	for a in g.leaving:
		if a.say_t > 0.0:
			actor_bubble(a, a.say, 380.0, g.voice.shown_text() if g.voice.is_saying(a.say) else a.say)
	if g.boss.pivot.visible and g.boss.say_t > 0.0:
		actor_bubble(g.boss, g.boss.say, 300.0, g.boss_voice.shown_text() if g.boss_voice.is_saying(g.boss.say) else g.boss.say)
	match st:
		S_TALK:
			draw_controls_hint()
		S_DECIDE:
			draw_timer()
			draw_controls_hint()
		S_ATTACK:
			draw_sequence_ui("ATTACK! Type:", g.attack_seq, g.attack_idx, g.attack_left / g.ATTACK_TIME, Color(1, 0.55, 0.15), false)
		S_FLIP:
			draw_flip_ui()
		S_DANCE:
			draw_dance_ui()
		S_PRAY:
			draw_pray_ui()
	if st != S_GAME_OVER:
		draw_hud()
	draw_popups()
	if st == S_GAME_OVER:
		draw_game_over()


# ---------------------------------------------------------------- text & background

func text(pos: Vector2, s: String, size: int, col: Color, align := HORIZONTAL_ALIGNMENT_LEFT, width := -1.0, outline := -1) -> void:
	Toon.toon_text(self, font, pos, s, size, col, align, width, outline)


func draw_screen_bubbles() -> void:
	for i in 9:
		var x := fmod(i * 173.0 + sin(game.t * 0.7 + i) * 18.0, W)
		var y := H - fmod(game.t * (18.0 + i * 3.0) + i * 97.0, H + 60.0)
		Toon.bubble(self, Vector2(x, y), 6.0 + (i % 4) * 4.0, 0.35)


func draw_underwater_bg(alpha := 1.0) -> void:
	# Deep-sea backdrop for menu screens: gradient, light rays, city silhouettes, corals, particles.
	var t: float = game.t
	var full := PackedVector2Array([Vector2(0, 0), Vector2(W, 0), Vector2(W, H), Vector2(0, H)])
	Toon.vgrad(self, full, Color(0.04, 0.32, 0.48, alpha), Color(0.0, 0.03, 0.1, alpha))
	# violet / cyan light accents
	for k in 5:
		draw_circle(Vector2(W * 0.12, H * 0.25), 160.0 + k * 50.0, Color(0.55, 0.3, 0.95, 0.025 * alpha))
		draw_circle(Vector2(W * 0.88, H * 0.3), 140.0 + k * 50.0, Color(0.2, 0.9, 1.0, 0.025 * alpha))
	# light rays from the surface
	for k in 6:
		var x := W * (0.08 + k * 0.17) + sin(t * 0.3 + k) * 30.0
		var ray := PackedVector2Array([Vector2(x - 30, 0), Vector2(x + 40, 0), Vector2(x + 200, H), Vector2(x + 40, H)])
		draw_colored_polygon(ray, Color(0.6, 0.95, 1.0, 0.045 * alpha))
	# far and near city silhouettes
	for layer in 2:
		var col := Color(0.04, 0.17, 0.3, 0.7 * alpha) if layer == 0 else Color(0.01, 0.06, 0.14, 0.92 * alpha)
		var base_y := H * (0.8 if layer == 0 else 0.9)
		var step := 150.0 if layer == 0 else 210.0
		var n := int(W / step) + 2
		for i in n:
			var x := i * step + (40.0 if layer == 0 else 0.0)
			match (i + layer) % 4:
				0:
					draw_colored_polygon(Toon.ellipse(Vector2(x, base_y), 70, 75), col)
					draw_colored_polygon(PackedVector2Array([Vector2(x - 12, base_y - 70), Vector2(x, base_y - 115), Vector2(x + 12, base_y - 70)]), col)
				1:
					draw_rect(Rect2(x - 22, base_y - 190, 44, 200), col)
					draw_circle(Vector2(x, base_y - 195), 24, col)
					draw_rect(Rect2(x - 38, base_y - 120, 76, 10), col)
				2:
					draw_colored_polygon(Toon.ellipse(Vector2(x, base_y + 10), 95, 55), col)
				_:
					draw_rect(Rect2(x - 40, base_y - 110, 80, 120), col)
					draw_colored_polygon(PackedVector2Array([Vector2(x - 50, base_y - 110), Vector2(x, base_y - 150), Vector2(x + 50, base_y - 110)]), col)
	draw_rect(Rect2(0, H * 0.9, W, H * 0.1), Color(0.01, 0.06, 0.14, 0.92 * alpha))
	# corals / plants swaying at the bottom
	for i in 18:
		var x := i * (W / 17.0)
		var pts := PackedVector2Array()
		var h := 60.0 + (i % 5) * 18.0
		for k in 7:
			var f := k / 6.0
			pts.append(Vector2(x + sin(t * 1.2 + i + f * 3.0) * 12.0 * f, H - f * h))
		draw_polyline(pts, Color(0.02, 0.14, 0.16, 0.9 * alpha), 6.0, true)
	# floating particles and light dots
	for i in 40:
		var px := fmod(i * 97.3 + sin(t * 0.5 + i) * 20.0, W)
		var py := H - fmod(t * (10.0 + (i % 7) * 4.0) + i * 53.0, H)
		var pc := Color(0.6, 0.95, 1.0) if i % 3 else Color(0.8, 0.6, 1.0)
		draw_circle(Vector2(px, py), 4.0 + (i % 3), Color(pc, 0.08 * alpha))
		draw_circle(Vector2(px, py), 1.5 + (i % 3) * 0.6, Color(pc, 0.6 * alpha))


# ---------------------------------------------------------------- bubbles & captions

func bubble_rect(anchor: Vector2, s: String, width: float, fs: int) -> Rect2:
	var single := font.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	var inner := minf(width - 32.0, single + 2.0)
	var sz := font.get_multiline_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, inner, fs)
	var w := inner + 32.0
	var h := sz.y + 24.0
	var x := clampf(anchor.x - w / 2.0, 12.0, W - w - 12.0)
	var y := clampf(anchor.y - h - 26.0, 108.0, H - h - 130.0)
	return Rect2(x, y, w, h)


func actor_bubble(a, s: String, width := 380.0, shown := "") -> void:
	var world: Vector3 = a.pivot.global_transform * Vector3(0, a.height + 0.05, 0)
	if game.camera.is_position_behind(world):
		return
	draw_bubble(game.camera.unproject_position(world), s, width, shown)


func draw_bubble(anchor: Vector2, s: String, width := 380.0, shown := "") -> void:
	# Sized for the full line; `shown` (typewriter) is drawn inside it.
	if shown == "":
		shown = s
	var fs := 21
	var rect := bubble_rect(anchor, s, width, fs)
	var tip := Vector2(anchor.x, maxf(anchor.y, rect.end.y + 18.0))
	var tx := clampf(tip.x, rect.position.x + 28, rect.end.x - 28)
	var tail := PackedVector2Array([Vector2(tx - 14, rect.end.y - 4), Vector2(tx + 14, rect.end.y - 4), tip])
	var tail_out := PackedVector2Array([Vector2(tx - 19, rect.end.y - 2), Vector2(tx + 19, rect.end.y - 2), tip + Vector2(0, 5)])
	draw_colored_polygon(tail_out, Toon.INK)
	Toon.bubble_panel(self, rect, 18.0)
	draw_colored_polygon(tail, Color(0.9, 0.92, 0.96))
	draw_multiline_string(font, rect.position + Vector2(16, 12 + font.get_ascent(fs)), shown, HORIZONTAL_ALIGNMENT_LEFT, rect.size.x - 32.0, fs, -1, Toon.NAVY)


func draw_thought(anchor: Vector2, s: String) -> void:
	var fs := 27
	var w := font.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x + 40.0
	var h := font.get_height(fs) + 24.0
	var rect := Rect2(clampf(anchor.x + 70, 12, W - w - 12), clampf(anchor.y - 40, 108, H - 210), w, h)
	var from := Vector2(rect.position.x + 22, rect.end.y - 4)
	for k in 3:
		var p := from.lerp(anchor + Vector2(10, 10), (k + 1) / 4.0)
		Toon.orb(self, p, 9.0 - k * 2.2, Color(0.95, 0.97, 1.0))
	Toon.bubble_panel(self, rect, h * 0.5)
	draw_string(font, rect.position + Vector2(20, 12 + font.get_ascent(fs)), s, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Toon.NAVY)


func draw_subtitle(s: String, bottom := 160.0) -> void:
	var fs := 20
	var line := "Customer: \"%s\"" % s
	var width := minf(760.0, W - 40.0)
	var sz := font.get_multiline_string_size(line, HORIZONTAL_ALIGNMENT_CENTER, width - 36, fs)
	var rect := Rect2(W / 2 - width / 2, H - bottom - sz.y, width, sz.y + 20)
	Toon.glass_panel(self, rect, Toon.GLASS_DEEP, 14.0)
	draw_multiline_string(font, rect.position + Vector2(18, 10 + font.get_ascent(fs)), line, HORIZONTAL_ALIGNMENT_CENTER, width - 36, fs, -1, Toon.CREAM)


# ---------------------------------------------------------------- decision widgets

func time_color(frac: float) -> Color:
	if frac > 0.5:
		return Toon.LIME
	if frac > 0.25:
		return Color(1, 0.8, 0.15)
	return Color(1, 0.3, 0.2)


func draw_timer() -> void:
	var frac := clampf(game.time_left / game.time_limit, 0.0, 1.0)
	Toon.pill_bar(self, Rect2(W / 2 - 180, H - 104, 360, 22), frac, time_color(frac))


func draw_controls_hint() -> void:
	var y := H - 46.0
	Toon.orb(self, Vector2(W / 2 - 300, y), 22, Color(1, 0.3, 0.3))
	Toon.arrow_glyph(self, Vector2(W / 2 - 300, y + 1), 0, 12, Toon.CREAM)
	text(Vector2(W / 2 - 266, y + 9), "Attack", 26, Toon.CREAM)
	Toon.orb(self, Vector2(W / 2 + 90, y), 22, Toon.LIME)
	Toon.arrow_glyph(self, Vector2(W / 2 + 90, y + 1), 2, 12, Toon.CREAM)
	text(Vector2(W / 2 + 124, y + 9), "Serve", 26, Toon.CREAM)


# ---------------------------------------------------------------- minigame widgets

func draw_sequence_ui(title: String, seq: Array, idx: int, frac: float, bar_col: Color, hidden: bool) -> void:
	var g = game
	var n := seq.size()
	var box := 70.0
	var total := n * box
	var x0 := W / 2.0 - total / 2.0
	var y := H - 96.0
	Toon.glass_panel(self, Rect2(x0 - 32, y - 60, total + 64, 148), Toon.GLASS_DEEP, 24.0)
	text(Vector2(x0 - 32, y - 24), title, 26, Toon.CREAM, HORIZONTAL_ALIGNMENT_CENTER, total + 64)
	for i in n:
		var status := "done" if i < idx else ("current" if i == idx else "pending")
		var center := Vector2(x0 + i * box + box / 2.0, y + 22)
		if hidden and i >= idx:
			Toon.orb(self, center, 25, Toon.VIOLET)
			text(center + Vector2(-30, 11), "?", 30, Toon.CREAM, HORIZONTAL_ALIGNMENT_CENTER, 60)
			continue
		if status == "current":
			center.y += sin(g.t * 12.0) * 2.0
		Toon.arrow_orb(self, center, seq[i], status, 25.0)
	Toon.pill_bar(self, Rect2(x0, y + 60, total, 16), frac, bar_col)


func draw_flip_ui() -> void:
	var g = game
	for i in 3:
		var p: Dictionary = g.patties[i]
		var world: Vector3 = p["mesh"].global_position + Vector3(0, 0.12, 0)
		if g.camera.is_position_behind(world):
			continue
		var pos: Vector2 = g.camera.unproject_position(world)
		var cook: float = p["cook"]
		var ready: bool = cook >= g.FLIP_ZONE and not p["flipped"]
		var status := "done" if p["flipped"] else ("current" if ready else "pending")
		var arrow_pos := pos + Vector2(0, -88)
		if ready:
			arrow_pos.y += sin(g.t * 14.0) * 3.0
		Toon.arrow_orb(self, arrow_pos, i, status, 24.0)
		var bar := Rect2(pos.x - 50, pos.y - 48, 100, 14)
		var col: Color = p["mat"].albedo_color
		Toon.pill_bar(self, bar, cook, col.lightened(0.15))
		var zx: float = bar.position.x + bar.size.x * g.FLIP_ZONE
		draw_line(Vector2(zx, bar.position.y - 5), Vector2(zx, bar.end.y + 5), Toon.GOLD, 3)
	text(Vector2(0, H - 28), "Flip each patty with its arrow key when it turns golden brown!", 22, Toon.CREAM, HORIZONTAL_ALIGNMENT_CENTER, W)


func draw_dance_ui() -> void:
	var g = game
	var n: int = g.dance_seq.size()
	if g.dance_idx < n:
		var c := Vector2(W / 2, H - 142)
		var pulse := 1.0 + 0.08 * sin(g.t * 16.0)
		Toon.arrow_orb(self, c, g.dance_seq[g.dance_idx], "current", 46.0 * pulse)
		var frac := clampf(g.dance_left / g.dance_beat, 0.0, 1.0)
		Toon.pill_bar(self, Rect2(W / 2 - 100, H - 80, 200, 16), frac, Color(1, 0.4, 0.85))
	for i in n:
		var p := Vector2(W / 2 - (n - 1) * 26 + i * 52, H - 34)
		var col := Color(0.4, 0.5, 0.65)
		if i < g.dance_idx:
			col = Toon.LIME
		elif i == g.dance_idx:
			col = Color(1, 0.4, 0.85)
		Toon.orb(self, p, 12, col)


func draw_pray_ui() -> void:
	var g = game
	if g.pray_show > 0.0:
		draw_sequence_ui("Memorize the prayer!", g.pray_seq, -1, g.pray_show / (1.2 + 0.25 * g.pray_seq.size()), Toon.SKY, false)
	else:
		draw_sequence_ui("Pray! (from memory)", g.pray_seq, g.pray_idx, g.pray_left / g.PRAY_TIME, Toon.GOLD, true)


# ---------------------------------------------------------------- HUD

func draw_hud() -> void:
	var g = game
	Toon.glass_panel(self, Rect2(16, 16, 254, 76), Toon.GLASS_BLUE, 22.0)
	Toon.orb(self, Vector2(48, 46), 17, Toon.GOLD)
	text(Vector2(36, 54), "$", 22, Toon.CREAM, HORIZONTAL_ALIGNMENT_CENTER, 24, 4)
	text(Vector2(74, 56), "%d" % g.score, 32, Toon.CREAM)
	text(Vector2(74, 82), "Highscore: %d" % g.highscore, 15, Color(0.8, 0.95, 1.0), HORIZONTAL_ALIGNMENT_LEFT, -1, 4)
	Toon.glass_panel(self, Rect2(W - 246, 16, 230, 76), Toon.GLASS_GREEN, 22.0)
	var mcol: Color = Toon.CREAM.lerp(Toon.GOLD, (g.mult - 1) / float(g.MAX_MULT - 1))
	text(Vector2(W - 246, 64), "x%d" % g.mult, 44, mcol, HORIZONTAL_ALIGNMENT_RIGHT, 214)
	var lit := int(round((g.mult - 1) / float(g.MAX_MULT - 1) * 5.0))
	for i in 5:
		Toon.star(self, Vector2(W - 222 + i * 24, 38), 9.0, Toon.GOLD, i < lit)
	text(Vector2(W - 232, 80), "Streak: %d" % g.streak, 15, Color(0.85, 1.0, 0.85), HORIZONTAL_ALIGNMENT_LEFT, -1, 4)
	draw_job_bar()


func draw_job_bar() -> void:
	var g = game
	var slot_w := 27.0
	var gap := 5.0
	var n: int = g.BAR_MAX * 2 + 1
	var total := n * slot_w + (n - 1) * gap
	var x0 := W / 2.0 - total / 2.0
	var y := 26.0
	Toon.glass_panel(self, Rect2(x0 - 58, 16, total + 80, 76), Toon.GLASS_DEEP, 22.0)
	for i in n:
		var v: int = i - g.BAR_MAX
		var col: Color
		if v < 0:
			col = Color(1, 0.35, 0.3).lerp(Color(0.6, 0.05, 0.1), float(-v) / g.BAR_MAX)
		elif v == 0:
			col = Color(0.85, 0.92, 1.0)
		else:
			col = Color(0.7, 1.0, 0.45).lerp(Color(0.1, 0.75, 0.3), float(v) / g.BAR_MAX)
		var r := Rect2(x0 + i * (slot_w + gap), y, slot_w, 20)
		Toon.vgrad(self, Toon.rrect(r.grow(2.5), 9), Toon.INK, Toon.INK)
		Toon.vgrad(self, Toon.rrect(r, 7), col.lightened(0.3), col.darkened(0.25))
		Toon.vgrad(self, Toon.rrect(Rect2(r.position + Vector2(3, 2), Vector2(r.size.x - 6, 7)), 3.5), Color(1, 1, 1, 0.75), Color(1, 1, 1, 0.1))
	draw_skull(Vector2(x0 - 30, y + 10))
	var px: float = x0 + (g.bar_shown + g.BAR_MAX) * (slot_w + gap) + slot_w / 2.0
	Toon.orb(self, Vector2(px, y + 34), 8, Toon.GOLD, 0.5)
	text(Vector2(x0, y + 60), "JOB", 15, Toon.CREAM, HORIZONTAL_ALIGNMENT_CENTER, total, 4)


func draw_skull(c: Vector2) -> void:
	Toon.orb(self, c, 14, Color(0.85, 0.88, 0.95))
	draw_circle(c + Vector2(-5, 0), 3.5, Toon.INK)
	draw_circle(c + Vector2(5, 0), 3.5, Toon.INK)
	for k in 3:
		draw_line(Vector2(c.x - 4 + k * 4, c.y + 6), Vector2(c.x - 4 + k * 4, c.y + 11), Toon.INK, 1.5)


func draw_popups() -> void:
	for p in game.popups:
		var k: float = p["t"] / p["life"]
		var col: Color = p["color"]
		col.a = 1.0 - k * k
		var pos: Vector2 = p["pos"]
		var pop := 1.0 + 0.25 * maxf(0.0, 1.0 - k * 6.0)
		text(Vector2(W / 2 + pos.x - 450, pos.y), p["text"], int(p["size"] * pop), col, HORIZONTAL_ALIGNMENT_CENTER, 900)


# ---------------------------------------------------------------- title, countdown, game over

func draw_title() -> void:
	var g = game
	draw_underwater_bg()
	var aspect := float(LOGO.get_width()) / LOGO.get_height()
	var w := minf(W * 0.72, H * 0.62 * aspect) * (1.0 + 0.015 * sin(g.t * 2.2))
	var h := w / aspect
	var c := Vector2(W / 2, H * 0.42 + sin(g.t * 1.6) * 6.0)
	draw_texture_rect(LOGO, Rect2(c - Vector2(w, h) / 2.0, Vector2(w, h)), false)
	var blink := 0.6 + 0.4 * sin(g.t * 3.5)
	text(Vector2(0, c.y + h / 2.0 + 48), "Press any key to start", 26, Color(Toon.CREAM, blink), HORIZONTAL_ALIGNMENT_CENTER, W)
	if g.title_t < 1.2:
		draw_rect(Rect2(0, 0, W, H), Color(0, 0, 0, 1.0 - g.title_t / 1.2))


func draw_countdown() -> void:
	var g = game
	var n: int = g.countdown_n
	var lamps_lit := 3 - n + 1 if n > 0 else 3
	var panel := Rect2(W / 2 - 112, 118, 224, 76)
	Toon.glass_panel(self, panel, Color(0.04, 0.08, 0.18, 0.92), 38.0)
	for i in 3:
		var c := Vector2(panel.position.x + 45 + i * 67, panel.position.y + 38)
		var col := Color(0.2, 0.22, 0.28)
		var glow := 0.0
		if n == 0:
			col = Color(0.3, 1.0, 0.35)
			glow = 1.0
		elif i < lamps_lit:
			col = Color(1.0, 0.2, 0.15)
			glow = 1.0
		Toon.orb(self, c, 23, col, glow)
	var k := clampf(g.countdown_t * 5.0, 0.0, 1.0)
	var pop := 1.6 - 0.6 * (1.0 - pow(1.0 - k, 3.0))
	var label := "GO!" if n == 0 else str(n)
	var colors := [Color(0.45, 1.0, 0.4), Color(1, 0.9, 0.3), Color(1, 0.6, 0.2), Color(1, 0.35, 0.3)]
	var col: Color = colors[n]
	var life := 0.8 if n > 0 else 0.7
	col.a = clampf((life - g.countdown_t) / 0.25, 0.0, 1.0)
	var size := int(150 * pop)
	text(Vector2(0, H * 0.58 + size * 0.35), label, size, col, HORIZONTAL_ALIGNMENT_CENTER, W)


func star_rating(score: int) -> int:
	var n := 0
	for s in STAR_SCORES:
		if score >= s:
			n += 1
	return n


func draw_game_over() -> void:
	var g = game
	draw_underwater_bg(0.9)
	var ww := minf(W * 0.62, 720.0)
	var wh := minf(H * 0.86, 540.0)
	var bob := sin(g.t * 1.8) * 3.0
	var win := Rect2(W / 2 - ww / 2, H / 2 - wh / 2 + bob, ww, wh)
	Toon.glass_panel(self, win, Color(0.06, 0.2, 0.42, 0.88), 34.0)
	# headline ribbon
	var rib := Rect2(win.position.x + 40, win.position.y - 26, ww - 80, 78)
	Toon.glass_panel(self, rib, Toon.GLASS_RED, 39.0)
	text(Vector2(rib.position.x, rib.position.y + 58), "YOU'RE FIRED!", 54, Toon.CREAM, HORIZONTAL_ALIGNMENT_CENTER, rib.size.x)
	# star rating
	var stars := star_rating(g.score)
	for i in 3:
		var sc := Vector2(win.get_center().x + (i - 1) * 96, win.position.y + 118 + (0.0 if i == 1 else 14.0))
		var r := 40.0 if i == 1 else 32.0
		var wob := 1.0 + 0.05 * sin(g.t * 4.0 + i) if i < stars else 1.0
		Toon.star(self, sc, r * wob, Toon.GOLD, i < stars)
	# reward tiles
	var tile_w := (ww - 120) / 2.0
	var ty := win.position.y + 182
	var t1 := Rect2(win.position.x + 40, ty, tile_w, 110)
	var t2 := Rect2(win.position.x + 80 + tile_w, ty, tile_w, 110)
	Toon.glass_panel(self, t1, Color(0.1, 0.32, 0.62, 0.9), 22.0)
	Toon.glass_panel(self, t2, Color(0.1, 0.32, 0.62, 0.9), 22.0)
	coin_icon(t1.position + Vector2(48, 55), 30.0)
	text(Vector2(t1.position.x + 90, t1.position.y + 52), "%d" % g.score, 40, Toon.CREAM)
	text(Vector2(t1.position.x + 92, t1.position.y + 84), "SCORE", 18, Color(0.75, 0.92, 1.0), HORIZONTAL_ALIGNMENT_LEFT, -1, 4)
	burger_icon(t2.position + Vector2(48, 58), 30.0)
	text(Vector2(t2.position.x + 90, t2.position.y + 52), "%d" % g.served, 40, Toon.CREAM)
	text(Vector2(t2.position.x + 92, t2.position.y + 84), "CORRECT", 18, Color(0.75, 0.92, 1.0), HORIZONTAL_ALIGNMENT_LEFT, -1, 4)
	# highscore line
	var hy := ty + 150
	if g.new_highscore:
		var pulse := 1.0 + 0.06 * sin(g.t * 6.0)
		text(Vector2(win.position.x, hy), "NEW HIGHSCORE!", int(34 * pulse), Toon.GOLD, HORIZONTAL_ALIGNMENT_CENTER, ww)
	else:
		text(Vector2(win.position.x, hy), "Highscore: %d" % g.highscore, 26, Color(0.8, 0.95, 1.0), HORIZONTAL_ALIGNMENT_CENTER, ww)
	# buttons
	var bw := (ww - 140) / 2.0
	var by := win.end.y - 112
	for i in buttons.size():
		var b: Dictionary = buttons[i]
		b["rect"] = Rect2(win.position.x + 50 + i * (bw + 40), by, bw, 68)
		Toon.button(self, font, b["rect"], b["label"], b["color"], b["hover"], clampf(b["press"], -0.3, 1.0), 32)
	text(Vector2(win.position.x, win.end.y - 16), "Mouse or  ← →  + Enter", 15, Color(0.75, 0.9, 1.0, 0.8), HORIZONTAL_ALIGNMENT_CENTER, ww, 4)


func coin_icon(c: Vector2, r: float) -> void:
	Toon.orb(self, c, r, Toon.GOLD, 0.6)
	draw_arc(c, r * 0.68, 0, TAU, 32, Color(0.7, 0.45, 0.05, 0.9), 3.0, true)
	text(c + Vector2(-30, 13), "$", 34, Toon.CREAM, HORIZONTAL_ALIGNMENT_CENTER, 60, 5)


func burger_icon(c: Vector2, r: float) -> void:
	# Plump glossy burger power-up.
	for k in 3:
		draw_circle(c, r + 6.0 + k * 5.0, Color(1, 0.7, 0.3, 0.06))
	var bun := Color(0.95, 0.62, 0.25)
	var top := Toon.ellipse(c + Vector2(0, -r * 0.3), r * 1.0, r * 0.62)
	Toon.vgrad(self, Toon.ellipse(c + Vector2(0, -r * 0.3), r * 1.08, r * 0.7), Toon.INK, Toon.INK)
	Toon.vgrad(self, top, bun.lightened(0.3), bun.darkened(0.2))
	Toon.vgrad(self, Toon.rrect(Rect2(c.x - r * 1.05, c.y + r * 0.05, r * 2.1, r * 0.3), 6), Color(0.35, 0.85, 0.3), Color(0.2, 0.6, 0.2))
	Toon.vgrad(self, Toon.rrect(Rect2(c.x - r * 0.98, c.y + r * 0.3, r * 1.96, r * 0.36), 8), Color(0.55, 0.3, 0.15), Color(0.32, 0.16, 0.08))
	Toon.vgrad(self, Toon.rrect(Rect2(c.x - r * 0.95, c.y + r * 0.62, r * 1.9, r * 0.4), 10), bun.lightened(0.1), bun.darkened(0.3))
	Toon.vgrad(self, Toon.ellipse(c + Vector2(-r * 0.3, -r * 0.6), r * 0.35, r * 0.15), Color(1, 1, 1, 0.8), Color(1, 1, 1, 0.1))
