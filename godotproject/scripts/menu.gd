extends Node2D
## Pause menu (Esc / M during play), options page (volume + graphics preset) and the red quit
## button on the title screen. Runs while the tree is paused (PROCESS_MODE_ALWAYS).
## Settings are saved to user://settings.cfg and re-applied every time the scene loads.

const Toon := preload("res://scripts/toon_ui.gd")
const FONT_FILE := preload("res://assets/fonts/Fredoka.ttf")
const SETTINGS_PATH := "user://settings.cfg"

# game.gd State values (keep in sync with its enum)
const S_TITLE := 9
const PAUSABLE := [0, 1, 2, 3, 4, 5, 6, 11, 12]  # TALK..RESOLVING, INTRO, COUNTDOWN

const GFX_NAMES := ["MIN", "MID", "MAX"]
const RED := Color(0.95, 0.18, 0.2)

enum Page { NONE, PAUSE, OPTIONS, TUTORIAL }

var game  # game.gd root
var font: Font
var W := 1152.0
var H := 648.0
var t := 0.0
var page: Page = Page.NONE
var open_t := 0.0  # 0..1 pop-in animation

var volume := 0.8  # 0..1, master bus
var graphics := 2  # 0 = min, 1 = mid, 2 = max
var tutorial_seen := false
var tutorial_saved := false  # what is on disk; only finishing the tutorial changes it

# tutorial
const TUT_SLIDES := [
	{"title": "WELCOME!", "text": "You're the new cashier at SeaSaltBurger. Customers line up one by one and tell you what they want."},
	{"title": "NICE OR MEAN?", "text": "Listen to every customer. Nice ones deserve a burger. Rude ones deserve... something else."},
	{"title": "YOUR CALL", "text": "Press  →  to SERVE a nice customer, press  ←  to ATTACK a mean one. Decide before the timer runs out - it gets faster!"},
	{"title": "MINIGAMES", "text": "Serving: flip the patties, dance or pray from memory. Attacking: type the combo, mash SPACE to rage - or win a quiz!"},
	{"title": "DON'T GET FIRED", "text": "Right calls fill your job bar and boost your multiplier. Mistakes push you toward the skull. Reach it and you're FIRED!"},
]
var tut_slide := 0
var tut_anim := 1.0  # 0..1 slide-in animation
var tut_dir := 1
var tut_done := Callable()  # called when the tutorial closes (null = back to the pause menu)
var tut_tex := {}
var tut_buttons: Array = []  # BACK, NEXT

# buttons: {label, action, color, rect, hover, press, vel}
var pause_buttons: Array = []
var option_buttons: Array = []  # MIN, MID, MAX, BACK
var quit_button := {}
var selected := 0  # pause: button index; options: row (0 volume, 1 graphics, 2 back)
var pressed_btn = null
var mouse_was_down := false
var dragging_volume := false
var slider_rect := Rect2()


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	var fv := FontVariation.new()
	fv.base_font = FONT_FILE
	var ts := TextServerManager.get_primary_interface()
	fv.variation_opentype = {ts.name_to_tag("wght"): 650}
	font = fv
	pause_buttons = [
		make_button("CONTINUE", "continue", Color(0.3, 0.85, 0.2)),
		make_button("HOW TO PLAY", "tutorial", Color(0.65, 0.45, 1.0)),
		make_button("OPTIONS", "options", Color(0.2, 0.6, 1.0)),
		make_button("MENU", "menu", Color(0.95, 0.6, 0.15)),
		make_button("QUIT", "quit", RED),
	]
	option_buttons = [
		make_button("MIN", "gfx0", Color(0.2, 0.6, 1.0)),
		make_button("MID", "gfx1", Color(0.2, 0.6, 1.0)),
		make_button("MAX", "gfx2", Color(0.2, 0.6, 1.0)),
		make_button("BACK", "back", Color(0.3, 0.85, 0.2)),
	]
	quit_button = make_button("", "quit", RED)
	tut_buttons = [
		make_button("BACK", "tut_back", Color(0.32, 0.42, 0.55)),
		make_button("NEXT", "tut_next", Color(0.3, 0.85, 0.2)),
	]
	load_settings()
	apply_volume()
	apply_graphics.call_deferred()


