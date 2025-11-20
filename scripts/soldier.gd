class_name Soldier
extends CharacterBody3D

signal died

@export var move_speed: float = 5.0
@export var attack_range: float = 20.0
@export var fire_rate: float = 0.15
@export var damage: int = 1

@onready var visuals: Node3D = $Visuals
@onready var attack_timer: Timer = $AttackTimer
@onready var animation_player: AnimationPlayer

var projectile_scene = preload("res://scenes/projectile.tscn")
var target: Node3D = null

func _ready() -> void:
	# Attempt to find animation player in the instantiated GLB
	if visuals.has_node("AnimationPlayer"):
		animation_player = visuals.get_node("AnimationPlayer")
	elif visuals.get_child_count() > 0 and visuals.get_child(0).has_node("AnimationPlayer"):
		animation_player = visuals.get_child(0).get_node("AnimationPlayer")
		
	play_anim("Run")
	
	# Setup Timer
	if not attack_timer:
		attack_timer = Timer.new()
		attack_timer.wait_time = fire_rate
		attack_timer.one_shot = false
		add_child(attack_timer)
	
	if not attack_timer.timeout.is_connected(_on_attack_timer_timeout):
		attack_timer.timeout.connect(_on_attack_timer_timeout)
	
	# Don't start timer until game is active
	# Timer will be started when game begins
	if GameManager.is_game_active:
		attack_timer.start()

func _process(_delta: float) -> void:
	# Periodically check if game started (for soldiers spawned before game start)
	if not GameManager.is_game_active:
		if attack_timer and not attack_timer.is_stopped():
			attack_timer.stop()
	else:
		if attack_timer and attack_timer.is_stopped():
			attack_timer.start()

func play_anim(anim_name: String) -> void:
	if animation_player and animation_player.has_animation(anim_name):
		animation_player.play(anim_name)

func _physics_process(_delta: float) -> void:
	# Soldier logic mainly handled by SquadController for movement
	# Always face forward (negative Z)
	rotation.y = PI # or 0, depending on model orientation. Model usually faces Z+. We move -Z.
	# Actually, standard models usually face +Z. If we move -Z, we should rotate 180 (PI).
	rotation.y = PI 
	rotation.x = 0

func _on_attack_timer_timeout() -> void:
	# Only shoot if game is active
	if GameManager.is_game_active:
		shoot()

func shoot() -> void:
	# Double check game is active
	if not GameManager.is_game_active:
		return
		
	var p = projectile_scene.instantiate()
	get_tree().current_scene.add_child(p)
	p.global_position = global_position + Vector3(0, 1, 0)
	# Shoot straight forward (Negative Z)
	# Projectile script moves in -basis.z.
	# If we set rotation to PI, basis.z is (0,0,-1). -basis.z is (0,0,1). That's backwards.
	# We want projectile to move -Z.
	# So projectile should face 0 rotation?
	# Let's just look at a point far in front.
	var target_pos = global_position + Vector3(0, 0, -100)
	p.look_at(target_pos, Vector3.UP)

func take_damage() -> void:
	died.emit()
	queue_free()
