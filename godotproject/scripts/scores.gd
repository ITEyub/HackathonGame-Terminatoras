extends Node2D
## After a game over: asks for a player name (with a bad-word filter), saves the score and shows
## a TOP 10 table next to the game over window.
## Online table: dreamlo.com (free, plain HTTP GET). Paste the two codes of your board below.
## Without codes, or when the request fails, the table falls back to scores saved on this computer.

const Toon := preload("res://scripts/toon_ui.gd")
const FONT_FILE := preload("res://assets/fonts/Fredoka.ttf")

# --- online leaderboard: get both codes from dreamlo.com ("Get Yours Now") ---
const DREAMLO_PRIVATE := "a5LMaSmkr0C4Toy97bKBFAn1PVxIsrt0yDK5vkfCiBNg"  # private code: adds scores
const DREAMLO_PUBLIC := "6af82feb8f40be25b076d918"   # public code: reads scores
const DREAMLO_URL := "http://dreamlo.com/lb/"
const HTTP_TIMEOUT := 6.0

const SAVE_PATH := "user://scores.json"
const S_GAME_OVER := 8  # game.gd State.GAME_OVER
const MIN_LEN := 2
const MAX_LEN := 12
const ROWS := 10
const ALLOWED := "ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789_-"

# Bad-word filter. Names are lower-cased, leetspeak is undone (4 -> a, 3 -> e, $ -> s ...),
# everything but letters is dropped and repeated letters are collapsed before matching.
const LEET := {"0": "o", "3": "e", "4": "a", "5": "s", "7": "t", "8": "b", "@": "a", "$": "s", "!": "i"}
const BAD_PARTS := [
	# english
	"fuck", "fuk", "fck", "fack", "shit", "bitch", "cunt", "dick", "cock", "pussy", "penis", "vagina", "whore",
	"slut", "nigger", "nigga", "niger", "faggot", "fagot", "retard", "nazi", "hitler", "rape",
	"rapist", "porn", "sex", "asshole", "ashole", "bastard", "wank", "twat", "kike", "chink",
	"tranny", "anus", "boob", "tits", "dildo", "jizz", "pedo", "kkk", "heil",
	# german
	"hure", "fotze", "schlampe", "wichser", "wixer", "wixxer", "arsch", "scheis", "schwuchtel",
	"neger", "spast", "missgeburt", "misgeburt", "fick", "nutte", "pimmel", "schwanz", "muschi",
	"titten", "kanake", "kanacke", "schwul", "behindert",
]
const BAD_EXACT := ["ass", "arse", "fag", "hoe", "cum", "anal", "spic", "mongo", "homo", "jew", "jude", "gay"]

enum Phase { IDLE, NAME, BOARD }

var game  # game.gd root
var font: Font
var W := 1152.0
var H := 648.0
var t := 0.0
var phase: Phase = Phase.IDLE
var phase_t := 0.0
var cooldown := 0.0  # keeps the game over buttons locked for a moment after Enter / Esc

var name_text := ""
var last_name := ""
var error_text := ""
var error_t := 0.0
var my_name := ""
var my_score := 0

var local: Array = []  # [{name, score}] best score per name on this computer
var rows: Array = []   # what the table shows
var status := "local"  # local | loading | online | offline
var http_add: HTTPRequest
var http_get: HTTPRequest

var ok_rect := Rect2()
var ok_hover := 0.0
var mouse_was_down := false


func _ready() -> void:
	var fv := FontVariation.new()
	fv.base_font = FONT_FILE
	var ts := TextServerManager.get_primary_interface()
	fv.variation_opentype = {ts.name_to_tag("wght"): 650}
	font = fv
	http_add = HTTPRequest.new()
	http_add.timeout = HTTP_TIMEOUT
	http_add.request_completed.connect(_on_add_done)
	add_child(http_add)
	http_get = HTTPRequest.new()
	http_get.timeout = HTTP_TIMEOUT
	http_get.request_completed.connect(_on_get_done)
	add_child(http_get)
	load_local()


# ---------------------------------------------------------------- bad-word filter

static func squeeze(s: String) -> String:
	var out := ""
	for ch in s:
		if out.is_empty() or out[-1] != ch:
			out += ch
	return out


static func normalised(n: String, one: String) -> String:
	var s := ""
	for ch in n.to_lower():
		var c: String = one if ch == "1" else LEET.get(ch, ch)
		if c >= "a" and c <= "z":
			s += c
	return s