func make_button(label: String, action: String, col: Color) -> Dictionary:
	return {"label": label, "action": action, "color": col, "rect": Rect2(), "hover": 0.0, "press": 0.0, "vel": 0.0}


# ---------------------------------------------------------------- settings

func load_settings() -> void:
	var cf := ConfigFile.new()
	if cf.load(SETTINGS_PATH) == OK:
		volume = clampf(float(cf.get_value("audio", "volume", volume)), 0.0, 1.0)
		graphics = clampi(int(cf.get_value("video", "graphics", graphics)), 0, 2)
		tutorial_saved = bool(cf.get_value("progress", "tutorial_seen", false))
		tutorial_seen = tutorial_saved


func save_settings() -> void:
	var cf := ConfigFile.new()
	cf.set_value("audio", "volume", volume)
	cf.set_value("video", "graphics", graphics)
	cf.set_value("progress", "tutorial_seen", tutorial_saved)
	cf.save(SETTINGS_PATH)


func apply_volume() -> void:
	var bus := AudioServer.get_bus_index("Master")
	AudioServer.set_bus_mute(bus, volume <= 0.001)
	AudioServer.set_bus_volume_db(bus, linear_to_db(maxf(volume, 0.001)))


func apply_graphics() -> void:
	# MAX: 4x MSAA, full 3D resolution, shadows, glow
	# MID: 2x MSAA, 85% 3D resolution, shadows, glow
	# MIN: no MSAA, 60% 3D resolution, no shadows, no glow
	var vp := get_viewport()
	vp.msaa_3d = [Viewport.MSAA_DISABLED, Viewport.MSAA_2X, Viewport.MSAA_4X][graphics]
	vp.scaling_3d_scale = [0.6, 0.85, 1.0][graphics]
	if game == null:
		return
	game.set_art_quality(graphics == 2)  # sharp 3x character art on MAX only
	for n in game.get_children():
		if n is WorldEnvironment and n.environment:
			n.environment.glow_enabled = graphics > 0
		elif n is DirectionalLight3D:
			n.shadow_enabled = graphics > 0


# ---------------------------------------------------------------- open / close

func is_open() -> bool:
	return page != Page.NONE


func open_pause() -> void:
	page = Page.PAUSE
	selected = 0
	open_t = 0.0
	pressed_btn = null
	get_tree().paused = true


func close_pause() -> void:
	page = Page.NONE
	dragging_volume = false
	get_tree().paused = false
	game.prev_any = true  # the key that closed the menu must not count as input for the game


func do_action(action: String) -> void:
	match action:
		"continue":
			close_pause()
		"options":
			page = Page.OPTIONS
			selected = 0
		"back":
			page = Page.PAUSE
			selected = 2
		"tutorial":
			open_tutorial(Callable())
		"tut_back":
			tut_go(-1)
		"tut_next":
			tut_go(1)
		"menu":
			game.restart(true)  # stays paused behind the fade; fader.gd unpauses before reloading
		"quit":
			get_tree().quit()
		"gfx0", "gfx1", "gfx2":
			set_graphics(int(action.substr(3)))


func set_graphics(level: int) -> void:
	graphics = clampi(level, 0, 2)
	apply_graphics()
	save_settings()


func set_volume(v: float) -> void:
	volume = clampf(v, 0.0, 1.0)
	apply_volume()


# ---------------------------------------------------------------- tutorial

func tutorial_pending() -> bool:
	return not tutorial_seen


