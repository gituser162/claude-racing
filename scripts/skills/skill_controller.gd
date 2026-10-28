class_name SkillController
extends Node
## Два скіли машини (Q і E) та правила гонки для них:
## - на старті скіли заблоковані кілька секунд (lock_for);
## - ультімейт E відкривається лише на останньому колі (unlock_ultimate).
## Гравець вмикає скіли клавішами, боти — через BotDriver.

var car: Car
var q: Skill
var e: Skill
var q_name: String = ""
var e_name: String = ""

## Контекст гонки — заповнює сцена гонки (set_race). Потрібен скілам, що діють на інших.
var cars: Array[Car] = []
var track: Track

var _lock_left: float = 0.0
## Вміння вимкнені на всю гонку (мапа без умінь, MapData.skills_enabled = false).
var disabled: bool = false
var _ultimate_unlocked: bool = false


func set_racer(data: RacerData) -> void:
	for old: Skill in [q, e]:
		if old:
			old.queue_free()
	q = _make(data.skill_q_script, false)
	e = _make(data.skill_e_script, true)
	q_name = data.skill_q_name
	e_name = data.skill_e_name


func set_race(p_cars: Array[Car], p_track: Track) -> void:
	cars = p_cars
	track = p_track


func lock_for(seconds: float) -> void:
	_lock_left = seconds


func unlock_ultimate() -> void:
	_ultimate_unlocked = true


func is_locked() -> bool:
	return disabled or _lock_left > 0.0


func lock_left() -> float:
	return _lock_left


func is_ultimate_unlocked() -> bool:
	return _ultimate_unlocked


func can_use_q() -> bool:
	return q != null and not is_locked() and q.is_ready()


func can_use_e() -> bool:
	return e != null and not is_locked() and _ultimate_unlocked and e.is_ready()


func use_q() -> bool:
	return can_use_q() and q.activate()


func use_e() -> bool:
	return can_use_e() and e.activate()


func _physics_process(delta: float) -> void:
	_lock_left = maxf(_lock_left - delta, 0.0)
	if car and car.controlled_by_player:
		if Input.is_action_just_pressed(&"skill_1"):
			use_q()
		if Input.is_action_just_pressed(&"skill_2"):
			use_e()


func _make(script: Script, ultimate: bool) -> Skill:
	if script == null:
		return null
	var skill: Skill = script.new()
	skill.car = car
	skill.is_ultimate = ultimate
	skill.name = "SkillE" if ultimate else "SkillQ"
	add_child(skill)
	return skill
