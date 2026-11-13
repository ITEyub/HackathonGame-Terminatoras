extends Node
## Animalese-style babble: every letter of the text plays its own short clip (a-z, 0-9),
## sped up and pitched per speaker, each letter cutting off the previous one.
## Also drives the typewriter reveal of the speech bubble (shown_text()).

const LETTERS := "abcdefghijklmnopqrstuvwxyz0123456789"
const CLIP_PATH := "res://assets/animalese/default/snd_light_%s.ogg"
const UMLAUTS := {"ä": "a", "ö": "o", "ü": "u", "ß": "s", "é": "e", "è": "e"}

var streams := {}
var player: AudioStreamPlayer
var text := ""
var idx := 0
var timer := 0.0
var interval := 0.045
var pitch := 1.5
var speaking := false
var rng := RandomNumberGenerator.new()


func _ready() -> void:
	rng.randomize()
	player = AudioStreamPlayer.new()
	player.volume_db = -3.0
	add_child(player)
	for c in LETTERS:
		streams[c] = load(CLIP_PATH % c)


func speak(t: String, base_pitch: float, letter_time := 0.045) -> void:
	text = t
	idx = 0
	timer = 0.0
	pitch = base_pitch
	interval = letter_time
	speaking = true


func stop() -> void:
	speaking = false
	player.stop()


func is_saying(t: String) -> bool:
	return text == t and (speaking or idx > 0)


func shown_text() -> String:
	return text.substr(0, idx)


func _process(delta: float) -> void:
	if not speaking:
		return
	timer -= delta
	while timer <= 0.0 and speaking:
		if idx >= text.length():
			speaking = false
			break
		var ch := text[idx]
		idx += 1
		timer += say_char(ch)


func say_char(ch: String) -> float:
	# Plays one character and returns how long until the next one.
	var c := ch.to_lower()
	if UMLAUTS.has(c):
		c = UMLAUTS[c]
	if c == " ":
		return interval * 0.8
	if c in [",", ";", ":", "-"]:
		return interval * 3.0
	if c in [".", "!", "?"]:
		return interval * 4.0
	if not streams.has(c):
		return interval * 0.5
	var p := pitch * rng.randf_range(0.9, 1.1)
	var tail := text.strip_edges()
	if tail.ends_with("?") and idx > text.length() - 7:
		p *= 1.0 + 0.04 * (idx - (text.length() - 7))  # questions rise at the end
	player.stream = streams[c]
	player.pitch_scale = p
	player.volume_db = 0.0 if tail.ends_with("!") else -3.0
	player.play()
	return interval
