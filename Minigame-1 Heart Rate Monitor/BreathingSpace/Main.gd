extends Node2D
## Breathing Space (Heart Rate Manager) - a self-contained Godot 4 minigame.
## Keep your BPM in the steady zone (60-100), press SPACE to exhale, dodge stressors.
## Control: press (or spam) SPACE to exhale. Optional art/audio live in res://assets;
## if a file is missing the game falls back to shapes / silence.

signal minigame_finished(won: bool, score: int)

## Scene to load after the final fade to black (your main game menu).
## Leave empty to return to this minigame's own title screen instead.
@export_file("*.tscn") var menu_scene_path: String = ""

# ── Constants ──────────────────────────────────────────────────────────────
const SCREEN_W: int = 2400
const SCREEN_H: int = 1350
const PLAY_TOP: float = 220.0
const PLAY_BOT: float = 1230.0 # SCREEN_H - 120

const BPM_MIN: float = 40.0
const BPM_MAX: float = 180.0
const BPM_START: float = 72.0
const BPM_BASELINE: float = 75.0
const SAFE_MIN: float = 60.0
const SAFE_MAX: float = 100.0

const BALL_X: float = 320.0
const BALL_RADIUS: float = 40.0
const MAX_LEVELS: int = 3
const MAX_LIVES: int = 3
const SPEED_SCALE: float = 3.75
const HUD_MARGIN: int = 40
const EXHALE_DROP_MIN: float = 5.0   # BPM dropped per SPACE press (no cooldown)
const EXHALE_DROP_MAX: float = 7.0
const BREATH_FLASH_TIME: float = 0.25

# Each chapter has its own intensity profile (difficulty, look and music).
#  duration  : seconds to survive           spawn   : seconds between stressors
#  speed     : base stressor speed          track   : chance a stressor aims at your height
#  pressure  : BPM/sec upward push          danger  : seconds in danger before losing a heart
#  hit       : multiplier on BPM spike per hit
#  themes    : spawn weights for [Self, Social Media, Class] stressors
#  double    : chance of a second stressor  scan/vignette/tint : visual intensity
const CHAPTERS: Array[Dictionary] = [
	{ "name": "Quiet Morning", "sub": "Take it slow. Breathe.", "duration": 30.0, "themes": [0.60, 0.25, 0.15],
	  "spawn": 1.5, "speed": 1.5, "track": 0.60, "pressure": 1.0, "danger": 2.4,
	  "hit": 0.8, "double": 0.0, "scan": 0.08, "vignette": 0.0, "tint": Color(0.96, 0.64, 0.38) },
	{ "name": "Before Class", "sub": "The day starts moving.", "duration": 35.0, "themes": [0.20, 0.45, 0.35],
	  "spawn": 0.85, "speed": 2.2, "track": 0.70, "pressure": 2.5, "danger": 2.0,
	  "hit": 1.0, "double": 0.25, "scan": 0.11, "vignette": 0.10, "tint": Color(0.90, 0.45, 0.25) },
	{ "name": "After Class", "sub": "Everything piles up at once.", "duration": 40.0, "themes": [0.20, 0.30, 0.50],
	  "spawn": 0.55, "speed": 3.0, "track": 0.82, "pressure": 4.0, "danger": 1.6,
	  "hit": 1.3, "double": 0.40, "scan": 0.15, "vignette": 0.24, "tint": Color(0.60, 0.25, 0.65) },
]

const SFX_PATHS: Dictionary = {
	"exhale": "res://assets/audio/sfx_exhale.wav",
	"hit": "res://assets/audio/sfx_hit.wav",
	"heartbeat": "res://assets/audio/sfx_heartbeat.wav",
	"life_lost": "res://assets/audio/sfx_life_lost.wav",
	"danger_tick": "res://assets/audio/sfx_danger_tick.wav",
	"chapter_start": "res://assets/audio/sfx_chapter_start.wav",
	"win": "res://assets/audio/sfx_win.wav",
	"lose": "res://assets/audio/sfx_lose.wav",
	"ui_start": "res://assets/audio/sfx_ui_start.wav",
}
const MUSIC_PATHS: Array[String] = [
	"res://assets/audio/music_ch1.wav",
	"res://assets/audio/music_ch2.wav",
	"res://assets/audio/music_ch3.wav",
]
const MUSIC_DB: float = -14.0
const MUSIC_TITLE_DB: float = -22.0
const SFX_MAX_DB: float = -6.0          # no sound effect can ever play louder than this
# Minimum seconds between two plays of the same sound (anti-spam)
const SFX_MIN_INTERVAL: Dictionary = {
	"exhale": 0.16, "hit": 0.12, "danger_tick": 0.10, "heartbeat": 0.25,
	"life_lost": 0.5, "chapter_start": 0.5, "win": 0.5, "lose": 0.5, "ui_start": 0.2,
}

# Stressor themes: 0 = Self, 1 = Social Media, 2 = Class
const THEMES: Array[Dictionary] = [
	{ "name": "SELF",         "color": Color(0.55, 0.28, 0.70) },
	{ "name": "SOCIAL MEDIA", "color": Color(0.78, 0.32, 0.48) },
	{ "name": "CLASS",        "color": Color(0.85, 0.45, 0.25) },
]

const STRESSOR_TYPES: Array[Dictionary] = [
	# Self: inner doubts and neglected self-care
	{ "theme": 0, "label": "Not Good Enough",   "bpm_hit": 22.0, "w": 290.0, "h": 64.0 },
	{ "theme": 0, "label": "No Sleep Again",    "bpm_hit": 14.0, "w": 280.0, "h": 64.0 },
	{ "theme": 0, "label": "Self-Doubt",        "bpm_hit": 20.0, "w": 220.0, "h": 64.0 },
	{ "theme": 0, "label": "Skipped Self-Care", "bpm_hit": 12.0, "w": 325.0, "h": 64.0 },
	# Social media: doomscrolling and online pressure
	{ "theme": 1, "label": "Doomscrolling",        "bpm_hit": 18.0, "w": 265.0, "h": 64.0 },
	{ "theme": 1, "label": "Left on Read",         "bpm_hit": 16.0, "w": 250.0, "h": 64.0 },
	{ "theme": 1, "label": "Notification Flood",   "bpm_hit": 14.0, "w": 340.0, "h": 64.0 },
	{ "theme": 1, "label": "Everyone Looks Happy", "bpm_hit": 24.0, "w": 370.0, "h": 64.0 },
	# Class: homework anxiety, deadlines, school stress
	{ "theme": 2, "label": "Deadline Tomorrow",   "bpm_hit": 24.0, "w": 350.0, "h": 64.0, "icon": "deadline" },
	{ "theme": 2, "label": "Pop Quiz",            "bpm_hit": 14.0, "w": 190.0, "h": 64.0 },
	{ "theme": 2, "label": "Unfinished Homework", "bpm_hit": 20.0, "w": 355.0, "h": 64.0 },
	{ "theme": 2, "label": "Group Project Panic", "bpm_hit": 22.0, "w": 355.0, "h": 64.0 },
]

