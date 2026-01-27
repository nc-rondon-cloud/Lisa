"""
LISA (Learning Intelligent Software Agent)

A dual-mode AI agent for software development and machine learning.

Modes:
  - Code: General software development and engineering
  - ML: Autonomous machine learning and data science

Core Modules:
  - config: Configuration management
  - diary: Structured documentation system
  - mlflow_manager: Experiment tracking and model management
  - core: ML-specific functionality (EDA, training, monitoring, stopping)
  - visualizer: Visualization generation
"""

__version__ = "2.0.0"
__author__ = "LISA Development Team"

from .config import Config, config
from .diary import Diary
from .mlflow_manager import MLflowManager, mlflow_manager

__all__ = [
    'Config',
    'config',
    'Diary',
    'MLflowManager',
    'mlflow_manager',
    '__version__',
]
