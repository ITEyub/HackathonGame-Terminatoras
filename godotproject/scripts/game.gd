extends Node3D
## 2.5D endless cashier arcade: a 3D restaurant with flat 2D characters (Sprite3D).
## Per customer: TALK (camera on customer) -> DECIDE (front view of the cashier, "Was jetzt?")
## -> Right = serve (random minigame: flip burgers / dance / pray) or Left = attack (arrow sequence).

# (hud.gd mirrors these values - keep the order)
enum State { TALK, DECIDE, ATTACK, FLIP, DANCE, PRAY, RESOLVING, GAME_OVER_ANIM, GAME_OVER, TITLE, BLACKOUT, INTRO, COUNTDOWN }

class Actor extends RefCounted:
	var data := {}
	var pivot: Node3D          # feet position, squash scale, facing
	var body: Node3D           # spin (rotation.z) and hop (position.y), centred on the art
	var sprite: Sprite3D       # art facing +Z (towards the main camera)
	var sprite_front: Sprite3D # optional art facing -Z (front view of the cashier)
	var say := ""
	var say_t := 0.0
	var height := 1.2          # metres, used to place the speech bubble

const CharacterArt := preload("res://scripts/character_art.gd")
const Hud := preload("res://scripts/hud.gd")
const Animalese := preload("res://scripts/animalese.gd")
const COUNTDOWN_HIT := preload("res://assets/sounds/philly_hit.ogg")
const HIT_PITCHES := [1.0, 1.08, 1.17, 1.28]  # 3, 2, 1, GO - each hit a bit higher
const SCREAM_DIR := "res://assets/sounds/death_screams/scream_%02d.wav"
const SCREAM_COUNT := 21
const TIMER_SOUND := preload("res://assets/sounds/timer.mp3")
const CHIME_SOUND := preload("res://assets/sounds/wind-chime.mp3")
# Adaptive soundtrack: stems in the order they join (bass always plays).
const MUSIC_STEMS := ["res://assets/music/bass.wav", "res://assets/music/drums.wav", "res://assets/music/mullet.wav", "res://assets/music/keys.wav"]
const MUSIC_BPM := 95.0
const MUSIC_LOOP_BEATS := 8      # every stem loops at exactly 2 bars so they stay in sync
const STEM_OFF_DB := -60.0
const BASE_FOV := 58.0
const BEAT_ZOOM_DEG := 3.0   # how far the camera punches in on each beat at keys level
const DANGER_VIGNETTE := [0.0, 1.0, 1.6, 2.4]  # stronger every step closer to the skull  # by danger level (3, 2, 1 steps from the skull)
const SURFACE_SHADER := preload("res://shaders/surface.gdshader")
const CHAR_SHADER := preload("res://shaders/character.gdshader")
const CHAR_SHADER_ONE_SIDED := preload("res://shaders/character_one_sided.gdshader")
const BUBBLE_SHADER := preload("res://shaders/bubble.gdshader")
const SHAFT_SHADER := preload("res://shaders/light_shaft.gdshader")
const VIGNETTE_SHADER := preload("res://shaders/vignette.gdshader")
const KELP_SHADER := preload("res://shaders/kelp.gdshader")
const STORE_LOGO := preload("res://assets/seasaltburger.png")
const SKY_SHADER := preload("res://shaders/water_sky.gdshader")

# World layout (metres)
const PIXEL := 0.0075
const BODY_Y := (CharacterArt.FEET_PX - CharacterArt.ART_SIZE / 2.0) * PIXEL
const CASHIER_POS := Vector3(-1.05, 0.0, 0.95)
const SLOT0 := Vector3(0.3, 0.0, -1.15)
const SLOT_STEP := Vector3(0.55, 0.0, -1.1)
const QUEUE_LEN := 9          # slots inside the shop; slot 9 is the door
const QUEUE_TOTAL := 18       # the rest of the line waits outside
const EXIT_POS := Vector3(5.5, 0.0, -1.6)
const HAND_POS := Vector3(-0.6, 1.1, 0.6)
const GRILL_POS := Vector3(-2.6, 0.0, 1.2)
const DOOR_POS := Vector3(5.25, 0.0, -12.5)  # = slot_pos(QUEUE_LEN) projected onto the back wall
const INTRO_A := Vector3(11.0, 6.5, -38.0)
const INTRO_A_LOOK := Vector3(4.0, 2.0, -14.0)
const INTRO_B := Vector3(7.2, 2.1, -17.5)
const INTRO_B_LOOK := Vector3(5.25, 1.4, -12.0)
const INTRO_C := Vector3(5.25, 2.25, -12.0)
const INTRO_C_LOOK := Vector3(2.5, 1.2, -5.0)

# Tuning
const START_TIME := 5.0
const MIN_TIME := 1.2
const TIME_FACTOR := 0.95
const ATTACK_TIME := 3.0
const PRAY_TIME := 4.0
const FLIP_ZONE := 0.55     # patty is "golden" from here until it burns at 1.0
const MAX_MULT := 20
const BAR_MAX := 5
const SAVE_PATH := "user://highscore.dat"
const ARROW_ACTIONS := ["ui_left", "ui_up", "ui_right", "ui_down"]
const SERVE_GAMES := ["flip", "dance", "pray"]

const NICE_LINES := [
	"Hello! One burger, please. Thank you so much!",
	"Good afternoon! I'd love the combo meal, if it's no trouble.",
	"Hi! You look busy today. Some fries, please.",
	"Excuse me, may I order? A kelp shake, please.",
	"Have a lovely day! Two burgers to go, please.",
	"Hiya! I'll have whatever you recommend. Thanks!",
	"One kids' meal, please. You're doing great!",
	"No rush, I've got time. A burger, please.",
	"Good morning! A coffee and a smile, if you have one spare.",
	"Hey, nice to see you! The usual, please.",
	"Could I get extra ketchup? Only if that's okay.",
	"A combo, please. Your cap looks great today!",
	"Hello, I'll take a shake. How are you doing?",
	"Fries, please. Thanks for serving me!",
	"I'd like a burger, please. Take your time.",
]
const MEAN_LINES := [
	"Burger. Now. And stop staring like that.",
	"Are you asleep or what? Serve me already!",
	"I'm not paying for that face. Gimme a burger!",
	"Hey, sleepyhead! Fries, and make it snappy!",
	"Last time the burger was cold, you loser.",
	"Give me the combo and spare me the small talk.",
	"Could you BE any slower? A shake, hurry up!",
	"I want the manager. And a burger. In that order.",
	"Move it, fin-brain, I don't have all day.",
	"What are you gawking at? Fries, and zip it.",
	"This place stinks. Gimme a burger anyway.",
	"Hurry up or I'm leaving a one-star review!",
	"One burger. Hold the bad attitude.",
	"Pfff, the service here is a joke. Combo!",
	"Hello? HELLO?! Am I invisible? Burger!",
]
const THINK_LINES := ["What now?", "What should I do?", "Hmm...", "Ugh, customers...", "Serve... or not?"]
const THANKS_LINES := ["Thank you!", "Yummy, see you!", "Great service!", "Have a nice day!"]
const RUNAWAY_LINES := ["Pay? Forget it!", "Bye, loser!", "Haha, free food!"]
const BOSS_LINES := [
	"That was MY money!",
	"Every mistake costs me coins!",
	"Are you trying to ruin me?!",
	"Money! MONEY! MONEEEY!",
	"That's coming out of your paycheck!",
]
const PRAISE_WORDS := ["Cool!", "Nice!", "Awesome!", "Money!"]
const DANCE_WORDS := ["Yeah!", "Woohoo!", "Groovy!", "Hup!", "Olé!"]
const ATTACK_NAMES := ["Tornado Kick!", "Mega Punch!", "Giant Slap!"]

static var skip_title := false  # set when restarting after game over

var state: State = State.TITLE
var black_alpha := 0.0
var countdown_n := 3
var countdown_t := 0.0
var intro_tween: Tween
var prev_any := true
var hit_players: Array[AudioStreamPlayer] = []
var jellies: Array = []        # {node, base, phase}
var screams: Array[AudioStream] = []
var scream_player: AudioStreamPlayer
var timer_player: AudioStreamPlayer
var chime_player: AudioStreamPlayer
var music_player: AudioStreamPlayer
var music_stream: AudioStreamSynchronized
var music_level := 0                 # how many stems above the bass are playing (0-3)
var stem_db := [0.0, STEM_OFF_DB, STEM_OFF_DB, STEM_OFF_DB]
var stem_tweens := [null, null, null, null]
var danger_mat: ShaderMaterial
var danger := 0.0
var last_scream := -1
var lighthouse_beam: Node3D
var hit_idx := 0
var voice: Node       # customer voice (Animalese)
var boss_voice: Node   # boss voice (same clips, pitched down)
var queue: Array[Actor] = []
var leaving: Array[Actor] = []
var cashier: Actor
var boss: Actor
var camera: Camera3D
var cam_tween: Tween
var hud: Node2D
var burger_tex: Texture2D
var tray_tex: Texture2D
var winged_tex: Texture2D
var glove_tex: Texture2D
var hand_tex: Texture2D
var pray_light: OmniLight3D
var popups: Array = []  # {text, pos (x = offset from screen centre), color, size, life, t, rise}
var queue_offset := 0.0

var score := 0
var highscore := 0
var new_highscore := false
var mult := 1
var streak := 0
var bar := 0
var bar_shown := 0.0
var mistakes := 0
var served := 0
var time_limit := START_TIME
var time_left := START_TIME
var talk_left := 0.0
var think_line := ""
var shake := 0.0
var t := 0.0

# attack
var attack_seq: Array[int] = []
var attack_idx := 0
var attack_left := 0.0
# flip burgers
var patties: Array = []  # {mesh, mat, cook, speed, flipped}
# dance
var dance_seq: Array[int] = []
var dance_idx := 0
var dance_left := 0.0
var dance_beat := 0.9
# pray
var pray_seq: Array[int] = []
var pray_idx := 0
var pray_show := 0.0
var pray_left := 0.0

# boss (a 2D character in the 3D world)
var boss_mode := ""  # "" | "shout" | "kick"
var boss_slide := 0.0
var boss_tween: Tween

var rng := RandomNumberGenerator.new()


func _ready() -> void:
	rng.randomize()
	load_highscore()
	build_world()
	burger_tex = art_texture("burger", {})[0]
	tray_tex = art_texture("tray", {})[0]
	winged_tex = art_texture("winged_burger", {})[0]
	glove_tex = art_texture("glove", {})[0]
	hand_tex = art_texture("hand", {})[0]
	Engine.time_scale = 1.0
	cashier = make_actor("cashier", {}, "cashier_front")
	cashier.pivot.position = CASHIER_POS
	cashier.height = 1.75
	boss = make_actor("boss", {})
	boss.height = 2.0
	boss.pivot.visible = false
	for i in QUEUE_TOTAL:
		queue.append(make_actor("customer", make_customer_data(), "customer_back"))
	layout_queue()
	var vlayer := CanvasLayer.new()
	vlayer.layer = 1
	add_child(vlayer)
	var vig := ColorRect.new()
	vig.set_anchors_preset(Control.PRESET_FULL_RECT)
	vig.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var vm := ShaderMaterial.new()
	vm.shader = VIGNETTE_SHADER
	vig.material = vm
	vlayer.add_child(vig)
	var dvig := ColorRect.new()
	dvig.set_anchors_preset(Control.PRESET_FULL_RECT)
	dvig.mouse_filter = Control.MOUSE_FILTER_IGNORE
	danger_mat = ShaderMaterial.new()
	danger_mat.shader = VIGNETTE_SHADER
	danger_mat.set_shader_parameter("tint", Color(0.62, 0.0, 0.04))
	danger_mat.set_shader_parameter("inner", 0.18)
	danger_mat.set_shader_parameter("strength", 0.0)
	dvig.material = danger_mat
	vlayer.add_child(dvig)
	var layer := CanvasLayer.new()
	layer.layer = 2
	add_child(layer)
	hud = Hud.new()
	hud.game = self
	layer.add_child(hud)
	voice = Animalese.new()
	add_child(voice)
	boss_voice = Animalese.new()
	add_child(boss_voice)
	timer_player = AudioStreamPlayer.new()
	var ts: AudioStreamMP3 = TIMER_SOUND.duplicate()
	ts.loop = true
	timer_player.stream = ts
	timer_player.volume_db = -4.0
	add_child(timer_player)
	setup_music()
	chime_player = AudioStreamPlayer.new()
	chime_player.stream = CHIME_SOUND
	chime_player.volume_db = linear_to_db(0.7)  # 30% quieter (about -3 dB)
	add_child(chime_player)
	scream_player = AudioStreamPlayer.new()
	scream_player.volume_db = linear_to_db(0.5)  # screams at 50% volume (about -6 dB)
	add_child(scream_player)
	for i in SCREAM_COUNT:
		screams.append(load(SCREAM_DIR % (i + 1)))
	for i in HIT_PITCHES.size():
		var hp := AudioStreamPlayer.new()
		hp.stream = COUNTDOWN_HIT
		add_child(hp)
		hit_players.append(hp)
	if skip_title:
		skip_title = false
		shot_overview(0.0)
		start_countdown()
	else:
		state = State.TITLE
		shot(INTRO_A, INTRO_A_LOOK, 0.0)


