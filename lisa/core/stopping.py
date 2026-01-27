"""
LISA Stopping Criteria Module

Multi-level stopping criteria for ML experiments:
- Level 1: Early stopping (within single training run)
- Level 2: Experiment stopping (single experiment)
- Level 3: Campaign stopping (entire experimentation campaign)
"""

import numpy as np
from typing import Dict, Any, List, Optional, Tuple
from datetime import datetime, timedelta
from ..config import config


class StoppingCriteria:
    """Manages stopping criteria at multiple levels"""

    def __init__(self, criteria_config: Optional[Dict[str, Any]] = None):
        """
        Initialize stopping criteria

        Args:
            criteria_config: Configuration dictionary. If None, uses config from lisa_config.yaml
        """
        if criteria_config is None:
            criteria_config = config.get_stopping_criteria()

        self.config = criteria_config
        self.campaign_start_time = datetime.now()

    def should_stop_training(
        self,
        monitor: 'TrainingMonitor',
        patience: Optional[int] = None
    ) -> Tuple[bool, str]:
        """
        Level 1: Determine if a single training run should stop (early stopping)

        Args:
            monitor: TrainingMonitor instance
            patience: Override patience from monitor

        Returns:
            Tuple of (should_stop: bool, reasoning: str)
        """
        return monitor.should_stop()

    def should_stop_experiment(
        self,
        metrics: Dict[str, float],
        experiment_time_minutes: Optional[float] = None
    ) -> Tuple[bool, str, str]:
        """
        Level 2: Determine if an individual experiment should stop

        Args:
            metrics: Dictionary of metrics from the experiment
            experiment_time_minutes: Time taken by experiment (minutes)

        Returns:
            Tuple of (should_stop: bool, reasoning: str, next_action: str)
        """
        reasons = []

        # Check performance threshold
        perf_config = self.config.get('performance', {})
        if perf_config.get('enabled', False):
            metric_name = perf_config.get('metric')
            threshold = perf_config.get('threshold')

            if metric_name in metrics:
                metric_value = metrics[metric_name]

                if metric_value >= threshold:
                    return (
                        True,
                        f"Performance threshold achieved: {metric_name}={metric_value:.4f} >= {threshold}",
                        "STOP_CAMPAIGN"
                    )

        # If no stopping criteria met, continue
        return False, "Experiment completed successfully", "CONTINUE"

    def should_stop_campaign(
        self,
        experiment_history: List[Dict[str, Any]],
        current_time: Optional[datetime] = None
    ) -> Tuple[bool, str, str]:
        """
        Level 3: Determine if entire experimentation campaign should stop

        Args:
            experiment_history: List of experiment results (each with metrics, params, etc.)
            current_time: Current timestamp (for testing)

        Returns:
            Tuple of (should_stop: bool, reasoning: str, next_action: str)

        next_action can be:
            - STOP: Stop all experimentation
            - CONTINUE: Continue with next experiment
            - TRY_DIFFERENT_MODEL: Current approach isn't working
        """
        if not experiment_history:
            return False, "No experiments yet", "CONTINUE"

        if current_time is None:
            current_time = datetime.now()

        reasons = []

        # 1. Check performance threshold
        perf_config = self.config.get('performance', {})
        if perf_config.get('enabled', False):
            metric_name = perf_config.get('metric')
            threshold = perf_config.get('threshold')

            # Check if any experiment achieved the threshold
            for exp in experiment_history:
                metrics = exp.get('metrics', {})
                if metric_name in metrics and metrics[metric_name] >= threshold:
                    return (
                        True,
                        f"Target performance achieved: {metric_name}={metrics[metric_name]:.4f} >= {threshold}",
                        "STOP"
                    )

        # 2. Check improvement rate
        improvement_config = self.config.get('improvement', {})
        if improvement_config.get('enabled', False):
            min_improvement_pct = improvement_config.get('min_improvement_percent', 1.0)
            window_size = improvement_config.get('window_size', 5)

            if len(experiment_history) >= window_size:
                should_stop, reason = self._check_improvement_rate(
                    experiment_history,
                    min_improvement_pct,
                    window_size
                )
                if should_stop:
                    return True, reason, "TRY_DIFFERENT_MODEL"

        # 3. Check convergence
        convergence_config = self.config.get('convergence', {})
        if convergence_config.get('enabled', False):
            max_variance = convergence_config.get('max_variance', 0.01)
            window_size = convergence_config.get('window_size', 10)

            if len(experiment_history) >= window_size:
                should_stop, reason = self._check_convergence(
                    experiment_history,
                    max_variance,
                    window_size
                )
                if should_stop:
                    return True, reason, "STOP"

        # 4. Check resource limits
        resource_config = self.config.get('resources', {})
        if resource_config.get('enabled', False):
            # Check max experiments
            max_experiments = resource_config.get('max_experiments')
            if max_experiments and len(experiment_history) >= max_experiments:
                return (
                    True,
                    f"Maximum experiments reached: {len(experiment_history)} >= {max_experiments}",
                    "STOP"
                )

            # Check max time
            max_hours = resource_config.get('max_time_hours')
            if max_hours:
                elapsed = (current_time - self.campaign_start_time).total_seconds() / 3600
                if elapsed >= max_hours:
                    return (
                        True,
                        f"Maximum time exceeded: {elapsed:.1f}h >= {max_hours}h",
                        "STOP"
                    )

        return False, "Continue experimentation", "CONTINUE"

    def _check_improvement_rate(
        self,
        experiment_history: List[Dict[str, Any]],
        min_improvement_pct: float,
        window_size: int
    ) -> Tuple[bool, str]:
        """Check if improvement rate is below threshold"""
        # Get metric name from config
        metric_name = self.config.get('performance', {}).get('metric', 'f1_score')

        # Get recent experiments
        recent = experiment_history[-window_size:]

        # Extract metric values
        metric_values = []
        for exp in recent:
            metrics = exp.get('metrics', {})
            if metric_name in metrics:
                metric_values.append(metrics[metric_name])

        if len(metric_values) < 2:
            return False, "Not enough data for improvement check"

        # Calculate improvements
        improvements = []
        for i in range(1, len(metric_values)):
            if metric_values[i-1] > 0:
                improvement_pct = ((metric_values[i] - metric_values[i-1]) / metric_values[i-1]) * 100
                improvements.append(improvement_pct)

        # Check if all recent improvements are below threshold
        if improvements and all(imp < min_improvement_pct for imp in improvements):
            return (
                True,
                f"Low improvement rate: all improvements < {min_improvement_pct}% in last {window_size} experiments"
            )

        return False, "Improvement rate acceptable"

    def _check_convergence(
        self,
        experiment_history: List[Dict[str, Any]],
        max_variance: float,
        window_size: int
    ) -> Tuple[bool, str]:
        """Check if performance has converged"""
        # Get metric name from config
        metric_name = self.config.get('performance', {}).get('metric', 'f1_score')

        # Get recent experiments
        recent = experiment_history[-window_size:]

        # Extract metric values
        metric_values = []
        for exp in recent:
            metrics = exp.get('metrics', {})
            if metric_name in metrics:
                metric_values.append(metrics[metric_name])

        if len(metric_values) < window_size:
            return False, "Not enough data for convergence check"

        # Calculate variance
        variance = np.var(metric_values)

        if variance < max_variance:
            return (
                True,
                f"Performance converged: variance {variance:.6f} < {max_variance} over {window_size} experiments"
            )

        return False, f"Not converged: variance {variance:.6f} >= {max_variance}"

    def evaluate_performance_threshold(
        self,
        best_metric: float,
        threshold: float
    ) -> bool:
        """Check if performance threshold is met"""
        return best_metric >= threshold

    def evaluate_improvement_rate(
        self,
        recent_experiments: List[Dict[str, Any]],
        min_improvement: float,
        window: int
    ) -> bool:
        """Check if improvement rate is acceptable"""
        should_stop, _ = self._check_improvement_rate(
            recent_experiments,
            min_improvement,
            window
        )
        return not should_stop  # Return True if improvement is acceptable

    def evaluate_convergence(
        self,
        recent_experiments: List[Dict[str, Any]],
        max_variance: float,
        window: int
    ) -> bool:
        """Check if performance has converged"""
        should_stop, _ = self._check_convergence(
            recent_experiments,
            max_variance,
            window
        )
        return should_stop

    def evaluate_resource_limits(
        self,
        start_time: datetime,
        num_experiments: int,
        config: Optional[Dict[str, Any]] = None
    ) -> Tuple[bool, List[str]]:
        """
        Check if resource limits are exceeded

        Returns:
            Tuple of (limits_exceeded: bool, reasons: List[str])
        """
        if config is None:
            config = self.config.get('resources', {})

        reasons = []

        # Check experiments
        max_experiments = config.get('max_experiments')
        if max_experiments and num_experiments >= max_experiments:
            reasons.append(f"Max experiments: {num_experiments} >= {max_experiments}")

        # Check time
        max_hours = config.get('max_time_hours')
        if max_hours:
            elapsed_hours = (datetime.now() - start_time).total_seconds() / 3600
            if elapsed_hours >= max_hours:
                reasons.append(f"Max time: {elapsed_hours:.1f}h >= {max_hours}h")

        return len(reasons) > 0, reasons

    def get_best_experiment(
        self,
        experiment_history: List[Dict[str, Any]],
        metric_name: Optional[str] = None
    ) -> Optional[Dict[str, Any]]:
        """
        Get the best experiment based on metric

        Args:
            experiment_history: List of experiments
            metric_name: Metric to optimize (if None, uses config)

        Returns:
            Best experiment dictionary
        """
        if not experiment_history:
            return None

        if metric_name is None:
            metric_name = self.config.get('performance', {}).get('metric', 'f1_score')

        # Filter experiments with the metric
        valid_experiments = [
            exp for exp in experiment_history
            if metric_name in exp.get('metrics', {})
        ]

        if not valid_experiments:
            return None

        # Find best
        best = max(
            valid_experiments,
            key=lambda exp: exp['metrics'][metric_name]
        )

        return best

    def generate_stopping_report(
        self,
        experiment_history: List[Dict[str, Any]]
    ) -> Dict[str, Any]:
        """
        Generate comprehensive stopping decision report

        Args:
            experiment_history: List of all experiments

        Returns:
            Report dictionary
        """
        should_stop, reasoning, next_action = self.should_stop_campaign(experiment_history)

        # Get best experiment
        best_experiment = self.get_best_experiment(experiment_history)

        # Calculate statistics
        metric_name = self.config.get('performance', {}).get('metric', 'f1_score')
        metric_values = [
            exp['metrics'][metric_name]
            for exp in experiment_history
            if metric_name in exp.get('metrics', {})
        ]

        report = {
            'should_stop': should_stop,
            'reasoning': reasoning,
            'next_action': next_action,
            'total_experiments': len(experiment_history),
            'elapsed_time_hours': (datetime.now() - self.campaign_start_time).total_seconds() / 3600,
            'best_experiment': best_experiment,
            'statistics': {
                'metric_name': metric_name,
                'best_value': max(metric_values) if metric_values else None,
                'mean_value': np.mean(metric_values) if metric_values else None,
                'std_value': np.std(metric_values) if metric_values else None,
                'improvement_from_first': (
                    metric_values[-1] - metric_values[0] if len(metric_values) >= 2 else None
                )
            }
        }

        return report

    def __repr__(self) -> str:
        return f"StoppingCriteria(experiments=?, elapsed={datetime.now() - self.campaign_start_time})"
