extends Node2D
# ═══════════════════════════════════════════════════════════════
#  SPOT & BREATHE  —  Godot 4.x
#  A calming hidden-object game following Mia through an anxiety
#  attack. She grounds herself by breathing and noticing details
#  in familiar, comforting places.
#  • 20 assets, 5 random targets per scene  (always visible)
#  • Items in the FIND LIST panel are actually clickable
#  • Breathing minigame → explore phase
#  • 3 hearts displayed large, timer bar, smooth fades
# ═══════════════════════════════════════════════════════════════

const SW : int = 800
const SH : int = 520
const TOP_H   : int = 52    # top bar (hearts + scene name)
const BOT_H   : int = 28    # bottom hint bar
const PANEL_W : int = 164   # right list panel
const PLAY_X2 : int = SW - PANEL_W   # 636
const PLAY_Y1 : int = TOP_H          # 52
const PLAY_Y2 : int = SH - BOT_H     # 492

# ── 1920×1080 output — uniform scale, horizontally centred ────
const WIN_W : int   = 1920
const WIN_H : int   = 1080
# Scale to fill height exactly; this gives 1662 logical-px wide,
# leaving (1920-1662)/2 = 129 px letterbox on each side.
const SCALE : float = float(WIN_H) / float(SH)          # ≈ 2.0769
var   OFS_X : float = (float(WIN_W) - float(SW) * SCALE) * 0.5

# ── Colours ────────────────────────────────────────────────────
var C_BG : Array = [
	Color(0.953, 0.922, 0.875),   # 0 Café
	Color(0.741, 0.855, 0.773),   # 1 Forest
	Color(0.886, 0.859, 0.820),   # 2 Library
]
var C_PANEL      := Color(0.10, 0.09, 0.08, 0.96)
var C_PANEL2     := Color(0.08, 0.06, 0.05, 0.97)
var C_GOLD       := Color(0.95, 0.80, 0.25)
var C_GREEN      := Color(0.22, 0.78, 0.38)
var C_WHITE      := Color(1.0,  1.0,  1.0)
var C_DIM        := Color(0.55, 0.55, 0.60)
var C_WRONG      := Color(0.90, 0.22, 0.20)
var C_HEART_ON   := Color(0.94, 0.16, 0.16)
var C_HEART_OFF  := Color(0.28, 0.22, 0.22)
var C_BLO        := Color(0.28, 0.55, 0.90)
var C_BHI        := Color(0.18, 0.86, 0.58)
var C_TIM_OK     := Color(0.22, 0.80, 0.40)
var C_TIM_WARN   := Color(0.96, 0.65, 0.14)
var C_TIM_CRIT   := Color(0.92, 0.20, 0.20)

# ── Phase enum ─────────────────────────────────────────────────
enum Phase { MENU, BREATH, EXPLORE }
var phase : Phase = Phase.MENU

# ── Fade state ─────────────────────────────────────────────────
var fade_alpha    : float    = 1.0
var fading_out    : bool     = false
var fading_in     : bool     = false
var fade_cb       : Callable
const FADE_OUT_SPD : float = 2.4
const FADE_IN_SPD  : float = 1.8

# ── Menu/overlay state ────────────────────────────────────────
var menu_visible  : bool   = true
var menu_title    : String = ""
var menu_sub      : String = ""
var menu_btn      : String = ""

# ═══════════════════════════════════════════════════════════════
#  ITEM POOL  (20 assets — coin and scroll removed)
# ═══════════════════════════════════════════════════════════════
const ALL_ASSETS : Array = [
	{ "id":"acorn",    "label":"Acorn"       },
	{ "id":"book",     "label":"Book"        },
	{ "id":"bottle",   "label":"Bottle"      },
	{ "id":"butterfly","label":"Butterfly"   },
	{ "id":"candle",   "label":"Candle"      },
	{ "id":"compass",  "label":"Compass"     },
	{ "id":"crown",    "label":"Crown"       },
	{ "id":"cup",      "label":"Coffee Mug"  },
	{ "id":"dice",     "label":"Dice"        },
	{ "id":"feather",  "label":"Feather"     },
	{ "id":"gem",      "label":"Blue Gem"    },
	{ "id":"glasses",  "label":"Glasses"     },
	{ "id":"inkwell",  "label":"Inkwell"     },
	{ "id":"key",      "label":"Old Key"     },
	{ "id":"lantern",  "label":"Lantern"     },
	{ "id":"mushroom", "label":"Mushroom"    },
	{ "id":"plant",    "label":"Potted Plant"},
	{ "id":"shell",    "label":"Seashell"    },
	{ "id":"teapot",   "label":"Teapot"      },
	{ "id":"watch",    "label":"Pocket Watch"},
]

var item_pool : Array = []

func _load_pool() -> void:
	item_pool.clear()
	for d : Dictionary in ALL_ASSETS:
		var path : String = "res://assets/item_%s.svg" % d["id"]
		item_pool.append({
			"id":    d["id"],
			"label": d["label"],
			"tex":   load(path) if ResourceLoader.exists(path) else null,
		})

# ═══════════════════════════════════════════════════════════════
#  SCENE DEFINITIONS  (3 scenes — Mia's grounding journey)
# ═══════════════════════════════════════════════════════════════
const SCENE_DEFS : Array = [
	{ "name":"Cosy Café",    "bg":0, "draw":"cafe"    },
	{ "name":"Quiet Forest", "bg":1, "draw":"forest"  },
	{ "name":"Old Library",  "bg":2, "draw":"library" },
]

