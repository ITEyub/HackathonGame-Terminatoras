extends Node3D
## 2.5D endless cashier arcade: a 3D restaurant with flat 2D characters (Sprite3D).
## Per customer: TALK (camera on customer) -> DECIDE (front view of the cashier, "Was jetzt?")
## -> Right = serve (random minigame: flip burgers / dance / pray) or Left = attack (arrow sequence).

# (hud.gd mirrors these values - keep the order)
enum State { TALK, DECIDE, ATTACK, FLIP, DANCE, PRAY, RESOLVING, GAME_OVER_ANIM, GAME_OVER, TITLE, BLACKOUT, INTRO, COUNTDOWN, CINEMA }

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
const Menu := preload("res://scripts/menu.gd")
const Scores := preload("res://scripts/scores.gd")
const Animalese := preload("res://scripts/animalese.gd")
const Cine := preload("res://scripts/cinematic.gd")
const VALKYRIES := preload("res://assets/sounds/valkyries.mp3")
const EXPLOSION_SOUND := preload("res://assets/sounds/explosion.mp3")
const PARA_START := Vector3(1.6, 15.0, -16.5)
const PARA_LAND := Vector3(2.6, 0.0, -14.6)   # beside the line in front of the door
const COUNTDOWN_HIT := preload("res://assets/sounds/philly_hit.ogg")
const HIT_PITCHES := [1.0, 1.08, 1.17, 1.28]  # 3, 2, 1, GO - each hit a bit higher
const SCREAM_DIR := "res://assets/sounds/death_screams/scream_%02d.wav"
const SCREAM_COUNT := 21
const TIMER_SOUND := preload("res://assets/sounds/timer.mp3")
const CHIME_SOUND := preload("res://assets/sounds/wind-chime.mp3")
const HALLELUJAH_SOUND := preload("res://assets/sounds/hallelujah.mp3")
const CROWD_SOUND := preload("res://assets/sounds/crowd.mp3")
const PUNCH_SOUND := preload("res://assets/sounds/punch.mp3")
const CROWD_NEAR := 2.5    # metres: full volume this close to the nearest customer
const CROWD_FAR := 22.0    # metres: silent from this far away
const MUSIC_DB := -1.0
const MUSIC_DUCK_DB := -24.0  # soundtrack level while the holy burger floats
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
static var skip_cinematic := false  # "Menu" from game over goes straight to the start screen

var state: State = State.TITLE
var black_alpha := 0.0
var cine_t := 0.0
var cine_skip := -1.0  # >= 0 while the skip fade-to-black runs
const CINE_SKIP_FADE := 0.6
var cine_3d := false
var cine_landed := false
var cine_tex := {}
var para: Actor
var parachute: Node3D
var valk_player: AudioStreamPlayer
var type_players: Array[AudioStreamPlayer] = []
var type_clacks: Array[AudioStreamWAV] = []
var type_ding: AudioStreamWAV
var type_idx := 0
var typed_shown := {}
var spoken_lines := {}
var heli_player: AudioStreamPlayer
var heli_db := -60.0
var fx_player: AudioStreamPlayer
var sizzle_player: AudioStreamPlayer
var boom_played := false
var valk_lowpass: AudioEffectLowPassFilter
var title_t := 0.0
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
var holy_player: AudioStreamPlayer
var crowd_player: AudioStreamPlayer
var punch_player: AudioStreamPlayer
var crowd_level := 0.0
var holy_tween: Tween
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
# chase cam: after a hit the camera tracks and zooms in on the flying fish for a moment
const CHASE_TIME := 0.6
const CHASE_FILL := 0.42  # how much of the screen height the fish should fill
var chase_actor: Actor
var chase_t := 0.0
var chase_zoom := 0.0
var chase_fov := 30.0
var chase_point := Vector3.ZERO
var chase_hold := false  # fish exploded: keep looking at the explosion
var boom_player: AudioStreamPlayer
var hud: Node2D
var scores: Node2D  # name entry + highscore table after a game over (scores.gd)
var menu: Node2D  # pause menu / options / title quit button (menu.gd)
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
# attack minigame variants: "combo" (arrow sequence), "rage" (mash space), "quiz" (quiz show)
var attack_mode := "combo"
var attack_time := ATTACK_TIME
var last_attack_mode := ""
var rage := 0.0        # 0..1
var rage_need := 20    # presses for a full bar
var rage_drain := 0.2  # bar lost per second
var rage_steam: Array[CPUParticles3D] = []
# power-up: golden aura, rising energy, floating rocks, light and a charging hum
var aura_meshes: Array[MeshInstance3D] = []
var aura_flames: CPUParticles3D
var aura_rocks: CPUParticles3D
var aura_light: OmniLight3D
var charge_player: AudioStreamPlayer
var power_flash := 0.0  # 1 -> 0 white flash when the bar is full
var quiz := {}         # {q, answers: [4], correct}
var quiz_pick := -1    # -1 nothing yet, 0..3 chosen, -2 ran out of time
var quiz_t := 0.0      # time since the pick
var quiz_revealed := false
var quiz_used: Array[int] = []
var quiz_music: AudioStreamPlayer
var quiz_fx: AudioStreamPlayer
var quiz_sting := {}
var mash_player: AudioStreamPlayer
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
# restaurant life: guests at the tables, the slot machine's reels and lights
var diners: Array[Actor] = []
var slot_reels: Array[Label3D] = []
var slot_lights: Array[MeshInstance3D] = []
var slot_spin_t := 2.0  # countdown to the next spin
var slot_spinning := 0.0
var open_sign: Label3D
const DECOR_FONT := preload("res://assets/fonts/Fredoka.ttf")
const TABLES := [Vector3(-3.6, 0, -3.5), Vector3(-3.6, 0, -7.0), Vector3(-3.6, 0, -10.0)]
const SLOT_SYMBOLS := ["7", "$", "*", "B", "#"]


func _ready() -> void:
	get_tree().node_added.connect(_on_node_added)  # before anything is built: see optimize_mesh()
	rng.randomize()
	load_highscore()
	build_world()
	burger_tex = art_texture("burger", {})[0]
	tray_tex = art_texture("tray", {})[0]
	winged_tex = art_texture("winged_burger", {})[0]
	glove_tex = art_texture("glove", {})[0]
	hand_tex = art_texture("hand", {})[0]
	build_warm_rig()
	boom_player = AudioStreamPlayer.new()  # generated up front: building it mid-game costs a frame
	boom_player.stream = EXPLOSION_SOUND
	boom_player.volume_db = 4.0
	add_child(boom_player)
	Engine.time_scale = 1.0
	cashier = make_actor("cashier", {}, "cashier_front")
	cashier.pivot.position = CASHIER_POS
	cashier.height = 1.75
	setup_attack_variants()
	boss = make_actor("boss", {})
	boss.height = 2.0
	boss.pivot.visible = false
	# the boss is hidden until his first shout: keep a sub-pixel copy on screen so that first
	# appearance doesn't have to build his shader mid-game (see build_warm_rig)
	var boss_warm: Sprite3D = boss.sprite.duplicate()
	boss_warm.no_depth_test = true
	camera.get_node("WarmRig").add_child(boss_warm)
	for i in QUEUE_TOTAL:
		queue.append(make_actor("customer", make_customer_data(), "customer_back"))
	layout_queue()
	spawn_diners()
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
	scores = Scores.new()
	scores.game = self
	layer.add_child(scores)
	var mlayer := CanvasLayer.new()
	mlayer.layer = 5
	add_child(mlayer)
	menu = Menu.new()
	menu.game = self
	mlayer.add_child(menu)
	if OS.get_cmdline_user_args().has("bench"):  # automatic performance run, see bench.gd
		var bench: Node = load("res://scripts/bench.gd").new()
		bench.game = self
		add_child(bench)
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
	punch_player = AudioStreamPlayer.new()
	punch_player.stream = PUNCH_SOUND
	add_child(punch_player)
	crowd_player = AudioStreamPlayer.new()
	var cs: AudioStreamMP3 = CROWD_SOUND.duplicate()
	cs.loop = true
	crowd_player.stream = cs
	crowd_player.volume_db = -60.0
	add_child(crowd_player)
	holy_player = AudioStreamPlayer.new()
	holy_player.stream = HALLELUJAH_SOUND
	add_child(holy_player)
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
	setup_cinema_audio()
	if skip_title:
		skip_title = false
		shot_overview(0.0)
		start_countdown()
	elif skip_cinematic:
		skip_cinematic = false
		go_title()
	else:
		start_cinematic()


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
	# Default is 4 shadow splits over 100 m: every shadow caster is drawn 4 extra times.
	# 2 splits over 60 m draws half as much and gives each split more shadow-map pixels (sharper).
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS
	sun.directional_shadow_max_distance = 60.0
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

	build_decor()

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


# ---------------------------------------------------------------- restaurant interior details

func prop(m: MeshInstance3D) -> MeshInstance3D:
	# small decoration: no shadow (cheaper, and keeps the floor lighting clean)
	m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return m


func wall_text(text_: String, pos: Vector3, yaw: float, col: Color, size := 64, outline := 12, outline_col := Color(0.05, 0.05, 0.12)) -> Label3D:
	# Flat text on a wall. yaw 0 = readable from +Z, PI/2 = from +X, -PI/2 = from -X, PI = from -Z.
	var l := Label3D.new()
	l.text = text_
	l.font = DECOR_FONT
	l.font_size = size
	l.pixel_size = 0.005
	l.modulate = col
	l.outline_size = outline
	l.outline_modulate = outline_col
	l.position = pos
	l.rotation.y = yaw
	l.double_sided = false
	l.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(l)
	return l


func floor_marks(col: Color, marks: Array) -> void:
	# Dirt / spills: flat translucent blobs just above the floor, one draw call per colour.
	# marks: [[x, z, radius_x, radius_z, angle], ...]
	var disc := CylinderMesh.new()
	disc.top_radius = 1.0
	disc.bottom_radius = 1.0
	disc.height = 0.002
	disc.radial_segments = 20
	disc.rings = 1
	var m := StandardMaterial3D.new()
	m.albedo_color = col
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.roughness = 0.25 if col.a > 0.5 else 1.0  # wet spills shine a little
	disc.material = m
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = disc
	mm.instance_count = marks.size()
	for i in marks.size():
		var d: Array = marks[i]
		var b := Basis(Vector3.UP, d[4]).scaled(Vector3(d[2], 1.0, d[3]))
		mm.set_instance_transform(i, Transform3D(b, Vector3(d[0], 0.004 + i * 0.0003, d[1])))
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mmi)


