# Design: Goal Runner RL Project

## 1. System Architecture Overview

### 1.1 High-Level Architecture
```
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│   Godot Engine  │    │  godot_rl_agents│    │ StableBaselines3│
│                 │    │     Plugin      │    │   (Python)      │
│ ┌─────────────┐ │    │ ┌─────────────┐ │    │ ┌─────────────┐ │
│ │GoalRunner   │ │◄──►│ │SyncNode     │ │◄──►│ │PPO Trainer  │ │
│ │Scene        │ │    │ │Interface    │ │    │ │             │ │
│ └─────────────┘ │    │ └─────────────┘ │    │ └─────────────┘ │
│                 │    │                 │    │                 │
│ ┌─────────────┐ │    │ ┌─────────────┐ │    │ ┌─────────────┐ │
│ │Agent+Walls  │ │    │ │Observation  │ │    │ │Environment  │ │
│ │Physics      │ │    │ │Buffer       │ │    │ │Wrapper      │ │
│ └─────────────┘ │    │ └─────────────┘ │    │ └─────────────┘ │
└─────────────────┘    └─────────────────┘    └─────────────────┘
```

### 1.2 Communication Flow
1. **Godot → Python**: Observations (8 floats), reward signal, done flag
2. **Python → Godot**: Action (integer 0-4), reset commands
3. **Protocol**: TCP/IP via godot_rl_agents plugin (default port 12001)
4. **Frequency**: 60 FPS physics sync (configurable)

## 2. Godot Environment Design

### 2.1 Scene Hierarchy
```
GoalRunner (Node2D)
├── Environment (Node2D)
│   ├── Walls (StaticBody2D)
│   │   ├── Wall_1 (CollisionShape2D)
│   │   ├── Wall_2 (CollisionShape2D)
│   │   └── Wall_N (CollisionShape2D)
│   └── Goal (Area2D)
│       ├── CollisionShape2D
│       └── GoalDetector (Script)
├── Agent (CharacterBody2D)
│   ├── CollisionShape2D
│   ├── Sprite2D
│   ├── AgentController (Script)
│   └── Camera2D (Follow)
├── GdrlSyncNode (SyncNode) [from plugin]
│   ├── SyncNodeScript (Script)
│   └── ObservationSensors (Node)
│       ├── PositionSensor (Node)
│       ├── VelocitySensor (Node)
│       └── DistanceSensors (Node4)
└── UI (CanvasLayer)
    ├── TrainingInfo (Label)
    └── EpisodeCounter (Label)
```

### 2.2 Physics Configuration
```gdscript
# Physics settings (Project Settings)
physics/2d/default_gravity = Vector2(0, 0)
physics/2d/default_linear_damp = 10.0
physics/2d/default_angular_damp = 1.0
physics/common/physics_ticks_per_second = 60
```

### 2.3 Agent Movement System
```gdscript
# AgentController.gd
extends CharacterBody2D

const MOVE_SPEED = 200.0
const ACTION_VELOCITIES = {
    0: Vector2(0, 0),    # No-op
    1: Vector2(0, -1),   # Up
    2: Vector2(0, 1),    # Down
    3: Vector2(-1, 0),   # Left
    4: Vector2(1, 0)     # Right
}

var current_action = 0

func _physics_process(delta):
    var direction = ACTION_VELOCITIES[current_action]
    velocity = direction * MOVE_SPEED
    move_and_collide(velocity * delta)
```

### 2.4 Observation System Design

#### 2.4.1 Position Normalization
```gdscript
func get_normalized_position(pos: Vector2) -> Vector2:
    var bounds = get_viewport().get_visible_rect().size
    return Vector2(
        pos.x / bounds.x,
        pos.y / bounds.y
    )
```

#### 2.4.2 Velocity Normalization
```gdscript
func get_normalized_velocity(vel: Vector2) -> Vector2:
    return Vector2(
        clamp(vel.x / MOVE_SPEED, -1.0, 1.0),
        clamp(vel.y / MOVE_SPEED, -1.0, 1.0)
    )
```