# Mia's narrative for each scene transition
const SCENE_INTROS : Array = [
	# shown before scene 0 (first scene uses the main menu text instead)
	"",
	# shown after clearing scene 0, before scene 1
	"Mia steps outside.\nThe cool air helps. She finds a quiet path\nthrough the trees and breathes again.",
	# shown after clearing scene 1, before scene 2
	"Better. She slips into the old library —\nher favourite refuge. The smell of old paper\nalways brings her back to herself.",
]

# 10 item slots spread inside play area (center coords)
const SLOT_GRID : Array = [
	[  90, 110], [218,  90], [356,  80], [490,  95], [600,  80],
	[ 110, 260], [248, 285], [380, 270], [510, 280], [610, 255],
]

const ITEM_W    : int = 56
const ITEM_H    : int = 56
const NEED_FIND : int = 5
const TOTAL_PLY : int = 10

# ── Runtime scene state ───────────────────────────────────────
var scene_idx : int   = 0
var placed    : Array = []
var targets   : Array = []
var found     : Array = []

# ── Hearts & timer ────────────────────────────────────────────
var hearts     : int   = 3
var timer_left : float = 60.0
const TIMER_MAX : float = 60.0

# ── Breathing ─────────────────────────────────────────────────
var br_pos        : float = 0.0
var br_dir        : int   = 1
var br_holding    : bool  = false
var br_hold_t     : float = 0.0
var br_done       : int   = 0
var br_flash      : float = 0.0
var br_fail       : float = 0.0
const BR_SWEEP    : float = 3.33
const BR_ZS       : float = 0.33
const BR_ZE       : float = 0.67
const BR_NEEDED   : int   = 3
const BR_HOLD_MIN : float = 1.0

# ── Effects ───────────────────────────────────────────────────
var ripples     : Array = []
var wrong_flash : float = 0.0
var good_flash  : float = 0.0
var heart_pulse : float = 0.0

# ── HUD refs ──────────────────────────────────────────────────
var lbl_scene   : Label
var lbl_hint    : Label
var overlay     : ColorRect
var lbl_ov_t    : Label
var lbl_ov_s    : Label
var btn_action  : Button

# ═══════════════════════════════════════════════════════════════
func _ready() -> void:
	DisplayServer.window_set_size(Vector2i(WIN_W, WIN_H))
	# Disable Godot's built-in viewport stretch so our manual transform is the only scaling
	get_tree().root.content_scale_mode   = Window.CONTENT_SCALE_MODE_DISABLED
	get_tree().root.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_IGNORE
	OFS_X = (float(WIN_W) - float(SW) * SCALE) * 0.5
	_load_pool()
	_build_hud()
	_show_menu(
		"Spot & Breathe",
		"Mia feels her chest tighten — another anxiety attack.\n" +
		"She knows what to do: breathe, look around, find something\n" +
		"familiar. Help her come back to herself, one breath at a time.\n\n" +
		"Hold SPACE in the green zone · Find each listed item · 3 hearts",
		"Begin")

# ═══════════════════════════════════════════════════════════════
#  HUD
# ═══════════════════════════════════════════════════════════════
func _build_hud() -> void:
	var hud := CanvasLayer.new()
	hud.layer = 1
	# Scale the entire CanvasLayer to match draw transform
	hud.scale  = Vector2(SCALE, SCALE)
	hud.offset = Vector2(OFS_X, 0)
	add_child(hud)

	lbl_scene = _mk_lbl(hud, "", 13, 10, 14, 400, Color(0.88, 0.82, 0.68))

	var bot := ColorRect.new()
	bot.color    = Color(0, 0, 0, 0.68)
	bot.size     = Vector2(SW, BOT_H)
	bot.position = Vector2(0, SH - BOT_H)
	hud.add_child(bot)

	lbl_hint = _mk_lbl(hud, "", 12, 0, SH - BOT_H + 6, SW, Color(0.90, 0.86, 0.72))
	lbl_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

	var fl := CanvasLayer.new()
	fl.layer  = 10
	fl.scale  = Vector2(SCALE, SCALE)
	fl.offset = Vector2(OFS_X, 0)
	add_child(fl)

	overlay         = ColorRect.new()
	overlay.color   = Color(0, 0, 0, 1.0)
	# Extend left by letterbox amount (in logical coords) so it covers full 1920px
	var lb_logical : float = OFS_X / SCALE
	overlay.position = Vector2(-lb_logical, 0)
	overlay.size     = Vector2(SW + lb_logical * 2.0, SH)
	overlay.visible = true
	fl.add_child(overlay)

	lbl_ov_t = Label.new()
	lbl_ov_t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl_ov_t.position = Vector2(0, SH * 0.5 - 110)
	lbl_ov_t.size     = Vector2(SW, 64)
	lbl_ov_t.add_theme_font_size_override("font_size", 38)
	lbl_ov_t.add_theme_color_override("font_color", C_WHITE)
	fl.add_child(lbl_ov_t)

	lbl_ov_s = Label.new()
	lbl_ov_s.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl_ov_s.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	lbl_ov_s.position = Vector2(SW * 0.5 - 230, SH * 0.5 - 40)
	lbl_ov_s.size     = Vector2(460, 140)
	lbl_ov_s.add_theme_font_size_override("font_size", 15)
	lbl_ov_s.add_theme_color_override("font_color", Color(0.82, 0.80, 0.72))
	fl.add_child(lbl_ov_s)

	btn_action = Button.new()
	btn_action.custom_minimum_size   = Vector2(220, 52)
	btn_action.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	btn_action.add_theme_font_size_override("font_size", 18)
	btn_action.position = Vector2(SW * 0.5 - 110, SH * 0.5 + 104)
	btn_action.pressed.connect(_on_btn)
	fl.add_child(btn_action)

