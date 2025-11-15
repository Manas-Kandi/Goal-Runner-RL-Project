@echo off
REM Goal Runner RL Project Setup Script for Windows
REM This script sets up the complete development environment

echo 🚀 Setting up Goal Runner RL Project...

REM Check if Python is installed
python --version >nul 2>&1
if %errorlevel% neq 0 (
    echo ❌ Python 3 is not installed. Please install Python 3.9+ first.
    pause
    exit /b 1
)

echo ✅ Python detected

REM Create virtual environment
echo 📦 Creating virtual environment...
python -m venv .venv

REM Activate virtual environment
echo 🔌 Activating virtual environment...
call .venv\Scripts\activate.bat

REM Upgrade pip
echo ⬆️ Upgrading pip...
python -m pip install --upgrade pip

REM Install requirements
echo 📚 Installing Python dependencies...
pip install -r requirements.txt

REM Verify installation
echo 🔍 Verifying installation...
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

REM Create necessary directories
echo 📁 Creating directories...
if not exist rl\logs mkdir rl\logs
if not exist rl\models mkdir rl\models
if not exist godot_env\bin mkdir godot_env\bin

REM Create default training config
echo ⚙️ Creating default training configuration...
(
echo training:
echo   total_timesteps: 100000
echo   learning_rate: 0.0003
echo   algorithm: "PPO"
echo   n_steps: 2048
echo   batch_size: 64
echo   n_epochs: 10
echo   gamma: 0.99
echo   gae_lambda: 0.95
echo   clip_range: 0.2
echo   ent_coef: 0.01
echo   vf_coef: 0.5
echo   max_grad_norm: 0.5
echo   seed: 42
echo.
echo environment:
echo   max_episode_steps: 200
echo   reward_scaling: 1.0
echo   timeout_penalty: 0.5
echo.
echo logging:
echo   tensorboard: true
echo   checkpoint_freq: 10000
echo   eval_freq: 5000
echo   n_eval_episodes: 10
echo.
echo model:
echo   policy: "MlpPolicy"
echo   activation_fn: "relu"
echo   net_arch: [64, 64]
) > rl\configs\default.yaml

echo.
echo 🎉 Setup completed successfully!
echo.
echo 📋 Next steps:
echo    1. Activate the virtual environment: .venv\Scripts\activate.bat
echo    2. Open godot_env\ in Godot editor and set up the scene
echo    3. Export the Godot binary
echo    4. Run training: python rl\stable_baselines3_example.py
echo.
echo 📖 For detailed instructions, see README.md
pause