#### 2.4.3 Distance Sensors Implementation
```gdscript
# Raycast sensors for wall distances
const SENSOR_RANGES = [100.0, 100.0, 100.0, 100.0]  # Up, Down, Left, Right
const SENSOR_DIRECTIONS = [
    Vector2(0, -1), Vector2(0, 1), Vector2(-1, 0), Vector2(1, 0)
]

func get_wall_distances() -> Array[float]:
    var distances = []
    for i in range(4):
        var space_state = get_world_2d().direct_space_state
        var query = PhysicsRaycastQueryParameters2D.create(
            global_position,
            global_position + SENSOR_DIRECTIONS[i] * SENSOR_RANGES[i],
            collision_mask = 1  # Wall layer
        )
        var result = space_state.intersect_ray(query)
        if result:
            distances.append(result.position.distance_to(global_position) / SENSOR_RANGES[i])
        else:
            distances.append(1.0)
    return distances
```

### 2.5 Reward System Implementation

#### 2.5.1 Reward Calculation Logic
```gdscript
# Reward constants
const GOAL_REWARD = 1.0
const WALL_PENALTY = -1.0
const STEP_PENALTY = -0.01
const TIMEOUT_PENALTY = -0.5

var episode_reward = 0.0
var steps_in_episode = 0
const MAX_EPISODE_STEPS = 200

func calculate_reward() -> float:
    var reward = STEP_PENALTY
    steps_in_episode += 1
    
    # Check goal reached
    if goal_detector.is_overlapping_body(self):
        reward += GOAL_REWARD
        episode_done = true
    
    # Check wall collision
    if get_slide_collision_count() > 0:
        reward += WALL_PENALTY
        episode_done = true
    
    # Check timeout
    if steps_in_episode >= MAX_EPISODE_STEPS:
        reward += TIMEOUT_PENALTY
        episode_done = true
    
    episode_reward += reward
    return reward
```

#### 2.5.2 Reward Shaping Strategy
- **Sparse rewards**: Primary reward only on goal/wall collision
- **Dense shaping**: Small step penalty encourages efficiency
- **Termination rewards**: Clear success/failure signals
- **Expected reward range**: [-1.0, +1.0] per episode

### 2.6 Episode Management System

#### 2.6.1 Reset Logic
```gdscript
const SPAWN_REGION = Rect2(50, 50, 200, 400)
const GOAL_POSITIONS = [
    Vector2(700, 250), Vector2(700, 350), Vector2(650, 300)
]

func reset_episode():
    # Reset agent position
    var random_spawn = Vector2(
        randf_range(SPAWN_REGION.position.x, SPAWN_REGION.position.x + SPAWN_REGION.size.x),
        randf_range(SPAWN_REGION.position.y, SPAWN_REGION.position.y + SPAWN_REGION.size.y)
    )
    global_position = random_spawn
    
    # Reset goal position
    goal.global_position = GOAL_POSITIONS[randi() % GOAL_POSITIONS.size()]
    
    # Reset episode variables
    episode_reward = 0.0
    steps_in_episode = 0
    episode_done = false
    current_action = 0
```

## 3. Python Training Architecture

### 3.1 Environment Wrapper Design
```python
# stable_baselines3_example.py (modified)
from godot_rl.wrappers.stable_baselines_wrapper import StableBaselinesGodotEnv
from stable_baselines3 import PPO
from stable_baselines3.common.callbacks import CheckpointCallback
from stable_baselines3.common.vec_env import VecMonitor

class GoalRunnerEnv(StableBaselinesGodotEnv):
    def __init__(self, env_path: str, **kwargs):
        super().__init__(env_path, **kwargs)
        self.observation_space = gym.spaces.Box(
            low=0.0, high=1.0, shape=(8,), dtype=np.float32
        )
        self.action_space = gym.spaces.Discrete(5)
    
    def step(self, action):
        obs, reward, done, truncated, info = super().step(action)
        # Validate observation ranges
        assert np.all(obs >= 0.0) and np.all(obs <= 1.0), "Observation out of bounds"
        return obs, reward, done or truncated, info
```