func build_decor() -> void:
	var r := RandomNumberGenerator.new()
	r.seed = 1234  # same room every time

	# --- tables with condiments, napkins, drinks and a hanging lamp above each
	for tp in TABLES:
		var p: Vector3 = tp
		cylinder(0.62, 0.07, p + Vector3(0, 0.78, 0), Color(1.0, 0.3, 0.35))
		prop(cylinder(0.64, 0.02, p + Vector3(0, 0.745, 0), Color(0.95, 0.85, 0.3)))  # chrome-ish rim
		cylinder(0.07, 0.75, p + Vector3(0, 0.375, 0), Color(0.4, 0.4, 0.45))
		prop(cylinder(0.3, 0.04, p + Vector3(0, 0.02, 0), Color(0.35, 0.35, 0.4)))
		prop(cylinder(0.035, 0.2, p + Vector3(0.18, 0.92, -0.12), Color(0.9, 0.1, 0.1)))   # ketchup
		prop(cylinder(0.035, 0.2, p + Vector3(0.27, 0.92, -0.08), Color(1.0, 0.8, 0.1)))   # mustard
		prop(box(Vector3(0.14, 0.12, 0.08), p + Vector3(-0.2, 0.88, -0.15), Color(0.85, 0.85, 0.9)))  # napkins
		prop(box(Vector3(0.1, 0.03, 0.06), p + Vector3(-0.2, 0.955, -0.15), Color(1, 1, 1)))
		# soda cup with straw
		prop(cylinder(0.06, 0.18, p + Vector3(0.05, 0.91, 0.2), Color(0.2, 0.75, 0.95)))
		prop(cylinder(0.012, 0.16, p + Vector3(0.07, 1.04, 0.2), Color(1, 0.3, 0.4), Vector3(0, 0, 12)))
		# pendant lamp
		prop(cylinder(0.012, 2.1, p + Vector3(0, 3.95, 0), Color(0.15, 0.15, 0.18)))
		var shade := prop(cone(0.32, 0.08, 0.28, p + Vector3(0, 2.62, 0), Color(0.1, 0.55, 0.45)))
		shade.material_override = std_mat(Color(0.1, 0.55, 0.45))
		prop(sphere(0.1, p + Vector3(0, 2.6, 0), Color(1.0, 0.9, 0.6), 2.5))

	# --- slot machine against the left wall, near the counter
	var sm := Vector3(-5.45, 0, -1.25)
	var yaw := PI / 2.0  # faces +X, into the room
	box(Vector3(0.75, 1.15, 0.85), sm + Vector3(0, 0.575, 0), Color(0.75, 0.08, 0.12))
	box(Vector3(0.6, 0.55, 0.8), sm + Vector3(0.02, 1.42, 0), Color(0.85, 0.12, 0.15)).rotation.z = -0.12
	prop(box(Vector3(0.78, 0.08, 0.88), sm + Vector3(0, 1.17, 0), Color(1.0, 0.8, 0.15), 0.3))
	prop(box(Vector3(0.62, 0.2, 0.86), sm + Vector3(0.0, 1.8, 0), Color(1.0, 0.75, 0.1), 0.6))  # light bar
	prop(box(Vector3(0.05, 0.3, 0.62), sm + Vector3(0.36, 1.38, 0), Color(0.05, 0.05, 0.1)))  # reel window
	for k in 3:
		var z := -0.2 + k * 0.2
		prop(box(Vector3(0.02, 0.24, 0.16), sm + Vector3(0.385, 1.38, z), Color(1, 1, 0.95), 0.5))
		var reel := wall_text("7", sm + Vector3(0.4, 1.38, z), yaw, Color(0.85, 0.1, 0.1), 52, 8, Color(1, 1, 1))
		slot_reels.append(reel)
	wall_text("JACKPOT", sm + Vector3(0.43, 1.8, 0), yaw, Color(0.75, 0.05, 0.1), 40, 6, Color(1, 0.95, 0.6))
	for k in 6:  # chasing lights around the top
		var lt := prop(sphere(0.035, sm + Vector3(0.33, 1.95, -0.33 + k * 0.13), Color(1, 1, 0.7), 2.0))
		lt.material_override = std_mat(Color(1, 1, 0.7), 2.0)
		slot_lights.append(lt)
	prop(box(Vector3(0.25, 0.06, 0.5), sm + Vector3(0.45, 0.85, 0), Color(0.15, 0.15, 0.18)))  # coin tray
	prop(cylinder(0.03, 0.5, sm + Vector3(0.0, 1.5, 0.48), Color(0.75, 0.75, 0.8)))           # lever
	prop(sphere(0.07, sm + Vector3(0.0, 1.78, 0.48), Color(0.95, 0.1, 0.15), 0.4))
	# a stool in front of it
	cylinder(0.2, 0.06, sm + Vector3(0.8, 0.62, 0), Color(0.9, 0.3, 0.3))
	prop(cylinder(0.04, 0.6, sm + Vector3(0.8, 0.3, 0), Color(0.4, 0.4, 0.45)))

	# --- restroom doors on the left wall (puns on the signs) + direction sign
	for d in [[-8.3, "BUOYS", Color(0.3, 0.6, 1.0)], [-11.4, "GILLS", Color(1.0, 0.45, 0.7)]]:
		var z: float = d[0]
		box(Vector3(0.08, 2.2, 0.95), Vector3(-5.86, 1.1, z), Color(0.55, 0.3, 0.15))
		prop(box(Vector3(0.1, 2.3, 0.08), Vector3(-5.84, 1.15, z - 0.5), Color(0.35, 0.2, 0.1)))
		prop(box(Vector3(0.1, 2.3, 0.08), Vector3(-5.84, 1.15, z + 0.5), Color(0.35, 0.2, 0.1)))
		prop(box(Vector3(0.1, 0.08, 1.08), Vector3(-5.84, 2.3, z), Color(0.35, 0.2, 0.1)))
		prop(sphere(0.045, Vector3(-5.8, 1.05, z + 0.32), Color(0.95, 0.8, 0.3), 0.2))  # knob
		prop(box(Vector3(0.03, 0.34, 0.6), Vector3(-5.81, 1.75, z), Color(0.95, 0.95, 0.9)))
		wall_text(d[1], Vector3(-5.79, 1.75, z), PI / 2.0, d[2], 44, 6)
	prop(box(Vector3(0.03, 0.3, 1.3), Vector3(-5.85, 2.9, -9.85), Color(0.1, 0.25, 0.45)))
	wall_text("RESTROOMS", Vector3(-5.83, 2.9, -9.85), PI / 2.0, Color(1, 1, 1), 46, 6)

	# --- big brass portholes with bolts, thick glass and a shine
	for side in [-1.0, 1.0]:
		for z in [-3.0, -6.5, -10.0]:
			var x: float = side * 5.86
			if side < 0.0 and z == -10.0:
				continue  # the restroom sign hangs there
			var rim := MeshInstance3D.new()
			var tm := TorusMesh.new()
			tm.inner_radius = 0.42
			tm.outer_radius = 0.56
			rim.mesh = tm
			rim.material_override = std_mat(Color(0.8, 0.6, 0.25))
			rim.position = Vector3(x, 2.6, z)
			rim.rotation_degrees = Vector3(0, 0, 90)
			prop(rim)
			add_child(rim)
			cylinder(0.43, 0.06, Vector3(x - side * 0.01, 2.6, z), Color(0.25, 0.65, 0.85), Vector3(0, 0, 90), 1.0)
			var bolts := MultiMesh.new()
			var bm := SphereMesh.new()
			bm.radius = 0.035
			bm.height = 0.07
			bm.material = std_mat(Color(0.65, 0.5, 0.2))
			bolts.transform_format = MultiMesh.TRANSFORM_3D
			bolts.mesh = bm
			bolts.instance_count = 8
			for k in 8:
				var a := TAU * k / 8.0
				bolts.set_instance_transform(k, Transform3D(Basis(), Vector3(x - side * 0.06, 2.6 + sin(a) * 0.49, z + cos(a) * 0.49)))
			var bmi := MultiMeshInstance3D.new()
			bmi.multimesh = bolts
			bmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			add_child(bmi)
			# glass shine streaks
			for k in 2:
				var sh := prop(box(Vector3(0.01, 0.06 - k * 0.025, 0.36 - k * 0.14), Vector3(x - side * 0.05, 2.72 - k * 0.1, z - 0.06), Color(1, 1, 1), 1.5))
				sh.rotation_degrees = Vector3(35, 0, 0)

	# --- life ring and an anchor on the right wall
	var ring := MeshInstance3D.new()
	var rt := TorusMesh.new()
	rt.inner_radius = 0.24
	rt.outer_radius = 0.4
	ring.mesh = rt
	ring.material_override = std_mat(Color(1, 0.35, 0.2))
	ring.position = Vector3(5.83, 2.5, -4.8)
	ring.rotation_degrees = Vector3(0, 0, 90)
	add_child(prop(ring))
	for k in 4:
		var a := TAU * k / 4.0 + PI / 4.0
		var band := prop(box(Vector3(0.18, 0.1, 0.18), Vector3(5.8, 2.5 + sin(a) * 0.32, -4.8 + cos(a) * 0.32), Color(1, 1, 1)))
		band.rotation.x = -a
	wall_text("S.S. SALTY", Vector3(5.75, 1.95, -4.8), -PI / 2.0, Color(1, 1, 1), 34, 6)

	# --- menu board + employee of the month behind the counter (seen from the customer side)
	box(Vector3(3.2, 1.5, 0.08), Vector3(-1.0, 3.0, 5.36), Color(0.08, 0.1, 0.12))
	prop(box(Vector3(3.3, 0.08, 0.1), Vector3(-1.0, 3.77, 5.34), Color(0.6, 0.4, 0.2)))
	prop(box(Vector3(3.3, 0.08, 0.1), Vector3(-1.0, 2.23, 5.34), Color(0.6, 0.4, 0.2)))
	wall_text("~ MENU ~", Vector3(-1.0, 3.55, 5.31), PI, Color(1, 0.85, 0.3), 70, 8)
	var items := [["SALT BURGER", "3.50"], ["DOUBLE TROUBLE", "5.00"], ["KELP FRIES", "1.75"], ["SEAFOAM SODA", "1.25"]]
	for i in items.size():
		var row: Array = items[i]
		var y := 3.22 - i * 0.24
		var name_l := wall_text(row[0], Vector3(0.35, y, 5.31), PI, Color(0.95, 0.95, 0.9), 38, 4)
		name_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		var price_l := wall_text(row[1], Vector3(-2.45, y, 5.31), PI, Color(0.5, 1.0, 0.6), 38, 4)
		price_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	box(Vector3(0.75, 0.95, 0.06), Vector3(1.4, 2.6, 5.37), Color(0.85, 0.65, 0.2))
	prop(box(Vector3(0.62, 0.7, 0.03), Vector3(1.4, 2.66, 5.33), Color(0.75, 0.88, 0.95)))
	var emp := Sprite3D.new()
	emp.texture = art_texture("cashier_front", {})[0] if ResourceLoader.exists(SPRITE_DIR % "cashier_front") else null
	if emp.texture != null:
		emp.pixel_size = 0.6 / emp.texture.get_width() * 1.0
		emp.position = Vector3(1.4, 2.62, 5.31)
		emp.rotation.y = PI
		emp.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
		emp.shaded = false
		emp.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(emp)
	wall_text("EMPLOYEE OF THE MONTH", Vector3(1.4, 2.21, 5.31), PI, Color(0.2, 0.1, 0.05), 22, 0)

	# --- neon OPEN sign on the back wall, next to the door
	box(Vector3(1.0, 0.45, 0.04), Vector3(3.6, 3.1, -12.36), Color(0.05, 0.05, 0.1))
	open_sign = wall_text("OPEN", Vector3(3.6, 3.1, -12.32), 0.0, Color(1.6, 0.3, 0.8), 80, 10, Color(1.0, 0.3, 0.8, 0.5))

	# --- potted coral in the back corner, trash can by the door
	cylinder(0.3, 0.45, Vector3(-5.3, 0.225, -11.95), Color(0.75, 0.4, 0.25))
	for k in 5:
		var a := TAU * k / 5.0
		var c := prop(cone(0.06, 0.02, r.randf_range(0.5, 0.9), Vector3(-5.3 + cos(a) * 0.12, 0.42, -11.95 + sin(a) * 0.12), Color(1.0, 0.45, 0.6), Vector3(sin(a) * 18.0, 0, cos(a) * 18.0)))
		c.material_override = std_mat(Color(1.0, 0.45, 0.6))
	cylinder(0.24, 0.7, Vector3(3.55, 0.35, -11.9), Color(0.3, 0.45, 0.35))
	prop(cylinder(0.26, 0.05, Vector3(3.55, 0.72, -11.9), Color(0.25, 0.35, 0.3)))
	for k in 4:  # wrappers spilling over the rim
		prop(sphere(0.07, Vector3(3.45 + k * 0.08, 0.78, -11.85 + (k % 2) * 0.06), [Color(1, 0.9, 0.3), Color(1, 1, 1), Color(1, 0.4, 0.3)][k % 3], 0.0, 0.1))
	prop(sphere(0.06, Vector3(3.95, 0.03, -11.6), Color(1, 1, 1), 0.0, 0.1))  # one missed the bin

	# --- wet floor sign next to a soda spill
	var wf := Vector3(-2.3, 0, -1.6)
	for side in [-1.0, 1.0]:
		var panel := box(Vector3(0.36, 0.62, 0.02), wf + Vector3(0, 0.3, side * 0.1), Color(1.0, 0.85, 0.05))
		panel.rotation.x = side * 0.3
		prop(panel)
	wall_text("CAUTION\nWET FLOOR", wf + Vector3(0, 0.36, 0.2), 0.0, Color(0.1, 0.1, 0.1), 22, 0).rotation.x = 0.3

	# --- dirt: soda puddle, ketchup splat, gum, footprints from the door, crumbs under tables
	floor_marks(Color(0.45, 0.25, 0.1, 0.55), [[-2.0, -2.0, 0.55, 0.35, 0.3], [-1.6, -2.3, 0.25, 0.18, 1.0], [-2.5, -1.9, 0.2, 0.14, 2.0]])
	floor_marks(Color(0.8, 0.05, 0.05, 0.75), [[-3.0, -4.3, 0.16, 0.11, 0.5], [-2.85, -4.4, 0.06, 0.05, 0.0], [-3.15, -4.15, 0.05, 0.04, 0.0]])
	floor_marks(Color(1.0, 0.45, 0.7, 0.9), [[1.8, -4.5, 0.05, 0.04, 0.0], [-1.2, -8.2, 0.045, 0.04, 0.0], [3.0, -9.3, 0.05, 0.045, 0.0]])
	var steps: Array = []
	for i in 14:  # muddy footprints walking in from the door
		var f := i / 13.0
		var px := lerpf(4.9, 1.3, f) + (0.12 if i % 2 == 0 else -0.12)
		var pz := lerpf(-11.6, -2.6, f)
		steps.append([px, pz, 0.07, 0.12, -0.38])
	floor_marks(Color(0.25, 0.18, 0.1, 0.35), steps)
	var crumbs: Array = []
	for tp in TABLES:
		for k in 8:
			crumbs.append([tp.x + r.randf_range(-0.7, 0.7), tp.z + r.randf_range(-0.7, 0.7), 0.025, 0.02, r.randf() * TAU])
	floor_marks(Color(0.75, 0.55, 0.25, 0.9), crumbs)
	floor_marks(Color(0.2, 0.2, 0.25, 0.18), [[-4.6, -5.4, 0.6, 0.4, 0.4], [-2.4, -9.0, 0.7, 0.45, 2.1], [2.2, -6.8, 0.5, 0.35, 1.0], [-4.9, -0.4, 0.45, 0.3, 0.2]])  # general grime


