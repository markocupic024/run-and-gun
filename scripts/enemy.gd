class_name Enemy
extends CharacterBody3D

enum EnemyType { NORMAL, LARGE, GIANT }

@export var enemy_type: EnemyType = EnemyType.NORMAL
@export var hp: int = 3
@export var max_hp: int = 3
@export var move_speed: float = 3.5
@export var damage: int = 1

@onready var visuals: Node3D = $Visuals
@onready var animation_player: AnimationPlayer

var health_bar_container: Node3D = null
var health_bar: MeshInstance3D = null
var mesh_instance: MeshInstance3D = null
var enemy_material: StandardMaterial3D = null
var original_color: Color = Color.WHITE

func _ready() -> void:
	add_to_group("Enemy")
	setup_enemy_type()
	setup_health_bar()
	
	if visuals.has_node("AnimationPlayer"):
		animation_player = visuals.get_node("AnimationPlayer")
	elif visuals.get_child_count() > 0 and visuals.get_child(0).has_node("AnimationPlayer"):
		animation_player = visuals.get_child(0).get_node("AnimationPlayer")
	
	if animation_player and animation_player.has_animation("Walk"):
		animation_player.play("Walk")
		
	# Tint based on type
	_tint_enemy()

func setup_enemy_type() -> void:
	# Setup based on enemy type
	match enemy_type:
		EnemyType.NORMAL:
			max_hp = 2
			hp = 2
			move_speed = 2.5
			damage = 1
			scale = Vector3(1, 1, 1)
		EnemyType.LARGE:
			max_hp = 8
			hp = 8
			move_speed = 1.8
			damage = 2
			# Scale entire node for large enemies (including collision)
			scale = Vector3(2.8, 2.8, 2.8)
		EnemyType.GIANT:
			max_hp = 35
			hp = 35
			move_speed = 1.2
			damage = 4
			# Scale entire node for giant enemies
			scale = Vector3(4.5, 4.5, 4.5)

func _tint_enemy() -> void:
	# Traverse children to find MeshInstance3D
	mesh_instance = _find_mesh_instance(visuals)
	if mesh_instance:
		enemy_material = StandardMaterial3D.new()
		match enemy_type:
			EnemyType.NORMAL:
				enemy_material.albedo_color = Color(1, 0.2, 0.2) # Red
			EnemyType.LARGE:
				enemy_material.albedo_color = Color(0.8, 0.1, 0.1) # Darker red
			EnemyType.GIANT:
				enemy_material.albedo_color = Color(0.5, 0.05, 0.05) # Very dark red
		original_color = enemy_material.albedo_color
		mesh_instance.material_override = enemy_material

func setup_health_bar() -> void:
	# Create health bar container if it doesn't exist
	if not has_node("HealthBarContainer"):
		var container = Node3D.new()
		container.name = "HealthBarContainer"
		add_child(container)
		
		# Position above enemy head (adjust based on enemy size)
		# Since the enemy node is scaled, we need to account for that in local space
		# Base character is ~1 unit tall, so head is around 1.0
		# We want health bar just above head, so slightly more than the scaled height
		var height_offset = 1.2
		if enemy_type == EnemyType.LARGE:
			# Large is 2.8x scale, so head is at ~2.8, but in local space that's 1.0
			# We want it just above, so maybe 1.1-1.2 in local space
			height_offset = 1.1
		elif enemy_type == EnemyType.GIANT:
			# Giant is 4.5x scale, so head is at ~4.5, but in local space that's 1.0
			# We want it just above, so maybe 1.1-1.2 in local space
			height_offset = 1.1
		container.position = Vector3(0, height_offset, 0)
		
		# Scale health bar based on enemy size
		var bar_width = 1.0
		var bar_height = 0.15
		if enemy_type == EnemyType.LARGE:
			bar_width = 1.5
			bar_height = 0.2
		elif enemy_type == EnemyType.GIANT:
			bar_width = 2.0
			bar_height = 0.25
		
		# Single health bar
		var bar_mesh = BoxMesh.new()
		bar_mesh.size = Vector3(bar_width, bar_height, 0.05)
		var bar = MeshInstance3D.new()
		bar.name = "HealthBar"
		bar.mesh = bar_mesh
		var bar_mat = StandardMaterial3D.new()
		bar_mat.albedo_color = Color(0, 1, 0) # Green
		bar.material_override = bar_mat
		container.add_child(bar)
		
		# Store references
		health_bar_container = container
		health_bar = bar
	
	update_health_bar()

