import os
import yaml
from pathlib import Path
from typing import Dict, Any

class Config:
    _instance = None
    _config = None

    def __new__(cls):
        if cls._instance is None:
            cls._instance = super().__new__(cls)
        return cls._instance

    def __init__(self):
        if self._config is None:
            self._load_config()

    def _load_config(self):
        """Load configuration from YAML file."""
        config_path = os.getenv('CONFIG_PATH', 'config/config.yaml')
        
        try:
            with open(config_path, 'r') as f:
                self._config = yaml.safe_load(f)
                
            # Override with environment variables
            self._override_from_env()
        except Exception as e:
            raise RuntimeError(f"Failed to load configuration: {str(e)}")

    def _override_from_env(self):
        """Override configuration values from environment variables."""
        for key in os.environ:
            if key.startswith('EBAYSEO_'):
                # Convert EBAYSEO_DATABASE_HOST to ['database', 'host']
                config_path = key.replace('EBAYSEO_', '').lower().split('_')
                self._set_nested_value(self._config, config_path, os.environ[key])

    def _set_nested_value(self, config: Dict, path: list, value: Any):
        """Set a nested dictionary value using a path list."""
        current = config
        for part in path[:-1]:
            current = current.setdefault(part, {})
        current[path[-1]] = value

    def get(self, *keys, default=None):
        """Get a configuration value using dot notation."""
        current = self._config
        for key in keys:
            if isinstance(current, dict) and key in current:
                current = current[key]
            else:
                return default
        return current

# Global configuration instance
config = Config()