func _mk_lbl(parent: Node, text: String, size: int,
		x: float, y: float, w: float, col: Color) -> Label:
	var l := Label.new()
	l.text     = text
	l.position = Vector2(x, y)
	l.size     = Vector2(w, 26)
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", col)
	parent.add_child(l)
	return l

func _show_menu(title: String, sub: String, btn: String) -> void:
	menu_visible       = true
	lbl_ov_t.text      = title
	lbl_ov_s.text      = sub
	btn_action.text    = btn
	lbl_ov_t.visible   = true
	lbl_ov_s.visible   = true
	btn_action.visible = true
	overlay.visible    = true
	overlay.color      = Color(0, 0, 0, 1.0)
	fade_alpha         = 1.0

func _hide_menu() -> void:
	menu_visible       = false
	lbl_ov_t.visible   = false
	lbl_ov_s.visible   = false
	btn_action.visible = false

func _fade_out_then(cb: Callable) -> void:
	fading_out = true
	fading_in  = false
	fade_cb    = cb
	fade_alpha = 0.0

func _fade_in() -> void:
	fading_in  = true
	fading_out = false
	fade_alpha = 1.0
	overlay.visible = true
	overlay.color   = Color(0, 0, 0, 1.0)

func _on_btn() -> void:
	_hide_menu()
	_setup_scene()
	_fade_in()

# ═══════════════════════════════════════════════════════════════
#  SCENE SETUP
# ═══════════════════════════════════════════════════════════════
func _setup_scene() -> void:
	_build_placed()
	br_pos     = 0.0; br_dir   = 1; br_done  = 0
	br_holding = false; br_hold_t = 0.0
	br_flash   = 0.0;  br_fail  = 0.0
	timer_left = TIMER_MAX
	ripples.clear()
	wrong_flash = 0.0; good_flash = 0.0
	phase = Phase.BREATH
	_hint("Mia breathes.  Hold  SPACE  or  hold click  in the green zone  —  %d breaths needed" % BR_NEEDED)

func _build_placed() -> void:
	placed.clear(); targets.clear(); found.clear()

	var pool : Array = item_pool.duplicate()
	pool.shuffle()
	var chosen : Array = pool.slice(0, TOTAL_PLY)

	var slots : Array = SLOT_GRID.duplicate()
	slots.shuffle()

	for i in range(chosen.size()):
		var e  : Dictionary = chosen[i]
		var sl : Array      = slots[i]
		var tgt : bool      = (i < NEED_FIND)
		placed.append({
			"id":     e["id"],
			"label":  e["label"],
			"tex":    e["tex"],
			"x":      float(sl[0]),
			"y":      float(sl[1]) + float(PLAY_Y1),
			"w":      float(ITEM_W),
			"h":      float(ITEM_H),
			"target": tgt,
			"found":  false,
		})
		if tgt:
			targets.append(e["label"])

func _begin_explore() -> void:
	phase      = Phase.EXPLORE
	timer_left = TIMER_MAX
	_hint("Mia looks around carefully.  Find all %d items!  Wrong tap = lose a heart.  60 seconds." % NEED_FIND)

# ═══════════════════════════════════════════════════════════════
#  GAME EVENTS
# ═══════════════════════════════════════════════════════════════
func _on_scene_done() -> void:
	_fade_out_then(func() -> void:
		scene_idx += 1
		if scene_idx >= SCENE_DEFS.size():
			# All 3 scenes complete — show ending, no replay button
			menu_visible       = true
			lbl_ov_t.text      = "Mia is okay."
			lbl_ov_s.text      = (
				"She made it through — the café, the forest, the library.\n" +
				"Her breathing is steady now. The panic has passed.\n\n" +
				"Well done for staying with her.\n" +
				"Remember: you can always breathe through it."
			)
			lbl_ov_t.visible   = true
			lbl_ov_s.visible   = true
			btn_action.visible = false
			overlay.visible    = true
			overlay.color      = Color(0, 0, 0, 1.0)
			fade_alpha         = 1.0
		else:
			var nxt : String  = SCENE_DEFS[scene_idx]["name"]
			var intro : String = SCENE_INTROS[scene_idx]
			_show_menu(
				"Scene Complete",
				intro + "\n\nNext: %s\n%s" % [nxt, _hearts_str()],
				"Keep Going")
	)

func _on_timer_up() -> void:
	timer_left = 0.0
	_lose_heart()
	_fade_out_then(func() -> void:
		if hearts <= 0:
			_game_over()
		else:
			_show_menu("Time's Up",
				"Mia's mind drifted. She lost track.\n" +
				"Hearts remaining: %s\n\nSame place — try again." % _hearts_str(),
				"Try Again")
	)

func _on_breath_fail() -> void:
	_lose_heart()
	br_fail = 1.0
	_hint("Stay inside the green zone for %.0fs!   %s" % [BR_HOLD_MIN, _hearts_str()])
	if hearts <= 0:
		_fade_out_then(func() -> void: _game_over())