func spawn_diners() -> void:
	# Guests standing at the tables, chatting and eating (decoration only).
	var spots := [Vector3(-4.25, 0, -3.95), Vector3(-2.95, 0, -3.9), Vector3(-4.2, 0, -7.45), Vector3(-3.0, 0, -7.4), Vector3(-3.6, 0, -10.55)]
	for i in spots.size():
		var a := make_actor("customer", make_customer_data(), "customer_back")
		a.pivot.position = spots[i]
		a.data["bob"] = rng.randf() * TAU
		diners.append(a)
	# their food on the tables
	for tp in TABLES:
		var b := flying_sprite(burger_tex, tp + Vector3(-0.1, 0.92, 0.05), 0.55)
		b.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var tr := flying_sprite(tray_tex, tp + Vector3(0.25, 0.85, 0.08), 0.6)
		tr.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


func animate_decor(delta: float) -> void:
	# guests bob and lean towards each other while they talk; slot machine lights chase, reels spin now and then
	for a in diners:
		var ph: float = a.data["bob"]
		a.body.position.y = BODY_Y + maxf(0.0, sin(t * 2.3 + ph)) * 0.04
		a.body.rotation.z = sin(t * 0.9 + ph) * 0.06
	for k in slot_lights.size():
		var on := int(t * 6.0) % slot_lights.size() == k or int(t * 6.0 + 3) % slot_lights.size() == k
		var m: StandardMaterial3D = slot_lights[k].material_override
		m.emission_energy_multiplier = 3.0 if on else 0.3
	slot_spin_t -= delta
	if slot_spin_t <= 0.0:
		slot_spin_t = rng.randf_range(4.0, 9.0)
		slot_spinning = 1.2
	if slot_spinning > 0.0:
		slot_spinning -= delta
		for i in slot_reels.size():  # reels stop one after the other
			if slot_spinning > i * 0.3:
				slot_reels[i].text = SLOT_SYMBOLS[rng.randi() % SLOT_SYMBOLS.size()]
	if open_sign:
		open_sign.modulate.a = 1.0 if fmod(t, 5.0) > 0.25 else 0.35  # neon flicker


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

# Character art resolution: 1 = classic 320 px textures (MIN / MID graphics), 3 = HQ (MAX).
static var art_mult := 1


func make_art(kind: String, data: Dictionary) -> SubViewport:
	var vp := SubViewport.new()
	vp.size = Vector2i.ONE * CharacterArt.ART_SIZE * art_mult
	vp.add_to_group("art_viewport")
	vp.transparent_bg = true
	vp.disable_3d = true
	vp.render_target_update_mode = SubViewport.UPDATE_ONCE
	var art := CharacterArt.new()
	art.scale = Vector2.ONE * art_mult
	art.kind = kind
	art.data = data
	vp.add_child(art)
	add_child(vp)
	return vp


const SPRITE_DIR := "res://assets/sprites/%s.png"
const BODY_NAMES := ["round", "tall", "wide"]


func set_art_quality(hq: bool) -> void:
	# Re-renders every procedural character/prop texture at the new resolution (live, from Options).
	var m := 3 if hq else 1
	if m == art_mult:
		return
	art_mult = m
	for vp in get_tree().get_nodes_in_group("art_viewport"):
		vp.size = Vector2i.ONE * CharacterArt.ART_SIZE * m
		for c in vp.get_children():
			c.scale = Vector2.ONE * m
			c.queue_redraw()
		vp.render_target_update_mode = SubViewport.UPDATE_ONCE
	for s in get_tree().get_nodes_in_group("art_sprite"):
		var tex: Texture2D = s.texture
		if tex != null and tex.get_width() > 0:
			s.pixel_size = s.get_meta("px_base") / float(tex.get_width())


func override_name(kind: String, data: Dictionary) -> String:
	# File name a custom PNG must have to replace this piece of procedural art.
	# Customers can have numbered variants (customer_round_front_1.png ...); front and back
	# use the same number. Without a variant (or file) the un-numbered name is used.
	match kind:
		"customer", "customer_back":
			var base := "customer_%s_%s" % [BODY_NAMES[data["kind"]], "front" if kind == "customer" else "back"]
			if data.has("variant") and ResourceLoader.exists(SPRITE_DIR % ("%s_%d" % [base, data["variant"]])):
				return "%s_%d" % [base, data["variant"]]
			return base
		"cashier":
			return "cashier_back"
	return kind


const SPRITE_VARIANTS := 4
var art_height_cache := {}


func art_height(tex: Texture2D) -> float:
	# Height (metres) of a custom PNG's character, from its lowest opaque pixel... to the top one,
	# so speech bubbles sit right on top of the drawn head.
	if tex == null or tex.resource_path == "":
		return -1.0
	if art_height_cache.has(tex.resource_path):
		return art_height_cache[tex.resource_path]
	var img := tex.get_image()
	if img == null:
		return -1.0
	if img.is_compressed():
		img.decompress()
	var used := img.get_used_rect()
	var scale := float(CharacterArt.ART_SIZE) / img.get_width()
	var h := (CharacterArt.FEET_PX - used.position.y * scale) * PIXEL
	art_height_cache[tex.resource_path] = h
	return h


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
	s.set_meta("px_base", PIXEL * CharacterArt.ART_SIZE)
	s.add_to_group("art_sprite")
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
		var h := art_height(a.sprite.texture)
		if h > 0.0:
			a.height = h
	return a


func free_actor(a: Actor) -> void:
	leaving.erase(a)
	for s in [a.sprite, a.sprite_front]:
		if s != null and is_instance_valid(s):
			var vp = s.get_meta("vp") if s.has_meta("vp") else null  # PNG sprites have no viewport
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
		"variant": rng.randi_range(1, SPRITE_VARIANTS),
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
	s.set_meta("px_base", PIXEL * 0.5 * size * CharacterArt.ART_SIZE)
	s.add_to_group("art_sprite")
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
	if valk_player.playing:
		var vt := create_tween()
		vt.tween_property(valk_player, "volume_db", -60.0, 1.0)
		vt.tween_callback(valk_player.stop)
	black_alpha = 1.0
	get_tree().create_timer(1.0, false).timeout.connect(start_intro)


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
	get_tree().create_timer(0.5, false).timeout.connect(start_countdown)


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
	music_player.volume_db = MUSIC_DB
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
	if state in [State.TITLE, State.BLACKOUT, State.INTRO, State.GAME_OVER_ANIM, State.GAME_OVER, State.CINEMA]:
		return 0
	return clampi(-bar - 1, 0, 3)


func update_crowd_sound(delta: float) -> void:
	# Crowd chatter during the intro flight, louder the closer the camera gets to the line.
	var target := 0.0
	if state == State.INTRO:
		var nearest := INF
		for a in queue:
			nearest = minf(nearest, camera.global_position.distance_to(a.pivot.global_position + Vector3(0, 0.8, 0)))
		var k := clampf((CROWD_FAR - nearest) / (CROWD_FAR - CROWD_NEAR), 0.0, 1.0)
		target = k * k * (1.0 - black_alpha)  # also fades in with the picture
	crowd_level = lerpf(crowd_level, target, 1.0 - exp(-(3.0 if target > crowd_level else 1.8) * delta))
	if crowd_level > 0.003:
		if not crowd_player.playing:
			crowd_player.play()
		crowd_player.volume_db = linear_to_db(crowd_level)
	elif crowd_player.playing:
		crowd_player.stop()


func timer_fraction() -> float:
	# How much time is left (1 = plenty, 0 = out) for whatever timer is running, or -1 if none.
	match state:
		State.DECIDE:
			return time_left / time_limit
		State.ATTACK:
			if attack_mode == "quiz" and quiz_pick != -1:
				return -1.0  # answer locked in: no more ticking
			return attack_left / attack_time
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


# ---------------------------------------------------------------- opening cinematic

func setup_cinema_audio() -> void:
	# Valkyries play on their own bus with a low-pass filter (muffled once we're underwater).
	var bus := AudioServer.get_bus_index("Cinema")
	if bus < 0:
		AudioServer.add_bus()
		bus = AudioServer.bus_count - 1
		AudioServer.set_bus_name(bus, "Cinema")
		AudioServer.add_bus_effect(bus, AudioEffectLowPassFilter.new())
	valk_lowpass = AudioServer.get_bus_effect(bus, 0)
	valk_lowpass.cutoff_hz = 20000.0
	# typewriter: a few clack variations + the carriage bell (all generated, no files)
	for v in 4:
		type_clacks.append(make_clack(v))
	type_ding = make_ding()
	for i in 4:
		var tp := AudioStreamPlayer.new()
		tp.volume_db = -4.0
		add_child(tp)
		type_players.append(tp)
	fx_player = AudioStreamPlayer.new()
	fx_player.stream = EXPLOSION_SOUND
	fx_player.volume_db = 4.0
	add_child(fx_player)
	sizzle_player = AudioStreamPlayer.new()
	sizzle_player.stream = make_sizzle()
	sizzle_player.volume_db = -60.0
	add_child(sizzle_player)
	heli_player = AudioStreamPlayer.new()
	heli_player.stream = make_heli_loop()
	heli_player.volume_db = -60.0
	add_child(heli_player)
	valk_player = AudioStreamPlayer.new()
	valk_player.stream = VALKYRIES
	valk_player.bus = "Cinema"
	add_child(valk_player)


func make_clack(variant: int) -> AudioStreamWAV:
	# Typewriter key strike: sharp filtered noise click + short low "thunk" of the typebar.
	var rate := 22050
	var n := int(rate * 0.07)
	var data := PackedByteArray()
	data.resize(n * 2)
	var r := RandomNumberGenerator.new()
	r.seed = 1234 + variant
	var lp := 0.0
	var thunk_f := 170.0 + variant * 25.0
	for i in n:
		var tt := float(i) / rate
		var noise := r.randf_range(-1.0, 1.0)
		lp += (noise - lp) * 0.55
		var click := (noise - lp) * exp(-tt * 260.0) * 0.9
		var thunk := sin(TAU * thunk_f * tt) * exp(-tt * 70.0) * 0.55
		var rattle := lp * exp(-tt * 45.0) * 0.25
		var v := clampf(click + thunk + rattle, -1.0, 1.0)
		data.encode_s16(i * 2, int(v * 30000.0))
	var st := AudioStreamWAV.new()
	st.format = AudioStreamWAV.FORMAT_16_BITS
	st.mix_rate = rate
	st.data = data
	return st


func make_heli_loop() -> AudioStreamWAV:
	# Seamless 2 s helicopter loop: rotor blade thumps (11 per second), turbine whine and wind.
	var rate := 22050
	var n := rate * 2
	var data := PackedByteArray()
	data.resize(n * 2)
	var r := RandomNumberGenerator.new()
	r.seed = 77
	var lp := 0.0
	var lp2 := 0.0
	var blade := 1.0 / 11.0
	for i in n:
		var tt := float(i) / rate
		var noise := r.randf_range(-1.0, 1.0)
		lp += (noise - lp) * 0.08
		lp2 += (lp - lp2) * 0.15
		var ph := fmod(tt, blade) / blade
		var thump_env := exp(-ph * 9.0)
		var thump := (sin(TAU * 55.0 * tt) * 0.7 + lp2 * 3.5) * thump_env
		var whine := sin(TAU * 1650.0 * tt + sin(TAU * 3.0 * tt) * 2.0) * 0.035
		var wind := lp * 0.45 * (0.6 + 0.4 * thump_env)
		var v := clampf((thump + whine + wind) * 0.75, -1.0, 1.0)
		data.encode_s16(i * 2, int(v * 30000.0))
	var st := AudioStreamWAV.new()
	st.format = AudioStreamWAV.FORMAT_16_BITS
	st.mix_rate = rate
	st.data = data
	st.loop_mode = AudioStreamWAV.LOOP_FORWARD
	st.loop_begin = 0
	st.loop_end = n
	return st


