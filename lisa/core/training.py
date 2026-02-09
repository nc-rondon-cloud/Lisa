"""
LISA Training Module

Unified interface for training various ML models with monitoring and checkpointing.
"""

import numpy as np
import pandas as pd
from typing import Dict, Any, Optional, Tuple, Union
from pathlib import Path
import joblib
import json

# ML Libraries
from sklearn.model_selection import train_test_split
from sklearn.ensemble import RandomForestClassifier, RandomForestRegressor
from sklearn.linear_model import LogisticRegression, LinearRegression
from sklearn.svm import SVC, SVR

try:
    import xgboost as xgb
    HAS_XGBOOST = True
except ImportError:
    HAS_XGBOOST = False

try:
    import lightgbm as lgb
    HAS_LIGHTGBM = True
except ImportError:
    HAS_LIGHTGBM = False


class ModelTrainer:
    """Unified interface for training ML models"""

    SUPPORTED_MODELS = {
        'classification': [
            'random_forest', 'xgboost', 'lightgbm',
            'logistic_regression', 'svm'
        ],
        'regression': [
            'random_forest', 'xgboost', 'lightgbm',
            'linear_regression', 'svr'
        ]
    }

    def __init__(self, task_type: str = 'classification', random_seed: int = 42, verbose: bool = True):
        """
        Initialize trainer

        Args:
            task_type: 'classification' or 'regression'
            random_seed: Random seed for reproducibility
            verbose: Show progress bars and detailed logs
        """
        self.task_type = task_type
        self.random_seed = random_seed
        self.verbose = verbose
        self.model = None
        self.training_history = []

    def prepare_data(
        self,
        X: Union[pd.DataFrame, np.ndarray],
        y: Union[pd.Series, np.ndarray],
        test_size: float = 0.2,
        val_size: float = 0.1
    ) -> Tuple:
        """
        Prepare train/val/test splits

        Args:
            X: Features
            y: Target
            test_size: Test set proportion
            val_size: Validation set proportion (from train)

        Returns:
            Tuple of (X_train, X_val, X_test, y_train, y_val, y_test)
        """
        # First split: separate test set
        X_temp, X_test, y_temp, y_test = train_test_split(
            X, y,
            test_size=test_size,
            random_state=self.random_seed,
            stratify=y if self.task_type == 'classification' else None
        )

        # Second split: separate validation set from remaining data
        val_proportion = val_size / (1 - test_size)
        X_train, X_val, y_train, y_val = train_test_split(
            X_temp, y_temp,
            test_size=val_proportion,
            random_state=self.random_seed,
            stratify=y_temp if self.task_type == 'classification' else None
        )

        return X_train, X_val, X_test, y_train, y_val, y_test

    def create_model(
        self,
        model_type: str,
        params: Optional[Dict[str, Any]] = None
    ):
        """
        Create a model instance

        Args:
            model_type: Type of model to create
            params: Model hyperparameters

        Returns:
            Model instance
        """
        if params is None:
            params = {}

        # Add random seed
        if 'random_state' not in params:
            params['random_state'] = self.random_seed

        # Classification models
        if self.task_type == 'classification':
            if model_type == 'random_forest':
                return RandomForestClassifier(**params)

            elif model_type == 'xgboost':
                if not HAS_XGBOOST:
                    raise ImportError("XGBoost not installed")
                params.setdefault('use_label_encoder', False)
                params.setdefault('eval_metric', 'logloss')
                return xgb.XGBClassifier(**params)

            elif model_type == 'lightgbm':
                if not HAS_LIGHTGBM:
                    raise ImportError("LightGBM not installed")
                params.setdefault('verbose', -1)
                return lgb.LGBMClassifier(**params)

            elif model_type == 'logistic_regression':
                params.setdefault('max_iter', 1000)
                return LogisticRegression(**params)

            elif model_type == 'svm':
                params.setdefault('probability', True)  # For predict_proba
                return SVC(**params)

        # Regression models
        elif self.task_type == 'regression':
            if model_type == 'random_forest':
                return RandomForestRegressor(**params)

            elif model_type == 'xgboost':
                if not HAS_XGBOOST:
                    raise ImportError("XGBoost not installed")
                return xgb.XGBRegressor(**params)

            elif model_type == 'lightgbm':
                if not HAS_LIGHTGBM:
                    raise ImportError("LightGBM not installed")
                params.setdefault('verbose', -1)
                return lgb.LGBMRegressor(**params)

            elif model_type == 'linear_regression':
                return LinearRegression(**params)

            elif model_type == 'svr':
                return SVR(**params)

        raise ValueError(f"Unknown model_type: {model_type} for task: {self.task_type}")

    def train(
        self,
        model_type: str,
        X_train: Union[pd.DataFrame, np.ndarray],
        y_train: Union[pd.Series, np.ndarray],
        X_val: Optional[Union[pd.DataFrame, np.ndarray]] = None,
        y_val: Optional[Union[pd.Series, np.ndarray]] = None,
        params: Optional[Dict[str, Any]] = None,
        monitor: Optional[Any] = None,
        mlflow_mgr: Optional[Any] = None
    ) -> Dict[str, Any]:
        """
        Train a model

        Args:
            model_type: Type of model to train
            X_train: Training features
            y_train: Training target
            X_val: Validation features (optional)
            y_val: Validation target (optional)
            params: Model hyperparameters
            monitor: TrainingMonitor instance for logging
            mlflow_mgr: MLflowManager instance for experiment tracking

        Returns:
            Training results dictionary
        """
        from .callbacks import XGBoostProgressCallback, LightGBMProgressCallback, GenericProgressWrapper

        # Create model
        self.model = self.create_model(model_type, params)

        # Train with or without validation
        if X_val is not None and y_val is not None:
            # Models that support early stopping and callbacks
            if model_type in ['xgboost', 'lightgbm']:
                if model_type == 'xgboost':
                    # Get number of estimators for progress bar
                    n_estimators = params.get('n_estimators', 100) if params else 100

                    # Create progress callback if verbose
                    if self.verbose:
                        print(f"\n🚀 Starting XGBoost training ({n_estimators} rounds)...")
                        progress_callback = XGBoostProgressCallback(
                            total_rounds=n_estimators,
                            monitor=monitor,
                            mlflow_mgr=mlflow_mgr,
                            metric_name='logloss' if self.task_type == 'classification' else 'rmse'
                        )
                        custom_callbacks = [progress_callback]
                    else:
                        custom_callbacks = []

                    self.model.fit(
                        X_train, y_train,
                        eval_set=[(X_train, y_train), (X_val, y_val)],
                        verbose=False
                    )

                    if self.verbose and custom_callbacks:
                        # Close progress bar
                        progress_callback.close()

                    # Get training history from evals_result
                    results = self.model.evals_result()
                    self.training_history = results.get('validation_1', {})

                elif model_type == 'lightgbm':
                    # Get number of estimators for progress bar
                    n_estimators = params.get('n_estimators', 100) if params else 100

                    # Create progress callback if verbose
                    callbacks_list = [lgb.early_stopping(50), lgb.log_evaluation(0)]

                    if self.verbose:
                        print(f"\n🚀 Starting LightGBM training ({n_estimators} rounds)...")
                        progress_callback = LightGBMProgressCallback(
                            total_rounds=n_estimators,
                            monitor=monitor,
                            mlflow_mgr=mlflow_mgr,
                            metric_name='binary_logloss' if self.task_type == 'classification' else 'rmse'
                        )
                        callbacks_list.append(progress_callback)

                    self.model.fit(
                        X_train, y_train,
                        eval_set=[(X_train, y_train), (X_val, y_val)],
                        callbacks=callbacks_list
                    )

                    if self.verbose:
                        # Close progress bar
                        progress_callback.close()

                    # Get training history
                    self.training_history = self.model.evals_result_

            else:
                # Standard sklearn models with progress wrapper
                if self.verbose:
                    model_name = model_type.replace('_', ' ').title()
                    print(f"\n🤖 Training {model_name}...")
                    wrapper = GenericProgressWrapper(desc=model_name)
                    wrapper.train_with_progress(self.model, X_train, y_train)
                else:
                    self.model.fit(X_train, y_train)
        else:
            # Train without validation
            if self.verbose:
                model_name = model_type.replace('_', ' ').title()
                print(f"\n🤖 Training {model_name}...")
                wrapper = GenericProgressWrapper(desc=model_name)
                wrapper.train_with_progress(self.model, X_train, y_train)
            else:
                self.model.fit(X_train, y_train)

        # Evaluate on training data
        train_score = self.model.score(X_train, y_train)
        val_score = self.model.score(X_val, y_val) if X_val is not None else None

        results = {
            'model_type': model_type,
            'train_score': train_score,
            'val_score': val_score,
            'params': params or {},
            'training_history': self.training_history
        }

        return results

    def predict(self, X: Union[pd.DataFrame, np.ndarray]) -> np.ndarray:
        """Make predictions"""
        if self.model is None:
            raise ValueError("No model trained yet")

        return self.model.predict(X)

    def predict_proba(self, X: Union[pd.DataFrame, np.ndarray]) -> np.ndarray:
        """Get prediction probabilities (classification only)"""
        if self.model is None:
            raise ValueError("No model trained yet")

        if self.task_type != 'classification':
            raise ValueError("predict_proba only available for classification")

        if not hasattr(self.model, 'predict_proba'):
            raise ValueError(f"Model {type(self.model)} does not support predict_proba")

        return self.model.predict_proba(X)

    def get_feature_importance(
        self,
        feature_names: Optional[list] = None
    ) -> Optional[Dict[str, float]]:
        """
        Get feature importance

        Args:
            feature_names: Optional list of feature names

        Returns:
            Dictionary mapping feature names to importance values
        """
        if self.model is None:
            return None

        if hasattr(self.model, 'feature_importances_'):
            importances = self.model.feature_importances_

            if feature_names:
                return dict(zip(feature_names, importances))
            else:
                return {f"feature_{i}": imp for i, imp in enumerate(importances)}

        return None

    def save_checkpoint(
        self,
        path: Path,
        metadata: Optional[Dict[str, Any]] = None
    ):
        """
        Save model checkpoint

        Args:
            path: Path to save checkpoint
            metadata: Additional metadata to save
        """
        if self.model is None:
            raise ValueError("No model to save")

        path = Path(path)
        path.parent.mkdir(parents=True, exist_ok=True)

        # Save model
        model_path = path.with_suffix('.pkl')
        joblib.dump(self.model, model_path)

        # Save metadata
        checkpoint_data = {
            'task_type': self.task_type,
            'model_type': type(self.model).__name__,
            'training_history': self.training_history,
            'metadata': metadata or {}
        }

        metadata_path = path.with_suffix('.json')
        with open(metadata_path, 'w') as f:
            json.dump(checkpoint_data, f, indent=2)

    def load_checkpoint(self, path: Path):
        """
        Load model checkpoint

        Args:
            path: Path to checkpoint
        """
        path = Path(path)

        # Load model
        model_path = path.with_suffix('.pkl')
        self.model = joblib.load(model_path)

        # Load metadata
        metadata_path = path.with_suffix('.json')
        if metadata_path.exists():
            with open(metadata_path, 'r') as f:
                checkpoint_data = json.load(f)
                self.training_history = checkpoint_data.get('training_history', [])

    @staticmethod
    def get_default_params(model_type: str, task_type: str = 'classification') -> Dict[str, Any]:
        """
        Get default hyperparameters for a model type

        Args:
            model_type: Type of model
            task_type: 'classification' or 'regression'

        Returns:
            Dictionary of default parameters
        """
        defaults = {
            'random_forest': {
                'n_estimators': 100,
                'max_depth': None,
                'min_samples_split': 2,
                'min_samples_leaf': 1,
                'n_jobs': -1
            },
            'xgboost': {
                'n_estimators': 100,
                'max_depth': 6,
                'learning_rate': 0.1,
                'subsample': 0.8,
                'colsample_bytree': 0.8,
                'n_jobs': -1
            },
            'lightgbm': {
                'n_estimators': 100,
                'max_depth': -1,
                'learning_rate': 0.1,
                'num_leaves': 31,
                'n_jobs': -1
            },
            'logistic_regression': {
                'C': 1.0,
                'max_iter': 1000,
                'n_jobs': -1
            },
            'linear_regression': {
                'n_jobs': -1
            },
            'svm': {
                'C': 1.0,
                'kernel': 'rbf'
            },
            'svr': {
                'C': 1.0,
                'kernel': 'rbf'
            }
        }

        return defaults.get(model_type, {})

    def __repr__(self) -> str:
        model_name = type(self.model).__name__ if self.model else "None"
        return f"ModelTrainer(task={self.task_type}, model={model_name})"