func _on_wrong_tap() -> void:
	_lose_heart()
	wrong_flash = 0.65
	_hint("That wasn't one she needed to notice.   %s" % _hearts_str())
	if hearts <= 0:
		_fade_out_then(func() -> void: _game_over())

func _lose_heart() -> void:
	hearts      = maxi(0, hearts - 1)
	heart_pulse = 1.0

func _game_over() -> void:
	menu_visible       = true
	lbl_ov_t.text      = "Overwhelmed"
	lbl_ov_s.text      = (
		"Mia lost her footing.\n" +
		"That's okay — anxiety can feel like that.\n\n" +
		"Take a real breath yourself."
	)
	lbl_ov_t.visible   = true
	lbl_ov_s.visible   = true
	btn_action.visible = false
	overlay.visible    = true
	overlay.color      = Color(0, 0, 0, 1.0)
	fade_alpha         = 1.0

func _hint(t: String) -> void:
	lbl_hint.text = t

func _hearts_str() -> String:
	var s := ""
	for i in range(3):
		s += "♥" if i < hearts else "♡"
	return s

func _scene_name() -> String:
	return SCENE_DEFS[clamp(scene_idx, 0, SCENE_DEFS.size()-1)]["name"]

# ═══════════════════════════════════════════════════════════════
#  INPUT
# ═══════════════════════════════════════════════════════════════
func _input(event: InputEvent) -> void:
	if fading_out or fading_in or menu_visible:
		return

	if phase == Phase.BREATH:
		var press   := false
		var release := false
		if event is InputEventKey and event.keycode == KEY_SPACE:
			if event.pressed and not event.echo: press   = true
			elif not event.pressed:              release = true
		elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed: press   = true
			else:             release = true

		if press and not br_holding:
			br_holding = true; br_hold_t = 0.0

		if release and br_holding:
			br_holding = false
			var in_zone : bool = br_pos >= BR_ZS and br_pos <= BR_ZE
			if in_zone and br_hold_t >= BR_HOLD_MIN:
				br_done += 1
				br_flash = 1.0
				if br_done >= BR_NEEDED:
					_begin_explore()
				else:
					_hint("Good breath.  %d / %d complete — keep going." % [br_done, BR_NEEDED])
			else:
				_on_breath_fail()
		return

	if phase != Phase.EXPLORE:
		return

	var tapped := false
	var tap    := Vector2.ZERO
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		tapped = true; tap = (event.position - Vector2(OFS_X, 0)) / SCALE
	elif event is InputEventScreenTouch and event.pressed:
		tapped = true; tap = (event.position - Vector2(OFS_X, 0)) / SCALE
	if not tapped:
		return

	if tap.y < float(PLAY_Y1) or tap.y > float(PLAY_Y2) or tap.x > float(PLAY_X2):
		return

	for item : Dictionary in placed:
		if item["found"]:
			continue
		if _hit(tap, item):
			if item["target"]:
				item["found"] = true
				found.append(item["label"])
				good_flash    = 0.55
				_spawn_rip(item, C_GREEN)
				_hint("Mia notices: %s   (%d / %d)" % [item["label"], found.size(), NEED_FIND])
				if found.size() >= NEED_FIND:
					_on_scene_done()
			else:
				_spawn_rip(item, C_WRONG)
				_on_wrong_tap()
			return

func _hit(tap: Vector2, item: Dictionary) -> bool:
	var hw : float = item["w"] * 0.5 + 10.0
	var hh : float = item["h"] * 0.5 + 10.0
	return absf(tap.x - item["x"]) <= hw and absf(tap.y - item["y"]) <= hh

func _spawn_rip(item: Dictionary, col: Color) -> void:
	ripples.append({ "x": item["x"], "y": item["y"], "r": 10.0, "life": 1.0, "col": col })

# ═══════════════════════════════════════════════════════════════
#  PROCESS
# ═══════════════════════════════════════════════════════════════
func _process(delta: float) -> void:
	wrong_flash = maxf(0.0, wrong_flash - delta * 2.2)
	good_flash  = maxf(0.0, good_flash  - delta * 1.8)
	br_flash    = maxf(0.0, br_flash    - delta * 1.8)
	br_fail     = maxf(0.0, br_fail     - delta * 1.8)
	heart_pulse = maxf(0.0, heart_pulse - delta * 2.5)

	for rp : Dictionary in ripples:
		rp["r"]    += delta * 58.0
		rp["life"] -= delta * 1.7
	var keep_r : Array = []
	for rp : Dictionary in ripples:
		if rp["life"] > 0.0:
			keep_r.append(rp)
	ripples = keep_r

	if not fading_out and not fading_in and not menu_visible:
		if phase == Phase.BREATH:
			br_pos += delta / BR_SWEEP * float(br_dir)
			if br_pos >= 1.0:
				br_pos = 1.0; br_dir = -1
			elif br_pos <= 0.0:
				br_pos = 0.0; br_dir = 1
			if br_holding:
				br_hold_t += delta

		elif phase == Phase.EXPLORE:
			timer_left = maxf(0.0, timer_left - delta)
			if timer_left <= 0.0:
				_on_timer_up()

	if fading_out:
		fade_alpha = minf(1.0, fade_alpha + delta * FADE_OUT_SPD)
		overlay.visible = true
		overlay.color   = Color(0, 0, 0, fade_alpha)
		if fade_alpha >= 1.0:
			fading_out = false
			fade_cb.call()

	elif fading_in:
		fade_alpha = maxf(0.0, fade_alpha - delta * FADE_IN_SPD)
		overlay.visible = true
		overlay.color   = Color(0, 0, 0, fade_alpha)
		if fade_alpha <= 0.0:
			fading_in       = false
			overlay.visible = false

	lbl_scene.text = _scene_name()
	queue_redraw()