func open_tutorial(on_done: Callable) -> void:
	# on_done valid: shown before the first round, the game continues afterwards.
	# on_done empty: opened from the pause menu, closing returns there.
	tut_done = on_done
	tut_slide = 0
	tut_anim = 0.0
	tut_dir = 1
	pressed_btn = null
	if tut_tex.is_empty():
		var nice: Dictionary = game.make_customer_data()
		var mean: Dictionary = game.make_customer_data()
		nice["color"] = Color(0.3, 0.8, 1.0)
		mean["color"] = Color(1.0, 0.45, 0.25)
		mean["kind"] = (nice["kind"] + 1) % 3
		tut_tex["cashier"] = game.art_texture("cashier_front", {})[0]
		tut_tex["burger"] = game.art_texture("burger", {})[0]
		tut_tex["nice"] = game.art_texture("customer", nice)[0]
		tut_tex["mean"] = game.art_texture("customer", mean)[0]
	if page == Page.NONE:
		open_t = 0.0
	page = Page.TUTORIAL
	get_tree().paused = true


func tut_go(d: int) -> void:
	var n := tut_slide + d
	if n < 0:
		return
	if n >= TUT_SLIDES.size():
		close_tutorial()
		return
	tut_slide = n
	tut_dir = d
	tut_anim = 0.0


func close_tutorial() -> void:
	if not tutorial_saved:
		tutorial_seen = true
		tutorial_saved = true
		save_settings()
	if tut_done.is_valid():
		var cb := tut_done
		tut_done = Callable()
		close_pause()
		cb.call()
	else:
		page = Page.PAUSE
		selected = 1


# ---------------------------------------------------------------- input

func _input(event: InputEvent) -> void:
	if game == null:
		return
	if not (event is InputEventKey and event.pressed and not event.echo):
		return
	var key: int = event.keycode
	var toggle: bool = key == KEY_ESCAPE or key == KEY_M
	if not is_open():
		if toggle and game.state in PAUSABLE:
			open_pause()
			get_viewport().set_input_as_handled()
		return
	get_viewport().set_input_as_handled()
	if page == Page.PAUSE:
		match key:
			KEY_ESCAPE, KEY_M:
				close_pause()
			KEY_UP, KEY_W:
				selected = posmod(selected - 1, pause_buttons.size())
			KEY_DOWN, KEY_S:
				selected = posmod(selected + 1, pause_buttons.size())
			KEY_ENTER, KEY_KP_ENTER, KEY_SPACE:
				pause_buttons[selected]["press"] = 1.0
				do_action(pause_buttons[selected]["action"])
	elif page == Page.TUTORIAL:
		match key:
			KEY_RIGHT, KEY_D, KEY_ENTER, KEY_KP_ENTER, KEY_SPACE:
				tut_buttons[1]["press"] = 1.0
				tut_go(1)
			KEY_LEFT, KEY_A, KEY_BACKSPACE:
				if tut_slide > 0:
					tut_buttons[0]["press"] = 1.0
				tut_go(-1)
			KEY_ESCAPE, KEY_M:
				close_tutorial()
	elif page == Page.OPTIONS:
		match key:
			KEY_ESCAPE, KEY_M, KEY_BACKSPACE:
				do_action("back")
				save_settings()
			KEY_UP, KEY_W:
				selected = posmod(selected - 1, 3)
			KEY_DOWN, KEY_S:
				selected = posmod(selected + 1, 3)
			KEY_LEFT, KEY_A, KEY_RIGHT, KEY_D:
				var d := -1 if key in [KEY_LEFT, KEY_A] else 1
				if selected == 0:
					set_volume(snappedf(volume + d * 0.1, 0.1))
					save_settings()
				elif selected == 1:
					set_graphics(graphics + d)
			KEY_ENTER, KEY_KP_ENTER, KEY_SPACE:
				if selected == 2:
					option_buttons[3]["press"] = 1.0
					do_action("back")
					save_settings()


