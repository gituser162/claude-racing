extends Node
## Налаштування екрана (autoload «Settings»): режим вікна, розмір вікна, обмеження FPS, вертикальна синхронізація.
## Застосовуються під час запуску гри, зберігаються в user://settings.cfg (секція display) — поруч зі звуком (Audio).
## Звук і світло під музику — в Audio; вікно «НАЛАШТУВАННЯ» (scripts/ui/settings_panel.gd) показує все разом.

enum WindowMode { WINDOWED, FULLSCREEN, EXCLUSIVE }

const SETTINGS_PATH: String = "user://settings.cfg"
const WINDOW_MODE_NAMES: Array[String] = ["Вікно", "Повноекранний", "Ексклюзивний"]
## Розміри вікна на вибір (лише ті, що вміщаються на екрані).
const WINDOW_SIZES: Array[Vector2i] = [
	Vector2i(960, 540), Vector2i(1280, 720), Vector2i(1600, 900), Vector2i(1920, 1080),
	Vector2i(2560, 1440), Vector2i(3840, 2160),
]
## Обмеження кадрів за секунду; 0 — без обмеження.
const FPS_LIMITS: Array[int] = [30, 60, 75, 120, 144, 165, 240, 0]

var window_mode: WindowMode = WindowMode.WINDOWED
var window_size: Vector2i = Vector2i(1280, 720)
var fps_limit: int = 0
var vsync: bool = true


func _ready() -> void:
	var config := ConfigFile.new()
	if config.load(SETTINGS_PATH) == OK:
		window_mode = clampi(config.get_value("display", "window_mode", window_mode), 0, 2) as WindowMode
		window_size = config.get_value("display", "window_size", window_size)
		fps_limit = config.get_value("display", "fps_limit", fps_limit)
		vsync = config.get_value("display", "vsync", vsync)
	# Перше застосування — після першого кадру, коли вікно вже створене.
	_apply_all.call_deferred()


func _apply_all() -> void:
	_apply_window()
	_apply_fps()


## Розміри, що вміщаються на поточному екрані (завжди хоча б найменший).
func available_sizes() -> Array[Vector2i]:
	var screen := _screen_size()
	var result: Array[Vector2i] = []
	for size: Vector2i in WINDOW_SIZES:
		if size.x <= screen.x and size.y <= screen.y:
			result.append(size)
	if result.is_empty():
		result.append(WINDOW_SIZES[0])
	if not result.has(window_size):
		result.append(window_size)
		result.sort_custom(func(a: Vector2i, b: Vector2i) -> bool: return a.x < b.x)
	return result


func set_window_mode(mode: WindowMode) -> void:
	window_mode = mode
	_apply_window()
	_save()


func set_window_size(size: Vector2i) -> void:
	window_size = size
	_apply_window()
	_save()


func set_fps_limit(limit: int) -> void:
	fps_limit = limit
	_apply_fps()
	_save()


func set_vsync(enabled: bool) -> void:
	vsync = enabled
	_apply_fps()
	_save()


static func fps_name(limit: int) -> String:
	return "Без обмеження" if limit <= 0 else "%d" % limit


static func size_name(size: Vector2i) -> String:
	return "%d × %d" % [size.x, size.y]


func _headless() -> bool:
	return DisplayServer.get_name() == "headless"


func _screen_size() -> Vector2i:
	if _headless():
		return Vector2i(1920, 1080)
	return DisplayServer.screen_get_size(DisplayServer.window_get_current_screen())


func _apply_window() -> void:
	if _headless() or OS.has_feature("web"):
		return
	match window_mode:
		WindowMode.FULLSCREEN:
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
		WindowMode.EXCLUSIVE:
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN)
		_:
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
			var screen := DisplayServer.window_get_current_screen()
			var size := window_size.min(DisplayServer.screen_get_size(screen))
			DisplayServer.window_set_size(size)
			# По центру екрана.
			var rect := DisplayServer.screen_get_usable_rect(screen)
			DisplayServer.window_set_position(rect.position + (rect.size - size) / 2)


func _apply_fps() -> void:
	Engine.max_fps = maxi(fps_limit, 0)
	if _headless():
		return
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED if vsync else DisplayServer.VSYNC_DISABLED)


## Зберігаємо поверх наявного файлу: у ньому ж звук і треки (Audio).
func _save() -> void:
	var config := ConfigFile.new()
	config.load(SETTINGS_PATH)
	config.set_value("display", "window_mode", int(window_mode))
	config.set_value("display", "window_size", window_size)
	config.set_value("display", "fps_limit", fps_limit)
	config.set_value("display", "vsync", vsync)
	config.save(SETTINGS_PATH)
