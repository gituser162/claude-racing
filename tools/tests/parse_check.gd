extends SceneTree
## Швидка перевірка: основні скрипти завантажуються без помилок (без гонок).
func _initialize() -> void:
	for p in ["res://scripts/main.gd", "res://scripts/race/race_dynamics.gd", "res://scripts/car/car.gd", "res://scripts/race/bot_driver.gd", "res://scripts/autoload/game.gd", "res://scripts/ui/main_menu.gd", "res://scripts/data/map_data.gd"]:
		var s: GDScript = load(p)
		print(p, " ok=", s != null and s.can_instantiate())
	quit()