# ---------------------------------------------------------------- camera shots

func shot(pos: Vector3, target: Vector3, dur := 0.45) -> void:
	if cam_tween:
		cam_tween.kill()
	var q := Transform3D(Basis(), pos).looking_at(target, Vector3.UP).basis.get_rotation_quaternion()
	if dur <= 0.0:
		camera.position = pos
		camera.quaternion = q
		return
	cam_tween = create_tween().set_parallel(true).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	cam_tween.tween_property(camera, "position", pos, dur)
	cam_tween.tween_property(camera, "quaternion", q, dur)


func shot_overview(dur := 0.45) -> void:
	shot(Vector3(0.2, 2.45, 3.7), Vector3(0.9, 0.75, -3.5), dur)


func shot_talk(c: Actor) -> void:
	# Close-up on the customer, from just over the counter.
	var head := c.pivot.position + Vector3(0, c.height * 0.75, 0)
	shot(head + Vector3(-0.35, 0.12, 1.5), head + Vector3(0, -0.05, 0))


func shot_decide() -> void:
	# Front view of the cashier, from the customer's side of the counter.
	shot(Vector3(CASHIER_POS.x + 0.45, 1.25, -0.9), CASHIER_POS + Vector3(0, 0.95, 0))


func shot_dance() -> void:
	shot(Vector3(CASHIER_POS.x + 0.25, 1.45, -1.0), CASHIER_POS + Vector3(0, 1.05, 0), 0.35)


func shot_pray() -> void:
	# Low angle looking up at the cashier.
	shot(Vector3(CASHIER_POS.x + 0.35, 1.0, -0.85), CASHIER_POS + Vector3(0, 1.3, 0), 0.4)


func shot_grill() -> void:
	shot(GRILL_POS + Vector3(0.1, 2.0, 1.3), GRILL_POS + Vector3(0, 0.85, -0.05), 0.4)


func shot_heaven(c: Actor) -> void:
	var head := c.pivot.position + Vector3(0, c.height, 0)
	shot(head + Vector3(-0.4, -0.1, 2.1), head + Vector3(0, 0.45, 0), 0.5)


func shot_attack() -> void:
	shot(Vector3(0.9, 2.1, 3.4), Vector3(-0.2, 1.0, -0.9), 0.3)


# ---------------------------------------------------------------- 3D world

func mat(col: Color, emission := 0.0, caustics := 0.18) -> Material:
	if emission <= 0.0 and caustics > 0.0:
		var sm := ShaderMaterial.new()
		sm.shader = SURFACE_SHADER
		sm.set_shader_parameter("albedo", col)
		sm.set_shader_parameter("caustic_strength", caustics)
		return sm
	return std_mat(col, emission)


func std_mat(col: Color, emission := 0.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = col
	m.roughness = 1.0
	m.metallic_specular = 0.05
	if emission > 0.0:
		m.emission_enabled = true
		m.emission = col
		m.emission_energy_multiplier = emission
	return m


func box(size: Vector3, pos: Vector3, col: Color, emission := 0.0, caustics := 0.18) -> MeshInstance3D:
	var m := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	m.mesh = bm
	m.material_override = mat(col, emission, caustics)
	m.position = pos
	add_child(m)
	return m


func cylinder(radius: float, height: float, pos: Vector3, col: Color, rot_deg := Vector3.ZERO, emission := 0.0) -> MeshInstance3D:
	var m := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = radius
	cm.bottom_radius = radius
	cm.height = height
	m.mesh = cm
	m.material_override = mat(col, emission)
	m.position = pos
	m.rotation_degrees = rot_deg
	add_child(m)
	return m


func build_world() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.16, 0.4, 0.55)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.65, 0.85, 0.95)
	env.ambient_light_energy = 0.4
	env.fog_enabled = true
	env.fog_light_color = Color(0.22, 0.5, 0.65)
	env.fog_density = 0.016
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.glow_enabled = true
	env.glow_intensity = 0.6
	env.glow_bloom = 0.04
	env.glow_hdr_threshold = 0.9
	env.adjustment_enabled = true
	env.adjustment_saturation = 1.35
	env.adjustment_contrast = 1.08
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)

	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-55, -25, 0)
	sun.light_energy = 0.35
	sun.shadow_enabled = true
	add_child(sun)
	var lamp := OmniLight3D.new()
	lamp.position = Vector3(0, 3.4, -1.5)
	lamp.omni_range = 8.0
	lamp.light_color = Color(1, 0.9, 0.7)
	lamp.light_energy = 0.6
	add_child(lamp)
	pray_light = OmniLight3D.new()
	pray_light.position = CASHIER_POS + Vector3(0, 2.4, -0.6)
	pray_light.omni_range = 4.0
	pray_light.light_color = Color(1, 0.85, 0.4)
	pray_light.light_energy = 0.0
	add_child(pray_light)

	camera = Camera3D.new()
	camera.fov = BASE_FOV
	add_child(camera)

	# Floor with a checker texture (1 m tiles)
	var floor_mat := ShaderMaterial.new()
	floor_mat.shader = SURFACE_SHADER
	floor_mat.set_shader_parameter("albedo", Color(0.98, 0.9, 0.62))
	floor_mat.set_shader_parameter("albedo_b", Color(0.1, 0.62, 0.72))
	floor_mat.set_shader_parameter("checker", true)
	floor_mat.set_shader_parameter("caustic_strength", 0.45)
	var floor_mi := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(12, 18)
	floor_mi.mesh = pm
	floor_mi.material_override = floor_mat
	floor_mi.position = Vector3(0, 0, -3.5)
	add_child(floor_mi)

	# Room shell does not cast shadows, so the sun lights the floor evenly.
	var wall := Color(0.05, 0.55, 0.85)
	var wain := Color(0.02, 0.3, 0.62)
	var shell: Array[MeshInstance3D] = [
		box(Vector3(10.65, 5, 0.2), Vector3(-0.675, 2.5, -12.5), wall),
		box(Vector3(0.15, 5, 0.2), Vector3(5.925, 2.5, -12.5), wall),
		box(Vector3(1.2, 2.4, 0.2), Vector3(5.25, 3.8, -12.5), wall),
		box(Vector3(0.2, 5, 18), Vector3(-6, 2.5, -3.5), wall),
		box(Vector3(0.2, 5, 18), Vector3(6, 2.5, -3.5), wall),
		box(Vector3(12, 5, 0.2), Vector3(0, 2.5, 5.5), wall),
		box(Vector3(10.65, 0.9, 0.24), Vector3(-0.675, 0.45, -12.42), wain),
		box(Vector3(0.24, 0.9, 18), Vector3(-5.92, 0.45, -3.5), wain),
		box(Vector3(0.24, 0.9, 18), Vector3(5.92, 0.45, -3.5), wain),
		box(Vector3(12, 0.2, 18), Vector3(0, 5.0, -3.5), Color(0.2, 0.42, 0.5), 0.0, 0.9),
	]
	for m in shell:
		m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

	# Door at the end of the line
	var door_x := DOOR_POS.x
	var wood := Color(0.75, 0.32, 0.1)
	box(Vector3(0.2, 2.7, 0.35), Vector3(door_x - 0.7, 1.35, -12.32), wood)
	box(Vector3(0.2, 2.7, 0.35), Vector3(door_x + 0.7, 1.35, -12.32), wood)
	box(Vector3(1.6, 0.22, 0.35), Vector3(door_x, 2.8, -12.32), wood)

	build_outside()

	# Sign on the back wall
	box(Vector3(5.6, 1.6, 0.15), Vector3(-2.0, 3.6, -12.3), Color(0.03, 0.1, 0.28))
	store_logo(Vector3(-2.0, 3.6, -12.2), 5.2, false)

	# Portholes on both side walls
	for side in [-1.0, 1.0]:
		for z in [-3.0, -6.5, -10.0]:
			var x: float = side * 5.86
			cylinder(0.5, 0.08, Vector3(x, 2.6, z), Color(0.55, 0.45, 0.3), Vector3(0, 0, 90))
			cylinder(0.38, 0.1, Vector3(x - side * 0.02, 2.6, z), Color(0.45, 0.78, 0.9), Vector3(0, 0, 90), 0.8)

	# Tables on the left for depth
	for z in [-3.5, -7.0, -10.0]:
		cylinder(0.6, 0.06, Vector3(-3.6, 0.75, z), Color(1.0, 0.3, 0.35))
		cylinder(0.07, 0.75, Vector3(-3.6, 0.375, z), Color(0.4, 0.4, 0.45))

	# Counter + register
	box(Vector3(2.6, 0.62, 0.7), Vector3(-0.3, 0.31, 0), Color(1.0, 0.42, 0.15))
	box(Vector3(2.62, 0.08, 0.72), Vector3(-0.3, 0.42, 0), Color(1.0, 0.85, 0.1))
	box(Vector3(2.75, 0.07, 0.85), Vector3(-0.3, 0.655, 0), Color(0.7, 0.22, 0.08))

	# Grill station behind the counter, with three patties
	box(Vector3(1.6, 0.84, 0.8), GRILL_POS + Vector3(0, 0.42, 0), Color(0.55, 0.58, 0.62))
	box(Vector3(1.4, 0.04, 0.62), GRILL_POS + Vector3(0, 0.86, 0), Color(0.12, 0.12, 0.14))
	for k in 6:
		box(Vector3(1.38, 0.012, 0.02), GRILL_POS + Vector3(0, 0.885, -0.25 + k * 0.1), Color(0.3, 0.3, 0.32))
	var glow := OmniLight3D.new()
	glow.position = GRILL_POS + Vector3(0, 1.1, 0)
	glow.omni_range = 1.6
	glow.light_color = Color(1, 0.5, 0.2)
	glow.light_energy = 0.8
	add_child(glow)
	for k in 3:
		var pm2 := MeshInstance3D.new()
		var cm := CylinderMesh.new()
		cm.top_radius = 0.15
		cm.bottom_radius = 0.15
		cm.height = 0.06
		pm2.mesh = cm
		var m := std_mat(Color(0.95, 0.55, 0.55))
		pm2.material_override = m
		pm2.position = GRILL_POS + Vector3(-0.45 + k * 0.45, 0.92, 0)
		add_child(pm2)
		patties.append({"mesh": pm2, "mat": m, "cook": 0.0, "speed": 0.4, "flipped": false})

	# Rising bubbles
	var bubbles := CPUParticles3D.new()
	var sm := SphereMesh.new()
	sm.radius = 0.04
	sm.height = 0.08
	var bm := ShaderMaterial.new()
	bm.shader = BUBBLE_SHADER
	sm.material = bm
	bubbles.mesh = sm
	bubbles.amount = 70
	bubbles.lifetime = 9.0
	bubbles.preprocess = 9.0
	bubbles.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	bubbles.emission_box_extents = Vector3(5.5, 0.1, 7.5)
	bubbles.position = Vector3(0, 0.1, -4.0)
	bubbles.direction = Vector3.UP
	bubbles.spread = 10.0
	bubbles.gravity = Vector3(0, 0.2, 0)
	bubbles.initial_velocity_min = 0.25
	bubbles.initial_velocity_max = 0.55
	bubbles.scale_amount_min = 0.5
	bubbles.scale_amount_max = 1.6
	add_child(bubbles)

	# Sun shafts slanting down from the water surface
	for i in 6:
		var shaft := MeshInstance3D.new()
		var q := QuadMesh.new()
		q.size = Vector2(rng.randf_range(1.2, 2.2), 6.0)
		shaft.mesh = q
		var shm := ShaderMaterial.new()
		shm.shader = SHAFT_SHADER
		shm.set_shader_parameter("strength", rng.randf_range(0.08, 0.16))
		shm.set_shader_parameter("speed", rng.randf_range(0.6, 1.4))
		shaft.material_override = shm
		shaft.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		shaft.position = Vector3(-4.0 + i * 1.7, 2.4, -2.0 - (i % 3) * 3.2)
		shaft.rotation = Vector3(0.0, rng.randf_range(-0.3, 0.3), 0.32)
		add_child(shaft)


