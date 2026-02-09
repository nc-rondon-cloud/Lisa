"""
LISA Training Monitoring Module

Monitors training progress, detects issues (overfitting, convergence, anomalies),
and provides alerts and recommendations.
"""

import numpy as np
from typing import Dict, Any, List, Optional, Tuple
from collections import deque


class TrainingMonitor:
    """Monitors model training in real-time"""

    def __init__(
        self,
        patience: int = 10,
        overfitting_threshold: float = 0.1,
        convergence_threshold: float = 0.001,
        convergence_window: int = 10
    ):
        """
        Initialize training monitor

        Args:
            patience: Epochs to wait before stopping if no improvement
            overfitting_threshold: Max acceptable gap between train and val metrics
            convergence_threshold: Min change in metric to consider converged
            convergence_window: Window size for convergence detection
        """
        self.patience = patience
        self.overfitting_threshold = overfitting_threshold
        self.convergence_threshold = convergence_threshold
        self.convergence_window = convergence_window

        # Training history
        self.epochs = []
        self.train_metrics = []
        self.val_metrics = []
        self.learning_rates = []

        # Tracking
        self.best_val_metric = None
        self.best_epoch = 0
        self.epochs_since_improvement = 0

        # Status flags
        self.converged = False
        self.overfitting_detected = False
        self.anomaly_detected = False

        # Recent metrics for convergence check
        self.recent_metrics = deque(maxlen=convergence_window)

    def log_epoch(
        self,
        epoch: int,
        train_metric: float,
        val_metric: Optional[float] = None,
        learning_rate: Optional[float] = None,
        verbose: bool = False
    ):
        """
        Log metrics for an epoch

        Args:
            epoch: Epoch number
            train_metric: Training metric value
            val_metric: Validation metric value (optional)
            learning_rate: Current learning rate (optional)
            verbose: Print epoch metrics to console
        """
        self.epochs.append(epoch)
        self.train_metrics.append(train_metric)

        is_best = False

        if val_metric is not None:
            self.val_metrics.append(val_metric)
            self.recent_metrics.append(val_metric)

            # Check if this is best validation metric
            if self.best_val_metric is None or val_metric > self.best_val_metric:
                self.best_val_metric = val_metric
                self.best_epoch = epoch
                self.epochs_since_improvement = 0
                is_best = True
            else:
                self.epochs_since_improvement += 1

        if learning_rate is not None:
            self.learning_rates.append(learning_rate)

        # Console output if verbose
        if verbose:
            improvement = " ✓ NEW BEST" if is_best else ""
            if val_metric is not None:
                print(f"Epoch {epoch:3d} | Train: {train_metric:.4f} | Val: {val_metric:.4f}{improvement}")
            else:
                print(f"Epoch {epoch:3d} | Train: {train_metric:.4f}")

    def check_convergence(self) -> Tuple[bool, str]:
        """
        Check if training has converged

        Returns:
            Tuple of (converged: bool, reasoning: str)
        """
        if len(self.recent_metrics) < self.convergence_window:
            return False, "Not enough data for convergence check"

        # Calculate variance in recent metrics
        variance = np.var(list(self.recent_metrics))

        if variance < self.convergence_threshold:
            self.converged = True
            return True, f"Converged: variance {variance:.6f} < threshold {self.convergence_threshold}"

        return False, f"Not converged: variance {variance:.6f} >= threshold {self.convergence_threshold}"

    def check_overfitting(self) -> Tuple[bool, str]:
        """
        Check for overfitting

        Returns:
            Tuple of (overfitting: bool, reasoning: str)
        """
        if not self.val_metrics or not self.train_metrics:
            return False, "Not enough data for overfitting check"

        # Compare most recent train and val metrics
        train_metric = self.train_metrics[-1]
        val_metric = self.val_metrics[-1]

        gap = train_metric - val_metric

        if gap > self.overfitting_threshold:
            self.overfitting_detected = True
            return True, f"Overfitting detected: train-val gap {gap:.4f} > threshold {self.overfitting_threshold}"

        return False, f"No overfitting: train-val gap {gap:.4f} <= threshold {self.overfitting_threshold}"

    def check_anomalies(self) -> Tuple[bool, List[str]]:
        """
        Check for anomalies (NaN, exploding metrics, etc.)

        Returns:
            Tuple of (has_anomaly: bool, issues: List[str])
        """
        issues = []

        # Check for NaN in recent metrics
        if self.train_metrics and np.isnan(self.train_metrics[-1]):
            issues.append("NaN detected in training metric")

        if self.val_metrics and np.isnan(self.val_metrics[-1]):
            issues.append("NaN detected in validation metric")

        # Check for infinite values
        if self.train_metrics and np.isinf(self.train_metrics[-1]):
            issues.append("Inf detected in training metric")

        if self.val_metrics and np.isinf(self.val_metrics[-1]):
            issues.append("Inf detected in validation metric")

        # Check for sudden drops (metric degradation)
        if len(self.val_metrics) >= 2:
            recent_change = self.val_metrics[-1] - self.val_metrics[-2]
            if abs(recent_change) > 0.5:  # More than 50% change
                issues.append(f"Sudden metric change: {recent_change:.4f}")

        # Check for exploding metrics
        if self.train_metrics and abs(self.train_metrics[-1]) > 1e6:
            issues.append(f"Exploding training metric: {self.train_metrics[-1]:.2e}")

        if issues:
            self.anomaly_detected = True

        return len(issues) > 0, issues

    def should_stop(self) -> Tuple[bool, str]:
        """
        Determine if training should stop

        Returns:
            Tuple of (should_stop: bool, reasoning: str)
        """
        # Check for anomalies first
        has_anomaly, issues = self.check_anomalies()
        if has_anomaly:
            return True, f"Anomalies detected: {', '.join(issues)}"

        # Check for convergence
        converged, conv_reason = self.check_convergence()
        if converged:
            return True, conv_reason

        # Check for early stopping (patience)
        if self.epochs_since_improvement >= self.patience:
            return True, f"No improvement for {self.patience} epochs (early stopping)"

        return False, "Training should continue"

    def get_status(self) -> Dict[str, Any]:
        """
        Get current monitoring status

        Returns:
            Dictionary with monitoring status
        """
        converged, conv_reason = self.check_convergence()
        overfitting, overfit_reason = self.check_overfitting()
        has_anomaly, anomaly_issues = self.check_anomalies()
        should_stop, stop_reason = self.should_stop()

        status = {
            'total_epochs': len(self.epochs),
            'best_epoch': self.best_epoch,
            'best_val_metric': self.best_val_metric,
            'epochs_since_improvement': self.epochs_since_improvement,
            'converged': converged,
            'convergence_reasoning': conv_reason,
            'overfitting': overfitting,
            'overfitting_reasoning': overfit_reason,
            'has_anomaly': has_anomaly,
            'anomaly_issues': anomaly_issues,
            'should_stop': should_stop,
            'stop_reasoning': stop_reason
        }

        if self.train_metrics:
            status['latest_train_metric'] = self.train_metrics[-1]

        if self.val_metrics:
            status['latest_val_metric'] = self.val_metrics[-1]

        if self.learning_rates:
            status['latest_learning_rate'] = self.learning_rates[-1]

        return status

    def get_recommendations(self) -> List[str]:
        """
        Get recommendations based on monitoring

        Returns:
            List of recommendation strings
        """
        recommendations = []

        # Check overfitting
        overfitting, _ = self.check_overfitting()
        if overfitting:
            recommendations.append("Apply regularization (L1/L2, dropout)")
            recommendations.append("Reduce model complexity")
            recommendations.append("Increase training data or use data augmentation")

        # Check convergence
        if self.converged:
            recommendations.append("Training has converged - consider stopping")

        # Check for no improvement
        if self.epochs_since_improvement > self.patience // 2:
            recommendations.append("Consider adjusting learning rate")
            recommendations.append("Try different hyperparameters")

        # Check for anomalies
        has_anomaly, issues = self.check_anomalies()
        if has_anomaly:
            if "NaN" in str(issues):
                recommendations.append("Reduce learning rate to prevent NaN")
                recommendations.append("Check for invalid input data")
            if "Exploding" in str(issues):
                recommendations.append("Apply gradient clipping")
                recommendations.append("Significantly reduce learning rate")

        # Check learning rate (if available)
        if self.learning_rates and len(self.learning_rates) >= 2:
            if self.learning_rates[-1] == self.learning_rates[-2]:
                if self.epochs_since_improvement > 5:
                    recommendations.append("Consider using learning rate scheduler")

        return recommendations

    def print_training_summary(self):
        """Print comprehensive training summary to console."""
        print("\n" + "="*60)
        print("Training Summary")
        print("="*60)
        print(f"Total Epochs: {len(self.epochs)}")

        if self.best_val_metric is not None:
            print(f"Best Epoch: {self.best_epoch}")
            print(f"Best Val Metric: {self.best_val_metric:.4f}")

        if self.train_metrics:
            print(f"Final Train Metric: {self.train_metrics[-1]:.4f}")

        if self.val_metrics:
            print(f"Final Val Metric: {self.val_metrics[-1]:.4f}")

        # Check for issues
        converged, reason = self.check_convergence()
        overfitting, overfit_reason = self.check_overfitting()

        print(f"\nConverged: {converged}")
        if converged:
            print(f"  └─ {reason}")

        print(f"Overfitting: {overfitting}")
        if overfitting:
            print(f"  └─ {overfit_reason}")

        # Recommendations
        recommendations = self.get_recommendations()
        if recommendations:
            print("\nRecommendations:")
            for rec in recommendations:
                print(f"  • {rec}")

        print("="*60 + "\n")

    def plot_training_curves(self, output_path: Optional[str] = None):
        """
        Plot training curves

        Args:
            output_path: Optional path to save plot

        Returns:
            matplotlib figure
        """
        try:
            import matplotlib.pyplot as plt

            fig, axes = plt.subplots(1, 2, figsize=(14, 5))

            # Plot metrics
            ax1 = axes[0]
            ax1.plot(self.epochs, self.train_metrics, 'b-', label='Train', linewidth=2)
            if self.val_metrics:
                ax1.plot(self.epochs, self.val_metrics, 'r-', label='Validation', linewidth=2)

            # Mark best epoch
            if self.best_epoch and self.best_val_metric:
                ax1.axvline(x=self.best_epoch, color='g', linestyle='--', alpha=0.5, label='Best')

            ax1.set_xlabel('Epoch')
            ax1.set_ylabel('Metric')
            ax1.set_title('Training Curves')
            ax1.legend()
            ax1.grid(True, alpha=0.3)

            # Plot learning rate if available
            ax2 = axes[1]
            if self.learning_rates:
                ax2.plot(self.epochs[:len(self.learning_rates)], self.learning_rates, 'g-', linewidth=2)
                ax2.set_xlabel('Epoch')
                ax2.set_ylabel('Learning Rate')
                ax2.set_title('Learning Rate Schedule')
                ax2.set_yscale('log')
                ax2.grid(True, alpha=0.3)
            else:
                ax2.text(0.5, 0.5, 'No learning rate data', ha='center', va='center')
                ax2.axis('off')

            plt.tight_layout()

            if output_path:
                plt.savefig(output_path, dpi=150, bbox_inches='tight')

            return fig

        except ImportError:
            print("matplotlib not available for plotting")
            return None

    def reset(self):
        """Reset monitor state"""
        self.epochs = []
        self.train_metrics = []
        self.val_metrics = []
        self.learning_rates = []
        self.best_val_metric = None
        self.best_epoch = 0
        self.epochs_since_improvement = 0
        self.converged = False
        self.overfitting_detected = False
        self.anomaly_detected = False
        self.recent_metrics.clear()

    def __repr__(self) -> str:
        return (
            f"TrainingMonitor(epochs={len(self.epochs)}, "
            f"best_epoch={self.best_epoch}, "
            f"converged={self.converged})"
        )
