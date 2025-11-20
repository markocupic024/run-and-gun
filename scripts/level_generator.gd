class_name LevelGenerator
extends Node3D

@export var chunk_length: float = 20.0
@export var view_distance_chunks: int = 6

var chunk_scene = preload("res://scenes/chunk.tscn")
var gate_scene = preload("res://scenes/gate.tscn")
var enemy_scene = preload("res://scenes/enemy.tscn")

var player: Node3D
var current_z: float = 0.0
var active_chunks: Array[Node3D] = []
var chunks_spawned: int = 0
var last_gate_chunk: int = -1
var gate_spacing: int = 6 # Gates every 6 chunks (with variation)

func _process(delta: float) -> void:
	if not is_instance_valid(player):
		player = get_tree().get_first_node_in_group("SquadController")
		if not player: return
		
	# Player moves in -Z.
	# We spawn ahead (more negative Z)
	var player_z = player.global_position.z
	var generate_threshold = player_z - (view_distance_chunks * chunk_length)
	
	while current_z > generate_threshold:
		spawn_chunk()
		
	# Cleanup old chunks (behind player)
	var cleanup_threshold = player_z + chunk_length * 2
	if active_chunks.size() > 0:
		var first = active_chunks[0]
		# The logic here depends on spawn order.
		# spawn_chunk decrements current_z.
		# The first chunk in array is the closest to start (Z=0).
		# As player moves -Z, first chunk (Z=0) is behind.
		if first.global_position.z > cleanup_threshold:
			active_chunks.pop_front()
			first.queue_free()

func spawn_chunk() -> void:
	var c = chunk_scene.instantiate()
	add_child(c)
	c.global_position.z = current_z
	active_chunks.append(c)
	
	spawn_obstacles(c)
	chunks_spawned += 1
	
	current_z -= chunk_length

func get_difficulty_zone() -> String:
	# Returns: "early", "mid", or "late"
	if chunks_spawned < 10:
		return "early"
	elif chunks_spawned < 25:
		return "mid"
	else:
		return "late"

func spawn_obstacles(chunk: Node3D) -> void:
	# Safe zone: First 2 chunks always have gates
	if chunks_spawned < 2:
		spawn_gates(chunk)
		last_gate_chunk = chunks_spawned
		return
	
	var zone = get_difficulty_zone()
	
	# Early game: More gates, including convertible ones
	if zone == "early":
		# In early game, spawn gates more frequently (every 3-4 chunks)
		var chunks_since_gate = chunks_spawned - last_gate_chunk
		if chunks_since_gate >= 3 and chunks_since_gate <= 4:
			if chunks_since_gate >= 3 or randf() < 0.5:
				spawn_gates(chunk, true) # More convertible gates in early game
				last_gate_chunk = chunks_spawned
				return
	
	# Consistent gate spacing: every 6 chunks (with 5-7 variation)
	var chunks_since_gate = chunks_spawned - last_gate_chunk
	if chunks_since_gate >= gate_spacing - 1 and chunks_since_gate <= gate_spacing + 1:
		# Randomize within range
		if chunks_since_gate >= gate_spacing or (chunks_since_gate >= gate_spacing - 1 and randf() < 0.3):
			spawn_gates(chunk, zone == "early")
			last_gate_chunk = chunks_spawned
			gate_spacing = randi_range(5, 7) # Next gate in 5-7 chunks
			return
	
	# Spawn enemies in waves
	spawn_enemies(chunk)

func spawn_gates(chunk: Node3D, prefer_convertible: bool = false) -> void:
	# Spawn at -10 (center of chunk)
	var z_offset = -10
	
	# Wider spacing for larger gates
	var gate_spacing = 4.5
	
	var g1 = gate_scene.instantiate() as Gate
	chunk.add_child(g1)
	g1.transform.origin = Vector3(-gate_spacing, 0, z_offset)
	setup_gate(g1, prefer_convertible)
	
	var g2 = gate_scene.instantiate() as Gate
	chunk.add_child(g2)
	g2.transform.origin = Vector3(gate_spacing, 0, z_offset)
	setup_gate(g2, prefer_convertible)
	
	# Link gates together so selecting one removes the other
	g1.paired_gate = g2
	g2.paired_gate = g1

func setup_gate(g: Gate, prefer_convertible: bool = false) -> void:
	# Most gates should be convertible (80% chance overall, 90% in early game)
	var convertible_chance = 0.9 if prefer_convertible else 0.8
	
	if randf() < convertible_chance:
		g.is_convertible = true
		g.operation = Gate.Operation.ADD
		
		# Get player squad size to scale gate values
		var squad = get_tree().get_first_node_in_group("SquadController") as SquadController
		var squad_size = 1
		if squad:
			squad_size = squad.get_squad_size()
		
		# Scale negative value based on squad size - gentle early, aggressive later
		# Base value 2-4 for early game, scales up with squad size
		# Formula: base_value * (1 + squad_size / 4) - starts gentle, ramps up
		var base_val = randi_range(2, 4)
		var scaled_val = int(base_val * (1.0 + squad_size / 4.0))
		# Ensure minimum of 2 for very early game
		scaled_val = max(2, scaled_val)
		# Cap at reasonable maximum (e.g., 200)
		scaled_val = min(scaled_val, 200)
		
		var abs_val = scaled_val
		g.value = -abs_val # Start negative
		g.original_abs_value = abs_val # Store for flipping
		g.hits_to_convert = abs_val # Not used anymore but kept for compatibility
		g.update_visuals()
		return
	
	# Regular gates (20% chance)
	var op = randi() % 3
	g.operation = op
	
	# Gate.Operation is enum 0=ADD, 1=SUBTRACT, 2=MULTIPLY
	# Reduced values for less power
	if op == 0:
		g.value = randi_range(1, 2) # Further reduced from 1-3
	elif op == 1:
		g.value = randi_range(1, 3)
	elif op == 2:
		g.value = randi_range(12, 18) # Reduced multiplier (12-18 = 1.2x-1.8x)
		
	g.update_visuals()