func store_logo(pos: Vector3, width: float, facing_out: bool) -> void:
	# The SeaSaltBurger logo as a flat sign (one-sided so it only shows on its own wall side).
	var s := Sprite3D.new()
	s.texture = STORE_LOGO
	s.pixel_size = width / float(STORE_LOGO.get_width())
	s.double_sided = false
	s.shaded = false
	s.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	s.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	s.position = pos
	if facing_out:
		s.rotation.y = PI
	add_child(s)


func build_outside() -> void:
	# Sea floor in front of the shop, where the line continues.
	var sand := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(240, 240)  # one sea floor under the whole town (shop floor sits just above it)
	sand.mesh = pm
	sand.material_override = mat(Color(0.84, 0.76, 0.55), 0.0, 0.5)
	sand.position = Vector3(3, -0.03, -15.0)
	add_child(sand)
	# Facade details (outside face of the back wall)
	store_logo(Vector3(0.3, 4.0, -12.68), 8.0, true)
	for k in 5:
		box(Vector3(0.36, 0.1, 0.9), Vector3(4.53 + k * 0.36, 2.95, -13.05), Color(0.9, 0.25, 0.25) if k % 2 == 0 else Color(0.97, 0.95, 0.9), 0.0, 0.0).rotation.x = -0.25
	for x in [-3.5, -0.5, 2.5]:
		box(Vector3(1.6, 1.2, 0.05), Vector3(x, 1.9, -12.64), Color(1.0, 0.85, 0.55), 0.9)
		box(Vector3(1.8, 0.12, 0.12), Vector3(x, 1.25, -12.68), Color(0.5, 0.32, 0.2))
	# Roof trim on the facade
	box(Vector3(12.4, 0.35, 0.7), Vector3(0, 5.15, -12.6), Color(1.0, 0.45, 0.1), 0.0, 0.2)
	for x in [-6.0, 6.0]:
		box(Vector3(0.5, 5.2, 0.5), Vector3(x, 2.6, -12.6), Color(1.0, 0.45, 0.1), 0.0, 0.2)
	build_town()


# ---------------------------------------------------------------- the town outside

func sphere(radius: float, pos: Vector3, col: Color, emission := 0.0, caustics := 0.25, hemi := false, scl := Vector3.ONE) -> MeshInstance3D:
	var m := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = radius
	sm.height = radius if hemi else radius * 2.0
	sm.is_hemisphere = hemi
	m.mesh = sm
	m.material_override = mat(col, emission, caustics)
	m.position = pos
	m.scale = scl
	add_child(m)
	return m


func cone(r_bottom: float, r_top: float, h: float, base: Vector3, col: Color, rot_deg := Vector3.ZERO, emission := 0.0) -> MeshInstance3D:
	var m := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.bottom_radius = r_bottom
	cm.top_radius = r_top
	cm.height = h
	m.mesh = cm
	m.material_override = mat(col, emission, 0.25)
	m.rotation_degrees = rot_deg
	m.position = base + m.basis * Vector3(0, h / 2.0, 0)
	add_child(m)
	return m


func town_sign(text_: String, pos: Vector3, col: Color, size := 90) -> void:
	var l := Label3D.new()
	l.text = text_
	l.font_size = size
	l.pixel_size = 0.006
	l.modulate = col
	l.outline_size = 22
	l.outline_modulate = Color(0.12, 0.08, 0.2)
	l.position = pos
	l.rotation.y = PI  # face the street / intro camera (towards -Z)
	add_child(l)


func bubble_vent(pos: Vector3, amount := 14) -> void:
	var p := CPUParticles3D.new()
	var sm := SphereMesh.new()
	sm.radius = 0.06
	sm.height = 0.12
	var bm := ShaderMaterial.new()
	bm.shader = BUBBLE_SHADER
	sm.material = bm
	p.mesh = sm
	p.amount = amount
	p.lifetime = 4.0
	p.preprocess = 4.0
	p.direction = Vector3.UP
	p.spread = 12.0
	p.gravity = Vector3(0, 0.4, 0)
	p.initial_velocity_min = 0.6
	p.initial_velocity_max = 1.1
	p.scale_amount_min = 0.5
	p.scale_amount_max = 1.5
	p.position = pos
	add_child(p)


func kelp(pos: Vector3, h: float, col := Color(0.25, 0.6, 0.3)) -> void:
	var m := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 0.03
	cm.bottom_radius = 0.09
	cm.height = h
	cm.rings = 8
	cm.radial_segments = 6
	m.mesh = cm
	var km := ShaderMaterial.new()
	km.shader = KELP_SHADER
	km.set_shader_parameter("albedo", col)
	km.set_shader_parameter("height", h)
	m.material_override = km
	m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	m.position = pos + Vector3(0, h / 2.0, 0)
	add_child(m)


func shell_house(pos: Vector3, r: float, col: Color, name_: String) -> void:
	# Dome house shaped like a big seashell: ribs, spire, glowing round windows, bubbling chimney.
	sphere(r, pos, col, 0.0, 0.3, true)
	for k in 7:
		var a := -PI * 0.5 + PI * k / 6.0
		var rib := sphere(r * 1.01, pos, col.darkened(0.15), 0.0, 0.2, true, Vector3(0.12, 1.0, 1.0))
		rib.rotation.y = a
	cone(r * 0.28, 0.02, r * 0.9, pos + Vector3(0, r * 0.92, 0), col.lightened(0.25))
	box(Vector3(1.0, 1.8, 0.3), pos + Vector3(0, 0.9, -r * 0.96), Color(0.45, 0.28, 0.18), 0.0, 0.1)
	for sx in [-1.0, 1.0]:
		sphere(0.32, pos + Vector3(sx * r * 0.5, 1.9, -r * 0.82), Color(1.0, 0.85, 0.5), 1.4)
	var chim := pos + Vector3(r * 0.45, r * 0.75, r * 0.25)
	cone(0.25, 0.22, 1.2, chim, col.darkened(0.3))
	bubble_vent(chim + Vector3(0, 1.25, 0), 8)
	town_sign(name_, pos + Vector3(0, 2.75, -r * 0.98), Color(1, 0.95, 0.7), 70)


func coral_tower(pos: Vector3, h: float, col: Color, name_: String, light := false) -> void:
	# Stacked coral tower with balconies, branches and a glowing crown.
	var y := 0.0
	var seg := 4
	for k in seg:
		var sh := h / seg
		var r := 1.6 - k * 0.3
		cone(r, r * 0.85, sh, pos + Vector3(0, y, 0), col.lightened(k * 0.06))
		y += sh
		cylinder(r + 0.35, 0.18, pos + Vector3(0, y, 0), col.lightened(0.35))
		sphere(0.25, pos + Vector3(0, y - sh * 0.5, -r * 0.92), Color(1, 0.9, 0.6), 1.3)
		if k < seg - 1:
			var side := -1.0 if k % 2 == 0 else 1.0
			cone(0.22, 0.08, 2.2, pos + Vector3(side * r * 0.8, y - sh * 0.4, 0), col.darkened(0.1), Vector3(0, 0, -side * 45))
	sphere(0.7, pos + Vector3(0, y + 0.5, 0), Color(0.6, 1.0, 0.95), 2.0)
	if light:
		var l := OmniLight3D.new()
		l.position = pos + Vector3(0, y + 0.6, 0)
		l.light_color = Color(0.6, 1.0, 0.95)
		l.light_energy = 1.5
		l.omni_range = 9.0
		add_child(l)
	town_sign(name_, pos + Vector3(0, 2.2, -1.75), Color(0.85, 1, 0.9), 70)


func sunken_ship(pos: Vector3) -> void:
	# Tilted shipwreck turned diner.
	var ship := Node3D.new()
	ship.position = pos
	ship.rotation = Vector3(0.0, 0.5, 0.12)
	add_child(ship)
	var parts := [
		[Vector3(3.2, 2.0, 9.0), Vector3(0, 1.0, 0), Color(0.45, 0.3, 0.2)],
		[Vector3(3.0, 0.2, 8.6), Vector3(0, 2.05, 0), Color(0.62, 0.45, 0.3)],
		[Vector3(2.6, 1.6, 2.6), Vector3(0, 2.9, 2.6), Color(0.5, 0.35, 0.25)],
	]
	for p in parts:
		var b := box(p[0], Vector3.ZERO, p[2], 0.0, 0.2)
		remove_child(b)
		b.position = p[1]
		ship.add_child(b)
	var bow := MeshInstance3D.new()
	var pm := PrismMesh.new()
	pm.size = Vector3(3.2, 2.0, 2.4)
	bow.mesh = pm
	bow.material_override = mat(Color(0.45, 0.3, 0.2), 0.0, 0.2)
	bow.rotation = Vector3(PI / 2.0, 0, 0)
	bow.position = Vector3(0, 1.0, -5.6)
	bow.scale = Vector3(1, 1.2, 1)
	ship.add_child(bow)
	var mast := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 0.1
	cm.bottom_radius = 0.16
	cm.height = 7.0
	mast.mesh = cm
	mast.material_override = mat(Color(0.4, 0.28, 0.18))
	mast.position = Vector3(0, 5.5, -1.0)
	ship.add_child(mast)
	var sail := MeshInstance3D.new()
	var q := QuadMesh.new()
	q.size = Vector2(3.2, 3.0)
	sail.mesh = q
	var sm := std_mat(Color(0.93, 0.9, 0.8))
	sm.cull_mode = BaseMaterial3D.CULL_DISABLED
	sail.material_override = sm
	sail.position = Vector3(0, 5.8, -0.95)
	ship.add_child(sail)
	for k in 4:
		var ph := MeshInstance3D.new()
		var s2 := SphereMesh.new()
		s2.radius = 0.25
		s2.height = 0.5
		ph.mesh = s2
		ph.material_override = std_mat(Color(1, 0.85, 0.5), 1.5)
		ph.position = Vector3(-1.62, 1.1, -3.0 + k * 2.0)
		ship.add_child(ph)
	town_sign("THE SOGGY ANCHOR", pos + Vector3(-0.8, 4.3, -3.8), Color(1, 0.8, 0.4), 80)


