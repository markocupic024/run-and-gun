class_name Gate
extends Area3D

enum Operation { ADD, SUBTRACT, MULTIPLY }

@export var operation: Operation = Operation.ADD
@export var value: int = 2
@export var is_convertible: bool = false # Gates that can be converted from negative to positive
@export var hits_to_convert: int = 3 # Number of hits needed to convert

@onready var label: Label3D = $Label3D
@onready var mesh: MeshInstance3D = $MeshInstance3D

var triggered = false
var paired_gate: Gate = null
var hit_count: int = 0
var original_abs_value: int = 0 # Store original absolute value for flipping

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	area_entered.connect(_on_area_entered) # Detect projectiles
	update_visuals()

func update_visuals() -> void:
	if not label or not mesh: return
	
	var text_str = ""
	var color = Color.GREEN
	
	match operation:
		Operation.ADD:
			text_str = "+" + str(value)
			color = Color(0.2, 0.8, 0.2, 0.5) # Green
		Operation.SUBTRACT:
			text_str = "-" + str(value)
			color = Color(0.8, 0.2, 0.2, 0.5) # Red
		Operation.MULTIPLY:
			# Display as multiplier (value 12-18 = 1.2x-1.8x)
			var multiplier = value / 10.0
			if multiplier == int(multiplier):
				text_str = "x" + str(int(multiplier))
			else:
				text_str = "x" + str(multiplier)
			color = Color(0.2, 0.4, 0.8, 0.5) # Blue
			
	if operation == Operation.ADD and value < 0:
		color = Color(0.8, 0.2, 0.2, 0.5)
		
	label.text = text_str
	
	var mat = StandardMaterial3D.new()
	mat.albedo_color = color
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mesh.material_override = mat

func _on_area_entered(area: Area3D) -> void:
	# Detect projectile hits for convertible gates
	if is_convertible and area is Projectile:
		# Incrementally increase value by 1 per shot: -4 → -3 → -2 → -1 → 0 → +1 → +2 → +3 → +4
		value += 1
		if value == 0:
			# When it reaches 0, switch to ADD operation
			operation = Operation.ADD
		elif value > 0 and operation != Operation.ADD:
			# Ensure it stays as ADD once positive
			operation = Operation.ADD
		update_visuals()
		area.queue_free() # Destroy the projectile

func _on_body_entered(body: Node3D) -> void:
	if triggered: return
	
	var squad: SquadController = null
	if body is Soldier:
		squad = body.get_parent() as SquadController
	elif body is SquadController:
		squad = body
		
	if squad:
		triggered = true
		apply_effect(squad)
		# Remove paired gate if it exists
		if is_instance_valid(paired_gate):
			paired_gate.queue_free()
		queue_free()

func apply_effect(squad: SquadController) -> void:
	var squad_size = squad.get_squad_size()
	
	match operation:
		Operation.ADD:
			if value > 0:
				# Stronger diminishing returns: effectiveness decreases more aggressively as squad grows
				# Formula: actual = base * (1 / (1 + squad_size / 10))
				# At 10 soldiers: ~50% effectiveness
				# At 20 soldiers: ~33% effectiveness
				# At 30 soldiers: ~25% effectiveness
				var effectiveness = 1.0 / (1.0 + squad_size / 10.0)
				var actual_value = max(1, int(value * effectiveness))
				squad.add_soldiers(actual_value)
			else: 
				squad.remove_soldiers(abs(value))
		Operation.SUBTRACT:
			squad.remove_soldiers(value)
		Operation.MULTIPLY:
			# Value stored as percentage (12-18 = 1.2x-1.8x)
			# Convert to multiplier: 12 = 1.2x, 18 = 1.8x
			var multiplier = value / 10.0
			# Stronger diminishing returns on multiply: effectiveness decreases more aggressively
			var effectiveness = 1.0 / (1.0 + squad_size / 15.0)
			var adjusted_factor = 1.0 + (multiplier - 1.0) * effectiveness
			# Apply adjusted multiply
			var current = squad_size
			var target = int(current * adjusted_factor)
			squad.add_soldiers(target - current)

