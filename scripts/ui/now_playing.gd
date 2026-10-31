extends CanvasLayer
## Плашка «зараз грає» вгорі по центру: виїжджає при зміні треку, тримається кілька секунд і зникає.
## Створюється й керується з Audio (show_track). Працює і на паузі.

const THEME: Theme = preload("res://resources/ui/neon_theme.tres")
const SHOW_TIME: float = 4.0
const FADE_TIME: float = 0.4
const MIN_WIDTH: float = 170.0
const MAX_WIDTH: float = 250.0

var _panel: PanelContainer
var _title: Label
var _artist: Label
var _left: float = 0.0


func _ready() -> void:
	layer = 20
	process_mode = Node.PROCESS_MODE_ALWAYS
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.theme = THEME
	add_child(root)
	_panel = PanelContainer.new()
	_panel.theme_type_variation = &"SkillReady"
	_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_panel.offset_top = 8.0
	root.add_child(_panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override(&"separation", -2)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel.add_child(box)
	var caption := Label.new()
	caption.theme_type_variation = &"HudLabel"
	caption.add_theme_font_size_override(&"font_size", 8)
	caption.add_theme_color_override(&"font_color", Color(0.3, 0.95, 1))
	caption.text = "♪ ЗАРАЗ ГРАЄ        [ / ] — перемкнути"
	caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title = Label.new()
	_title.theme_type_variation = &"GlitchLabel"
	_title.add_theme_font_size_override(&"font_size", 13)
	_title.add_theme_color_override(&"font_color", Color(1, 0.85, 0.3))
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_artist = Label.new()
	_artist.add_theme_font_size_override(&"font_size", 9)
	_artist.add_theme_color_override(&"font_color", Color(0.85, 0.85, 0.95))
	_artist.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_artist.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	for label: Label in [caption, _title, _artist]:
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		box.add_child(label)
	_panel.visible = false


func show_track(index: int) -> void:
	var track: Dictionary = Audio.get_track(index)
	if track.is_empty():
		return
	_title.text = track.title
	_artist.text = track.artist
	# Ширина — під назву, але не ширше MAX_WIDTH (щоб не налазити на таблицю місць у гонці);
	# задовга назва обрізається «…». Позиція — по центру.
	var font := _title.get_theme_font(&"font")
	var text_width := font.get_string_size(_title.text, HORIZONTAL_ALIGNMENT_LEFT, -1, _title.get_theme_font_size(&"font_size")).x
	var width := clampf(text_width + 28.0, MIN_WIDTH, MAX_WIDTH)
	_panel.offset_left = -width * 0.5
	_panel.offset_right = width * 0.5
	_panel.visible = true
	_panel.modulate.a = 1.0
	_left = SHOW_TIME


func _process(delta: float) -> void:
	if _left <= 0.0:
		return
	_left -= delta
	_panel.modulate.a = clampf(_left / FADE_TIME, 0.0, 1.0)
	if _left <= 0.0:
		_panel.visible = false
