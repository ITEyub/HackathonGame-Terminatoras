extends Node2D
## Draws one 2D character/prop into its SubViewport; the texture is shown in 3D on a Sprite3D.
## Origin for characters: feet at bottom-centre of the canvas.

const ART_SIZE := 320
const FEET_PX := 304
const ART_SCALE := 1.3

var kind := "customer"  # customer | cashier | burger | tray
var data := {}


static func customer_height_px(d: Dictionary) -> float:
	var ry: float = [55.0, 72.0, 44.0][d["kind"]]
	var hat := 34.0 if d["hat"] == 2 else 8.0
	return (ry * 2.0 + 14.0 + hat) * float(d["size"]) * ART_SCALE


func _draw() -> void:
	var feet := Vector2(ART_SIZE / 2.0, FEET_PX)
	var centre := Vector2(ART_SIZE / 2.0, ART_SIZE / 2.0)
	match kind:
		"customer":
			draw_set_transform(feet, 0, Vector2.ONE * ART_SCALE * float(data["size"]))
			draw_customer()
		"cashier":
			draw_set_transform(feet, 0, Vector2.ONE * 1.05)
			draw_cashier_back()
		"customer_back":
			draw_set_transform(feet, 0, Vector2.ONE * ART_SCALE * float(data["size"]))
			draw_customer_back()
		"cashier_front":
			draw_set_transform(feet, 0, Vector2.ONE * 1.05)
			draw_cashier_front()
		"boss":
			draw_set_transform(feet, 0, Vector2.ONE * 1.15)
			draw_boss_front()
		"winged_burger":
			draw_set_transform(centre, 0, Vector2.ONE * 2.0)
			draw_winged_burger()
		"burger":
			draw_set_transform(centre, 0, Vector2.ONE * 2.4)
			draw_burger()
		"glove":
			draw_set_transform(centre, 0, Vector2.ONE * 2.3)
			draw_glove()
		"hand":
			draw_set_transform(centre + Vector2(0, 20), 0, Vector2.ONE * 2.2)
			draw_big_hand()
		"tray":
			draw_set_transform(centre, 0, Vector2.ONE * 2.4)
			draw_tray()


func ell(c: Vector2, rx: float, ry: float, col: Color, seg := 36) -> void:
	var pts := PackedVector2Array()
	for i in seg:
		var a := TAU * i / seg
		pts.append(c + Vector2(cos(a) * rx, sin(a) * ry))
	draw_colored_polygon(pts, col)


func tri(a: Vector2, b: Vector2, c: Vector2, col: Color) -> void:
	draw_colored_polygon(PackedVector2Array([a, b, c]), col)


