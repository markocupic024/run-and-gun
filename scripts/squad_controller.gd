class_name SquadController
extends Node3D

@export var move_speed: float = 5.0
@export var strafe_speed: float = 6.0
@export var max_strafe_x: float = 7.0

var soldier_scene = preload("res://scenes/soldier.tscn")
var soldiers: Array[Soldier] = []

func _ready() -> void:
	add_to_group("SquadController")
	# Start with 1 soldier
	add_soldiers(1)

func _process(delta: float) -> void:
	if not GameManager.is_game_active:
		# Only move if game is active, but maybe we want to auto-start?
		# For now, assume game starts immediately or via UI
		pass
		
	if Input.is_action_just_pressed("ui_accept") and not GameManager.is_game_active:
		GameManager.start_game()

	if GameManager.is_game_active:
		# Move Forward (Negative Z is forward in Godot usually)
		global_position.z -= move_speed * delta
		
		# Strafe
		var input = Input.get_axis("move_left", "move_right")
		if input != 0:
			global_position.x += input * strafe_speed * delta
			global_position.x = clamp(global_position.x, -max_strafe_x, max_strafe_x)

func add_soldiers(amount: int) -> void:
	for i in range(amount):
		var s = soldier_scene.instantiate() as Soldier
		add_child(s)
		soldiers.append(s)
		s.died.connect(_on_soldier_died.bind(s))
	update_formation()

func remove_soldiers(amount: int) -> void:
	# Remove from end
	amount = min(amount, soldiers.size())
	for i in range(amount):
		var s = soldiers.pop_back()
		s.queue_free()
	
	if soldiers.is_empty():
		GameManager.end_game()
	else:
		update_formation()

func multiply_soldiers(factor: int) -> void:
	var current = soldiers.size()
	var target = current * factor
	add_soldiers(target - current)

func update_formation() -> void:
	# Fermat's spiral formation
	var count = soldiers.size()
	var spacing = 0.4
	
	for i in range(count):
		if not is_instance_valid(soldiers[i]): continue
		
		var radius = sqrt(i) * spacing
		var theta = i * 2.39996 # Golden angle in radians
		
		var x = radius * cos(theta)
		var z = radius * sin(theta)
		
		var target_pos = Vector3(x, 0, z)
		
		# Simple lerp or tween
		var tween = create_tween()
		tween.tween_property(soldiers[i], "position", target_pos, 0.3).set_trans(Tween.TRANS_SINE)

func _on_soldier_died(s: Soldier) -> void:
	if s in soldiers:
		soldiers.erase(s)
		update_formation()
	
	if soldiers.is_empty():
		GameManager.end_game()

func get_squad_size() -> int:
	return soldiers.size()