func bottle_lighthouse(pos: Vector3) -> void:
	# A lighthouse inside a giant glass bottle, with a sweeping beam.
	sphere(2.2, pos, Color(0.42, 0.45, 0.48), 0.0, 0.3, true, Vector3(1.2, 0.5, 1.2))
	var glass := std_mat(Color(0.45, 0.85, 0.6, 0.35))
	glass.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	glass.emission_enabled = true
	glass.emission = Color(0.2, 0.5, 0.35)
	var body := cone(1.3, 1.3, 6.0, pos + Vector3(0, 0.9, 0), Color.WHITE)
	body.material_override = glass
	var neck := cone(1.3, 0.5, 1.4, pos + Vector3(0, 6.9, 0), Color.WHITE)
	neck.material_override = glass
	cone(0.5, 0.5, 1.4, pos + Vector3(0, 8.3, 0), Color.WHITE).material_override = glass
	cone(0.55, 0.5, 0.7, pos + Vector3(0, 9.7, 0), Color(0.6, 0.42, 0.25))
	# little lighthouse inside the bottle
	cone(0.6, 0.45, 4.5, pos + Vector3(0, 0.9, 0), Color(0.95, 0.95, 0.95))
	for k in 3:
		cylinder(0.56 - k * 0.04, 0.4, pos + Vector3(0, 1.8 + k * 1.3, 0), Color(0.9, 0.25, 0.25))
	sphere(0.4, pos + Vector3(0, 5.8, 0), Color(1, 0.95, 0.6), 3.0)
	var l := OmniLight3D.new()
	l.position = pos + Vector3(0, 5.8, 0)
	l.light_color = Color(1, 0.9, 0.6)
	l.light_energy = 1.6
	l.omni_range = 10.0
	add_child(l)
	lighthouse_beam = Node3D.new()
	lighthouse_beam.position = pos + Vector3(0, 5.8, 0)
	add_child(lighthouse_beam)
	for side in [0.0, PI]:
		var beam := MeshInstance3D.new()
		var bq := QuadMesh.new()
		bq.size = Vector2(1.4, 16.0)
		beam.mesh = bq
		var bm := ShaderMaterial.new()
		bm.shader = SHAFT_SHADER
		bm.set_shader_parameter("color", Color(1, 0.95, 0.7))
		bm.set_shader_parameter("strength", 0.25)
		beam.material_override = bm
		beam.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		beam.rotation = Vector3(0, side, PI / 2.0)
		beam.position = Vector3(cos(side), 0, -sin(side)) * 8.0
		lighthouse_beam.add_child(beam)
	town_sign("BUBBLE BANK", pos + Vector3(0, 1.5, -2.7), Color(0.8, 1, 0.85), 70)


func clam_stage(pos: Vector3) -> void:
	# Open giant clam used as a stage, with a glowing pearl.
	var pink := Color(0.95, 0.6, 0.7)
	sphere(2.4, pos + Vector3(0, 0.9, 0), pink, 0.0, 0.3, true, Vector3(1, -0.45, 1))
	var lid := sphere(2.4, pos + Vector3(0, 0.95, 0.9), pink.darkened(0.1), 0.0, 0.3, true, Vector3(1, 0.45, 1))
	lid.rotation.x = -1.0
	sphere(0.6, pos + Vector3(0, 1.4, -0.3), Color(1, 0.98, 0.95), 2.2)
	town_sign("CLAM JAM - OPEN MIC TONIGHT", pos + Vector3(0, 3.6, -0.5), Color(1, 0.8, 0.95), 60)


func coral_cluster(pos: Vector3) -> void:
	var cols := [Color(1, 0.45, 0.55), Color(1, 0.65, 0.3), Color(0.7, 0.45, 1.0), Color(0.3, 0.85, 0.8), Color(1, 0.85, 0.35)]
	for k in rng.randi_range(4, 7):
		var c: Color = cols[rng.randi() % cols.size()]
		var p := pos + Vector3(rng.randf_range(-0.9, 0.9), 0, rng.randf_range(-0.9, 0.9))
		match rng.randi() % 3:
			0:
				cone(rng.randf_range(0.08, 0.14), 0.03, rng.randf_range(0.6, 1.5), p, c, Vector3(rng.randf_range(-25, 25), 0, rng.randf_range(-25, 25)))
			1:
				sphere(rng.randf_range(0.3, 0.6), p, c, 0.0, 0.25, true, Vector3(1, 0.7, 1))
			_:
				cone(0.25, 0.4, 0.5, p, c)
				sphere(0.42, p + Vector3(0, 0.5, 0), c.lightened(0.2), 0.3, 0.2, true, Vector3(1, 0.35, 1))


func street_lamp(pos: Vector3, real_light := false) -> void:
	# Lantern on a curved pole, like an anglerfish lure.
	cone(0.09, 0.07, 3.2, pos, Color(0.25, 0.25, 0.32))
	cone(0.06, 0.06, 0.8, pos + Vector3(0, 3.15, 0), Color(0.25, 0.25, 0.32), Vector3(0, 0, -60))
	var orb := pos + Vector3(0.62, 3.0, 0)
	sphere(0.22, orb, Color(1, 0.9, 0.5), 2.5)
	if real_light:
		var l := OmniLight3D.new()
		l.position = orb
		l.light_color = Color(1, 0.85, 0.5)
		l.light_energy = 1.2
		l.omni_range = 5.0
		add_child(l)


func build_town() -> void:
	# Sky dome
	var sky := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 150.0
	sm.height = 300.0
	sky.mesh = sm
	var skm := ShaderMaterial.new()
	skm.shader = SKY_SHADER
	sky.material_override = skm
	sky.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(sky)
	# Buildings along the street (the line runs out of the door towards -Z)
	shell_house(Vector3(-3.5, 0, -21), 3.2, Color(1.0, 0.62, 0.7), "SHELL MART")
	shell_house(Vector3(-12, 0, -15), 2.6, Color(0.75, 0.65, 1.0), "SEA SPA")
	shell_house(Vector3(12, 0, -14.5), 2.3, Color(0.55, 0.95, 0.8), "KELP & CO")
	shell_house(Vector3(-11, 0, -6), 2.8, Color(1.0, 0.8, 0.45), "")
	coral_tower(Vector3(-10, 0, -28), 11.0, Color(1.0, 0.5, 0.4), "CORAL CAFE", true)
	coral_tower(Vector3(-4, 0, 9), 14.0, Color(0.6, 0.5, 1.0), "")
	coral_tower(Vector3(13, 0, -1), 9.0, Color(0.3, 0.75, 0.85), "")
	sunken_ship(Vector3(20, 0, -21))
	bottle_lighthouse(Vector3(19, 0, -7))
	clam_stage(Vector3(-1.0, 0, -28))
	# Cobblestone path along the line (one MultiMesh = cheap)
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	var stone := CylinderMesh.new()
	stone.top_radius = 0.32
	stone.bottom_radius = 0.36
	stone.height = 0.08
	stone.radial_segments = 8
	mm.mesh = stone
	mm.instance_count = 150
	for k in 150:
		var z := -13.0 - (k / 5) * 0.75 - rng.randf_range(0, 0.2)
		var x := DOOR_POS.x - 1.2 + (k % 5) * 0.6 + rng.randf_range(-0.1, 0.1)
		var tf := Transform3D(Basis().rotated(Vector3.UP, rng.randf() * TAU).scaled(Vector3.ONE * rng.randf_range(0.8, 1.1)), Vector3(x, 0.02, z))
		mm.set_instance_transform(k, tf)
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	mmi.material_override = mat(Color(0.62, 0.6, 0.58), 0.0, 0.35)
	add_child(mmi)
	# Street lamps on both sides of the path
	for k in 6:
		var z := -16.0 - k * 6.0
		street_lamp(Vector3(DOOR_POS.x - 2.6, 0, z), k < 2)
		street_lamp(Vector3(DOOR_POS.x + 3.0, 0, z - 3.0), false)
	# Coral, kelp, rocks
	for i in 22:
		var x := rng.randf_range(-16.0, 22.0)
		var z := rng.randf_range(-14.0, -48.0)
		if absf(x - DOOR_POS.x) < 3.0:
			continue
		coral_cluster(Vector3(x, 0, z))
	for i in 70:
		var x := rng.randf_range(-18.0, 24.0)
		var z := rng.randf_range(-13.5, -55.0)
		if absf(x - DOOR_POS.x) < 2.6:
			continue
		kelp(Vector3(x, 0, z), rng.randf_range(1.5, 5.0), Color(0.25, 0.6, 0.3).lerp(Color(0.5, 0.65, 0.2), rng.randf()))
	for i in 10:
		var x := rng.randf_range(-16.0, 22.0)
		var z := rng.randf_range(-15.0, -50.0)
		if absf(x - DOOR_POS.x) < 3.0:
			continue
		sphere(rng.randf_range(0.5, 1.3), Vector3(x, 0.1, z), Color(0.45, 0.48, 0.5), 0.0, 0.3, false, Vector3(1.3, 0.6, 1.0))
	# Distant hills on the horizon
	for i in 24:
		var a := TAU * i / 24.0
		var d := rng.randf_range(55.0, 70.0)
		var r := rng.randf_range(14.0, 24.0)
		sphere(r, Vector3(cos(a) * d + 4.0, -r * 0.45, sin(a) * d - 10.0), Color(0.2, 0.34, 0.42), 0.0, 0.15)
	for i in 40:
		var x := rng.randf_range(-24.0, 28.0)
		var z := rng.randf_range(-12.0, 22.0)
		if absf(x) < 7.5 and z < 6.5:
			continue  # not inside the shop
		if i % 4 == 0:
			coral_cluster(Vector3(x, 0, z))
		else:
			kelp(Vector3(x, 0, z), rng.randf_range(1.5, 5.0), Color(0.25, 0.6, 0.3).lerp(Color(0.5, 0.65, 0.2), rng.randf()))
	# Bubble vents in the sand
	for p in [Vector3(1.5, 0, -18), Vector3(9.5, 0, -27), Vector3(-6.5, 0, -31)]:
		bubble_vent(p, 16)
	# Glowing jellyfish drifting above the street
	for i in 10:
		var jelly := Node3D.new()
		var base := Vector3(rng.randf_range(-12, 20), rng.randf_range(4.5, 10.0), rng.randf_range(-16, -45))
		jelly.position = base
		add_child(jelly)
		var col: Color = [Color(1, 0.55, 0.85), Color(0.6, 0.85, 1.0), Color(0.8, 0.6, 1.0)][i % 3]
		var bell_mat := std_mat(Color(col, 0.55), 1.2)
		bell_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		var bell := MeshInstance3D.new()
		var bs := SphereMesh.new()
		bs.radius = 0.5
		bs.height = 0.5
		bs.is_hemisphere = true
		bell.mesh = bs
		bell.material_override = bell_mat
		jelly.add_child(bell)
		for k in 5:
			var ten := MeshInstance3D.new()
			var tc := CylinderMesh.new()
			tc.top_radius = 0.025
			tc.bottom_radius = 0.01
			tc.height = 1.2
			ten.mesh = tc
			ten.material_override = bell_mat
			var a := TAU * k / 5.0
			ten.position = Vector3(cos(a) * 0.3, -0.6, sin(a) * 0.3)
			jelly.add_child(ten)
		jellies.append({"node": jelly, "base": base, "phase": rng.randf() * TAU})
	# Schools of fish swimming past
	for row in 2:
		var school := CPUParticles3D.new()
		var fm := SphereMesh.new()
		fm.radius = 0.07
		fm.height = 0.14
		var fish_col: Color = [Color(1, 0.75, 0.3), Color(0.5, 0.8, 1.0)][row]
		fm.material = std_mat(fish_col)
		school.mesh = fm
		school.amount = 40
		school.lifetime = 24.0
		school.preprocess = 24.0
		school.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
		school.emission_box_extents = Vector3(1.0, 1.0, 2.5)
		school.direction = Vector3(1, 0, 0) if row == 0 else Vector3(-1, 0, 0)
		school.spread = 4.0
		school.gravity = Vector3.ZERO
		school.initial_velocity_min = 1.8
		school.initial_velocity_max = 2.2
		school.scale_amount_min = 0.7
		school.scale_amount_max = 1.3
		school.position = Vector3(-30.0, 12.0, -50.0) if row == 0 else Vector3(40.0, 14.0, -30.0)
		add_child(school)