func _process(delta: float) -> void:
	t += delta
	var s := get_viewport_rect().size
	W = s.x
	H = s.y
	if game == null:
		return
	open_t = minf(1.0, open_t + delta * 6.0)
	tut_anim = minf(1.0, tut_anim + delta * 5.0)
	# fade in together with the title screen (the HUD's black fade is on a lower layer)
	var fade := 1.0
	if page == Page.NONE and game.state == S_TITLE:
		fade = clampf(game.title_t / 1.2, 0.0, 1.0)
	modulate.a = fade * fade
	var mp := get_viewport().get_mouse_position()
	var down := Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT)
	var just_down := down and not mouse_was_down
	var just_up := not down and mouse_was_down
	mouse_was_down = down
	var active: Array = []
	var sel_btn = null
	match page:
		Page.PAUSE:
			active = pause_buttons
			sel_btn = pause_buttons[selected]
		Page.OPTIONS:
			active = option_buttons
			if selected == 2:
				sel_btn = option_buttons[3]
			# volume slider: click or drag anywhere on the bar
			var hit := slider_rect.grow_individual(14, 18, 14, 18)
			if just_down and hit.has_point(mp):
				dragging_volume = true
				selected = 0
			if dragging_volume:
				if down:
					set_volume((mp.x - slider_rect.position.x) / slider_rect.size.x)
				else:
					dragging_volume = false
					save_settings()
		Page.TUTORIAL:
			active = tut_buttons if tut_slide > 0 else [tut_buttons[1]]
			sel_btn = tut_buttons[1]
		Page.NONE:
			if game.state == S_TITLE:
				active = [quit_button]
	for b in active:
		var over: bool = b["rect"].has_point(mp)
		if over and page == Page.PAUSE:
			selected = pause_buttons.find(b)
		if over and page == Page.OPTIONS:
			selected = 1 if option_buttons.find(b) < 3 else 2
		if over and just_down and not dragging_volume:
			pressed_btn = b
		var lit: bool = over or b == sel_btn
		if page == Page.OPTIONS and b["action"] == "gfx%d" % graphics:
			lit = true
		b["hover"] = lerpf(b["hover"], 1.0 if lit else 0.0, 1.0 - exp(-14.0 * delta))
		var target := 1.0 if (pressed_btn == b and down and over) else 0.0
		b["vel"] = (b["vel"] + (target - b["press"]) * 900.0 * delta) * exp(-22.0 * delta)
		b["press"] += b["vel"] * delta
	if just_up and pressed_btn != null:
		var b: Dictionary = pressed_btn
		pressed_btn = null
		if b["rect"].has_point(mp) and b in active:
			do_action(b["action"])
	queue_redraw()


func title_quit_hovered() -> bool:
	# game.gd asks this so a click on the quit button doesn't also start the game
	return quit_button["rect"].has_point(get_viewport().get_mouse_position())


# ---------------------------------------------------------------- drawing

func text(pos: Vector2, s: String, size: int, col: Color, align := HORIZONTAL_ALIGNMENT_LEFT, width := -1.0, outline := -1) -> void:
	Toon.toon_text(self, font, pos, s, size, col, align, width, outline)


func _draw() -> void:
	if game == null:
		return
	match page:
		Page.PAUSE:
			draw_pause()
		Page.OPTIONS:
			draw_options()
		Page.TUTORIAL:
			draw_tutorial()
		Page.NONE:
			if game.state == S_TITLE:
				draw_quit_button()


func pop_scale() -> float:
	# little overshoot when the window opens
	var k := open_t
	return 0.85 + 0.15 * k + sin(k * PI) * 0.06


func window(ww: float, wh: float, title: String) -> Rect2:
	draw_rect(Rect2(0, 0, W, H), Color(0.0, 0.03, 0.1, 0.55 * open_t))
	var sc := pop_scale()
	ww *= sc
	wh *= sc
	var bob := sin(t * 1.8) * 3.0
	var win := Rect2(W / 2 - ww / 2, H / 2 - wh / 2 + bob + 14, ww, wh)
	Toon.glass_panel(self, win, Color(0.06, 0.2, 0.42, 0.9), 34.0)
	var rib := Rect2(win.position.x + 50, win.position.y - 30, ww - 100, 74)
	Toon.glass_panel(self, rib, Toon.GLASS_BLUE, 37.0)
	text(Vector2(rib.position.x, rib.position.y + 55), title, 48, Toon.CREAM, HORIZONTAL_ALIGNMENT_CENTER, rib.size.x)
	return win