# 7x6 pixel heart used for the FOCUS meter
const HEART_PATTERN: Array[String] = [
	"0110110",
	"1111111",
	"1111111",
	"0111110",
	"0011100",
	"0001000",
]
const HEART_PX: float = 7.0

# ── Design tokens (warm sepia / twilight blue / cream) ───────────────────────
const C_BG_DARK: Color    = Color(0.12, 0.11, 0.16, 1.0)
const C_PANEL_BG: Color   = Color(0.18, 0.17, 0.24, 0.95)
const C_PANEL_BRD: Color  = Color(0.85, 0.80, 0.70, 0.80)
const C_SAFE: Color       = Color(0.96, 0.64, 0.38)
const C_DANGER: Color     = Color(0.85, 0.28, 0.28)
const C_CALM: Color       = Color(0.28, 0.55, 0.75)
const C_BREATH: Color     = Color(0.96, 0.87, 0.70)
const C_TEXT_MAIN: Color  = Color(0.95, 0.93, 0.88)
const C_TEXT_MUTED: Color = Color(0.60, 0.58, 0.66)

# ── Game state ─────────────────────────────────────────────────────────────
enum State { IDLE, PLAYING, TRANSITION, GAME_OVER }
var state: State = State.IDLE

var bpm: float = BPM_START
var score: float = 0.0
var lives: int = MAX_LIVES
var level: int = 1
var elapsed: float = 0.0
var danger_time: float = 0.0
var level_timer: float = 0.0
var spawn_timer: float = 0.0
var breath_flash: float = 0.0
var ball_y: float = 0.0
var shake_amt: float = 0.0
var fade_alpha: float = 0.0
var fade_rect: ColorRect   # pure black, above the whole HUD
var ending: bool = false

var stressors: Array[Dictionary] = []
var particles: Array[Dictionary] = []
var breath_particles: Array[Dictionary] = []

var _pill_style: StyleBoxFlat

# Audio
var sfx_streams: Dictionary = {}
var sfx_voices: Dictionary = {}     # one player per sound: it can never stack on itself
var sfx_last_time: Dictionary = {}
var music_streams: Array[AudioStream] = []
var music_player: AudioStreamPlayer
var music_tween: Tween
var current_music: int = -1
var music_enabled: bool = false
var beat_timer: float = 0.0
var tick_timer: float = 0.0

# Textures from res://assets (all optional - the game falls back to drawn shapes)
var tex_heart: Texture2D
var tex_safe: Texture2D
var tex_danger: Texture2D
var tex_breath: Texture2D
var tex_deadline: Texture2D

# ── HUD nodes ──────────────────────────────────────────────────────────────
var hud_layer: CanvasLayer
var lbl_bpm: Label
var lbl_score: Label
var lbl_level: Label
var hearts_ctrl: Control
var lbl_msg: Label
var header_box: MarginContainer
var timer_panel: PanelContainer
var lbl_timer: Label
var lbl_chapter_name: Label
var overlay: ColorRect
var center_box: VBoxContainer
var lbl_title: Label
var lbl_sub: Label
var inst_panel: PanelContainer
var btn_start: Button

# ── Initialization ─────────────────────────────────────────────────────────
func _ready() -> void:
	randomize()
	# Always fit the 2400x1350 design into whatever window size we are given
	var win := get_window()
	win.content_scale_size = Vector2i(SCREEN_W, SCREEN_H)
	win.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	win.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_KEEP
	_fit_window_to_screen(win)
	RenderingServer.set_default_clear_color(C_BG_DARK)
	tex_heart = _load_tex("res://assets/heart.svg")
	tex_safe = _load_tex("res://assets/icon_safe.svg")
	tex_danger = _load_tex("res://assets/icon_danger.svg")
	tex_breath = _load_tex("res://assets/icon_breath.svg")
	tex_deadline = _load_tex("res://assets/stressor_deadline.svg")
	_pill_style = StyleBoxFlat.new()
	_pill_style.set_corner_radius_all(32)
	_pill_style.anti_aliasing = false
	ball_y = bpm_to_y(BPM_START)
	_setup_ui()
	_setup_fade()
	_layout_hud()
	get_viewport().size_changed.connect(_layout_hud)
	_setup_audio()
	_show_title()
	queue_redraw()

## The design resolution is 2400x1350, but the real window must never be bigger
## than the monitor (that is what made the right/bottom of the UI get cut off).
func _fit_window_to_screen(win: Window) -> void:
	if Engine.is_embedded_in_editor() or win.mode != Window.MODE_WINDOWED:
		return
	var usable := DisplayServer.screen_get_usable_rect().size
	if usable.x <= 0 or usable.y <= 0:
		return
	var k := minf(float(usable.x) * 0.95 / float(win.size.x), float(usable.y) * 0.90 / float(win.size.y))
	if k < 1.0:
		win.size = Vector2i(int(float(win.size.x) * k), int(float(win.size.y) * k))
		win.move_to_center()

func _load_tex(path: String) -> Texture2D:
	if ResourceLoader.exists(path):
		return load(path) as Texture2D
	return null

func _setup_ui() -> void:
	hud_layer = CanvasLayer.new()
	add_child(hud_layer)

	# Header cards (top-left)
	var header := MarginContainer.new()
	header_box = header
	header.mouse_filter = Control.MOUSE_FILTER_IGNORE
	header.add_theme_constant_override("margin_left", HUD_MARGIN)
	header.add_theme_constant_override("margin_top", HUD_MARGIN)
	hud_layer.add_child(header)

	var hbox := HBoxContainer.new()
	hbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hbox.add_theme_constant_override("separation", 24)
	header.add_child(hbox)

	lbl_bpm = _create_hud_card(hbox, "HEART RATE", "72 BPM", C_SAFE, 260)
	lbl_score = _create_hud_card(hbox, "MEMORIES", "0", C_TEXT_MAIN, 240)
	_create_hearts_card(hbox, "FOCUS", 250)
	lbl_level = _create_hud_card(hbox, "CHAPTER", "1", C_TEXT_MAIN, 200)

	# Bottom hint
	lbl_msg = Label.new()
	lbl_msg.text = "Press Begin to take a breath"
	lbl_msg.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl_msg.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lbl_msg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	lbl_msg.add_theme_font_size_override("font_size", 34)
	lbl_msg.add_theme_color_override("font_color", C_TEXT_MUTED)
	hud_layer.add_child(lbl_msg)

	# Chapter + countdown card, pinned to the top-right corner
	timer_panel = PanelContainer.new()
	timer_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	timer_panel.custom_minimum_size = Vector2(560, 104)
	var tstyle := _card_style()
	tstyle.content_margin_left = 28
	tstyle.content_margin_right = 28
	tstyle.content_margin_top = 12
	tstyle.content_margin_bottom = 12
	timer_panel.add_theme_stylebox_override("panel", tstyle)
	timer_panel.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	hud_layer.add_child(timer_panel)

	var tvb := VBoxContainer.new()
	tvb.alignment = BoxContainer.ALIGNMENT_CENTER
	tvb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	timer_panel.add_child(tvb)

	lbl_timer = Label.new()
	lbl_timer.text = "CHAPTER 1  —  00:30"
	lbl_timer.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	lbl_timer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lbl_timer.custom_minimum_size = Vector2(470, 0)
	lbl_timer.autowrap_mode = TextServer.AUTOWRAP_OFF
	lbl_timer.clip_text = false
	lbl_timer.text_overrun_behavior = TextServer.OVERRUN_NO_TRIMMING
	lbl_timer.add_theme_font_size_override("font_size", 38)
	lbl_timer.add_theme_color_override("font_color", C_TEXT_MAIN)
	tvb.add_child(lbl_timer)

	lbl_chapter_name = Label.new()
	lbl_chapter_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	lbl_chapter_name.add_theme_font_size_override("font_size", 22)
	lbl_chapter_name.add_theme_color_override("font_color", C_TEXT_MUTED)
	tvb.add_child(lbl_chapter_name)
	timer_panel.visible = false

	# Overlay (title / how to play / chapter cards / end screens)
	overlay = ColorRect.new()
	overlay.color = Color(0.08, 0.07, 0.11, 0.92)
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	hud_layer.add_child(overlay)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.add_child(center)

	center_box = VBoxContainer.new()
	center_box.alignment = BoxContainer.ALIGNMENT_CENTER
	center_box.custom_minimum_size = Vector2(760, 0)
	center_box.add_theme_constant_override("separation", 18)
	center.add_child(center_box)

	lbl_title = Label.new()
	lbl_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl_title.add_theme_font_size_override("font_size", 64)
	center_box.add_child(lbl_title)

	lbl_sub = Label.new()
	lbl_sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl_sub.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	lbl_sub.add_theme_font_size_override("font_size", 26)
	center_box.add_child(lbl_sub)

	# "How to play" modal panel
	inst_panel = PanelContainer.new()
	var inst_style := StyleBoxFlat.new()
	inst_style.bg_color = Color(0.08, 0.07, 0.11, 0.7)
	inst_style.border_color = C_PANEL_BRD
	inst_style.set_border_width_all(2)
	inst_style.content_margin_left = 28
	inst_style.content_margin_right = 28
	inst_style.content_margin_top = 16
	inst_style.content_margin_bottom = 16
	inst_panel.add_theme_stylebox_override("panel", inst_style)
	center_box.add_child(inst_panel)

	var inst_lbl := Label.new()
	inst_lbl.text = "HOW TO PLAY\n\n" \
		+ "• CONTROLS: Press or spam the SPACEBAR to exhale and drop your heart rate.\n" \
		+ "• OBJECTIVE: Keep your heart rate within the Golden Hour (60–100 BPM).\n" \
		+ "• DODGE: Dodge incoming stressors that track your height.\n" \
		+ "• THOUGHTS: Self-doubt, social media and class stress all raise your heart rate.\n" \
		+ "• SURVIVE: Get through Quiet Morning, Before Class and After Class. Lose all 3 hearts and focus is lost."
	inst_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	inst_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	inst_lbl.custom_minimum_size = Vector2(700, 0)
	inst_lbl.add_theme_font_size_override("font_size", 22)
	inst_lbl.add_theme_color_override("font_color", C_TEXT_MAIN)
	inst_panel.add_child(inst_lbl)

	btn_start = Button.new()
	btn_start.text = "Begin"
	btn_start.custom_minimum_size = Vector2(320, 76)
	btn_start.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	btn_start.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	btn_start.add_theme_font_size_override("font_size", 34)
	btn_start.add_theme_color_override("font_color", C_TEXT_MAIN)
	btn_start.add_theme_color_override("font_hover_color", C_BG_DARK)

	var btn_normal := StyleBoxFlat.new()
	btn_normal.bg_color = C_PANEL_BG
	btn_normal.border_color = C_PANEL_BRD
	btn_normal.set_border_width_all(4)
	btn_normal.set_corner_radius_all(0)
	btn_normal.anti_aliasing = false
	var btn_hover := btn_normal.duplicate() as StyleBoxFlat
	btn_hover.bg_color = C_SAFE
	btn_hover.border_color = C_TEXT_MAIN
	var btn_pressed := btn_normal.duplicate() as StyleBoxFlat
	btn_pressed.bg_color = C_DANGER

	btn_start.add_theme_stylebox_override("normal", btn_normal)
	btn_start.add_theme_stylebox_override("hover", btn_hover)
	btn_start.add_theme_stylebox_override("pressed", btn_pressed)
	btn_start.add_theme_stylebox_override("focus", btn_hover)
	btn_start.pressed.connect(_on_start_pressed)
	center_box.add_child(btn_start)

# ── Audio ──────────────────────────────────────────────────────────────────
func _setup_audio() -> void:
	for key in SFX_PATHS:
		var st := _load_audio(SFX_PATHS[key] as String)
		if st != null:
			sfx_streams[key] = st
	for key in sfx_streams:
		var pl := AudioStreamPlayer.new()
		add_child(pl)
		sfx_voices[key] = pl
	_add_master_limiter()

	for path in MUSIC_PATHS:
		var ms := _load_audio(path)
		if ms != null:
			_make_loop(ms)
			music_streams.append(ms)
	music_player = AudioStreamPlayer.new()
	music_player.volume_db = -40.0
	music_player.finished.connect(_on_music_finished)
	add_child(music_player)

func _load_audio(path: String) -> AudioStream:
	if ResourceLoader.exists(path):
		return load(path) as AudioStream
	return null

func _make_loop(st: AudioStream) -> void:
	var w := st as AudioStreamWAV
	if w == null or w.format != AudioStreamWAV.FORMAT_16_BITS:
		return
	var bytes_per_frame := 4 if w.stereo else 2
	w.loop_mode = AudioStreamWAV.LOOP_FORWARD
	w.loop_begin = 0
	w.loop_end = int(w.data.size() / bytes_per_frame)

func _on_music_finished() -> void:
	# Fallback loop in case the stream itself was not set to loop
	if music_enabled and current_music >= 0:
		music_player.play()

## Safety net: a limiter on the master bus so nothing can ever get loud
func _add_master_limiter() -> void:
	if AudioServer.get_bus_effect_count(0) > 0:
		return
	var cls := "AudioEffectHardLimiter" if ClassDB.class_exists("AudioEffectHardLimiter") else "AudioEffectLimiter"
	var fx := ClassDB.instantiate(cls) as AudioEffect
	if fx == null:
		return
	fx.set("ceiling_db", -6.0)
	AudioServer.add_bus_effect(0, fx)
	AudioServer.set_bus_volume_db(0, -2.0)

## Anti-spam rules: (1) each sound has one voice, so a new play replaces the old one
## instead of stacking, (2) a minimum gap between plays, (3) a hard volume ceiling.
func _sfx(key: String, vol_db: float = 0.0, pitch: float = 1.0) -> void:
	if not sfx_streams.has(key) or not sfx_voices.has(key):
		return
	var now := Time.get_ticks_msec() / 1000.0
	var min_gap := float(SFX_MIN_INTERVAL.get(key, 0.05))
	if now - float(sfx_last_time.get(key, -10.0)) < min_gap:
		return
	sfx_last_time[key] = now
	var player := sfx_voices[key] as AudioStreamPlayer
	player.stop()
	player.stream = sfx_streams[key] as AudioStream
	player.volume_db = minf(vol_db, SFX_MAX_DB)
	player.pitch_scale = pitch
	player.play()

func _play_music(idx: int, vol_db: float = MUSIC_DB) -> void:
	if music_streams.is_empty():
		return
	idx = clampi(idx, 0, music_streams.size() - 1)
	music_enabled = true
	if idx != current_music or not music_player.playing:
		music_player.stream = music_streams[idx]
		music_player.volume_db = -40.0
		music_player.play()
		current_music = idx
	if music_tween:
		music_tween.kill()
	music_tween = create_tween()
	music_tween.tween_property(music_player, "volume_db", vol_db, 1.2)

func _stop_music(fade: float = 1.0) -> void:
	if music_player == null:
		return
	music_enabled = false
	current_music = -1
	if music_tween:
		music_tween.kill()
	music_tween = create_tween()
	music_tween.tween_property(music_player, "volume_db", -40.0, fade)
	music_tween.tween_callback(music_player.stop)

func _setup_fade() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 100
	add_child(layer)
	fade_rect = ColorRect.new()
	fade_rect.color = Color(0, 0, 0, 1)
	fade_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fade_rect.modulate.a = 0.0
	layer.add_child(fade_rect)
	fade_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

func _fade_to(alpha: float, duration: float) -> void:
	var tw := create_tween()
	tw.tween_property(fade_rect, "modulate:a", alpha, duration) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	await tw.finished

func _card_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = C_PANEL_BG
	style.border_color = C_PANEL_BRD
	style.set_border_width_all(4)
	style.set_corner_radius_all(0)
	style.anti_aliasing = false
	style.content_margin_left = 20
	style.content_margin_top = 10
	style.content_margin_right = 20
	style.content_margin_bottom = 10
	return style

## Re-anchors the HUD to the current viewport (called at start and on resize)
func _layout_hud() -> void:
	if header_box == null or timer_panel == null:
		return
	header_box.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	timer_panel.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT, Control.PRESET_MODE_MINSIZE, HUD_MARGIN)
	timer_panel.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	lbl_msg.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	lbl_msg.offset_top = -112.0
	lbl_msg.offset_bottom = -64.0
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

func _make_card_panel(parent: Control, min_w: float) -> VBoxContainer:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(min_w, 104)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := StyleBoxFlat.new()
	style.bg_color = C_PANEL_BG
	style.border_color = C_PANEL_BRD
	style.set_border_width_all(4)
	style.set_corner_radius_all(0)
	style.anti_aliasing = false
	style.content_margin_left = 20
	style.content_margin_top = 12
	style.content_margin_right = 20
	style.content_margin_bottom = 12
	panel.add_theme_stylebox_override("panel", style)
	parent.add_child(panel)

	var vb := VBoxContainer.new()
	vb.alignment = BoxContainer.ALIGNMENT_CENTER
	vb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(vb)
	return vb

func _create_hud_card(parent: Control, title: String, val_str: String, accent: Color, min_w: float) -> Label:
	var vb := _make_card_panel(parent, min_w)
	var cap := Label.new()
	cap.text = title
	cap.add_theme_font_size_override("font_size", 20)
	cap.add_theme_color_override("font_color", C_TEXT_MUTED)
	vb.add_child(cap)

	var val := Label.new()
	val.text = val_str
	val.add_theme_font_size_override("font_size", 44)
	val.add_theme_color_override("font_color", accent)
	vb.add_child(val)
	return val