func make_boom() -> AudioStreamWAV:
	# Explosion: noise burst + deep falling rumble.
	var rate := 22050
	var n := int(rate * 2.2)
	var data := PackedByteArray()
	data.resize(n * 2)
	var r := RandomNumberGenerator.new()
	r.seed = 9
	var lp := 0.0
	for i in n:
		var tt := float(i) / rate
		var noise := r.randf_range(-1.0, 1.0)
		lp += (noise - lp) * lerpf(0.5, 0.03, minf(tt / 1.2, 1.0))
		var rumble := sin(TAU * lerpf(70.0, 30.0, minf(tt, 1.0)) * tt) * exp(-tt * 2.2)
		var v := (lp * 2.2 * exp(-tt * 2.8) + rumble * 0.8) * minf(1.0, tt * 300.0)
		data.encode_s16(i * 2, int(clampf(v, -1.0, 1.0) * 30000.0))
	var st := AudioStreamWAV.new()
	st.format = AudioStreamWAV.FORMAT_16_BITS
	st.mix_rate = rate
	st.data = data
	return st


func make_sizzle() -> AudioStreamWAV:
	# Deep-fryer sizzle loop: crackly high noise with random pops.
	var rate := 22050
	var n := rate * 2
	var data := PackedByteArray()
	data.resize(n * 2)
	var r := RandomNumberGenerator.new()
	r.seed = 21
	var prev := 0.0
	var pop := 0.0
	for i in n:
		var noise := r.randf_range(-1.0, 1.0)
		var hp := noise - prev
		prev = noise
		if r.randf() < 0.002:
			pop = r.randf_range(0.5, 1.0)
		pop *= 0.985
		var v := hp * 0.18 * (0.7 + 0.3 * r.randf()) + noise * pop * 0.5
		data.encode_s16(i * 2, int(clampf(v, -1.0, 1.0) * 30000.0))
	var st := AudioStreamWAV.new()
	st.format = AudioStreamWAV.FORMAT_16_BITS
	st.mix_rate = rate
	st.data = data
	st.loop_mode = AudioStreamWAV.LOOP_FORWARD
	st.loop_end = n
	return st


func update_heli_sound(delta: float) -> void:
	# Distant squadron -> roaring cabin during close-ups (ducked under dialogue) -> fly-by -> gone underwater.
	var t := cine_t
	var target := -60.0
	var pitch := 1.0
	if t >= Cine.T_HELIS and t < Cine.T_CU_COMMANDER:
		var k := (t - Cine.T_HELIS) / (Cine.T_CU_COMMANDER - Cine.T_HELIS)
		target = lerpf(-38.0, -12.0, k * k)
	elif t >= Cine.T_CU_COMMANDER and t < Cine.T_WIDE_JUMP:
		target = -15.0 if not Cine.current_line(t).is_empty() else -9.0
		pitch = 0.92  # inside the cabin: lower, rumbly
	elif t >= Cine.T_WIDE_JUMP and t < Cine.T_CABIN:
		var k := (t - Cine.T_WIDE_JUMP) / (Cine.T_CABIN - Cine.T_WIDE_JUMP)
		target = lerpf(-4.0, -16.0, k)
		pitch = lerpf(1.08, 0.9, k)  # doppler as they roar past
	elif t >= Cine.T_CABIN and t < Cine.T_CRASH:
		target = -15.0 if not Cine.current_line(t).is_empty() else -9.0
		pitch = 0.92 + (sin(t * 9.0) * 0.06 if t > 38.8 else 0.0)  # engine starts to wobble
	elif t >= Cine.T_CRASH and t < Cine.T_CRASH + Cine.CRASH_IMPACT:
		var k := (t - Cine.T_CRASH) / Cine.CRASH_IMPACT
		target = -7.0
		pitch = lerpf(1.0, 0.5, k) + sin(t * 23.0) * 0.08  # sputtering, dying engine
	var impact_t := Cine.T_CRASH + Cine.CRASH_IMPACT
	if t >= impact_t and not boom_played:
		boom_played = true
		fx_player.play()
		shake = 18.0
	# fryer sizzle over the fish sticks
	var sz_target := -10.0 if t >= Cine.T_STICKS - 0.4 and t < Cine.T_3D else -60.0
	if sz_target > -59.0 and not sizzle_player.playing:
		sizzle_player.play()
	sizzle_player.volume_db = lerpf(sizzle_player.volume_db, sz_target, 1.0 - exp(-5.0 * delta))
	if sizzle_player.volume_db < -58.0 and sizzle_player.playing and t >= Cine.T_3D:
		sizzle_player.stop()
	if target > -59.0 and not heli_player.playing:
		heli_player.play()
	heli_db = lerpf(heli_db, target, 1.0 - exp(-(14.0 if t >= impact_t else 3.0) * delta))
	heli_player.volume_db = heli_db
	heli_player.pitch_scale = lerpf(heli_player.pitch_scale, pitch, 1.0 - exp(-4.0 * delta))
	if heli_db < -58.0 and heli_player.playing and t >= impact_t:
		heli_player.stop()


func update_dialogue() -> void:
	# Speak each crew line once, in Animalese, when its time comes.
	for i in Cine.DIALOGUE.size():
		var d: Array = Cine.DIALOGUE[i]
		if cine_t >= d[0] and not spoken_lines.has(i):
			spoken_lines[i] = true
			voice.speak(d[2], Cine.SPEAKER_PITCH.get(d[1], 1.3), 0.04)


func make_ding() -> AudioStreamWAV:
	# Little carriage-return bell.
	var rate := 22050
	var n := int(rate * 0.9)
	var data := PackedByteArray()
	data.resize(n * 2)
	for i in n:
		var tt := float(i) / rate
		var env := minf(1.0, tt * 400.0) * exp(-tt * 5.5)
		var v := (sin(TAU * 2350.0 * tt) * 0.5 + sin(TAU * 3920.0 * tt) * 0.25 + sin(TAU * 5600.0 * tt) * 0.1) * env * 0.6
		data.encode_s16(i * 2, int(clampf(v, -1.0, 1.0) * 30000.0))
	var st := AudioStreamWAV.new()
	st.format = AudioStreamWAV.FORMAT_16_BITS
	st.mix_rate = rate
	st.data = data
	return st


func play_type(stream: AudioStreamWAV, pitch: float, vol_db := -4.0) -> void:
	var tp := type_players[type_idx % type_players.size()]
	type_idx += 1
	tp.stream = stream
	tp.pitch_scale = pitch
	tp.volume_db = vol_db
	tp.play()


func update_typewriter() -> void:
	# Clack once for every newly typed character of the current name card; ding when it's done.
	for who in Cine.CARDS:
		var lt: float = cine_t - Cine.card_start(who)
		if lt < 0.0 or lt > 5.0:
			continue
		var total: int = Cine.CARDS[who][0].length() + 2 + Cine.CARDS[who][1].length()
		var n := mini(Cine.typed_count(lt), total)
		var before: int = typed_shown.get(who, 0)
		if n > before:
			var text_all: String = Cine.CARDS[who][0] + "— " + Cine.CARDS[who][1]
			var ch := text_all[n - 1]
			if ch != " ":
				play_type(type_clacks[rng.randi() % type_clacks.size()], rng.randf_range(0.92, 1.12))
			if n == total:
				play_type(type_ding, 1.0, -8.0)
			typed_shown[who] = n


func start_cinematic() -> void:
	state = State.CINEMA
	cine_t = 0.0
	cine_3d = false
	cine_landed = false
	typed_shown = {}
	spoken_lines = {}
	boom_played = false
	shot(INTRO_A, INTRO_A_LOOK, 0.0)
	var crew := {
		# "variant" picks the sprite (customer_<body>_front_<n>.png); costume props are drawn on top
		"commander": {"color": Color(0.95, 0.55, 0.2), "kind": 0, "hat": 0, "glasses": false, "size": 1.0, "variant": 3},
		"surfer": {"color": Color(0.15, 0.8, 0.95), "kind": 1, "hat": 0, "glasses": false, "size": 1.0, "variant": 3},
		"soldier": {"color": Color(0.95, 0.85, 0.2), "kind": 2, "hat": 0, "glasses": false, "size": 1.0, "variant": 1},
	}
	for k in crew:
		cine_tex[k] = art_texture("customer", crew[k])[0]
	cine_tex["cashier"] = art_texture("cashier_front", {})[0]


func seek_cinematic(to_t: float) -> void:
	# Jump the cinematic to a time (for previewing/testing a shot).
	cine_t = to_t
	boom_played = to_t >= Cine.T_CRASH + Cine.CRASH_IMPACT
	for i in Cine.DIALOGUE.size():
		if Cine.DIALOGUE[i][0] < to_t - 0.1:
			spoken_lines[i] = true


func update_cinematic(delta: float) -> void:
	cine_t += delta
	if cine_t >= Cine.T_MUSIC and not valk_player.playing:
		valk_player.volume_db = -40.0
		valk_player.play(Cine.MUSIC_OFFSET)  # skip ahead to the build-up
		create_tween().tween_property(valk_player, "volume_db", 5.0, 4.0).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	update_typewriter()
	update_dialogue()
	update_heli_sound(delta)
	if cine_t >= Cine.T_3D and not cine_3d:
		begin_cine_3d()
	if cine_3d:
		update_cine_3d()
	if cine_t >= Cine.T_END:
		end_cinematic()


func begin_cine_3d() -> void:
	# Underwater: the cashier parachutes down onto the street in front of the shop.
	cine_3d = true
	create_tween().tween_property(valk_lowpass, "cutoff_hz", 900.0, 0.5)
	para = make_actor("cashier", {}, "cashier_front")
	para.height = 1.75
	para.pivot.position = PARA_START
	parachute = Node3D.new()
	parachute.position = Vector3(0, 2.6, 0)
	para.pivot.add_child(parachute)
	# one solid orange dome + white stripes laid just on top of it (no overlapping z-fighting)
	var dome := MeshInstance3D.new()
	var dm := SphereMesh.new()
	dm.radius = 1.2
	dm.height = 1.2
	dm.is_hemisphere = true
	dome.mesh = dm
	var dmat := std_mat(Color(1.0, 0.32, 0.08))
	dmat.cull_mode = BaseMaterial3D.CULL_DISABLED
	dome.material_override = dmat
	dome.scale = Vector3(1.0, 0.75, 1.0)
	parachute.add_child(dome)
	for k in 4:
		var stripe := MeshInstance3D.new()
		var stm := SphereMesh.new()
		stm.radius = 1.235
		stm.height = 1.235
		stm.is_hemisphere = true
		stripe.mesh = stm
		var smat := std_mat(Color(1.0, 0.96, 0.88))
		smat.cull_mode = BaseMaterial3D.CULL_DISABLED
		stripe.material_override = smat
		stripe.scale = Vector3(0.16, 0.76, 1.0)
		stripe.rotation.y = k * PI / 4.0
		parachute.add_child(stripe)
	for k in 6:
		var a := TAU * k / 6.0
		var line := MeshInstance3D.new()
		var cm := CylinderMesh.new()
		cm.top_radius = 0.012
		cm.bottom_radius = 0.012
		cm.height = 1.0
		line.mesh = cm
		line.material_override = std_mat(Color(0.9, 0.9, 0.85))
		parachute.add_child(line)
		beam_between(line, Vector3(cos(a) * 1.15, 0.0, sin(a) * 1.15), Vector3(0, -1.55, 0))
	var trail := CPUParticles3D.new()
	var bs := SphereMesh.new()
	bs.radius = 0.05
	bs.height = 0.1
	var bm := ShaderMaterial.new()
	bm.shader = BUBBLE_SHADER
	bs.material = bm
	trail.mesh = bs
	trail.amount = 30
	trail.lifetime = 2.5
	trail.direction = Vector3.UP
	trail.spread = 25.0
	trail.gravity = Vector3(0, 0.6, 0)
	trail.initial_velocity_min = 0.3
	trail.initial_velocity_max = 0.8
	trail.local_coords = false
	trail.position = Vector3(0, 1.0, 0)
	para.pivot.add_child(trail)
	update_cine_3d()


func update_cine_3d() -> void:
	var p := cine_t - Cine.T_3D
	var fall := Cine.T_LAND - Cine.T_3D
	if para != null and is_instance_valid(para.pivot) and not cine_landed:
		var k := clampf(p / fall, 0.0, 1.0)
		var e := 1.0 - pow(1.0 - k, 1.7)
		var pos := PARA_START.lerp(PARA_LAND, e)
		pos.x += sin(p * 1.5) * 0.7 * (1.0 - k)
		para.pivot.position = pos
		para.body.rotation.z = sin(p * 1.5 + 0.6) * 0.2 * (1.0 - k)
		parachute.rotation.z = -sin(p * 1.5 + 0.2) * 0.12 * (1.0 - k)
		if p >= fall:
			cine_land()
	# camera: low on the street, tilting down with the descent, slow dolly in
	var dolly := smoothstep(0.0, 1.0, clampf(p / 7.0, 0.0, 1.0))
	var cam := Vector3(-0.6, 0.7, -25.5).lerp(Vector3(0.4, 1.5, -20.0), dolly)
	var target := Vector3(4.5, 1.6, -13.0)
	if para != null and is_instance_valid(para.pivot):
		target = para.pivot.position + Vector3(0, 1.4, 0)
		if cine_landed:
			target = target.lerp(Vector3(4.8, 1.8, -12.6), clampf((p - fall) / 1.5, 0.0, 1.0))
	camera.look_at_from_position(cam, target)


