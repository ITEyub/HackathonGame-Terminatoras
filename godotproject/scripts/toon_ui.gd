extends RefCounted
## Underwater 3D-cartoon UI drawing helpers: chunky glossy panels with thick silver-blue frames,
## plastic orbs, golden stars, inflated green buttons, glow and layered shadows.
## All procedural - call from a CanvasItem's _draw(), passing the CanvasItem as `ci`.

const NAVY := Color(0.02, 0.07, 0.18)
const INK := Color(0.01, 0.04, 0.12)
const CREAM := Color(1.0, 0.97, 0.88)
const CYAN := Color(0.3, 0.9, 1.0)
const AQUA := Color(0.15, 0.75, 1.0)
const LIME := Color(0.45, 0.95, 0.25)
const SKY := Color(0.5, 0.85, 1.0)
const GOLD := Color(1.0, 0.78, 0.15)
const VIOLET := Color(0.65, 0.45, 1.0)
const FRAME_TOP := Color(0.88, 0.96, 1.0)
const FRAME_BOT := Color(0.4, 0.62, 0.85)
# Panel body tints (dark translucent glass)
const GLASS_BLUE := Color(0.1, 0.36, 0.7, 0.85)
const GLASS_DEEP := Color(0.05, 0.18, 0.42, 0.85)
const GLASS_GREEN := Color(0.1, 0.5, 0.35, 0.85)
const GLASS_WHITE := Color(1.0, 0.98, 0.92, 0.98)  # speech bubbles (cream)
const GLASS_RED := Color(0.7, 0.12, 0.2, 0.9)


# ---------------------------------------------------------------- geometry

static func rrect(r: Rect2, rad: float, seg := 7) -> PackedVector2Array:
	rad = clampf(rad, 1.0, minf(r.size.x, r.size.y) * 0.5)
	var pts := PackedVector2Array()
	var centres := [
		Vector2(r.end.x - rad, r.position.y + rad),
		Vector2(r.end.x - rad, r.end.y - rad),
		Vector2(r.position.x + rad, r.end.y - rad),
		Vector2(r.position.x + rad, r.position.y + rad),
	]
	for k in 4:
		var start := -PI / 2.0 + k * PI / 2.0
		for i in seg + 1:
			var a := start + (PI / 2.0) * i / seg
			var p: Vector2 = centres[k] + Vector2(cos(a), sin(a)) * rad
			# Skip duplicates (pill shapes share corner points) - they break triangulation.
			if pts.is_empty() or pts[pts.size() - 1].distance_to(p) > 0.05:
				pts.append(p)
	if pts.size() > 2 and pts[0].distance_to(pts[pts.size() - 1]) <= 0.05:
		pts.remove_at(pts.size() - 1)
	return pts


static func ellipse(c: Vector2, rx: float, ry: float, seg := 32) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in seg:
		var a := TAU * i / seg
		pts.append(c + Vector2(cos(a) * rx, sin(a) * ry))
	return pts


static func vgrad(ci: CanvasItem, pts: PackedVector2Array, top: Color, bot: Color) -> void:
	var y0 := INF
	var y1 := -INF
	for p in pts:
		y0 = minf(y0, p.y)
		y1 = maxf(y1, p.y)
	var x0 := INF
	var x1 := -INF
	for p in pts:
		x0 = minf(x0, p.x)
		x1 = maxf(x1, p.x)
	if x1 - x0 < 3.0 or y1 - y0 < 3.0:
		return  # sub-pixel shape (e.g. highlight on a tiny orb): invisible and can't be triangulated
	var cols := PackedColorArray()
	for p in pts:
		cols.append(top.lerp(bot, (p.y - y0) / maxf(1.0, y1 - y0)))
	ci.draw_polygon(pts, cols)


static func outline(ci: CanvasItem, pts: PackedVector2Array, col: Color, width := 1.5) -> void:
	var closed := pts.duplicate()
	closed.append(pts[0])
	ci.draw_polyline(closed, col, width, true)


static func glow_rrect(ci: CanvasItem, r: Rect2, rad: float, col: Color, size := 10.0, layers := 4) -> void:
	# Soft "bloom" halo built from a few translucent layers.
	for k in layers:
		var g := size * (k + 1) / layers
		vgrad(ci, rrect(r.grow(g), rad + g), Color(col, col.a / layers), Color(col, col.a / layers))