static func is_clean(n: String) -> bool:
	for one in ["i", "l"]:  # a "1" can stand for both
		var s := normalised(n, one)
		var sq := squeeze(s)
		for w in BAD_PARTS:
			var wq := squeeze(w)  # "fuuuck" -> "fuck"; too short when squeezed (kkk -> k) is skipped
			if s.contains(w) or (wq.length() >= 4 and sq.contains(wq)):
				return false
		for w in BAD_EXACT:
			if s == w or sq == w:
				return false
	return true


# ---------------------------------------------------------------- local scores

func load_local() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		return
	var data = JSON.parse_string(FileAccess.get_file_as_string(SAVE_PATH))
	if data is Dictionary:
		last_name = str(data.get("name", ""))
		for e in data.get("scores", []):
			if e is Dictionary and e.has("name") and e.has("score"):
				local.append({"name": str(e["name"]), "score": int(e["score"])})


func save_local() -> void:
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify({"name": last_name, "scores": local}))


func add_local(n: String, score: int) -> void:
	var found := false
	for e in local:
		if e["name"] == n:
			e["score"] = maxi(e["score"], score)
			found = true
	if not found:
		local.append({"name": n, "score": score})
	local.sort_custom(func(a, b): return a["score"] > b["score"])
	if local.size() > 50:
		local.resize(50)
	save_local()


# ---------------------------------------------------------------- flow

func blocking() -> bool:
	# true while the game over buttons / shortcuts must not react
	return phase == Phase.NAME or cooldown > 0.0


func online_enabled() -> bool:
	return DREAMLO_PRIVATE != "" and DREAMLO_PUBLIC != ""


func begin() -> void:
	my_score = game.score
	phase_t = 0.0
	if my_score > 0:
		phase = Phase.NAME
		name_text = ""  # always start with an empty field
		error_text = ""
	else:
		show_board()
		fetch()


func show_board() -> void:
	phase = Phase.BOARD
	phase_t = 0.0
	cooldown = 0.35
	rows = local.slice(0, ROWS)
	status = "local"


func add_char(c: String) -> void:
	c = c.to_upper()
	if c.length() == 1 and ALLOWED.contains(c) and name_text.length() < MAX_LEN:
		name_text += c
		error_text = ""


func backspace() -> void:
	name_text = name_text.substr(0, name_text.length() - 1)
	error_text = ""


func fail(msg: String) -> void:
	error_text = msg
	error_t = 0.0


func submit() -> void:
	if phase != Phase.NAME:
		return
	if name_text.length() < MIN_LEN:
		fail("At least %d characters!" % MIN_LEN)
		return
	if not is_clean(name_text):
		fail("Let's keep it friendly - pick another name!")
		return
	my_name = name_text
	last_name = name_text
	add_local(my_name, my_score)
	show_board()
	if online_enabled():
		status = "loading"
		var err := http_add.request("%s%s/add/%s/%d" % [DREAMLO_URL, DREAMLO_PRIVATE, my_name.uri_encode(), my_score])
		if err != OK:
			status = "offline"


func skip() -> void:
	if phase != Phase.NAME:
		return
	show_board()
	fetch()


func fetch() -> void:
	if not online_enabled():
		return
	status = "loading"
	if http_get.request("%s%s/pipe/%d" % [DREAMLO_URL, DREAMLO_PUBLIC, ROWS]) != OK:
		status = "offline"


func _on_add_done(_result: int, _code: int, _headers: PackedStringArray, _body: PackedByteArray) -> void:
	fetch()  # even if adding failed, try to show the table


func _on_get_done(result: int, code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	if result != HTTPRequest.RESULT_SUCCESS or code != 200:
		status = "offline"
		return
	# one line per entry: name|score|seconds|text|date|index
	var out: Array = []
	for line in body.get_string_from_utf8().split("\n", false):
		var parts := line.strip_edges().split("|")
		if parts.size() >= 2 and parts[1].is_valid_int():
			var n: String = parts[0].uri_decode().left(MAX_LEN)
			out.append({"name": n if is_clean(n) else "*****", "score": int(parts[1])})
	out.sort_custom(func(a, b): return a["score"] > b["score"])
	rows = out.slice(0, ROWS)
	status = "online"


# ---------------------------------------------------------------- input

func _input(event: InputEvent) -> void:
	if phase != Phase.NAME or not (event is InputEventKey) or not event.pressed:
		return
	get_viewport().set_input_as_handled()
	match event.keycode:
		KEY_ENTER, KEY_KP_ENTER:
			if not event.echo:
				submit()
		KEY_ESCAPE:
			if not event.echo:
				skip()
		KEY_BACKSPACE:
			backspace()
		_:
			if event.unicode > 0:
				add_char(String.chr(event.unicode))


func _process(delta: float) -> void:
	t += delta
	phase_t += delta
	error_t += delta
	cooldown = maxf(0.0, cooldown - delta)
	var s := get_viewport_rect().size
	W = s.x
	H = s.y
	if game == null:
		return
	if phase == Phase.IDLE and game.state == S_GAME_OVER:
		begin()
	var down := Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT)
	if phase == Phase.NAME:
		var over := ok_rect.has_point(get_viewport().get_mouse_position())
		ok_hover = lerpf(ok_hover, 1.0 if over else 0.0, 1.0 - exp(-14.0 * delta))
		if over and down and not mouse_was_down:
			submit()
	mouse_was_down = down
	queue_redraw()


