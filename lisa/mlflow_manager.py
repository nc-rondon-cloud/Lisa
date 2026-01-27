"""
LISA MLflow Manager

Manages MLflow experiment tracking, logging, and model registry.
"""

import mlflow
from mlflow.tracking import MlflowClient
from mlflow.entities import ViewType
from typing import Dict, Any, List, Optional, Tuple
from pathlib import Path
from .config import config


class MLflowManager:
    """Manages MLflow operations for LISA"""

    def __init__(self):
        """Initialize MLflow manager with configuration"""
        self.tracking_uri = config.mlflow_tracking_uri
        self.experiment_name = config.mlflow_experiment_name

        # Set tracking URI
        mlflow.set_tracking_uri(self.tracking_uri)

        # Create or get experiment
        self.experiment = self._get_or_create_experiment()

        # Initialize client
        self.client = MlflowClient(tracking_uri=self.tracking_uri)

    def _get_or_create_experiment(self) -> mlflow.entities.Experiment:
        """Get existing experiment or create new one"""
        experiment = mlflow.get_experiment_by_name(self.experiment_name)

        if experiment is None:
            experiment_id = mlflow.create_experiment(
                self.experiment_name,
                tags={"created_by": "LISA", "version": "2026"}
            )
            experiment = mlflow.get_experiment(experiment_id)

        return experiment

    def start_run(
        self,
        run_name: Optional[str] = None,
        tags: Optional[Dict[str, str]] = None
    ) -> mlflow.ActiveRun:
        """
        Start a new MLflow run

        Args:
            run_name: Name for this run
            tags: Additional tags for the run

        Returns:
            Active MLflow run context
        """
        if tags is None:
            tags = {}

        tags.setdefault("created_by", "LISA")

        return mlflow.start_run(
            experiment_id=self.experiment.experiment_id,
            run_name=run_name,
            tags=tags
        )

    def log_params(self, params: Dict[str, Any]):
        """Log parameters to current run"""
        mlflow.log_params(params)

    def log_metrics(
        self,
        metrics: Dict[str, float],
        step: Optional[int] = None
    ):
        """
        Log metrics to current run

        Args:
            metrics: Dictionary of metric names and values
            step: Optional step number (for training curves)
        """
        mlflow.log_metrics(metrics, step=step)

    def log_metric(self, key: str, value: float, step: Optional[int] = None):
        """Log a single metric"""
        mlflow.log_metric(key, value, step=step)

    def log_artifact(self, file_path: str, artifact_path: Optional[str] = None):
        """
        Log an artifact file

        Args:
            file_path: Path to file to log
            artifact_path: Optional subdirectory in artifact store
        """
        mlflow.log_artifact(file_path, artifact_path=artifact_path)

    def log_artifacts(self, dir_path: str, artifact_path: Optional[str] = None):
        """
        Log all files in a directory

        Args:
            dir_path: Directory containing files to log
            artifact_path: Optional subdirectory in artifact store
        """
        mlflow.log_artifacts(dir_path, artifact_path=artifact_path)

    def log_model(
        self,
        model: Any,
        artifact_path: str,
        **kwargs
    ):
        """
        Log a model to MLflow

        Args:
            model: Model object to log
            artifact_path: Path within artifacts to store model
            **kwargs: Additional arguments (signature, input_example, etc.)
        """
        # Detect model type and use appropriate logging function
        model_type = type(model).__name__

        if 'sklearn' in str(type(model).__module__):
            mlflow.sklearn.log_model(model, artifact_path, **kwargs)
        elif 'xgboost' in str(type(model).__module__):
            mlflow.xgboost.log_model(model, artifact_path, **kwargs)
        elif 'lightgbm' in str(type(model).__module__):
            mlflow.lightgbm.log_model(model, **kwargs)
        elif 'torch' in str(type(model).__module__):
            mlflow.pytorch.log_model(model, artifact_path, **kwargs)
        else:
            # Fallback to generic Python model
            mlflow.pyfunc.log_model(artifact_path, python_model=model, **kwargs)

    def get_run(self, run_id: str) -> mlflow.entities.Run:
        """Get run by ID"""
        return self.client.get_run(run_id)

    def get_best_run(
        self,
        metric: str,
        mode: str = 'max',
        filter_string: str = ""
    ) -> Optional[mlflow.entities.Run]:
        """
        Get the best run based on a metric

        Args:
            metric: Metric name to optimize
            mode: 'max' or 'min'
            filter_string: Optional filter query

        Returns:
            Best run, or None if no runs found
        """
        order_by = [f"metrics.{metric} {'DESC' if mode == 'max' else 'ASC'}"]

        runs = self.client.search_runs(
            experiment_ids=[self.experiment.experiment_id],
            filter_string=filter_string,
            order_by=order_by,
            max_results=1
        )

        return runs[0] if runs else None

    def get_all_runs(
        self,
        filter_string: str = "",
        max_results: int = 1000
    ) -> List[mlflow.entities.Run]:
        """
        Get all runs for the current experiment

        Args:
            filter_string: Optional filter query
            max_results: Maximum number of runs to return

        Returns:
            List of runs
        """
        return self.client.search_runs(
            experiment_ids=[self.experiment.experiment_id],
            filter_string=filter_string,
            order_by=["start_time DESC"],
            max_results=max_results
        )

    def compare_runs(
        self,
        run_ids: List[str],
        metrics: Optional[List[str]] = None
    ) -> Dict[str, Dict[str, Any]]:
        """
        Compare multiple runs

        Args:
            run_ids: List of run IDs to compare
            metrics: Optional list of specific metrics to compare

        Returns:
            Dictionary mapping run_id to run info and metrics
        """
        comparison = {}

        for run_id in run_ids:
            run = self.get_run(run_id)

            run_data = {
                'run_name': run.data.tags.get('mlflow.runName', 'unnamed'),
                'start_time': run.info.start_time,
                'params': run.data.params,
                'metrics': {}
            }

            # Filter metrics if specified
            if metrics:
                for metric in metrics:
                    if metric in run.data.metrics:
                        run_data['metrics'][metric] = run.data.metrics[metric]
            else:
                run_data['metrics'] = run.data.metrics

            comparison[run_id] = run_data

        return comparison

    def load_model(self, run_id: str, artifact_path: str = "model"):
        """
        Load a model from a specific run

        Args:
            run_id: Run ID containing the model
            artifact_path: Path to model within artifacts

        Returns:
            Loaded model object
        """
        model_uri = f"runs:/{run_id}/{artifact_path}"
        return mlflow.pyfunc.load_model(model_uri)

    def register_model(
        self,
        run_id: str,
        model_name: str,
        artifact_path: str = "model"
    ) -> str:
        """
        Register a model in the MLflow Model Registry

        Args:
            run_id: Run ID containing the model
            model_name: Name to register the model under
            artifact_path: Path to model within artifacts

        Returns:
            Model version
        """
        model_uri = f"runs:/{run_id}/{artifact_path}"
        result = mlflow.register_model(model_uri, model_name)
        return result.version

    def get_experiment_stats(self) -> Dict[str, Any]:
        """
        Get statistics about the current experiment

        Returns:
            Dictionary with experiment statistics
        """
        runs = self.get_all_runs()

        if not runs:
            return {
                'total_runs': 0,
                'status': 'No runs yet'
            }

        # Calculate statistics
        total_runs = len(runs)
        finished_runs = sum(1 for r in runs if r.info.status == 'FINISHED')
        failed_runs = sum(1 for r in runs if r.info.status == 'FAILED')

        # Get common metrics across runs
        all_metrics = set()
        for run in runs:
            all_metrics.update(run.data.metrics.keys())

        # Get best values for each metric
        best_metrics = {}
        for metric in all_metrics:
            values = [r.data.metrics.get(metric) for r in runs if metric in r.data.metrics]
            if values:
                best_metrics[f"best_{metric}"] = max(values)

        return {
            'total_runs': total_runs,
            'finished_runs': finished_runs,
            'failed_runs': failed_runs,
            'running_runs': total_runs - finished_runs - failed_runs,
            'metrics_tracked': list(all_metrics),
            'best_metrics': best_metrics
        }

    def __repr__(self) -> str:
        return f"MLflowManager(experiment={self.experiment_name}, uri={self.tracking_uri})"


# Global instance
mlflow_manager = MLflowManager()