func get_enemy_count_for_zone(zone: String) -> int:
	# Base enemy count
	var base_count: int
	match zone:
		"early":
			base_count = randi_range(3, 6)
		"mid":
			base_count = randi_range(5, 9)
		"late":
			base_count = randi_range(8, 12)
		_:
			base_count = 6
	
	# Scale with player squad size to balance growth
	var squad = get_tree().get_first_node_in_group("SquadController") as SquadController
	if squad:
		var squad_size = squad.get_squad_size()
		# More enemies spawn as player grows: base * (1 + squad_size / 15)
		var scale_factor = 1.0 + (squad_size / 15.0)
		base_count = int(base_count * scale_factor)
	
	return base_count

func get_large_enemy_chance(zone: String) -> float:
	match zone:
		"early":
			return 0.05 # 5% large
		"mid":
			return 0.15 # 15% large
		"late":
			return 0.2 # 20% large (reduced because GIANT takes some)
		_:
			return 0.15

func get_giant_enemy_chance(zone: String) -> float:
	match zone:
		"early":
			return 0.0 # No giants in early game
		"mid":
			return 0.02 # 2% giants in mid game
		"late":
			return 0.08 # 8% giants in late game
		_:
			return 0.0

func generate_wave_positions(count: int, pattern: String) -> Array[Vector3]:
	var positions: Array[Vector3] = []
	var z_offset = -10 # Center of chunk
	var lane_width = 8.0 # Total width for enemies
	var spacing = 1.2 # Space between enemies
	
	match pattern:
		"single_line":
			# Single horizontal line
			var start_x = -lane_width / 2
			var step = lane_width / max(1, count - 1)
			for i in range(count):
				var x = start_x + (i * step)
				positions.append(Vector3(x, 0.5, z_offset))
				
		"double_line":
			# Two rows
			var per_row = count / 2
			var start_x = -lane_width / 2
			var step = lane_width / max(1, per_row - 1)
			for i in range(count):
				var row = i / per_row
				var col = i % per_row
				var x = start_x + (col * step)
				var z = z_offset + (row * -2.0) # Second row slightly behind
				positions.append(Vector3(x, 0.5, z))
				
		"staggered":
			# Alternating positions
			var start_x = -lane_width / 2
			var step = lane_width / max(1, count - 1)
			for i in range(count):
				var x = start_x + (i * step)
				var z = z_offset + (sin(i * 2.0) * 1.5) # Slight stagger
				positions.append(Vector3(x, 0.5, z))
				
		"v_formation":
			# V shape
			var center = count / 2
			for i in range(count):
				var offset = i - center
				var x = offset * spacing
				var z = z_offset + abs(offset) * 0.8 # V shape depth
				positions.append(Vector3(x, 0.5, z))
				
		_:
			# Default: single line
			var start_x = -lane_width / 2
			var step = lane_width / max(1, count - 1)
			for i in range(count):
				var x = start_x + (i * step)
				positions.append(Vector3(x, 0.5, z_offset))
	
	return positions

func get_wave_pattern(zone: String, chunk_num: int) -> String:
	# Pattern selection based on zone and chunk
	var patterns = ["single_line", "double_line", "staggered", "v_formation"]
	
	match zone:
		"early":
			# Early: mostly simple patterns
			if chunk_num % 3 == 0:
				return "double_line"
			else:
				return "single_line"
		"mid":
			# Mid: mix of patterns
			return patterns[chunk_num % patterns.size()]
		"late":
			# Late: more complex patterns
			if chunk_num % 4 == 0:
				return "v_formation"
			elif chunk_num % 3 == 0:
				return "double_line"
			else:
				return "staggered"
		_:
			return "single_line"

func spawn_enemies(chunk: Node3D) -> void:
	var zone = get_difficulty_zone()
	var count = get_enemy_count_for_zone(zone)
	var large_chance = get_large_enemy_chance(zone)
	var giant_chance = get_giant_enemy_chance(zone)
	var pattern = get_wave_pattern(zone, chunks_spawned)
	
	var positions = generate_wave_positions(count, pattern)
	
	for i in range(positions.size()):
		var e = enemy_scene.instantiate() as Enemy
		
		# Determine enemy type BEFORE adding to scene
		# Check GIANT first, then LARGE, then NORMAL
		var rand = randf()
		if rand < giant_chance:
			e.enemy_type = Enemy.EnemyType.GIANT
		elif rand < giant_chance + large_chance:
			e.enemy_type = Enemy.EnemyType.LARGE
		else:
			e.enemy_type = Enemy.EnemyType.NORMAL
		
		chunk.add_child(e)
		# Setup the enemy type after adding (in case _ready already ran)
		e.setup_enemy_type()
		e._tint_enemy() # Also update tint
		
		e.transform.origin = positions[i]