# ---------------------------------------------------------------- layout shared with hud.gd

func gameover_center_x() -> float:
	return W * 0.31


func gameover_width() -> float:
	return minf(W * 0.52, 600.0)


# ---------------------------------------------------------------- drawing

func text(pos: Vector2, s: String, size: int, col: Color, align := HORIZONTAL_ALIGNMENT_LEFT, width := -1.0, outline := -1) -> void:
	Toon.toon_text(self, font, pos, s, size, col, align, width, outline)


func _draw() -> void:
	if game == null:
		return
	match phase:
		Phase.NAME:
			draw_name_entry()
		Phase.BOARD:
			draw_board()


func draw_name_entry() -> void:
	var k := clampf(phase_t * 5.0, 0.0, 1.0)
	draw_rect(Rect2(0, 0, W, H), Color(0.0, 0.03, 0.1, 0.72 * k))
	var sc := 0.85 + 0.15 * k + sin(k * PI) * 0.05
	var ww := 560.0 * sc
	var wh := 330.0 * sc
	var shake := sin(error_t * 55.0) * 9.0 * exp(-error_t * 9.0) if error_text != "" else 0.0
	var win := Rect2(W / 2 - ww / 2 + shake, H / 2 - wh / 2 + 10, ww, wh)
	Toon.glass_panel(self, win, Color(0.06, 0.2, 0.42, 0.95), 34.0)
	var rib := Rect2(win.position.x + 40, win.position.y - 30, ww - 80, 70)
	Toon.glass_panel(self, rib, Toon.GLASS_BLUE, 35.0)
	text(Vector2(rib.position.x, rib.position.y + 51), "ENTER YOUR NAME", 40, Toon.CREAM, HORIZONTAL_ALIGNMENT_CENTER, rib.size.x)
	text(Vector2(win.position.x, win.position.y + 84), "Your score: %d" % my_score, 26, Toon.GOLD, HORIZONTAL_ALIGNMENT_CENTER, ww)
	# text field
	var field := Rect2(win.position.x + 50, win.position.y + 108, ww - 100, 66)
	var border := Color(1, 0.35, 0.3) if error_text != "" else Toon.FRAME_TOP
	Toon.vgrad(self, Toon.rrect(field.grow(4.0), 20), border, border.darkened(0.3))
	Toon.vgrad(self, Toon.rrect(field, 16), Color(0.0, 0.04, 0.12), Color(0.04, 0.12, 0.26))
	var shown := name_text
	var tw := font.get_string_size(shown, HORIZONTAL_ALIGNMENT_LEFT, -1, 40).x
	var tx := field.get_center().x - tw / 2.0
	text(Vector2(tx, field.position.y + 47), shown, 40, Toon.CREAM)
	if fmod(t, 0.9) < 0.55 and name_text.length() < MAX_LEN:
		draw_rect(Rect2(tx + tw + 4, field.position.y + 14, 4, 38), Toon.CYAN)
	if name_text.is_empty():
		text(Vector2(field.position.x, field.position.y + 44), "type here", 26, Color(0.6, 0.75, 0.9, 0.45), HORIZONTAL_ALIGNMENT_CENTER, field.size.x, 2)
	text(Vector2(field.position.x, field.end.y + 22), "%d/%d" % [name_text.length(), MAX_LEN], 15, Color(0.75, 0.9, 1.0, 0.8), HORIZONTAL_ALIGNMENT_RIGHT, field.size.x, 4)
	# error or hint
	if error_text != "":
		text(Vector2(win.position.x, field.end.y + 46), error_text, 20, Color(1, 0.45, 0.4), HORIZONTAL_ALIGNMENT_CENTER, ww)
	else:
		text(Vector2(win.position.x, field.end.y + 46), "Letters and numbers, %d-%d characters" % [MIN_LEN, MAX_LEN], 17, Color(0.75, 0.9, 1.0, 0.85), HORIZONTAL_ALIGNMENT_CENTER, ww, 4)
	# OK button
	ok_rect = Rect2(win.get_center().x - 100, win.end.y - 84, 200, 54)
	Toon.button(self, font, ok_rect, "OK", Color(0.3, 0.85, 0.2), ok_hover, 0.0, 28)
	text(Vector2(win.position.x, win.end.y - 6), "Enter to save   ·   Esc to skip", 15, Color(0.75, 0.9, 1.0, 0.8), HORIZONTAL_ALIGNMENT_CENTER, ww, 4)


