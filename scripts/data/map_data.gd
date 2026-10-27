class_name MapData
extends Resource
## Дані однієї мапи (траси) для вибору в меню.
## Сцена зберігається шляхом, а не PackedScene: так Game не тягне сцену траси
## під час завантаження (див. «Ресурси гонщиків» у DESIGN.md — та сама проблема з циклом).

@export var id: StringName
@export var display_name: String
## Короткий опис для меню (один рядок).
@export_multiline var description: String
## Сцена траси. Корінь сцени — вузол зі скриптом Track (scripts/race/track.gd).
@export_file("*.tscn") var scene_path: String
## Скільки кіл у гонці. 1 — для трас-«спринтів» від старту до фінішу (Track.closed = false).
@export_range(1, 9) var laps: int = 3


## Завантажує сцену траси (лише коли вона справді потрібна).
func load_scene() -> PackedScene:
	return load(scene_path) as PackedScene