func draw_customer() -> void:
	# Front-facing cartoon fish. Expression is neutral on purpose: only speech reveals mood.
	var d := data
	var col: Color = d["color"]
	var dark := col.darkened(0.35)
	var ink := Color(0.05, 0.05, 0.1)
	var rx := 42.0
	var ry := 55.0
	match d["kind"]:
		1:
			rx = 34.0
			ry = 72.0
		2:
			rx = 56.0
			ry = 44.0
	var cy := -ry - 14.0
	var top := cy - ry
	draw_line(Vector2(-14, cy + ry - 6), Vector2(-16, -3), dark, 7)
	draw_line(Vector2(14, cy + ry - 6), Vector2(16, -3), dark, 7)
	ell(Vector2(-19, -3), 10, 4, dark)
	ell(Vector2(19, -3), 10, 4, dark)
	tri(Vector2(-rx + 6, cy + 2), Vector2(-rx - 22, cy + 22), Vector2(-rx + 4, cy + 28), dark)
	tri(Vector2(rx - 6, cy + 2), Vector2(rx + 22, cy + 22), Vector2(rx - 4, cy + 28), dark)
	if d["hat"] == 0:
		tri(Vector2(-12, top + 8), Vector2(2, top - 18), Vector2(14, top + 8), dark)
	ell(Vector2(0, cy), rx, ry, col)
	ell(Vector2(0, cy + ry * 0.35), rx * 0.62, ry * 0.45, col.lightened(0.3))
	var ey := cy - ry * 0.35
	var ex := rx * 0.4
	for sx in [-1.0, 1.0]:
		ell(Vector2(sx * ex, ey), 11, 12, Color.WHITE)
		ell(Vector2(sx * ex, ey + 2), 5, 5.5, ink)
		ell(Vector2(sx * ex + 2, ey - 1), 1.8, 1.8, Color.WHITE)
	if d["glasses"]:
		for sx in [-1.0, 1.0]:
			draw_arc(Vector2(sx * ex, ey), 14, 0, TAU, 24, ink, 3)
		draw_line(Vector2(-ex + 14, ey), Vector2(ex - 14, ey), ink, 3)
	draw_line(Vector2(-11, ey + 27), Vector2(11, ey + 27), Color(0.3, 0.06, 0.06), 3)
	match d["hat"]:
		1:
			var cap := Color(0.2, 0.4, 0.9)
			ell(Vector2(0, top + 4), 26, 14, cap)
			ell(Vector2(0, top + 13), 31, 6, cap.darkened(0.3))
		2:
			var black := Color(0.1, 0.1, 0.12)
			draw_rect(Rect2(-17, top - 34, 34, 34), black)
			draw_rect(Rect2(-17, top - 10, 34, 5), Color(0.75, 0.15, 0.2))
			draw_rect(Rect2(-28, top - 4, 56, 7), black)
		3:
			var fc := Vector2(rx * 0.45, top + 8)
			for k in 5:
				var ang := TAU * k / 5.0
				ell(fc + Vector2(cos(ang), sin(ang)) * 8, 6, 6, Color(1, 0.5, 0.75))
			ell(fc, 5, 5, Color(1, 0.9, 0.3))


func draw_cashier_back() -> void:
	# The grumpy pufferfish cashier, seen from behind (the camera looks over its shoulder).
	var body := Color(0.93, 0.8, 0.55)
	var c := Vector2(0, -98)
	for i in 16:
		var ang := TAU * i / 16.0
		var dir := Vector2(cos(ang), sin(ang))
		var perp := Vector2(-dir.y, dir.x)
		tri(c + dir * 57 + perp * 9, c + dir * 57 - perp * 9, c + dir * 80, body.darkened(0.3))
	draw_line(Vector2(-16, -44), Vector2(-18, -2), body.darkened(0.45), 8)
	draw_line(Vector2(16, -44), Vector2(18, -2), body.darkened(0.45), 8)
	ell(Vector2(-66, -90), 17, 9, body.darkened(0.15))
	ell(Vector2(66, -90), 17, 9, body.darkened(0.15))
	ell(c, 64, 62, body)
	for p in [Vector2(-26, -122), Vector2(22, -108), Vector2(-6, -82), Vector2(32, -138), Vector2(-38, -95)]:
		ell(p, 7, 6, body.darkened(0.16))
	tri(Vector2(0, -60), Vector2(-28, -20), Vector2(28, -20), body.darkened(0.25))
	var white := Color(0.96, 0.96, 0.96)
	draw_line(Vector2(-60, -64), Vector2(60, -64), white, 4)
	ell(Vector2(-11, -64), 10, 5, white)
	ell(Vector2(11, -64), 10, 5, white)
	ell(Vector2(0, -64), 4, 4, white)
	var red := Color(0.85, 0.2, 0.2)
	ell(Vector2(0, -158), 42, 16, red)
	draw_rect(Rect2(-14, -152, 28, 6), white)
	draw_line(Vector2(-14, -149), Vector2(14, -149), red.darkened(0.3), 2)