### 3.2 Training Configuration
```python
# Hyperparameter configuration
TRAINING_CONFIG = {
    "total_timesteps": 100_000,
    "learning_rate": 3e-4,
    "n_steps": 2048,
    "batch_size": 64,
    "n_epochs": 10,
    "gamma": 0.99,
    "gae_lambda": 0.95,
    "clip_range": 0.2,
    "ent_coef": 0.01,
    "vf_coef": 0.5,
    "max_grad_norm": 0.5,
    "seed": 42
}

# PPO model initialization
model = PPO(
    "MlpPolicy",
    env,
    tensorboard_log="./logs/",
    verbose=1,
    **TRAINING_CONFIG
)
```

### 3.3 Callback System
```python
class GoalRunnerCallback(BaseCallback):
    def __init__(self, eval_freq: int = 5000, **kwargs):
        super().__init__(**kwargs)
        self.eval_freq = eval_freq
    
    def _on_step(self) -> bool:
        if self.n_calls % self.eval_freq == 0:
            # Evaluate current policy
            mean_reward, std_reward = evaluate_policy(
                self.model, self.training_env, n_eval_episodes=10
            )
            self.logger.record("eval/mean_reward", mean_reward)
            self.logger.record("eval/std_reward", std_reward)
        return True
```

### 3.4 Model Export Pipeline
```python
# ONNX export for inference
def export_for_inference(model, output_path: str):
    from godot_rl.wrappers.onnx.stable_baselines_export import export_model_as_onnx
    export_model_as_onnx(
        model,
        output_path,
        input_shape=(1, 8),  # Batch size 1, 8 observations
        output_shape=(1,)    # Single action output
    )
```

## 4. Data Flow & Communication Protocol

### 4.1 Message Protocol
```
┌─────────────────┐    Message Format    ┌─────────────────┐
│   Godot Side    │ ──────────────────► │   Python Side   │
│                 │                     │                 │
│ Observation:    │                     │                 │
│ [agent_x,       │                     │                 │
│  agent_y,       │                     │                 │
│  goal_x,        │                     │                 │
│  goal_y,        │                     │                 │
│  vel_x,         │                     │                 │
│  vel_y,         │                     │                 │
│  dist_up,       │                     │                 │
│  dist_down,     │                     │                 │
│  dist_left,     │                     │                 │
│  dist_right]    │                     │                 │
│                 │                     │                 │
│ Reward: float   │                     │                 │
│ Done: bool      │                     │                 │
└─────────────────┘                     └─────────────────┘

┌─────────────────┐    Message Format    ┌─────────────────┐
│   Python Side   │ ◄────────────────── │   Godot Side    │
│                 │                     │                 │
│ Action: int     │                     │                 │
│ (0-4)           │                     │                 │
│ Reset: bool     │                     │                 │
└─────────────────┘                     └─────────────────┘
```

### 4.2 Timing & Synchronization
- **Physics tick**: 60 Hz (16.67ms per step)
- **Network buffer**: 100ms timeout for communication
- **Observation latency**: <5ms target
- **Action latency**: <5ms target
- **Frame drop handling**: Buffer up to 3 frames

### 4.3 Error Handling Protocol
```python
# Python side error handling
try:
    obs, reward, done, info = env.step(action)
except ConnectionError:
    logger.error("Lost connection to Godot environment")
    env.restart_connection()
except ValueError as e:
    logger.error(f"Invalid observation: {e}")
    env.reset()
```

```gdscript
# Godot side error handling
func _on_connection_error():
    print("Connection to Python lost, attempting reconnection...")
    sync_node.restart_server()

func _on_invalid_action(action_id):
    print("Warning: Received invalid action ", action_id)
    current_action = 0  # Default to no-op
```

## 5. Performance Optimization

### 5.1 Godot Optimization
- **Physics optimization**: Use `move_and_collide` instead of `move_and_slide` for simple movement
- **Rendering optimization**: Disable unnecessary visual effects during training
- **Memory management**: Pool objects instead of frequent instantiation
- **LOD system**: Simplify collision geometry for distance sensors

### 5.2 Python Optimization
- **Vectorization**: NumPy operations for observation processing
- **Batch processing**: StableBaselines3 handles batching automatically
- **Memory efficiency**: Use float32 instead of float64 where possible
- **Parallel environments**: VecEnv for multiple instances (future extension)