func draw_pause() -> void:
	var ww := minf(W * 0.5, 480.0)
	var bh := 56.0
	var gap := 16.0
	var n := pause_buttons.size()
	var wh := 80.0 + n * bh + (n - 1) * gap + 60.0
	var win := window(ww, wh, "PAUSED")
	var sc := pop_scale()  # buttons shrink with the window while it pops open
	bh *= sc
	gap *= sc
	var y := win.position.y + 76.0 * sc
	for b in pause_buttons:
		b["rect"] = Rect2(win.position.x + 60 * sc, y, win.size.x - 120 * sc, bh)
		Toon.button(self, font, b["rect"], b["label"], b["color"], b["hover"], clampf(b["press"], -0.3, 1.0), 30)
		y += bh + gap
	text(Vector2(win.position.x, win.end.y - 18), "Esc / M  to continue   ·   ↑ ↓ + Enter", 15, Color(0.75, 0.9, 1.0, 0.8), HORIZONTAL_ALIGNMENT_CENTER, win.size.x, 4)


func draw_options() -> void:
	var ww := minf(W * 0.62, 620.0)
	var win := window(ww, 430.0, "OPTIONS")
	var x0 := win.position.x + 44
	var inner := win.size.x - 88
	# --- volume
	var y := win.position.y + 92
	var row_col := func(row: int) -> Color: return Toon.GOLD if selected == row else Toon.CREAM
	text(Vector2(x0, y), "VOLUME", 28, row_col.call(0))
	text(Vector2(x0, y), "%d%%" % roundi(volume * 100.0), 28, row_col.call(0), HORIZONTAL_ALIGNMENT_RIGHT, inner)
	slider_rect = Rect2(x0 + 8, y + 26, inner - 16, 22)
	Toon.pill_bar(self, slider_rect, volume, Toon.LIME)
	var knob := Vector2(slider_rect.position.x + slider_rect.size.x * volume, slider_rect.get_center().y)
	Toon.orb(self, knob, 17.0 + (2.0 if dragging_volume or selected == 0 else 0.0), Toon.GOLD, 0.6 if selected == 0 else 0.2)
	# --- graphics
	y += 104
	text(Vector2(x0, y), "GRAPHICS", 28, row_col.call(1))
	var bw := (inner - 2 * 18.0) / 3.0
	for i in 3:
		var b: Dictionary = option_buttons[i]
		b["rect"] = Rect2(x0 + i * (bw + 18.0), y + 18, bw, 54)
		var col: Color = Toon.LIME.darkened(0.15) if i == graphics else Color(0.32, 0.42, 0.55)
		Toon.button(self, font, b["rect"], b["label"], col, b["hover"], clampf(b["press"], -0.3, 1.0), 26)
	# --- back
	var back: Dictionary = option_buttons[3]
	back["rect"] = Rect2(win.get_center().x - 120, win.end.y - 106, 240, 60)
	Toon.button(self, font, back["rect"], back["label"], back["color"], back["hover"], clampf(back["press"], -0.3, 1.0), 30)
	text(Vector2(win.position.x, win.end.y - 18), "↑ ↓ choose   ·   ← → change   ·   Esc back", 15, Color(0.75, 0.9, 1.0, 0.8), HORIZONTAL_ALIGNMENT_CENTER, win.size.x, 4)


