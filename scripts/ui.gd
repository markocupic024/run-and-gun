extends CanvasLayer

@onready var score_label: Label = $Control/ScoreLabel
@onready var game_over_panel: Panel = $Control/GameOverPanel
@onready var start_label: Label = $Control/StartLabel

func _ready() -> void:
	GameManager.score_changed.connect(_on_score_changed)
	GameManager.game_over.connect(_on_game_over)
	
	var btn = $Control/GameOverPanel/RestartButton
	btn.pressed.connect(_on_restart_pressed)
	
	game_over_panel.hide()
	score_label.text = "Score: 0"
	
	# Ideally, we hide StartLabel when game starts.
	# GameManager can emit signal or we check input in SquadController.
	
func _process(delta: float) -> void:
	if GameManager.is_game_active:
		start_label.hide()
	else:
		if not game_over_panel.visible:
			start_label.show()

func _on_score_changed(new_score: int) -> void:
	score_label.text = "Score: " + str(new_score)

func _on_game_over() -> void:
	game_over_panel.show()

func _on_restart_pressed() -> void:
	GameManager.start_game() # Reset state
	get_tree().reload_current_scene()