func cine_land() -> void:
	cine_landed = true
	shake = 12.0
	var pv := para.pivot
	var tw := pv.create_tween()
	tw.tween_property(pv, "scale", Vector3(1.35, 0.6, 1), 0.08)
	tw.tween_property(pv, "scale", Vector3.ONE, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	# canopy collapses and settles behind him
	var ct := parachute.create_tween().set_parallel(true)
	ct.tween_property(parachute, "position", Vector3(-0.9, 0.25, 0.4), 0.9).set_trans(Tween.TRANS_SINE)
	ct.tween_property(parachute, "scale", Vector3(1.3, 0.12, 1.3), 0.9)
	ct.tween_property(parachute, "rotation:z", 0.4, 0.9)
	# sand puff
	var puff := CPUParticles3D.new()
	var sm := SphereMesh.new()
	sm.radius = 0.12
	sm.height = 0.24
	sm.material = std_mat(Color(0.9, 0.82, 0.6))
	puff.mesh = sm
	puff.one_shot = true
	puff.explosiveness = 1.0
	puff.amount = 26
	puff.lifetime = 1.0
	puff.direction = Vector3.UP
	puff.spread = 80.0
	puff.gravity = Vector3(0, -1.0, 0)
	puff.initial_velocity_min = 1.0
	puff.initial_velocity_max = 2.2
	puff.position = PARA_LAND + Vector3(0, 0.1, 0)
	add_child(puff)
	puff.emitting = true
	get_tree().create_timer(1.5, false).timeout.connect(puff.queue_free)
	# then he unclips and waddles straight past the queue into the shop
	tw.tween_interval(0.5)
	tw.tween_property(pv, "position", DOOR_POS + Vector3(-0.35, 0, -0.2), 1.2)
	tw.parallel().tween_method(func(k: float): para.body.position.y = BODY_Y + absf(sin(k * PI * 5.0)) * 0.18, 0.0, 1.0, 1.2)
	tw.tween_property(pv, "position", DOOR_POS + Vector3(-0.35, 0, 0.6), 0.3)


func end_cinematic() -> void:
	voice.stop()
	heli_player.stop()
	sizzle_player.stop()
	if para != null and is_instance_valid(para.pivot):
		para.pivot.queue_free()
	para = null
	cine_3d = false
	shake = 0.0
	create_tween().tween_property(valk_lowpass, "cutoff_hz", 20000.0, 0.6)
	create_tween().tween_property(valk_player, "volume_db", -4.0, 1.0)
	go_title()


func go_title() -> void:
	state = State.TITLE
	title_t = 0.0
	shot(INTRO_A, INTRO_A_LOOK, 0.0)


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
	get_tree().create_timer(delay, false).timeout.connect(next_customer)


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
	get_tree().create_timer(0.55, false).timeout.connect(serve_delivered)


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


func holy_audio(start: bool, fade := 0.25) -> void:
	# Duck the soundtrack and sing hallelujah only while the holy burger floats.
	if holy_tween:
		holy_tween.kill()
	holy_tween = create_tween().set_parallel(true)
	if start:
		holy_player.volume_db = -30.0
		holy_player.play()
		holy_tween.tween_property(holy_player, "volume_db", 6.0, fade)
		holy_tween.tween_property(music_player, "volume_db", MUSIC_DUCK_DB, fade)
	else:
		holy_tween.tween_property(holy_player, "volume_db", -40.0, fade)
		holy_tween.tween_property(music_player, "volume_db", MUSIC_DB, fade * 2.0)
		holy_tween.chain().tween_callback(holy_player.stop)


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
	holy_audio(true)
	var tw := create_tween()
	tw.tween_property(bm, "shader_parameter/strength", 0.55, 0.3)
	tw.tween_property(wb, "position", chest(c) + Vector3(0, 0.15, 0.05), 1.6).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_method(func(v: float): wb.scale = Vector3(1.0 + 0.18 * sin(v), 1, 1), 0.0, TAU * 6.0, 1.6)
	tw.tween_property(bm, "shader_parameter/strength", 0.0, 0.25)
	tw.parallel().tween_callback(holy_audio.bind(false, 0.25))
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

func start_attack(forced_mode := "") -> void:
	state = State.ATTACK
	shot_decide()
	# pick a variant, never the same one three times in a row
	var modes := ["combo", "rage", "quiz"]
	attack_mode = modes[rng.randi() % 3]
	if attack_mode == last_attack_mode and rng.randf() < 0.6:
		attack_mode = modes[(modes.find(attack_mode) + 1 + rng.randi() % 2) % 3]
	if forced_mode != "":
		attack_mode = forced_mode
	last_attack_mode = attack_mode
	match attack_mode:
		"combo":
			attack_seq.clear()
			for i in 4 + mini(3, int(served / 8.0)):
				attack_seq.append(rng.randi_range(0, 3))
			attack_idx = 0
			attack_time = maxf(2.2, ATTACK_TIME - served * 0.03)
		"rage":
			rage = 0.0
			rage_need = 10 + mini(12, int(served * 0.5))
			rage_drain = minf(0.3, 0.06 + served * 0.008)
			attack_time = maxf(3.4, 5.0 - served * 0.04)
		"quiz":
			start_quiz()
	attack_left = attack_time


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
	end_attack_variant()
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


# ---------------------------------------------------------------- attack variants: rage & quiz

const QUIZ := [
	# [question, correct answer, wrong, wrong, wrong, tier (0 easiest)]
	["What colour is the sky on a clear day?", "Blue", "Green", "Red", "Purple", 0],
	["How many days are in a week?", "7", "5", "10", "12", 0],
	["Which animal says 'moo'?", "Cow", "Cat", "Duck", "Dog", 0],
	["What do fish use to breathe underwater?", "Gills", "Lungs", "Ears", "Fins", 0],
	["What is 2 + 2?", "4", "3", "5", "22", 0],
	["Which of these is a fruit?", "Apple", "Carrot", "Potato", "Onion", 0],
	["What is frozen water called?", "Ice", "Steam", "Sand", "Glass", 0],
	["How many wheels does a bicycle have?", "2", "3", "4", "1", 0],
	["What goes between the buns of a burger?", "A patty", "A sock", "A shoe", "A rock", 0],
	["Which sea animal has eight arms?", "Octopus", "Shark", "Dolphin", "Whale", 0],
	["What colour is a ripe banana?", "Yellow", "Blue", "Black", "Purple", 0],
	["What do bees make?", "Honey", "Milk", "Bread", "Cheese", 0],
	["Which one is the biggest?", "Whale", "Shrimp", "Goldfish", "Crab", 0],
	["What is the largest ocean on Earth?", "Pacific", "Atlantic", "Indian", "Arctic", 1],
	["How many minutes are in an hour?", "60", "100", "30", "24", 1],
	["Which planet do we live on?", "Earth", "Mars", "Venus", "Jupiter", 1],
	["Which of these is a mammal?", "Dolphin", "Shark", "Tuna", "Jellyfish", 1],
	["What is 5 x 6?", "30", "11", "25", "56", 1],
	["What gas do we need to breathe?", "Oxygen", "Helium", "Neon", "Smoke", 1],
	["What is the capital of France?", "Paris", "Berlin", "Madrid", "Rome", 1],
	["How many legs does a spider have?", "8", "6", "10", "4", 1],
	["What is a baby fish called?", "Fry", "Puppy", "Calf", "Kitten", 1],
	["Which animal walks sideways?", "Crab", "Eel", "Seal", "Squid", 1],
	["A group of fish is called a...?", "School", "Office", "Garage", "Choir", 1],
	["Blue + yellow paint makes...?", "Green", "Orange", "Purple", "Pink", 1],
	["How many continents are there?", "7", "5", "3", "12", 1],
	["What is the biggest animal that ever lived?", "Blue whale", "T-rex", "Elephant", "Giraffe", 2],
	["Which planet is called the Red Planet?", "Mars", "Venus", "Saturn", "Neptune", 2],
	["What is H2O?", "Water", "Salt", "Gold", "Air", 2],
	["How many sides does a hexagon have?", "6", "5", "8", "7", 2],
	["What is 12 x 12?", "144", "124", "132", "154", 2],
	["What does a pufferfish do when scared?", "Puffs up", "Glows", "Flies", "Sings", 2],
	["What is the hardest natural material?", "Diamond", "Gold", "Iron", "Glass", 2],
	["How many bones does an adult human have?", "206", "106", "306", "56", 2],
	["Which instrument has 88 keys?", "Piano", "Guitar", "Violin", "Drum", 2],
	["In which country are the Giza pyramids?", "Egypt", "Mexico", "Peru", "Greece", 2],
	["Water freezes at how many degrees Celsius?", "0", "10", "100", "-10", 2],
	["Sharks are a kind of...?", "Fish", "Mammal", "Reptile", "Bird", 2],
	["What is the smallest prime number?", "2", "1", "3", "0", 2],
]
const QUIZ_LOCK := 1.0     # seconds the "final answer" hangs before the reveal
const QUIZ_REVEAL := 1.0   # seconds the result is shown


func setup_attack_variants() -> void:
	# keys: C or S skips the opening cutscene
	if not InputMap.has_action("skip_cutscene"):
		InputMap.add_action("skip_cutscene")
		for k in [KEY_C, KEY_S]:
			var e := InputEventKey.new()
			e.physical_keycode = k
			InputMap.action_add_event("skip_cutscene", e)
	# keys: SPACE to mash, 1-4 / A-D as alternative quiz answers
	if not InputMap.has_action("mash"):
		InputMap.add_action("mash")
		var ev := InputEventKey.new()
		ev.physical_keycode = KEY_SPACE
		InputMap.action_add_event("mash", ev)
		for i in 4:
			InputMap.add_action("quiz_%d" % i)
			for k in [KEY_1 + i, KEY_A + i]:
				var e := InputEventKey.new()
				e.physical_keycode = k
				InputMap.action_add_event("quiz_%d" % i, e)
	# steam jets above the cashier's head
	var steam_mesh := SphereMesh.new()
	steam_mesh.radius = 0.07
	steam_mesh.height = 0.14
	steam_mesh.material = fx_mat(Color(1, 1, 1, 0.75), 0.0)
	for side in [-1.0, 1.0]:
		var p := CPUParticles3D.new()
		p.mesh = steam_mesh
		p.amount = 18
		p.lifetime = 0.55
		p.emitting = false
		p.direction = Vector3(side * 0.6, 1, 0)
		p.spread = 18.0
		p.gravity = Vector3(0, 2.0, 0)
		p.initial_velocity_min = 1.6
		p.initial_velocity_max = 2.6
		p.scale_amount_min = 0.6
		p.scale_amount_max = 1.4
		p.position = Vector3(side * 0.42, cashier.height + 0.05, -0.15)
		cashier.pivot.add_child(p)
		rage_steam.append(p)
	# --- power-up aura (anime style): two glowing shells behind him
	var shell := SphereMesh.new()
	shell.radius = 1.0
	shell.height = 2.0
	for i in 2:
		var m := fx_mat(Color(1.0, 0.7, 0.05, 0.0) if i == 0 else Color(1.0, 0.92, 0.45, 0.0), 3.0)
		var a := fx_mesh(cashier.pivot, shell, m, Vector3(0, cashier.height * 0.55, 0.4))
		a.visible = false
		aura_meshes.append(a)
	# energy flames streaming upwards around his body
	var flame := SphereMesh.new()
	flame.radius = 0.08
	flame.height = 0.7
	flame.material = fx_mat(Color(1.0, 0.85, 0.3, 0.85), 3.0)
	aura_flames = CPUParticles3D.new()
	aura_flames.mesh = flame
	aura_flames.amount = 110
	aura_flames.lifetime = 0.45
	aura_flames.emitting = false
	aura_flames.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	aura_flames.emission_box_extents = Vector3(1.0, 0.9, 0.1)
	aura_flames.direction = Vector3(0, 1, 0)
	aura_flames.spread = 8.0
	aura_flames.gravity = Vector3(0, 3.0, 0)
	aura_flames.initial_velocity_min = 2.0
	aura_flames.initial_velocity_max = 3.6
	aura_flames.scale_amount_min = 0.6
	aura_flames.scale_amount_max = 1.3
	aura_flames.position = Vector3(0, cashier.height * 0.45, 0.3)
	cashier.pivot.add_child(aura_flames)
	# pebbles lifting off the floor around him
	var rock := BoxMesh.new()
	rock.size = Vector3.ONE * 0.07
	rock.material = std_mat(Color(0.55, 0.5, 0.45))
	aura_rocks = CPUParticles3D.new()
	aura_rocks.mesh = rock
	aura_rocks.amount = 30
	aura_rocks.lifetime = 1.6
	aura_rocks.emitting = false
	aura_rocks.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	aura_rocks.emission_box_extents = Vector3(1.3, 0.02, 0.9)
	aura_rocks.direction = Vector3(0, 1, 0)
	aura_rocks.spread = 10.0
	aura_rocks.gravity = Vector3(0, 0.4, 0)
	aura_rocks.initial_velocity_min = 0.5
	aura_rocks.initial_velocity_max = 1.3
	aura_rocks.angular_velocity_min = -200.0
	aura_rocks.angular_velocity_max = 200.0
	aura_rocks.scale_amount_min = 0.5
	aura_rocks.scale_amount_max = 1.5
	aura_rocks.position = Vector3(0, 0.05, 0.3)
	cashier.pivot.add_child(aura_rocks)
	aura_light = OmniLight3D.new()
	aura_light.light_color = Color(1.0, 0.8, 0.35)
	aura_light.omni_range = 4.0
	aura_light.light_energy = 0.0
	aura_light.position = Vector3(0, cashier.height * 0.6, -0.4)
	cashier.pivot.add_child(aura_light)
	charge_player = AudioStreamPlayer.new()
	charge_player.stream = make_charge_loop()
	charge_player.volume_db = -60.0
	add_child(charge_player)
	# sounds
	mash_player = AudioStreamPlayer.new()
	mash_player.stream = make_clack(0)
	mash_player.volume_db = -8.0
	add_child(mash_player)
	quiz_music = AudioStreamPlayer.new()
	quiz_music.stream = make_quiz_loop()
	quiz_music.volume_db = -6.0
	add_child(quiz_music)
	quiz_fx = AudioStreamPlayer.new()
	quiz_fx.volume_db = -4.0
	add_child(quiz_fx)
	quiz_sting = {"lock": make_quiz_sting("lock"), "right": make_quiz_sting("right"), "wrong": make_quiz_sting("wrong")}


func update_attack(delta: float) -> void:
	match attack_mode:
		"combo":
			attack_left -= delta
			if attack_left <= 0.0:
				attack_fail()
		"rage":
			attack_left -= delta
			rage = maxf(0.0, rage - rage_drain * delta)
			update_rage_fx()
			if attack_left <= 0.0:
				add_popup("Ran out of steam...", Vector2(0, 300), Color(1, 0.6, 0.4), 30, 1.0)
				attack_fail()
		"quiz":
			if quiz_pick == -1:
				attack_left -= delta
				if attack_left <= 0.0:
					quiz_pick = -2
					quiz_t = QUIZ_LOCK  # time's up: straight to the reveal
			else:
				quiz_t += delta
			if quiz_pick != -1 and quiz_t >= QUIZ_LOCK and not quiz_revealed:
				quiz_revealed = true
				quiz_fx.stream = quiz_sting["right"] if quiz_pick == quiz["correct"] else quiz_sting["wrong"]
				quiz_fx.play()
				quiz_music.stop()
			if quiz_revealed and quiz_t >= QUIZ_LOCK + QUIZ_REVEAL:
				if quiz_pick == quiz["correct"]:
					attack_success()
				else:
					add_popup("Wrong answer!" if quiz_pick >= 0 else "Time's up!", Vector2(0, 300), Color(1, 0.5, 0.4), 34, 1.0)
					attack_fail()


func end_attack_variant() -> void:
	# put the cashier and the soundtrack back to normal after rage / quiz
	if attack_mode == "rage":
		rage = 0.0
		update_rage_fx()
		cashier.pivot.position = CASHIER_POS
		cashier.pivot.scale = Vector3.ONE
		# still in the ATTACK state here, so switch the power-up effects off explicitly
		charge_player.stop()
		aura_flames.emitting = false
		aura_rocks.emitting = false
		aura_light.light_energy = 0.0
		for a in aura_meshes:
			a.visible = false
		for st in rage_steam:
			st.emitting = false
	if attack_mode == "quiz":
		quiz_music.stop()
		create_tween().tween_property(music_player, "volume_db", MUSIC_DB, 0.6)


# --- rage

func rage_press() -> void:
	rage = minf(1.0, rage + 1.0 / rage_need)
	mash_player.pitch_scale = 0.8 + rage * 0.9
	mash_player.play()
	shake = maxf(shake, 2.0 + rage * 8.0)
	if rage >= 1.0:
		add_popup(pick(["MAXIMUM POWER!", "FULL POWER!", "AAAAAARGH!!"]), Vector2(0, 230), Color(1, 0.85, 0.2), 54, 1.0)
		power_flash = 1.0
		shake = 30.0
		impact_burst(chest(cashier))
		attack_success()


func update_rage_fx() -> void:
	var r := rage
	var active := state == State.ATTACK and attack_mode == "rage"
	# red with anger first, then glowing gold as he powers up
	var tint_col := Color(1.0, 0.08, 0.04).lerp(Color(1.0, 0.85, 0.3), smoothstep(0.55, 1.0, r))
	for sp in [cashier.sprite, cashier.sprite_front]:
		if sp != null:
			sp.material_override.set_shader_parameter("tint", Color(tint_col, r * 0.65))
	# aura grows and flickers like a flame
	var flick := 0.85 + 0.15 * sin(t * 37.0) * sin(t * 23.0)
	for i in aura_meshes.size():
		var a := aura_meshes[i]
		var k := smoothstep(0.25, 0.9, r)
		a.visible = active and k > 0.01
		var sz := (1.25 - i * 0.3) * (0.75 + 0.5 * k) * flick
		a.scale = Vector3(0.95 * sz, 1.6 * sz + 0.1 * sin(t * 19.0 + i), 0.3 * sz)
		var mat: StandardMaterial3D = a.material_override
		mat.albedo_color.a = k * (0.5 if i == 0 else 0.6) * flick
	aura_flames.emitting = active and r > 0.3
	aura_flames.speed_scale = 0.7 + r * 0.8
	aura_rocks.emitting = active and r > 0.5
	aura_light.light_energy = (r * r * 4.0 * flick) if active else 0.0
	if active:
		if not charge_player.playing:
			charge_player.play()
		charge_player.pitch_scale = 0.6 + r * 1.1
		charge_player.volume_db = lerpf(-30.0, -6.0, r)
	elif charge_player.playing:
		charge_player.stop()
	if state == State.ATTACK and attack_mode == "rage":
		# puffs up, trembles harder and harder
		var jitter := Vector3(rng.randf_range(-1, 1), rng.randf_range(-0.3, 1), rng.randf_range(-1, 1)) * 0.035 * r * r
		cashier.pivot.position = CASHIER_POS + jitter
		cashier.pivot.scale = Vector3(1.0 + 0.2 * r, 1.0 + 0.14 * r, 1.0 + 0.2 * r)
		shake = maxf(shake, r * r * r * 7.0)
	for st in rage_steam:
		st.emitting = r > 0.45 and state == State.ATTACK
		st.speed_scale = 0.8 + r


# --- quiz

func make_charge_loop() -> AudioStreamWAV:
	# Power-up hum: buzzy low drone + airy rushing noise; 1 s loop, pitch follows the rage bar.
	var rate := 22050
	var n := rate
	var data := PackedByteArray()
	data.resize(n * 2)
	var r := RandomNumberGenerator.new()
	r.seed = 77
	var lp := 0.0
	for i in n:
		var tt := float(i) / rate
		var saw := fmod(110.0 * tt, 1.0) * 2.0 - 1.0
		var saw2 := fmod(111.0 * tt * 2.0, 1.0) * 2.0 - 1.0
		lp += (r.randf_range(-1.0, 1.0) - lp) * 0.25
		var v := saw * 0.22 + saw2 * 0.12 + lp * 0.5 + sin(TAU * 55.0 * tt) * 0.3
		v *= 0.8 + 0.2 * sin(TAU * 8.0 * tt)  # wobble
		data.encode_s16(i * 2, int(clampf(v, -1.0, 1.0) * 24000.0))
	var st := AudioStreamWAV.new()
	st.format = AudioStreamWAV.FORMAT_16_BITS
	st.mix_rate = rate
	st.data = data
	st.loop_mode = AudioStreamWAV.LOOP_FORWARD
	st.loop_end = n
	return st


func start_quiz() -> void:
	# easy questions first, slightly harder ones (and less time) the longer you survive
	var tier_max := 0 if served < 6 else (1 if served < 14 else 2)
	var tier_min := 0 if served < 14 else 1
	var pool: Array[int] = []
	for i in QUIZ.size():
		var tier: int = QUIZ[i][5]
		if tier >= tier_min and tier <= tier_max and not quiz_used.has(i):
			pool.append(i)
	if pool.is_empty():
		quiz_used.clear()
		for i in QUIZ.size():
			if int(QUIZ[i][5]) <= tier_max:
				pool.append(i)
	var qi: int = pool[rng.randi() % pool.size()]
	quiz_used.append(qi)
	var q: Array = QUIZ[qi]
	var answers: Array = [q[1], q[2], q[3], q[4]]
	answers.shuffle()
	quiz = {"q": q[0], "answers": answers, "correct": answers.find(q[1])}
	quiz_pick = -1
	quiz_t = 0.0
	quiz_revealed = false
	attack_time = maxf(4.0, 9.0 - served * 0.2)
	create_tween().tween_property(music_player, "volume_db", MUSIC_DB - 28.0, 0.4)
	quiz_music.play()


func quiz_answer(i: int) -> void:
	if state != State.ATTACK or attack_mode != "quiz" or quiz_pick != -1:
		return
	quiz_pick = i
	quiz_t = 0.0
	quiz_fx.stream = quiz_sting["lock"]
	quiz_fx.play()


func make_quiz_loop() -> AudioStreamWAV:
	# Original quiz-show suspense bed: dark pad, double heartbeat thump, ticking clock, rising shimmer.
	# 12 beats at 90 BPM = 8 s, every frequency fits a whole number of cycles so it loops cleanly.
	var rate := 22050
	var length := 8.0
	var n := int(rate * length)
	var beat := 60.0 / 90.0
	var data := PackedByteArray()
	data.resize(n * 2)
	var pad := [73.5, 110.0, 146.75, 174.625, 220.0]  # D2 A2 D3 F3 A3 (rounded to whole cycles)
	for i in n:
		var tt := float(i) / rate
		var v := 0.0
		# pad with a slow swell
		var swell := 0.75 + 0.25 * sin(TAU * tt / length)
		for k in pad.size():
			var f: float = pad[k]
			v += (sin(TAU * f * tt) + 0.35 * sin(TAU * f * 2.0 * tt)) * (0.09 if k < 2 else 0.05) * swell
		# heartbeat: two low thumps per beat
		var bt := fmod(tt, beat)
		for off in [0.0, 0.17]:
			var x: float = bt - off
			if x >= 0.0:
				v += sin(TAU * 52.0 * x) * exp(-x * 18.0) * (0.55 if off == 0.0 else 0.35)
		# clock tick on every half beat, alternating pitch
		var ht := fmod(tt, beat * 0.5)
		var idx := int(tt / (beat * 0.5)) % 2
		v += sin(TAU * (1760.0 if idx == 0 else 1320.0) * ht) * exp(-ht * 90.0) * 0.12
		# high shimmer that brightens through the loop
		v += sin(TAU * 880.0 * tt) * sin(TAU * 0.125 * tt) * 0.025
		data.encode_s16(i * 2, int(clampf(v, -1.0, 1.0) * 26000.0))
	var st := AudioStreamWAV.new()
	st.format = AudioStreamWAV.FORMAT_16_BITS
	st.mix_rate = rate
	st.data = data
	st.loop_mode = AudioStreamWAV.LOOP_FORWARD
	st.loop_end = n
	return st


func make_quiz_sting(kind: String) -> AudioStreamWAV:
	var rate := 22050
	var dur := 1.2
	var n := int(rate * dur)
	var data := PackedByteArray()
	data.resize(n * 2)
	for i in n:
		var tt := float(i) / rate
		var v := 0.0
		match kind:
			"lock":  # deep hit + suspended shimmer
				v = sin(TAU * lerpf(90.0, 45.0, minf(tt * 2.0, 1.0)) * tt) * exp(-tt * 3.0) * 0.8
				v += (sin(TAU * 587.3 * tt) + sin(TAU * 880.0 * tt)) * 0.12 * exp(-tt * 1.6) * minf(1.0, tt * 20.0)
			"right":  # bright rising major arpeggio
				var notes := [523.25, 659.25, 783.99, 1046.5]
				for k in 4:
					var x := tt - k * 0.09
					if x >= 0.0:
						var f: float = notes[k]
						v += (sin(TAU * f * x) + 0.4 * sin(TAU * f * 2.0 * x)) * exp(-x * 2.5) * 0.22
			_:  # wrong: falling buzzy two-note groan
				var f := 220.0 if tt < 0.35 else 165.0
				var ph := fmod(f * tt, 1.0)
				v = (ph * 2.0 - 1.0) * 0.35 * exp(-maxf(0.0, tt - 0.35) * 2.5)
				v += sin(TAU * f * 0.5 * tt) * 0.3 * exp(-tt * 1.5)
		v *= minf(1.0, tt * 400.0)
		data.encode_s16(i * 2, int(clampf(v, -1.0, 1.0) * 28000.0))
	var st := AudioStreamWAV.new()
	st.format = AudioStreamWAV.FORMAT_16_BITS
	st.mix_rate = rate
	st.data = data
	return st


# ---------------------------------------------------------------- attack animations

func hitstop(dur := 0.09) -> void:
	# Freeze-frame on impact (real time, ignores the slowed time scale).
	Engine.time_scale = 0.04
	get_tree().create_timer(dur, true, false, true).timeout.connect(func(): Engine.time_scale = 1.0)


func impact(c: Actor, power: float) -> void:
	punch_player.pitch_scale = rng.randf_range(0.92, 1.08)
	punch_player.play()
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
	get_tree().create_timer(1.0, false).timeout.connect(sparks.queue_free)


func start_chase(c: Actor, dur := CHASE_TIME) -> void:
	if is_over():
		return
	if cam_tween:
		cam_tween.kill()
	chase_actor = c
	chase_hold = false
	chase_t = dur
	chase_fov = BASE_FOV * 0.7


func update_chase(delta: float) -> void:
	# Called every frame after the base FOV is set. Tracks the flying fish, then holds on the
	# spot where it exploded.
	if chase_t > 0.0 and not is_over():
		chase_t -= delta
		var size := 0.0
		if chase_actor != null and is_instance_valid(chase_actor.pivot):
			size = chase_actor.height * chase_actor.pivot.scale.y
			chase_point = chase_actor.pivot.global_position + Vector3(0, size * 0.5, 0)
		elif chase_hold:
			size = 2.4  # frame the whole explosion
		else:
			chase_t = 0.0
		var dist := chase_point.distance_to(camera.global_position)
		if chase_t > 0.0 and dist > 0.2:
			var q := Transform3D(Basis(), camera.position).looking_at(chase_point, Vector3.UP).basis.get_rotation_quaternion()
			camera.quaternion = camera.quaternion.slerp(q, 1.0 - exp(-45.0 * delta))
			# zoom so the fish keeps about the same size on screen however far it flies
			var want := rad_to_deg(2.0 * atan(size / CHASE_FILL / 2.0 / dist))
			chase_fov = lerpf(chase_fov, clampf(want, 7.0, BASE_FOV * 0.8), 1.0 - exp(-25.0 * delta))
			chase_zoom = lerpf(chase_zoom, 1.0, 1.0 - exp(-16.0 * delta))
		if chase_t <= 0.0:
			chase_t = 0.0
			chase_actor = null
			chase_hold = false
			if state == State.RESOLVING:
				shot_overview(0.4)
	else:
		chase_t = 0.0
		chase_zoom = lerpf(chase_zoom, 0.0, 1.0 - exp(-9.0 * delta))
	camera.fov = lerpf(camera.fov, chase_fov, chase_zoom)


func launch(c: Actor, wall: String, dur: float, spin_z: float, spin_y := 0.0) -> Tween:
	# Send a customer flying across the room into a wall ("left" | "right" | "back"),
	# where it explodes.
	var start := c.pivot.position
	var target: Vector3
	var normal: Vector3
	match wall:
		"left":
			target = Vector3(-5.8, 2.3, start.z - 2.0)
			normal = Vector3(1, 0, 0)
		"right":
			target = Vector3(5.8, 2.9, clampf(start.z - 3.5, -11.0, 4.0))
			normal = Vector3(-1, 0, 0)
		_:
			target = Vector3(clampf(start.x + 0.5, -5.0, 4.2), 2.5, -12.3)
			normal = Vector3(0, 0, 1)
	start_chase(c, dur + 0.6)
	var tw := create_tween().set_parallel(true)
	tw.tween_method(func(k: float):
		c.pivot.position = start.lerp(target - Vector3(0, c.height * 0.5, 0), k) + Vector3(0, sin(k * PI) * 0.7, 0), 0.0, 1.0, dur)
	tw.tween_property(c.body, "rotation:z", spin_z, dur)
	if spin_y != 0.0:
		tw.tween_property(c.body, "rotation:y", spin_y, dur)
	tw.tween_property(c.pivot, "scale", Vector3.ONE, dur * 0.5)
	tw.chain().tween_callback(explode_fish.bind(c, target, normal))
	return tw


# ---------------------------------------------------------------- wall explosion

func fx_mat(col: Color, emission := 3.0) -> StandardMaterial3D:
	var m := std_mat(col, emission)
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	return m


func fx_mesh(parent: Node3D, mesh: Mesh, mat: Material, pos := Vector3.ZERO) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.position = pos
	parent.add_child(mi)
	return mi


func fx_particles(parent: Node3D, mesh: Mesh, amount: int, life: float, vmin: float, vmax: float, spread: float, gravity: Vector3) -> CPUParticles3D:
	var p := CPUParticles3D.new()
	p.mesh = mesh
	p.one_shot = true
	p.explosiveness = 1.0
	p.amount = amount
	p.lifetime = life
	p.direction = Vector3(0, 0, 1)  # out of the wall
	p.spread = spread
	p.gravity = gravity
	p.initial_velocity_min = vmin
	p.initial_velocity_max = vmax
	p.scale_amount_min = 0.5
	p.scale_amount_max = 1.6
	p.position = Vector3(0, 0, 0.15)
	parent.add_child(p)
	p.emitting = true
	return p


func explode_fish(c: Actor, pos: Vector3, normal: Vector3) -> void:
	# The fish hits the wall and goes off like a firework: flash, fireballs, shockwave rings,
	# comic impact lines, chunks, sparks, bubbles, a paint splat and two flying eyeballs.
	var col: Color = c.data.get("color", Color(1, 0.6, 0.2))
	free_actor(c)
	shake = 38.0
	hitstop(0.08)
	boom_player.pitch_scale = rng.randf_range(0.95, 1.25)
	boom_player.play()
	add_popup(pick(["KABOOM!", "SPLAT!", "BOOM!", "KA-POW!"]), Vector2(rng.randf_range(-60, 60), 330), Color(1, 0.85, 0.2), 54, 1.0)
	if chase_t > 0.0:
		chase_actor = null
		chase_hold = true
		chase_point = pos + normal * 0.4
	var root := Node3D.new()
	root.position = pos
	root.basis = Basis.looking_at(-normal, Vector3.UP)  # local +Z points out of the wall
	add_child(root)
	get_tree().create_timer(3.2, false).timeout.connect(root.queue_free)

	# light flash
	var light := OmniLight3D.new()
	light.position = Vector3(0, 0, 0.8)
	light.omni_range = 10.0
	light.light_color = Color(1, 0.8, 0.5)
	light.light_energy = 12.0
	root.add_child(light)
	create_tween().tween_property(light, "light_energy", 0.0, 0.45)

	# white flash ball
	var sphere := SphereMesh.new()
	sphere.radius = 0.5
	sphere.height = 1.0
	var fm := fx_mat(Color(1, 1, 0.9, 0.95), 4.0)
	var flash := fx_mesh(root, sphere, fm, Vector3(0, 0, 0.2))
	flash.scale = Vector3.ONE * 0.4
	var ft := create_tween().set_parallel(true)
	ft.tween_property(flash, "scale", Vector3.ONE * 5.5, 0.16).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	ft.tween_property(fm, "albedo_color:a", 0.0, 0.16)

	# fireballs
	for i in 9:
		var fc: Color = [Color(1, 0.55, 0.1), Color(1, 0.85, 0.2), col.lightened(0.3), Color(1, 0.3, 0.15)][i % 4]
		var m := fx_mat(fc, 3.0)
		var ball := fx_mesh(root, sphere, m, Vector3(rng.randf_range(-0.9, 0.9), rng.randf_range(-0.9, 0.9), rng.randf_range(0.2, 0.9)))
		ball.scale = Vector3.ZERO
		var bt := create_tween()
		bt.tween_interval(i * 0.018)
		bt.tween_property(ball, "scale", Vector3.ONE * rng.randf_range(1.0, 2.0), 0.16).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		bt.tween_property(ball, "scale", Vector3.ONE * 0.2, 0.4).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		bt.parallel().tween_property(m, "albedo_color:a", 0.0, 0.4)
		bt.parallel().tween_property(ball, "position:z", ball.position.z + 0.8, 0.4)

	# shockwave rings on the wall
	var torus := TorusMesh.new()
	torus.inner_radius = 0.86
	torus.outer_radius = 1.0
	for i in 2:
		var m := fx_mat(Color(1, 1, 1, 0.9) if i == 0 else Color(col.lightened(0.4), 0.9), 2.5)
		var ring := fx_mesh(root, torus, m, Vector3(0, 0, 0.06 + i * 0.05))
		ring.rotation.x = PI / 2.0
		ring.scale = Vector3.ONE * 0.2
		var rt := create_tween()
		rt.tween_interval(i * 0.09)
		rt.tween_property(ring, "scale", Vector3(5.5, 1.0, 5.5) if i == 0 else Vector3(3.8, 1.0, 3.8), 0.45).set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)
		rt.parallel().tween_property(m, "albedo_color:a", 0.0, 0.45)

	# comic impact lines radiating over the wall
	var line := BoxMesh.new()
	line.size = Vector3(0.09, 1.0, 0.03)
	for i in 12:
		var ang := TAU * i / 12.0 + rng.randf_range(-0.12, 0.12)
		var dir := Vector3(sin(ang), cos(ang), 0)
		var m := fx_mat(Color(1, 0.95, 0.4, 1.0), 3.0)
		var l := fx_mesh(root, line, m, dir * 0.7 + Vector3(0, 0, 0.08))
		l.rotation.z = -ang
		l.scale = Vector3(1, 0.1, 1)
		var lt := create_tween()
		var reach := rng.randf_range(1.6, 2.8)
		lt.tween_property(l, "position", dir * reach + Vector3(0, 0, 0.08), 0.14).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
		lt.parallel().tween_property(l, "scale:y", rng.randf_range(1.0, 1.9), 0.14)
		lt.tween_property(l, "scale", Vector3(0.1, 0.1, 1), 0.22)
		lt.parallel().tween_property(l, "position", dir * (reach + 0.9) + Vector3(0, 0, 0.08), 0.22)

	# chunks of fish
	var chunk := BoxMesh.new()
	chunk.size = Vector3.ONE * 0.16
	var cm := std_mat(Color.WHITE)
	cm.vertex_color_use_as_albedo = true
	chunk.material = cm
	var chunks := fx_particles(root, chunk, 80, 1.3, 4.0, 13.0, 78.0, Vector3(0, -11, 0))
	chunks.color = col
	chunks.hue_variation_min = -0.06
	chunks.hue_variation_max = 0.06
	# sparks
	var spark := SphereMesh.new()
	spark.radius = 0.045
	spark.height = 0.09
	spark.material = std_mat(Color(1, 0.95, 0.6), 3.0)
	fx_particles(root, spark, 60, 0.6, 8.0, 19.0, 85.0, Vector3(0, -5, 0))
	# bubbles (we're underwater after all)
	var bub := SphereMesh.new()
	bub.radius = 0.09
	bub.height = 0.18
	bub.material = fx_mat(Color(0.8, 0.97, 1.0, 0.45), 0.6)
	fx_particles(root, bub, 40, 1.8, 1.0, 5.0, 70.0, Vector3(0, 3.5, 0))

	# paint splat left on the wall, dripping away
	var disc := CylinderMesh.new()
	disc.top_radius = 1.0
	disc.bottom_radius = 1.0
	disc.height = 0.02
	var sm := fx_mat(Color(col.darkened(0.1), 0.95), 0.0)
	var blobs: Array = [[Vector3.ZERO, 1.25]]
	for i in 9:
		var a := rng.randf() * TAU
		blobs.append([Vector3(cos(a), sin(a), 0) * rng.randf_range(0.9, 2.0), rng.randf_range(0.15, 0.5)])
	for bl in blobs:
		var d := fx_mesh(root, disc, sm, bl[0] + Vector3(0, 0, 0.03))
		d.rotation.x = PI / 2.0
		d.scale = Vector3.ONE * 0.1
		var size: float = bl[1]
		var dt := create_tween()
		dt.tween_property(d, "scale", Vector3(size, 1, size), 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		dt.tween_interval(0.9)
		# drip: stretch downwards
		dt.tween_property(d, "scale", Vector3(size * 0.8, 1, size * 1.5), 1.2)
		dt.parallel().tween_property(d, "position:y", d.position.y - size * 0.7, 1.2)
	var st := create_tween()
	st.tween_interval(1.6)
	st.tween_property(sm, "albedo_color:a", 0.0, 1.2)

	# two eyeballs fly off and bounce on the floor
	var eye_mesh := SphereMesh.new()
	eye_mesh.radius = 0.14
	eye_mesh.height = 0.28
	var pupil_mesh := SphereMesh.new()
	pupil_mesh.radius = 0.07
	pupil_mesh.height = 0.14
	for i in 2:
		var eye := fx_mesh(root, eye_mesh, std_mat(Color.WHITE, 0.3), Vector3(0, 0, 0.3))
		fx_mesh(eye, pupil_mesh, std_mat(Color(0.05, 0.05, 0.1)), Vector3(0, 0, 0.1))
		var from := eye.position
		var land := Vector3(rng.randf_range(0.5, 2.2) * (1.0 if i == 0 else -1.0), 0.14 - pos.y, rng.randf_range(1.6, 3.6))
		var top := rng.randf_range(0.8, 1.8)
		var et := create_tween()
		et.tween_method(func(k: float):
			eye.position = from.lerp(land, k) + Vector3(0, sin(k * PI) * top, 0)
			eye.rotation = Vector3(k * 9.0, k * 6.0, 0), 0.0, 1.0, 0.7)
		for bounce in 2:
			var h := 0.5 / (bounce + 1.0)
			var b0 := land + Vector3(0, 0, 0.5 * bounce)
			var b1 := land + Vector3(0, 0, 0.5 * (bounce + 1))
			et.tween_method(func(k: float):
				eye.position = b0.lerp(b1, k) + Vector3(0, sin(k * PI) * h, 0)
				eye.rotation.x += 0.2, 0.0, 1.0, 0.25)
		et.tween_interval(0.6)
		et.tween_property(eye, "scale", Vector3.ZERO, 0.25)


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
		launch(c, "right", 0.5, 14.0, TAU * 3.0))
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
		launch(c, "back", 0.5, -10.0))
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
		impact(c, 26.0)
		hitstop(0.14)
		c.pivot.scale = Vector3(0.55, 1.3, 1)  # squished by the hand
		# slapped clean across the room into the left wall, spinning like a top
		launch(c, "left", 0.5, -7.0, TAU * 5.0))
	# follow-through and fade out
	tw.tween_property(hand, "position", p + Vector3(-1.4, c.height * 0.45, 0.35), 0.18).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(hand, "rotation:z", -0.95, 0.18)
	tw.parallel().tween_property(cashier.body, "rotation:z", 0.0, 0.25)
	tw.tween_property(hand, "scale", Vector3.ZERO, 0.2)
	tw.tween_callback(hand.queue_free)