func draw_quit_button() -> void:
	if modulate.a <= 0.01:
		return
	var sz := 64.0
	var r := Rect2(W - sz - 26, H - sz - 34, sz, sz)
	quit_button["rect"] = r
	var b := quit_button
	Toon.button(self, font, r, "", RED, b["hover"], clampf(b["press"], -0.3, 1.0), 30)
	# white X on the button face (follows the button's hover/press motion)
	var press: float = clampf(b["press"], -0.3, 1.0)
	var sc: float = 1.0 - press * 0.04 + b["hover"] * 0.03
	var c := r.get_center() + Vector2(0, press * 5.0)
	var a := sz * 0.2 * sc
	for d in [Vector2(a, a), Vector2(a, -a)]:
		draw_line(c - d, c + d, Toon.INK, 13.0)
	for d in [Vector2(a, a), Vector2(a, -a)]:
		draw_line(c - d, c + d, Toon.CREAM, 7.0)
	if b["hover"] > 0.05:
		text(Vector2(r.position.x - 200, r.end.y + 24), "QUIT", 18, Color(Toon.CREAM, b["hover"]), HORIZONTAL_ALIGNMENT_RIGHT, r.size.x + 200 - 4, 4)


# ---------------------------------------------------------------- tutorial drawing

func para(pos: Vector2, s: String, size: int, col: Color, width: float) -> void:
	# wrapped, centered toon text
	var o := maxi(4, int(size * 0.2))
	draw_multiline_string_outline(font, pos + Vector2(0, size * 0.07 + 1), s, HORIZONTAL_ALIGNMENT_CENTER, width, size, -1, o + 2, Color(Toon.INK, 0.6))
	draw_multiline_string_outline(font, pos, s, HORIZONTAL_ALIGNMENT_CENTER, width, size, -1, o, Toon.INK)
	draw_multiline_string(font, pos, s, HORIZONTAL_ALIGNMENT_CENTER, width, size, -1, col)


func tex_at(key: String, c: Vector2, h: float, bob := 0.0) -> void:
	var tex: Texture2D = tut_tex.get(key)
	if tex == null:
		return
	var w := h * tex.get_width() / float(tex.get_height())
	draw_texture_rect(tex, Rect2(c.x - w / 2, c.y - h / 2 + sin(t * 2.5 + bob) * 4.0, w, h), false)


func mini_bubble(anchor: Vector2, s: String, size := 17) -> void:
	var tw := font.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
	var r := Rect2(anchor.x - tw / 2 - 14, anchor.y - size - 22, tw + 28, size + 18)
	Toon.bubble_panel(self, r, 14.0)
	draw_colored_polygon(PackedVector2Array([Vector2(anchor.x - 8, r.end.y - 1), Vector2(anchor.x + 8, r.end.y - 1), Vector2(anchor.x, r.end.y + 10)]), Color(0.9, 0.92, 0.96))
	draw_string(font, Vector2(r.position.x + 14, r.end.y - 11), s, HORIZONTAL_ALIGNMENT_LEFT, -1, size, Toon.INK)


func key_orb(c: Vector2, dir: int, col: Color, r := 30.0) -> void:
	Toon.orb(self, c, r, col, 0.4 + 0.3 * sin(t * 5.0))
	Toon.arrow_glyph(self, c + Vector2(0, 1), dir, r * 0.55, Toon.CREAM)