# ---------------------------------------------------------------- 2D art in 3D

func make_art(kind: String, data: Dictionary) -> SubViewport:
	var vp := SubViewport.new()
	vp.size = Vector2i(CharacterArt.ART_SIZE, CharacterArt.ART_SIZE)
	vp.transparent_bg = true
	vp.disable_3d = true
	vp.render_target_update_mode = SubViewport.UPDATE_ONCE
	var art := CharacterArt.new()
	art.kind = kind
	art.data = data
	vp.add_child(art)
	add_child(vp)
	return vp


const SPRITE_DIR := "res://assets/sprites/%s.png"
const BODY_NAMES := ["round", "tall", "wide"]


func override_name(kind: String, data: Dictionary) -> String:
	# File name a custom PNG must have to replace this piece of procedural art.
	match kind:
		"customer":
			return "customer_%s_front" % BODY_NAMES[data["kind"]]
		"customer_back":
			return "customer_%s_back" % BODY_NAMES[data["kind"]]
		"cashier":
			return "cashier_back"
	return kind


func art_texture(kind: String, data: Dictionary) -> Array:
	# Returns [texture, viewport_or_null]. A PNG in assets/sprites/ wins over the drawn art.
	var path := SPRITE_DIR % override_name(kind, data)
	if ResourceLoader.exists(path):
		return [load(path), null]
	var vp := make_art(kind, data)
	return [vp.get_texture(), vp]


func make_sprite(kind: String, data: Dictionary, one_sided := false) -> Sprite3D:
	var art: Array = art_texture(kind, data)
	var tex: Texture2D = art[0]
	var vp = art[1]
	var s := Sprite3D.new()
	s.texture = tex
	# Custom PNGs may be any resolution as long as they keep the exported canvas layout.
	s.pixel_size = PIXEL * CharacterArt.ART_SIZE / float(tex.get_width())
	s.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
	s.double_sided = not one_sided
	var m := ShaderMaterial.new()
	m.shader = CHAR_SHADER_ONE_SIDED if one_sided else CHAR_SHADER
	m.set_shader_parameter("tex", tex)
	m.set_shader_parameter("seed", rng.randf() * TAU)
	m.set_shader_parameter("wobble", 0.05 if kind == "customer" else 0.025)
	s.material_override = m
	s.set_meta("vp", vp)
	return s


func make_actor(kind: String, data: Dictionary, front_kind := "") -> Actor:
	var a := Actor.new()
	a.data = data
	a.pivot = Node3D.new()
	add_child(a.pivot)
	a.body = Node3D.new()
	a.body.position.y = BODY_Y
	a.pivot.add_child(a.body)
	a.sprite = make_sprite(kind, data, front_kind != "")
	a.body.add_child(a.sprite)
	if front_kind != "":
		a.sprite_front = make_sprite(front_kind, data, true)
		a.sprite_front.rotation.y = PI
		a.body.add_child(a.sprite_front)
	if kind == "customer":
		a.height = CharacterArt.customer_height_px(data) * PIXEL
	return a


func free_actor(a: Actor) -> void:
	leaving.erase(a)
	for s in [a.sprite, a.sprite_front]:
		if s != null and is_instance_valid(s):
			var vp = s.get_meta("vp")
			if vp != null and is_instance_valid(vp):
				vp.queue_free()
	if is_instance_valid(a.pivot):
		a.pivot.queue_free()


func make_customer_data() -> Dictionary:
	var nice := rng.randf() < 0.5
	var lines: Array = NICE_LINES if nice else MEAN_LINES
	var kind := rng.randi_range(0, 2)
	var size := rng.randf_range(0.9, 1.1)
	return {
		"nice": nice,
		"line": lines[rng.randi() % lines.size()],
		"color": Color.from_hsv(rng.randf(), rng.randf_range(0.75, 0.95), rng.randf_range(0.85, 1.0)),
		"kind": kind,
		"hat": rng.randi_range(0, 3),
		"glasses": rng.randf() < 0.3,
		"size": size,
		"bob": rng.randf() * TAU,
		"voice": rng.randf_range(1.25, 1.75) * [1.0, 1.12, 0.85][kind] / float(size),
	}


func slot_pos(i: float) -> Vector3:
	if i <= QUEUE_LEN:
		return SLOT0 + SLOT_STEP * i
	var door := SLOT0 + SLOT_STEP * QUEUE_LEN
	var k := i - QUEUE_LEN
	return door + Vector3(0.25 * sin(i * 1.7), 0, -1.15 * k)


func music_beat() -> float:
	# Beats elapsed in the soundtrack (fractional), corrected for audio latency. -1 if silent.
	if music_player == null or not music_player.playing:
		return -1.0
	var pos := music_player.get_playback_position() + AudioServer.get_time_since_last_mix() - AudioServer.get_output_latency()
	return maxf(pos, 0.0) * MUSIC_BPM / 60.0


func hop_height(beat_index: int, seed: float) -> float:
	# Random (but stable within one hop) height per customer per beat: tiny hops to big leaps.
	var r := fposmod(sin(beat_index * 12.9898 + seed * 78.233) * 43758.5453, 1.0)
	return lerpf(0.04, 0.42, r * r)


func layout_queue() -> void:
	var beat := music_beat()
	for i in queue.size():
		var a := queue[i]
		var p := slot_pos(i + queue_offset)
		var stretch := 1.0
		if beat >= 0.0:
			# Hop on every beat: take off on the beat, land just before the next one.
			var n := int(floor(beat))
			var ph := beat - n
			var air := clampf(ph / 0.8, 0.0, 1.0)
			p.y = sin(air * PI) * hop_height(n, a.data["bob"] + i * 0.37)
			if ph > 0.8:  # squash on landing
				stretch = 1.0 - 0.18 * sin((ph - 0.8) / 0.2 * PI)
			elif air < 0.25:  # stretch on take-off
				stretch = 1.0 + 0.12 * sin(air / 0.25 * PI)
		else:
			p.y = (sin(t * 4.0 + a.data["bob"]) * 0.5 + 0.5) * 0.03
		a.pivot.position = p
		a.body.scale = Vector3(1.0 / sqrt(stretch), stretch, 1.0)


func head_screen_pos(a: Actor) -> Vector2:
	return camera.unproject_position(a.pivot.global_transform * Vector3(0, a.height + 0.05, 0))


func on_screen(world: Vector3) -> bool:
	return not camera.is_position_behind(world)


func chest(a: Actor) -> Vector3:
	return a.pivot.position + Vector3(0, a.height * 0.6, 0)


func flying_sprite(tex: Texture2D, from: Vector3, size := 1.0) -> Sprite3D:
	var s := Sprite3D.new()
	s.texture = tex
	s.pixel_size = PIXEL * 0.5 * size * CharacterArt.ART_SIZE / float(tex.get_width())
	s.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
	add_child(s)
	s.position = from
	return s


func throw(tex: Texture2D, from: Vector3, to: Vector3, dur: float, size := 1.0, spin := true) -> void:
	var s := flying_sprite(tex, from, size)
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(s, "position", to, dur)
	if spin:
		tw.tween_property(s, "rotation:z", TAU * 2.0, dur)
	tw.chain().tween_callback(s.queue_free)


func hop(a: Actor, height := 0.25, delay := 0.0) -> void:
	var tw := create_tween()
	tw.tween_interval(maxf(delay, 0.001))
	tw.tween_property(a.body, "position:y", BODY_Y + height, 0.12)
	tw.tween_property(a.body, "position:y", BODY_Y, 0.12)


# ---------------------------------------------------------------- title, intro, countdown

func start_blackout() -> void:
	state = State.BLACKOUT
	black_alpha = 1.0
	get_tree().create_timer(1.0).timeout.connect(start_intro)


func cam_q(pos: Vector3, target: Vector3) -> Quaternion:
	return Transform3D(Basis(), pos).looking_at(target, Vector3.UP).basis.get_rotation_quaternion()


func start_intro() -> void:
	# Fade in outside the shop, glide along the line, through the door, behind the cashier.
	state = State.INTRO
	shot(INTRO_A, INTRO_A_LOOK, 0.0)
	create_tween().tween_property(self, "black_alpha", 0.0, 1.3)
	intro_tween = create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	intro_tween.tween_property(camera, "position", INTRO_B, 4.2)
	intro_tween.parallel().tween_property(camera, "quaternion", cam_q(INTRO_B, INTRO_B_LOOK), 4.2)
	intro_tween.tween_property(camera, "position", INTRO_C, 1.5)
	intro_tween.parallel().tween_property(camera, "quaternion", cam_q(INTRO_C, INTRO_C_LOOK), 1.5)
	var over_pos := Vector3(0.2, 2.45, 3.7)
	intro_tween.tween_property(camera, "position", over_pos, 2.0)
	intro_tween.parallel().tween_property(camera, "quaternion", cam_q(over_pos, Vector3(0.9, 0.75, -3.5)), 2.0)
	intro_tween.tween_callback(start_countdown)


func skip_intro() -> void:
	if intro_tween:
		intro_tween.kill()
	black_alpha = 0.0
	shot_overview(0.5)
	state = State.RESOLVING
	get_tree().create_timer(0.5).timeout.connect(start_countdown)


func start_countdown() -> void:
	state = State.COUNTDOWN
	countdown_n = 3
	countdown_t = 0.0
	hit_idx = 0
	start_music()
	play_hit()


func play_scream(delay: float) -> void:
	# Random death scream (never the same twice in a row), timed to the hit.
	var i := rng.randi() % screams.size()
	if i == last_scream:
		i = (i + 1) % screams.size()
	last_scream = i
	var tw := create_tween()
	tw.tween_interval(delay)
	tw.tween_callback(func():
		scream_player.stream = screams[i]
		scream_player.pitch_scale = rng.randf_range(0.95, 1.1)
		scream_player.play())


func setup_music() -> void:
	music_stream = AudioStreamSynchronized.new()
	music_stream.stream_count = MUSIC_STEMS.size()
	var loop_samples := int(round(MUSIC_LOOP_BEATS * 60.0 / MUSIC_BPM * 44100.0))
	for i in MUSIC_STEMS.size():
		var w: AudioStreamWAV = load(MUSIC_STEMS[i]).duplicate()
		w.loop_mode = AudioStreamWAV.LOOP_FORWARD
		w.loop_begin = 0
		w.loop_end = loop_samples
		music_stream.set_sync_stream(i, w)
		music_stream.set_sync_stream_volume(i, stem_db[i])
	music_player = AudioStreamPlayer.new()
	music_player.stream = music_stream
	music_player.volume_db = -5.0
	add_child(music_player)


func start_music() -> void:
	if not music_player.playing:
		music_player.play()
	set_music_level(0)


func set_music_level(n: int) -> void:
	# Fade stems in/out (they keep playing in sync underneath, so they come back on the beat).
	music_level = clampi(n, 0, MUSIC_STEMS.size() - 1)
	for i in range(1, MUSIC_STEMS.size()):
		var target := 0.0 if i <= music_level else STEM_OFF_DB
		if is_equal_approx(stem_db[i], target):
			continue
		if stem_tweens[i]:
			stem_tweens[i].kill()
		var tw := create_tween()
		tw.tween_method(set_stem_db.bind(i), stem_db[i], target, 0.6 if target > stem_db[i] else 0.9)
		stem_tweens[i] = tw