func attack_fail() -> void:
	end_attack_variant()
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
	skip_cinematic = to_title
	# fade to a black loading screen, reload, fade back in (see fader.gd)
	load("res://scripts/fader.gd").get_or_create(get_tree()).reload_scene()


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
	var now := Time.get_ticks_usec()
	if perf_last > 0:
		var ms := (now - perf_last) / 1000.0
		perf_worst_ms = maxf(perf_worst_ms, ms)
		perf_frames += 1
		if ms > 20.0:
			perf_slow_frames += 1
	perf_last = now
	t += delta
	handle_input()
	layout_queue()
	match state:
		State.CINEMA:
			update_cinematic(delta)
			if cine_skip >= 0.0 and state == State.CINEMA:
				cine_skip += delta
				if cine_skip >= CINE_SKIP_FADE:
					cine_skip = -1.0
					end_cinematic()
		State.TITLE:
			title_t += delta
		State.COUNTDOWN:
			countdown_t += delta
			if countdown_n > 0 and countdown_t >= 0.8:
				countdown_n -= 1
				countdown_t = 0.0
				play_hit()
			elif countdown_n == 0 and countdown_t >= 0.7:
				if menu.tutorial_pending():
					# first time playing: explain the rules, the round starts when it closes
					menu.open_tutorial(begin_customer)
				else:
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
			update_attack(delta)
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
	animate_decor(delta)
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
	update_crowd_sound(delta)
	bar_shown = lerpf(bar_shown, float(bar), 1.0 - exp(-12.0 * delta))
	shake = maxf(0.0, shake - 40.0 * delta)
	power_flash = maxf(0.0, power_flash - delta * 3.0)
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
	update_chase(delta)
	if state == State.ATTACK and attack_mode == "rage":
		camera.fov += smoothstep(0.2, 1.0, rage) * 14.0  # pull back so the whole power-up aura is in frame
	# The title and the 2D part of the cinematic cover the whole screen, so the
	# 3D world behind them doesn't need to be drawn. (Kept on for the first second so the
	# shaders are built while nothing can stutter visibly.)
	var covered := state == State.TITLE or (state == State.CINEMA and not cine_3d)
	get_viewport().disable_3d = covered and t > 1.0
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
		State.CINEMA:
			if Input.is_action_just_pressed("skip_cutscene") and cine_t > 0.5 and cine_skip < 0.0:
				cine_skip = 0.0  # fade to black, then the title fades in
				voice.stop()
		State.TITLE:
			if any_just and title_t > 0.4 and not menu.title_quit_hovered():
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
			match attack_mode:
				"combo":
					if dir >= 0:
						attack_input(dir)
				"rage":
					if Input.is_action_just_pressed("mash"):
						rage_press()
				"quiz":
					if dir >= 0:
						quiz_answer(dir)
					for i in 4:
						if Input.is_action_just_pressed("quiz_%d" % i):
							quiz_answer(i)
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
			if Input.is_key_pressed(KEY_R) and not scores.blocking():  # shortcut; the HUD buttons handle mouse/Enter
				restart(false)


