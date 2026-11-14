extends Node
## Automatic benchmark. Start the game with:  Godot --path godotproject -- bench gfx=0|1|2
## Plays through every part of the game by itself (cinematic, title, intro, gameplay, all three
## attack games + explosions and a serve minigame), records every frame time and
## prints one "BENCH_RESULT {...}" JSON line per phase, then quits. Nothing is saved to settings.

var game
var phase := ""
var frames: Array[float] = []
var proc_ms: Array[float] = []
var render_ms: Array[float] = []
var draws: Array[float] = []
var last_us := 0
var results := {}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	RenderingServer.viewport_set_measure_render_time(get_viewport().get_viewport_rid(), true)
	run.call_deferred()


func _process(_delta: float) -> void:
	var now := Time.get_ticks_usec()
	if last_us > 0 and phase != "":
		frames.append((now - last_us) / 1000.0)
		proc_ms.append(Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0)
		var vp := get_viewport().get_viewport_rid()
		render_ms.append(RenderingServer.viewport_get_measured_render_time_cpu(vp) + RenderingServer.get_frame_setup_time_cpu())
		draws.append(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
	last_us = now


func measure(name: String, seconds: float) -> void:
	phase = name
	frames.clear()
	proc_ms.clear()
	render_ms.clear()
	draws.clear()
	await wait(seconds)
	var sorted := frames.duplicate()
	sorted.sort()
	var n := sorted.size()
	var total := 0.0
	var slow := 0
	for f in sorted:
		total += f
		if f > 33.4:
			slow += 1
	var r := {
		"avg_fps": snappedf(1000.0 / (total / maxi(n, 1)), 0.1),
		"low1_fps": snappedf(1000.0 / sorted[int(n * 0.99)], 0.1) if n > 0 else 0.0,
		"worst_ms": snappedf(sorted[-1], 0.1) if n > 0 else 0.0,
		"frames_over_33ms": slow,
		"frames": n,
		"script_ms": snappedf(avg(proc_ms), 0.01),
		"render_cpu_ms": snappedf(avg(render_ms), 0.01),
		"draw_calls": int(avg(draws)),
	}
	results[name] = r
	print("BENCH_PHASE %s %s" % [name, JSON.stringify(r)])
	phase = ""


func avg(a: Array[float]) -> float:
	var t := 0.0
	for v in a:
		t += v
	return t / maxi(a.size(), 1)


func shot(name: String) -> void:
	# with "shots" on the command line, save a screenshot of the phase to the system temp folder
	if OS.get_cmdline_user_args().has("shots"):
		await RenderingServer.frame_post_draw  # grab a freshly drawn frame
		var path := OS.get_temp_dir().path_join("bench_%s.png" % name)
		get_viewport().get_texture().get_image().save_png(path)
		print("BENCH_SHOT ", path)


func wait(seconds: float) -> void:
	await get_tree().create_timer(seconds, true, false, true).timeout


func wait_for_decision(limit := 8.0) -> void:
	var t := 0.0
	while not game.can_decide() and t < limit:
		await wait(0.1)
		t += 0.1


func run() -> void:
	var gfx := 2
	for a in OS.get_cmdline_user_args():
		if a.begins_with("gfx="):
			gfx = int(a.substr(4))
	var menu = game.menu
	menu.graphics = gfx  # in memory only, nothing is written to settings.cfg
	menu.apply_graphics()
	menu.tutorial_seen = true
	await wait(1.5)  # startup / shader warm-up is not part of any phase
	if OS.get_cmdline_user_args().has("menuswitch"):
		# pause menu -> MENU: screenshots through the fade / reload / title fade-in
		game.end_cinematic()
		await wait(0.3)
		game.start_blackout()
		await wait(0.5)
		game.skip_intro()
		await wait_for_decision(10.0)
		game.menu.open_pause()
		await wait(0.3)
		reparent.call_deferred(get_tree().root)  # survive the scene reload
		await get_tree().process_frame
		game.menu.do_action("menu")
		for k in [0.15, 0.25, 0.25, 0.3, 0.6]:
			await wait(k)
			await shot("switch_%d" % int(Time.get_ticks_msec()))
		get_tree().quit()
		return
	if OS.get_cmdline_user_args().has("roomshots"):
		# screenshots of the restaurant from a few angles (use together with "shots")
		game.end_cinematic()
		await wait(0.3)
		game.state = 6  # RESOLVING: no gameplay camera moves
		get_viewport().disable_3d = false
		var views := [
			["overview", Vector3(0.2, 2.45, 3.7), Vector3(0.9, 0.75, -3.5)],
			["left_tables", Vector3(1.5, 2.0, 0.5), Vector3(-4.2, 1.0, -6.0)],
			["slot_machine", Vector3(-2.3, 1.6, -0.2), Vector3(-5.4, 1.2, -1.3)],
			["restrooms", Vector3(-1.5, 2.0, -6.0), Vector3(-5.9, 1.6, -10.0)],
			["counter_wall", Vector3(-0.6, 1.25, -0.9), Vector3(-0.8, 2.4, 5.4)],
			["back_door", Vector3(1.0, 2.2, -4.0), Vector3(3.8, 1.5, -12.0)],
		]
		for v in views:
			game.shot(v[1], v[2], 0.0)
			await wait(0.4)
			await shot("room_" + v[0])
		get_tree().quit()
		return
	if OS.get_cmdline_user_args().has("cineshots"):
		# screenshots of the opening cutscene's character shots (use together with "shots")
		for p in [["commander", 13.0], ["surfer", 17.6], ["soldier", 22.2], ["cashier", 27.0], ["jump", 32.6], ["cabin", 35.5], ["crash", 42.5]]:
			game.seek_cinematic(p[1])
			await wait(0.5)
			await shot("cine_" + p[0])
		get_tree().quit()
		return
	if OS.get_cmdline_user_args().has("experiments"):
		await experiments()
		return
	await measure("cinematic", 7.0)
	game.end_cinematic()
	await wait(1.3)
	await measure("title", 3.0)
	game.start_blackout()
	await measure("intro_flythrough", 5.0)
	game.skip_intro()
	await wait_for_decision(10.0)
	await measure("gameplay", 3.0)
	await shot("gameplay")

	await wait_for_decision()
	game.start_attack("combo")
	game.attack_success()
	await measure("combo_attack_explosion", 3.0)

	await wait_for_decision()
	game.start_attack("rage")
	game.rage = 0.9
	game.rage_drain = 0.0
	game.attack_left = 99.0
	await measure("rage_powerup", 3.0)
	await shot("rage")
	for i in 6:
		game.rage_press()
	await measure("rage_attack_explosion", 3.0)

	await wait_for_decision()
	game.start_attack("quiz")
	await measure("quiz", 2.5)
	await shot("quiz")
	game.quiz_answer(game.quiz["correct"])
	await wait(2.2)

	await wait_for_decision()
	game.start_flip()
	await measure("flip_minigame", 3.0)
	game.flip_success()
	await wait(3.0)

	print("BENCH_RESULT gfx=%d %s" % [gfx, JSON.stringify(results)])
	get_tree().quit()


func experiments() -> void:
	# Same gameplay moment with parts switched off, to see where the frame time goes.
	game.end_cinematic()
	await wait(0.5)
	game.start_blackout()
	await wait(1.0)
	game.skip_intro()
	await wait_for_decision(10.0)
	game.time_left = 999.0
	game.talk_left = 999.0
	await measure("normal", 3.0)
	game.hud.visible = false
	await measure("no_hud", 3.0)
	game.hud.visible = true
	get_viewport().disable_3d = true
	await measure("no_3d", 3.0)
	get_viewport().disable_3d = false
	game.set_process(false)
	await measure("no_game_process", 3.0)
	game.set_process(true)
	for n in game.find_children("*", "CPUParticles3D", true, false):
		n.visible = false
	await measure("no_particles", 3.0)
	for n in game.find_children("*", "CPUParticles3D", true, false):
		n.visible = true
	var sun: DirectionalLight3D = game.find_children("*", "DirectionalLight3D", false, false)[0]
	sun.shadow_enabled = false
	await measure("no_shadows", 3.0)
	sun.shadow_enabled = true
	get_tree().quit()