func draw_burger() -> void:
	var bun := Color(0.88, 0.58, 0.25)
	ell(Vector2(0, -6), 20, 11, bun)
	draw_rect(Rect2(-21, 1, 42, 4), Color(0.3, 0.75, 0.25))
	draw_rect(Rect2(-19, 5, 38, 7), Color(0.42, 0.22, 0.1))
	ell(Vector2(0, 14), 19, 5, bun)
	for p in [Vector2(-8, -10), Vector2(4, -12), Vector2(10, -7)]:
		ell(p, 1.6, 1, Color(1, 0.95, 0.8))


func draw_tray() -> void:
	draw_rect(Rect2(-24, -6, 48, 12), Color(0.7, 0.7, 0.75))
	draw_rect(Rect2(-24, -6, 48, 3), Color(0.9, 0.9, 0.95))
	draw_rect(Rect2(-24, -6, 48, 12), Color(0.35, 0.35, 0.4), false, 1.5)


func half_ell_top(c: Vector2, rx: float, ry: float, col: Color) -> void:
	var pts := PackedVector2Array()
	for i in 17:
		var a := PI + PI * i / 16.0
		pts.append(c + Vector2(cos(a) * rx, sin(a) * ry))
	draw_colored_polygon(pts, col)


func draw_cashier_front() -> void:
	# The grumpy pufferfish cashier, front view: heavy eyelids, frown, visor cap, apron.
	var body := Color(0.93, 0.8, 0.55)
	var c := Vector2(0, -98)
	for i in 16:
		var ang := TAU * i / 16.0
		var dir := Vector2(cos(ang), sin(ang))
		var perp := Vector2(-dir.y, dir.x)
		tri(c + dir * 57 + perp * 9, c + dir * 57 - perp * 9, c + dir * 80, body.darkened(0.3))
	draw_line(Vector2(-16, -44), Vector2(-18, -2), body.darkened(0.45), 8)
	draw_line(Vector2(16, -44), Vector2(18, -2), body.darkened(0.45), 8)
	ell(Vector2(-66, -88), 17, 9, body.darkened(0.15))
	ell(Vector2(66, -88), 17, 9, body.darkened(0.15))
	ell(c, 64, 62, body)
	ell(c + Vector2(0, 26), 42, 26, body.lightened(0.35))
	# apron + name tag
	draw_colored_polygon(PackedVector2Array([Vector2(-34, -78), Vector2(34, -78), Vector2(40, -42), Vector2(-40, -42)]), Color(0.96, 0.96, 0.96))
	draw_rect(Rect2(10, -72, 18, 9), Color(0.35, 0.6, 0.95))
	# grumpy half-closed eyes
	for ex in [-22.0, 22.0]:
		var e := Vector2(ex, -112)
		ell(e, 14, 15, Color.WHITE)
		ell(e + Vector2(0, 5), 5.5, 5.5, Color(0.05, 0.05, 0.1))
		half_ell_top(e + Vector2(0, 2), 15.5, 16.5, body.darkened(0.12))
		draw_line(e + Vector2(-15, 2), e + Vector2(15, 2), body.darkened(0.5), 3)
	# frown
	draw_arc(Vector2(0, -80), 15, PI + 0.45, TAU - 0.45, 14, Color(0.35, 0.1, 0.1), 4)
	# visor cap with front brim
	var red := Color(0.85, 0.2, 0.2)
	ell(Vector2(0, -158), 42, 16, red)
	ell(Vector2(0, -147), 46, 7, red.darkened(0.3))


