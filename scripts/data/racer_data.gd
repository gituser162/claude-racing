class_name RacerData
extends Resource
## Дані одного гонщика: машина, характеристики і два скіли.
## Значення характеристик 1–3 (як зірки в DESIGN.md).

@export var id: StringName
@export var display_name: String
## Короткий опис для меню вибору гонщика.
@export_multiline var bio: String
@export var car_color: Color = Color.WHITE

@export_group("Модель")
## Сцена видимої моделі (корінь Node3D, «перед» — напрямок -Z, низ коліс на y = 0).
## Порожньо — використовується карт Ракети.
@export var model_scene: PackedScene
## Габарит для зіткнень: ширина × довжина, м.
@export var footprint: Vector2 = Vector2(1.7, 2.9)

@export_group("Характеристики")
@export_range(1, 3) var speed: int = 2
@export_range(1, 3) var acceleration: int = 2
@export_range(1, 3) var handling: int = 2
@export_range(1, 3) var weight: int = 2
## Тонке підлаштування максимальної швидкості (1.0 — як за зірками; 0.95 — на 5% повільніше).
@export_range(0.8, 1.2, 0.01) var top_speed_multiplier: float = 1.0

@export_group("Скіл Q (легкий)")
@export var skill_q_name: String
@export_multiline var skill_q_description: String
## Скрипт поведінки скіла (успадковує Skill).
@export var skill_q_script: Script

@export_group("Скіл E (ультімейт)")
@export var skill_e_name: String
@export_multiline var skill_e_description: String
@export var skill_e_script: Script