func draw_board() -> void:
	var k := clampf(phase_t * 4.0, 0.0, 1.0)
	var e := 1.0 - pow(1.0 - k, 3.0)
	var left := gameover_center_x() + gameover_width() / 2.0 + 44.0
	var ww := W - left - 34.0
	var wh := minf(H * 0.86, 540.0)
	var bob := sin(game.t * 1.8 + 1.0) * 3.0
	var win := Rect2(left + (1.0 - e) * 80.0, H / 2 - wh / 2 + bob, ww, wh)
	modulate.a = e
	Toon.glass_panel(self, win, Color(0.06, 0.2, 0.42, 0.88), 30.0)
	var rib := Rect2(win.position.x + 30, win.position.y - 26, ww - 60, 64)
	Toon.glass_panel(self, rib, Toon.GLASS_GREEN, 32.0)
	text(Vector2(rib.position.x, rib.position.y + 47), "TOP %d" % ROWS, 38, Toon.CREAM, HORIZONTAL_ALIGNMENT_CENTER, rib.size.x)
	# status line
	var label := "this computer"
	var col := Color(0.75, 0.9, 1.0)
	match status:
		"online":
			label = "ONLINE"
			col = Toon.LIME
		"loading":
			label = "loading" + ".".repeat(1 + int(t * 3.0) % 3)
		"offline":
			label = "offline - this computer"
			col = Color(1, 0.6, 0.4)
	text(Vector2(win.position.x, win.position.y + 62), label, 15, col, HORIZONTAL_ALIGNMENT_CENTER, ww, 4)
	# rows
	var y0 := win.position.y + 78.0
	var rh := (win.end.y - 22.0 - y0) / ROWS
	var fs := int(clampf(rh * 0.62, 14.0, 24.0))
	var mine_shown := false
	for i in ROWS:
		var r := Rect2(win.position.x + 16, y0 + i * rh, ww - 32, rh - 4)
		var has: bool = i < rows.size()
		var mine: bool = has and my_name != "" and rows[i]["name"] == my_name
		if mine:
			mine_shown = true
			var pulse := 0.25 + 0.1 * sin(t * 5.0)
			Toon.vgrad(self, Toon.rrect(r, 10), Color(1.0, 0.8, 0.2, pulse + 0.1), Color(1.0, 0.6, 0.1, pulse))
		elif i % 2 == 0:
			Toon.vgrad(self, Toon.rrect(r, 10), Color(1, 1, 1, 0.05), Color(1, 1, 1, 0.03))
		var by := r.position.y + r.size.y * 0.5 + fs * 0.36
		var rank_col: Color = [Toon.GOLD, Color(0.82, 0.88, 0.95), Color(0.9, 0.6, 0.35)][i] if i < 3 else Color(0.7, 0.85, 1.0)
		text(Vector2(r.position.x + 6, by), "%d." % (i + 1), fs, rank_col, HORIZONTAL_ALIGNMENT_RIGHT, 34)
		if has:
			var c := Toon.GOLD if mine else Toon.CREAM
			text(Vector2(r.position.x + 50, by), rows[i]["name"], fs, c)
			text(Vector2(r.position.x, by), "%d" % rows[i]["score"], fs, c, HORIZONTAL_ALIGNMENT_RIGHT, r.size.x - 10)
		else:
			text(Vector2(r.position.x + 50, by), "- - -", fs, Color(0.6, 0.75, 0.9, 0.35), HORIZONTAL_ALIGNMENT_LEFT, -1, 2)
	if my_name != "" and not mine_shown and status != "loading":
		text(Vector2(win.position.x, win.end.y - 6), "%s: %d - not in the top %d yet" % [my_name, my_score, ROWS], 14, Toon.GOLD, HORIZONTAL_ALIGNMENT_CENTER, ww, 4)