func set_stem_db(db: float, i: int) -> void:
	stem_db[i] = db
	music_stream.set_sync_stream_volume(i, db)


func danger_level() -> int:
	# 1, 2, 3 when the job bar is 3, 2, 1 steps away from the skull (-5).
	if state in [State.TITLE, State.BLACKOUT, State.INTRO, State.GAME_OVER_ANIM, State.GAME_OVER]:
		return 0
	return clampi(-bar - 1, 0, 3)


func timer_fraction() -> float:
	# How much time is left (1 = plenty, 0 = out) for whatever timer is running, or -1 if none.
	match state:
		State.DECIDE:
			return time_left / time_limit
		State.ATTACK:
			return attack_left / ATTACK_TIME
		State.DANCE:
			return dance_left / dance_beat
		State.PRAY:
			return pray_left / PRAY_TIME if pray_show <= 0.0 else 1.0
		State.FLIP:
			var hottest := 0.0
			for p in patties:
				if not p["flipped"]:
					hottest = maxf(hottest, p["cook"])
			return 1.0 - hottest
	return -1.0


func update_timer_sound() -> void:
	# Ticking loop while any timer runs; speeds up and rises in pitch when time runs low.
	var f := timer_fraction()
	if f < 0.0:
		if timer_player.playing:
			timer_player.stop()
		return
	if not timer_player.playing:
		timer_player.play()
	var urgency := 1.0 - clampf(f / 0.5, 0.0, 1.0)
	timer_player.pitch_scale = lerpf(1.0, 1.4, urgency)


func play_hit() -> void:
	var hp: AudioStreamPlayer = hit_players[hit_idx % hit_players.size()]
	hp.pitch_scale = HIT_PITCHES[mini(hit_idx, HIT_PITCHES.size() - 1)]
	hp.play()
	hit_idx += 1


# ---------------------------------------------------------------- customer flow

func begin_customer() -> void:
	if is_over():
		return
	state = State.TALK
	talk_left = clampf(time_limit * 0.4, 0.7, 1.8)
	time_left = time_limit
	think_line = pick(THINK_LINES)
	shot_talk(queue[0])
	voice.speak(queue[0].data["line"], queue[0].data["voice"], voice_speed())


func voice_speed() -> float:
	return 0.045 * clampf(time_limit / START_TIME, 0.6, 1.0)


func to_decide() -> void:
	state = State.DECIDE
	shot_decide()


func take_current() -> Actor:
	var c: Actor = queue.pop_front()
	queue_offset = 1.0  # keep the line in place until it steps forward
	leaving.append(c)
	return c


func schedule_next(delay: float) -> void:
	get_tree().create_timer(delay).timeout.connect(next_customer)


func next_customer() -> void:
	if is_over():
		return
	queue.append(make_actor("customer", make_customer_data(), "customer_back"))
	var tw := create_tween()
	tw.tween_property(self, "queue_offset", 0.0, 0.35).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_callback(begin_customer)


func walk_off(c: Actor, delay: float, dur: float) -> void:
	var tw := create_tween()
	tw.tween_interval(delay)
	tw.tween_property(c.pivot, "position", EXIT_POS, dur)
	tw.tween_callback(free_actor.bind(c))


func can_decide() -> bool:
	return state == State.TALK or state == State.DECIDE


func in_minigame() -> bool:
	return state in [State.ATTACK, State.FLIP, State.DANCE, State.PRAY]


func timeout() -> void:
	if not can_decide():
		return
	state = State.RESOLVING
	shot_overview()
	var c := take_current()
	say(c, "Hello?! Fine, forget it!", 1.4)
	wrong("Too slow!")
	walk_off(c, 0.5, 1.0)
	schedule_next(0.9)


# ---------------------------------------------------------------- serving (minigames)

func start_serve() -> void:
	match pick(SERVE_GAMES):
		"flip":
			start_flip()
		"dance":
			start_dance()
		_:
			start_pray()


func serve_delivered() -> void:
	# The burger reached the customer: the action always happens, right or wrong.
	state = State.RESOLVING
	var c := take_current()
	if c.data["nice"]:
		chime_player.play()  # correct serve: happy wind chime
		say(c, pick(THANKS_LINES), 1.2)
		correct()
		hop(c, 0.25, 0.1)
		walk_off(c, 0.45, 1.0)
	else:
		say(c, pick(RUNAWAY_LINES), 1.0)
		wrong("DIDN'T PAY!")
		walk_off(c, 0.25, 0.45)
	schedule_next(0.9)


func serve_fail(reason: String) -> void:
	state = State.RESOLVING
	shot_overview()
	var c := take_current()
	say(c, "Terrible service!", 1.4)
	wrong(reason)
	walk_off(c, 0.6, 1.2)
	schedule_next(1.0)


# --- flip burgers: three patties on ← ↑ →; flip each when golden (not raw, not burnt)

func start_flip() -> void:
	state = State.FLIP
	shot_grill()
	var spd := minf(0.7, 0.32 + served * 0.01)
	for p in patties:
		p["cook"] = rng.randf_range(0.0, 0.2)
		p["speed"] = spd * rng.randf_range(0.75, 1.35)
		p["flipped"] = false
		p["mesh"].rotation.x = 0.0
		set_patty_color(p)
	add_popup("Flip the burgers!", Vector2(0, 160), Color(1, 0.9, 0.4), 36, 1.4)


func set_patty_color(p: Dictionary) -> void:
	var raw := Color(0.95, 0.55, 0.55)
	var golden := Color(0.62, 0.36, 0.15)
	var burnt := Color(0.08, 0.06, 0.05)
	var c: float = p["cook"]
	var col := raw.lerp(golden, clampf(c / FLIP_ZONE, 0, 1)) if c < FLIP_ZONE else golden.lerp(burnt, clampf((c - FLIP_ZONE) / (1.0 - FLIP_ZONE), 0, 1))
	p["mat"].albedo_color = col


func flip_patty(i: int) -> void:
	if state != State.FLIP:
		return
	var p: Dictionary = patties[i]
	if p["flipped"]:
		return
	if p["cook"] < FLIP_ZONE:
		flip_fail("Still raw!")
		return
	p["flipped"] = true
	p["cook"] = 0.62
	set_patty_color(p)
	var m: MeshInstance3D = p["mesh"]
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(m, "rotation:x", PI, 0.25)
	tw.tween_property(m, "position:y", m.position.y + 0.25, 0.12)
	tw.chain().tween_property(m, "position:y", m.position.y, 0.12)
	add_popup("Perfect!", Vector2(-220 + i * 220, 420), Color(0.6, 1, 0.5), 26, 0.6)
	for q in patties:
		if not q["flipped"]:
			return
	flip_success()


func flip_success() -> void:
	state = State.RESOLVING
	add_popup("Delicious!", Vector2(0, 220), Color(0.6, 1, 0.5), 44, 0.9)
	var c := queue[0]
	shot_overview(0.35)
	throw(burger_tex, GRILL_POS + Vector3(0, 1.1, 0), chest(c), 0.55)
	get_tree().create_timer(0.55).timeout.connect(serve_delivered)


func flip_fail(reason: String) -> void:
	for p in patties:
		p["cook"] = 0.0
		set_patty_color(p)
	serve_fail(reason)


# --- dance for no reason, then spit out the burger

func start_dance() -> void:
	state = State.DANCE
	shot_dance()
	dance_seq.clear()
	for i in 5:
		dance_seq.append(rng.randi_range(0, 3))
	dance_idx = 0
	dance_beat = maxf(0.5, 0.95 - served * 0.015)
	dance_left = dance_beat + 0.7
	add_popup("Dance!", Vector2(0, 170), Color(1, 0.6, 1), 40, 1.0)
	add_popup("Customer: \"Uh... why are you dancing?\"", Vector2(0, 470), Color(1, 1, 1), 22, 2.0, 0.0)


func dance_input(dir: int) -> void:
	if state != State.DANCE:
		return
	if dir != dance_seq[dance_idx]:
		dance_fail()
		return
	dance_pose(dir)
	dance_idx += 1
	if dance_idx >= dance_seq.size():
		dance_success()
	else:
		dance_left = dance_beat


func dance_pose(dir: int) -> void:
	var b := cashier.body
	var tw := create_tween()
	match dir:
		0:
			tw.tween_property(b, "rotation:z", 0.45, 0.08)
			tw.tween_property(b, "rotation:z", 0.0, 0.15)
		2:
			tw.tween_property(b, "rotation:z", -0.45, 0.08)
			tw.tween_property(b, "rotation:z", 0.0, 0.15)
		1:
			tw.tween_property(b, "position:y", BODY_Y + 0.45, 0.1)
			tw.tween_property(b, "position:y", BODY_Y, 0.14)
		_:
			tw.tween_property(cashier.pivot, "scale", Vector3(1.25, 0.7, 1), 0.08)
			tw.tween_property(cashier.pivot, "scale", Vector3.ONE, 0.15)
	add_popup(pick(DANCE_WORDS), Vector2(rng.randf_range(-200, 200), 240), Color(1, 0.6, 1), 30, 0.6)


func dance_success() -> void:
	state = State.RESOLVING
	add_popup("PTUI!", Vector2(0, 230), Color(1, 0.9, 0.4), 56, 0.9)
	var c := queue[0]
	var tw := create_tween()
	tw.tween_interval(0.35)
	tw.tween_callback(func():
		shot_overview(0.3)
		throw(burger_tex, CASHIER_POS + Vector3(0.1, 1.15, -0.3), chest(c), 0.45))
	tw.tween_interval(0.45)
	tw.tween_callback(serve_delivered)


func dance_fail() -> void:
	cashier.body.rotation.z = 0.0
	add_popup("Off beat!", Vector2(0, 230), Color(1, 0.35, 0.3), 40, 1.0)
	serve_fail("Dance flopped!")


# --- pray: memorise the arrows, repeat them, and a winged burger descends from heaven

func start_pray() -> void:
	state = State.PRAY
	shot_pray()
	pray_seq.clear()
	for i in 4 + mini(2, int(served / 12.0)):
		pray_seq.append(rng.randi_range(0, 3))
	pray_idx = 0
	pray_show = 1.2 + 0.25 * pray_seq.size()
	pray_left = PRAY_TIME
	var tw := create_tween()
	tw.tween_property(pray_light, "light_energy", 2.5, 0.4)


func pray_input(dir: int) -> void:
	if state != State.PRAY:
		return
	if pray_show > 0.0:
		return  # still memorising
	if dir != pray_seq[pray_idx]:
		pray_fail()
		return
	pray_idx += 1
	if pray_idx >= pray_seq.size():
		pray_success()


func pray_success() -> void:
	state = State.RESOLVING
	cashier.body.rotation.z = 0.0
	add_popup("Prayer answered!", Vector2(0, 200), Color(1, 0.95, 0.5), 48, 1.2)
	var c := queue[0]
	shot_heaven(c)
	# beam of light from above
	var beam := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 0.5
	cm.bottom_radius = 0.35
	cm.height = 6.0
	beam.mesh = cm
	var bm := ShaderMaterial.new()
	bm.shader = SHAFT_SHADER
	bm.set_shader_parameter("color", Color(1, 0.9, 0.55))
	bm.set_shader_parameter("strength", 0.0)
	bm.set_shader_parameter("soft_edges", false)
	beam.material_override = bm
	beam.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	beam.position = c.pivot.position + Vector3(0, 3.0, 0)
	add_child(beam)
	var wb := flying_sprite(winged_tex, c.pivot.position + Vector3(0, 4.2, 0.05), 1.3)
	var tw := create_tween()
	tw.tween_property(bm, "shader_parameter/strength", 0.55, 0.3)
	tw.tween_property(wb, "position", chest(c) + Vector3(0, 0.15, 0.05), 1.6).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_method(func(v: float): wb.scale = Vector3(1.0 + 0.18 * sin(v), 1, 1), 0.0, TAU * 6.0, 1.6)
	tw.tween_property(bm, "shader_parameter/strength", 0.0, 0.25)
	tw.tween_callback(func():
		wb.queue_free()
		beam.queue_free()
		serve_delivered())
	create_tween().tween_property(pray_light, "light_energy", 0.0, 0.5)