static func shadow_rrect(ci: CanvasItem, r: Rect2, rad: float, depth := 8.0) -> void:
	# Two stacked drop shadows for strong depth.
	vgrad(ci, rrect(Rect2(r.position + Vector2(0, depth * 1.6), r.size).grow(2), rad + 2), Color(0, 0.02, 0.08, 0.18), Color(0, 0.02, 0.08, 0.28))
	vgrad(ci, rrect(Rect2(r.position + Vector2(0, depth * 0.7), r.size), rad), Color(0, 0.02, 0.08, 0.35), Color(0, 0.02, 0.08, 0.5))


# ---------------------------------------------------------------- panels

static func glass_panel(ci: CanvasItem, r: Rect2, tint: Color, rad := 18.0) -> void:
	# Chunky underwater display: drop shadows, cyan glow, thick silver-blue frame, dark glass body,
	# inner shadow, glossy highlight and cyan rim light.
	var frame := 5.0 if minf(r.size.x, r.size.y) > 40.0 else 3.0
	var outer := r.grow(frame)
	shadow_rrect(ci, outer, rad + frame, 7.0)
	glow_rrect(ci, outer, rad + frame, Color(CYAN, 0.22), 9.0, 3)
	var opts := rrect(outer.grow(2.0), rad + frame + 2.0)
	vgrad(ci, opts, INK, INK)  # dark outer contour
	vgrad(ci, rrect(outer, rad + frame), FRAME_TOP, FRAME_BOT)  # thick metallic frame
	vgrad(ci, rrect(Rect2(outer.position + Vector2(3, 1.5), Vector2(outer.size.x - 6, frame + 2)), frame), Color(1, 1, 1, 0.8), Color(1, 1, 1, 0.0))
	vgrad(ci, rrect(r.grow(1.0), rad + 1.0), INK, INK)  # inner contour
	var body := rrect(r, rad)
	vgrad(ci, body, Color(tint.lightened(0.25), tint.a), Color(tint.darkened(0.35), tint.a))
	# inner shadow along the top edge
	var ish := Rect2(r.position, Vector2(r.size.x, minf(14.0, r.size.y * 0.35)))
	vgrad(ci, rrect(ish, rad), Color(0, 0, 0.05, 0.4), Color(0, 0, 0.05, 0.0))
	# glossy top highlight
	var g := Rect2(r.position.x + rad * 0.4, r.position.y + 4, r.size.x - rad * 0.8, r.size.y * 0.42)
	vgrad(ci, rrect(g, maxf(2.0, rad - 4.0)), Color(1, 1, 1, 0.22), Color(1, 1, 1, 0.0))
	# cyan rim light at the bottom edge
	var rim := Rect2(r.position.x + rad * 0.5, r.end.y - 5, r.size.x - rad, 3)
	vgrad(ci, rrect(rim, 1.5), Color(CYAN, 0.0), Color(CYAN, 0.55))


static func bubble_panel(ci: CanvasItem, r: Rect2, rad := 18.0) -> void:
	# Cream cartoon speech bubble: thick dark outline, soft shading, glossy top.
	shadow_rrect(ci, r, rad, 5.0)
	vgrad(ci, rrect(r.grow(3.5), rad + 3.5), INK, INK)
	vgrad(ci, rrect(r, rad), Color(1, 1, 0.97), Color(0.88, 0.9, 0.95))
	var g := Rect2(r.position.x + 8, r.position.y + 3, r.size.x - 16, r.size.y * 0.45)
	vgrad(ci, rrect(g, maxf(2.0, rad - 4.0)), Color(1, 1, 1, 0.9), Color(1, 1, 1, 0.0))


# ---------------------------------------------------------------- shiny objects

