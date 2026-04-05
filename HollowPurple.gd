extends Node2D

@export var speed := 150.0
@export var damage := 1
@export var life_time := 5.0

var direction := Vector2.RIGHT
var shooter: Node2D = null

func _ready():
	get_tree().create_timer(life_time).timeout.connect(queue_free)
	# Hiệu ứng quay nhẹ cho đẹp
	var tween = create_tween().set_loops()
	tween.tween_property(self, "rotation", PI * 2, 2.0).as_relative()

func _physics_process(delta):
	position += direction * speed * delta

func _on_area_2d_body_entered(body):
	if body.is_in_group("Player") and body != shooter:
		if body.has_method("apply_damage"):
			body.apply_damage(damage)
		# Hollow Purple đi xuyên qua mọi thứ
