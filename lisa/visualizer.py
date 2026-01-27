"""
LISA Visualization Module

Generates model-specific visualizations for different types of ML models.
"""

import numpy as np
import pandas as pd
import matplotlib.pyplot as plt
import seaborn as sns
from pathlib import Path
from typing import Dict, Any, List, Optional, Union
import warnings

warnings.filterwarnings('ignore')

# Set style
sns.set_style('whitegrid')
plt.rcParams['figure.figsize'] = (10, 6)
plt.rcParams['font.size'] = 10


class Visualizer:
    """Generate visualizations for ML models and data"""

    def __init__(self, output_dir: Path):
        """
        Initialize visualizer

        Args:
            output_dir: Directory to save visualizations
        """
        self.output_dir = Path(output_dir)
        self.output_dir.mkdir(parents=True, exist_ok=True)

    def generate_visualizations(
        self,
        model_type: str,
        task_type: str,
        y_true: np.ndarray,
        y_pred: np.ndarray,
        y_pred_proba: Optional[np.ndarray] = None,
        feature_names: Optional[List[str]] = None,
        feature_importance: Optional[Dict[str, float]] = None,
        experiment_id: Optional[str] = None
    ) -> List[Path]:
        """
        Generate all relevant visualizations for a model

        Args:
            model_type: Type of model (random_forest, xgboost, etc.)
            task_type: 'classification' or 'regression'
            y_true: True labels
            y_pred: Predicted labels
            y_pred_proba: Prediction probabilities (for classification)
            feature_names: List of feature names
            feature_importance: Dictionary of feature importances
            experiment_id: Optional experiment identifier

        Returns:
            List of paths to generated visualization files
        """
        plots = []
        prefix = f"{experiment_id}_" if experiment_id else ""

        if task_type == 'classification':
            # Confusion matrix
            cm_path = self.plot_confusion_matrix(
                y_true, y_pred,
                output_path=self.output_dir / f"{prefix}confusion_matrix.png"
            )
            plots.append(cm_path)

            # ROC curves (if probabilities available)
            if y_pred_proba is not None:
                roc_path = self.plot_roc_curves(
                    y_true, y_pred_proba,
                    output_path=self.output_dir / f"{prefix}roc_curves.png"
                )
                plots.append(roc_path)

                # Precision-Recall curves
                pr_path = self.plot_precision_recall_curves(
                    y_true, y_pred_proba,
                    output_path=self.output_dir / f"{prefix}precision_recall.png"
                )
                plots.append(pr_path)

            # Class distribution
            dist_path = self.plot_class_distribution(
                y_true, y_pred,
                output_path=self.output_dir / f"{prefix}class_distribution.png"
            )
            plots.append(dist_path)

        elif task_type == 'regression':
            # Actual vs Predicted
            scatter_path = self.plot_actual_vs_predicted(
                y_true, y_pred,
                output_path=self.output_dir / f"{prefix}actual_vs_predicted.png"
            )
            plots.append(scatter_path)

            # Residual plot
            residual_path = self.plot_residuals(
                y_true, y_pred,
                output_path=self.output_dir / f"{prefix}residuals.png"
            )
            plots.append(residual_path)

            # Residual distribution
            residual_dist_path = self.plot_residual_distribution(
                y_true, y_pred,
                output_path=self.output_dir / f"{prefix}residual_distribution.png"
            )
            plots.append(residual_dist_path)

        # Feature importance (if available)
        if feature_importance:
            fi_path = self.plot_feature_importance(
                feature_importance,
                output_path=self.output_dir / f"{prefix}feature_importance.png"
            )
            plots.append(fi_path)

        return plots

    def plot_confusion_matrix(
        self,
        y_true: np.ndarray,
        y_pred: np.ndarray,
        labels: Optional[List[str]] = None,
        output_path: Optional[Path] = None
    ) -> Path:
        """Plot confusion matrix"""
        from sklearn.metrics import confusion_matrix

        cm = confusion_matrix(y_true, y_pred)

        fig, ax = plt.subplots(figsize=(8, 6))
        sns.heatmap(
            cm, annot=True, fmt='d', cmap='Blues',
            xticklabels=labels or np.unique(y_true),
            yticklabels=labels or np.unique(y_true),
            ax=ax
        )
        ax.set_xlabel('Predicted')
        ax.set_ylabel('Actual')
        ax.set_title('Confusion Matrix')

        if output_path is None:
            output_path = self.output_dir / "confusion_matrix.png"

        plt.tight_layout()
        plt.savefig(output_path, dpi=150, bbox_inches='tight')
        plt.close()

        return output_path

    def plot_roc_curves(
        self,
        y_true: np.ndarray,
        y_pred_proba: np.ndarray,
        output_path: Optional[Path] = None
    ) -> Path:
        """Plot ROC curves for each class"""
        from sklearn.metrics import roc_curve, auc
        from sklearn.preprocessing import label_binarize

        # Get unique classes
        classes = np.unique(y_true)
        n_classes = len(classes)

        fig, ax = plt.subplots(figsize=(10, 8))

        # Binary classification
        if n_classes == 2:
            fpr, tpr, _ = roc_curve(y_true, y_pred_proba[:, 1])
            roc_auc = auc(fpr, tpr)

            ax.plot(fpr, tpr, lw=2, label=f'ROC curve (AUC = {roc_auc:.3f})')

        # Multi-class
        else:
            y_true_bin = label_binarize(y_true, classes=classes)

            for i, class_label in enumerate(classes):
                fpr, tpr, _ = roc_curve(y_true_bin[:, i], y_pred_proba[:, i])
                roc_auc = auc(fpr, tpr)

                ax.plot(fpr, tpr, lw=2, label=f'Class {class_label} (AUC = {roc_auc:.3f})')

        # Diagonal line
        ax.plot([0, 1], [0, 1], 'k--', lw=2, label='Random')

        ax.set_xlabel('False Positive Rate')
        ax.set_ylabel('True Positive Rate')
        ax.set_title('ROC Curves')
        ax.legend(loc='lower right')
        ax.grid(True, alpha=0.3)

        if output_path is None:
            output_path = self.output_dir / "roc_curves.png"

        plt.tight_layout()
        plt.savefig(output_path, dpi=150, bbox_inches='tight')
        plt.close()

        return output_path

    def plot_precision_recall_curves(
        self,
        y_true: np.ndarray,
        y_pred_proba: np.ndarray,
        output_path: Optional[Path] = None
    ) -> Path:
        """Plot Precision-Recall curves"""
        from sklearn.metrics import precision_recall_curve, average_precision_score
        from sklearn.preprocessing import label_binarize

        classes = np.unique(y_true)
        n_classes = len(classes)

        fig, ax = plt.subplots(figsize=(10, 8))

        if n_classes == 2:
            precision, recall, _ = precision_recall_curve(y_true, y_pred_proba[:, 1])
            ap = average_precision_score(y_true, y_pred_proba[:, 1])

            ax.plot(recall, precision, lw=2, label=f'AP = {ap:.3f}')

        else:
            y_true_bin = label_binarize(y_true, classes=classes)

            for i, class_label in enumerate(classes):
                precision, recall, _ = precision_recall_curve(y_true_bin[:, i], y_pred_proba[:, i])
                ap = average_precision_score(y_true_bin[:, i], y_pred_proba[:, i])

                ax.plot(recall, precision, lw=2, label=f'Class {class_label} (AP = {ap:.3f})')

        ax.set_xlabel('Recall')
        ax.set_ylabel('Precision')
        ax.set_title('Precision-Recall Curves')
        ax.legend(loc='best')
        ax.grid(True, alpha=0.3)

        if output_path is None:
            output_path = self.output_dir / "precision_recall.png"

        plt.tight_layout()
        plt.savefig(output_path, dpi=150, bbox_inches='tight')
        plt.close()

        return output_path

    def plot_class_distribution(
        self,
        y_true: np.ndarray,
        y_pred: np.ndarray,
        output_path: Optional[Path] = None
    ) -> Path:
        """Plot class distribution comparison"""
        fig, axes = plt.subplots(1, 2, figsize=(14, 5))

        # True distribution
        unique, counts = np.unique(y_true, return_counts=True)
        axes[0].bar(unique, counts, color='skyblue', edgecolor='black')
        axes[0].set_xlabel('Class')
        axes[0].set_ylabel('Count')
        axes[0].set_title('True Class Distribution')
        axes[0].grid(True, alpha=0.3, axis='y')

        # Predicted distribution
        unique_pred, counts_pred = np.unique(y_pred, return_counts=True)
        axes[1].bar(unique_pred, counts_pred, color='lightcoral', edgecolor='black')
        axes[1].set_xlabel('Class')
        axes[1].set_ylabel('Count')
        axes[1].set_title('Predicted Class Distribution')
        axes[1].grid(True, alpha=0.3, axis='y')

        if output_path is None:
            output_path = self.output_dir / "class_distribution.png"

        plt.tight_layout()
        plt.savefig(output_path, dpi=150, bbox_inches='tight')
        plt.close()

        return output_path

    def plot_actual_vs_predicted(
        self,
        y_true: np.ndarray,
        y_pred: np.ndarray,
        output_path: Optional[Path] = None
    ) -> Path:
        """Plot actual vs predicted scatter plot for regression"""
        fig, ax = plt.subplots(figsize=(8, 8))

        ax.scatter(y_true, y_pred, alpha=0.5, edgecolors='k')

        # Perfect prediction line
        min_val = min(y_true.min(), y_pred.min())
        max_val = max(y_true.max(), y_pred.max())
        ax.plot([min_val, max_val], [min_val, max_val], 'r--', lw=2, label='Perfect Prediction')

        ax.set_xlabel('Actual Values')
        ax.set_ylabel('Predicted Values')
        ax.set_title('Actual vs Predicted')
        ax.legend()
        ax.grid(True, alpha=0.3)

        if output_path is None:
            output_path = self.output_dir / "actual_vs_predicted.png"

        plt.tight_layout()
        plt.savefig(output_path, dpi=150, bbox_inches='tight')
        plt.close()

        return output_path

    def plot_residuals(
        self,
        y_true: np.ndarray,
        y_pred: np.ndarray,
        output_path: Optional[Path] = None
    ) -> Path:
        """Plot residual plot"""
        residuals = y_true - y_pred

        fig, ax = plt.subplots(figsize=(10, 6))

        ax.scatter(y_pred, residuals, alpha=0.5, edgecolors='k')
        ax.axhline(y=0, color='r', linestyle='--', lw=2)

        ax.set_xlabel('Predicted Values')
        ax.set_ylabel('Residuals')
        ax.set_title('Residual Plot')
        ax.grid(True, alpha=0.3)

        if output_path is None:
            output_path = self.output_dir / "residuals.png"

        plt.tight_layout()
        plt.savefig(output_path, dpi=150, bbox_inches='tight')
        plt.close()

        return output_path

    def plot_residual_distribution(
        self,
        y_true: np.ndarray,
        y_pred: np.ndarray,
        output_path: Optional[Path] = None
    ) -> Path:
        """Plot residual distribution"""
        residuals = y_true - y_pred

        fig, ax = plt.subplots(figsize=(10, 6))

        ax.hist(residuals, bins=50, edgecolor='black', alpha=0.7)
        ax.axvline(x=0, color='r', linestyle='--', lw=2, label='Zero Residual')

        ax.set_xlabel('Residuals')
        ax.set_ylabel('Frequency')
        ax.set_title('Residual Distribution')
        ax.legend()
        ax.grid(True, alpha=0.3, axis='y')

        if output_path is None:
            output_path = self.output_dir / "residual_distribution.png"

        plt.tight_layout()
        plt.savefig(output_path, dpi=150, bbox_inches='tight')
        plt.close()

        return output_path

    def plot_feature_importance(
        self,
        feature_importance: Dict[str, float],
        top_n: int = 20,
        output_path: Optional[Path] = None
    ) -> Path:
        """Plot feature importance"""
        # Sort by importance
        sorted_features = sorted(
            feature_importance.items(),
            key=lambda x: abs(x[1]),
            reverse=True
        )[:top_n]

        features, importances = zip(*sorted_features)

        fig, ax = plt.subplots(figsize=(10, max(6, len(features) * 0.3)))

        y_pos = np.arange(len(features))
        ax.barh(y_pos, importances, color='skyblue', edgecolor='black')
        ax.set_yticks(y_pos)
        ax.set_yticklabels(features)
        ax.invert_yaxis()
        ax.set_xlabel('Importance')
        ax.set_title(f'Top {len(features)} Feature Importances')
        ax.grid(True, alpha=0.3, axis='x')

        if output_path is None:
            output_path = self.output_dir / "feature_importance.png"

        plt.tight_layout()
        plt.savefig(output_path, dpi=150, bbox_inches='tight')
        plt.close()

        return output_path

    def plot_correlation_heatmap(
        self,
        df: pd.DataFrame,
        max_features: int = 20,
        output_path: Optional[Path] = None
    ) -> Path:
        """Plot correlation heatmap"""
        # Select numeric columns
        numeric_df = df.select_dtypes(include=[np.number])

        # Limit to max_features if too many
        if len(numeric_df.columns) > max_features:
            numeric_df = numeric_df.iloc[:, :max_features]

        # Compute correlation matrix
        corr = numeric_df.corr()

        fig, ax = plt.subplots(figsize=(12, 10))
        sns.heatmap(
            corr, annot=True, fmt='.2f', cmap='coolwarm',
            center=0, square=True, ax=ax,
            cbar_kws={'label': 'Correlation'}
        )
        ax.set_title('Feature Correlation Heatmap')

        if output_path is None:
            output_path = self.output_dir / "correlation_heatmap.png"

        plt.tight_layout()
        plt.savefig(output_path, dpi=150, bbox_inches='tight')
        plt.close()

        return output_path

    def __repr__(self) -> str:
        return f"Visualizer(output_dir={self.output_dir})"