func _create_hearts_card(parent: Control, title: String, min_w: float) -> void:
	var vb := _make_card_panel(parent, min_w)
	var cap := Label.new()
	cap.text = title
	cap.add_theme_font_size_override("font_size", 20)
	cap.add_theme_color_override("font_color", C_TEXT_MUTED)
	vb.add_child(cap)

	# Pixel-art hearts drawn by a small Control (no font glyph dependency)
	hearts_ctrl = Control.new()
	hearts_ctrl.custom_minimum_size = Vector2(190, 44)
	hearts_ctrl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hearts_ctrl.draw.connect(_draw_hearts)
	vb.add_child(hearts_ctrl)

func _draw_hearts() -> void:
	if tex_heart != null:
		for i in range(MAX_LIVES):
			var tint := Color.WHITE if i < lives else Color(1, 1, 1, 0.15)
			hearts_ctrl.draw_texture_rect(tex_heart,
				Rect2(float(i) * 60.0, 0.0, 44.0, 44.0), false, tint)
		return
	var heart_w := HEART_PATTERN[0].length() * HEART_PX
	for i in range(MAX_LIVES):
		var col := C_DANGER if i < lives else Color(1, 1, 1, 0.12)
		var ox := float(i) * (heart_w + 18.0)
		for row in range(HEART_PATTERN.size()):
			var line: String = HEART_PATTERN[row]
			for c in range(line.length()):
				if line[c] == "1":
					hearts_ctrl.draw_rect(
						Rect2(ox + c * HEART_PX, 4.0 + row * HEART_PX, HEART_PX, HEART_PX), col)

# ── Screens ────────────────────────────────────────────────────────────────
func _show_title() -> void:
	state = State.IDLE
	overlay.visible = true
	overlay.color = Color(0.08, 0.07, 0.11, 0.92)
	inst_panel.visible = true
	btn_start.visible = true
	lbl_title.text = "Breathing Space"
	lbl_sub.text = "Avoid the noise  •  Press SPACE to exhale  •  Keep your heart rate steady"
	lbl_title.add_theme_color_override("font_color", C_SAFE)
	lbl_sub.add_theme_color_override("font_color", C_TEXT_MUTED)
	lbl_msg.text = "Press Begin to take a breath"
	lbl_msg.add_theme_color_override("font_color", C_TEXT_MUTED)
	_play_music(0, MUSIC_TITLE_DB)
	timer_panel.visible = false

func _show_message(title: String, sub: String, title_color: Color) -> void:
	overlay.visible = true
	inst_panel.visible = false
	btn_start.visible = false
	lbl_title.text = title
	lbl_sub.text = sub
	lbl_title.add_theme_color_override("font_color", title_color)
	lbl_sub.add_theme_color_override("font_color", C_TEXT_MUTED)

# ── Input ──────────────────────────────────────────────────────────────────
func _is_space_press(event: InputEvent) -> bool:
	if event is InputEventKey:
		var ke := event as InputEventKey
		return ke.pressed and not ke.echo \
			and (ke.keycode == KEY_SPACE or ke.physical_keycode == KEY_SPACE)
	return false

func _input(event: InputEvent) -> void:
	if not _is_space_press(event):
		return
	if state == State.IDLE and btn_start.visible:
		get_viewport().set_input_as_handled()
		_on_start_pressed()
	elif state == State.PLAYING:
		get_viewport().set_input_as_handled()
		_do_breathe()   # no cooldown: every press counts

# ── Process ────────────────────────────────────────────────────────────────
func _process(delta: float) -> void:
	shake_amt = lerpf(shake_amt, 0.0, minf(delta * 8.0, 1.0))
	if state == State.PLAYING:
		_update_game(delta)
	if state != State.IDLE:
		_update_hud()
	queue_redraw()