# ---------------------------------------------------------------- performance & profiling

func build_warm_rig() -> void:
	# Effect materials (explosion, sparks, thrown burgers, glove ...) only exist while an effect
	# plays. When the last one is freed the driver throws its shader away and has to rebuild it
	# on the next hit - a 100-270 ms freeze every time. This invisible, sub-pixel rig in front
	# of the camera uses one material of every effect type all the time, so the shaders are
	# built once at startup (behind the cinematic) and never dropped.
	var rig := Node3D.new()
	rig.name = "WarmRig"
	rig.position = Vector3(0, 0, -3)
	rig.scale = Vector3.ONE * 0.0005
	camera.add_child(rig)
	var quad := QuadMesh.new()
	var vertex_col := std_mat(Color.WHITE)
	vertex_col.vertex_color_use_as_albedo = true
	var mats: Array = [fx_mat(Color.WHITE, 3.0), fx_mat(Color.WHITE, 0.0), std_mat(Color.WHITE, 2.0), std_mat(Color.WHITE), vertex_col]
	for m in mats:
		fx_mesh(rig, quad, m)
		# the same material drawn through particles is a different shader variant
		var pm := QuadMesh.new()
		pm.material = m
		var p := CPUParticles3D.new()
		p.mesh = pm
		p.amount = 1
		p.lifetime = 10.0
		p.local_coords = true  # otherwise the particle stays behind in the world at full size
		p.scale_amount_min = 0.0005
		p.scale_amount_max = 0.0005
		p.gravity = Vector3.ZERO
		p.color = Color(1, 0.5, 0.2)
		rig.add_child(p)
	# sprites thrown through the room (burger, tray, glove, hand, winged burger)
	var spr := Sprite3D.new()
	spr.texture = burger_tex
	spr.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
	rig.add_child(spr)
	# a dim light, so the "lit by an extra omni light" variants are ready for the explosion flash
	var l := OmniLight3D.new()
	l.omni_range = 0.5
	l.light_energy = 0.01
	rig.add_child(l)


