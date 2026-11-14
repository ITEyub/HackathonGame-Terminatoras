extends CanvasLayer
## Black "LOADING..." screen used when the scene reloads (Try Again / back to the menu).
## Lives on the scene tree root, so it survives the reload: fade out -> reload -> fade in.

const FONT_FILE := preload("res://assets/fonts/Fredoka.ttf")
const FADE_OUT := 0.3
const FADE_IN := 0.45

var rect: ColorRect
var label: Label
var busy := false


static func get_or_create(tree: SceneTree) -> Node:
	var f := tree.root.get_node_or_null("Fader")
	if f == null:
		f = load("res://scripts/fader.gd").new()
		f.name = "Fader"
		tree.root.add_child(f)
	return f


func _ready() -> void:
	layer = 100
	process_mode = Node.PROCESS_MODE_ALWAYS
	rect = ColorRect.new()
	rect.color = Color.BLACK
	rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(rect)
	label = Label.new()
	label.text = "LOADING..."
	label.add_theme_font_override("font", FONT_FILE)
	label.add_theme_font_size_override("font_size", 22)
	label.add_theme_color_override("font_color", Color(1.0, 0.97, 0.88, 0.8))
	label.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	label.position = Vector2(-170, -50)
	label.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	label.grow_vertical = Control.GROW_DIRECTION_BEGIN
	rect.add_child(label)
	rect.modulate.a = 0.0
	visible = false


func _process(_delta: float) -> void:
	if visible:
		var dots := 1 + int(Time.get_ticks_msec() / 300.0) % 3
		label.text = "LOADING" + ".".repeat(dots)


func reload_scene() -> void:
	if busy:
		return
	busy = true
	visible = true
	RenderingServer.set_default_clear_color(Color.BLACK)  # no grey frame while the scene rebuilds
	var tw := create_tween()
	tw.tween_property(rect, "modulate:a", 1.0, FADE_OUT)
	await tw.finished
	get_tree().paused = false
	get_tree().reload_current_scene()
	# let the new scene build and draw its first frames behind the black screen
	for i in 3:
		await get_tree().process_frame
	var tw2 := create_tween()
	tw2.tween_property(rect, "modulate:a", 0.0, FADE_IN)
	await tw2.finished
	visible = false
	busy = false