func update_health_bar() -> void:
	if not health_bar_container or not health_bar:
		return
	
	var health_percent = float(hp) / float(max_hp)
	health_percent = clamp(health_percent, 0.0, 1.0)
	
	# Scale bar down as health decreases
	health_bar.scale.x = health_percent
	health_bar.position.x = -(1.0 - health_percent) / 2.0 # Keep left-aligned
	
	# Update color (green -> yellow -> red)
	if health_percent > 0.6:
		health_bar.material_override.albedo_color = Color(0, 1, 0) # Green
	elif health_percent > 0.3:
		health_bar.material_override.albedo_color = Color(1, 1, 0) # Yellow
	else:
		health_bar.material_override.albedo_color = Color(1, 0, 0) # Red

func _find_mesh_instance(node: Node) -> MeshInstance3D:
	if node is MeshInstance3D:
		return node
	for child in node.get_children():
		var res = _find_mesh_instance(child)
		if res: return res
	return null

func _flash_on_hit() -> void:
	if not enemy_material or not mesh_instance:
		return
	
	# Flash to white with emission for brighter effect
	enemy_material.albedo_color = Color.WHITE
	enemy_material.emission_enabled = true
	enemy_material.emission = Color.WHITE
	enemy_material.emission_energy_multiplier = 2.0
	
	# Tween back to original color
	var tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(enemy_material, "albedo_color", original_color, 0.2).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	tween.tween_method(_set_emission_intensity, 2.0, 0.0, 0.2).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	tween.tween_callback(_disable_emission)

func _set_emission_intensity(intensity: float) -> void:
	if enemy_material:
		enemy_material.emission_energy_multiplier = intensity

func _disable_emission() -> void:
	if enemy_material:
		enemy_material.emission_enabled = false

func _process(_delta: float) -> void:
	# Make health bar face camera (billboard effect)
	if health_bar_container:
		var camera = get_viewport().get_camera_3d()
		if camera:
			health_bar_container.look_at(camera.global_position, Vector3.UP)
			health_bar_container.rotation.x = 0 # Keep upright

func _physics_process(delta: float) -> void:
	# Stop moving if game is over
	if not GameManager.is_game_active:
		velocity = Vector3.ZERO
		move_and_slide()
		return
	
	# Swarm logic
	var player = get_tree().get_first_node_in_group("SquadController")
	
	var direction = Vector3.ZERO
	
	if player:
		# Move towards player
		# We want to move towards their X, but generally towards +Z (since player moves -Z)
		# Wait, player moves -Z. Enemy spawns at e.g. -50.
		# Enemy should move +Z to meet player.
		# But also adjust X to match player X.
		
		var target_pos = player.global_position
		var my_pos = global_position
		
		# We only care about X tracking mainly, but we must move forward (Z) too.
		# Simple homing:
		direction = (target_pos - my_pos).normalized()
		
		# Enforce minimum Z speed so they don't just stop if they are sideways
		# Actually, pure homing is fine if speed is enough.
		# But we want them to definitely come "down" the screen.
		
		# Modify direction to prefer Z movement?
		# Let's just use direction.
		
	else:
		# Fallback if no player
		direction = Vector3(0, 0, 1)

	velocity.x = direction.x * move_speed
	velocity.z = direction.z * move_speed * 1.5 # Move faster in Z
	
	# If very close to player Z, maybe stop or slow down Z to avoid overshooting?
	# For now, simple collision logic will handle it.
	
	move_and_slide()
	
	# Face player
	if player:
		look_at(player.global_position, Vector3.UP)
		rotation.x = 0
	else:
		rotation.y = PI 
	
	if global_position.y < -10 or global_position.z > 20: # Clean up if passed player
		queue_free()

func take_damage(amount: int) -> void:
	hp -= amount
	hp = max(0, hp)
	update_health_bar()
	_flash_on_hit()
	if hp <= 0:
		die()

func die() -> void:
	match enemy_type:
		EnemyType.NORMAL:
			GameManager.add_score(10)
		EnemyType.LARGE:
			GameManager.add_score(30)
		EnemyType.GIANT:
			GameManager.add_score(100)
	queue_free()

func _on_hitbox_body_entered(body: Node3D) -> void:
	if body is Soldier:
		body.take_damage()
		# Enemy also dies on impact?
		take_damage(100)

