class_name Projectile
extends Area3D

@export var speed: float = 30.0
@export var damage: int = 1

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	# Auto destroy after 0.8 seconds (shorter range)
	await get_tree().create_timer(0.8).timeout
	queue_free()

func _process(delta: float) -> void:
	global_position += -transform.basis.z * speed * delta

func _on_body_entered(body: Node3D) -> void:
	if body.has_method("take_damage"):
		body.take_damage(damage)
		queue_free()

