extends Area2D

@export var target_group := "Player"
@export var keep_shape_centered := true

@onready var _shape = get_node_or_null("CollisionShape2D")

func _ready() -> void:
	monitoring = true
	monitorable = true
	if keep_shape_centered and _shape:
		_shape.position = Vector2.ZERO