# ═══════════════════════════════════════════════════════════════
#  DRAW
# ═══════════════════════════════════════════════════════════════
func _draw() -> void:
	# ── Letterbox bars (outside the scaled logical area) ──────
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	if OFS_X > 0.0:
		draw_rect(Rect2(0, 0, OFS_X, WIN_H), Color(0, 0, 0, 1.0))
		draw_rect(Rect2(WIN_W - OFS_X, 0, OFS_X, WIN_H), Color(0, 0, 0, 1.0))

	# ── All game drawing uses scaled+offset transform ─────────
	draw_set_transform(Vector2(OFS_X, 0.0), 0.0, Vector2(SCALE, SCALE))

	if menu_visible and not fading_in:
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		return

	var sd  : Dictionary = SCENE_DEFS[clamp(scene_idx, 0, SCENE_DEFS.size()-1)]
	var bg  : Color      = C_BG[int(sd["bg"])]

	draw_rect(Rect2(0, PLAY_Y1, PLAY_X2, PLAY_Y2 - PLAY_Y1), bg)
	_draw_bg(sd["draw"])

	for item : Dictionary in placed:
		_draw_item(item)

	for rp : Dictionary in ripples:
		var c : Color = rp["col"]
		c.a = rp["life"] * 0.8
		draw_arc(Vector2(rp["x"], rp["y"]), rp["r"], 0, TAU, 32, c, 3.0)
		c.a = rp["life"] * 0.28
		draw_arc(Vector2(rp["x"], rp["y"]), rp["r"] * 0.5, 0, TAU, 20, c, 1.6)

	if wrong_flash > 0.0:
		draw_rect(Rect2(0, PLAY_Y1, PLAY_X2, PLAY_Y2 - PLAY_Y1),
				Color(C_WRONG.r, C_WRONG.g, C_WRONG.b, wrong_flash * 0.30))
	if good_flash > 0.0:
		draw_rect(Rect2(0, PLAY_Y1, PLAY_X2, PLAY_Y2 - PLAY_Y1),
				Color(C_GREEN.r, C_GREEN.g, C_GREEN.b, good_flash * 0.18))

	_draw_top_bar()
	_draw_right_panel()

	if phase == Phase.BREATH:
		_draw_breath_panel()

	# Reset transform
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

func _draw_item(item: Dictionary) -> void:
	if item["found"]:
		return
	var cx : float = item["x"]
	var cy : float = item["y"]
	var hw : float = item["w"] * 0.5
	var hh : float = item["h"] * 0.5
	if item["tex"] != null:
		draw_texture_rect(item["tex"], Rect2(cx-hw, cy-hh, item["w"], item["h"]), false)
	else:
		draw_rect(Rect2(cx-hw, cy-hh, item["w"], item["h"]), Color(0.5, 0.5, 0.85, 0.75))
		var f : Font   = ThemeDB.fallback_font
		var s : String = item["label"].substr(0, 5)
		var sw : float = f.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, 10).x
		draw_string(f, Vector2(cx - sw*0.5, cy + 4), s, HORIZONTAL_ALIGNMENT_LEFT, -1, 10, C_WHITE)

# ═══════════════════════════════════════════════════════════════
#  TOP BAR
# ═══════════════════════════════════════════════════════════════
func _draw_top_bar() -> void:
	draw_rect(Rect2(0, 0, SW, TOP_H), C_PANEL)
	draw_line(Vector2(0, TOP_H), Vector2(SW, TOP_H), Color(C_GOLD.r, C_GOLD.g, C_GOLD.b, 0.35), 1.5)

	var font : Font = ThemeDB.fallback_font

	var hcx : float = float(PLAY_X2) * 0.5 + 60.0
	var hcy : float = float(TOP_H)   * 0.5
	var hr  : float = 13.0 + heart_pulse * 4.0

	draw_rect(Rect2(hcx - 70, hcy - 17, 140, 34), Color(0.0, 0.0, 0.0, 0.45), true, 4.0)

	for i in range(3):
		var hx : float = hcx - 44.0 + float(i) * 44.0
		var on : bool  = i < hearts
		if on:
			var glow_a : float = 0.22 + heart_pulse * 0.30 * (1.0 if i == hearts - 1 else 0.0)
			draw_circle(Vector2(hx, hcy), hr + 8, Color(C_HEART_ON.r, C_HEART_ON.g, C_HEART_ON.b, glow_a))
		_draw_heart(Vector2(hx, hcy), hr, C_HEART_ON if on else C_HEART_OFF)

	var hl : String = "LIVES"
	var hlw : float = font.get_string_size(hl, HORIZONTAL_ALIGNMENT_LEFT, -1, 9).x
	draw_string(font, Vector2(hcx - hlw * 0.5, float(TOP_H) - 3),
			hl, HORIZONTAL_ALIGNMENT_LEFT, -1, 9, Color(C_GOLD.r, C_GOLD.g, C_GOLD.b, 0.60))

	var bx   : float = 10.0
	var by   : float = float(TOP_H) - 6.0
	var bw   : float = float(PLAY_X2) - 20.0
	var fill : float = clampf(timer_left / TIMER_MAX, 0.0, 1.0)
	var tc   : Color = C_TIM_CRIT if fill < 0.25 else (C_TIM_WARN if fill < 0.50 else C_TIM_OK)
	draw_rect(Rect2(bx, by, bw, 5), Color(0.14, 0.14, 0.14, 0.85))
	draw_rect(Rect2(bx, by, bw * fill, 5), tc)

	var ts : String = "%ds" % ceili(timer_left)
	draw_string(font, Vector2(float(PLAY_X2) + 5, float(TOP_H) - 2),
			ts, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, tc)

