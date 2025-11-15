# Goal Runner RL Project

A 2D reinforcement learning navigation game built with Godot 4.x and StableBaselines3. Train an agent to navigate from start to goal while avoiding obstacles in a simple 2D environment.

## 🎯 Project Overview

**Goal Runner** is an educational reinforcement learning project that demonstrates the integration of Godot Engine with Python-based RL training. The agent learns to navigate a 2D environment using the PPO algorithm from StableBaselines3, communicating with Godot via the godot_rl_agents plugin.

### Key Features

- **2D Navigation Environment**: Simple top-down environment with walls and goals
- **Reinforcement Learning**: PPO-based training with StableBaselines3
- **Real-time Visualization**: Watch the agent learn and improve
- **Model Export**: Export trained models to ONNX for inference in Godot
- **Comprehensive Logging**: TensorBoard integration for training metrics
- **Cross-platform**: Support for macOS, Linux, and Windows

## 🏗️ Architecture

```
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│   Godot Engine  │    │  godot_rl_agents│    │ StableBaselines3│
│                 │    │     Plugin      │    │   (Python)      │
│ ┌─────────────┐ │    │ ┌─────────────┐ │    │ ┌─────────────┐ │
│ │GoalRunner   │ │◄──►│ │SyncNode     │ │◄──►│ │PPO Trainer  │ │
│ │Scene        │ │    │ │Interface    │ │    │ │             │ │
│ └─────────────┘ │    │ └─────────────┘ │    │ └─────────────┘ │
└─────────────────┘    └─────────────────┘    └─────────────────┘
```

## 🚀 Quick Start

### Prerequisites

- **Godot 4.2+** - Download from [godotengine.org](https://godotengine.org/)
- **Python 3.9+** - Ensure Python and pip are installed
- **Git** - For version control

### Setup (10 minutes)

1. **Clone the repository**
   ```bash
   git clone https://github.com/Manas-Kandi/Goal-Runner-RL-Project.git
   cd Goal-Runner-RL-Project
   ```

2. **Set up Python environment**
   ```bash
   python -m venv .venv
   source .venv/bin/activate  # On Windows: .venv\Scripts\activate
   pip install -r requirements.txt
   ```

3. **Verify installation**
   ```bash
   python -c "import godot_rl; import stable_baselines3; print('Setup successful!')"
   ```

### Training

1. **Export Godot environment** (after setting up the Godot project)
   ```bash
   # Open godot_env/project.godot in Godot editor
   # Project -> Export -> Export All
   ```

2. **Start training**
   ```bash
   python rl/stable_baselines3_example.py \
     --env_path=godot_env/bin/GoalRunner.x86_64 \
     --experiment_name=goal_runner_v1
   ```

3. **Monitor training**
   ```bash
   tensorboard --logdir=logs/
   ```

## 📁 Project Structure

```
9xf-firstAttempt/
├── godot_env/                 # Godot project files
│   ├── scenes/               # Scene files (.tscn)
│   ├── scripts/              # GDScript files (.gd)
│   ├── addons/               # Godot plugins
│   └── bin/                  # Exported binaries (generated)
├── rl/                       # Python training code
│   ├── configs/              # Training configurations
│   ├── logs/                 # TensorBoard logs (generated)
│   └── models/               # Trained models (generated)
├── docs/                     # Documentation
├── tests/                    # Test suite
├── requirements.txt          # Python dependencies
└── README.md                 # This file
```

## 🎮 Environment Details

### Observation Space (8 floats)
- Agent position (x, y) normalized to [0, 1]
- Goal position (x, y) normalized to [0, 1]
- Agent velocity (vx, vy) normalized to [-1, 1]
- Distance to nearest wall in 4 directions normalized to [0, 1]

### Action Space (5 discrete)
- 0: No-op/stand still
- 1: Move up
- 2: Move down
- 3: Move left
- 4: Move right

### Reward System
- +1.0 for reaching the goal
- -1.0 for hitting walls
- -0.01 per timestep (encourages efficiency)
- -0.5 for timeout (200 steps max)

## 🧪 Training Configuration

Default hyperparameters (configurable in `rl/configs/training.yaml`):

```yaml
training:
  total_timesteps: 100000
  learning_rate: 0.0003
  algorithm: "PPO"
  n_steps: 2048
  batch_size: 64

environment:
  max_episode_steps: 200
  reward_scaling: 1.0

logging:
  tensorboard: true
  checkpoint_freq: 10000
```

## 📊 Expected Results

- **Convergence**: Agent achieves >95% success rate within 100k timesteps
- **Performance**: Training speed >1000 steps/second
- **Efficiency**: Average steps to goal <50 after convergence
- **Memory**: Usage <1GB during training

## 🛠️ Development

### Running Tests
```bash
pytest tests/
```

### Code Style
- Python: Follow PEP 8
- GDScript: Follow Godot style guidelines
- Use type hints where applicable

### Contributing
1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Add tests for new functionality
5. Submit a pull request

## 📚 Documentation

- [Design Document](Design.md) - Detailed system architecture
- [Requirements](Requirements.md) - Functional and non-functional requirements
- [Tasks](Tasks.md) - Implementation roadmap
- [API Documentation](docs/api/) - Comprehensive API reference

## 🐛 Troubleshooting

### Common Issues

**Godot connection fails**
- Ensure Godot binary is exported correctly
- Check that port 12001 is not blocked
- Verify godot_rl_agents plugin is installed

**Training is slow**
- Disable visual effects in Godot during training
- Ensure you're using CPU training (no GPU required)
- Close unnecessary applications

**Import errors**
- Verify Python virtual environment is activated
- Check requirements.txt versions match your system
- Reinstall dependencies: `pip install -r requirements.txt --force-reinstall`

### Getting Help

- Check the [Issues](https://github.com/Manas-Kandi/Goal-Runner-RL-Project/issues) page
- Review the documentation in the `docs/` folder
- Join our community discussions

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## 🙏 Acknowledgments

- [godot_rl_agents](https://github.com/edbeeching/godot_rl_agents) - Godot RL integration
- [StableBaselines3](https://github.com/DLR-RM/stable-baselines3) - RL algorithms
- [Godot Engine](https://godotengine.org/) - Game engine framework

## 📈 Performance Metrics

| Metric | Target | Achieved |
|--------|--------|----------|
| Success Rate | >95% | TBD |
| Training Speed | >1000 steps/s | TBD |
| Memory Usage | <1GB | TBD |
| Setup Time | <10 minutes | ✓ |

---

**Note**: This is an educational project designed to demonstrate RL concepts. The environment is intentionally simple to focus on the integration between Godot and Python RL frameworks.