static func orb(ci: CanvasItem, c: Vector2, r: float, col: Color, glow := 0.0) -> void:
	# Plastic 3D sphere: shadow, dark contour, shaded body, rim light, sharp specular highlight.
	if glow > 0.0:
		for k in 4:
			ci.draw_circle(c, r + 4.0 + k * 4.0 * glow, Color(col.lightened(0.3), 0.1 * glow))
	ci.draw_circle(c + Vector2(0, r * 0.22), r * 1.04, Color(0, 0.02, 0.08, 0.35))
	ci.draw_circle(c, r + maxf(2.0, r * 0.1), INK)
	for i in 8:
		var k := i / 7.0
		ci.draw_circle(c + Vector2(-r * 0.12 * k, -r * 0.14 * k), r * (1.0 - 0.45 * k), col.darkened(0.45).lerp(col.lightened(0.22), k))
	vgrad(ci, ellipse(c + Vector2(0, r * 0.5), r * 0.62, r * 0.28), Color(col.lightened(0.5), 0.0), Color(col.lightened(0.7), 0.55))
	vgrad(ci, ellipse(c + Vector2(-r * 0.2, -r * 0.45), r * 0.5, r * 0.3), Color(1, 1, 1, 0.95), Color(1, 1, 1, 0.25))
	ci.draw_circle(c + Vector2(-r * 0.42, -r * 0.5), r * 0.1, Color(1, 1, 1, 0.95))


static func bubble(ci: CanvasItem, c: Vector2, r: float, alpha := 0.5) -> void:
	ci.draw_circle(c, r, Color(0.6, 0.9, 1.0, alpha * 0.12))
	ci.draw_arc(c, r, 0, TAU, 32, Color(0.85, 0.97, 1, alpha * 0.8), 1.8, true)
	vgrad(ci, ellipse(c + Vector2(-r * 0.3, -r * 0.4), r * 0.35, r * 0.2), Color(1, 1, 1, alpha), Color(1, 1, 1, 0.0))


static func pill_bar(ci: CanvasItem, r: Rect2, frac: float, col: Color) -> void:
	# Chunky bar: dark contour, metallic frame, deep track, glossy inflated fill.
	var rad := r.size.y * 0.5
	var outer := r.grow(3.0)
	vgrad(ci, rrect(Rect2(outer.position + Vector2(0, 4), outer.size), rad + 3), Color(0, 0.02, 0.08, 0.35), Color(0, 0.02, 0.08, 0.35))
	vgrad(ci, rrect(outer.grow(2.0), rad + 5), INK, INK)
	vgrad(ci, rrect(outer, rad + 3), FRAME_TOP, FRAME_BOT)
	vgrad(ci, rrect(r, rad), Color(0.0, 0.04, 0.12), Color(0.04, 0.12, 0.26))
	frac = clampf(frac, 0.0, 1.0)
	if frac > 0.0:
		var fr := Rect2(r.position, Vector2(maxf(r.size.y, r.size.x * frac), r.size.y))
		vgrad(ci, rrect(fr, rad), col.lightened(0.35), col.darkened(0.3))
		var g := Rect2(fr.position + Vector2(rad * 0.6, 2), Vector2(fr.size.x - rad * 1.2, fr.size.y * 0.38))
		if g.size.x > 3.0:
			vgrad(ci, rrect(g, g.size.y * 0.5), Color(1, 1, 1, 0.8), Color(1, 1, 1, 0.15))


static func star(ci: CanvasItem, c: Vector2, r: float, col: Color, lit: bool) -> void:
	# Plump golden star with contour, shading, specular and glow.
	var pts := PackedVector2Array()
	var outer_pts := PackedVector2Array()
	for i in 10:
		var a := -PI / 2.0 + TAU * i / 10.0
		var rr := r if i % 2 == 0 else r * 0.5
		pts.append(c + Vector2(cos(a), sin(a)) * rr)
		outer_pts.append(c + Vector2(cos(a), sin(a)) * (rr + 3.0))
	if lit:
		for k in 3:
			ci.draw_circle(c, r * (1.0 + 0.25 * (k + 1)), Color(col, 0.08))
	vgrad(ci, outer_pts, INK, INK)
	if lit:
		vgrad(ci, pts, col.lightened(0.55), col.darkened(0.25))
		var hi := PackedVector2Array()
		for p in pts:
			hi.append(c + (p - c) * 0.55 + Vector2(-r * 0.08, -r * 0.12))
		vgrad(ci, hi, Color(1, 1, 0.9, 0.75), Color(1, 1, 0.9, 0.0))
	else:
		vgrad(ci, pts, Color(0.32, 0.42, 0.58), Color(0.16, 0.22, 0.34))


