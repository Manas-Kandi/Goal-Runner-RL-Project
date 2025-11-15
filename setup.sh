#!/bin/bash

# Goal Runner RL Project Setup Script
# This script sets up the complete development environment

set -e  # Exit on any error

echo "🚀 Setting up Goal Runner RL Project..."

# Check if Python is installed
if ! command -v python3 &> /dev/null; then
    echo "❌ Python 3 is not installed. Please install Python 3.9+ first."
    exit 1
fi

# Check Python version
PYTHON_VERSION=$(python3 -c 'import sys; print(".".join(map(str, sys.version_info[:2])))')
REQUIRED_VERSION="3.9"

if [ "$(printf '%s\n' "$REQUIRED_VERSION" "$PYTHON_VERSION" | sort -V | head -n1)" != "$REQUIRED_VERSION" ]; then
    echo "❌ Python $PYTHON_VERSION is too old. Please install Python 3.9+"
    exit 1
fi

echo "✅ Python $PYTHON_VERSION detected"

# Create virtual environment
echo "📦 Creating virtual environment..."
python3 -m venv .venv

# Activate virtual environment
echo "🔌 Activating virtual environment..."
source .venv/bin/activate

# Upgrade pip
echo "⬆️ Upgrading pip..."
pip install --upgrade pip

# Install requirements
echo "📚 Installing Python dependencies..."
pip install -r requirements.txt

# Verify installation
echo "🔍 Verifying installation..."
python -c "
import godot_rl
import stable_baselines3
import torch
import gymnasium
import tensorboard
print('✅ All dependencies installed successfully!')
print(f'   godot-rl: {godot_rl.__version__}')
print(f'   stable-baselines3: {stable_baselines3.__version__}')
print(f'   torch: {torch.__version__}')
print(f'   gymnasium: {gymnasium.__version__}')
"

# Create necessary directories
echo "📁 Creating directories..."
mkdir -p rl/logs rl/models godot_env/bin

# Create default training config
echo "⚙️ Creating default training configuration..."
cat > rl/configs/default.yaml << EOF
training:
  total_timesteps: 100000
  learning_rate: 0.0003
  algorithm: "PPO"
  n_steps: 2048
  batch_size: 64
  n_epochs: 10
  gamma: 0.99
  gae_lambda: 0.95
  clip_range: 0.2
  ent_coef: 0.01
  vf_coef: 0.5
  max_grad_norm: 0.5
  seed: 42

environment:
  max_episode_steps: 200
  reward_scaling: 1.0
  timeout_penalty: 0.5

logging:
  tensorboard: true
  checkpoint_freq: 10000
  eval_freq: 5000
  n_eval_episodes: 10

model:
  policy: "MlpPolicy"
  activation_fn: "relu"
  net_arch: [64, 64]
EOF

echo "🎉 Setup completed successfully!"
echo ""
echo "📋 Next steps:"
echo "   1. Activate the virtual environment: source .venv/bin/activate"
echo "   2. Open godot_env/ in Godot editor and set up the scene"
echo "   3. Export the Godot binary"
echo "   4. Run training: python rl/stable_baselines3_example.py"
echo ""
echo "📖 For detailed instructions, see README.md"
