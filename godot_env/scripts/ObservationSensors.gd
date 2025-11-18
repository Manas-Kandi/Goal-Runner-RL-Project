extends Node2D
## Observation Sensors for Goal Runner RL Environment
## Generates 8-float observation vector with normalized values

# Sensor configuration
const SENSOR_RANGE = 100.0
const SENSOR_DIRECTIONS = [
	Vector2(0, -1),   # Up
	Vector2(0, 1),    # Down
	Vector2(-1, 0),   # Left
	Vector2(1, 0)     # Right
]

# Environment bounds (matching viewport)
var bounds_size = Vector2(800, 600)

# References
@onready var agent: CharacterBody2D = get_parent()
@onready var goal_area: Area2D = get_node("../../Goal")

func _ready():
	# Get viewport bounds
	var viewport = get_viewport()
	if viewport:
		bounds_size = viewport.get_visible_rect().size

func get_observation_vector() -> Array:
	"""
	Returns 8-float observation vector:
	[0-1]: Agent position (x, y) normalized [0, 1]
	[2-3]: Goal position (x, y) normalized [0, 1]
	[4-5]: Agent velocity (vx, vy) normalized [-1, 1]
	[6-9]: Wall distances (up, down, left, right) normalized [0, 1]
	"""
	var observation = []
	
	# Agent position (normalized to [0, 1])
	var agent_pos_norm = get_normalized_position(agent.global_position)
	observation.append(agent_pos_norm.x)
	observation.append(agent_pos_norm.y)
	
	# Goal position (normalized to [0, 1])
	if goal_area:
		var goal_pos_norm = get_normalized_position(goal_area.global_position)
		observation.append(goal_pos_norm.x)
		observation.append(goal_pos_norm.y)
	else:
		observation.append(0.5)
		observation.append(0.5)
	
	# Agent velocity (normalized to [-1, 1])
	var vel_norm = agent.get_normalized_velocity()
	observation.append(vel_norm.x)
	observation.append(vel_norm.y)
	
	# Wall distances (normalized to [0, 1])
	var wall_distances = get_wall_distances()
	for dist in wall_distances:
		observation.append(dist)
	
	# Validate observation
	if not validate_observation(observation):
		push_warning("Invalid observation detected, returning safe default")
		return get_safe_default_observation()
	
	return observation

func get_normalized_position(pos: Vector2) -> Vector2:
	"""Normalizes a position to [0, 1] based on viewport bounds"""
	if bounds_size.x > 0 and bounds_size.y > 0:
		return Vector2(
			clamp(pos.x / bounds_size.x, 0.0, 1.0),
			clamp(pos.y / bounds_size.y, 0.0, 1.0)
		)
	return Vector2(0.5, 0.5)

func get_wall_distances() -> Array:
	"""
	Uses raycasts to measure distance to nearest wall in 4 directions
	Returns normalized distances [0, 1] where 1.0 = max range, 0.0 = collision
	"""
	var distances = []
	var space_state = get_world_2d().direct_space_state
	
	for direction in SENSOR_DIRECTIONS:
		var query = PhysicsRayQueryParameters2D.create(
			agent.global_position,
			agent.global_position + direction * SENSOR_RANGE
		)
		query.collision_mask = 1  # Wall layer
		query.exclude = [agent]
		
		var result = space_state.intersect_ray(query)
		
		if result:
			var distance_to_wall = agent.global_position.distance_to(result.position)
			var normalized_distance = clamp(distance_to_wall / SENSOR_RANGE, 0.0, 1.0)
			distances.append(normalized_distance)
		else:
			# No collision, max distance
			distances.append(1.0)
	
	return distances

func validate_observation(obs: Array) -> bool:
	"""Validates observation vector for NaN, Inf, and correct bounds"""
	if obs.size() != 8:
		push_error("Observation size mismatch: expected 8, got " + str(obs.size()))
		return false
	
	for i in range(obs.size()):
		var val = obs[i]
		
		# Check for NaN or Inf
		if is_nan(val) or is_inf(val):
			push_error("Invalid value at index " + str(i) + ": " + str(val))
			return false
		
		# Check bounds
		if i < 2 or i >= 6:  # Position and distance values [0, 1]
			if val < 0.0 or val > 1.0:
				push_warning("Value out of bounds [0,1] at index " + str(i) + ": " + str(val))
				return false
		elif i >= 4 and i < 6:  # Velocity values [-1, 1]
			if val < -1.0 or val > 1.0:
				push_warning("Velocity out of bounds [-1,1] at index " + str(i) + ": " + str(val))
				return false
	
	return true

func get_safe_default_observation() -> Array:
	"""Returns a safe default observation when validation fails"""
	return [0.5, 0.5, 0.5, 0.5, 0.0, 0.0, 1.0, 1.0, 1.0, 1.0]

func _draw():
	if not agent:
		return
	
	# Debug visualization for distance sensors
	for i in range(SENSOR_DIRECTIONS.size()):
		var direction = SENSOR_DIRECTIONS[i]
		var color = Color.CYAN
		color.a = 0.3
		
		# Draw sensor ray
		draw_line(
			Vector2.ZERO,
			direction * SENSOR_RANGE,
			color,
			1.0
		)

func enable_debug_visualization(enabled: bool):
	"""Enable or disable debug ray visualization"""
	set_process(enabled)
	queue_redraw()
