extends CharacterBody2D
## Agent Controller for Goal Runner RL Environment
## Handles movement, observations, rewards, and episode management

# Movement constants
const MOVE_SPEED = 200.0

# Action mapping (5 discrete actions)
const ACTION_VELOCITIES = {
	0: Vector2(0, 0),    # No-op
	1: Vector2(0, -1),   # Up
	2: Vector2(0, 1),    # Down
	3: Vector2(-1, 0),   # Left
	4: Vector2(1, 0)     # Right
}

# Reward constants
const GOAL_REWARD = 1.0
const WALL_PENALTY = -1.0
const STEP_PENALTY = -0.01
const TIMEOUT_PENALTY = -0.5

# Episode management
const MAX_EPISODE_STEPS = 200
const SPAWN_REGION = Rect2(50, 50, 200, 400)
const GOAL_POSITIONS = [
	Vector2(700, 250),
	Vector2(700, 350),
	Vector2(650, 300)
]

# State variables
var current_action = 0
var episode_reward = 0.0
var steps_in_episode = 0
var episode_done = false
var collision_detected = false

# References
@onready var goal_area: Area2D = get_node("../Goal")
@onready var observation_sensors = $ObservationSensors
@onready var sprite = $Sprite2D
@onready var camera = $Camera2D

# Debug visualization
var debug_draw_enabled = true
var wall_collision_this_frame = false

func _ready():
	# Set collision layers
	collision_layer = 2  # Agent layer
	collision_mask = 1   # Collide with walls
	
	# Initialize episode
	reset_episode()
	
	# Connect goal detection
	if goal_area:
		goal_area.body_entered.connect(_on_goal_reached)

func _physics_process(delta):
	if episode_done:
		return
	
	# Apply action-based movement
	var direction = ACTION_VELOCITIES.get(current_action, Vector2.ZERO)
	velocity = direction * MOVE_SPEED
	
	# Move and detect collisions
	var collision = move_and_collide(velocity * delta)
	wall_collision_this_frame = collision != null
	
	# Calculate reward
	var reward = calculate_reward()
	episode_reward += reward
	
	# Increment step counter
	steps_in_episode += 1
	
	# Check timeout
	if steps_in_episode >= MAX_EPISODE_STEPS:
		episode_done = true
		episode_reward += TIMEOUT_PENALTY
	
	# Debug visualization
	if debug_draw_enabled:
		queue_redraw()

func _draw():
	if not debug_draw_enabled:
		return
	
	# Draw velocity arrow
	if velocity.length() > 0:
		draw_line(Vector2.ZERO, velocity.normalized() * 30, Color.GREEN, 2.0)
	
	# Draw collision indicator
	if wall_collision_this_frame:
		draw_circle(Vector2.ZERO, 25, Color.RED, false, 3.0)

func calculate_reward() -> float:
	var reward = STEP_PENALTY
	
	# Check wall collision
	if wall_collision_this_frame:
		reward += WALL_PENALTY
		episode_done = true
	
	return reward

func _on_goal_reached(body):
	if body == self:
		episode_reward += GOAL_REWARD
		episode_done = true

func set_action(action: int):
	"""Called by RL agent to set the next action"""
	if action >= 0 and action < ACTION_VELOCITIES.size():
		current_action = action
	else:
		push_warning("Invalid action received: " + str(action))
		current_action = 0

func get_observation() -> Array:
	"""Returns 8-float observation vector"""
	if observation_sensors:
		return observation_sensors.get_observation_vector()
	return [0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0]

func get_reward() -> float:
	"""Returns the current episode reward"""
	return episode_reward

func is_done() -> bool:
	"""Returns whether the episode is complete"""
	return episode_done

func reset_episode():
	"""Resets the episode to a random starting configuration"""
	# Random agent spawn
	var random_spawn = Vector2(
		randf_range(SPAWN_REGION.position.x, SPAWN_REGION.position.x + SPAWN_REGION.size.x),
		randf_range(SPAWN_REGION.position.y, SPAWN_REGION.position.y + SPAWN_REGION.size.y)
	)
	global_position = random_spawn
	
	# Random goal position
	if goal_area:
		var goal_pos = GOAL_POSITIONS[randi() % GOAL_POSITIONS.size()]
		goal_area.global_position = goal_pos
	
	# Reset episode variables
	episode_reward = 0.0
	steps_in_episode = 0
	episode_done = false
	current_action = 0
	velocity = Vector2.ZERO
	wall_collision_this_frame = false
	
	# Visual feedback
	if sprite:
		sprite.modulate = Color.WHITE

func get_normalized_velocity() -> Vector2:
	"""Returns velocity normalized to [-1, 1]"""
	if MOVE_SPEED > 0:
		return Vector2(
			clamp(velocity.x / MOVE_SPEED, -1.0, 1.0),
			clamp(velocity.y / MOVE_SPEED, -1.0, 1.0)
		)
	return Vector2.ZERO

func get_episode_stats() -> Dictionary:
	"""Returns episode statistics for logging"""
	return {
		"steps": steps_in_episode,
		"reward": episode_reward,
		"done": episode_done,
		"success": episode_done and episode_reward > 0.9
	}