func _draw_heart(pos: Vector2, r: float, col: Color) -> void:
	var pts : PackedVector2Array = []
	for i in range(32):
		var t  : float = TAU * i / 31.0
		var hx : float = r * 16.0 * pow(sin(t), 3.0) / 16.0
		var hy : float = -r * (13.0*cos(t) - 5.0*cos(2.0*t) - 2.0*cos(3.0*t) - cos(4.0*t)) / 16.0
		pts.append(pos + Vector2(hx, hy))
	draw_colored_polygon(pts, col)

# ═══════════════════════════════════════════════════════════════
#  RIGHT PANEL
# ═══════════════════════════════════════════════════════════════
func _draw_right_panel() -> void:
	var px  : float = float(PLAY_X2)
	var pw  : float = float(PANEL_W)
	var pty : float = float(TOP_H)
	var pby : float = float(SH - BOT_H)

	draw_rect(Rect2(px, pty, pw, pby - pty), C_PANEL2)
	draw_line(Vector2(px, pty), Vector2(px, pby), Color(C_GOLD.r, C_GOLD.g, C_GOLD.b, 0.50), 2.0)

	var font : Font  = ThemeDB.fallback_font

	var hdr : String = "FIND THESE"
	var hdrw : float = font.get_string_size(hdr, HORIZONTAL_ALIGNMENT_LEFT, -1, 12).x
	draw_string(font, Vector2(px + pw * 0.5 - hdrw * 0.5, pty + 18),
			hdr, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, C_GOLD)
	draw_line(Vector2(px + 8, pty + 23), Vector2(px + pw - 8, pty + 23),
			Color(C_GOLD.r, C_GOLD.g, C_GOLD.b, 0.35), 1.0)

	var prog : String = "%d / %d found" % [found.size(), NEED_FIND]
	var progw : float = font.get_string_size(prog, HORIZONTAL_ALIGNMENT_LEFT, -1, 11).x
	draw_string(font, Vector2(px + pw * 0.5 - progw * 0.5, pty + 36),
			prog, HORIZONTAL_ALIGNMENT_LEFT, -1, 11,
			C_GREEN if found.size() == NEED_FIND else C_DIM)

	var row_h   : float = 44.0
	var list_y0 : float = pty + 46.0

	for i in range(targets.size()):
		var lbl  : String = targets[i]
		var done : bool   = found.has(lbl)
		var iy   : float  = list_y0 + float(i) * row_h

		var rc : Color = Color(0.14, 0.40, 0.18, 0.58) if done else Color(0.18, 0.14, 0.10, 0.55)
		draw_rect(Rect2(px + 5, iy + 1, pw - 10, row_h - 3), rc)

		var tex : Texture2D = null
		for item : Dictionary in placed:
			if item["label"] == lbl:
				tex = item["tex"]
				break
		if tex != null:
			draw_texture_rect(tex,
				Rect2(px + 7, iy + 5, 32, 32), false,
				Color(1.0, 1.0, 1.0, 0.35 if done else 1.0))

		var lc : Color = Color(0.42, 0.92, 0.44) if done else C_WHITE
		draw_string(font, Vector2(px + 44, iy + 22),
				lbl, HORIZONTAL_ALIGNMENT_LEFT, int(pw - 52), 11, lc)

		if done:
			var lw : float = minf(
				font.get_string_size(lbl, HORIZONTAL_ALIGNMENT_LEFT, -1, 11).x, pw - 52)
			draw_line(Vector2(px + 42, iy + 18), Vector2(px + 42 + lw, iy + 18),
					Color(0.38, 0.90, 0.40, 0.85), 1.5)
			draw_circle(Vector2(px + pw - 14, iy + 14), 10, Color(0.12, 0.52, 0.18))
			var ck : String = "v"
			var ckw : float = font.get_string_size(ck, HORIZONTAL_ALIGNMENT_LEFT, -1, 12).x
			draw_string(font, Vector2(px + pw - 14 - ckw * 0.5, iy + 19),
					ck, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, C_WHITE)