func draw_boss_front() -> void:
	# Greedy anglerfish boss, front view: huge underbite, angry brows, coin lure, top hat.
	var body := Color(0.4, 0.22, 0.52)
	var c := Vector2(0, -96)
	draw_line(Vector2(-24, -40), Vector2(-28, -2), body.darkened(0.4), 10)
	draw_line(Vector2(24, -40), Vector2(28, -2), body.darkened(0.4), 10)
	ell(Vector2(-30, -2), 14, 5, body.darkened(0.4))
	ell(Vector2(30, -2), 14, 5, body.darkened(0.4))
	tri(Vector2(-70, -100), Vector2(-104, -128), Vector2(-96, -72), body.darkened(0.25))
	tri(Vector2(70, -100), Vector2(104, -128), Vector2(96, -72), body.darkened(0.25))
	ell(c, 76, 64, body)
	# underbite mouth
	draw_colored_polygon(PackedVector2Array([Vector2(-52, -84), Vector2(52, -84), Vector2(58, -50), Vector2(-58, -50)]), Color(0.15, 0.02, 0.08))
	for i in 6:
		var x := -46.0 + i * 17.0
		tri(Vector2(x, -84), Vector2(x + 12, -84), Vector2(x + 6, -70), Color.WHITE)
		tri(Vector2(x - 3, -50), Vector2(x + 13, -50), Vector2(x + 5, -66 - (i % 2) * 6), Color.WHITE)
	# angry eyes
	for sx in [-1.0, 1.0]:
		ell(Vector2(sx * 28, -126), 15, 15, Color.WHITE)
		ell(Vector2(sx * 26, -123), 6, 6, Color(0.05, 0.05, 0.1))
		draw_line(Vector2(sx * 48, -150), Vector2(sx * 10, -138), Color(0.12, 0.02, 0.12), 6)
	# lure with gold coin
	draw_polyline(PackedVector2Array([Vector2(8, -158), Vector2(14, -196), Vector2(42, -212), Vector2(60, -196)]), body.darkened(0.3), 4)
	ell(Vector2(60, -184), 20, 20, Color(1, 0.85, 0.2, 0.3))
	ell(Vector2(60, -184), 12, 12, Color(1, 0.8, 0.1))
	draw_arc(Vector2(60, -184), 7, 0, TAU, 12, Color(0.75, 0.5, 0.05), 2)
	# top hat
	var black := Color(0.08, 0.08, 0.1)
	draw_rect(Rect2(-40, -200, 44, 34), black)
	draw_rect(Rect2(-52, -170, 68, 8), black)
	draw_rect(Rect2(-40, -174, 44, 5), Color(0.9, 0.75, 0.2))


func draw_winged_burger() -> void:
	var wing := Color(1, 1, 1)
	for sx in [-1.0, 1.0]:
		for k in 3:
			ell(Vector2(sx * (30 + k * 9), -6 - k * 7), 16 - k * 2, 7, wing)
		ell(Vector2(sx * 26, -2), 12, 8, Color(0.92, 0.92, 1))
	draw_burger()
	draw_arc(Vector2(0, -28), 14, 0, TAU, 24, Color(1, 0.85, 0.2), 3)


func draw_customer_back() -> void:
	# Same fish seen from behind (for the line outside the shop).
	var d := data
	var col: Color = d["color"]
	var dark := col.darkened(0.35)
	var rx := 42.0
	var ry := 55.0
	match d["kind"]:
		1:
			rx = 34.0
			ry = 72.0
		2:
			rx = 56.0
			ry = 44.0
	var cy := -ry - 14.0
	var top := cy - ry
	draw_line(Vector2(-14, cy + ry - 6), Vector2(-16, -3), dark, 7)
	draw_line(Vector2(14, cy + ry - 6), Vector2(16, -3), dark, 7)
	ell(Vector2(-19, -3), 10, 4, dark)
	ell(Vector2(19, -3), 10, 4, dark)
	tri(Vector2(-rx + 6, cy + 2), Vector2(-rx - 22, cy + 22), Vector2(-rx + 4, cy + 28), dark)
	tri(Vector2(rx - 6, cy + 2), Vector2(rx + 22, cy + 22), Vector2(rx - 4, cy + 28), dark)
	if d["hat"] == 0:
		tri(Vector2(-14, top + 8), Vector2(-2, top - 18), Vector2(12, top + 8), dark)
	ell(Vector2(0, cy), rx, ry, col)
	ell(Vector2(0, cy - ry * 0.2), rx * 0.55, ry * 0.5, col.darkened(0.12))
	tri(Vector2(0, cy + ry * 0.45), Vector2(-24, cy + ry + 6), Vector2(24, cy + ry + 6), dark)
	match d["hat"]:
		1:
			var cap := Color(0.2, 0.4, 0.9)
			ell(Vector2(0, top + 4), 26, 14, cap)
			draw_rect(Rect2(-10, top + 8, 20, 5), Color(0.95, 0.95, 0.95))
		2:
			var black := Color(0.1, 0.1, 0.12)
			draw_rect(Rect2(-17, top - 34, 34, 34), black)
			draw_rect(Rect2(-17, top - 10, 34, 5), Color(0.75, 0.15, 0.2))
			draw_rect(Rect2(-28, top - 4, 56, 7), black)
		3:
			var fc := Vector2(-rx * 0.45, top + 8)
			for k in 5:
				var ang := TAU * k / 5.0
				ell(fc + Vector2(cos(ang), sin(ang)) * 8, 6, 6, Color(1, 0.5, 0.75))
			ell(fc, 5, 5, Color(1, 0.9, 0.3))


