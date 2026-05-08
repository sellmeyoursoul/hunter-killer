extends RigidBody2D

@export var isHostile = true

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	add_to_group(&"mobs")
	var mob_animations: Array[StringName] = [&"fly", &"swim", &"walk"]
	$AnimatedSprite2D.animation = mob_animations.pick_random()
	$AnimatedSprite2D.play()
	
func _on_visible_on_screen_notifier_2d_screen_exited():
	queue_free()


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass
