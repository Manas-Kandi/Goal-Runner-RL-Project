extends Area2D
## Goal Detector for Goal Runner RL Environment
## Detects when the agent reaches the goal

signal goal_reached(agent)

@onready var sprite = $Sprite2D
@onready var collision_shape = $CollisionShape2D

# Visual settings
var base_color = Color(0.2, 0.8, 0.2)  # Green
var highlight_color = Color(0.4, 1.0, 0.4)  # Bright green
var pulse_speed = 2.0
var pulse_time = 0.0

func _ready():
	# Set collision layers
	collision_layer = 4  # Goal layer (layer 3)
	collision_mask = 2   # Detect agent (layer 2)
	
	# Connect body entered signal
	body_entered.connect(_on_body_entered)
	
	# Set initial color
	if sprite:
		sprite.modulate = base_color

func _process(delta):
	# Pulse animation
	pulse_time += delta * pulse_speed
	var pulse = (sin(pulse_time) + 1.0) / 2.0  # Normalized [0, 1]
	
	if sprite:
		sprite.modulate = base_color.lerp(highlight_color, pulse * 0.3)

func _on_body_entered(body):
	if body.is_in_group("agent") or body.has_method("get_observation"):
		goal_reached.emit(body)
		
		# Visual feedback
		if sprite:
			sprite.modulate = highlight_color
			# Reset after brief delay
			await get_tree().create_timer(0.1).timeout
			if sprite:
				sprite.modulate = base_color

func _draw():
	# Draw goal radius for debugging
	if Engine.is_editor_hint():
		draw_circle(Vector2.ZERO, 20, Color(0.2, 0.8, 0.2, 0.3))