func pray_fail() -> void:
	cashier.body.rotation.z = 0.0
	create_tween().tween_property(pray_light, "light_energy", 0.0, 0.3)
	add_popup("Wrong prayer!", Vector2(0, 230), Color(1, 0.35, 0.3), 40, 1.0)
	serve_fail("Prayer ignored!")


# ---------------------------------------------------------------- attacking

func start_attack() -> void:
	state = State.ATTACK
	shot_decide()
	attack_seq.clear()
	for i in 4 + mini(2, int(served / 10.0)):
		attack_seq.append(rng.randi_range(0, 3))
	attack_idx = 0
	attack_left = ATTACK_TIME


func attack_input(dir: int) -> void:
	if state != State.ATTACK:
		return
	if dir == attack_seq[attack_idx]:
		attack_idx += 1
		if attack_idx >= attack_seq.size():
			attack_success()
	else:
		attack_fail()


func attack_success(forced_kind := -1) -> void:
	state = State.RESOLVING
	shot_attack()
	var c := take_current()
	var kind := rng.randi_range(0, 2) if forced_kind < 0 else forced_kind
	add_popup(ATTACK_NAMES[kind], Vector2(0, 250), Color(1, 0.6, 0.2), 44, 1.2)
	voice.stop()  # attacked fish scream instead of babbling
	match kind:
		0:
			attack_tornado_kick(c)
		1:
			attack_glove_punch(c)
		_:
			attack_giant_slap(c)
	if c.data["nice"]:
		wrong("That was a nice customer!")
	else:
		correct()
	schedule_next(1.8)


# ---------------------------------------------------------------- attack animations

func hitstop(dur := 0.09) -> void:
	# Freeze-frame on impact (real time, ignores the slowed time scale).
	Engine.time_scale = 0.04
	get_tree().create_timer(dur, true, false, true).timeout.connect(func(): Engine.time_scale = 1.0)


func impact(c: Actor, power: float) -> void:
	hitstop()
	shake = power
	c.say = "OUCH!"
	c.say_t = 1.0
	play_scream(0.0)
	impact_burst(chest(c) + Vector3(0, 0.15, 0.1))


func impact_burst(pos: Vector3) -> void:
	# Comic "POW" star burst + flying sparks at the hit point.
	var star := MeshInstance3D.new()
	var pm := PrismMesh.new()
	pm.size = Vector3(0.5, 0.5, 0.02)
	star.mesh = pm
	star.material_override = std_mat(Color(1, 0.9, 0.3), 2.0)
	star.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	star.position = pos
	add_child(star)
	var star2: MeshInstance3D = star.duplicate()
	star2.rotation.z = PI
	add_child(star2)
	for m in [star, star2]:
		m.scale = Vector3.ONE * 0.2
		var tw := create_tween()
		tw.tween_property(m, "scale", Vector3.ONE * 2.2, 0.12).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tw.tween_property(m, "scale", Vector3.ZERO, 0.2)
		tw.tween_callback(m.queue_free)
	var sparks := CPUParticles3D.new()
	var sm := SphereMesh.new()
	sm.radius = 0.04
	sm.height = 0.08
	sm.material = std_mat(Color(1, 0.95, 0.6), 2.0)
	sparks.mesh = sm
	sparks.one_shot = true
	sparks.explosiveness = 1.0
	sparks.amount = 24
	sparks.lifetime = 0.5
	sparks.spread = 180.0
	sparks.gravity = Vector3(0, -6, 0)
	sparks.initial_velocity_min = 2.5
	sparks.initial_velocity_max = 5.0
	sparks.position = pos
	add_child(sparks)
	sparks.emitting = true
	get_tree().create_timer(1.0).timeout.connect(sparks.queue_free)


func launch(c: Actor, offset: Vector3, dur: float, spin_z: float, spin_y := 0.0) -> Tween:
	# Send a customer flying with a ballistic arc and spin, then remove it.
	var start := c.pivot.position
	var tw := create_tween().set_parallel(true)
	tw.tween_property(c.pivot, "position:x", start.x + offset.x, dur)
	tw.tween_property(c.pivot, "position:z", start.z + offset.z, dur)
	tw.tween_method(func(k: float): c.pivot.position.y = start.y + offset.y * sin(k * PI * 0.75) * 1.4, 0.0, 1.0, dur)
	tw.tween_property(c.body, "rotation:z", spin_z, dur)
	if spin_y != 0.0:
		tw.tween_property(c.body, "rotation:y", spin_y, dur)
	tw.tween_property(c.pivot, "scale", Vector3.ONE * 0.5, dur)
	tw.chain().tween_callback(free_actor.bind(c))
	return tw


func attack_tornado_kick(c: Actor) -> void:
	# Crouch -> spinning leap over the counter inside a wind funnel -> kick -> hop back.
	var target := c.pivot.position + Vector3(-0.35, 0, 0.6)
	var home := CASHIER_POS
	var tornado := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 0.75
	cm.bottom_radius = 0.15
	cm.height = 1.9
	cm.cap_top = false
	cm.cap_bottom = false
	tornado.mesh = cm
	var tm := std_mat(Color(0.85, 0.97, 1.0, 0.35), 0.6)
	tm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	tm.cull_mode = BaseMaterial3D.CULL_DISABLED
	tornado.material_override = tm
	tornado.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	tornado.position = Vector3(0, 0.95, 0)
	tornado.scale = Vector3.ZERO
	cashier.pivot.add_child(tornado)
	var tw := create_tween()
	# crouch
	tw.tween_property(cashier.pivot, "scale", Vector3(1.25, 0.7, 1), 0.18).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	# leap + spin
	tw.tween_property(cashier.pivot, "scale", Vector3.ONE, 0.08)
	tw.parallel().tween_property(tornado, "scale", Vector3.ONE, 0.15)
	tw.parallel().tween_property(cashier.pivot, "position:x", target.x, 0.45).set_trans(Tween.TRANS_SINE)
	tw.parallel().tween_property(cashier.pivot, "position:z", target.z, 0.45).set_trans(Tween.TRANS_SINE)
	tw.parallel().tween_method(func(k: float): cashier.pivot.position.y = sin(k * PI) * 1.0, 0.0, 1.0, 0.45)
	tw.parallel().tween_property(cashier.body, "rotation:y", TAU * 4.0, 0.45).from(0.0)
	tw.parallel().tween_method(func(a: float): tornado.rotation.y = a, 0.0, -TAU * 6.0, 0.6)
	# KICK
	tw.tween_callback(func():
		cashier.body.rotation.y = 0.0
		impact(c, 22.0)
		launch(c, Vector3(3.5, 3.5, -9.0), 0.9, 16.0, TAU * 3.0))
	tw.tween_property(tornado, "scale", Vector3.ZERO, 0.2)
	tw.tween_callback(tornado.queue_free)
	# hop back home
	tw.tween_interval(0.15)
	tw.tween_callback(func():
		if is_over():
			return
		var back := create_tween().set_parallel(true)
		back.tween_property(cashier.pivot, "position:x", home.x, 0.4).set_trans(Tween.TRANS_SINE)
		back.tween_property(cashier.pivot, "position:z", home.z, 0.4).set_trans(Tween.TRANS_SINE)
		back.tween_method(func(k: float): cashier.pivot.position.y = sin(k * PI) * 0.6, 0.0, 1.0, 0.4)
		back.chain().tween_property(cashier.pivot, "scale", Vector3(1.15, 0.85, 1), 0.07)
		back.chain().tween_property(cashier.pivot, "scale", Vector3.ONE, 0.1))


func beam_between(m: MeshInstance3D, a: Vector3, b: Vector3) -> void:
	var d := b - a
	var q := Quaternion(Vector3.UP, d.normalized()) if d.length() > 0.001 else Quaternion()
	m.transform = Transform3D(Basis(q) * Basis.from_scale(Vector3(1, maxf(d.length(), 0.01), 1)), (a + b) * 0.5)


func attack_glove_punch(c: Actor) -> void:
	# Wind-up -> giant boxing glove on a spring arm shoots out -> launches the customer down the line.
	var hand := CASHIER_POS + Vector3(0.45, 1.05, -0.2)
	var face := c.pivot.position + Vector3(-0.1, c.height * 0.62, 0.35)
	var glove := flying_sprite(glove_tex, hand, 1.0)
	glove.scale = Vector3.ONE * 0.4
	var arm := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.045
	cyl.bottom_radius = 0.045
	cyl.height = 1.0
	cyl.radial_segments = 8
	arm.mesh = cyl
	arm.material_override = std_mat(Color(0.75, 0.78, 0.85))
	add_child(arm)
	var a := camera.unproject_position(hand)
	var b := camera.unproject_position(face)
	glove.rotation.z = atan2(-(b.y - a.y), b.x - a.x)  # point the fist along the punch on screen
	var pullback := hand + Vector3(-0.4, 0.22, -0.05)  # wind up sideways, not towards the camera
	var set_glove := func(p: Vector3) -> void:
		glove.position = p
		beam_between(arm, hand, p)
	set_glove.call(hand)
	var tw := create_tween()
	# wind-up: glove pulls back and wobbles, cashier leans back
	tw.tween_method(func(k: float): set_glove.call(hand.lerp(pullback, k)), 0.0, 1.0, 0.28).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(glove, "scale", Vector3.ONE * 0.65, 0.28)
	tw.parallel().tween_property(cashier.body, "rotation:z", 0.25, 0.28)
	tw.parallel().tween_method(func(k: float): glove.rotation.z += sin(k * 40.0) * 0.02, 0.0, 1.0, 0.28)
	# PUNCH: fast and huge
	tw.tween_method(func(k: float): set_glove.call(pullback.lerp(face, k)), 0.0, 1.0, 0.1).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_IN)
	tw.parallel().tween_property(glove, "scale", Vector3.ONE * 3.2, 0.1)
	tw.parallel().tween_property(cashier.body, "rotation:z", -0.2, 0.1)
	tw.tween_callback(func():
		impact(c, 20.0)
		c.pivot.scale = Vector3(0.6, 1.25, 1)  # squished against the glove
		launch(c, Vector3(0.6, 1.8, -12.0), 0.8, -10.0))
	# glove overshoots a little, then retracts on the spring
	tw.tween_method(func(k: float): set_glove.call(face.lerp(face + (face - hand).normalized() * 0.3, k)), 0.0, 1.0, 0.1)
	tw.tween_interval(0.15)
	tw.tween_method(func(k: float): set_glove.call((face + (face - hand).normalized() * 0.3).lerp(hand, k)), 0.0, 1.0, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	tw.parallel().tween_property(glove, "scale", Vector3.ZERO, 0.3)
	tw.parallel().tween_property(cashier.body, "rotation:z", 0.0, 0.3)
	tw.tween_callback(func():
		glove.queue_free()
		arm.queue_free())


func attack_giant_slap(c: Actor) -> void:
	# Huge fin-hand winds up beside the customer, swings through -> customer spins like a top and keels over.
	var p := c.pivot.position
	var hand := flying_sprite(hand_tex, p + Vector3(1.5, c.height * 0.85, -0.1), 1.0)
	hand.scale = Vector3.ZERO
	hand.rotation.z = 0.7
	var tw := create_tween()
	# appear + wind-up (raise further back)
	tw.tween_property(hand, "scale", Vector3.ONE * 2.0, 0.16).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(hand, "rotation:z", 1.15, 0.16).set_trans(Tween.TRANS_SINE)
	tw.parallel().tween_property(hand, "position", p + Vector3(1.75, c.height * 0.95, -0.1), 0.16)
	tw.parallel().tween_property(cashier.body, "rotation:z", -0.3, 0.16)
	# SWING
	tw.tween_property(hand, "position", p + Vector3(-0.35, c.height * 0.6, 0.35), 0.09).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_IN)
	tw.parallel().tween_property(hand, "rotation:z", -0.55, 0.09)
	tw.parallel().tween_property(cashier.body, "rotation:z", 0.35, 0.09)
	tw.tween_callback(func():
		impact(c, 15.0)
		var spin := create_tween()
		# spin like a top while sliding left...
		spin.tween_property(c.body, "rotation:y", TAU * 5.0, 0.7).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		spin.parallel().tween_property(c.pivot, "position", p + Vector3(-1.2, 0, -0.4), 0.7)
		# ...then keel over and slide off
		spin.tween_property(c.pivot, "rotation:z", 1.45, 0.18).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
		spin.tween_property(c.pivot, "position", p + Vector3(-3.5, 0, -1.6), 0.45)
		spin.parallel().tween_property(c.pivot, "scale", Vector3.ZERO, 0.45)
		spin.tween_callback(free_actor.bind(c)))
	# follow-through and fade out
	tw.tween_property(hand, "position", p + Vector3(-1.4, c.height * 0.45, 0.35), 0.18).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(hand, "rotation:z", -0.95, 0.18)
	tw.parallel().tween_property(cashier.body, "rotation:z", 0.0, 0.25)
	tw.tween_property(hand, "scale", Vector3.ZERO, 0.2)
	tw.tween_callback(hand.queue_free)


func attack_fail() -> void:
	state = State.RESOLVING
	shot_overview()
	var c := take_current()
	say(c, "Terrible service!", 1.4)
	wrong("Attack failed!")
	walk_off(c, 0.6, 1.2)
	schedule_next(1.0)


# ---------------------------------------------------------------- scoring & boss

func correct() -> void:
	score += 10 * mult
	mult = mini(MAX_MULT, mult + 1)
	streak += 1
	served += 1
	bar = mini(BAR_MAX, bar + 1)
	time_limit = maxf(MIN_TIME, time_limit * TIME_FACTOR)
	set_music_level(music_level + 1)
	var size := 34 + mini(streak, 20) * 2
	add_popup(pick(PRAISE_WORDS), Vector2(rng.randf_range(-140, 140), 200), Color(0.5, 1.0, 0.4), size, 0.9)


func wrong(reason: String) -> void:
	streak = 0
	mult = 1
	bar = maxi(-BAR_MAX, bar - 1)
	mistakes += 1
	set_music_level(0)  # any mistake drops straight back to just the bass
	add_popup(reason, Vector2(0, 330), Color(1, 0.35, 0.3), 36, 1.1)
	if bar <= -BAR_MAX:
		game_over()
	elif mistakes % 2 == 0:
		boss_shout()


func boss_shout() -> void:
	# The boss pops in at the left edge of whatever the camera is looking at.
	if boss_mode == "kick":
		return
	if boss_tween:
		boss_tween.kill()
	boss_mode = "shout"
	boss_slide = 0.0
	boss.sprite.no_depth_test = true
	boss.pivot.visible = true
	say(boss, pick(BOSS_LINES), 1.9)
	boss_tween = create_tween()
	boss_tween.tween_property(self, "boss_slide", 1.0, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	boss_tween.tween_interval(1.4)
	boss_tween.tween_property(self, "boss_slide", 0.0, 0.25)
	boss_tween.tween_callback(func():
		if boss_mode == "shout":
			boss_mode = ""
			boss.pivot.visible = false)


func game_over() -> void:
	state = State.GAME_OVER_ANIM
	if score > highscore:
		highscore = score
		new_highscore = true
		save_highscore()
	if boss_tween:
		boss_tween.kill()
	# Tornado kick from 10 metres away: the boss flies in from the far door.
	boss_mode = "kick"
	shot_overview(0.4)
	boss.sprite.no_depth_test = false
	boss.pivot.visible = true
	boss.pivot.transform = Transform3D(Basis().scaled(Vector3.ONE * 1.1), Vector3(SLOT0.x + SLOT_STEP.x * QUEUE_LEN, 0, -11.8))
	say(boss, "HIIIYAAA!", 1.6)
	var target := CASHIER_POS + Vector3(0.9, 0.0, -0.55)
	var mid := (boss.pivot.position + target) * 0.5 + Vector3(0, 2.2, 0)
	boss_tween = create_tween()
	boss_tween.tween_interval(0.4)
	boss_tween.tween_property(boss.pivot, "position", mid, 0.7).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	boss_tween.tween_property(boss.pivot, "position", target, 0.6).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	boss_tween.parallel().tween_property(boss.body, "rotation:z", TAU * 6.0, 1.3).from(0.0)
	boss_tween.tween_callback(kick_cashier)


func kick_cashier() -> void:
	shake = 22.0
	boss.body.rotation.z = 0.0
	say(boss, "You're fired!", 2.5)
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(cashier.pivot, "position", CASHIER_POS + Vector3(-4.0, 4.5, 2.0), 0.9)
	tw.tween_property(cashier.body, "rotation:z", 12.0, 0.9)
	tw.chain().tween_callback(func(): state = State.GAME_OVER)


func restart(to_title: bool) -> void:
	# Try again skips straight to the countdown; Menu goes back to the start screen.
	skip_title = not to_title
	get_tree().reload_current_scene()


func is_over() -> bool:
	return state == State.GAME_OVER_ANIM or state == State.GAME_OVER


# ---------------------------------------------------------------- helpers

func pick(arr: Array) -> Variant:
	return arr[rng.randi() % arr.size()]


func say(a: Actor, text_: String, dur: float) -> void:
	a.say = text_
	a.say_t = dur
	if a == boss:
		boss_voice.speak(text_, 0.72, 0.05)
	elif a.data.has("voice"):
		voice.speak(text_, a.data["voice"], 0.04)


func add_popup(text_: String, pos: Vector2, color: Color, size: int, life: float, rise := 50.0) -> void:
	popups.append({"text": text_, "pos": pos, "color": color, "size": size, "life": life, "t": 0.0, "rise": rise})


func load_highscore() -> void:
	if FileAccess.file_exists(SAVE_PATH):
		var f := FileAccess.open(SAVE_PATH, FileAccess.READ)
		if f:
			highscore = f.get_32()


func save_highscore() -> void:
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f:
		f.store_32(highscore)


# ---------------------------------------------------------------- loop & input

func _process(delta: float) -> void:
	t += delta
	handle_input()
	layout_queue()
	match state:
		State.COUNTDOWN:
			countdown_t += delta
			if countdown_n > 0 and countdown_t >= 0.8:
				countdown_n -= 1
				countdown_t = 0.0
				play_hit()
			elif countdown_n == 0 and countdown_t >= 0.7:
				add_popup("Serve the nice ones, deal with the mean ones!", Vector2(0, 170), Color(1, 1, 0.6), 30, 2.0, 0.0)
				begin_customer()
		State.TALK:
			talk_left -= delta
			if talk_left <= 0.0 and not voice.speaking:
				to_decide()
		State.DECIDE:
			time_left -= delta
			if time_left <= 0.0:
				timeout()
		State.ATTACK:
			attack_left -= delta
			if attack_left <= 0.0:
				attack_fail()
		State.FLIP:
			for p in patties:
				if not p["flipped"]:
					p["cook"] += p["speed"] * delta
					set_patty_color(p)
					if p["cook"] >= 1.0:
						flip_fail("Burnt!")
						break
		State.DANCE:
			dance_left -= delta
			if dance_left <= 0.0:
				dance_fail()
		State.PRAY:
			cashier.body.rotation.z = sin(t * 2.5) * 0.08
			if pray_show > 0.0:
				pray_show -= delta
			else:
				pray_left -= delta
				if pray_left <= 0.0:
					pray_fail()
	for j in jellies:
		var n: Node3D = j["node"]
		var ph: float = j["phase"]
		n.position = j["base"] + Vector3(sin(t * 0.3 + ph) * 0.8, sin(t * 0.9 + ph) * 0.6, 0)
		var pulse := 1.0 + 0.12 * sin(t * 2.4 + ph)
		n.scale = Vector3(pulse, 2.0 - pulse, pulse)
	if lighthouse_beam:
		lighthouse_beam.rotation.y = t * 0.8
	if boss_mode == "shout":
		var local := Transform3D(Basis().scaled(Vector3.ONE * 0.75), Vector3(lerpf(-2.7, -1.15, boss_slide), -1.05, -2.3))
		boss.pivot.global_transform = camera.global_transform * local
	for a in leaving:
		a.say_t -= delta
	boss.say_t -= delta
	for p in popups:
		p["t"] += delta
		p["pos"] = p["pos"] + Vector2(0, -p["rise"] * delta)
	popups = popups.filter(func(p): return p["t"] < p["life"])
	update_timer_sound()
	bar_shown = lerpf(bar_shown, float(bar), 1.0 - exp(-12.0 * delta))
	shake = maxf(0.0, shake - 40.0 * delta)
	var dl := danger_level()
	danger = lerpf(danger, DANGER_VIGNETTE[dl], 1.0 - exp(-4.0 * delta))
	danger_mat.set_shader_parameter("strength", danger * (0.85 + 0.15 * sin(t * 4.0)))
	var k := danger / 2.4  # 0..1
	danger_mat.set_shader_parameter("inner", lerpf(0.42, 0.2, k))  # red creeps further in each level
	danger_mat.set_shader_parameter("outer", lerpf(0.72, 0.5, k))
	danger_mat.set_shader_parameter("max_alpha", lerpf(0.75, 0.97, k))
	var tremble := Vector2.ZERO
	if dl > 0:
		# same gentle shake at every danger level - only the vignette gets stronger
		tremble = Vector2(sin(t * 21.0) + sin(t * 13.7) * 0.6, cos(t * 17.3) + sin(t * 9.1) * 0.5) * 0.012
	# Beat zoom: once the keys (piano) stem is in, punch in on every beat and ease back out.
	var keys_mix := clampf(db_to_linear(stem_db[3]), 0.0, 1.0)
	var beat := music_beat()
	var punch := 0.0
	if beat >= 0.0 and keys_mix > 0.01 and not is_over():
		punch = exp(-(beat - floor(beat)) * 7.0) * keys_mix
	camera.fov = BASE_FOV - BEAT_ZOOM_DEG * punch
	camera.h_offset = rng.randf_range(-shake, shake) * 0.006 + tremble.x
	camera.v_offset = rng.randf_range(-shake, shake) * 0.006 + tremble.y


func just_pressed_arrow() -> int:
	for i in 4:
		if Input.is_action_just_pressed(ARROW_ACTIONS[i]):
			return i
	return -1


func handle_input() -> void:
	# Polled every frame (works for keyboard and injected test input alike).
	var dir := just_pressed_arrow()
	var any_now := Input.is_anything_pressed()
	var any_just := any_now and not prev_any
	prev_any = any_now
	match state:
		State.TITLE:
			if any_just:
				start_blackout()
		State.INTRO:
			if any_just:
				skip_intro()
		State.TALK, State.DECIDE:
			if dir == 2:
				start_serve()
			elif dir == 0:
				start_attack()
		State.ATTACK:
			if dir >= 0:
				attack_input(dir)
		State.FLIP:
			if dir >= 0 and dir <= 2:
				flip_patty(dir)
		State.DANCE:
			if dir >= 0:
				dance_input(dir)
		State.PRAY:
			if dir >= 0:
				pray_input(dir)
		State.GAME_OVER:
			if Input.is_key_pressed(KEY_R):  # shortcut; the HUD buttons handle mouse/Enter
				restart(false)