func draw_tutorial() -> void:
	var ww := minf(W * 0.8, 820.0)
	var wh := minf(H * 0.86, 540.0)
	var slide: Dictionary = TUT_SLIDES[tut_slide]
	var win := window(ww, wh, slide["title"])
	# slide content slides in from the side
	var e := 1.0 - pow(1.0 - tut_anim, 3.0)
	var off := Vector2((1.0 - e) * 60.0 * tut_dir, 0)
	var a := e
	var art := Rect2(win.position.x + 30, win.position.y + 58, win.size.x - 60, win.size.y * 0.44)
	var c := art.get_center() + off
	match tut_slide:
		0:
			tex_at("cashier", c + Vector2(0, -2), art.size.y * 1.45)
			tex_at("burger", c + Vector2(-art.size.x * 0.28, 6), art.size.y * 1.0, 1.0)
			tex_at("burger", c + Vector2(art.size.x * 0.28, 6), art.size.y * 1.0, 2.5)
		1:
			var l := c + Vector2(-art.size.x * 0.22, 20)
			var r := c + Vector2(art.size.x * 0.22, 20)
			tex_at("nice", l, art.size.y * 0.8)
			tex_at("mean", r, art.size.y * 0.8, 1.5)
			mini_bubble(l + Vector2(0, -art.size.y * 0.3), "One burger, please! :)")
			mini_bubble(r + Vector2(0, -art.size.y * 0.3), "Burger. NOW!")
			text(Vector2(l.x - 80, art.end.y + 4), "NICE", 24, Toon.LIME, HORIZONTAL_ALIGNMENT_CENTER, 160)
			text(Vector2(r.x - 80, art.end.y + 4), "MEAN", 24, Color(1, 0.4, 0.35), HORIZONTAL_ALIGNMENT_CENTER, 160)
		2:
			var l := c + Vector2(-art.size.x * 0.2, -10)
			var r := c + Vector2(art.size.x * 0.2, -10)
			key_orb(l, 0, Color(1, 0.3, 0.3), 40.0)
			key_orb(r, 2, Toon.LIME, 40.0)
			text(Vector2(l.x - 100, l.y + 78), "ATTACK", 28, Toon.CREAM, HORIZONTAL_ALIGNMENT_CENTER, 200)
			text(Vector2(r.x - 100, r.y + 78), "SERVE", 28, Toon.CREAM, HORIZONTAL_ALIGNMENT_CENTER, 200)
			var frac := 1.0 - fmod(t * 0.25, 1.0)
			var col := Toon.LIME.lerp(Color(1, 0.3, 0.3), 1.0 - frac)
			Toon.pill_bar(self, Rect2(c.x - 130, art.end.y - 6, 260, 16), frac, col)
		3:
			var names := ["FLIP", "DANCE", "PRAY", "ATTACK"]
			var cols := [Color(1, 0.75, 0.3), Color(1, 0.4, 0.85), Toon.SKY, Color(1, 0.55, 0.15)]
			var pw := (art.size.x - 3 * 16.0) / 4.0
			for i in 4:
				var pr := Rect2(art.position.x + off.x + i * (pw + 16.0), art.position.y + 8, pw, art.size.y - 8)
				Toon.glass_panel(self, pr, Color(0.1, 0.32, 0.62, 0.9), 18.0)
				text(Vector2(pr.position.x, pr.end.y - 16), names[i], 22, cols[i], HORIZONTAL_ALIGNMENT_CENTER, pr.size.x)
				var pc := pr.get_center() + Vector2(0, -12)
				var step := int(t * 2.0) % 4
				match i:
					0:
						Toon.pill_bar(self, Rect2(pc.x - pw * 0.35, pc.y + 14, pw * 0.7, 12), fmod(t * 0.5, 1.0), Color(0.75, 0.45, 0.2))
						Toon.arrow_orb(self, pc + Vector2(0, -22), 1, "current" if fmod(t * 0.5, 1.0) > 0.7 else "pending", 20.0)
					1:
						Toon.arrow_orb(self, pc, [0, 1, 2, 3][step], "current", 28.0 * (1.0 + 0.08 * sin(t * 16.0)))
					2, 3:
						var seq := [1, 3, 0, 2]
						for k in 4:
							var st := "done" if k < step else ("current" if k == step else "pending")
							Toon.arrow_orb(self, pc + Vector2((k - 1.5) * pw * 0.22, 0), seq[k] if i == 2 else seq[3 - k], st, pw * 0.09)
		4:
			mini_job_bar(c + Vector2(0, -24), art.size.x * 0.7)
			var badge := Rect2(c.x - 70, c.y + 26, 140, 62)
			Toon.glass_panel(self, badge, Toon.GLASS_GREEN, 22.0)
			var m := 1 + int(t * 3.0) % 20
			text(Vector2(badge.position.x, badge.position.y + 46), "x%d" % m, 38, Toon.GOLD, HORIZONTAL_ALIGNMENT_CENTER, badge.size.x)
	# text
	var ty := art.end.y + 58
	para(Vector2(win.position.x + 50, ty) + off, slide["text"], 22, Color(Toon.CREAM, a), win.size.x - 100)
	# page dots
	var n := TUT_SLIDES.size()
	var dy := win.end.y - 112
	for i in n:
		var dc := Vector2(win.get_center().x + (i - (n - 1) / 2.0) * 26.0, dy)
		Toon.orb(self, dc, 8.0 if i == tut_slide else 6.0, Toon.GOLD if i == tut_slide else Color(0.4, 0.5, 0.65), 0.4 if i == tut_slide else 0.0)
	# buttons
	var bw := 200.0
	var by := win.end.y - 84
	var back: Dictionary = tut_buttons[0]
	var nxt: Dictionary = tut_buttons[1]
	nxt["label"] = "LET'S GO!" if tut_slide == n - 1 else "NEXT"
	if tut_done.is_valid() == false and tut_slide == n - 1:
		nxt["label"] = "DONE"
	back["rect"] = Rect2(win.position.x + 50, by, bw, 58)
	nxt["rect"] = Rect2(win.end.x - 50 - bw, by, bw, 58)
	if tut_slide > 0:
		Toon.button(self, font, back["rect"], back["label"], back["color"], back["hover"], clampf(back["press"], -0.3, 1.0), 28)
	Toon.button(self, font, nxt["rect"], nxt["label"], nxt["color"], nxt["hover"], clampf(nxt["press"], -0.3, 1.0), 28)
	text(Vector2(win.position.x, win.end.y - 6), "← →  or  Enter   ·   Esc to skip", 15, Color(0.75, 0.9, 1.0, 0.8), HORIZONTAL_ALIGNMENT_CENTER, win.size.x, 4)


