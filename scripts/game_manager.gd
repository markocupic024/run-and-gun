extends Node

signal score_changed(new_score: int)
signal game_over

var score: int = 0
var is_game_active: bool = false

func _ready() -> void:
	pass

func start_game() -> void:
	score = 0
	is_game_active = true
	score_changed.emit(score)

func add_score(amount: int) -> void:
	if not is_game_active: return
	score += amount
	score_changed.emit(score)

func end_game() -> void:
	is_game_active = false
	game_over.emit()