func _update_game(delta: float) -> void:
	elapsed += delta
	breath_flash = maxf(0.0, breath_flash - delta)
	level_timer += delta
	spawn_timer += delta

	# Chapter / win handling
	if level_timer >= _chapter_duration():
		level_timer = 0.0
		if level >= MAX_LEVELS:
			_win_game()
		else:
			level += 1
			_show_level_transition()
		return

	# Stressor spawning (faster each chapter)
	var spawn_rate := float(_cp()["spawn"])
	if spawn_timer >= spawn_rate:
		spawn_timer = 0.0
		_spawn_stressor()
		# Later chapters throw in extra thoughts at the same time
		if randf() < float(_cp()["double"]):
			_spawn_stressor(randf_range(140.0, 340.0))

	# Passive drift toward baseline + gentle wobble
	bpm += (BPM_BASELINE - bpm) * 0.4 * delta
	bpm += float(_cp()["pressure"]) * delta
	bpm += sin(elapsed * 3.1) * (0.4 + 0.3 * float(level)) * delta

	# Ball follows BPM smoothly (frame-rate independent)
	ball_y = lerpf(ball_y, bpm_to_y(bpm), 1.0 - exp(-10.0 * delta))

	# Stressors: move + collide
	for s in stressors:
		s["x"] = float(s["x"]) + float(s["vx"]) * delta * 60.0
		if float(s["flash"]) > 0.0:
			s["flash"] = float(s["flash"]) - delta * 3.0
		if not bool(s["hit"]):
			var dx := absf(BALL_X - float(s["x"]))
			var dy := absf(ball_y - float(s["y"]))
			if dx < float(s["w"]) * 0.5 + BALL_RADIUS and dy < float(s["h"]) * 0.5 + BALL_RADIUS:
				s["hit"] = true
				s["flash"] = 1.0
				bpm += float(s["bpm_hit"]) * float(_cp()["hit"])
				shake_amt = 25.0
				_sfx("hit", -9.0, randf_range(0.95, 1.05))
				_spawn_particles(Vector2(BALL_X, ball_y), s["color"] as Color, 18)

	stressors = stressors.filter(func(s: Dictionary) -> bool:
		return float(s["x"]) > -float(s["w"]) - 10.0)

	# Particles
	for p in particles:
		var vel := p["vel"] as Vector2
		p["pos"] = (p["pos"] as Vector2) + vel * delta * 60.0
		p["vel"] = Vector2(vel.x, vel.y + 0.15)
		p["life"] = float(p["life"]) - delta * 1.5
	particles = particles.filter(func(p: Dictionary) -> bool: return float(p["life"]) > 0.0)

	for p in breath_particles:
		p["pos"] = (p["pos"] as Vector2) + (p["vel"] as Vector2) * delta * 60.0
		p["life"] = float(p["life"]) - delta * 2.5
	breath_particles = breath_particles.filter(func(p: Dictionary) -> bool: return float(p["life"]) > 0.0)

	# Heartbeat sound follows your BPM
	beat_timer -= delta
	if beat_timer <= 0.0:
		beat_timer += 60.0 / maxf(bpm, 30.0)
		_sfx("heartbeat", clampf(-24.0 + (bpm - 60.0) * 0.08, -26.0, -14.0), clampf(0.9 + bpm / 600.0, 0.95, 1.15))

	# Danger meter
	if bpm > SAFE_MAX or bpm < SAFE_MIN:
		tick_timer -= delta
		if tick_timer <= 0.0:
			tick_timer = lerpf(0.55, 0.22, minf(danger_time / _danger_limit(), 1.0))
			_sfx("danger_tick", -20.0)
		danger_time += delta
		shake_amt = minf(shake_amt + delta * 5.0, 8.0)
		if danger_time >= _danger_limit():
			lives -= 1
			_sfx("life_lost", -10.0)
			danger_time = 0.0
			bpm = BPM_BASELINE
			shake_amt = 40.0
			if hearts_ctrl:
				hearts_ctrl.queue_redraw()
			if lives <= 0:
				_end_game()
				return
	else:
		tick_timer = 0.0
		danger_time = maxf(0.0, danger_time - delta * 0.8)
		score += delta * (10.0 + float(level) * 3.0)

	bpm = clampf(bpm, BPM_MIN, BPM_MAX)

	# Status hint at the bottom of the screen
	if bpm > SAFE_MAX:
		lbl_msg.text = "Heart rate too tense  -  press SPACE to exhale"
		lbl_msg.add_theme_color_override("font_color", C_DANGER)
	elif bpm < SAFE_MIN:
		lbl_msg.text = "Heart rate too low  -  stop exhaling and let it settle"
		lbl_msg.add_theme_color_override("font_color", C_CALM)
	else:
		lbl_msg.text = "Press SPACE to exhale."
		lbl_msg.add_theme_color_override("font_color", C_TEXT_MUTED)

# ── Drawing ────────────────────────────────────────────────────────────────
func _draw() -> void:
	var shake_offset := Vector2(randf_range(-shake_amt, shake_amt), randf_range(-shake_amt, shake_amt))
	draw_set_transform(shake_offset, 0.0, Vector2.ONE)
	_draw_rect_full(C_BG_DARK)
	if state != State.IDLE:
		_draw_playing()
	_draw_scanlines()
	if fade_alpha > 0.0:
		_draw_rect_full(Color(0.08, 0.07, 0.11, fade_alpha))

func _draw_rect_full(c: Color) -> void:
	draw_rect(Rect2(-50, -50, SCREEN_W + 100, SCREEN_H + 100), c)

func _draw_scanlines() -> void:
	var y := 0
	while y < SCREEN_H:
		draw_rect(Rect2(-50, y, SCREEN_W + 100, 2), Color(0, 0, 0, float(_cp()["scan"])))
		y += 6

func _draw_pixel_heart(center: Vector2, px: float, col: Color) -> void:
	var cols := HEART_PATTERN[0].length()
	var origin := center - Vector2(float(cols) * px, float(HEART_PATTERN.size()) * px) * 0.5
	for row in range(HEART_PATTERN.size()):
		var line: String = HEART_PATTERN[row]
		for c in range(cols):
			if line[c] == "1":
				var rc := Rect2(origin + Vector2(float(c), float(row)) * px, Vector2(px + 0.6, px + 0.6))
				draw_rect(rc, C_TEXT_MAIN if (row == 1 and c == 1) else col)

func _zone_color() -> Color:
	if bpm > SAFE_MAX:
		return C_DANGER
	if bpm < SAFE_MIN:
		return C_CALM
	return C_SAFE