# ═══════════════════════════════════════════════════════════════
#  BREATHING PANEL
# ═══════════════════════════════════════════════════════════════
func _draw_breath_panel() -> void:
	var px  : float = 20.0
	var py  : float = float(PLAY_Y1) + 14.0
	var pw  : float = float(PLAY_X2) - 40.0
	var ph  : float = 222.0
	var mid : float = px + pw * 0.5

	draw_rect(Rect2(px-5, py-5, pw+10, ph+10), Color(0,0,0,0.42))
	draw_rect(Rect2(px, py, pw, ph), Color(0.06, 0.05, 0.04, 0.95))
	draw_rect(Rect2(px, py, pw, ph), C_BHI, false, 2.0)

	var font : Font = ThemeDB.fallback_font

	var ttl : String = "Mia breathes."
	var tw  : float  = font.get_string_size(ttl, HORIZONTAL_ALIGNMENT_LEFT, -1, 22).x
	draw_string(font, Vector2(mid - tw*0.5, py + 32), ttl,
			HORIZONTAL_ALIGNMENT_LEFT, -1, 22, C_WHITE)

	var ins : String = "Hold  SPACE  or  hold click  inside the green zone  for 1 second"
	var iw  : float  = font.get_string_size(ins, HORIZONTAL_ALIGNMENT_LEFT, -1, 11).x
	draw_string(font, Vector2(mid - iw*0.5, py + 56), ins,
			HORIZONTAL_ALIGNMENT_LEFT, -1, 11, C_DIM)

	var pip_cx : float = mid - float(BR_NEEDED) * 20.0
	for i in range(BR_NEEDED):
		var done : bool  = i < br_done
		var pc   : Color = C_BHI if done else Color(0.28, 0.28, 0.35)
		draw_circle(Vector2(pip_cx + float(i)*40.0 + 20.0, py + 82.0), 11.0, pc)
		if done:
			var ck  : String = "v"
			var ckw : float  = font.get_string_size(ck, HORIZONTAL_ALIGNMENT_LEFT, -1, 11).x
			draw_string(font, Vector2(pip_cx + float(i)*40.0 + 20.0 - ckw*0.5, py + 87.0),
					ck, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, C_WHITE)
	var prg : String = "%d / %d breaths" % [br_done, BR_NEEDED]
	var prw : float  = font.get_string_size(prg, HORIZONTAL_ALIGNMENT_LEFT, -1, 11).x
	draw_string(font, Vector2(mid - prw*0.5, py + 106.0), prg,
			HORIZONTAL_ALIGNMENT_LEFT, -1, 11, C_DIM)

	var bx : float = px + 30.0
	var by : float = py + 124.0
	var bw : float = pw - 60.0
	var bh : float = 34.0
	draw_rect(Rect2(bx, by, bw, bh), Color(0.12, 0.12, 0.18))
	draw_rect(Rect2(bx, by, bw, bh), Color(0.26, 0.26, 0.40), false, 1.0)

	var zs  : float = bx + bw * BR_ZS
	var ze  : float = bx + bw * BR_ZE
	var za  : float = 0.38 + br_flash * 0.50
	var zc  : Color = Color(C_BHI.r, C_BHI.g, C_BHI.b, za)
	if br_fail > 0.0:
		zc = Color(C_WRONG.r, C_WRONG.g, C_WRONG.b, br_fail * 0.65)
	draw_rect(Rect2(zs, by, ze-zs, bh), zc)
	var zlbl : String = "HOLD HERE"
	var zlw  : float  = font.get_string_size(zlbl, HORIZONTAL_ALIGNMENT_LEFT, -1, 10).x
	draw_string(font, Vector2((zs+ze)*0.5 - zlw*0.5, by + bh + 16),
			zlbl, HORIZONTAL_ALIGNMENT_LEFT, -1, 10, C_BHI)

	var cx  : float = bx + bw * br_pos
	var cc  : Color
	if br_flash > 0.0:   cc = C_WHITE
	elif br_fail > 0.0:  cc = C_WRONG
	elif br_holding:     cc = C_BHI
	else:                cc = C_BLO
	draw_rect(Rect2(cx-9,  by-5, 18, bh+10), Color(cc.r, cc.g, cc.b, 0.22))
	draw_rect(Rect2(cx-4,  by-6, 8,  bh+12), cc)

	if br_holding:
		var in_z : bool   = br_pos >= BR_ZS and br_pos <= BR_ZE
		var hs   : String = "Holding...  %.1fs / %.0fs" % [br_hold_t, BR_HOLD_MIN] if in_z \
				else "Move into the green zone!"
		var hc   : Color  = C_BHI if in_z else C_WRONG
		var hlw  : float  = font.get_string_size(hs, HORIZONTAL_ALIGNMENT_LEFT, -1, 13).x
		draw_string(font, Vector2(mid - hlw*0.5, py + ph - 14.0),
				hs, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, hc)

# ═══════════════════════════════════════════════════════════════
#  BACKGROUND SCENE DECORATIONS
# ═══════════════════════════════════════════════════════════════
func _draw_bg(which: String) -> void:
	match which:
		"cafe":    _bg_cafe()
		"forest":  _bg_forest()
		"library": _bg_library()

