"""
LISA Configuration Management

Loads and manages configuration from lisa_config.yaml
"""

import os
import yaml
from pathlib import Path
from typing import Dict, Any, Optional


class Config:
    """Singleton configuration manager for LISA"""

    _instance: Optional['Config'] = None
    _config: Dict[str, Any] = {}
    _base_dir: Path = Path(".")

    def __new__(cls):
        if cls._instance is None:
            cls._instance = super().__new__(cls)
        return cls._instance

    def __init__(self):
        if not self._config:
            self.load_config()

    def load_config(self, config_path: Optional[str] = None):
        """Load configuration from YAML file"""
        if config_path is None:
            # Try to find lisa_config.yaml in current directory or parent
            config_path = self._find_config_file()

        if config_path and os.path.exists(config_path):
            with open(config_path, 'r') as f:
                self._config = yaml.safe_load(f)

            # Set base directory
            base_dir = self._config.get('project', {}).get('base_dir', '.')
            self._base_dir = Path(base_dir).resolve()
        else:
            # Use default configuration
            self._config = self._default_config()
            self._base_dir = Path(".").resolve()

    def _find_config_file(self) -> Optional[str]:
        """Find lisa_config.yaml in current or parent directories"""
        current = Path(".").resolve()

        # Check current directory
        config_file = current / "lisa_config.yaml"
        if config_file.exists():
            return str(config_file)

        # Check parent directory
        parent_config = current.parent / "lisa_config.yaml"
        if parent_config.exists():
            return str(parent_config)

        return None

    def _default_config(self) -> Dict[str, Any]:
        """Return default configuration"""
        return {
            'project': {
                'name': 'lisa-ml-project',
                'base_dir': '.'
            },
            'paths': {
                'data': 'data/',
                'diary': 'lisa/lisas_diary',
                'laboratory': 'lisa/lisas_laboratory',
                'mlruns': 'lisa/mlruns'
            },
            'mlflow': {
                'tracking_uri': 'file:./lisa/mlruns',
                'experiment_name': 'default-experiment'
            },
            'stopping_criteria': {
                'performance': {
                    'enabled': True,
                    'metric': 'f1_score',
                    'threshold': 0.90
                },
                'improvement': {
                    'enabled': True,
                    'min_improvement_percent': 1.0,
                    'window_size': 5
                },
                'convergence': {
                    'enabled': True,
                    'max_variance': 0.01,
                    'window_size': 10
                },
                'resources': {
                    'enabled': True,
                    'max_experiments': 50,
                    'max_time_hours': 24
                }
            },
            'data_science': {
                'large_dataset_threshold_mb': 500,
                'chunk_size_rows': 10000,
                'max_features_for_viz': 20,
                'random_seed': 42
            }
        }

    def get(self, key_path: str, default: Any = None) -> Any:
        """
        Get configuration value by dot-separated path

        Example:
            config.get('mlflow.experiment_name')
            config.get('stopping_criteria.performance.threshold')
        """
        keys = key_path.split('.')
        value = self._config

        for key in keys:
            if isinstance(value, dict) and key in value:
                value = value[key]
            else:
                return default

        return value

    def get_path(self, path_key: str) -> Path:
        """
        Get an absolute Path object for a configured path

        Example:
            config.get_path('data')  # Returns Path to data directory
            config.get_path('diary')  # Returns Path to lisas_diary
        """
        relative_path = self.get(f'paths.{path_key}', path_key)
        return (self._base_dir / relative_path).resolve()

    @property
    def project_name(self) -> str:
        """Get project name"""
        return self.get('project.name', 'lisa-ml-project')

    @property
    def random_seed(self) -> int:
        """Get random seed for reproducibility"""
        return self.get('data_science.random_seed', 42)

    @property
    def mlflow_tracking_uri(self) -> str:
        """Get MLflow tracking URI"""
        tracking_uri = self.get('mlflow.tracking_uri', 'file:./lisa/mlruns')

        # Convert relative file:// URIs to absolute paths
        if tracking_uri.startswith('file:'):
            path = tracking_uri[5:]  # Remove 'file:' prefix
            if not os.path.isabs(path):
                abs_path = (self._base_dir / path).resolve()
                tracking_uri = f'file:{abs_path}'

        return tracking_uri

    @property
    def mlflow_experiment_name(self) -> str:
        """Get MLflow experiment name"""
        return self.get('mlflow.experiment_name', 'default-experiment')

    def get_stopping_criteria(self) -> Dict[str, Any]:
        """Get all stopping criteria configuration"""
        return self.get('stopping_criteria', {})

    def __repr__(self) -> str:
        return f"Config(project={self.project_name}, base_dir={self._base_dir})"


# Global singleton instance
config = Config()
