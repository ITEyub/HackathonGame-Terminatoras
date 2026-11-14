extends Node
## Renders every procedural character/prop to PNG (2x resolution) so you can paint your own versions.
## Run this scene (tools/sprite_exporter.tscn) once; files go to OUT_DIR.
## Put edited PNGs (same names, same canvas size) into res://assets/sprites/ and the game uses them.

const CharacterArt := preload("res://scripts/character_art.gd")
var OUT_DIR := ProjectSettings.globalize_path("res://").path_join("../sprites_export").simplify_path()  # folder next to godotproject/
const SCALE := 2
const BODIES := ["round", "tall", "wide"]


func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(OUT_DIR)
	var jobs: Array = []
	var base := {"color": Color(0.35, 0.72, 0.95), "kind": 0, "hat": 0, "glasses": false, "size": 1.0}
	for b in 3:
		var d := base.duplicate()
		d["kind"] = b
		jobs.append(["customer_%s_front" % BODIES[b], "customer", d])
		jobs.append(["customer_%s_back" % BODIES[b], "customer_back", d])
	# accessory examples (the game picks these at random)
	for h in [[1, "cap"], [2, "tophat"], [3, "flower"]]:
		var d := base.duplicate()
		d["hat"] = h[0]
		jobs.append(["example_customer_round_front_%s" % h[1], "customer", d])
		jobs.append(["example_customer_round_back_%s" % h[1], "customer_back", d])
	var dg := base.duplicate()
	dg["glasses"] = true
	jobs.append(["example_customer_round_front_glasses", "customer", dg])
	for k in ["cashier_back", "cashier_front", "boss", "burger", "tray", "winged_burger"]:
		var name: String = "cashier_back" if k == "cashier_back" else k
		jobs.append([name, "cashier" if k == "cashier_back" else k, {}])

	for job in jobs:
		var vp := SubViewport.new()
		vp.size = Vector2i(CharacterArt.ART_SIZE * SCALE, CharacterArt.ART_SIZE * SCALE)
		vp.transparent_bg = true
		vp.disable_3d = true
		vp.render_target_update_mode = SubViewport.UPDATE_ONCE
		var holder := Node2D.new()
		holder.scale = Vector2(SCALE, SCALE)
		var art := CharacterArt.new()
		art.kind = job[1]
		art.data = job[2]
		holder.add_child(art)
		vp.add_child(holder)
		add_child(vp)
		await RenderingServer.frame_post_draw
		await RenderingServer.frame_post_draw
		var img := vp.get_texture().get_image()
		var path := "%s/%s.png" % [OUT_DIR, job[0]]
		img.save_png(path)
		print("EXPORTED ", path)
		vp.queue_free()
	print("EXPORT DONE ", jobs.size())
	get_tree().quit()