func _bg_cafe() -> void:
	var oy : int = PLAY_Y1; var pw : int = PLAY_X2; var ph : int = PLAY_Y2 - PLAY_Y1
	draw_rect(Rect2(0, oy,       pw, 270), Color(0.94, 0.91, 0.86))
	draw_rect(Rect2(0, oy + 270, pw, ph - 270), Color(0.72, 0.60, 0.44))
	draw_rect(Rect2(0, oy + 258, pw, 14), Color(0.76, 0.66, 0.50))
	draw_rect(Rect2(50, oy+50, 150, 190), Color(0.66, 0.83, 0.95, 0.55))
	draw_rect(Rect2(50, oy+50, 150, 190), Color(0.50, 0.37, 0.22), false, 4)
	draw_line(Vector2(125, oy+50), Vector2(125, oy+240), Color(0.50,0.37,0.22), 3)
	draw_line(Vector2(50,  oy+145),Vector2(200, oy+145), Color(0.50,0.37,0.22), 3)
	draw_rect(Rect2(42,  oy+42, 24, 210), Color(0.78, 0.36, 0.28, 0.78))
	draw_rect(Rect2(188, oy+42, 24, 210), Color(0.78, 0.36, 0.28, 0.78))
	draw_rect(Rect2(80,  oy+270, 530, 13), Color(0.55, 0.38, 0.22))
	draw_rect(Rect2(90,  oy+283, 14,  50), Color(0.44, 0.29, 0.17))
	draw_rect(Rect2(588, oy+283, 14,  50), Color(0.44, 0.29, 0.17))
	draw_rect(Rect2(415, oy+62, 175, 122), Color(0.19, 0.27, 0.21))
	draw_rect(Rect2(415, oy+62, 175, 122), Color(0.37, 0.28, 0.16), false, 4)
	var f : Font = ThemeDB.fallback_font
	draw_string(f,Vector2(432,oy+88), "Today's Special",HORIZONTAL_ALIGNMENT_LEFT,-1,11,Color(0.80,0.80,0.70,0.85))
	draw_string(f,Vector2(432,oy+106),"Latte  . . . .  80",HORIZONTAL_ALIGNMENT_LEFT,-1,10,Color(0.70,0.70,0.60,0.70))
	draw_string(f,Vector2(432,oy+122),"Croissant . .  45",HORIZONTAL_ALIGNMENT_LEFT,-1,10,Color(0.70,0.70,0.60,0.70))
	draw_string(f,Vector2(432,oy+138),"Earl Grey . .  60",HORIZONTAL_ALIGNMENT_LEFT,-1,10,Color(0.70,0.70,0.60,0.70))

func _bg_forest() -> void:
	var oy:int=PLAY_Y1; var pw:int=PLAY_X2; var ph:int=PLAY_Y2-PLAY_Y1
	draw_rect(Rect2(0,oy,    pw,180), Color(0.64,0.87,0.76))
	draw_rect(Rect2(0,oy+345,pw,ph-345), Color(0.32,0.52,0.26))
	draw_rect(Rect2(0,oy+328,pw,28),    Color(0.38,0.62,0.30))
	for tx in [68,186,318,476,610]:
		draw_rect(Rect2(tx-10,oy+288,20,62), Color(0.39,0.27,0.13))
		var tp1:PackedVector2Array=PackedVector2Array([Vector2(tx,oy+58),Vector2(tx-56,oy+248),Vector2(tx+56,oy+248)])
		draw_colored_polygon(tp1,Color(0.17,0.47,0.19))
		var tp2:PackedVector2Array=PackedVector2Array([Vector2(tx,oy+30),Vector2(tx-44,oy+194),Vector2(tx+44,oy+194)])
		draw_colored_polygon(tp2,Color(0.23,0.56,0.23))
	draw_circle(Vector2(592,oy+72),36,Color(1.0,0.95,0.60,0.65))
	draw_circle(Vector2(592,oy+72),25,Color(1.0,0.97,0.72))
	var pp:PackedVector2Array=PackedVector2Array([Vector2(262,oy+338),Vector2(350,oy+338),Vector2(410,oy+450),Vector2(202,oy+450)])
	draw_colored_polygon(pp,Color(0.71,0.65,0.48))

func _bg_library() -> void:
	var oy:int=PLAY_Y1; var pw:int=PLAY_X2; var ph:int=PLAY_Y2-PLAY_Y1
	draw_rect(Rect2(0,oy,    pw,345), Color(0.87,0.85,0.81))
	draw_rect(Rect2(0,oy+345,pw,ph-345), Color(0.57,0.47,0.33))
	for shelf_y in [60,138,216,294]:
		draw_rect(Rect2(16,oy+shelf_y,215,10),Color(0.51,0.37,0.19))
		var bk_c:Array=[Color(0.85,0.22,0.22),Color(0.28,0.55,0.90),Color(0.5,0.42,0.22),
						Color(0.3,0.6,0.38),Color(0.72,0.62,0.22),Color(0.85,0.22,0.22),Color(0.6,0.3,0.6)]
		var bx2:int=22
		for bc:Color in bk_c:
			var bw2:int=13+(bx2%9)
			draw_rect(Rect2(bx2,oy+shelf_y-48,bw2,49),bc)
			bx2+=bw2+2
	draw_rect(Rect2(285,oy+50,128,185),Color(0.67,0.83,0.96,0.50))
	draw_rect(Rect2(285,oy+50,128,185),Color(0.47,0.35,0.19),false,4)
	draw_arc(Vector2(349,oy+50),64,PI,TAU,16,Color(0.47,0.35,0.19),4)
	draw_rect(Rect2(354,oy+270,240,16),Color(0.51,0.37,0.19))
	draw_rect(Rect2(362,oy+286,14,64),Color(0.43,0.31,0.17))
	draw_rect(Rect2(574,oy+286,14,64),Color(0.43,0.31,0.17))
	var rp2:PackedVector2Array=PackedVector2Array([Vector2(92,oy+352),Vector2(540,oy+352),Vector2(568,oy+440),Vector2(64,oy+440)])
	draw_colored_polygon(rp2,Color(0.67,0.25,0.25,0.55))
	draw_polyline(rp2,Color(0.84,0.68,0.26,0.45),3)
