"""
Training callbacks for progress tracking and monitoring.

This module provides callback classes for integrating tqdm progress bars
and logging with machine learning model training.
"""

from tqdm import tqdm
from typing import Optional, Any


class TqdmProgressCallback:
    """Base callback with tqdm progress bar."""

    def __init__(self, total_epochs: int, desc: str = "Training"):
        """
        Initialize progress callback.

        Args:
            total_epochs: Total number of epochs/iterations
            desc: Description to show in progress bar
        """
        self.pbar = tqdm(total=total_epochs, desc=desc, leave=True)
        self.current_epoch = 0

    def update(self, metrics: dict):
        """
        Update progress bar with metrics.

        Args:
            metrics: Dictionary of metrics to display
        """
        self.pbar.set_postfix(metrics)
        self.pbar.update(1)
        self.current_epoch += 1

    def close(self):
        """Close the progress bar."""
        self.pbar.close()


class XGBoostProgressCallback:
    """XGBoost callback with progress bar and logging."""

    def __init__(
        self,
        total_rounds: int,
        monitor: Optional[Any] = None,
        mlflow_mgr: Optional[Any] = None,
        metric_name: str = "metric"
    ):
        """
        Initialize XGBoost progress callback.

        Args:
            total_rounds: Total number of boosting rounds
            monitor: TrainingMonitor instance for logging
            mlflow_mgr: MLflowManager instance for experiment tracking
            metric_name: Name of the metric being tracked
        """
        self.pbar = tqdm(total=total_rounds, desc="XGBoost Training", leave=True)
        self.monitor = monitor
        self.mlflow_mgr = mlflow_mgr
        self.metric_name = metric_name
        self.iteration = 0

    def __call__(self, env):
        """
        Called by XGBoost after each iteration.

        Args:
            env: XGBoost environment with evaluation results
        """
        # XGBoost provides evaluation_result_list: [(dataset_name, metric_name, score), ...]
        # Typically: [('train', 'logloss', 0.5), ('val', 'logloss', 0.6)]
        if hasattr(env, 'evaluation_result_list') and len(env.evaluation_result_list) >= 2:
            # Get train and validation metrics
            train_metric = env.evaluation_result_list[0][2]  # (name, metric, score)
            val_metric = env.evaluation_result_list[1][2]

            # Update progress bar
            self.pbar.set_postfix({
                'train': f'{train_metric:.4f}',
                'val': f'{val_metric:.4f}'
            })
            self.pbar.update(1)

            # Log to monitor
            if self.monitor:
                self.monitor.log_epoch(
                    epoch=env.iteration,
                    train_metric=train_metric,
                    val_metric=val_metric,
                    verbose=False  # Progress bar shows metrics already
                )

            # Log to MLflow
            if self.mlflow_mgr:
                try:
                    self.mlflow_mgr.log_metric(f'train_{self.metric_name}', train_metric, step=env.iteration)
                    self.mlflow_mgr.log_metric(f'val_{self.metric_name}', val_metric, step=env.iteration)
                except Exception:
                    pass  # MLflow logging is optional

        self.iteration += 1

    def close(self):
        """Close the progress bar."""
        self.pbar.close()


class LightGBMProgressCallback:
    """LightGBM callback with progress bar and logging."""

    def __init__(
        self,
        total_rounds: int,
        monitor: Optional[Any] = None,
        mlflow_mgr: Optional[Any] = None,
        metric_name: str = "metric"
    ):
        """
        Initialize LightGBM progress callback.

        Args:
            total_rounds: Total number of boosting rounds
            monitor: TrainingMonitor instance for logging
            mlflow_mgr: MLflowManager instance for experiment tracking
            metric_name: Name of the metric being tracked
        """
        self.pbar = tqdm(total=total_rounds, desc="LightGBM Training", leave=True)
        self.monitor = monitor
        self.mlflow_mgr = mlflow_mgr
        self.metric_name = metric_name
        self.iteration = 0

    def __call__(self, env):
        """
        Called by LightGBM after each iteration.

        Args:
            env: LightGBM environment with evaluation results
        """
        # LightGBM provides evaluation_result_list similar to XGBoost
        # Format: [(dataset_name, metric_name, score, is_higher_better), ...]
        if hasattr(env, 'evaluation_result_list') and len(env.evaluation_result_list) >= 2:
            # Get train and validation metrics
            train_result = env.evaluation_result_list[0]
            val_result = env.evaluation_result_list[1]

            # Extract scores (handle different LightGBM versions)
            train_metric = train_result[2] if len(train_result) > 2 else train_result[1]
            val_metric = val_result[2] if len(val_result) > 2 else val_result[1]

            # Update progress bar
            self.pbar.set_postfix({
                'train': f'{train_metric:.4f}',
                'val': f'{val_metric:.4f}'
            })
            self.pbar.update(1)

            # Log to monitor
            if self.monitor:
                self.monitor.log_epoch(
                    epoch=env.iteration,
                    train_metric=train_metric,
                    val_metric=val_metric,
                    verbose=False  # Progress bar shows metrics already
                )

            # Log to MLflow
            if self.mlflow_mgr:
                try:
                    self.mlflow_mgr.log_metric(f'train_{self.metric_name}', train_metric, step=env.iteration)
                    self.mlflow_mgr.log_metric(f'val_{self.metric_name}', val_metric, step=env.iteration)
                except Exception:
                    pass  # MLflow logging is optional

        self.iteration += 1

    def close(self):
        """Close the progress bar."""
        self.pbar.close()


class GenericProgressWrapper:
    """Progress wrapper for models without native callbacks."""

    def __init__(self, desc: str = "Training"):
        """
        Initialize generic progress wrapper.

        Args:
            desc: Description for the progress bar
        """
        self.desc = desc

    def train_with_progress(self, model, X, y, stages: list = None):
        """
        Wrap training with progress indicator.

        Args:
            model: Model to train
            X: Training features
            y: Training labels
            stages: List of stage names to show during training

        Returns:
            Trained model
        """
        if stages is None:
            stages = ["Fitting"]

        with tqdm(total=len(stages), desc=self.desc, leave=True) as pbar:
            for stage in stages:
                pbar.set_description(f"{self.desc}: {stage}")

                if stage == "Fitting":
                    model.fit(X, y)

                pbar.update(1)

        return model


class ProgressBarManager:
    """Manager for coordinating multiple progress bars."""

    def __init__(self):
        """Initialize progress bar manager."""
        self.active_bars = []

    def add_bar(self, pbar):
        """
        Add a progress bar to track.

        Args:
            pbar: Progress bar instance
        """
        self.active_bars.append(pbar)

    def close_all(self):
        """Close all active progress bars."""
        for pbar in self.active_bars:
            if hasattr(pbar, 'close'):
                pbar.close()
        self.active_bars.clear()

    def __enter__(self):
        """Context manager entry."""
        return self

    def __exit__(self, exc_type, exc_val, exc_tb):
        """Context manager exit - cleanup all bars."""
        self.close_all()
        return False  # Don't suppress exceptions