static func arrow_glyph(ci: CanvasItem, c: Vector2, dir: int, s: float, col: Color) -> void:
	# dir: 0=left 1=up 2=right 3=down
	var ang: float = [PI, -PI / 2.0, 0.0, PI / 2.0][dir]
	var shape := [Vector2(s, 0), Vector2(-s * 0.1, -s * 0.85), Vector2(-s * 0.1, -s * 0.32), Vector2(-s * 0.9, -s * 0.32),
		Vector2(-s * 0.9, s * 0.32), Vector2(-s * 0.1, s * 0.32), Vector2(-s * 0.1, s * 0.85)]
	var pts := PackedVector2Array()
	var sh := PackedVector2Array()
	for p in shape:
		pts.append(c + p.rotated(ang))
		sh.append(c + p.rotated(ang) + Vector2(0, 2))
	ci.draw_colored_polygon(sh, Color(INK, 0.6))
	ci.draw_colored_polygon(pts, col)
	outline(ci, pts, INK, 2.0)


static func arrow_orb(ci: CanvasItem, c: Vector2, dir: int, status: String, r := 28.0) -> void:
	var col := Color(0.42, 0.55, 0.72)
	var glow := 0.0
	if status == "current":
		col = AQUA
		glow = 1.0
	elif status == "done":
		col = LIME
		glow = 0.4
	orb(ci, c, r, col, glow)
	arrow_glyph(ci, c + Vector2(0, 1), dir, r * 0.55, CREAM)


static func button(ci: CanvasItem, font: Font, r: Rect2, label: String, col: Color, hover: float, press: float, font_size := 34) -> void:
	# Inflated 3D button. hover/press are 0..1 animation values.
	var sink := press * 5.0
	var sc := 1.0 - press * 0.04 + hover * 0.03
	var c := r.get_center()
	var br := Rect2(c - r.size * sc / 2.0 + Vector2(0, sink), r.size * sc)
	var rad := br.size.y * 0.5
	var base := col.lightened(hover * 0.15)
	# underside (the "thickness" of the button) + shadow
	vgrad(ci, rrect(Rect2(br.position + Vector2(0, 14 - sink), br.size), rad), Color(0, 0.02, 0.08, 0.4), Color(0, 0.02, 0.08, 0.4))
	glow_rrect(ci, br, rad, Color(base.lightened(0.3), 0.25 + hover * 0.35), 10.0 + hover * 6.0, 3)
	vgrad(ci, rrect(Rect2(br.position + Vector2(0, 8 - sink), br.size).grow(3.5), rad + 3.5), INK, INK)
	vgrad(ci, rrect(Rect2(br.position + Vector2(0, 8 - sink), br.size), rad), base.darkened(0.45), base.darkened(0.55))
	# top face
	vgrad(ci, rrect(br.grow(3.5), rad + 3.5), INK, INK)
	vgrad(ci, rrect(br, rad), base.lightened(0.35), base.darkened(0.12))
	vgrad(ci, rrect(br.grow(-3.0), rad - 3.0), base.lightened(0.2), base.darkened(0.05))
	var g := Rect2(br.position.x + rad * 0.5, br.position.y + 4, br.size.x - rad, br.size.y * 0.4)
	vgrad(ci, rrect(g, g.size.y * 0.5), Color(1, 1, 1, 0.75), Color(1, 1, 1, 0.1))
	toon_text(ci, font, Vector2(br.position.x, br.get_center().y + font_size * 0.36), label, font_size, CREAM, HORIZONTAL_ALIGNMENT_CENTER, br.size.x)


static func toon_text(ci: CanvasItem, font: Font, pos: Vector2, s: String, size: int, col: Color, align := HORIZONTAL_ALIGNMENT_LEFT, width := -1.0, outline_px := -1, glow := true) -> void:
	# Cream cartoon text: soft cyan glow, drop shadow, thick dark outline.
	var o := outline_px if outline_px >= 0 else maxi(4, int(size * 0.2))
	if glow:
		ci.draw_string_outline(font, pos, s, align, width, size, o + 10, Color(CYAN, col.a * 0.12))
	ci.draw_string_outline(font, pos + Vector2(0, size * 0.07 + 1), s, align, width, size, o + 2, Color(INK, col.a * 0.6))
	ci.draw_string_outline(font, pos, s, align, width, size, o, Color(INK, col.a))
	ci.draw_string(font, pos, s, align, width, size, col)