func draw_glove() -> void:
	# Giant red boxing glove, pointing right (+x), with a white cuff on the left.
	var red := Color(0.92, 0.12, 0.12)
	var ink := Color(0.25, 0.02, 0.04)
	# outline pass
	draw_rect(Rect2(-62, -26, 38, 52), ink)
	ell(Vector2(8, 2), 46, 40, ink)
	ell(Vector2(-2, -30), 26, 15, ink)
	# cuff
	draw_rect(Rect2(-59, -23, 32, 46), Color(0.97, 0.97, 0.97))
	draw_rect(Rect2(-59, -6, 32, 12), Color(0.15, 0.35, 0.9))
	# fist
	ell(Vector2(8, 2), 42, 36, red)
	ell(Vector2(14, 12), 32, 20, red.darkened(0.18))
	# thumb over the top
	ell(Vector2(-2, -30), 22, 11, red.darkened(0.08))
	# knuckle creases
	for k in 3:
		draw_arc(Vector2(36, -14 + k * 14), 9, -PI / 2.0, PI / 2.0, 10, ink, 2.5)
	# glossy highlights
	ell(Vector2(4, -14), 18, 8, Color(1, 0.6, 0.6))
	ell(Vector2(-4, -17), 6, 3, Color(1, 0.95, 0.95))


func draw_big_hand() -> void:
	# Huge open fin-hand (cashier colours), fingers up, palm facing the viewer.
	var skin := Color(0.95, 0.8, 0.5)
	var ink := Color(0.35, 0.22, 0.1)
	var fingers := [[Vector2(-24, -6), Vector2(-30, -58)], [Vector2(-8, -10), Vector2(-9, -70)], [Vector2(8, -10), Vector2(10, -66)], [Vector2(23, -6), Vector2(30, -52)]]
	var thumb := [Vector2(-26, 18), Vector2(-60, -4)]
	for pass_ in 2:
		var col := ink if pass_ == 0 else skin
		var w := 22.0 if pass_ == 0 else 16.0
		for f in fingers + [thumb]:
			draw_line(f[0], f[1], col, w)
			ell(f[1], w * 0.5, w * 0.5, col)
		ell(Vector2(0, 16), 40 + (3 if pass_ == 0 else 0), 36 + (3 if pass_ == 0 else 0), col)
	# palm shading, lines and shine
	ell(Vector2(4, 22), 28, 22, skin.darkened(0.1))
	draw_arc(Vector2(2, 14), 20, PI * 0.15, PI * 0.85, 12, ink, 2.0)
	for f in fingers:
		ell(f[1] + Vector2(-2, 6), 3.5, 5, Color(1, 0.97, 0.88))
	ell(Vector2(-12, 0), 10, 5, Color(1, 0.95, 0.85))