func _draw_playing() -> void:
	var prof := _cp()
	_draw_rect_full(Color(prof["tint"] as Color, 0.06))
	var vig := float(prof["vignette"])
	if vig > 0.0:
		var pulse_v := 0.65 + 0.35 * sin(elapsed * 6.0)
		for i in range(6):
			var a := vig * (1.0 - float(i) / 6.0) * pulse_v
			var wdt := 14.0 * float(6 - i)
			draw_rect(Rect2(0, 0, wdt, SCREEN_H), Color(C_DANGER, a))
			draw_rect(Rect2(SCREEN_W - wdt, 0, wdt, SCREEN_H), Color(C_DANGER, a))
	var safe_top := bpm_to_y(SAFE_MAX)
	var safe_bot := bpm_to_y(SAFE_MIN)
	var font := ThemeDB.fallback_font
	var in_danger := bpm > SAFE_MAX or bpm < SAFE_MIN

	# Faint grid
	for i in range(25):
		var gy := PLAY_TOP + float(i) * (PLAY_BOT - PLAY_TOP) / 24.0
		draw_line(Vector2(0, gy), Vector2(SCREEN_W, gy), Color(1, 1, 1, 0.02), 2.0)

	# Zones
	draw_rect(Rect2(0, PLAY_TOP, SCREEN_W, safe_top - PLAY_TOP), Color(C_DANGER, 0.05))
	draw_rect(Rect2(0, safe_bot, SCREEN_W, PLAY_BOT - safe_bot), Color(C_CALM, 0.05))
	draw_rect(Rect2(0, safe_top, SCREEN_W, safe_bot - safe_top), Color(C_SAFE, 0.08))
	draw_line(Vector2(0, safe_top), Vector2(SCREEN_W, safe_top), Color(C_SAFE, 0.4), 4.0)
	draw_line(Vector2(0, safe_bot), Vector2(SCREEN_W, safe_bot), Color(C_SAFE, 0.4), 4.0)


	# Danger flash
	if in_danger and danger_time > 0.0:
		var flash_a := absf(sin(elapsed * 12.0)) * 0.08 * minf(danger_time, 1.0)
		_draw_rect_full(Color(C_DANGER, flash_a))

	# Heartbeat wave
	var wave_color := Color(_zone_color(), 0.8)
	var base_y := bpm_to_y(bpm)
	var pts := PackedVector2Array()
	for xi in range(0, SCREEN_W + 8, 8):
		var t := float(xi) / float(SCREEN_W) * 4.0 + elapsed * 2.0
		var spike := exp(-pow((fmod(t, 2.0) - 1.0) * 5.0, 2.0)) * 90.0
		pts.append(Vector2(float(xi), base_y - spike))
	draw_polyline(pts, wave_color, 6.0)

	# Stressor pills
	for s in stressors:
		var sx := float(s["x"])
		var sy := float(s["y"])
		var sw := float(s["w"])
		var sh := float(s["h"])
		var rect := Rect2(sx - sw * 0.5, sy - sh * 0.5, sw, sh)
		var flash := float(s["flash"]) > 0.0

		_pill_style.bg_color = Color(0, 0, 0, 0.45)
		draw_style_box(_pill_style, Rect2(rect.position + Vector2(8, 8), rect.size))
		_pill_style.bg_color = C_TEXT_MAIN if flash else (s["color"] as Color)
		draw_style_box(_pill_style, rect)

		var lbl := s["label"] as String
		var lw := font.get_string_size(lbl, HORIZONTAL_ALIGNMENT_LEFT, -1, 26).x
		var txt_col := C_BG_DARK if flash else C_TEXT_MAIN
		var text_off := 0.0
		if String(s["icon"]) == "deadline" and tex_deadline != null:
			draw_texture_rect(tex_deadline, Rect2(rect.position.x + 14.0, sy - 20.0, 40.0, 40.0), false)
			text_off = 22.0
		draw_string(font, Vector2(sx - lw * 0.5 + text_off, sy + 9), lbl,
			HORIZONTAL_ALIGNMENT_LEFT, -1, 26, txt_col)
		# Small theme tag above the pill (Self / Social Media / Class)
		var tag := String(THEMES[int(s["theme"])]["name"])
		draw_string(font, Vector2(rect.position.x + 14.0, rect.position.y - 8.0), tag,
			HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color((s["color"] as Color).lightened(0.35), 0.95))

	# Breath particles (soft, cream)
	for p in breath_particles:
		var lf := float(p["life"])
		var size := 18.0 * lf
		draw_rect(Rect2((p["pos"] as Vector2) - Vector2(size, size) * 0.5, Vector2(size, size)),
			Color(C_BREATH, lf * 0.6))

	# Impact particles (square pixels)
	for p in particles:
		var lf := float(p["life"])
		var size := 24.0 * lf
		draw_rect(Rect2((p["pos"] as Vector2) - Vector2(size, size) * 0.5, Vector2(size, size)),
			Color(p["color"] as Color, lf))

	# Player avatar
	var pulse := sin(elapsed * (bpm / 20.0)) * 6.0
	var r := BALL_RADIUS + pulse
	var core := Rect2(Vector2(BALL_X, ball_y) - Vector2(r, r), Vector2(r * 2.0, r * 2.0))
	draw_rect(core, _zone_color())
	draw_rect(core, C_TEXT_MAIN, false, 4.0)
	# Beating pixel heart sized to fit inside the avatar box
	var beat := 1.0 + 0.18 * maxf(0.0, sin(elapsed * (bpm / 20.0)))
	var heart_px := (r * 2.0 * 0.6 / float(HEART_PATTERN[0].length())) * beat
	_draw_pixel_heart(Vector2(BALL_X, ball_y), heart_px, C_BG_DARK)

	# Status icon above the avatar (calm / danger) and a quick flash when you exhale
	var status_tex := tex_safe
	if in_danger:
		status_tex = tex_danger
	if status_tex != null:
		draw_texture_rect(status_tex, Rect2(BALL_X - 20.0, ball_y - r - 56.0, 40.0, 40.0), false)
	if tex_breath != null and breath_flash > 0.0:
		draw_texture_rect(tex_breath, Rect2(BALL_X + r + 14.0, ball_y - 20.0, 40.0, 40.0),
			false, Color(1, 1, 1, breath_flash / BREATH_FLASH_TIME))

	# Danger meter (bottom)
	if in_danger and danger_time > 0.0:
		var dprog := minf(danger_time / _danger_limit(), 1.0)
		var bar_w := float(SCREEN_W - 120)
		draw_rect(Rect2(60, SCREEN_H - 60, bar_w, 16), Color(0, 0, 0, 0.5))
		draw_rect(Rect2(60, SCREEN_H - 60, bar_w * dprog, 16), C_DANGER)
		draw_rect(Rect2(60, SCREEN_H - 60, bar_w, 16), C_PANEL_BRD, false, 4.0)

	# Zone labels last, so stressors and the avatar never hide them
	_draw_zone_chip("TOO TENSE", Vector2(30.0, safe_top - 64.0), C_DANGER, bpm > SAFE_MAX)
	_draw_zone_chip("TOO LOW", Vector2(30.0, safe_bot + 16.0), C_CALM, bpm < SAFE_MIN)

func _draw_zone_chip(text: String, pos: Vector2, col: Color, active: bool) -> void:
	var font := ThemeDB.fallback_font
	var fs := 30
	var tw := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	var rect := Rect2(pos, Vector2(tw + 36.0, 48.0))
	draw_rect(rect, Color(C_BG_DARK, 0.9))
	if active:
		draw_rect(rect, Color(col, 0.35))
	draw_rect(rect, Color(col, 1.0 if active else 0.7), false, 3.0)
	draw_string(font, pos + Vector2(18.0, 34.0), text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs,
		Color(col.lightened(0.35), 1.0 if active else 0.9))

