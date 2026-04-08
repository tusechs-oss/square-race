extends Node2D

@export var speed := 300.0 # Tốc độ di chuyển chính
@export var orbit_radius := 50.0 # Bán kính vòng xoáy
@export var orbit_speed := 15.0 # Tốc độ xoáy vòng tròn
@export var lifetime := 5.0 # Thời gian tồn tại

var direction := Vector2.ZERO
var base_position := Vector2.ZERO
var time_passed := 0.0

@onready var anim_player = $Sprite2D/AnimationPlayer

func _ready() -> void:
	base_position = global_position
	if anim_player:
		anim_player.play("tornado")
	
	# Hiệu ứng Fade In khi vừa bắt đầu
	modulate.a = 0.0
	var tween_in = create_tween()
	tween_in.tween_property(self, "modulate:a", 1.0, 0.5)
	
	# Đợi gần hết lifetime thì thực hiện Fade Out và tự hủy
	var wait_time = lifetime - 0.5
	get_tree().create_timer(wait_time).timeout.connect(_start_fade_out)

func _start_fade_out() -> void:
	var tween_out = create_tween()
	tween_out.tween_property(self, "modulate:a", 0.0, 0.5)
	tween_out.finished.connect(queue_free)

func _process(delta: float) -> void:
	time_passed += delta
	# Xoay vòng vòng chậm hơn (3.0) và vòng tròn bé hơn (10px)
	var orbit_radius_tiny = 10.0
	var orbit_speed_slow = 3.0
	var offset = Vector2(
		cos(time_passed * orbit_speed_slow) * orbit_radius_tiny,
		sin(time_passed * orbit_speed_slow) * orbit_radius_tiny
	)
	global_position = base_position + offset