func _on_node_added(n: Node) -> void:
	if n is MeshInstance3D or n is CPUParticles3D:
		optimize_mesh.call_deferred(n)


func optimize_mesh(n: Node) -> void:
	# Godot's default spheres / cylinders have 64 segments (a sphere = 4224 triangles), which is
	# far more than these shapes need on screen. Pick the segment count from the real world size,
	# so big shapes stay perfectly round and tiny ones (bubbles, sparks, particles) get cheap.
	if not is_instance_valid(n) or not n.is_inside_tree() or not is_ancestor_of(n):
		return
	var mesh: Mesh = n.mesh
	if mesh == null or mesh.has_meta("opt"):
		return
	var sc: Vector3 = n.global_transform.basis.get_scale()
	var k := maxf(sc.x, maxf(sc.y, sc.z))
	var particle := n is CPUParticles3D
	if particle:
		k *= n.scale_amount_max
	if mesh is SphereMesh:
		var size: float = mesh.radius * k
		var seg := 12 if size < 0.12 else (20 if size < 0.5 else (32 if size < 2.0 else 48))
		if particle:
			seg = 8 if size < 0.2 else 12
		mesh.radial_segments = seg
		mesh.rings = maxi(3, seg / 2)
	elif mesh is CylinderMesh:
		var size: float = maxf(mesh.top_radius, mesh.bottom_radius) * k
		var seg := 10 if size < 0.1 else (16 if size < 0.5 else (28 if size < 2.0 else 48))
		if particle:
			seg = 8
		mesh.radial_segments = seg
		mesh.rings = 1
	elif mesh is TorusMesh:
		mesh.rings = 48
		mesh.ring_segments = 8
	else:
		return
	mesh.set_meta("opt", true)


var perf_last := 0
var perf_worst_ms := 0.0  # longest frame since the last perf_stats() call
var perf_frames := 0
var perf_slow_frames := 0  # frames over 20 ms since the last perf_stats() call


func perf_stats() -> Dictionary:
	# Debug: frame cost breakdown (used while optimising; call twice, the first call enables measuring).
	var vp := get_viewport().get_viewport_rid()
	RenderingServer.viewport_set_measure_render_time(vp, true)
	var worst := perf_worst_ms
	var frames := perf_frames
	var slow := perf_slow_frames
	perf_worst_ms = 0.0
	perf_frames = 0
	perf_slow_frames = 0
	return {
		"slow_frames": slow,
		"worst_frame_ms": worst,
		"frames": frames,
		"fps": Performance.get_monitor(Performance.TIME_FPS),
		"process_ms": Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0,
		"render_cpu_ms": RenderingServer.viewport_get_measured_render_time_cpu(vp) + RenderingServer.get_frame_setup_time_cpu(),
		"render_gpu_ms": RenderingServer.viewport_get_measured_render_time_gpu(vp),
		"draw_calls": Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),
		"objects": Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME),
		"primitives": Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME),
		"nodes": Performance.get_monitor(Performance.OBJECT_NODE_COUNT),
		"video_mem_mb": Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED) / 1048576.0,
		"size": get_viewport().get_visible_rect().size,
		"window": DisplayServer.window_get_size(),
		"vsync": DisplayServer.window_get_vsync_mode(),
	}


func perf_meshes() -> Array:
	# Debug: the biggest triangle contributors in the scene, grouped by mesh type + parent function.
	var groups := {}
	var stack: Array = [self]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		stack.append_array(n.get_children())
		var mesh: Mesh = null
		var mult := 1
		if n is MeshInstance3D:
			mesh = n.mesh
		elif n is CPUParticles3D:
			mesh = n.mesh
			mult = n.amount
		elif n is MultiMeshInstance3D and n.multimesh:
			mesh = n.multimesh.mesh
			mult = n.multimesh.instance_count
		if mesh == null:
			continue
		var tris := 0
		for si in mesh.get_surface_count():
			var arr := mesh.surface_get_arrays(si)
			var idx = arr[Mesh.ARRAY_INDEX]
			tris += (idx.size() if idx != null and idx.size() > 0 else arr[Mesh.ARRAY_VERTEX].size()) / 3
		var key := "%s/%s%s" % [n.get_class(), mesh.get_class(), "" if n.visible else " (hidden)"]
		if not groups.has(key):
			groups[key] = {"key": key, "count": 0, "tris": 0, "max_one": 0}
		groups[key]["count"] += 1
		groups[key]["tris"] += tris * mult
		groups[key]["max_one"] = maxi(groups[key]["max_one"], tris * mult)
	var out: Array = groups.values()
	out.sort_custom(func(a, b): return a["tris"] > b["tris"])
	return out


func perf_uncap(on: bool) -> void:
	# Debug: turn vsync off to see the real frame cost as an uncapped FPS number.
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED if on else DisplayServer.VSYNC_ENABLED)