# ── Gameplay helpers ───────────────────────────────────────────────────────
func bpm_to_y(b: float) -> float:
	var center_y := (PLAY_TOP + PLAY_BOT) * 0.5
	var half_span := (PLAY_BOT - PLAY_TOP) * 0.5
	var t := (b - 80.0) / 70.0
	return clampf(center_y - t * half_span, PLAY_TOP, PLAY_BOT)

func _do_breathe() -> void:
	bpm = maxf(BPM_MIN + 2.0, bpm - randf_range(EXHALE_DROP_MIN, EXHALE_DROP_MAX))
	breath_flash = BREATH_FLASH_TIME
	_sfx("exhale", -12.0, randf_range(0.95, 1.05))
	shake_amt = maxf(shake_amt, 2.0)
	for i in range(8):
		var angle := randf() * TAU
		var spd := 4.0 + randf() * 8.0
		breath_particles.append({
			"pos": Vector2(BALL_X, ball_y),
			"vel": Vector2(cos(angle) * spd, sin(angle) * spd),
			"life": 1.0,
		})

## Picks a stressor: the chapter decides how likely each theme is
func _pick_stressor() -> Dictionary:
	var weights: Array = _cp()["themes"]
	var roll := randf()
	var acc := 0.0
	var theme := weights.size() - 1
	for i in range(weights.size()):
		acc += float(weights[i])
		if roll <= acc:
			theme = i
			break
	var pool: Array[Dictionary] = []
	for t in STRESSOR_TYPES:
		if int(t["theme"]) == theme:
			pool.append(t)
	return pool[randi() % pool.size()]

func _spawn_stressor(x_offset: float = 0.0) -> void:
	var t: Dictionary = _pick_stressor()
	var spd := (float(_cp()["speed"]) + randf() * 0.6) * SPEED_SCALE

	# Chance to aim at the player's height depends on the chapter (60% / 70% / 82%)
	var spawn_y: float
	if randf() < float(_cp()["track"]):
		spawn_y = clampf(ball_y + randf_range(-100.0, 100.0), PLAY_TOP, PLAY_BOT)
	else:
		spawn_y = randf_range(PLAY_TOP, PLAY_BOT)

	stressors.append({
		"x": float(SCREEN_W) + float(t["w"]) + x_offset,
		"y": spawn_y,
		"vx": -spd,
		"label": t["label"],
		"color": THEMES[int(t["theme"])]["color"],
		"theme": t["theme"],
		"bpm_hit": t["bpm_hit"],
		"w": t["w"],
		"h": t["h"],
		"icon": t.get("icon", ""),
		"hit": false,
		"flash": 0.0,
	})

func _spawn_particles(pos: Vector2, color: Color, n: int) -> void:
	for i in range(n):
		var angle := TAU * float(i) / float(n) + randf() * 0.5
		var spd := 6.0 + randf() * 10.0
		particles.append({
			"pos": pos,
			"vel": Vector2(cos(angle) * spd, sin(angle) * spd),
			"life": 1.0,
			"color": color,
		})

## Per-chapter intensity profile
func _cp() -> Dictionary:
	return CHAPTERS[clampi(level - 1, 0, CHAPTERS.size() - 1)]

func _danger_limit() -> float:
	return float(_cp()["danger"])

func _chapter_duration() -> float:
	return float(_cp()["duration"])

func _reset() -> void:
	bpm = BPM_START
	ball_y = bpm_to_y(BPM_START)
	score = 0.0
	lives = MAX_LIVES
	level = 1
	elapsed = 0.0
	danger_time = 0.0
	level_timer = 0.0
	spawn_timer = 0.0
	breath_flash = 0.0
	beat_timer = 0.0
	tick_timer = 0.0
	shake_amt = 0.0
	fade_alpha = 0.0
	ending = false
	stressors.clear()
	particles.clear()
	breath_particles.clear()
	_update_hud()

func _update_hud() -> void:
	lbl_bpm.text = "%d BPM" % int(bpm)
	lbl_bpm.add_theme_color_override("font_color", _zone_color())
	lbl_score.text = str(int(score))
	lbl_level.text = str(level)
	var time_left := maxf(0.0, _chapter_duration() - level_timer)
	lbl_timer.text = "CHAPTER %d  —  00:%02d" % [level, int(ceil(time_left))]
	lbl_timer.add_theme_color_override("font_color", C_DANGER if time_left <= 5.0 else C_TEXT_MAIN)
	lbl_chapter_name.text = String(_cp()["name"])
	lbl_chapter_name.add_theme_color_override("font_color", _cp()["tint"] as Color)
	if hearts_ctrl:
		hearts_ctrl.queue_redraw()

# ── Flow ───────────────────────────────────────────────────────────────────
func _on_start_pressed() -> void:
	_reset()
	_sfx("ui_start", -10.0)
	timer_panel.visible = true
	_play_music(0)
	lbl_msg.text = "Press SPACE to exhale."
	_show_level_transition()   # opens with the "Quiet Morning" chapter card

# One run = three chapters, once. Win or lose, the screen fades straight to pitch
# black and stays black (no result screen, no menu drawn from this scene).
func _end_game() -> void:
	_end_sequence(false)

func _win_game() -> void:
	_end_sequence(true)

func _end_sequence(won: bool) -> void:
	if ending:
		return
	ending = true
	state = State.GAME_OVER
	_stop_music(2.5)
	_sfx("win" if won else "lose", -10.0)
	await _fade_to(1.0, 2.0)          # smooth fade to full black
	_finish(won)

func _show_level_transition() -> void:
	state = State.TRANSITION
	elapsed = 0.0
	bpm = BPM_START
	ball_y = bpm_to_y(BPM_START)
	danger_time = 0.0
	stressors.clear()
	_sfx("chapter_start", -10.0)
	_play_music(level - 1)
	_show_message("Chapter %d" % level, "%s\n%s" % [String(_cp()["name"]), String(_cp()["sub"])], C_TEXT_MAIN)
	await get_tree().create_timer(2.0).timeout
	overlay.visible = false
	state = State.PLAYING

func _finish(won: bool) -> void:
	minigame_finished.emit(won, int(score))
	# Screen is fully black here. If a menu scene is set, go there; otherwise stay black.
	if menu_scene_path != "":
		get_tree().change_scene_to_file(menu_scene_path)