func mini_job_bar(c: Vector2, width: float) -> void:
	var n := 11
	var gap := 5.0
	var sw := (width - 40.0 - (n - 1) * gap) / n
	var x0 := c.x - width / 2.0 + 40.0
	# the marker walks right (good calls), then slides back to the skull (mistakes)
	var ph := fmod(t * 0.35, 2.0)
	var pos := (ph * 5.0) if ph < 1.0 else (5.0 - (ph - 1.0) * 10.0)  # 0..5 then 5..-5
	pos = clampf(pos, -5.0, 5.0)
	for i in n:
		var v := i - 5
		var col: Color
		if v < 0:
			col = Color(1, 0.35, 0.3).lerp(Color(0.6, 0.05, 0.1), float(-v) / 5.0)
		elif v == 0:
			col = Color(0.85, 0.92, 1.0)
		else:
			col = Color(0.7, 1.0, 0.45).lerp(Color(0.1, 0.75, 0.3), float(v) / 5.0)
		var r := Rect2(x0 + i * (sw + gap), c.y - 10, sw, 20)
		Toon.vgrad(self, Toon.rrect(r.grow(2.5), 9), Toon.INK, Toon.INK)
		Toon.vgrad(self, Toon.rrect(r, 7), col.lightened(0.3), col.darkened(0.25))
	var sk := Vector2(x0 - 26, c.y)
	Toon.orb(self, sk, 14, Color(0.85, 0.88, 0.95), 0.6 if pos <= -4.5 else 0.0)
	draw_circle(sk + Vector2(-5, 0), 3.5, Toon.INK)
	draw_circle(sk + Vector2(5, 0), 3.5, Toon.INK)
	Toon.orb(self, Vector2(x0 + (pos + 5.0) * (sw + gap) + sw / 2.0, c.y + 24), 8, Toon.GOLD, 0.5)