### 5.3 Network Optimization
- **Compression**: Delta encoding for observations
- **Batching**: Send multiple steps per message when possible
- **Protocol**: Use TCP for reliability, consider UDP for speed (future)
- **Local optimization**: Use localhost to minimize network latency

## 6. Critical Implementation Details

### 6.1 Sync Node Configuration
```gdscript
# GdrlSyncNode configuration
func _ready():
    # Observation space setup
    observation_size = 8
    action_space_size = 5
    
    # Network settings
    port = 12001
    timeout_ms = 5000
    
    # Training mode
    speedup = 1.0  # Real-time by default
    
    # Initialize connection
    start_server(port, timeout_ms)
```

### 6.2 Action-Observation Mapping
```python
# Python side action mapping
ACTION_MAP = {
    0: "NO_OP",
    1: "MOVE_UP", 
    2: "MOVE_DOWN",
    3: "MOVE_LEFT",
    4: "MOVE_RIGHT"
}

# Godot side action handling
func handle_action(action_id: int):
    match action_id:
        0: current_action = 0  # No-op
        1: current_action = 1  # Up
        2: current_action = 2  # Down
        3: current_action = 3  # Left
        4: current_action = 4  # Right
        _::
            print("Invalid action received: ", action_id)
            current_action = 0
```

### 6.3 State Management
```gdscript
# Episode state tracking
enum EpisodeState {
    RUNNING,
    SUCCESS,
    FAILURE,
    TIMEOUT
}

var current_state = EpisodeState.RUNNING
var episode_start_time = 0.0
var episode_data = {
    "steps": 0,
    "reward": 0.0,
    "success": false,
    "start_pos": Vector2.ZERO,
    "goal_pos": Vector2.ZERO
}
```

## 7. Testing & Validation Strategy

### 7.1 Unit Testing
- **Observation validation**: Test range bounds and normalization
- **Action validation**: Test action mapping and movement
- **Reward calculation**: Test reward logic for all scenarios
- **Episode management**: Test reset and termination conditions

### 7.2 Integration Testing
- **End-to-end training**: Full training pipeline validation
- **Model export/import**: ONNX compatibility testing
- **Performance benchmarks**: Speed and memory validation
- **Cross-platform testing**: macOS, Linux, Windows compatibility

### 7.3 Regression Testing
- **Learning curve validation**: Ensure training converges
- **Model stability**: Test across multiple random seeds
- **Hyperparameter sensitivity**: Test parameter ranges
- **Environment robustness**: Test edge cases and error conditions

## 8. Security & Safety Considerations

### 8.1 Network Security
- **Local only**: Bind to localhost by default
- **Authentication**: Simple token-based auth (future)
- **Rate limiting**: Prevent message flooding
- **Input validation**: Validate all incoming data

### 8.2 Code Safety
- **Memory bounds**: Check array access and buffer sizes
- **Type safety**: Strong typing in Python, GDScript validation
- **Resource limits**: Prevent infinite loops and memory leaks
- **Error isolation**: Handle exceptions gracefully

## 9. Future Extensibility

### 9.1 Architecture Extensions
- **Multi-agent support**: Multiple agents in same environment
- **3D environments**: Extend to 3D physics and rendering
- **Curriculum learning**: Progressive difficulty scaling
- **Hierarchical RL**: Multi-level decision making

### 9.2 Algorithm Extensions
- **Alternative algorithms**: DQN, SAC, A2C support
- **Multi-objective**: Multiple reward signals
- **Imitation learning**: Demonstration-based training
- **Transfer learning**: Pre-trained model adaptation

### 9.3 Platform Extensions
- **Web deployment**: HTML5 export with WebGPU inference
- **Mobile deployment**: iOS/Android compatibility
- **Cloud training**: Distributed training support
- **Edge inference**: Optimized model deployment

## 10. Documentation & Maintenance

### 10.1 Code Documentation
- **API docs**: Comprehensive function documentation
- **Architecture docs**: System design and data flow
- **Tutorial docs**: Step-by-step setup and usage
- **Troubleshooting**: Common issues and solutions

### 10.2 Maintenance Strategy
- **Version management**: Semantic versioning and compatibility
- **Testing automation**: CI/CD pipeline integration
- **Performance monitoring**: Benchmark tracking over time
- **Community support**: Issue tracking and contribution guidelines
